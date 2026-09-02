-- Migration 005: Anomaly ground-truth labels
--
-- When the dataset generator injects a synthetic anomaly (duplicate scan,
-- bulk marking, grade inflation, etc.) it records the label here.
--
-- This is what allows the evaluation to report HONEST precision/recall:
-- the ML model is scored against these known labels rather than against
-- invented figures. Rows here are ground truth for evaluation only — the
-- model never sees this table during training.

CREATE TABLE IF NOT EXISTS anomaly_ground_truth (
    id            VARCHAR(36)  PRIMARY KEY,
    entity_type   VARCHAR(40)  NOT NULL,   -- 'attendance_session' | 'mark' | 'attendance_record'
    entity_id     VARCHAR(36)  NOT NULL,   -- id of the affected row
    anomaly_type  VARCHAR(60)  NOT NULL,   -- duplicate_scan | bulk_marking | no_biometric | odd_hours | grade_inflation | attendance_spike
    description   VARCHAR(255) NULL,
    injected_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    KEY idx_entity (entity_type, entity_id),
    KEY idx_type   (anomaly_type)
);
