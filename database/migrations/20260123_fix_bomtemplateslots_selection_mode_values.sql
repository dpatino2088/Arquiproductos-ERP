-- Fix invalid selection_mode values in BOMTemplateSlots
-- Align with constraint: ('user_select', 'fixed', 'none_allowed')

BEGIN;

UPDATE public."BOMTemplateSlots"
SET selection_mode = CASE
  WHEN fixed_catalog_item_id IS NOT NULL THEN 'fixed'
  ELSE 'user_select'
END
WHERE selection_mode IS NULL
   OR selection_mode NOT IN ('user_select', 'fixed', 'none_allowed');

COMMIT;
