const express    = require('express');
const router     = express.Router();
const { authenticate, authorize } = require('../middleware/auth');

// Controllers
const authCtrl       = require('../controllers/authController');
const studentsCtrl   = require('../controllers/studentsController');
const attendanceCtrl = require('../controllers/attendanceController');
const marksCtrl      = require('../controllers/marksController');
const analyticsCtrl  = require('../controllers/analyticsController');
const blockchainCtrl = require('../controllers/blockchainController');
const anomalyCtrl    = require('../controllers/anomalyController');
const forecastCtrl   = require('../controllers/forecastController');
const teacherClassesCtrl = require('../controllers/teacherClassesController');
const schoolMgmtCtrl = require('../controllers/schoolMgmtController');
const notificationService = require('../services/notificationService');
const mlService = require('../services/mlService');

// ── Health check ──────────────────────────────────────────────
router.get('/health', async (req, res) => {
  const mlHealthy = await mlService.checkHealth();
  res.json({
    status: 'ok',
    service: 'SAPMS API',
    version: '1.0.0',
    ml_service: mlHealthy ? 'connected' : 'unavailable (rule-based fallback active)',
  });
});

// ── Auth ──────────────────────────────────────────────────────
router.post('/auth/login',           authCtrl.login);
router.post('/auth/register',        authCtrl.register);
// Public: minimal school list so the registration screen can offer a dropdown.
router.get('/schools', async (req, res) => {
  try {
    const [rows] = await require('../config/db').query(
      'SELECT id, name, sector FROM schools ORDER BY name');
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
});
router.get('/auth/pending',          authenticate, authorize('admin','sysadmin'), authCtrl.pendingUsers);
router.post('/auth/review/:id',      authenticate, authorize('admin','sysadmin'), authCtrl.reviewUser);
router.get('/auth/me',               authenticate, authCtrl.me);
router.put('/auth/change-password',  authenticate, authCtrl.changePassword);

// ── Students ──────────────────────────────────────────────────
router.get('/students',              authenticate, authorize('teacher','admin','sysadmin','parent'), studentsCtrl.getStudents);
router.get('/students/:id',          authenticate, studentsCtrl.getStudent);
router.get('/classes',               authenticate, authorize('admin','sysadmin'), studentsCtrl.getClasses);
router.post('/students',             authenticate, authorize('admin','sysadmin'), studentsCtrl.createStudent);
router.get('/students/:id/qr',       authenticate, authorize('teacher','admin','sysadmin'), studentsCtrl.getStudentQR);

// ── Attendance ────────────────────────────────────────────────
router.post('/attendance/sessions',                  authenticate, authorize('teacher','admin','sysadmin'), attendanceCtrl.createSession);
router.post('/attendance/scan',                      authenticate, authorize('teacher','admin','sysadmin'), attendanceCtrl.scanQR);
router.post('/attendance/scan/batch',                authenticate, authorize('teacher','admin','sysadmin'), attendanceCtrl.scanBatch);
router.post('/attendance/sessions/:id/close',        authenticate, authorize('teacher','admin','sysadmin'), attendanceCtrl.closeSession);
router.get('/attendance/sessions/:id/records',       authenticate, authorize('teacher','admin','sysadmin'), attendanceCtrl.getSessionRecords);
router.get('/attendance/student/:student_id',        authenticate, attendanceCtrl.getStudentAttendance);

// ── Marks ─────────────────────────────────────────────────────
router.post('/marks/assessments',                                    authenticate, authorize('teacher','admin','sysadmin'), marksCtrl.createAssessment);
router.get('/marks/assessments',                                     authenticate, authorize('teacher','admin','sysadmin'), marksCtrl.getAssessments);
router.get('/marks/assessments/:assessment_id/marks',               authenticate, authorize('teacher','admin','sysadmin'), marksCtrl.getMarksSheet);
router.put('/marks/:mark_id',                                        authenticate, authorize('teacher','admin','sysadmin'), marksCtrl.updateMark);
router.post('/marks/assessments/:assessment_id/bulk',               authenticate, authorize('teacher','admin','sysadmin'), marksCtrl.bulkUpdateMarks);
router.get('/marks/student/:student_id',                             authenticate, marksCtrl.getStudentReport);

// ── Analytics ─────────────────────────────────────────────────
router.get('/analytics/dashboard',              authenticate, authorize('admin','teacher','sysadmin'), analyticsCtrl.getDashboard);
router.get('/analytics/at-risk',                authenticate, authorize('admin','teacher','sysadmin'), analyticsCtrl.getAtRiskStudents);
router.get('/analytics/class/:class_id/performance', authenticate, authorize('teacher','admin','sysadmin'), analyticsCtrl.getClassPerformance);
router.get('/analytics/notifications',          authenticate, analyticsCtrl.getNotifications);

// ── Blockchain audit ledger ───────────────────────────────────
router.get('/blockchain/chain',                 authenticate, authorize('admin','sysadmin','teacher'), blockchainCtrl.getChain);
router.get('/blockchain/verify',                authenticate, authorize('admin','sysadmin','teacher'), blockchainCtrl.verify);
router.get('/blockchain/verify/session/:id',    authenticate, authorize('teacher','admin','sysadmin'), blockchainCtrl.verifySession);
router.get('/blockchain/verify/assessment/:id', authenticate, authorize('teacher','admin','sysadmin'), blockchainCtrl.verifyAssessment);

// ── Anomaly detection (Layer 3) ───────────────────────────────
router.get('/anomalies',                        authenticate, authorize('admin','sysadmin'), anomalyCtrl.getAnomalies);

// ── Performance forecasting (F2) ──────────────────────────────
router.get('/forecasts/student/:id',            authenticate, forecastCtrl.getStudentForecasts);
router.get('/forecasts/summary',                authenticate, authorize('admin','sysadmin'), forecastCtrl.getForecastSummary);

// ── Teacher's assigned classes/subjects (from class_subjects) ─
router.get('/teacher/my-classes',               authenticate, authorize('teacher','admin','sysadmin'), teacherClassesCtrl.getMyClasses);

// Manually trigger sending of any queued (pending) notifications.
// Useful for admins after connectivity returns, and used internally
// by the background job in src/jobs/notificationWorker.js.
router.post('/notifications/dispatch', authenticate, authorize('admin','sysadmin'), async (req, res) => {
  try {
    const result = await notificationService.dispatchPendingNotifications();
    res.json({ success: true, data: result });
  } catch (err) {
    console.error('Manual dispatch error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Register/update the FCM device token for the logged-in user (parent app
// calls this once on login so risk_alert / absence push notifications work).
router.put('/auth/fcm-token', authenticate, async (req, res) => {
  const db = require('../config/db');
  const { fcm_token } = req.body;
  if (!fcm_token) return res.status(400).json({ success: false, message: 'fcm_token required' });
  try {
    await db.query('UPDATE users SET fcm_token = ? WHERE id = ?', [fcm_token, req.user.id]);
    res.json({ success: true, message: 'FCM token updated' });
  } catch (err) {
    console.error('FCM token update error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});


// -- School management + reference lists --
router.get('/terms',            authenticate, authorize('admin','sysadmin','teacher','parent'), schoolMgmtCtrl.getTerms);
router.post('/classes-create',  authenticate, authorize('admin','sysadmin'), schoolMgmtCtrl.createClass);
router.get('/subjects',         authenticate, authorize('admin','sysadmin','teacher'), schoolMgmtCtrl.getSubjects);
router.post('/subjects',        authenticate, authorize('admin','sysadmin'), schoolMgmtCtrl.createSubject);
router.get('/school-teachers',  authenticate, authorize('admin','sysadmin'), schoolMgmtCtrl.getSchoolTeachers);
router.post('/assign-teacher',  authenticate, authorize('admin','sysadmin'), schoolMgmtCtrl.assignTeacher);

module.exports = router;
