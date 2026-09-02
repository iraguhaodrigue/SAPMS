-- ============================================================
-- SAPMS Seed Data — Sample/Demo Data Only
-- Matches 6 schools described in proposal Table 3.2
-- All student names are fictional
-- ============================================================
USE sapms_db;

-- ============================================================
-- SCHOOLS (from Table 3.2 in proposal)
-- ============================================================
INSERT INTO schools VALUES
('sch-ns01','NS-01','Kagano Secondary School','lakeshore','Kagano','public',0,'good',NOW()),
('sch-ns02','NS-02','Cyato Secondary School','highland','Cyato','public',1,'poor',NOW()),
('sch-ns03','NS-03','Bushekeri Secondary School','intermediate','Bushekeri','government-aided',0,'intermittent',NOW()),
('sch-ns04','NS-04','Rangiro Private School','lakeshore','Rangiro','private',0,'good',NOW()),
('sch-ns05','NS-05','Kibogora Secondary School','highland','Kibogora','public',0,'intermittent',NOW()),
('sch-ns06','NS-06','Shangi Secondary School','intermediate','Shangi','government-aided',1,'poor',NOW());

-- ============================================================
-- ACADEMIC YEAR & TERMS
-- ============================================================
INSERT INTO academic_years VALUES
('ay-2024','2024-2025',1,NOW());

INSERT INTO terms VALUES
('term-1','ay-2024',1,'2025-01-20','2025-04-11',0,NOW()),
('term-2','ay-2024',2,'2025-05-05','2025-08-01',1,NOW()),
('term-3','ay-2024',3,'2025-09-01','2025-11-28',0,NOW());

-- ============================================================
-- SUBJECTS (REB curriculum, S4 level)
-- ============================================================
INSERT INTO subjects VALUES
('sub-math','MATH-S4','Mathematics','S4',NOW()),
('sub-eng','ENG-S4','English Language','S4',NOW()),
('sub-bio','BIO-S4','Biology','S4',NOW()),
('sub-chem','CHEM-S4','Chemistry','S4',NOW()),
('sub-phys','PHYS-S4','Physics','S4',NOW()),
('sub-hist','HIST-S4','History','S4',NOW()),
('sub-geo','GEO-S4','Geography','S4',NOW()),
('sub-ict','ICT-S4','ICT','S4',NOW()),
('sub-kiny','KINY-S4','Kinyarwanda','S4',NOW()),
('sub-eco','ECO-S4','Economics','S4',NOW()),
('sub-pe','PE-S4','Physical Education','S4',NOW());

-- ============================================================
-- USERS — System Admin
-- ============================================================
-- Password for all demo accounts: Sapms@2025
-- bcrypt hash of 'Sapms@2025'
SET @demo_pw = '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi';

INSERT INTO users VALUES
('usr-sysadmin',NULL,'System Administrator','sysadmin@sapms.rw','+250788000001',@demo_pw,'sysadmin',1,NOW(),NOW());

-- ============================================================
-- USERS — Admins (one per school)
-- ============================================================
INSERT INTO users VALUES
('usr-adm01','sch-ns01','Uwase Marie','admin.kagano@sapms.rw','+250788001001',@demo_pw,'admin',1,NOW(),NOW()),
('usr-adm02','sch-ns02','Nkurunziza Jean','admin.cyato@sapms.rw','+250788001002',@demo_pw,'admin',1,NOW(),NOW()),
('usr-adm03','sch-ns03','Mukamana Alice','admin.bushekeri@sapms.rw','+250788001003',@demo_pw,'admin',1,NOW(),NOW()),
('usr-adm04','sch-ns04','Habimana Eric','admin.rangiro@sapms.rw','+250788001004',@demo_pw,'admin',1,NOW(),NOW()),
('usr-adm05','sch-ns05','Uwimana Grace','admin.kibogora@sapms.rw','+250788001005',@demo_pw,'admin',1,NOW(),NOW()),
('usr-adm06','sch-ns06','Nshimiyimana Paul','admin.shangi@sapms.rw','+250788001006',@demo_pw,'admin',1,NOW(),NOW());

-- ============================================================
-- USERS — Teachers (NS-01 focus for demo)
-- ============================================================
INSERT INTO users VALUES
('usr-tch01','sch-ns01','Mugenzi Robert','teacher.math@sapms.rw','+250788002001',@demo_pw,'teacher',1,NOW(),NOW()),
('usr-tch02','sch-ns01','Nyirahabimana Claire','teacher.eng@sapms.rw','+250788002002',@demo_pw,'teacher',1,NOW(),NOW()),
('usr-tch03','sch-ns01','Hakizimana Denis','teacher.bio@sapms.rw','+250788002003',@demo_pw,'teacher',1,NOW(),NOW()),
('usr-tch04','sch-ns02','Uwizeyimana Solange','teacher.cyato.math@sapms.rw','+250788002004',@demo_pw,'teacher',1,NOW(),NOW()),
('usr-tch05','sch-ns05','Bizimana Faustin','teacher.kib.ict@sapms.rw','+250788002005',@demo_pw,'teacher',1,NOW(),NOW());

-- ============================================================
-- USERS — Parents
-- ============================================================
INSERT INTO users VALUES
('usr-par01','sch-ns01','Kamanzi Théophile','parent.kamanzi@sapms.rw','+250788003001',@demo_pw,'parent',1,NOW(),NOW()),
('usr-par02','sch-ns01','Mukagasana Vestine','parent.mukagasana@sapms.rw','+250788003002',@demo_pw,'parent',1,NOW(),NOW()),
('usr-par03','sch-ns01','Niyonzima Callixte','parent.niyonzima@sapms.rw','+250788003003',@demo_pw,'parent',1,NOW(),NOW()),
('usr-par04','sch-ns01','Uwimana Epiphanie','parent.uwimana@sapms.rw','+250788003004',@demo_pw,'parent',1,NOW(),NOW()),
('usr-par05','sch-ns01','Habimana Théodore','parent.habimana@sapms.rw','+250788003005',@demo_pw,'parent',1,NOW(),NOW());

-- ============================================================
-- CLASSES
-- ============================================================
INSERT INTO classes VALUES
('cls-ns01-s4a','sch-ns01','S4-A','S4','ay-2024',NOW()),
('cls-ns01-s4b','sch-ns01','S4-B','S4','ay-2024',NOW()),
('cls-ns02-s4a','sch-ns02','S4-A','S4','ay-2024',NOW()),
('cls-ns05-s4a','sch-ns05','S4-A','S4','ay-2024',NOW());

-- ============================================================
-- STUDENTS — NS-01 S4-A (20 students, realistic names)
-- ============================================================
INSERT INTO students (id,school_id,class_id,student_code,name,gender,date_of_birth,parent_id,qr_code_hash,is_active,created_at) VALUES
('stu-001','sch-ns01','cls-ns01-s4a','NS01-2024-001','Kamanzi Olivier','M','2008-03-12','usr-par01',SHA2('NS01-2024-001:sapms_salt_2025',256),1,NOW()),
('stu-002','sch-ns01','cls-ns01-s4a','NS01-2024-002','Mukagasana Clarisse','F','2008-07-22','usr-par02',SHA2('NS01-2024-002:sapms_salt_2025',256),1,NOW()),
('stu-003','sch-ns01','cls-ns01-s4a','NS01-2024-003','Niyonzima Patrick','M','2007-11-05','usr-par03',SHA2('NS01-2024-003:sapms_salt_2025',256),1,NOW()),
('stu-004','sch-ns01','cls-ns01-s4a','NS01-2024-004','Uwimana Sandrine','F','2008-01-30','usr-par04',SHA2('NS01-2024-004:sapms_salt_2025',256),1,NOW()),
('stu-005','sch-ns01','cls-ns01-s4a','NS01-2024-005','Habimana Christian','M','2007-09-14','usr-par05',SHA2('NS01-2024-005:sapms_salt_2025',256),1,NOW()),
('stu-006','sch-ns01','cls-ns01-s4a','NS01-2024-006','Nizeyimana Odette','F','2008-05-18',NULL,SHA2('NS01-2024-006:sapms_salt_2025',256),1,NOW()),
('stu-007','sch-ns01','cls-ns01-s4a','NS01-2024-007','Gatete Emmanuel','M','2007-12-03',NULL,SHA2('NS01-2024-007:sapms_salt_2025',256),1,NOW()),
('stu-008','sch-ns01','cls-ns01-s4a','NS01-2024-008','Mukamana Joselyne','F','2008-08-25',NULL,SHA2('NS01-2024-008:sapms_salt_2025',256),1,NOW()),
('stu-009','sch-ns01','cls-ns01-s4a','NS01-2024-009','Bizimana Thierry','M','2007-06-11',NULL,SHA2('NS01-2024-009:sapms_salt_2025',256),1,NOW()),
('stu-010','sch-ns01','cls-ns01-s4a','NS01-2024-010','Uwase Angélique','F','2008-02-07',NULL,SHA2('NS01-2024-010:sapms_salt_2025',256),1,NOW()),
('stu-011','sch-ns01','cls-ns01-s4a','NS01-2024-011','Nkurunziza Blaise','M','2007-04-19',NULL,SHA2('NS01-2024-011:sapms_salt_2025',256),1,NOW()),
('stu-012','sch-ns01','cls-ns01-s4a','NS01-2024-012','Mukansanga Diane','F','2008-10-31',NULL,SHA2('NS01-2024-012:sapms_salt_2025',256),1,NOW()),
('stu-013','sch-ns01','cls-ns01-s4a','NS01-2024-013','Nsengimana Fidèle','M','2007-08-16',NULL,SHA2('NS01-2024-013:sapms_salt_2025',256),1,NOW()),
('stu-014','sch-ns01','cls-ns01-s4a','NS01-2024-014','Ingabire Chantal','F','2008-04-23',NULL,SHA2('NS01-2024-014:sapms_salt_2025',256),1,NOW()),
('stu-015','sch-ns01','cls-ns01-s4a','NS01-2024-015','Hakizimana Léon','M','2007-07-09',NULL,SHA2('NS01-2024-015:sapms_salt_2025',256),1,NOW()),
('stu-016','sch-ns01','cls-ns01-s4a','NS01-2024-016','Nyirahabimana Solange','F','2008-09-14',NULL,SHA2('NS01-2024-016:sapms_salt_2025',256),1,NOW()),
('stu-017','sch-ns01','cls-ns01-s4a','NS01-2024-017','Habyarimana Jules','M','2007-03-28',NULL,SHA2('NS01-2024-017:sapms_salt_2025',256),1,NOW()),
('stu-018','sch-ns01','cls-ns01-s4a','NS01-2024-018','Uwimana Béatrice','F','2008-06-15',NULL,SHA2('NS01-2024-018:sapms_salt_2025',256),1,NOW()),
('stu-019','sch-ns01','cls-ns01-s4a','NS01-2024-019','Mugabo Alexis','M','2007-01-22',NULL,SHA2('NS01-2024-019:sapms_salt_2025',256),1,NOW()),
('stu-020','sch-ns01','cls-ns01-s4a','NS01-2024-020','Mutuyimana Claudine','F','2008-11-08',NULL,SHA2('NS01-2024-020:sapms_salt_2025',256),1,NOW());

-- ============================================================
-- CLASS-SUBJECT ASSIGNMENTS (NS-01 S4-A, Term 2)
-- ============================================================
INSERT INTO class_subjects VALUES
('cs-001','cls-ns01-s4a','sub-math','usr-tch01','term-2',NOW()),
('cs-002','cls-ns01-s4a','sub-eng','usr-tch02','term-2',NOW()),
('cs-003','cls-ns01-s4a','sub-bio','usr-tch03','term-2',NOW());

-- ============================================================
-- SAMPLE ASSESSMENTS
-- ============================================================
INSERT INTO assessments VALUES
('ass-001','cls-ns01-s4a','sub-math','usr-tch01','term-2','continuous','CAT 1 - Algebra',100,'2025-05-20',NOW()),
('ass-002','cls-ns01-s4a','sub-math','usr-tch01','term-2','continuous','CAT 2 - Geometry',100,'2025-06-10',NOW()),
('ass-003','cls-ns01-s4a','sub-math','usr-tch01','term-2','midterm','Midterm Exam',100,'2025-06-25',NOW()),
('ass-004','cls-ns01-s4a','sub-eng','usr-tch02','term-2','continuous','Essay Writing CAT 1',100,'2025-05-22',NOW()),
('ass-005','cls-ns01-s4a','sub-eng','usr-tch02','term-2','midterm','Midterm Exam',100,'2025-06-25',NOW()),
('ass-006','cls-ns01-s4a','sub-bio','usr-tch03','term-2','continuous','CAT 1 - Cell Biology',100,'2025-05-24',NOW());

-- ============================================================
-- SAMPLE MARKS (realistic spread — some at-risk students)
-- ============================================================
-- Mathematics marks (stu-003, stu-009 are low performers)
INSERT INTO marks (id,assessment_id,student_id,score,is_absent,synced,created_at) VALUES
('mk-001','ass-001','stu-001',72,0,1,NOW()),('mk-002','ass-001','stu-002',85,0,1,NOW()),
('mk-003','ass-001','stu-003',38,0,1,NOW()),('mk-004','ass-001','stu-004',91,0,1,NOW()),
('mk-005','ass-001','stu-005',67,0,1,NOW()),('mk-006','ass-001','stu-006',55,0,1,NOW()),
('mk-007','ass-001','stu-007',78,0,1,NOW()),('mk-008','ass-001','stu-008',82,0,1,NOW()),
('mk-009','ass-001','stu-009',29,0,1,NOW()),('mk-010','ass-001','stu-010',88,0,1,NOW()),
('mk-011','ass-002','stu-001',68,0,1,NOW()),('mk-012','ass-002','stu-002',79,0,1,NOW()),
('mk-013','ass-002','stu-003',41,0,1,NOW()),('mk-014','ass-002','stu-004',94,0,1,NOW()),
('mk-015','ass-002','stu-005',61,0,1,NOW()),('mk-016','ass-002','stu-006',58,0,1,NOW()),
('mk-017','ass-002','stu-007',74,0,1,NOW()),('mk-018','ass-002','stu-008',80,0,1,NOW()),
('mk-019','ass-002','stu-009',33,0,1,NOW()),('mk-020','ass-002','stu-010',91,0,1,NOW()),
-- English marks
('mk-021','ass-004','stu-001',65,0,1,NOW()),('mk-022','ass-004','stu-002',88,0,1,NOW()),
('mk-023','ass-004','stu-003',52,0,1,NOW()),('mk-024','ass-004','stu-004',76,0,1,NOW()),
('mk-025','ass-004','stu-005',43,0,1,NOW()),('mk-026','ass-004','stu-006',71,0,1,NOW()),
-- Biology marks
('mk-027','ass-006','stu-001',80,0,1,NOW()),('mk-028','ass-006','stu-002',75,0,1,NOW()),
('mk-029','ass-006','stu-003',31,0,1,NOW()),('mk-030','ass-006','stu-004',89,0,1,NOW()),
('mk-031','ass-006','stu-005',55,0,1,NOW()),('mk-032','ass-006','stu-006',66,0,1,NOW());

-- ============================================================
-- SAMPLE ATTENDANCE SESSION & RECORDS
-- ============================================================
INSERT INTO attendance_sessions VALUES
('sess-001','cls-ns01-s4a','sub-math','usr-tch01','term-2','2025-07-07',1,1,1,NOW()),
('sess-002','cls-ns01-s4a','sub-eng','usr-tch02','term-2','2025-07-07',2,1,1,NOW()),
('sess-003','cls-ns01-s4a','sub-math','usr-tch01','term-2','2025-07-08',1,1,1,NOW());

-- Session 1 attendance (stu-003 and stu-009 absent — at-risk pattern)
INSERT INTO attendance_records (id,session_id,student_id,status,scanned_at,notification_sent,synced,created_at) VALUES
('ar-001','sess-001','stu-001','present','2025-07-07 07:35:00',0,1,NOW()),
('ar-002','sess-001','stu-002','present','2025-07-07 07:36:00',0,1,NOW()),
('ar-003','sess-001','stu-003','absent',NULL,1,1,NOW()),
('ar-004','sess-001','stu-004','present','2025-07-07 07:37:00',0,1,NOW()),
('ar-005','sess-001','stu-005','late','2025-07-07 07:52:00',0,1,NOW()),
('ar-006','sess-001','stu-006','present','2025-07-07 07:36:00',0,1,NOW()),
('ar-007','sess-001','stu-007','present','2025-07-07 07:35:00',0,1,NOW()),
('ar-008','sess-001','stu-008','present','2025-07-07 07:38:00',0,1,NOW()),
('ar-009','sess-001','stu-009','absent',NULL,1,1,NOW()),
('ar-010','sess-001','stu-010','present','2025-07-07 07:36:00',0,1,NOW());

-- ============================================================
-- SAMPLE ANALYTICS (pre-calculated for demo)
-- ============================================================
INSERT INTO student_analytics VALUES
('ana-001','stu-001','term-2',82.5,71.7,'stable',0,0,'low',0.1200,NOW()),
('ana-002','stu-002','term-2',95.0,81.7,'improving',0,0,'low',0.0800,NOW()),
('ana-003','stu-003','term-2',61.5,40.3,'declining',1,2,'high',0.8700,NOW()),
('ana-004','stu-004','term-2',100.0,87.5,'improving',0,0,'low',0.0500,NOW()),
('ana-005','stu-005','term-2',72.0,55.0,'declining',0,1,'moderate',0.4900,NOW()),
('ana-006','stu-006','term-2',88.5,64.0,'stable',0,0,'low',0.2100,NOW()),
('ana-007','stu-007','term-2',90.0,76.0,'stable',0,0,'low',0.1500,NOW()),
('ana-008','stu-008','term-2',95.0,79.0,'stable',0,0,'low',0.1100,NOW()),
('ana-009','stu-009','term-2',55.0,31.0,'declining',1,3,'high',0.9200,NOW()),
('ana-010','stu-010','term-2',92.5,89.5,'improving',0,0,'low',0.0600,NOW());
