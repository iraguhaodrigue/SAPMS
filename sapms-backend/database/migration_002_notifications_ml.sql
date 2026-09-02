-- ============================================================
-- SAPMS Migration 002: Push notification support + ML risk fields
-- Run this AFTER schema.sql on an existing database:
--   mysql -u <user> -p sapms_db < migration_002_notifications_ml.sql
--
-- NOTE: standard MySQL 8.0 (unlike MariaDB) does not reliably support
-- "ALTER TABLE ... ADD COLUMN IF NOT EXISTS", so this migration uses a
-- small idempotent procedure instead — safe to re-run without erroring
-- if the columns already exist.
-- ============================================================

USE sapms_db;

DELIMITER $$

DROP PROCEDURE IF EXISTS sapms_add_column_if_missing $$
CREATE PROCEDURE sapms_add_column_if_missing(
    IN p_table VARCHAR(64),
    IN p_column VARCHAR(64),
    IN p_definition VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.COLUMNS
        WHERE table_schema = DATABASE()
          AND table_name = p_table
          AND column_name = p_column
    ) THEN
        SET @ddl = CONCAT('ALTER TABLE ', p_table, ' ADD COLUMN ', p_column, ' ', p_definition);
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END $$

DELIMITER ;

-- Store each parent's Firebase Cloud Messaging device token so we
-- can send push notifications alongside SMS (Section 3.7.4).
CALL sapms_add_column_if_missing('users', 'fcm_token', 'VARCHAR(255) NULL AFTER phone');

-- Record which prediction source produced a risk score, so the
-- dashboard can show "ML model" vs "rule-based fallback" (Section 3.7.5).
CALL sapms_add_column_if_missing('student_analytics', 'risk_source', "ENUM('rule_based','ml_model') DEFAULT 'rule_based' AFTER risk_score");
CALL sapms_add_column_if_missing('student_analytics', 'ml_model_version', 'VARCHAR(20) NULL AFTER risk_source');

DROP PROCEDURE IF EXISTS sapms_add_column_if_missing;
