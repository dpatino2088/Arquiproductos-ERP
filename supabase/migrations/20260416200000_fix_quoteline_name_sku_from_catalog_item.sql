-- Fix QuoteLine.name and QuoteLine.sku to match the actual CatalogItem
-- referenced by catalog_item_id. The edit path in QuoteNew.tsx was not
-- syncing these snapshot fields when the fabric was changed, causing the
-- old fabric's name/sku to persist while catalog_item_id, collection_name,
-- and variant_name pointed to the new fabric.

UPDATE "QuoteLines" ql
SET
  name = ci.name,
  sku  = ci.sku
FROM "CatalogItems" ci
WHERE ci.id = ql.catalog_item_id
  AND ql.product_type = 'roller'
  AND ql.name IS NOT NULL
  AND ci.name IS NOT NULL
  AND (ql.name IS DISTINCT FROM ci.name OR ql.sku IS DISTINCT FROM ci.sku);
