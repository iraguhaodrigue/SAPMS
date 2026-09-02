-- Migration 008: Academic performance forecasts (F2)
--
-- One predicted end-of-term score per student per subject per term, produced
-- by ml_service/train_forecast.py. Regenerated in full on each training run.
--
-- cat_average and attendance_rate are stored alongside the prediction so the
-- app can explain WHY a forecast looks the way it does without re-querying
-- the whole marks and attendance history.
--
-- actual_at_risk records the true outcome where it is already known, so the
-- dissertation can show predicted-versus-actual rather than predictions alone.

CREATE TABLE IF NOT EXISTS performance_forecasts (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    student_id       VARCHAR(36)   NOT NULL,
    subject_id       VARCHAR(36)   NOT NULL,
    term_id          VARCHAR(36)   NOT NULL,
    predicted_score  DECIMAL(5,2)  NOT NULL,
    cat_average      DECIMAL(5,2)  NULL,
    attendance_rate  DECIMAL(5,2)  NULL,
    actual_at_risk   TINYINT(1)    NULL,
    generated_at     TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_forecast (student_id, subject_id, term_id),
    KEY idx_student (student_id)
);
