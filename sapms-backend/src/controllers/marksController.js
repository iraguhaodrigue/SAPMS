const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');
const blockchainService = require('../services/blockchainService');

// Returns school_id scoped to the requesting user.
// sysadmin may pass ?school_id= to query any school; everyone else is
// automatically scoped to their own school_id from the JWT.
const scopeSchoolId = (req) =>
  req.user.role === 'sysadmin' ? (req.query.school_id || null) : req.user.school_id;

// Parents may only access their own child's records.
const assertParentOwnsStudent = async (req, res, studentId) => {
  if (req.user.role !== 'parent') return true;
  const [rows] = await db.query('SELECT parent_id FROM students WHERE id = ?', [studentId]);
  if (!rows.length || rows[0].parent_id !== req.user.id) {
    res.status(403).json({ success: false, message: 'Access denied' });
    return false;
  }
  return true;
};

// Confirms the requesting user may act on this assessment.
//   teacher  → must own it (teacher_id === req.user.id)
//   admin    → assessment's class must be in the admin's school
//   sysadmin → unrestricted
// Mirrors the ownership model already enforced in openSession/createAssessment.
// Returns the assessment row on success; sends 403/404 and returns null otherwise.
const assertCanAccessAssessment = async (req, res, assessmentId) => {
  const [rows] = await db.query(
    `SELECT a.*, c.school_id FROM assessments a
       JOIN classes c ON c.id = a.class_id
      WHERE a.id = ?`, [assessmentId]
  );
  if (!rows.length) {
    res.status(404).json({ success: false, message: 'Assessment not found' });
    return null;
  }
  const a = rows[0];
  if (req.user.role === 'teacher' && a.teacher_id !== req.user.id) {
    res.status(403).json({ success: false, message: 'Access denied' });
    return null;
  }
  if (req.user.role === 'admin' && a.school_id !== req.user.school_id) {
    res.status(403).json({ success: false, message: 'Access denied' });
    return null;
  }
  return a;
};

// POST /api/marks/assessments — create an assessment
const createAssessment = async (req, res) => {
  try {
    const { class_id, subject_id, term_id, assessment_type, assessment_name, max_score, assessment_date } = req.body;
    if (!class_id || !subject_id || !term_id || !assessment_type || !assessment_name || !assessment_date) {
      return res.status(400).json({ success: false, message: 'All fields required' });
    }

    // ── Authorization (mirrors openSession) ──
    // Teachers may only create assessments for class/subject/term they are
    // actually assigned to in class_subjects — client-supplied IDs are never
    // trusted. Admins are scoped to their own school; sysadmin is unrestricted.
    if (req.user.role === 'teacher') {
      const [assigned] = await db.query(
        'SELECT id FROM class_subjects WHERE class_id=? AND subject_id=? AND term_id=? AND teacher_id=?',
        [class_id, subject_id, term_id, req.user.id]
      );
      if (!assigned.length) {
        return res.status(403).json({ success: false, message: 'Teacher is not assigned to this class/subject.' });
      }
    } else if (req.user.role === 'admin') {
      const [cls] = await db.query('SELECT school_id FROM classes WHERE id=?', [class_id]);
      if (!cls.length || cls[0].school_id !== req.user.school_id) {
        return res.status(403).json({ success: false, message: 'Class not found in your school' });
      }
    }

    const id = uuidv4();
    await db.query(
      `INSERT INTO assessments (id,class_id,subject_id,teacher_id,term_id,assessment_type,assessment_name,max_score,assessment_date)
       VALUES (?,?,?,?,?,?,?,?,?)`,
      [id, class_id, subject_id, req.user.id, term_id, assessment_type, assessment_name, max_score || 100, assessment_date]
    );

    // Auto-create empty mark slots for all students
    const [students] = await db.query(
      'SELECT id FROM students WHERE class_id = ? AND is_active = 1', [class_id]
    );

    // Notify parents that a new assessment has been scheduled (non-blocking)
    try {
      const [parents] = await db.query(
        `SELECT s.id AS student_id, s.parent_id FROM students s
          WHERE s.class_id=? AND s.is_active=1 AND s.parent_id IS NOT NULL`, [class_id]);
      if (parents.length) {
        const nv = parents.map(r => [uuidv4(), r.student_id, r.parent_id, 'general', 'push',
          `New assessment "${assessment_name}" scheduled for ${assessment_date}.`, 'pending']);
        await db.query(
          'INSERT INTO notifications (id,student_id,parent_id,type,channel,message,status) VALUES ?', [nv]);
      }
    } catch (nErr) { console.error('assessment notification (non-blocking):', nErr); }
    if (students.length) {
      const values = students.map(s => [uuidv4(), id, s.id]);
      await db.query(
        'INSERT INTO marks (id, assessment_id, student_id) VALUES ?', [values]
      );
    }

    res.status(201).json({
      success: true,
      message: 'Assessment created with mark slots for all students',
      data: { assessment_id: id, student_slots: students.length }
    });
  } catch (err) {
    console.error('Create assessment error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/marks/assessments?class_id=&subject_id=&term_id=&all=1
// Teachers see ONLY their own assessments by default. Pass ?all=1 to widen
// to every assessment in their school (admin view for teachers with dual
// roles, or for context browsing).
const getAssessments = async (req, res) => {
  try {
    const { class_id, subject_id, term_id, all } = req.query;
    const school_id = scopeSchoolId(req);
    let query = `
      SELECT a.*, sub.name AS subject_name, c.name AS class_name, u.name AS teacher_name,
             (SELECT COUNT(*) FROM marks WHERE assessment_id = a.id AND score IS NOT NULL) AS marked_count,
             (SELECT COUNT(*) FROM marks WHERE assessment_id = a.id) AS total_slots
      FROM assessments a
      JOIN subjects sub ON a.subject_id = sub.id
      JOIN classes c ON a.class_id = c.id
      JOIN users u ON a.teacher_id = u.id
      WHERE (? IS NULL OR c.school_id = ?)
    `;
    const params = [school_id, school_id];

    // Teacher isolation: teachers ALWAYS see only their own assessments —
    // ?all=1 must not be a bypass. The parameter only has meaning for
    // admins/sysadmins (whose scope is already school-wide), so for teachers
    // it is simply ignored.
    if (req.user.role === 'teacher') {
      query += ' AND a.teacher_id = ?';
      params.push(req.user.id);
    }

    if (class_id)  { query += ' AND a.class_id = ?';  params.push(class_id); }
    if (subject_id){ query += ' AND a.subject_id = ?'; params.push(subject_id); }
    if (term_id)   { query += ' AND a.term_id = ?';    params.push(term_id); }
    query += ' ORDER BY a.assessment_date DESC';

    const [rows] = await db.query(query, params);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error('Get assessments error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/marks/assessments/:assessment_id/marks — marks sheet for a whole class
const getMarksSheet = async (req, res) => {
  try {
    if (!(await assertCanAccessAssessment(req, res, req.params.assessment_id))) return;
    const [rows] = await db.query(`
      SELECT m.id AS mark_id, m.student_id, m.score, m.is_absent, m.remarks,
             s.student_code, s.name AS student_name, s.gender,
             a.assessment_name, a.max_score, a.assessment_type
      FROM marks m
      JOIN students s ON m.student_id = s.id
      JOIN assessments a ON m.assessment_id = a.id
      WHERE m.assessment_id = ?
      ORDER BY s.name ASC
    `, [req.params.assessment_id]);

    if (!rows.length) return res.status(404).json({ success: false, message: 'Assessment not found or no students' });

    const scored = rows.filter(r => r.score !== null);
    const avg    = scored.length ? (scored.reduce((s,r) => s + parseFloat(r.score), 0) / scored.length).toFixed(1) : null;
    const max    = scored.length ? Math.max(...scored.map(r => parseFloat(r.score))) : null;
    const min    = scored.length ? Math.min(...scored.map(r => parseFloat(r.score))) : null;

    res.json({
      success: true,
      summary: { total: rows.length, scored: scored.length, class_average: avg, highest: max, lowest: min },
      data: rows
    });
  } catch (err) {
    console.error('Get marks sheet error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// PUT /api/marks/:mark_id — update a single student's mark
const updateMark = async (req, res) => {
  try {
    const { score, is_absent, remarks } = req.body;
    await db.query(
      'UPDATE marks SET score=?, is_absent=?, remarks=?, updated_at=NOW() WHERE id=?',
      [is_absent ? null : score, is_absent ? 1 : 0, remarks || null, req.params.mark_id]
    );
    res.json({ success: true, message: 'Mark updated' });
  } catch (err) {
    console.error('Update mark error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/marks/assessments/:assessment_id/bulk — submit entire class marks at once
const bulkUpdateMarks = async (req, res) => {
  try {
    // biometric_verified_at is the device-local timestamp of the teacher's
    // successful fingerprint check, captured just before submission (F4).
    // As with attendance, the fingerprint itself is verified on-device by the
    // OS biometric API — this column is an audit-trail flag, not a server-side
    // security boundary.
    const { marks, biometric_verified_at } = req.body; // [{ student_id, score, is_absent, remarks }]
    if (!Array.isArray(marks) || !marks.length) {
      return res.status(400).json({ success: false, message: 'marks array required' });
    }

    const assessmentId = req.params.assessment_id;

    // Ownership: a teacher may only write marks for their own assessment;
    // admin only within their school. Prevents cross-teacher/cross-school
    // mark tampering via a guessed assessment id.
    if (!(await assertCanAccessAssessment(req, res, assessmentId))) return;

    let bioAt = null;
    if (biometric_verified_at) {
      const parsed = new Date(biometric_verified_at);
      if (!isNaN(parsed.getTime())) bioAt = parsed;
    }

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      for (const m of marks) {
        await conn.query(
          `UPDATE marks SET score=?, is_absent=?, remarks=?, synced=1, updated_at=NOW()
           WHERE assessment_id=? AND student_id=?`,
          [m.is_absent ? null : m.score, m.is_absent ? 1 : 0, m.remarks || null,
           assessmentId, m.student_id]
        );
      }
      if (bioAt) {
        await conn.query(
          'UPDATE assessments SET biometric_verified_at=? WHERE id=?',
          [bioAt, assessmentId]
        );
      }
      await conn.commit();
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }

    // ── Blockchain: seal this grade submission onto the ledger (F3) ──
    // Grade manipulation is one of the three problems the system addresses,
    // so marks are sealed the same way attendance sessions are. We hash a
    // deterministic summary — never the individual scores — which is enough
    // to prove later that no mark was altered after submission.
    let blockInfo = null;
    try {
      const [rows] = await db.query(
        `SELECT a.id, a.class_id, a.subject_id, a.teacher_id, a.term_id,
                a.assessment_name, a.max_score, a.assessment_date
           FROM assessments a WHERE a.id = ?`, [assessmentId]
      );

      if (rows.length) {
        const a = rows[0];
        const [scores] = await db.query(
          `SELECT student_id, score, is_absent FROM marks
            WHERE assessment_id = ? ORDER BY student_id`, [assessmentId]
        );

        // Order-independent checksum over every (student, score) pair, so any
        // later edit to any single mark changes the sealed hash.
        const checksum = crypto.createHash('sha256').update(
          scores.map(r => `${r.student_id}:${r.is_absent ? 'A' : r.score}`).join('|')
        ).digest('hex');

        const summary = {
          assessment_id:   a.id,
          class_id:        a.class_id,
          subject_id:      a.subject_id,
          teacher_id:      a.teacher_id,
          term_id:         a.term_id,
          assessment_name: a.assessment_name,
          max_score:       a.max_score,
          mark_count:      scores.length,
          score_checksum:  checksum,
        };

        blockInfo = await blockchainService.addBlock({
          dataType:     'mark_submission',
          referenceId:  assessmentId,
          recordObject: summary,
          createdBy:    req.user.id,
        });
      }
    } catch (chainErr) {
      // Sealing must never block the teacher's submission — the marks are
      // already committed. Same resilience pattern as attendance closing.
      console.error('Blockchain sealing of marks failed (marks still saved):', chainErr);
    }

    // ── Trigger analytics recalculation so risk/GPA stay fresh after marks ──
    // (previously only happened on session close, leaving GPA stale until next attendance)
    try {
      const [asmtRow] = await db.query(
        'SELECT class_id, term_id FROM assessments WHERE id=?', [assessmentId]);
      if (asmtRow.length) {
        await db.query(
          `UPDATE student_analytics sa
              JOIN students st ON st.id = sa.student_id
              JOIN marks m ON m.student_id = st.id
              JOIN assessments a ON a.id = m.assessment_id
             SET sa.gpa = (
               SELECT ROUND(AVG(m2.score),2) FROM marks m2
               JOIN assessments a2 ON a2.id = m2.assessment_id
               WHERE m2.student_id = sa.student_id AND a2.term_id=? AND m2.is_absent=0
             ),
             sa.last_calculated = NOW()
           WHERE a.id = ? AND m.is_absent = 0`,
          [asmtRow[0].term_id, assessmentId]
        );

        // Notify parents when marks are published
        const [studentRows] = await db.query(
          `SELECT s.id AS student_id, s.parent_id, s.name AS student_name,
                  a.assessment_name, sub.name AS subject_name
             FROM marks mk
             JOIN students s ON s.id = mk.student_id
             JOIN assessments a ON a.id = mk.assessment_id
             JOIN subjects sub ON sub.id = a.subject_id
            WHERE mk.assessment_id = ? AND s.parent_id IS NOT NULL AND mk.is_absent = 0`,
          [assessmentId]
        );
        if (studentRows.length) {
          const notifValues = studentRows.map(r => [
            require('uuid').v4(), r.student_id, r.parent_id,
            'performance', 'push',
            `Marks published for ${r.assessment_name} (${r.subject_name}) — check your child's performance.`,
            'pending'
          ]);
          if (notifValues.length) {
            await db.query(
              'INSERT INTO notifications (id,student_id,parent_id,type,channel,message,status) VALUES ?',
              [notifValues]
            );
          }
        }
      }
    } catch (analyticsErr) {
      console.error('Post-marks analytics/notify (non-blocking):', analyticsErr);
    }

    res.json({
      success: true,
      message: `${marks.length} marks updated`,
      data: {
        biometric_verified: bioAt !== null,
        blockchain: blockInfo,
      },
    });
  } catch (err) {
    console.error('Bulk update marks error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/marks/student/:student_id?term_id= — full academic report for one student
const getStudentReport = async (req, res) => {
  try {
    if (!(await assertParentOwnsStudent(req, res, req.params.student_id))) return;
    const { term_id } = req.query;
    let query = `
      SELECT m.score, m.is_absent,
             a.assessment_name, a.assessment_type, a.max_score, a.assessment_date,
             sub.name AS subject_name, sub.code AS subject_code
      FROM marks m
      JOIN assessments a ON m.assessment_id = a.id
      JOIN subjects sub ON a.subject_id = sub.id
      WHERE m.student_id = ?
    `;
    const params = [req.params.student_id];
    if (term_id) { query += ' AND a.term_id = ?'; params.push(term_id); }
    query += ' ORDER BY sub.name ASC, a.assessment_date ASC';

    const [rows] = await db.query(query, params);

    // Group by subject
    const bySubject = {};
    for (const r of rows) {
      if (!bySubject[r.subject_code]) {
        bySubject[r.subject_code] = { subject: r.subject_name, assessments: [], average: null };
      }
      bySubject[r.subject_code].assessments.push(r);
    }
    for (const key of Object.keys(bySubject)) {
      const scored = bySubject[key].assessments.filter(a => a.score !== null);
      if (scored.length) {
        bySubject[key].average = (scored.reduce((s,a) => s + parseFloat(a.score), 0) / scored.length).toFixed(1);
      }
    }

    res.json({ success: true, data: bySubject });
  } catch (err) {
    console.error('Get student report error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { createAssessment, getAssessments, getMarksSheet, updateMark, bulkUpdateMarks, getStudentReport };
