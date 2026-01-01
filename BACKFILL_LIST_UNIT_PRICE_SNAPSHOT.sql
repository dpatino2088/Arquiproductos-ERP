-- Backfill list_unit_price_snapshot from CatalogItems.msrp
-- This is a one-time data fix for existing QuoteLines

UPDATE "QuoteLines" ql
SET "list_unit_price_snapshot" = ci.msrp
FROM "CatalogItems" ci
WHERE ql.catalog_item_id = ci.id
  AND ci.msrp IS NOT NULL
  AND ci.msrp > 0
  AND (ql."list_unit_price_snapshot" IS NULL OR ql."list_unit_price_snapshot" = 0);

-- For lines where we can't get MSRP from CatalogItem, try to derive it from unit_price_snapshot and discount
-- If discount_pct_used exists, reverse-calculate the list price
UPDATE "QuoteLines" ql
SET "list_unit_price_snapshot" = ql."unit_price_snapshot" / (1 - COALESCE(ql."discount_pct_used", 0) / 100.0)
WHERE ql."list_unit_price_snapshot" IS NULL
  AND ql."unit_price_snapshot" > 0
  AND ql."discount_pct_used" > 0
  AND ql."discount_pct_used" < 100;

-- For lines without discount, assume unit_price_snapshot is the list price
UPDATE "QuoteLines" ql
SET "list_unit_price_snapshot" = ql."unit_price_snapshot"
WHERE ql."list_unit_price_snapshot" IS NULL
  AND ql."unit_price_snapshot" > 0
  AND (ql."discount_pct_used" IS NULL OR ql."discount_pct_used" = 0);

-- Report results
SELECT 
  COUNT(*) FILTER (WHERE "list_unit_price_snapshot" IS NOT NULL AND "list_unit_price_snapshot" > 0) AS updated_with_value,
  COUNT(*) FILTER (WHERE "list_unit_price_snapshot" IS NULL OR "list_unit_price_snapshot" = 0) AS still_null_or_zero,
  COUNT(*) AS total_lines
FROM "QuoteLines"
WHERE "deleted" = false;





