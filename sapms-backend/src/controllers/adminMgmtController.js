// School Administration Management — safe management of teachers, students,
// parents, classes, subjects and their relationships. Every write is scoped to
// the admin's own school (sysadmin may target any). All destructive actions are
// wrapped in transactions and recorded in the audit log. Mirrors the ownership
// and response patterns used across SAPMS (see schoolMgmtController.js).

const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');

const scopeSchoolId = (req) =>
  req.user.role === 'sysadmin'
    ? (req.query.school_id || req.body.school_id || null)
    : req.user.school_id;

// ── Audit helper — call after any successful management action ──────────
async function writeAudit(conn, req, { action, target_type, target_id, target_name, previous_value, new_value }) {
  const q = conn || db;
  await q.query(
    `INSERT INTO audit_logs
       (id, admin_id, admin_name, action, target_type, target_id, target_name,
        previous_value, new_value, school_id)
     VALUES (?,?,?,?,?,?,?,?,?,?)`,
    [uuidv4(), req.user.id, req.user.name || null, action, target_type || null,
     target_id || null, target_name || null,
     previous_value != null ? String(previous_value) : null,
     new_value != null ? String(new_value) : null,
     scopeSchoolId(req)]
  );
}

// Confirm a row belongs to the admin's school (null school = sysadmin, allowed)
function inScope(row, school_id) {
  return school_id == null || row.school_id === school_id;
}

// ════════════════════════════════════════════════════════════════════════
// AUDIT LOG (read)
// GET /api/admin/audit-log
// ════════════════════════════════════════════════════════════════════════
const getAuditLog = async (req, res) => {
  try {
    const school_id = scopeSchoolId(req);
    const [rows] = await db.query(
      `SELECT id, admin_name, action, target_type, target_name,
              previous_value, new_value, created_at
         FROM audit_logs
        WHERE (? IS NULL OR school_id = ?)
        ORDER BY created_at DESC
        LIMIT 200`,
      [school_id, school_id]);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error('getAuditLog error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ════════════════════════════════════════════════════════════════════════
// SECTION 4 — MOVE STUDENT BETWEEN CLASSES  (SAFE)
// PUT /api/admin/students/:id/move   { destination_class_id }
// ════════════════════════════════════════════════════════════════════════
const moveStudent = async (req, res) => {
  const conn = await db.getConnection();
  try {
    const { id } = req.params;
    const { destination_class_id } = req.body;
    if (!destination_class_id) {
      conn.release();
      return res.status(400).json({ success: false, message: 'destination_class_id is required' });
    }
    const school_id = scopeSchoolId(req);

    // Load student + current class, confirm school scope
    const [students] = await conn.query(
      `SELECT s.id, s.name, s.class_id, s.school_id, c.name AS current_class
         FROM students s LEFT JOIN classes c ON c.id = s.class_id
        WHERE s.id = ?`, [id]);
    if (!students.length) { conn.release(); return res.status(404).json({ success: false, message: 'Student not found' }); }
    const student = students[0];
    if (!inScope(student, school_id)) { conn.release(); return res.status(403).json({ success: false, message: 'Student is not in your school' }); }

    // Confirm destination class exists and is in the same school
    const [classes] = await conn.query(
      `SELECT id, name, school_id FROM classes WHERE id = ?`, [destination_class_id]);
    if (!classes.length) { conn.release(); return res.status(404).json({ success: false, message: 'Destination class not found' }); }
    const dest = classes[0];
    if (!inScope(dest, school_id) || dest.school_id !== student.school_id) {
      conn.release();
      return res.status(400).json({ success: false, message: 'Destination class must be in the same school' });
    }
    if (student.class_id === destination_class_id) {
      conn.release();
      return res.status(400).json({ success: false, message: 'Student is already in that class' });
    }

    await conn.beginTransaction();
    await conn.query(`UPDATE students SET class_id = ? WHERE id = ?`, [destination_class_id, id]);
    await writeAudit(conn, req, {
      action: 'student_moved', target_type: 'student', target_id: id, target_name: student.name,
      previous_value: student.current_class, new_value: dest.name,
    });
    await conn.commit();
    conn.release();
    res.json({ success: true, message: `${student.name} moved to ${dest.name}`,
      data: { student_id: id, from: student.current_class, to: dest.name } });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('moveStudent error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ════════════════════════════════════════════════════════════════════════
// SECTION 7 — ARCHIVE / DEACTIVATE STUDENT  (SAFE — keeps all records)
// PUT /api/admin/students/:id/archive   { status? }
// ════════════════════════════════════════════════════════════════════════
const archiveStudent = async (req, res) => {
  const conn = await db.getConnection();
  try {
    const { id } = req.params;
    const school_id = scopeSchoolId(req);

    const [students] = await conn.query(
      `SELECT id, name, is_active, school_id FROM students WHERE id = ?`, [id]);
    if (!students.length) { conn.release(); return res.status(404).json({ success: false, message: 'Student not found' }); }
    const student = students[0];
    if (!inScope(student, school_id)) { conn.release(); return res.status(403).json({ success: false, message: 'Student is not in your school' }); }
    if (student.is_active === 0) { conn.release(); return res.status(400).json({ success: false, message: 'Student is already inactive' }); }

    await conn.beginTransaction();
    // Only flips is_active — grades, attendance, blockchain records all preserved
    await conn.query(`UPDATE students SET is_active = 0 WHERE id = ?`, [id]);
    await writeAudit(conn, req, {
      action: 'student_archived', target_type: 'student', target_id: id, target_name: student.name,
      previous_value: 'active', new_value: 'inactive (left school)',
    });
    await conn.commit();
    conn.release();
    res.json({ success: true, message: `${student.name} archived. All academic records are preserved.` });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('archiveStudent error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// Reactivate an archived student
// PUT /api/admin/students/:id/reactivate
const reactivateStudent = async (req, res) => {
  try {
    const { id } = req.params;
    const school_id = scopeSchoolId(req);
    const [students] = await db.query(`SELECT id, name, school_id FROM students WHERE id = ?`, [id]);
    if (!students.length) return res.status(404).json({ success: false, message: 'Student not found' });
    if (!inScope(students[0], school_id)) return res.status(403).json({ success: false, message: 'Student is not in your school' });
    await db.query(`UPDATE students SET is_active = 1 WHERE id = ?`, [id]);
    await writeAudit(null, req, {
      action: 'student_reactivated', target_type: 'student', target_id: id, target_name: students[0].name,
      previous_value: 'inactive', new_value: 'active',
    });
    res.json({ success: true, message: `${students[0].name} reactivated.` });
  } catch (err) {
    console.error('reactivateStudent error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ════════════════════════════════════════════════════════════════════════
// SECTION 6 — REASSIGN PARENT TO CORRECT STUDENT  (SAFE)
// GET  /api/admin/parents                       — list parents + linked child
// PUT  /api/admin/parents/:id/reassign          { student_code }
// ════════════════════════════════════════════════════════════════════════
const getParents = async (req, res) => {
  try {
    const school_id = scopeSchoolId(req);
    const [rows] = await db.query(
      `SELECT u.id, u.name, u.email, u.school_id,
              s.id AS student_id, s.name AS student_name, s.student_code
         FROM users u
         LEFT JOIN students s ON s.parent_id = u.id
        WHERE u.role = 'parent' AND (? IS NULL OR u.school_id = ?)
        ORDER BY u.name`,
      [school_id, school_id]);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error('getParents error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const reassignParent = async (req, res) => {
  const conn = await db.getConnection();
  try {
    const { id } = req.params;               // parent user id
    const { student_code } = req.body;
    if (!student_code) { conn.release(); return res.status(400).json({ success: false, message: 'student_code is required' }); }
    const school_id = scopeSchoolId(req);

    // Confirm parent exists and in scope
    const [parents] = await conn.query(
      `SELECT id, name, school_id FROM users WHERE id = ? AND role = 'parent'`, [id]);
    if (!parents.length) { conn.release(); return res.status(404).json({ success: false, message: 'Parent not found' }); }
    const parent = parents[0];
    if (!inScope(parent, school_id)) { conn.release(); return res.status(403).json({ success: false, message: 'Parent is not in your school' }); }

    // Find the correct student by code, in the same school
    const [students] = await conn.query(
      `SELECT id, name, student_code, school_id, parent_id FROM students WHERE student_code = ?`, [student_code]);
    if (!students.length) { conn.release(); return res.status(404).json({ success: false, message: 'No student with that code' }); }
    const student = students[0];
    if (!inScope(student, school_id)) { conn.release(); return res.status(403).json({ success: false, message: 'Student is not in your school' }); }
    if (student.parent_id && student.parent_id !== id) {
      conn.release();
      return res.status(400).json({ success: false, message: `That student is already linked to another parent` });
    }

    await conn.beginTransaction();
    // Find previously linked student(s) for the audit trail, then unlink them
    const [prev] = await conn.query(`SELECT id, name FROM students WHERE parent_id = ?`, [id]);
    const prevName = prev.length ? prev.map(p => p.name).join(', ') : 'none';
    await conn.query(`UPDATE students SET parent_id = NULL WHERE parent_id = ?`, [id]);   // clear old wrong link
    await conn.query(`UPDATE students SET parent_id = ? WHERE id = ?`, [id, student.id]); // set correct link
    await writeAudit(conn, req, {
      action: 'parent_reassigned', target_type: 'parent', target_id: id, target_name: parent.name,
      previous_value: prevName, new_value: `${student.name} (${student.student_code})`,
    });
    await conn.commit();
    conn.release();
    res.json({ success: true, message: `${parent.name} is now correctly linked to ${student.name}.` });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('reassignParent error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ════════════════════════════════════════════════════════════════════════
// SECTION 5 — DELETE PARENT  (safe: unlinks children first, never deletes them)
// GET    /api/admin/parents/:id/impact
// DELETE /api/admin/parents/:id
// ════════════════════════════════════════════════════════════════════════
const parentImpact = async (req, res) => {
  try {
    const { id } = req.params;
    const [children] = await db.query(
      `SELECT id, name, student_code FROM students WHERE parent_id = ?`, [id]);
    res.json({ success: true, data: { linked_students: children } });
  } catch (err) {
    console.error('parentImpact error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const deleteParent = async (req, res) => {
  const conn = await db.getConnection();
  try {
    const { id } = req.params;
    const school_id = scopeSchoolId(req);
    const [parents] = await conn.query(
      `SELECT id, name, school_id FROM users WHERE id = ? AND role = 'parent'`, [id]);
    if (!parents.length) { conn.release(); return res.status(404).json({ success: false, message: 'Parent not found' }); }
    const parent = parents[0];
    if (!inScope(parent, school_id)) { conn.release(); return res.status(403).json({ success: false, message: 'Parent is not in your school' }); }

    await conn.beginTransaction();
    // Unlink children (keep the students!), then delete the parent account
    await conn.query(`UPDATE students SET parent_id = NULL WHERE parent_id = ?`, [id]);
    await conn.query(`DELETE FROM users WHERE id = ?`, [id]);
    await writeAudit(conn, req, {
      action: 'parent_deleted', target_type: 'parent', target_id: id, target_name: parent.name,
      previous_value: 'active parent account', new_value: 'deleted (children preserved)',
    });
    await conn.commit();
    conn.release();
    res.json({ success: true, message: `${parent.name} deleted. Their children were kept and unlinked.` });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('deleteParent error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ════════════════════════════════════════════════════════════════════════
// SECTION 1 — TEACHER MANAGEMENT
// GET    /api/admin/teachers/:id/impact   — show assignments before delete
// PUT    /api/admin/assignments/:id/unassign — remove one class_subjects row
// DELETE /api/admin/teachers/:id          — delete teacher (unassigns first)
// ════════════════════════════════════════════════════════════════════════
const teacherImpact = async (req, res) => {
  try {
    const { id } = req.params;
    const [assignments] = await db.query(
      `SELECT cs.id AS assignment_id, c.name AS class_name, sub.name AS subject_name
         FROM class_subjects cs
         JOIN classes c ON c.id = cs.class_id
         JOIN subjects sub ON sub.id = cs.subject_id
        WHERE cs.teacher_id = ?`, [id]);
    res.json({ success: true, data: { assignments } });
  } catch (err) {
    console.error('teacherImpact error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// Unassign a teacher from ONE class+subject (delete a single class_subjects row)
const unassignTeacher = async (req, res) => {
  const conn = await db.getConnection();
  try {
    const { id } = req.params;                 // class_subjects.id
    const [rows] = await conn.query(
      `SELECT cs.id, cs.teacher_id, c.name AS class_name, sub.name AS subject_name, c.school_id
         FROM class_subjects cs
         JOIN classes c ON c.id = cs.class_id
         JOIN subjects sub ON sub.id = cs.subject_id
        WHERE cs.id = ?`, [id]);
    if (!rows.length) { conn.release(); return res.status(404).json({ success: false, message: 'Assignment not found' }); }
    const a = rows[0];
    const school_id = scopeSchoolId(req);
    if (!inScope(a, school_id)) { conn.release(); return res.status(403).json({ success: false, message: 'Assignment is not in your school' }); }

    await conn.beginTransaction();
    await conn.query(`DELETE FROM class_subjects WHERE id = ?`, [id]);
    await writeAudit(conn, req, {
      action: 'teacher_unassigned', target_type: 'assignment', target_id: id,
      target_name: `${a.class_name} / ${a.subject_name}`,
      previous_value: 'assigned', new_value: 'unassigned',
    });
    await conn.commit();
    conn.release();
    res.json({ success: true, message: `Unassigned from ${a.class_name} / ${a.subject_name}.` });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('unassignTeacher error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const deleteTeacher = async (req, res) => {
  const conn = await db.getConnection();
  try {
    const { id } = req.params;
    const school_id = scopeSchoolId(req);
    const [teachers] = await conn.query(
      `SELECT id, name, school_id FROM users WHERE id = ? AND role = 'teacher'`, [id]);
    if (!teachers.length) { conn.release(); return res.status(404).json({ success: false, message: 'Teacher not found' }); }
    const teacher = teachers[0];
    if (!inScope(teacher, school_id)) { conn.release(); return res.status(403).json({ success: false, message: 'Teacher is not in your school' }); }

    await conn.beginTransaction();
    // Remove the teacher's class/subject assignments (NOT the classes or subjects themselves)
    await conn.query(`DELETE FROM class_subjects WHERE teacher_id = ?`, [id]);
    // Delete the teacher account. Attendance/marks history keeps the teacher_id
    // value but the account is gone — records themselves are not deleted.
    await conn.query(`DELETE FROM users WHERE id = ?`, [id]);
    await writeAudit(conn, req, {
      action: 'teacher_deleted', target_type: 'teacher', target_id: id, target_name: teacher.name,
      previous_value: 'active teacher', new_value: 'deleted (assignments removed, records kept)',
    });
    await conn.commit();
    conn.release();
    res.json({ success: true, message: `${teacher.name} deleted. Classes, subjects and records were kept.` });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('deleteTeacher error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ════════════════════════════════════════════════════════════════════════
// SECTION 2 — DELETE CLASS  (blocked if it still has active students)
// GET    /api/admin/classes/:id/impact
// DELETE /api/admin/classes/:id
// ════════════════════════════════════════════════════════════════════════
const classImpact = async (req, res) => {
  try {
    const { id } = req.params;
    const [[{ student_count }]] = await db.query(
      `SELECT COUNT(*) AS student_count FROM students WHERE class_id = ? AND is_active = 1`, [id]);
    const [assignments] = await db.query(
      `SELECT cs.id, u.name AS teacher_name, sub.name AS subject_name
         FROM class_subjects cs
         JOIN users u ON u.id = cs.teacher_id
         JOIN subjects sub ON sub.id = cs.subject_id
        WHERE cs.class_id = ?`, [id]);
    res.json({ success: true, data: { active_students: student_count, assignments } });
  } catch (err) {
    console.error('classImpact error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const deleteClass = async (req, res) => {
  const conn = await db.getConnection();
  try {
    const { id } = req.params;
    const school_id = scopeSchoolId(req);
    const [classes] = await conn.query(`SELECT id, name, school_id FROM classes WHERE id = ?`, [id]);
    if (!classes.length) { conn.release(); return res.status(404).json({ success: false, message: 'Class not found' }); }
    const cls = classes[0];
    if (!inScope(cls, school_id)) { conn.release(); return res.status(403).json({ success: false, message: 'Class is not in your school' }); }

    // Block deletion if active students remain — admin must move them first
    const [[{ student_count }]] = await conn.query(
      `SELECT COUNT(*) AS student_count FROM students WHERE class_id = ? AND is_active = 1`, [id]);
    if (student_count > 0) {
      conn.release();
      return res.status(400).json({ success: false,
        message: `This class still has ${student_count} active student(s). Move or archive them first.` });
    }

    await conn.beginTransaction();
    await conn.query(`DELETE FROM class_subjects WHERE class_id = ?`, [id]); // remove teacher assignments
    await conn.query(`DELETE FROM classes WHERE id = ?`, [id]);
    await writeAudit(conn, req, {
      action: 'class_deleted', target_type: 'class', target_id: id, target_name: cls.name,
      previous_value: 'active class', new_value: 'deleted',
    });
    await conn.commit();
    conn.release();
    res.json({ success: true, message: `Class ${cls.name} deleted.` });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('deleteClass error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ════════════════════════════════════════════════════════════════════════
// SECTION 3 — DELETE SUBJECT  (blocked if still assigned to any class)
// GET    /api/admin/subjects/:id/impact
// DELETE /api/admin/subjects/:id
// ════════════════════════════════════════════════════════════════════════
const subjectImpact = async (req, res) => {
  try {
    const { id } = req.params;
    const [assignments] = await db.query(
      `SELECT cs.id, c.name AS class_name, u.name AS teacher_name
         FROM class_subjects cs
         JOIN classes c ON c.id = cs.class_id
         JOIN users u ON u.id = cs.teacher_id
        WHERE cs.subject_id = ?`, [id]);
    res.json({ success: true, data: { assignments } });
  } catch (err) {
    console.error('subjectImpact error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const deleteSubject = async (req, res) => {
  const conn = await db.getConnection();
  try {
    const { id } = req.params;
    const [subjects] = await conn.query(`SELECT id, name FROM subjects WHERE id = ?`, [id]);
    if (!subjects.length) { conn.release(); return res.status(404).json({ success: false, message: 'Subject not found' }); }
    const subject = subjects[0];

    const [[{ used }]] = await conn.query(
      `SELECT COUNT(*) AS used FROM class_subjects WHERE subject_id = ?`, [id]);
    if (used > 0) {
      conn.release();
      return res.status(400).json({ success: false,
        message: `This subject is still assigned in ${used} place(s). Unassign it first.` });
    }

    await conn.beginTransaction();
    await conn.query(`DELETE FROM subjects WHERE id = ?`, [id]);
    await writeAudit(conn, req, {
      action: 'subject_deleted', target_type: 'subject', target_id: id, target_name: subject.name,
      previous_value: 'active subject', new_value: 'deleted',
    });
    await conn.commit();
    conn.release();
    res.json({ success: true, message: `Subject ${subject.name} deleted.` });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('deleteSubject error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ── List teachers with their assignment counts (for the UI) ─────────────
const getTeachersDetailed = async (req, res) => {
  try {
    const school_id = scopeSchoolId(req);
    const [rows] = await db.query(
      `SELECT u.id, u.name, u.email, u.school_id,
              (SELECT COUNT(*) FROM class_subjects cs WHERE cs.teacher_id = u.id) AS assignment_count
         FROM users u
        WHERE u.role = 'teacher' AND (? IS NULL OR u.school_id = ?)
        ORDER BY u.name`,
      [school_id, school_id]);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error('getTeachersDetailed error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = {
  getAuditLog,
  moveStudent, archiveStudent, reactivateStudent,
  getParents, reassignParent, parentImpact, deleteParent,
  teacherImpact, unassignTeacher, deleteTeacher, getTeachersDetailed,
  classImpact, deleteClass,
  subjectImpact, deleteSubject,
};
