-- Revert the qty-doubling that was applied to children of RC3051-W (Headbox)
-- in migration 20261217100000. Those children had qty=2 set intentionally
-- by the engineer (meaning "2 units per parent"). The implicit ×2 from the
-- old `per_side` scope was a bug, not a design intent — so doubling qty when
-- migrating to per_item ended up over-counting (`delta × 4` instead of
-- `delta × 2`). Restore qty=2 so the new model `total = delta × qty` matches
-- the user-facing intent: 2mm × 2 units = 4mm per child.
--
-- Brackets (P01WH parent rows) are intentionally left at qty=2 because that
-- correctly represents "2 brackets per shade" — that contribution feeds the
-- side_channel cut total of 200mm (100mm × 2) which the user explicitly
-- confirmed.

BEGIN;

UPDATE public."BOMComponents"
   SET qty_value = 2,
       updated_at = now()
 WHERE id IN (
     'ddc5d65c-ed25-478c-84b5-41c17e5d9621',  -- RC3025 child of headbox
     '40d936a7-b34b-4e3e-b9ca-755cd86319d6'   -- RC3052-W child of headbox
   )
   AND qty_value = 4;

COMMIT;
