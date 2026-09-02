// F2 — Academic performance forecasts, read side.
// Rows are produced in bulk by ml_service/train_forecast.py; this controller
// only reads them. Predicted vs actual lives side-by-side so the app (and the
// dissertation) can show forecast quality, not just forecasts.

const db = require('../config/db');

// sysadmin may pass ?school_id=; everyone else is scoped to their JWT school_id.
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

// GET /api/forecasts/student/:id?term_id=...
const getStudentForecasts = async (req, res) => {
  try {
    const { id } = req.params;
    if (!(await assertParentOwnsStudent(req, res, id))) return;
    const { term_id } = req.query;

    const params = [id];
    let termFilter = '';
    if (term_id) { termFilter = 'AND f.term_id = ?'; params.push(term_id); }

    const [rows] = await db.query(
      `SELECT f.subject_id, sub.name AS subject_name,
              f.predicted_score, f.cat_average, f.attendance_rate,
              f.actual_at_risk, f.generated_at
         FROM performance_forecasts f
         JOIN subjects sub ON sub.id = f.subject_id
        WHERE f.student_id = ? ${termFilter}
        ORDER BY f.predicted_score ASC`, params
    );

    if (!rows.length) {
      return res.json({ success: true, data: { forecasts: [], available: false } });
    }

    const preds = rows.map(r => parseFloat(r.predicted_score));
    const overall = preds.reduce((a, b) => a + b, 0) / preds.length;

    res.json({
      success: true,
      data: {
        available: true,
        overall_predicted: Math.round(overall * 10) / 10,
        subjects_at_risk: rows.filter(r => parseFloat(r.predicted_score) < 50).length,
        generated_at: rows[0].generated_at,
        forecasts: rows,
      },
    });
  } catch (err) {
    console.error('getStudentForecasts error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/forecasts/summary — admin view: students predicted to fail
const getForecastSummary = async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT f.student_id, st.name AS student_name, st.student_code,
              c.name AS class_name,
              AVG(f.predicted_score) AS predicted_avg,
              SUM(f.predicted_score < 50) AS failing_subjects,
              COUNT(*) AS subject_count
         FROM performance_forecasts f
         JOIN students st ON st.id = f.student_id
         JOIN classes c   ON c.id = st.class_id
        WHERE (? IS NULL OR c.school_id = ?)
        GROUP BY f.student_id
       HAVING failing_subjects > 0
        ORDER BY predicted_avg ASC
        LIMIT 100`,
      [scopeSchoolId(req), scopeSchoolId(req)]
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    console.error('getForecastSummary error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getStudentForecasts, getForecastSummary };
