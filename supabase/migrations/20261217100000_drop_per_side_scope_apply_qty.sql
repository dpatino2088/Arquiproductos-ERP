-- Drop the implicit "per_side (×2)" behaviour from cut_delta_scope and let
-- qty_value carry the multiplier explicitly. The engineering popup will only
-- expose `per_item` going forward; existing rows that relied on the implicit
-- ×2 are migrated by doubling their qty_value so the RPC totals remain
-- identical:
--
--   parents:   total = (delta × 2) × qty   →   total = delta × (qty × 2)
--   children:  total =  delta × 2 × qty    →   total = delta × (qty × 2)
--
-- Both branches collapse to `delta × qty` once `cut_delta_scope` is normalized
-- to `per_item`, which is exactly the user-facing model:
--   delta × qty = total deduction, then placement_section decides the split.

BEGIN;

UPDATE public."BOMComponents"
   SET qty_value       = qty_value * 2,
       cut_delta_scope = 'per_item',
       updated_at      = now()
 WHERE deleted = false
   AND archived = false
   AND cut_delta_scope = 'per_side';

COMMIT;
