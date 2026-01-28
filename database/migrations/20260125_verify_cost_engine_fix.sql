-- ====================================================
-- VERIFICACIÓN: CostEngine después del fix
-- Date: 2026-01-25
-- Description: Verifica que las correcciones se aplicaron correctamente
-- ====================================================

-- ====================================================
-- 1. Verificar que las funciones existen
-- ====================================================
DO $$
BEGIN
  RAISE NOTICE '=== VERIFICACIÓN: Funciones ===';
  
  -- Verificar funciones principales
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'msrp_compute_for_item') THEN
    RAISE NOTICE '✅ msrp_compute_for_item existe';
  ELSE
    RAISE NOTICE '❌ msrp_compute_for_item NO existe';
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_import_tax_pct_for_category') THEN
    RAISE NOTICE '✅ get_import_tax_pct_for_category existe';
  ELSE
    RAISE NOTICE '❌ get_import_tax_pct_for_category NO existe';
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_category_margins_for_category') THEN
    RAISE NOTICE '✅ get_category_margins_for_category existe';
  ELSE
    RAISE NOTICE '❌ get_category_margins_for_category NO existe';
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'msrp_recompute_for_category') THEN
    RAISE NOTICE '✅ msrp_recompute_for_category existe';
  ELSE
    RAISE NOTICE '❌ msrp_recompute_for_category NO existe';
  END IF;
END $$;

-- ====================================================
-- 2. Verificar que los triggers existen
-- ====================================================
DO $$
BEGIN
  RAISE NOTICE '=== VERIFICACIÓN: Triggers ===';
  
  IF EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'trg_recompute_msrp_on_catalog_item_change'
  ) THEN
    RAISE NOTICE '✅ Trigger trg_recompute_msrp_on_catalog_item_change existe';
  ELSE
    RAISE NOTICE '❌ Trigger trg_recompute_msrp_on_catalog_item_change NO existe';
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'trg_recompute_msrp_on_import_tax_change'
  ) THEN
    RAISE NOTICE '✅ Trigger trg_recompute_msrp_on_import_tax_change existe';
  ELSE
    RAISE NOTICE '❌ Trigger trg_recompute_msrp_on_import_tax_change NO existe';
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'trg_recompute_msrp_on_category_margin_change'
  ) THEN
    RAISE NOTICE '✅ Trigger trg_recompute_msrp_on_category_margin_change existe';
  ELSE
    RAISE NOTICE '❌ Trigger trg_recompute_msrp_on_category_margin_change NO existe';
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'trg_recompute_msrp_on_cost_settings_change'
  ) THEN
    RAISE NOTICE '✅ Trigger trg_recompute_msrp_on_cost_settings_change existe';
  ELSE
    RAISE NOTICE '❌ Trigger trg_recompute_msrp_on_cost_settings_change NO existe';
  END IF;
END $$;

-- ====================================================
-- 3. Verificar fórmula de import_tax_cost
-- ====================================================
DO $$
DECLARE
  v_item RECORD;
  v_cost_exw numeric;
  v_shipping_pct numeric;
  v_import_tax_pct numeric;
  v_shipping_cost numeric;
  v_import_tax_cost_expected numeric;
  v_import_tax_cost_actual numeric;
  v_difference numeric;
BEGIN
  RAISE NOTICE '=== VERIFICACIÓN: Fórmula import_tax_cost ===';
  
  -- Obtener un item de ejemplo con valores
  SELECT 
    ci.id,
    ci.cost_exw,
    cs.shipping_pct,
    COALESCE(itr.import_tax_pct, cs.global_import_tax_pct, 0) as import_tax_pct,
    cim.shipping_cost,
    cim.import_tax_cost
  INTO v_item
  FROM public."CatalogItems" ci
  JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = ci.id
  LEFT JOIN public."CostSettings" cs ON cs.organization_id = ci.organization_id
  LEFT JOIN public."ImportTaxRules" itr ON itr.organization_id = ci.organization_id 
    AND itr.category_id = ci.category_id 
    AND COALESCE(itr.is_active, true) = true
  WHERE ci.cost_exw > 0
    AND cim.shipping_cost > 0
    AND cim.import_tax_cost > 0
  LIMIT 1;
  
  IF v_item IS NULL THEN
    RAISE NOTICE '⚠️ No se encontró item con shipping_cost e import_tax_cost > 0 para verificar';
    RETURN;
  END IF;
  
  -- Calcular según fórmula corregida: import_tax_cost = (cost_exw + shipping_cost) * import_tax_pct
  v_cost_exw := v_item.cost_exw;
  v_shipping_pct := COALESCE(v_item.shipping_pct, 0);
  v_import_tax_pct := COALESCE(v_item.import_tax_pct, 0);
  v_shipping_cost := v_item.shipping_cost;
  v_import_tax_cost_expected := (v_cost_exw + v_shipping_cost) * v_import_tax_pct;
  v_import_tax_cost_actual := v_item.import_tax_cost;
  v_difference := ABS(v_import_tax_cost_expected - v_import_tax_cost_actual);
  
  RAISE NOTICE 'Item ID: %', v_item.id;
  RAISE NOTICE 'Cost EXW: %', v_cost_exw;
  RAISE NOTICE 'Shipping Cost: %', v_shipping_cost;
  RAISE NOTICE 'Import Tax Pct: %', v_import_tax_pct;
  RAISE NOTICE 'Import Tax Cost (esperado): %', v_import_tax_cost_expected;
  RAISE NOTICE 'Import Tax Cost (actual): %', v_import_tax_cost_actual;
  RAISE NOTICE 'Diferencia: %', v_difference;
  
  IF v_difference < 0.01 THEN
    RAISE NOTICE '✅ Fórmula de import_tax_cost es CORRECTA';
  ELSE
    RAISE NOTICE '❌ Fórmula de import_tax_cost puede estar INCORRECTA (diferencia > 0.01)';
  END IF;
END $$;

-- ====================================================
-- 4. Verificar fórmula de msrp_sale_out
-- ====================================================
DO $$
DECLARE
  v_item RECORD;
  v_total_cost numeric;
  v_msrp_pct_sale_out numeric;
  v_msrp_sale_out_expected numeric;
  v_msrp_sale_out_actual numeric;
  v_difference numeric;
BEGIN
  RAISE NOTICE '=== VERIFICACIÓN: Fórmula msrp_sale_out ===';
  
  -- Obtener un item de ejemplo
  SELECT 
    ci.id,
    cim.total_cost,
    COALESCE(cm.msrp_pct_sale_out, cs.default_msrp_pct_sale_out, 0.65) as msrp_pct_sale_out,
    cim.msrp_sale_out
  INTO v_item
  FROM public."CatalogItems" ci
  JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = ci.id
  LEFT JOIN public."CostSettings" cs ON cs.organization_id = ci.organization_id
  LEFT JOIN public."CategoryMargins" cm ON cm.organization_id = ci.organization_id 
    AND cm.category_id = ci.category_id
    AND COALESCE(cm.is_active, true) = true
  WHERE ci.cost_exw > 0
    AND cim.total_cost > 0
    AND cim.msrp_sale_out > 0
  LIMIT 1;
  
  IF v_item IS NULL THEN
    RAISE NOTICE '⚠️ No se encontró item con total_cost y msrp_sale_out > 0 para verificar';
    RETURN;
  END IF;
  
  -- Calcular según fórmula corregida: msrp_sale_out = total_cost / (1 - msrp_pct_sale_out)
  v_total_cost := v_item.total_cost;
  v_msrp_pct_sale_out := COALESCE(v_item.msrp_pct_sale_out, 0.65);
  v_msrp_sale_out_expected := v_total_cost / (1 - v_msrp_pct_sale_out);
  v_msrp_sale_out_actual := v_item.msrp_sale_out;
  v_difference := ABS(v_msrp_sale_out_expected - v_msrp_sale_out_actual);
  
  RAISE NOTICE 'Item ID: %', v_item.id;
  RAISE NOTICE 'Total Cost: %', v_total_cost;
  RAISE NOTICE 'MSRP Pct Sale Out: %', v_msrp_pct_sale_out;
  RAISE NOTICE 'MSRP Sale Out (esperado): %', v_msrp_sale_out_expected;
  RAISE NOTICE 'MSRP Sale Out (actual): %', v_msrp_sale_out_actual;
  RAISE NOTICE 'Diferencia: %', v_difference;
  
  IF v_difference < 0.01 THEN
    RAISE NOTICE '✅ Fórmula de msrp_sale_out es CORRECTA';
  ELSE
    RAISE NOTICE '❌ Fórmula de msrp_sale_out puede estar INCORRECTA (diferencia > 0.01)';
  END IF;
END $$;

-- ====================================================
-- 5. Estadísticas generales
-- ====================================================
DO $$
DECLARE
  v_total_items integer;
  v_items_with_msrp integer;
  v_items_with_zero_import_tax integer;
  v_items_with_zero_shipping integer;
  v_items_with_zero_msrp_out integer;
BEGIN
  RAISE NOTICE '=== ESTADÍSTICAS GENERALES ===';
  
  SELECT COUNT(*) INTO v_total_items
  FROM public."CatalogItems"
  WHERE cost_exw > 0;
  
  SELECT COUNT(*) INTO v_items_with_msrp
  FROM public."CatalogItems" ci
  JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = ci.id
  WHERE ci.cost_exw > 0;
  
  SELECT COUNT(*) INTO v_items_with_zero_import_tax
  FROM public."CatalogItemsMSRP"
  WHERE COALESCE(import_tax_cost, 0) = 0;
  
  SELECT COUNT(*) INTO v_items_with_zero_shipping
  FROM public."CatalogItemsMSRP"
  WHERE COALESCE(shipping_cost, 0) = 0;
  
  SELECT COUNT(*) INTO v_items_with_zero_msrp_out
  FROM public."CatalogItemsMSRP"
  WHERE COALESCE(msrp_sale_out, 0) = 0;
  
  RAISE NOTICE 'Total CatalogItems (cost_exw > 0): %', v_total_items;
  RAISE NOTICE 'Items con MSRP calculado: %', v_items_with_msrp;
  RAISE NOTICE 'Items con import_tax_cost = 0: %', v_items_with_zero_import_tax;
  RAISE NOTICE 'Items con shipping_cost = 0: %', v_items_with_zero_shipping;
  RAISE NOTICE 'Items con msrp_sale_out = 0: %', v_items_with_zero_msrp_out;
  
  IF v_items_with_msrp = v_total_items THEN
    RAISE NOTICE '✅ Todos los items tienen MSRP calculado';
  ELSE
    RAISE NOTICE '⚠️ Faltan % items por calcular MSRP', (v_total_items - v_items_with_msrp);
  END IF;
END $$;
