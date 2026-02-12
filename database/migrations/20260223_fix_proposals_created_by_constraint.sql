-- Fix existing Proposals rows that violate proposals_created_by_exactly_one_chk
-- (both created_by_user_id and created_by_portal_user_id are NULL).
-- Copy creator from the source Quote when the Quote has exactly one set.
BEGIN;

UPDATE public."Proposals" p
SET
  created_by_user_id = q.created_by_user_id,
  created_by_portal_user_id = q.created_by_portal_user_id
FROM public."Quotes" q
WHERE p.quote_id = q.id
  AND p.created_by_user_id IS NULL
  AND p.created_by_portal_user_id IS NULL
  AND (
    (q.created_by_user_id IS NOT NULL AND q.created_by_portal_user_id IS NULL)
    OR (q.created_by_user_id IS NULL AND q.created_by_portal_user_id IS NOT NULL)
  );

COMMIT;
