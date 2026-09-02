// Layer 3 (anomaly detection) — surfaces flagged sessions/assessments to the app.
//
// Primary path: proxy the Python ML service's /detect-anomalies (hybrid
// rules + Isolation Forest). If the ML service is down, fall back to the
// deterministic RULE layer computed directly in SQL, so the Security
// Alerts screen still works — just without the ML-detected patterns.
// This mirrors the resilience pattern used for risk scoring in mlService.js.

const db = require('../config/db');

const ML_SERVICE_URL = process.env.ML_SERVICE_URL || 'http://localhost:8001';
const fetchFn = global.fetch;

const getAnomalies = async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit || '100', 10), 200);

  // 1) Try the full hybrid detector in the ML service
  try {
    const r = await fetchFn(`${ML_SERVICE_URL}/detect-anomalies?limit=${limit}`, {
      signal: AbortSignal.timeout(15000), // feature extraction over 56k rows takes a few seconds
    });
    if (r.ok) {
      const data = await r.json();
      return res.json({ success: true, source: 'ml_service', data });
    }
  } catch (_) {
    /* fall through to SQL rules */
  }

  // 2) Fallback: rule layer only, straight from SQL
  try {
    const [rows] = await db.query(
      `SELECT s.id AS session_id, s.session_date, s.biometric_verified_at,
              c.name AS class_name, u.name AS teacher_name,
              HOUR(MIN(r.scanned_at)) AS first_hour
       FROM attendance_sessions s
       JOIN classes c ON c.id = s.class_id
       JOIN users u   ON u.id = s.teacher_id
       LEFT JOIN attendance_records r ON r.session_id = s.id AND r.scanned_at IS NOT NULL
       GROUP BY s.id
       HAVING s.biometric_verified_at IS NULL
           OR (first_hour IS NOT NULL AND (first_hour < 6 OR first_hour > 18))
       ORDER BY s.session_date DESC
       LIMIT ?`, [limit]
    );

    const alerts = rows.map(r => ({
      entity_type: 'attendance_session',
      entity_id: r.session_id,
      date: String(r.session_date).slice(0, 10),
      class_name: r.class_name,
      teacher_name: r.teacher_name,
      reason: r.biometric_verified_at === null
        ? 'Session opened without biometric verification'
        : `Activity at ${String(r.first_hour).padStart(2, '0')}:00 — outside school hours`,
      severity: 'high',
      detected_by: 'rule',
      score: 0,
    }));

    res.json({
      success: true,
      source: 'sql_rules_fallback',
      data: {
        alerts,
        alert_count: alerts.length,
        models_loaded: false,
        note: 'ML service unavailable — showing policy-rule violations only',
      },
    });
  } catch (err) {
    console.error('getAnomalies error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getAnomalies };
