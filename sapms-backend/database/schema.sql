-- ============================================================
-- SAPMS - Student Attendance & Performance Monitoring System
-- Database Schema v1.0
-- University of Kigali | NSHUTIYIMANA Abraham (Reg: 25012215)
-- ============================================================

CREATE DATABASE IF NOT EXISTS sapms_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE sapms_db;

-- ============================================================
-- SCHOOLS
-- ============================================================
CREATE TABLE schools (
    id          VARCHAR(36) PRIMARY KEY,
    code        VARCHAR(10) NOT NULL UNIQUE,        -- e.g. NS-01
    name        VARCHAR(150) NOT NULL,
    zone        ENUM('lakeshore','highland','intermediate') NOT NULL,
    sector      VARCHAR(100) NOT NULL,
    type        ENUM('public','government-aided','private') NOT NULL,
    solar_power TINYINT(1) DEFAULT 0,              -- 1 = solar only
    network_quality ENUM('good','intermittent','poor') DEFAULT 'intermittent',
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- USERS  (4 roles as per proposal Section 3.7.3)
-- ============================================================
CREATE TABLE users (
    id          VARCHAR(36) PRIMARY KEY,
    school_id   VARCHAR(36) REFERENCES schools(id),
    name        VARCHAR(150) NOT NULL,
    email       VARCHAR(150) NOT NULL UNIQUE,
    phone       VARCHAR(20),
    password    VARCHAR(255) NOT NULL,             -- bcrypt hashed
    role        ENUM('teacher','admin','parent','sysadmin') NOT NULL,
    is_active   TINYINT(1) DEFAULT 1,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ============================================================
-- ACADEMIC YEARS & TERMS
-- ============================================================
CREATE TABLE academic_years (
    id          VARCHAR(36) PRIMARY KEY,
    year_label  VARCHAR(20) NOT NULL,              -- e.g. 2024-2025
    is_current  TINYINT(1) DEFAULT 0,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE terms (
    id              VARCHAR(36) PRIMARY KEY,
    academic_year_id VARCHAR(36) NOT NULL REFERENCES academic_years(id),
    term_number     TINYINT NOT NULL,              -- 1, 2, or 3
    start_date      DATE NOT NULL,
    end_date        DATE NOT NULL,
    is_current      TINYINT(1) DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- SUBJECTS
-- ============================================================
CREATE TABLE subjects (
    id          VARCHAR(36) PRIMARY KEY,
    code        VARCHAR(20) NOT NULL UNIQUE,       -- e.g. MATH-S4
    name        VARCHAR(100) NOT NULL,
    level       ENUM('S1','S2','S3','S4','S5','S6') NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- CLASSES
-- ============================================================
CREATE TABLE classes (
    id          VARCHAR(36) PRIMARY KEY,
    school_id   VARCHAR(36) NOT NULL REFERENCES schools(id),
    name        VARCHAR(50) NOT NULL,              -- e.g. S4-A
    level       ENUM('S1','S2','S3','S4','S5','S6') NOT NULL,
    academic_year_id VARCHAR(36) NOT NULL REFERENCES academic_years(id),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- STUDENTS
-- ============================================================
CREATE TABLE students (
    id              VARCHAR(36) PRIMARY KEY,
    school_id       VARCHAR(36) NOT NULL REFERENCES schools(id),
    class_id        VARCHAR(36) NOT NULL REFERENCES classes(id),
    student_code    VARCHAR(20) NOT NULL UNIQUE,   -- alphanumeric ID
    name            VARCHAR(150) NOT NULL,
    gender          ENUM('M','F') NOT NULL,
    date_of_birth   DATE,
    parent_id       VARCHAR(36) REFERENCES users(id),
    qr_code_hash    VARCHAR(255),                  -- SHA-256 hash for QR
    is_active       TINYINT(1) DEFAULT 1,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ============================================================
-- CLASS-TEACHER-SUBJECT ASSIGNMENTS
-- ============================================================
CREATE TABLE class_subjects (
    id          VARCHAR(36) PRIMARY KEY,
    class_id    VARCHAR(36) NOT NULL REFERENCES classes(id),
    subject_id  VARCHAR(36) NOT NULL REFERENCES subjects(id),
    teacher_id  VARCHAR(36) NOT NULL REFERENCES users(id),
    term_id     VARCHAR(36) NOT NULL REFERENCES terms(id),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_class_subject_term (class_id, subject_id, term_id)
);

-- ============================================================
-- ATTENDANCE SESSIONS  (one per class-period)
-- ============================================================
CREATE TABLE attendance_sessions (
    id              VARCHAR(36) PRIMARY KEY,
    class_id        VARCHAR(36) NOT NULL REFERENCES classes(id),
    subject_id      VARCHAR(36) NOT NULL REFERENCES subjects(id),
    teacher_id      VARCHAR(36) NOT NULL REFERENCES users(id),
    term_id         VARCHAR(36) NOT NULL REFERENCES terms(id),
    session_date    DATE NOT NULL,
    period_number   TINYINT NOT NULL,              -- 1-8 periods per day
    is_closed       TINYINT(1) DEFAULT 0,          -- closed = no more scanning
    synced          TINYINT(1) DEFAULT 0,          -- for offline-first tracking
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- ATTENDANCE RECORDS  (one per student per session)
-- ============================================================
CREATE TABLE attendance_records (
    id              VARCHAR(36) PRIMARY KEY,
    session_id      VARCHAR(36) NOT NULL REFERENCES attendance_sessions(id),
    student_id      VARCHAR(36) NOT NULL REFERENCES students(id),
    status          ENUM('present','absent','late','excused') NOT NULL DEFAULT 'absent',
    scanned_at      TIMESTAMP NULL,                -- NULL = auto-marked absent
    override_reason VARCHAR(255),                  -- if teacher overrode
    notification_sent TINYINT(1) DEFAULT 0,        -- SMS/push sent to parent
    synced          TINYINT(1) DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_session_student (session_id, student_id)
);

-- ============================================================
-- MARKS / ASSESSMENTS
-- ============================================================
CREATE TABLE assessments (
    id              VARCHAR(36) PRIMARY KEY,
    class_id        VARCHAR(36) NOT NULL REFERENCES classes(id),
    subject_id      VARCHAR(36) NOT NULL REFERENCES subjects(id),
    teacher_id      VARCHAR(36) NOT NULL REFERENCES users(id),
    term_id         VARCHAR(36) NOT NULL REFERENCES terms(id),
    assessment_type ENUM('continuous','midterm','endterm') NOT NULL,
    assessment_name VARCHAR(100) NOT NULL,         -- e.g. "CAT 1"
    max_score       DECIMAL(5,2) NOT NULL DEFAULT 100,
    assessment_date DATE NOT NULL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE marks (
    id              VARCHAR(36) PRIMARY KEY,
    assessment_id   VARCHAR(36) NOT NULL REFERENCES assessments(id),
    student_id      VARCHAR(36) NOT NULL REFERENCES students(id),
    score           DECIMAL(5,2),                  -- NULL = absent/not yet marked
    is_absent       TINYINT(1) DEFAULT 0,
    remarks         VARCHAR(255),
    synced          TINYINT(1) DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_assessment_student (assessment_id, student_id)
);

-- ============================================================
-- NOTIFICATIONS LOG
-- ============================================================
CREATE TABLE notifications (
    id              VARCHAR(36) PRIMARY KEY,
    student_id      VARCHAR(36) NOT NULL REFERENCES students(id),
    parent_id       VARCHAR(36) REFERENCES users(id),
    type            ENUM('absence','risk_alert','performance','general') NOT NULL,
    channel         ENUM('sms','push','both') NOT NULL DEFAULT 'both',
    message         TEXT NOT NULL,
    status          ENUM('pending','sent','failed') DEFAULT 'pending',
    sent_at         TIMESTAMP NULL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- ANALYTICS CACHE  (rule-based risk flags, updated by backend)
-- ============================================================
CREATE TABLE student_analytics (
    id                  VARCHAR(36) PRIMARY KEY,
    student_id          VARCHAR(36) NOT NULL UNIQUE REFERENCES students(id),
    term_id             VARCHAR(36) REFERENCES terms(id),
    attendance_rate     DECIMAL(5,2),              -- % attendance this term
    gpa                 DECIMAL(5,2),              -- weighted avg marks
    performance_trend   ENUM('improving','stable','declining'),
    absenteeism_flag    TINYINT(1) DEFAULT 0,      -- rate < 85%
    subject_weakness_count TINYINT DEFAULT 0,
    risk_level          ENUM('low','moderate','high') DEFAULT 'low',
    risk_score          DECIMAL(5,4),              -- 0.0000 to 1.0000
    last_calculated     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX idx_attendance_student   ON attendance_records(student_id);
CREATE INDEX idx_attendance_session   ON attendance_records(session_id);
CREATE INDEX idx_marks_student        ON marks(student_id);
CREATE INDEX idx_marks_assessment     ON marks(assessment_id);
CREATE INDEX idx_students_class       ON students(class_id);
CREATE INDEX idx_sessions_class_date  ON attendance_sessions(class_id, session_date);
CREATE INDEX idx_notifications_student ON notifications(student_id);
