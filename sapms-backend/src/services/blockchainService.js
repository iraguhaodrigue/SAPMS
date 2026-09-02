// ─────────────────────────────────────────────────────────────
// SAPMS-Secure — Self-Contained Blockchain Service
//
// A lightweight, dependency-free blockchain implemented directly in the
// backend. It does NOT use Ethereum, MetaMask, or any external network —
// everything runs locally and persists to the MySQL `blockchain_ledger`
// table. This demonstrates the same core properties a public blockchain
// provides:
//
//   • Cryptographic hashing (SHA-256)
//   • Block chaining (each block stores the previous block's hash)
//   • Immutability / tamper-evidence (editing any block invalidates the chain)
//   • Proof-of-work (a small mining difficulty, to show the concept)
//
// For attendance, we hash the SESSION SUMMARY (not raw student data) and
// seal that hash into a block when a teacher closes the session.
// ─────────────────────────────────────────────────────────────

const crypto = require('crypto');
const db     = require('../config/db');

// Mining difficulty: require the block hash to start with this many zeros.
// Kept low (2) so mining is instant — this is a demonstration of proof-of-work,
// not a security-critical setting. Raising it makes mining slower.
const DIFFICULTY = 2;
const LEADING = '0'.repeat(DIFFICULTY);

// Deterministic SHA-256 of any string.
function sha256(input) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

// Compute a block's hash from its contents. Order matters and must be
// identical here and during verification, or the chain won't validate.
function computeBlockHash({ block_index, timestamp, data_type, reference_id, data_hash, previous_hash, nonce }) {
  const payload = `${block_index}|${timestamp}|${data_type}|${reference_id || ''}|${data_hash}|${previous_hash}|${nonce}`;
  return sha256(payload);
}

// "Mine" a block: increment nonce until the hash satisfies the difficulty.
// With DIFFICULTY=2 this finds a hash in well under a second.
function mineBlock(block) {
  let nonce = 0;
  let hash = computeBlockHash({ ...block, nonce });
  while (!hash.startsWith(LEADING)) {
    nonce += 1;
    hash = computeBlockHash({ ...block, nonce });
  }
  return { nonce, block_hash: hash };
}

// Fetch the most recent block (highest index), or null if the chain is empty.
async function getLatestBlock() {
  const [rows] = await db.query(
    'SELECT * FROM blockchain_ledger ORDER BY block_index DESC LIMIT 1'
  );
  return rows.length ? rows[0] : null;
}

// Create the genesis block (index 0) if the chain is empty. Idempotent.
async function ensureGenesis() {
  const latest = await getLatestBlock();
  if (latest) return latest;

  const base = {
    block_index:   0,
    timestamp:     Date.now(),
    data_type:     'genesis',
    reference_id:  null,
    data_hash:     sha256('SAPMS-SECURE-GENESIS'),
    previous_hash: '0'.repeat(64),
  };
  const { nonce, block_hash } = mineBlock(base);

  await db.query(
    `INSERT INTO blockchain_ledger
       (block_index, timestamp, data_type, reference_id, data_hash, previous_hash, nonce, block_hash, created_by)
     VALUES (?,?,?,?,?,?,?,?,?)`,
    [base.block_index, base.timestamp, base.data_type, base.reference_id,
     base.data_hash, base.previous_hash, nonce, block_hash, null]
  );
  return getLatestBlock();
}

// Add a new block that certifies some record.
//   dataType    : category string, e.g. 'attendance_session'
//   referenceId : the id of the record being certified (session id)
//   recordObject: the actual data to hash (we store only its hash on-chain)
//   createdBy   : user id who triggered this (optional, for audit)
// Returns the newly created block row.
async function addBlock({ dataType, referenceId, recordObject, createdBy = null }) {
  // Make sure the chain exists first.
  await ensureGenesis();
  const prev = await getLatestBlock();

  const data_hash = sha256(JSON.stringify(recordObject));

  const base = {
    block_index:   prev.block_index + 1,
    timestamp:     Date.now(),
    data_type:     dataType,
    reference_id:  referenceId,
    data_hash,
    previous_hash: prev.block_hash,
  };
  const { nonce, block_hash } = mineBlock(base);

  await db.query(
    `INSERT INTO blockchain_ledger
       (block_index, timestamp, data_type, reference_id, data_hash, previous_hash, nonce, block_hash, created_by)
     VALUES (?,?,?,?,?,?,?,?,?)`,
    [base.block_index, base.timestamp, base.data_type, base.reference_id,
     base.data_hash, base.previous_hash, nonce, block_hash, createdBy]
  );

  return {
    block_index:   base.block_index,
    block_hash,
    previous_hash: base.previous_hash,
    data_hash,
    timestamp:     base.timestamp,
  };
}

// Walk the entire chain and verify integrity:
//   1. each block's stored hash matches a fresh recomputation
//   2. each block's previous_hash matches the actual previous block's hash
//   3. each block's hash satisfies the difficulty
// Returns { valid: true } or { valid: false, brokenAt, reason }.
async function verifyChain() {
  const [blocks] = await db.query(
    'SELECT * FROM blockchain_ledger ORDER BY block_index ASC'
  );
  if (!blocks.length) return { valid: true, length: 0, note: 'empty chain' };

  for (let i = 0; i < blocks.length; i++) {
    const b = blocks[i];

    const recomputed = computeBlockHash({
      block_index:   b.block_index,
      timestamp:     Number(b.timestamp),
      data_type:     b.data_type,
      reference_id:  b.reference_id,
      data_hash:     b.data_hash,
      previous_hash: b.previous_hash,
      nonce:         b.nonce,
    });

    if (recomputed !== b.block_hash) {
      return { valid: false, brokenAt: b.block_index, reason: 'block hash mismatch (data was tampered)' };
    }
    if (!b.block_hash.startsWith(LEADING)) {
      return { valid: false, brokenAt: b.block_index, reason: 'proof-of-work invalid' };
    }
    if (i > 0 && b.previous_hash !== blocks[i - 1].block_hash) {
      return { valid: false, brokenAt: b.block_index, reason: 'broken link to previous block' };
    }
  }
  return { valid: true, length: blocks.length };
}

// Return the whole chain (newest first) for display in the app.
async function getChain(limit = 100) {
  const [blocks] = await db.query(
    'SELECT block_index, timestamp, data_type, reference_id, data_hash, previous_hash, nonce, block_hash, created_at FROM blockchain_ledger ORDER BY block_index DESC LIMIT ?',
    [limit]
  );
  return blocks;
}

// Given a session id, re-hash its current DB state and check it against the
// hash sealed on-chain. This is the "is this record still authentic?" check.
//   currentRecordObject: freshly built summary of the session as it is NOW
// Returns { certified, matches, onChainHash, currentHash }.
async function verifyReference(referenceId, currentRecordObject) {
  const [rows] = await db.query(
    'SELECT data_hash, block_index, block_hash FROM blockchain_ledger WHERE reference_id = ? ORDER BY block_index DESC LIMIT 1',
    [referenceId]
  );
  if (!rows.length) return { certified: false, matches: false };

  const currentHash = sha256(JSON.stringify(currentRecordObject));
  return {
    certified:   true,
    matches:     currentHash === rows[0].data_hash,
    onChainHash: rows[0].data_hash,
    currentHash,
    block_index: rows[0].block_index,
    block_hash:  rows[0].block_hash,
  };
}

module.exports = {
  addBlock,
  verifyChain,
  getChain,
  verifyReference,
  ensureGenesis,
};
