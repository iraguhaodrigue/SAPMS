-- Migration 006: Self-registration + admin approval
--
-- Design (agreed): teachers and parents REGISTER THEMSELVES and an admin
-- approves them; students are created by staff (minors don't self-register);
-- school admins are created by the sysadmin only.
--
-- approval_status:
--   'approved' — can log in (default for all pre-existing/staff-created users)
--   'pending'  — self-registered, waiting for admin review; login blocked
--   'rejected' — reviewed and refused; login blocked
--
-- pending_student_code: when a PARENT self-registers they supply their
-- child's student code. The link (students.parent_id) is applied only at
-- APPROVAL time, so an unapproved stranger can never attach themselves to a
-- child's record just by knowing/guessing a code.

ALTER TABLE users
    ADD COLUMN approval_status ENUM('approved','pending','rejected')
        NOT NULL DEFAULT 'approved'
        AFTER is_active,
    ADD COLUMN pending_student_code VARCHAR(20) NULL
        AFTER approval_status;
