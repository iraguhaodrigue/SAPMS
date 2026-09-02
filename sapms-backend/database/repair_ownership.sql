-- ═══════════════════════════════════════════════════════════════════
-- SAPMS Ownership Repair
-- Fixes the root cause of "Class not found in your school" by removing
-- cross-school class_subjects assignments (a teacher assigned to a class
-- in a school they don't belong to). This does NOT bypass authorization —
-- it corrects the invalid ownership relationship so the (correct) auth
-- check passes for legitimately-owned classes.
--
-- SAFE: only deletes assignments where teacher.school_id <> class.school_id.
-- Run diagnose_ownership.sql FIRST to see what will be affected.
-- ═══════════════════════════════════════════════════════════════════

-- Option A (recommended): remove the invalid cross-school assignments.
-- The teacher keeps all assignments that ARE in their own school.
DELETE cs FROM class_subjects cs
JOIN users   u ON u.id = cs.teacher_id
JOIN classes c ON c.id = cs.class_id
WHERE u.school_id <> c.school_id;

SELECT ROW_COUNT() AS cross_school_assignments_removed;

-- After this, verify zero mismatches remain:
SELECT COUNT(*) AS remaining_mismatches
FROM class_subjects cs
JOIN users   u ON u.id = cs.teacher_id
JOIN classes c ON c.id = cs.class_id
WHERE u.school_id <> c.school_id;
