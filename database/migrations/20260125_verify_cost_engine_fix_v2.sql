-- ====================================================
-- VERIFICACIÓN: CostEngine después del fix (VERSIÓN CON RESULTADOS VISIBLES)
-- Date: 2026-01-25
-- Description: Verifica que las correcciones se aplicaron correctamente
-- Esta versión muestra resultados en tablas para mejor visibilidad
-- ====================================================

-- ====================================================
-- 1. Verificar que las funciones existen
-- ====================================================
SELECT 
  'Funciones' as tipo,
  proname as nombre,
  CASE 
    WHEN proname = 'msrp_compute_for_item' THEN '✅ Principal'
    WHEN proname = 'get_import_tax_pct_for_category' THEN '✅ Jerarquía categorías'
    WHEN proname = 'get_category_margins_for_category' THEN '✅ Márgenes categorías'
    WHEN proname = 'msrp_recompute_for_category' THEN '✅ Recompute masivo'
    ELSE '✅'
  END as estado
FROM pg_proc
WHERE proname IN (
  'msrp_compute_for_item',
  'get_import_tax_pct_for_category',
  'get_category_margins_for_category',
  'msrp_recompute_for_category'
)
ORDER BY proname;

-- ====================================================
-- 2. Verificar que los triggers existen
-- ====================================================
SELECT 
  'Triggers' as tipo,
  tgname as nombre,
  CASE 
    WHEN tgname = 'trg_recompute_msrp_on_catalog_item_change' THEN '✅ CatalogItems'
    WHEN tgname = 'trg_recompute_msrp_on_import_tax_change' THEN '✅ ImportTaxRules'
    WHEN tgname = 'trg_recompute_msrp_on_category_margin_change' THEN '✅ CategoryMargins'
    WHEN tgname = 'trg_recompute_msrp_on_cost_settings_change' THEN '✅ CostSettings'
    ELSE '✅'
  END as estado,
  tgrelid::regclass as tabla
FROM pg_trigger
WHERE tgname IN (
  'trg_recompute_msrp_on_catalog_item_change',
  'trg_recompute_msrp_on_import_tax_change',
  'trg_recompute_msrp_on_category_margin_change',
  'trg_recompute_msrp_on_cost_settings_change'
)
ORDER BY tgname;

-- ====================================================
-- 3. Verificar fórmula de import_tax_cost (ejemplo)
-- ====================================================
SELECT 
  'Verificación Import Tax' as tipo,
  ci.sku,
  ci.cost_exw,
  COALESCE(cs.shipping_pct, 0) as shipping_pct,
  COALESCE(itr.import_tax_pct, cs.global_import_tax_pct, 0) as import_tax_pct,
  cim.shipping_cost as shipping_cost_actual,
  cim.import_tax_cost as import_tax_cost_actual,
  -- Fórmula esperada: (cost_exw + shipping_cost) * import_tax_pct
  (ci.cost_exw + cim.shipping_cost) * COALESCE(itr.import_tax_pct, cs.global_import_tax_pct, 0) as import_tax_cost_esperado,
  ABS(cim.import_tax_cost - ((ci.cost_exw + cim.shipping_cost) * COALESCE(itr.import_tax_pct, cs.global_import_tax_pct, 0))) as diferencia,
  CASE 
    WHEN ABS(cim.import_tax_cost - ((ci.cost_exw + cim.shipping_cost) * COALESCE(itr.import_tax_pct, cs.global_import_tax_pct, 0))) < 0.01 
    THEN '✅ CORRECTO'
    ELSE '❌ INCORRECTO'
  END as estado
FROM public."CatalogItems" ci
JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = ci.id
LEFT JOIN public."CostSettings" cs ON cs.organization_id = ci.organization_id
LEFT JOIN public."ImportTaxRules" itr ON itr.organization_id = ci.organization_id 
  AND itr.category_id = ci.category_id 
  AND COALESCE(itr.is_active, true) = true
WHERE ci.cost_exw > 0
  AND cim.shipping_cost > 0
  AND cim.import_tax_cost > 0
LIMIT 5;

-- ====================================================
-- 4. Verificar fórmula de msrp_sale_out (ejemplo)
-- ====================================================
SELECT 
  'Verificación MSRP Sale Out' as tipo,
  ci.sku,
  cim.total_cost,
  COALESCE(cm.msrp_pct_sale_out, cs.default_msrp_pct_sale_out, 0.65) as msrp_pct_sale_out,
  cim.msrp_sale_out as msrp_sale_out_actual,
  -- Fórmula esperada: total_cost / (1 - msrp_pct_sale_out)
  (cim.total_cost / (1 - COALESCE(cm.msrp_pct_sale_out, cs.default_msrp_pct_sale_out, 0.65))) as msrp_sale_out_esperado,
  ABS(cim.msrp_sale_out - (cim.total_cost / (1 - COALESCE(cm.msrp_pct_sale_out, cs.default_msrp_pct_sale_out, 0.65)))) as diferencia,
  CASE 
    WHEN ABS(cim.msrp_sale_out - (cim.total_cost / (1 - COALESCE(cm.msrp_pct_sale_out, cs.default_msrp_pct_sale_out, 0.65)))) < 0.01 
    THEN '✅ CORRECTO'
    ELSE '❌ INCORRECTO'
  END as estado
FROM public."CatalogItems" ci
JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = ci.id
LEFT JOIN public."CostSettings" cs ON cs.organization_id = ci.organization_id
LEFT JOIN public."CategoryMargins" cm ON cm.organization_id = ci.organization_id 
  AND cm.category_id = ci.category_id
  AND COALESCE(cm.is_active, true) = true
WHERE ci.cost_exw > 0
  AND cim.total_cost > 0
  AND cim.msrp_sale_out > 0
LIMIT 5;

-- ====================================================
-- 5. Estadísticas generales
-- ====================================================
SELECT 
  'Estadísticas' as tipo,
  (SELECT COUNT(*) FROM public."CatalogItems" WHERE cost_exw > 0) as total_items,
  (SELECT COUNT(*) 
   FROM public."CatalogItems" ci
   JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = ci.id
   WHERE ci.cost_exw > 0) as items_con_msrp,
  (SELECT COUNT(*) 
   FROM public."CatalogItemsMSRP"
   WHERE COALESCE(import_tax_cost, 0) = 0) as items_sin_import_tax,
  (SELECT COUNT(*) 
   FROM public."CatalogItemsMSRP"
   WHERE COALESCE(shipping_cost, 0) = 0) as items_sin_shipping,
  (SELECT COUNT(*) 
   FROM public."CatalogItemsMSRP"
   WHERE COALESCE(msrp_sale_out, 0) = 0) as items_sin_msrp_out,
  CASE 
    WHEN (SELECT COUNT(*) FROM public."CatalogItems" WHERE cost_exw > 0) = 
         (SELECT COUNT(*) FROM public."CatalogItems" ci JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = ci.id WHERE ci.cost_exw > 0)
    THEN '✅ Todos calculados'
    ELSE '⚠️ Faltan por calcular'
  END as estado_calculo;
