-- Script de Verificación: Precios en QuoteLines y CatalogItems
-- Ejecutar para identificar problemas de cálculo de precios

-- ============================================
-- 1. CatalogItems sin MSRP o con MSRP = 0
-- ============================================
SELECT 
  'CatalogItems sin MSRP' AS tipo_problema,
  ci.id,
  ci.sku,
  ci.collection_name,
  ci.variant_name,
  ci.cost_exw,
  ci.msrp,
  ci.default_margin_pct,
  ci.msrp_manual,
  ci.updated_at
FROM "CatalogItems" ci
WHERE ci."deleted" = false
  AND ("msrp" IS NULL OR "msrp" = 0)
  AND "cost_exw" > 0
ORDER BY ci."updated_at" DESC
LIMIT 50;

-- ============================================
-- 2. QuoteLines con precios 0 o muy bajos
-- ============================================
SELECT 
  'QuoteLines con precio 0 o muy bajo' AS tipo_problema,
  ql.id AS quote_line_id,
  q.quote_no,
  q.status AS quote_status,
  ql.catalog_item_id,
  ci.sku,
  ci.collection_name || ' - ' || ci.variant_name AS item_name,
  ci.cost_exw AS item_cost_exw,
  ci.msrp AS item_msrp,
  ql.unit_price_snapshot,
  ql.unit_cost_snapshot,
  ql.total_unit_cost_snapshot,
  ql.line_total,
  ql.computed_qty,
  ql.discount_pct_used,
  ql.customer_type_snapshot,
  ql.created_at
FROM "QuoteLines" ql
LEFT JOIN "Quotes" q ON q.id = ql.quote_id
LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
WHERE ql."deleted" = false
  AND (
    ql."unit_price_snapshot" = 0 
    OR ql."line_total" = 0
    OR ql."unit_price_snapshot" < 1  -- Precios muy bajos (sospechosos)
  )
ORDER BY ql."created_at" DESC
LIMIT 50;

-- ============================================
-- 3. Comparación: CatalogItem MSRP vs QuoteLine unit_price_snapshot
-- ============================================
SELECT 
  'Diferencia entre MSRP y unit_price_snapshot' AS tipo_problema,
  ci.id AS catalog_item_id,
  ci.sku,
  ci.msrp AS catalog_msrp,
  ql.unit_price_snapshot AS quote_line_price,
  (ci.msrp - ql.unit_price_snapshot) AS diferencia,
  COUNT(ql.id) AS num_quote_lines,
  ql.customer_type_snapshot,
  ql.discount_pct_used
FROM "CatalogItems" ci
JOIN "QuoteLines" ql ON ql.catalog_item_id = ci.id
WHERE ci."deleted" = false
  AND ql."deleted" = false
  AND ci.msrp > 0
  AND ql.unit_price_snapshot > 0
  AND ABS(ci.msrp - ql.unit_price_snapshot) > 0.01  -- Diferencias significativas
GROUP BY ci.id, ci.sku, ci.msrp, ql.unit_price_snapshot, ql.customer_type_snapshot, ql.discount_pct_used
ORDER BY diferencia DESC
LIMIT 50;

-- ============================================
-- 4. QuoteLines recientes con datos completos (para referencia)
-- ============================================
SELECT 
  'QuoteLines recientes (ejemplo de datos correctos)' AS tipo_problema,
  ql.id AS quote_line_id,
  q.quote_no,
  q.status AS quote_status,
  ci.sku,
  ci.cost_exw AS item_cost,
  ci.msrp AS item_msrp,
  ql.unit_price_snapshot,
  ql.total_unit_cost_snapshot,
  ql.line_total,
  ql.computed_qty,
  ql.discount_pct_used,
  ql.customer_type_snapshot,
  ql.price_basis,
  ql.created_at
FROM "QuoteLines" ql
LEFT JOIN "Quotes" q ON q.id = ql.quote_id
LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
WHERE ql."deleted" = false
  AND ql."unit_price_snapshot" > 0
  AND ql."line_total" > 0
ORDER BY ql."created_at" DESC
LIMIT 20;

-- ============================================
-- 5. Resumen estadístico
-- ============================================
SELECT 
  'Resumen estadístico' AS tipo_problema,
  COUNT(DISTINCT CASE WHEN ci.msrp IS NULL OR ci.msrp = 0 THEN ci.id END) AS items_sin_msrp,
  COUNT(DISTINCT ci.id) AS total_items_activos,
  COUNT(DISTINCT CASE WHEN ql.unit_price_snapshot = 0 OR ql.line_total = 0 THEN ql.id END) AS quote_lines_precio_0,
  COUNT(DISTINCT ql.id) AS total_quote_lines_activos,
  AVG(ql.unit_price_snapshot) AS precio_promedio_snapshot,
  AVG(ql.line_total) AS total_promedio_linea,
  MIN(ql.unit_price_snapshot) AS precio_minimo,
  MAX(ql.unit_price_snapshot) AS precio_maximo
FROM "CatalogItems" ci
LEFT JOIN "QuoteLines" ql ON ql.catalog_item_id = ci.id AND ql."deleted" = false
WHERE ci."deleted" = false;





