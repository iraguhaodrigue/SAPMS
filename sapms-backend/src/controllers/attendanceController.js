const db     = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');
const mlService = require('../services/mlService');
const blockchainService = require('../services/blockchainService');
const { dispatchPendingNotifications } = require('../services/notificationService');


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

const verifyQRHash = (studentCode, scannedHash) => {
  const salt = process.env.QR_SALT || 'sapms_salt_2025';
  const expected = crypto.createHash('sha256').update(`${studentCode}:${salt}`).digest('hex');
  return expected === scannedHash;
};

// POST /api/attendance/sessions — teacher opens a session
const createSession = async (req, res) => {
  try {
    const { class_id, subject_id, term_id, session_date, period_number, biometric_verified_at } = req.body;
    if (!class_id || !subject_id || !term_id || !session_date || !period_number) {
      return res.status(400).json({ success: false, message: 'All fields required' });
    }

    // ── School isolation: class must belong to the requesting teacher's school ──
    const [classRow] = await db.query(
      'SELECT id, school_id FROM classes WHERE id = ?', [class_id]
    );
    if (!classRow.length || (req.user.role !== 'sysadmin' && classRow[0].school_id !== req.user.school_id)) {
      return res.status(403).json({ success: false, message: 'Class not found in your school' });
    }

    // ── Teacher isolation: teacher must be assigned to this class/subject ──
    if (req.user.role === 'teacher') {
      const [assigned] = await db.query(
        'SELECT id FROM class_subjects WHERE class_id=? AND subject_id=? AND teacher_id=?',
        [class_id, subject_id, req.user.id]
      );
      if (!assigned.length) {
        return res.status(403).json({ success: false, message: 'You are not assigned to this class/subject' });
      }
    }

    // ── Resume: if an open session exists for this slot, return it instead of erroring ──
    const [existing] = await db.query(
      `SELECT id FROM attendance_sessions
       WHERE class_id=? AND session_date=? AND period_number=? AND is_closed=0`,
      [class_id, session_date, period_number]
    );
    if (existing.length) {
      return res.json({ success: true, resumed: true, data: { session_id: existing[0].id } });
    }

    // biometric_verified_at is client-reported (the phone's local clock at
    // the moment the fingerprint check succeeded). We don't verify the
    // fingerprint itself server-side — that check happens on-device via the
    // OS biometric API — this column is an audit trail flag, not a security
    // boundary. Reject obviously invalid values but don't fail the whole
    // session creation over a malformed timestamp.
    let biometricVerifiedAt = null;
    if (biometric_verified_at) {
      const parsed = new Date(biometric_verified_at);
      if (!isNaN(parsed.getTime())) biometricVerifiedAt = parsed;
    }

    const id = uuidv4();
    await db.query(
      `INSERT INTO attendance_sessions (id,class_id,subject_id,teacher_id,term_id,session_date,period_number,biometric_verified_at)
       VALUES (?,?,?,?,?,?,?,?)`,
      [id, class_id, subject_id, req.user.id, term_id, session_date, period_number, biometricVerifiedAt]
    );

    const [students] = await db.query(
      'SELECT id FROM students WHERE class_id = ? AND is_active = 1', [class_id]
    );
    if (students.length) {
      const values = students.map(s => [uuidv4(), id, s.id, 'absent']);
      await db.query(
        'INSERT INTO attendance_records (id,session_id,student_id,status) VALUES ?', [values]
      );
    }

    res.status(201).json({
      success: true,
      message: 'Attendance session opened',
      data: { session_id: id, student_count: students.length }
    });
  } catch (err) {
    console.error('Create session error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/attendance/scan — teacher scans a QR code
// Also accepts an optional `client_scanned_at` ISO timestamp so that
// scans queued offline on the device (see Flutter local_db_service.dart)
// preserve their true capture time once synced.
const scanQR = async (req, res) => {
  try {
    const { session_id, qr_data, status, client_scanned_at } = req.body;
    if (!session_id || !qr_data) {
      return res.status(400).json({ success: false, message: 'session_id and qr_data required' });
    }

    const parts = qr_data.split(':');
    if (parts.length !== 3 || parts[0] !== 'SAPMS') {
      return res.status(400).json({ success: false, message: 'Invalid QR code format' });
    }
    const [, studentCode, scannedHash] = parts;

    if (!verifyQRHash(studentCode, scannedHash)) {
      return res.status(400).json({ success: false, message: 'Invalid QR code — not from SAPMS' });
    }

    const [students] = await db.query(
      'SELECT id, name FROM students WHERE student_code = ? AND is_active = 1', [studentCode]
    );
    if (!students.length) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }
    const student = students[0];

    const [sessions] = await db.query(
      'SELECT id, class_id, is_closed FROM attendance_sessions WHERE id = ?', [session_id]
    );
    if (!sessions.length) return res.status(404).json({ success: false, message: 'Session not found' });
    if (sessions[0].is_closed) return res.status(400).json({ success: false, message: 'Session is already closed' });

    const finalStatus = status || 'present';
    const scannedAt = client_scanned_at ? new Date(client_scanned_at) : new Date();
    const [result] = await db.query(
      `UPDATE attendance_records 
       SET status=?, scanned_at=?, updated_at=NOW(), synced=1
       WHERE session_id=? AND student_id=?`,
      [finalStatus, scannedAt, session_id, student.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Student not in this class' });
    }

    res.json({
      success: true,
      message: `${student.name} marked as ${finalStatus}`,
      data: { student_id: student.id, student_name: student.name, status: finalStatus }
    });
  } catch (err) {
    console.error('Scan QR error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/attendance/scan/batch — sync a batch of offline-queued scans at once.
// The Flutter app calls this when connectivity returns (offline-first design,
// proposal Section 3.7.1). Each item is processed independently so a single
// bad record doesn't fail the whole batch.
const scanBatch = async (req, res) => {
  try {
    const { scans } = req.body; // [{ session_id, qr_data, status, client_scanned_at, local_id }]
    if (!Array.isArray(scans) || !scans.length) {
      return res.status(400).json({ success: false, message: 'scans array required' });
    }

    const results = [];
    for (const scan of scans) {
      try {
        const fakeReq = { body: scan };
        let captured;
        const fakeRes = { json: (d) => (captured = d), status: () => fakeRes };
        await scanQR(fakeReq, fakeRes);
        if(captured && captured.success===false){ console.log("SCAN REJECTED:", scan.qr_data, "->", captured.message); } results.push({ local_id: scan.local_id, success: captured ? captured.success : false, ...captured });
      } catch (err) {
        results.push({ local_id: scan.local_id, success: false, message: err.message });
      }
    }

    res.json({ success: true, data: results });
  } catch (err) {
    console.error('Scan batch error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// POST /api/attendance/sessions/:id/close — close session, notify parents of absences
const closeSession = async (req, res) => {
  try {
    const { id } = req.params;

    const [sessions] = await db.query(
      'SELECT * FROM attendance_sessions WHERE id = ?', [id]
    );
    if (!sessions.length) return res.status(404).json({ success: false, message: 'Session not found' });
    if (sessions[0].is_closed) return res.status(400).json({ success: false, message: 'Already closed' });

    // Teachers may only close their own sessions; admins may close any session in their school.
    if (req.user.role === 'teacher' && sessions[0].teacher_id !== req.user.id) {
      return res.status(403).json({ success: false, message: 'You can only close your own sessions' });
    }
    if (req.user.role === 'admin') {
      const [cls] = await db.query('SELECT school_id FROM classes WHERE id=?', [sessions[0].class_id]);
      if (!cls.length || cls[0].school_id !== req.user.school_id) {
        return res.status(403).json({ success: false, message: 'Session not in your school' });
      }
    }

    await db.query(
      'UPDATE attendance_sessions SET is_closed=1, synced=1 WHERE id=?', [id]
    );

    const [absences] = await db.query(`
      SELECT ar.student_id, s.name AS student_name, s.student_code,
             s.parent_id, u.phone AS parent_phone, u.name AS parent_name,
             sess.session_date, sub.name AS subject_name
      FROM attendance_records ar
      JOIN students s ON ar.student_id = s.id
      JOIN attendance_sessions sess ON ar.session_id = sess.id
      JOIN subjects sub ON sess.subject_id = sub.id
      LEFT JOIN users u ON s.parent_id = u.id
      WHERE ar.session_id = ? AND ar.status = 'absent' AND ar.notification_sent = 0
    `, [id]);

    const notifValues = absences
      .filter(a => a.parent_id)
      .map(a => [
        uuidv4(),
        a.student_id,
        a.parent_id,
        'absence',
        'both',
        `Dear ${a.parent_name}, your child ${a.student_name} (${a.student_code}) ` +
        `was absent from ${a.subject_name} on ${a.session_date}. Please contact the school.`,
        'pending',
      ]);

    if (notifValues.length) {
      await db.query(
        'INSERT INTO notifications (id,student_id,parent_id,type,channel,message,status) VALUES ?',
        [notifValues]
      );
      await db.query(
        'UPDATE attendance_records SET notification_sent=1 WHERE session_id=? AND status="absent"', [id]
      );
    }

    // Recalculate risk analytics (tries ML microservice first, falls back to rules)
    await recalculateAnalytics(sessions[0].class_id, sessions[0].term_id);

    // ── Blockchain: seal this closed session onto the immutable ledger ──
    // We build a compact, deterministic summary of the session and record a
    // HASH of it as a new block. Raw student data never goes on-chain — only
    // the hash, which is enough to later prove the record wasn't altered.
    let blockInfo = null;
    try {
      const [counts] = await db.query(
        `SELECT
           COUNT(*) AS total,
           SUM(status='present') AS present,
           SUM(status='absent')  AS absent
         FROM attendance_records WHERE session_id = ?`, [id]
      );
      const summary = {
        session_id:    id,
        class_id:      sessions[0].class_id,
        subject_id:    sessions[0].subject_id,
        teacher_id:    sessions[0].teacher_id,
        session_date:  sessions[0].session_date,
        period_number: sessions[0].period_number,
        total:   Number(counts[0].total   || 0),
        present: Number(counts[0].present || 0),
        absent:  Number(counts[0].absent  || 0),
      };
      blockInfo = await blockchainService.addBlock({
        dataType:     'attendance_session',
        referenceId:  id,
        recordObject: summary,
        createdBy:    req.user.id,
      });
    } catch (chainErr) {
      // Blockchain sealing must never block closing the session — if it fails,
      // the attendance is still saved; we just log it (same resilience pattern
      // used for notifications below).
      console.error('Blockchain sealing failed (session still closed):', chainErr);
    }

    // Fire-and-forget: actually send the SMS/push we just queued.
    // Not awaited on the critical path so the teacher's UI isn't blocked
    // by a slow SMS gateway (important given intermittent connectivity).
    dispatchPendingNotifications().catch(err =>
      console.error('Background notification dispatch failed:', err)
    );

    res.json({
      success: true,
      message: 'Session closed',
      data: {
        absences: absences.length,
        notifications_queued: notifValues.length,
        blockchain: blockInfo, // { block_index, block_hash, ... } or null if sealing failed
      }
    });
  } catch (err) {
    console.error('Close session error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/attendance/sessions/:id/records
const getSessionRecords = async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT ar.id, ar.status, ar.scanned_at, ar.override_reason, ar.notification_sent,
             s.student_code, s.name AS student_name, s.gender
      FROM attendance_records ar
      JOIN students s ON ar.student_id = s.id
      WHERE ar.session_id = ?
      ORDER BY s.name ASC
    `, [req.params.id]);

    res.json({ success: true, count: rows.length, data: rows });
  } catch (err) {
    console.error('Get session records error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/attendance/student/:student_id?term_id=
const getStudentAttendance = async (req, res) => {
  try {
    if (!(await assertParentOwnsStudent(req, res, req.params.student_id))) return;
    const { term_id } = req.query;
    let query = `
      SELECT ar.status, ar.scanned_at, sess.session_date, sess.period_number,
             sub.name AS subject_name
      FROM attendance_records ar
      JOIN attendance_sessions sess ON ar.session_id = sess.id
      JOIN subjects sub ON sess.subject_id = sub.id
      WHERE ar.student_id = ?
    `;
    const params = [req.params.student_id];
    if (term_id) { query += ' AND sess.term_id = ?'; params.push(term_id); }
    query += ' ORDER BY sess.session_date DESC';

    const [rows] = await db.query(query, params);

    const total   = rows.length;
    const present = rows.filter(r => r.status === 'present' || r.status === 'late').length;
    const rate    = total > 0 ? ((present / total) * 100).toFixed(1) : null;

    res.json({
      success: true,
      summary: { total_sessions: total, present, absent: total - present, attendance_rate: rate },
      data: rows
    });
  } catch (err) {
    console.error('Get student attendance error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ── Feature engineering (Table 3.3) + risk recalculation ──────────────────
// Computes the derived features, tries the ML microservice for a Random
// Forest prediction, and falls back to the original rule-based logic if
// the microservice is unavailable — so grading/demoing never breaks just
// because the Python service isn't running.
const recalculateAnalytics = async (class_id, term_id) => {
  try {
    const [students] = await db.query(
      'SELECT id FROM students WHERE class_id = ? AND is_active = 1', [class_id]
    );

    for (const { id: student_id } of students) {
      // Attendance Rate
      const [attRows] = await db.query(`
        SELECT COUNT(*) AS total,
               SUM(CASE WHEN status IN ('present','late') THEN 1 ELSE 0 END) AS present_count
        FROM attendance_records ar
        JOIN attendance_sessions sess ON ar.session_id = sess.id
        WHERE ar.student_id = ? AND sess.term_id = ? AND sess.is_closed = 1
      `, [student_id, term_id]);
      const { total, present_count } = attRows[0];
      const att_rate = total > 0 ? parseFloat(((present_count / total) * 100).toFixed(2)) : null;
      const absenteeism_flag = att_rate !== null && att_rate < 85 ? 1 : 0;

      // Absenteeism Duration — longest run of consecutive absences (simplified:
      // count of absences within the last 30 calendar days)
      const [durRows] = await db.query(`
        SELECT COUNT(*) AS recent_absences
        FROM attendance_records ar
        JOIN attendance_sessions sess ON ar.session_id = sess.id
        WHERE ar.student_id = ? AND ar.status = 'absent'
          AND sess.session_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
      `, [student_id]);
      const absenteeism_duration = durRows[0].recent_absences;

      // GPA
      const [markRows] = await db.query(`
        SELECT AVG(m.score) AS avg_score
        FROM marks m
        JOIN assessments a ON m.assessment_id = a.id
        WHERE m.student_id = ? AND a.term_id = ? AND m.is_absent = 0
      `, [student_id, term_id]);
      const gpa = markRows[0].avg_score ? parseFloat(parseFloat(markRows[0].avg_score).toFixed(2)) : null;

      // Performance Trend Index — simplified linear trend: compare average
      // score of the student's earliest vs. most recent assessments this term
      const [trendRows] = await db.query(`
        SELECT m.score, a.assessment_date
        FROM marks m
        JOIN assessments a ON m.assessment_id = a.id
        WHERE m.student_id = ? AND a.term_id = ? AND m.is_absent = 0 AND m.score IS NOT NULL
        ORDER BY a.assessment_date ASC
      `, [student_id, term_id]);
      let performance_trend = 'stable';
      if (trendRows.length >= 2) {
        const mid = Math.floor(trendRows.length / 2);
        const firstHalfAvg = avg(trendRows.slice(0, mid).map(r => r.score));
        const secondHalfAvg = avg(trendRows.slice(mid).map(r => r.score));
        const delta = secondHalfAvg - firstHalfAvg;
        if (delta > 3) performance_trend = 'improving';
        else if (delta < -3) performance_trend = 'declining';
      }

      // Subject Weakness Flag count — subjects where this student's average
      // is below 50 (simplified stand-in for the ">1 SD below class mean" rule)
      const [weakRows] = await db.query(`
        SELECT sub.id, AVG(m.score) AS subj_avg
        FROM marks m
        JOIN assessments a ON m.assessment_id = a.id
        JOIN subjects sub ON a.subject_id = sub.id
        WHERE m.student_id = ? AND a.term_id = ? AND m.is_absent = 0
        GROUP BY sub.id
        HAVING subj_avg < 50
      `, [student_id, term_id]);
      const subject_weakness_count = weakRows.length;

      // ── Try ML model first ──
      const features = {
        attendance_rate: att_rate ?? 0,
        absenteeism_flag,
        absenteeism_duration,
        gpa: gpa ?? 0,
        performance_trend_numeric: performance_trend === 'improving' ? 1 : performance_trend === 'declining' ? -1 : 0,
        subject_weakness_count,
      };

      let risk_level, risk_score, risk_source = 'rule_based', ml_model_version = null;
      const mlResult = await mlService.predictRisk(features);

      if (mlResult) {
        risk_level = mlResult.riskLevel;
        risk_score = mlResult.riskScore;
        risk_source = 'ml_model';
        ml_model_version = mlResult.modelVersion;
      } else {
        // Rule-based fallback (original logic, unchanged)
        risk_level = 'low';
        risk_score = 0.1;
        if (absenteeism_flag && gpa !== null && gpa < 50) { risk_level = 'high'; risk_score = 0.85; }
        else if (absenteeism_flag || (gpa !== null && gpa < 50)) { risk_level = 'moderate'; risk_score = 0.50; }
      }

      await db.query(`
        INSERT INTO student_analytics
          (id, student_id, term_id, attendance_rate, gpa, performance_trend,
           absenteeism_flag, subject_weakness_count, risk_level, risk_score,
           risk_source, ml_model_version)
        VALUES (UUID(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
          term_id=VALUES(term_id), attendance_rate=VALUES(attendance_rate),
          gpa=VALUES(gpa), performance_trend=VALUES(performance_trend),
          absenteeism_flag=VALUES(absenteeism_flag),
          subject_weakness_count=VALUES(subject_weakness_count),
          risk_level=VALUES(risk_level), risk_score=VALUES(risk_score),
          risk_source=VALUES(risk_source), ml_model_version=VALUES(ml_model_version),
          last_calculated=NOW()
      `, [student_id, term_id, att_rate, gpa, performance_trend, absenteeism_flag,
          subject_weakness_count, risk_level, risk_score, risk_source, ml_model_version]);

      // If risk just became high, queue a parent alert (Section 3.7.4)
      if (risk_level === 'high') {
        await queueRiskAlertIfNew(student_id);
      }
    }
  } catch (err) {
    console.error('Recalculate analytics error:', err);
  }
};

function avg(arr) {
  const nums = arr.map(Number).filter(n => !Number.isNaN(n));
  if (!nums.length) return 0;
  return nums.reduce((a, b) => a + b, 0) / nums.length;
}

async function queueRiskAlertIfNew(student_id) {
  // Avoid spamming: only queue if no risk_alert was queued in the last 7 days
  const [recent] = await db.query(`
    SELECT id FROM notifications
    WHERE student_id = ? AND type = 'risk_alert' AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
  `, [student_id]);
  if (recent.length) return;

  const [studentRows] = await db.query(
    `SELECT s.name, s.student_code, s.parent_id, u.name AS parent_name
     FROM students s LEFT JOIN users u ON s.parent_id = u.id WHERE s.id = ?`,
    [student_id]
  );
  if (!studentRows.length || !studentRows[0].parent_id) return;
  const s = studentRows[0];

  await db.query(
    `INSERT INTO notifications (id, student_id, parent_id, type, channel, message, status)
     VALUES (?, ?, ?, 'risk_alert', 'both', ?, 'pending')`,
    [uuidv4(), student_id, s.parent_id,
     `Dear ${s.parent_name}, ${s.name} (${s.student_code}) has been flagged as at-risk based on ` +
     `recent attendance and academic performance. Please reach out to the school to discuss support options.`]
  );
}

module.exports = {
  createSession, scanQR, scanBatch, closeSession, getSessionRecords, getStudentAttendance,
};
