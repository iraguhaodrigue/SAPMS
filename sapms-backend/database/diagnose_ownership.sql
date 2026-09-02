-- ═══════════════════════════════════════════════════════════════════
-- SAPMS Ownership Diagnostic
-- Finds every place where a teacher's school_id does NOT match the
-- school_id of a class they are assigned to — the exact condition that
-- triggers "Class not found in your school".
-- ═══════════════════════════════════════════════════════════════════

-- 1. Teachers assigned to classes in a DIFFERENT school (the bug)
SELECT '=== MISMATCHED ASSIGNMENTS (root cause) ===' AS report;
SELECT cs.id            AS class_subject_id,
       u.id             AS teacher_id,
       u.name           AS teacher_name,
       u.email,
       u.school_id      AS teacher_school,
       c.id             AS class_id,
       c.name           AS class_name,
       c.school_id      AS class_school
FROM class_subjects cs
JOIN users   u ON u.id = cs.teacher_id
JOIN classes c ON c.id = cs.class_id
WHERE u.school_id <> c.school_id;

-- 2. Teachers with NULL school_id (self-registered without a school)
SELECT '=== TEACHERS WITH NO SCHOOL ===' AS report;
SELECT id, name, email, school_id, approval_status
FROM users
WHERE role = 'teacher' AND (school_id IS NULL OR school_id = '');

-- 3. Classes with NULL school_id (orphan classes)
SELECT '=== CLASSES WITH NO SCHOOL ===' AS report;
SELECT id, name, school_id FROM classes WHERE school_id IS NULL OR school_id = '';

-- 4. Summary: which school does each teacher belong to, and how many
--    of their assignments are cross-school
SELECT '=== PER-TEACHER ASSIGNMENT HEALTH ===' AS report;
SELECT u.name, u.email, u.school_id AS teacher_school,
       COUNT(cs.id) AS total_assignments,
       SUM(c.school_id <> u.school_id) AS cross_school_assignments
FROM users u
LEFT JOIN class_subjects cs ON cs.teacher_id = u.id
LEFT JOIN classes c ON c.id = cs.class_id
WHERE u.role = 'teacher'
GROUP BY u.id
HAVING total_assignments > 0
ORDER BY cross_school_assignments DESC;
