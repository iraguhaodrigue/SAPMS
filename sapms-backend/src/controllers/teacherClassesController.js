// GET /api/teacher/my-classes
// The classes/subjects a teacher is assigned to via class_subjects. Used to
// pre-populate the "Create Assessment" screen so teachers can't fat-finger
// class/subject IDs (the previous UX made them type UUIDs).
const db = require('../config/db');

const getMyClasses = async (req, res) => {
  try {
    // Admins/sysadmins can browse all classes in their school
    const scope = req.user.role === 'teacher'
      ? 'cs.teacher_id = ?'
      : "(? IS NULL OR c.school_id = ?)";
    const params = req.user.role === 'teacher'
      ? [req.user.id]
      : [req.user.school_id, req.user.school_id];

    const [rows] = await db.query(
      `SELECT DISTINCT c.id AS class_id, c.name AS class_name, c.level,
              s.id AS subject_id, s.name AS subject_name,
              cs.term_id, t.term_number, t.start_date AS term_start
         FROM class_subjects cs
         JOIN classes  c ON c.id = cs.class_id
         JOIN subjects s ON s.id = cs.subject_id
         JOIN terms    t ON t.id = cs.term_id
        WHERE ${scope}
        ORDER BY c.level, c.name, s.name`, params
    );
    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error('getMyClasses error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getMyClasses };
