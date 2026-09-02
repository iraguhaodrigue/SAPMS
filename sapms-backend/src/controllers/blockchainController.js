// Blockchain read/verify endpoints for the admin ledger view.
const blockchainService = require('../services/blockchainService');
const db = require('../config/db');

// GET /api/blockchain/chain  → the full ledger (newest first)
const getChain = async (req, res) => {
  try {
    const chain = await blockchainService.getChain(200);
    res.json({ success: true, data: chain });
  } catch (err) {
    console.error('getChain error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/blockchain/verify → walk the chain and report integrity
const verify = async (req, res) => {
  try {
    const result = await blockchainService.verifyChain();
    res.json({ success: true, data: result });
  } catch (err) {
    console.error('verify error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/blockchain/verify/session/:id
// Re-hash the session's CURRENT db state and compare to what's on-chain.
// This proves whether an attendance record has been altered since it was sealed.
const verifySession = async (req, res) => {
  try {
    const { id } = req.params;

    const [sessions] = await db.query('SELECT * FROM attendance_sessions WHERE id = ?', [id]);
    if (!sessions.length) return res.status(404).json({ success: false, message: 'Session not found' });
    const s = sessions[0];

    const [counts] = await db.query(
      `SELECT COUNT(*) AS total, SUM(status='present') AS present, SUM(status='absent') AS absent
       FROM attendance_records WHERE session_id = ?`, [id]
    );

    // Must be built identically to the summary used when sealing (in closeSession).
    const summary = {
      session_id:    id,
      class_id:      s.class_id,
      subject_id:    s.subject_id,
      teacher_id:    s.teacher_id,
      session_date:  s.session_date,
      period_number: s.period_number,
      total:   Number(counts[0].total   || 0),
      present: Number(counts[0].present || 0),
      absent:  Number(counts[0].absent  || 0),
    };

    const result = await blockchainService.verifyReference(id, summary);
    res.json({ success: true, data: result });
  } catch (err) {
    console.error('verifySession error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// GET /api/blockchain/verify/assessment/:id
// Re-hash the assessment's CURRENT marks and compare to what was sealed.
// This is what proves a grade was (or wasn't) altered after submission.
const verifyAssessment = async (req, res) => {
  try {
    const crypto = require('crypto');
    const { id } = req.params;

    const [rows] = await db.query(
      `SELECT id, class_id, subject_id, teacher_id, term_id,
              assessment_name, max_score, assessment_date
         FROM assessments WHERE id = ?`, [id]
    );
    if (!rows.length) {
      return res.status(404).json({ success: false, message: 'Assessment not found' });
    }
    const a = rows[0];

    const [scores] = await db.query(
      `SELECT student_id, score, is_absent FROM marks
        WHERE assessment_id = ? ORDER BY student_id`, [id]
    );

    // Must be built identically to the summary used when sealing in
    // marksController.bulkUpdateMarks, or verification gives false negatives.
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

    const result = await blockchainService.verifyReference(id, summary);
    res.json({ success: true, data: result });
  } catch (err) {
    console.error('verifyAssessment error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getChain, verify, verifySession, verifyAssessment };
