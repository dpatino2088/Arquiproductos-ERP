ALTER TABLE public."PurchaseOrderLines"
  ADD COLUMN IF NOT EXISTS is_roll_snapshot boolean NULL,
  ADD COLUMN IF NOT EXISTS roll_width_m_snapshot numeric NULL,
  ADD COLUMN IF NOT EXISTS roll_length_m_snapshot numeric NULL;

UPDATE public."PurchaseOrderLines" pol
SET
  is_roll_snapshot = COALESCE(pol.is_roll_snapshot, ci.is_roll, false),
  roll_width_m_snapshot = COALESCE(pol.roll_width_m_snapshot, ci.roll_width_m),
  roll_length_m_snapshot = COALESCE(pol.roll_length_m_snapshot, ci.roll_length_m)
FROM public."CatalogItems" ci
WHERE pol.catalog_item_id = ci.id;

UPDATE public."PurchaseOrderLines"
SET is_roll_snapshot = COALESCE(is_roll_snapshot, false)
WHERE is_roll_snapshot IS NULL;;
