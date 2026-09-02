-- Migration 003: Biometric-verified attendance sessions
-- Adds a column recording that the teacher who opened this session
-- authenticated with their device fingerprint immediately before opening it.
-- NULL = session opened without biometric verification (e.g. before this
-- feature existed, or biometric hardware unavailable).

ALTER TABLE attendance_sessions
    ADD COLUMN biometric_verified_at TIMESTAMP NULL DEFAULT NULL
    AFTER teacher_id;
