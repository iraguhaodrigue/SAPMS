const db = require('../config/db');

// GET /api/analytics/dashboard?school_id=&term_id=
// Admin/teacher school-level overview
const getDashboard = async (req, res) => {
  try {
    const school_id = req.user.role === 'sysadmin' ? req.query.school_id : req.user.school_id;
    const { term_id } = req.query;

    if (!school_id) return res.status(400).json({ success: false, message: 'school_id required' });

    // Total students
    const [totalRows] = await db.query(
      'SELECT COUNT(*) AS total FROM students WHERE school_id = ? AND is_active = 1', [school_id]
    );

    // Risk distribution
    const [riskRows] = await db.query(`
      SELECT sa.risk_level, COUNT(*) AS count
      FROM student_analytics sa
      JOIN students s ON sa.student_id = s.id
      WHERE s.school_id = ?
      GROUP BY sa.risk_level
    `, [school_id]);

    const riskMap = { low: 0, moderate: 0, high: 0 };
    riskRows.forEach(r => { riskMap[r.risk_level] = r.count; });

    // School-wide attendance rate (current term if specified)
    let attQuery = `
      SELECT AVG(sa.attendance_rate) AS avg_attendance
      FROM student_analytics sa
      JOIN students s ON sa.student_id = s.id
      WHERE s.school_id = ?
    `;
    const attParams = [school_id];
    if (term_id) { attQuery += ' AND sa.term_id = ?'; attParams.push(term_id); }
    const [attRows] = await db.query(attQuery, attParams);

    // School-wide GPA
    let gpaQuery = `
      SELECT AVG(sa.gpa) AS avg_gpa
      FROM student_analytics sa
      JOIN students s ON sa.student_id = s.id
      WHERE s.school_id = ? AND sa.gpa IS NOT NULL
    `;
    const gpaParams = [school_id];
    if (term_id) { gpaQuery += ' AND sa.term_id = ?'; gpaParams.push(term_id); }
    const [gpaRows] = await db.query(gpaQuery, gpaParams);

    // Recent absences (last 7 days)
    const [recentAbs] = await db.query(`
      SELECT COUNT(*) AS count
      FROM attendance_records ar
      JOIN attendance_sessions sess ON ar.session_id = sess.id
      JOIN students s ON ar.student_id = s.id
      WHERE s.school_id = ? AND ar.status = 'absent'
        AND sess.session_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
    `, [school_id]);

    // Classes breakdown
    const [classRows] = await db.query(`
      SELECT c.name AS class_name, c.level,
             COUNT(DISTINCT s.id) AS student_count,
             AVG(sa.attendance_rate) AS avg_attendance,
             SUM(CASE WHEN sa.risk_level='high' THEN 1 ELSE 0 END) AS high_risk_count
      FROM classes c
      JOIN students s ON s.class_id = c.id
      LEFT JOIN student_analytics sa ON sa.student_id = s.id
      WHERE c.school_id = ? AND s.is_active = 1
      GROUP BY c.id, c.name, c.level
      ORDER BY c.name
    `, [school_id]);

    res.json({
      success: true,
      data: {
        total_students:    totalRows[0].total,
        avg_attendance:    attRows[0].avg_attendance ? parseFloat(attRows[0].avg_attendance).toFixed(1) : null,
        avg_gpa:           gpaRows[0].avg_gpa ? parseFloat(gpaRows[0].avg_gpa).toFixed(1) : null,
        absences_last_7d:  recentAbs[0].count,
        risk_distribution: riskMap,
        classes:           classRows,
      }
    });
  } catch (err) {
    console.error('Dashboard error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/analytics/at-risk?school_id=&class_id=&risk_level=high
const getAtRiskStudents = async (req, res) => {
  try {
    const school_id = req.user.role === 'sysadmin' ? req.query.school_id : req.user.school_id;
    const { class_id, risk_level } = req.query;

    let query = `
      SELECT s.id, s.student_code, s.name, s.gender,
             c.name AS class_name, c.level,
             sa.risk_level, sa.risk_score, sa.attendance_rate, sa.gpa,
             sa.absenteeism_flag, sa.subject_weakness_count, sa.performance_trend,
             sa.last_calculated,
             u.name AS parent_name, u.phone AS parent_phone
      FROM student_analytics sa
      JOIN students s ON sa.student_id = s.id
      JOIN classes c ON s.class_id = c.id
      LEFT JOIN users u ON s.parent_id = u.id
      WHERE s.is_active = 1 AND sa.risk_level != 'low'
    `;
    const params = [];

    if (school_id)  { query += ' AND s.school_id = ?';   params.push(school_id); }
    if (class_id)   { query += ' AND s.class_id = ?';    params.push(class_id); }
    if (risk_level) { query += ' AND sa.risk_level = ?';  params.push(risk_level); }

    query += ' ORDER BY sa.risk_score DESC';

    const [rows] = await db.query(query, params);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error('At-risk error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/analytics/class/:class_id/performance?term_id=
const getClassPerformance = async (req, res) => {
  try {
    const { term_id } = req.query;
    let query = `
      SELECT sub.name AS subject_name, sub.code AS subject_code,
             COUNT(DISTINCT m.student_id) AS students_assessed,
             AVG(m.score) AS class_average,
             MAX(m.score) AS highest,
             MIN(m.score) AS lowest,
             SUM(CASE WHEN m.score < 50 THEN 1 ELSE 0 END) AS below_pass
      FROM marks m
      JOIN assessments a ON m.assessment_id = a.id
      JOIN subjects sub ON a.subject_id = sub.id
      WHERE a.class_id = ? AND m.is_absent = 0 AND m.score IS NOT NULL
    `;
    const params = [req.params.class_id];
    if (term_id) { query += ' AND a.term_id = ?'; params.push(term_id); }
    query += ' GROUP BY sub.id, sub.name, sub.code ORDER BY sub.name';

    const [rows] = await db.query(query, params);
    res.json({
      success: true,
      data: rows.map(r => ({
        ...r,
        class_average: r.class_average ? parseFloat(r.class_average).toFixed(1) : null,
      }))
    });
  } catch (err) {
    console.error('Class performance error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/analytics/notifications?student_id=&status=pending
const getNotifications = async (req, res) => {
  try {
    const { student_id, status } = req.query;
    let query = `
      SELECT n.*, s.name AS student_name, s.student_code
      FROM notifications n
      JOIN students s ON n.student_id = s.id
      WHERE 1=1
    `;
    const params = [];

    // Parents only see their children's notifications
    if (req.user.role === 'parent') {
      query += ' AND n.parent_id = ?';
      params.push(req.user.id);
    }
    if (student_id) { query += ' AND n.student_id = ?'; params.push(student_id); }
    if (status)     { query += ' AND n.status = ?';     params.push(status); }

    query += ' ORDER BY n.created_at DESC LIMIT 100';

    const [rows] = await db.query(query, params);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error('Notifications error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getDashboard, getAtRiskStudents, getClassPerformance, getNotifications };
