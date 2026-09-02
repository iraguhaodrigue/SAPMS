const db = require('./src/config/db');
const fs = require('fs');
(async () => {
  const BLOCK = 9;
  // Save the real hash to a file first
  const [rows] = await db.query('SELECT data_hash FROM blockchain_ledger WHERE block_index = ?', [BLOCK]);
  const realHash = rows[0].data_hash;
  fs.writeFileSync('block_backup.txt', realHash);
  console.log('SAVED real hash:', realHash);
  // Tamper
  await db.query("UPDATE blockchain_ledger SET data_hash = ? WHERE block_index = ?",
    ['ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', BLOCK]);
  console.log('TAMPERED block', BLOCK, '- now go verify on the phone -> should show INVALID');
  process.exit();
})();
