-- ═══════════════════════════════════════════════════════════════════
-- Assign a specific teacher to the correct school.
-- Use this if a self-registered teacher has NULL or wrong school_id but
-- SHOULD legitimately teach classes in a given school.
--
-- Replace the placeholders, then run.
-- ═══════════════════════════════════════════════════════════════════

-- Find the school_id you want (copy the id):
SELECT id, name, code FROM schools;

-- Then set the teacher's school to match the classes they teach.
-- Example — align teacher to the school of the classes they're assigned to:
UPDATE users u
JOIN (
  SELECT cs.teacher_id, c.school_id
  FROM class_subjects cs
  JOIN classes c ON c.id = cs.class_id
  GROUP BY cs.teacher_id
  HAVING COUNT(DISTINCT c.school_id) = 1   -- only if all their classes are in ONE school
) t ON t.teacher_id = u.id
SET u.school_id = t.school_id
WHERE u.role = 'teacher' AND (u.school_id IS NULL OR u.school_id <> t.school_id);

SELECT ROW_COUNT() AS teachers_realigned;
