// ============================================================
// SAPMS - Notification Worker
// Runs every 5 minutes and flushes any notifications still stuck
// in 'pending' status — a safety net for cases where the fire-and-
// forget dispatch in attendanceController never completed (server
// restart mid-send, transient Africa's Talking outage, etc.).
//
// Wire this up in app.js with:  require('./jobs/notificationWorker').start();
// ============================================================

const cron = require('node-cron');
const { dispatchPendingNotifications } = require('../services/notificationService');

function start() {
  // Every 5 minutes
  cron.schedule('*/5 * * * *', async () => {
    try {
      const result = await dispatchPendingNotifications();
      if (result.processed > 0) {
        console.log(`[notificationWorker] Processed ${result.processed} (sent: ${result.sent}, failed: ${result.failed})`);
      }
    } catch (err) {
      console.error('[notificationWorker] Run failed:', err);
    }
  });
  console.log('[notificationWorker] Scheduled — runs every 5 minutes');
}

module.exports = { start };
