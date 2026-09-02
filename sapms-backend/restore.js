const db = require('./src/config/db');
const fs = require('fs');
(async () => {
  const BLOCK = 9;
  const realHash = fs.readFileSync('block_backup.txt', 'utf8').trim();
  await db.query('UPDATE blockchain_ledger SET data_hash = ? WHERE block_index = ?', [realHash, BLOCK]);
  console.log('RESTORED block', BLOCK, 'to', realHash);
  console.log('Now verify on the phone -> should show VALID again');
  process.exit();
})();
