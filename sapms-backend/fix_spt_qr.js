const crypto = require('crypto');
const db = require('./src/config/db');
const salt = process.env.QR_SALT || 'sapms_salt_2025';
(async () => {
  const [rows] = await db.query(
    "SELECT id, student_code FROM students WHERE school_id = '379882db-953c-44f7-85d1-d13eb4a0fa31'"
  );
  let n = 0;
  for (const r of rows) {
    const h = crypto.createHash('sha256').update(r.student_code + ':' + salt).digest('hex');
    await db.query('UPDATE students SET qr_code_hash = ? WHERE id = ?', [h, r.id]);
    n++;
  }
  console.log('Updated ' + n + ' SPT students with QR hashes');
  process.exit();
})();
