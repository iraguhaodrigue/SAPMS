-- Migration 004: Self-contained blockchain audit ledger
-- Each row is one block in the chain. Blocks are linked by previous_hash,
-- so any change to an old block breaks every block after it (immutability).
-- We store a HASH of the attendance session, never the raw student data.

CREATE TABLE IF NOT EXISTS blockchain_ledger (
    block_index    INT           NOT NULL,           -- position in the chain (0 = genesis)
    timestamp      BIGINT        NOT NULL,           -- unix ms when block was mined
    data_type      VARCHAR(40)   NOT NULL,           -- e.g. 'attendance_session'
    reference_id   VARCHAR(36)   NULL,               -- the session id this block certifies
    data_hash      VARCHAR(64)   NOT NULL,           -- SHA-256 of the certified record
    previous_hash  VARCHAR(64)   NOT NULL,           -- hash of the previous block
    nonce          INT           NOT NULL DEFAULT 0, -- proof-of-work counter
    block_hash     VARCHAR(64)   NOT NULL,           -- SHA-256 of this whole block
    created_by     VARCHAR(36)   NULL,               -- user id who triggered the block
    created_at     TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (block_index),
    UNIQUE KEY uq_block_hash (block_hash),
    KEY idx_reference (reference_id)
);
