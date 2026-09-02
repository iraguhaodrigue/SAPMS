// ============================================================
// SAPMS - Notification Dispatch Service
// Sends queued notifications (attendance absences, risk alerts,
// performance updates) via SMS (Africa's Talking) and Push (FCM).
//
// This fulfils proposal Section 3.7.4 (Notification Architecture)
// and Section 3.7.6 tech stack rows: Africa's Talking API, FCM.
// ============================================================

const db = require('../config/db');

// ── Africa's Talking client (lazy-init so missing creds don't crash boot) ──
let atClient = null;
function getAfricasTalking() {
  if (atClient) return atClient;
  const username = process.env.AT_USERNAME;
  const apiKey   = process.env.AT_API_KEY;
  if (!username || !apiKey) {
    console.warn('[notificationService] AT_USERNAME/AT_API_KEY not set — SMS will run in DRY-RUN mode.');
    return null;
  }
  const AfricasTalking = require('africastalking')({ username, apiKey });
  atClient = AfricasTalking.SMS;
  return atClient;
}

// ── Firebase Admin (push) — lazy-init, optional ──────────────────────────
let firebaseAdmin = null;
function getFirebase() {
  if (firebaseAdmin) return firebaseAdmin;
  try {
    if (!process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
      console.warn('[notificationService] FIREBASE_SERVICE_ACCOUNT_PATH not set — push will run in DRY-RUN mode.');
      return null;
    }
    const admin = require('firebase-admin');
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(require(process.env.FIREBASE_SERVICE_ACCOUNT_PATH)),
      });
    }
    firebaseAdmin = admin;
    return firebaseAdmin;
  } catch (err) {
    console.warn('[notificationService] Firebase init failed — push disabled:', err.message);
    return null;
  }
}

// Normalise Rwandan phone numbers to E.164 (+250...)
function toE164(phone) {
  if (!phone) return null;
  let p = phone.replace(/[\s-]/g, '');
  if (p.startsWith('+250')) return p;
  if (p.startsWith('250'))  return `+${p}`;
  if (p.startsWith('0'))    return `+250${p.slice(1)}`;
  return p;
}

async function sendSms(phone, message) {
  const to = toE164(phone);
  if (!to) return { ok: false, reason: 'no_phone' };

  const sms = getAfricasTalking();
  if (!sms) {
    console.log(`[DRY-RUN SMS] to=${to} :: ${message}`);
    return { ok: true, dryRun: true };
  }
  try {
    const result = await sms.send({ to: [to], message, senderId: process.env.AT_SENDER_ID || undefined });
    return { ok: true, result };
  } catch (err) {
    console.error('[notificationService] SMS send failed:', err.message);
    return { ok: false, reason: err.message };
  }
}

async function sendPush(fcmToken, title, body, data = {}) {
  if (!fcmToken) return { ok: false, reason: 'no_token' };
  const admin = getFirebase();
  if (!admin) {
    console.log(`[DRY-RUN PUSH] token=${fcmToken.slice(0, 12)}... :: ${title} — ${body}`);
    return { ok: true, dryRun: true };
  }
  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data,
    });
    return { ok: true };
  } catch (err) {
    console.error('[notificationService] Push send failed:', err.message);
    return { ok: false, reason: err.message };
  }
}

// Process every 'pending' row in the notifications table.
// Called after attendance session close, after risk recalculation,
// and on a periodic cron (see src/jobs/notificationWorker.js).
async function dispatchPendingNotifications(limit = 100) {
  const [rows] = await db.query(
    `SELECT n.*, u.phone AS parent_phone, u.fcm_token AS parent_fcm_token
     FROM notifications n
     LEFT JOIN users u ON n.parent_id = u.id
     WHERE n.status = 'pending'
     ORDER BY n.created_at ASC
     LIMIT ?`,
    [limit]
  );

  let sent = 0, failed = 0;

  for (const n of rows) {
    let smsOk = true, pushOk = true;

    if (n.channel === 'sms' || n.channel === 'both') {
      const r = await sendSms(n.parent_phone, n.message);
      smsOk = r.ok;
    }
    if (n.channel === 'push' || n.channel === 'both') {
      const r = await sendPush(n.parent_fcm_token, notificationTitle(n.type), n.message, { type: n.type, student_id: n.student_id });
      // Push failing (e.g. no token on file) shouldn't block SMS-confirmed delivery
      pushOk = r.ok || r.reason === 'no_token';
    }

    const success = smsOk && pushOk;
    await db.query(
      `UPDATE notifications SET status = ?, sent_at = ? WHERE id = ?`,
      [success ? 'sent' : 'failed', success ? new Date() : null, n.id]
    );
    success ? sent++ : failed++;
  }

  return { processed: rows.length, sent, failed };
}

function notificationTitle(type) {
  switch (type) {
    case 'absence':    return 'Attendance Alert';
    case 'risk_alert':  return 'Student Risk Alert';
    case 'performance': return 'Performance Update';
    default:            return 'SAPMS Notification';
  }
}

module.exports = { dispatchPendingNotifications, sendSms, sendPush };
