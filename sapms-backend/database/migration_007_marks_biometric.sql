-- Migration 007: Biometric-verified grade submission (F4)
--
-- Mirrors migration_003 (attendance_sessions.biometric_verified_at). Records
-- that the teacher authenticated with their device fingerprint immediately
-- before submitting marks for this assessment.
--
-- NULL = submitted without biometric verification (e.g. marks entered before
-- this feature existed, or on a device with no biometric hardware).

ALTER TABLE assessments
    ADD COLUMN biometric_verified_at TIMESTAMP NULL DEFAULT NULL
    AFTER teacher_id;
