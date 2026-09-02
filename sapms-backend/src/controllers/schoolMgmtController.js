// School management — admin builds the school structure and reads reference
// lists (terms, subjects, classes, teachers). Rebuilt as a self-contained
// controller. Every write is scoped to the admin's own school; sysadmin may
// target any school. Mirrors the ownership model used across SAPMS.

const db = require('../config/db');
const { v4: uuidv4 } = require('uuid');

const scopeSchoolId = (req) =>
  req.user.role === 'sysadmin'
    ? (req.query.school_id || req.body.school_id || null)
    : req.user.school_id;

// ── TERMS ───────────────────────────────────────────────────
// GET /api/terms  — used by parent + admin screens to get the real term id
const getTerms = async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT t.id, t.term_number, t.start_date, t.end_date, t.is_current,
              ay.year_label
         FROM terms t
         JOIN academic_years ay ON ay.id = t.academic_year_id
        ORDER BY t.is_current DESC, t.start_date DESC`);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error('getTerms error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ── CLASSES (list) ──────────────────────────────────────────
// GET /api/classes  — classes in the admin's school (with student counts)
const getClasses = async (req, res) => {
  try {
    const school_id = scopeSchoolId(req);
    const [rows] = await db.query(
      `SELECT c.id, c.name, c.level, c.school_id, s.name AS school_name,
              (SELECT COUNT(*) FROM students st
                WHERE st.class_id = c.id AND st.is_active = 1) AS student_count
         FROM classes c
         JOIN schools s ON s.id = c.school_id
        WHERE (? IS NULL OR c.school_id = ?)
        ORDER BY c.level, c.name`,
      [school_id, school_id]);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error('getClasses error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/classes-create   { name, level, academic_year_id? }
const createClass = async (req, res) => {
  try {
    const { name, level } = req.body;
    let { academic_year_id } = req.body;
    if (!name || !level) {
      return res.status(400).json({ success: false, message: 'name and level are required' });
    }
    const school_id = scopeSchoolId(req);
    if (!school_id) return res.status(400).json({ success: false, message: 'No school context' });

    if (!academic_year_id) {
      const [ay] = await db.query(
        'SELECT id FROM academic_years ORDER BY is_current DESC, created_at DESC LIMIT 1');
      if (!ay.length) {
        return res.status(400).json({ success: false,
          message: 'No academic year exists. Create one first.' });
      }
      academic_year_id = ay[0].id;
    }
    const [dup] = await db.query(
      'SELECT id FROM classes WHERE school_id=? AND name=? AND academic_year_id=?',
      [school_id, name.trim(), academic_year_id]);
    if (dup.length) {
      return res.status(409).json({ success: false, message: 'A class with that name already exists' });
    }
    const id = uuidv4();
    await db.query(
      'INSERT INTO classes (id, school_id, name, level, academic_year_id) VALUES (?,?,?,?,?)',
      [id, school_id, name.trim(), level, academic_year_id]);
    res.status(201).json({ success: true, message: 'Class created',
      data: { id, name: name.trim(), level } });
  } catch (err) {
    console.error('createClass error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ── SUBJECTS ────────────────────────────────────────────────
// GET /api/subjects
const getSubjects = async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT id, code, name, level FROM subjects ORDER BY level, name');
    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error('getSubjects error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/subjects   { name, level, code? }
const createSubject = async (req, res) => {
  try {
    const { name, level } = req.body;
    let { code } = req.body;
    if (!name || !level) {
      return res.status(400).json({ success: false, message: 'name and level are required' });
    }
    if (!code) {
      const base = name.trim().toUpperCase().replace(/[^A-Z]/g, '').slice(0, 4) || 'SUBJ';
      code = `${base}-${level}`;
    }
    let finalCode = code, n = 1;
    while (true) {
      const [dup] = await db.query('SELECT id FROM subjects WHERE code = ?', [finalCode]);
      if (!dup.length) break;
      finalCode = `${code}-${n++}`;
    }
    const id = uuidv4();
    await db.query('INSERT INTO subjects (id, code, name, level) VALUES (?,?,?,?)',
      [id, finalCode, name.trim(), level]);
    res.status(201).json({ success: true, message: 'Subject created',
      data: { id, code: finalCode, name: name.trim(), level } });
  } catch (err) {
    console.error('createSubject error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ── TEACHERS (list) ─────────────────────────────────────────
// GET /api/school-teachers  — approved teachers in the admin's school
const getSchoolTeachers = async (req, res) => {
  try {
    const school_id = scopeSchoolId(req);
    const [rows] = await db.query(
      `SELECT id, name, email FROM users
        WHERE role='teacher' AND (? IS NULL OR school_id = ?)
          AND approval_status = 'approved'
        ORDER BY name`, [school_id, school_id]);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error('getSchoolTeachers error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ── ASSIGN TEACHER ──────────────────────────────────────────
// POST /api/assign-teacher   { class_id, subject_id, teacher_id, term_id }
const assignTeacher = async (req, res) => {
  try {
    const { class_id, subject_id, teacher_id, term_id } = req.body;
    if (!class_id || !subject_id || !teacher_id || !term_id) {
      return res.status(400).json({ success: false,
        message: 'class_id, subject_id, teacher_id and term_id are all required' });
    }
    const school_id = scopeSchoolId(req);

    const [cls] = await db.query('SELECT school_id FROM classes WHERE id=?', [class_id]);
    if (!cls.length) return res.status(404).json({ success: false, message: 'Class not found' });
    if (req.user.role === 'admin' && cls[0].school_id !== school_id) {
      return res.status(403).json({ success: false, message: 'Class not in your school' });
    }

    const [tch] = await db.query("SELECT school_id FROM users WHERE id=? AND role='teacher'", [teacher_id]);
    if (!tch.length) return res.status(404).json({ success: false, message: 'Teacher not found' });
    if (req.user.role === 'admin' && tch[0].school_id !== school_id) {
      return res.status(403).json({ success: false, message: 'Teacher not in your school' });
    }

    const [dup] = await db.query(
      'SELECT id FROM class_subjects WHERE class_id=? AND subject_id=? AND term_id=?',
      [class_id, subject_id, term_id]);
    if (dup.length) {
      await db.query('UPDATE class_subjects SET teacher_id=? WHERE id=?', [teacher_id, dup[0].id]);
      return res.json({ success: true,
        message: 'Assignment updated (this class/subject/term already existed)',
        data: { id: dup[0].id, reassigned: true } });
    }
    const id = uuidv4();
    await db.query(
      'INSERT INTO class_subjects (id, class_id, subject_id, teacher_id, term_id) VALUES (?,?,?,?,?)',
      [id, class_id, subject_id, teacher_id, term_id]);
    res.status(201).json({ success: true, message: 'Teacher assigned', data: { id } });
  } catch (err) {
    console.error('assignTeacher error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = {
  getTerms, getClasses, createClass,
  getSubjects, createSubject,
  getSchoolTeachers, assignTeacher,
};
