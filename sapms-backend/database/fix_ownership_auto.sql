-- ═══════════════════════════════════════════════════════════════════
-- SAPMS — Diagnose + Auto-Fix Ownership (safe, one-shot)
-- ═══════════════════════════════════════════════════════════════════

-- STEP 1 — show the problem before fixing
SELECT '=== BEFORE: mismatched assignments ===' AS step;
SELECT u.name AS teacher, u.email, u.school_id AS teacher_school,
       c.name AS class, c.school_id AS class_school
FROM class_subjects cs
JOIN users u   ON u.id = cs.teacher_id
JOIN classes c ON c.id = cs.class_id
WHERE u.school_id <> c.school_id OR u.school_id IS NULL;

-- STEP 2 — SAFE auto-fix: realign a teacher's school to their classes'
-- school, but ONLY when every class they teach is in exactly ONE school
-- (so there is no ambiguity about where they belong).
UPDATE users u
JOIN (
  SELECT cs.teacher_id, MIN(c.school_id) AS school_id
  FROM class_subjects cs
  JOIN classes c ON c.id = cs.class_id
  GROUP BY cs.teacher_id
  HAVING COUNT(DISTINCT c.school_id) = 1
) t ON t.teacher_id = u.id
SET u.school_id = t.school_id
WHERE u.role = 'teacher'
  AND (u.school_id IS NULL OR u.school_id <> t.school_id);

SELECT CONCAT('Teachers realigned: ', ROW_COUNT()) AS step2_result;

-- STEP 3 — verify: must be 0
SELECT '=== AFTER: remaining mismatches (must be 0) ===' AS step;
SELECT COUNT(*) AS remaining_mismatches
FROM class_subjects cs
JOIN users u   ON u.id = cs.teacher_id
JOIN classes c ON c.id = cs.class_id
WHERE u.school_id <> c.school_id;

-- STEP 4 — if any remain, they are AMBIGUOUS (teacher assigned across TWO
-- schools). List them so you can decide manually — these are true errors.
SELECT '=== AMBIGUOUS (teacher spans 2+ schools — fix manually) ===' AS step;
SELECT u.name, u.email, u.id AS teacher_id,
       COUNT(DISTINCT c.school_id) AS schools_spanned
FROM class_subjects cs
JOIN users u   ON u.id = cs.teacher_id
JOIN classes c ON c.id = cs.class_id
GROUP BY u.id
HAVING schools_spanned > 1;
