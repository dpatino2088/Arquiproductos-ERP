-- Optional code used for BOM template conditions (e.g. motor "EDU-100").
-- When condition_key = 'motor_item_id', preview compares condition_value to this
-- (or to sku if selection_code is null).
ALTER TABLE public."CatalogItems"
  ADD COLUMN IF NOT EXISTS selection_code text;

COMMENT ON COLUMN public."CatalogItems".selection_code IS
  'Optional code for configurator/BOM condition matching (e.g. EDU-100). If set, BOM condition_value is compared to this instead of item id.';
