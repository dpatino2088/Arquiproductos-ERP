-- ====================================================
-- DIAGNÓSTICO: CostEngine - Verificar configuración
-- Date: 2026-01-25
-- Description: Script para diagnosticar problemas en CostEngine
-- ====================================================

-- ====================================================
-- 1. Verificar CostSettings por organización
-- ====================================================
DO $$
DECLARE
  v_org_id uuid;
  v_settings RECORD;
BEGIN
  RAISE NOTICE '=== DIAGNÓSTICO: CostSettings ===';
  
  -- Obtener primera organización (o todas)
  FOR v_org_id IN 
    SELECT DISTINCT organization_id 
    FROM public."CatalogItems" 
    WHERE organization_id IS NOT NULL 
    LIMIT 5
  LOOP
    SELECT * INTO v_settings
    FROM public."CostSettings"
    WHERE organization_id = v_org_id;
    
    IF v_settings IS NULL THEN
      RAISE NOTICE '❌ Organización %: NO tiene CostSettings configurado', v_org_id;
    ELSE
      RAISE NOTICE '✅ Organización %: CostSettings encontrado', v_org_id;
      RAISE NOTICE '   - shipping_pct: %', v_settings.shipping_pct;
      RAISE NOTICE '   - global_import_tax_pct: %', v_settings.global_import_tax_pct;
      RAISE NOTICE '   - default_msrp_pct_sale_out: %', v_settings.default_msrp_pct_sale_out;
      RAISE NOTICE '   - minimum_margin_pct: %', v_settings.minimum_margin_pct;
    END IF;
  END LOOP;
END $$;

-- ====================================================
-- 2. Verificar ImportTaxRules por categoría
-- ====================================================
DO $$
DECLARE
  v_rule_count integer;
BEGIN
  SELECT COUNT(*) INTO v_rule_count
  FROM public."ImportTaxRules"
  WHERE COALESCE(is_active, true) = true;
  
  RAISE NOTICE '=== DIAGNÓSTICO: ImportTaxRules ===';
  RAISE NOTICE 'Reglas activas: %', v_rule_count;
  
  IF v_rule_count = 0 THEN
    RAISE NOTICE '⚠️ No hay reglas de import tax configuradas. Se usará global_import_tax_pct de CostSettings.';
  END IF;
END $$;

-- ====================================================
-- 3. Verificar CategoryMargins
-- ====================================================
DO $$
DECLARE
  v_margin_count integer;
BEGIN
  SELECT COUNT(*) INTO v_margin_count
  FROM public."CategoryMargins"
  WHERE is_active = true;
  
  RAISE NOTICE '=== DIAGNÓSTICO: CategoryMargins ===';
  RAISE NOTICE 'Márgenes activos: %', v_margin_count;
  
  IF v_margin_count = 0 THEN
    RAISE NOTICE '⚠️ No hay márgenes de categoría configurados. Se usará default_msrp_pct_sale_out de CostSettings.';
  END IF;
END $$;

-- ====================================================
-- 4. Verificar valores en CatalogItemsMSRP
-- ====================================================
DO $$
DECLARE
  v_zero_import_tax integer;
  v_zero_shipping integer;
  v_zero_msrp_out integer;
  v_total_items integer;
  v_pct_import_tax numeric;
  v_pct_shipping numeric;
  v_pct_msrp_out numeric;
BEGIN
  SELECT COUNT(*) INTO v_total_items FROM public."CatalogItemsMSRP";
  
  SELECT COUNT(*) INTO v_zero_import_tax
  FROM public."CatalogItemsMSRP"
  WHERE COALESCE(import_tax_cost, 0) = 0;
  
  SELECT COUNT(*) INTO v_zero_shipping
  FROM public."CatalogItemsMSRP"
  WHERE COALESCE(shipping_cost, 0) = 0;
  
  SELECT COUNT(*) INTO v_zero_msrp_out
  FROM public."CatalogItemsMSRP"
  WHERE COALESCE(msrp_sale_out, 0) = 0;
  
  -- Calcular porcentajes
  IF v_total_items > 0 THEN
    v_pct_import_tax := ROUND((v_zero_import_tax::numeric / v_total_items * 100), 1);
    v_pct_shipping := ROUND((v_zero_shipping::numeric / v_total_items * 100), 1);
    v_pct_msrp_out := ROUND((v_zero_msrp_out::numeric / v_total_items * 100), 1);
  ELSE
    v_pct_import_tax := 0;
    v_pct_shipping := 0;
    v_pct_msrp_out := 0;
  END IF;
  
  RAISE NOTICE '=== DIAGNÓSTICO: CatalogItemsMSRP ===';
  RAISE NOTICE 'Total items: %', v_total_items;
  RAISE NOTICE 'Items con import_tax_cost = 0: % (porcentaje: %)', v_zero_import_tax, v_pct_import_tax;
  RAISE NOTICE 'Items con shipping_cost = 0: % (porcentaje: %)', v_zero_shipping, v_pct_shipping;
  RAISE NOTICE 'Items con msrp_sale_out = 0: % (porcentaje: %)', v_zero_msrp_out, v_pct_msrp_out;
END $$;

-- ====================================================
-- 5. Ejemplo de cálculo para un item específico
-- ====================================================
DO $$
DECLARE
  v_item_id uuid;
  v_item RECORD;
  v_settings RECORD;
  v_margin RECORD;
  v_tax_rule RECORD;
  v_cost_exw numeric;
  v_tax_pct numeric;
  v_ship_pct numeric;
  v_sale_out_pct numeric;
  v_tax_cost numeric;
  v_ship_cost numeric;
  v_total_cost numeric;
  v_msrp_sale_out numeric;
  v_actual_msrp_sale_out numeric;
BEGIN
  -- Obtener un item de ejemplo
  SELECT id, organization_id, category_id, cost_exw
  INTO v_item
  FROM public."CatalogItems"
  WHERE cost_exw > 0
    AND organization_id IS NOT NULL
  LIMIT 1;
  
  IF v_item IS NULL THEN
    RAISE NOTICE '=== No hay items para ejemplo ===';
    RETURN;
  END IF;
  
  RAISE NOTICE '=== EJEMPLO DE CÁLCULO ===';
  RAISE NOTICE 'Item ID: %', v_item.id;
  RAISE NOTICE 'Cost EXW: %', v_item.cost_exw;
  
  -- Obtener CostSettings
  SELECT * INTO v_settings
  FROM public."CostSettings"
  WHERE organization_id = v_item.organization_id;
  
  IF v_settings IS NULL THEN
    RAISE NOTICE '❌ No hay CostSettings para esta organización';
    v_tax_pct := 0;
    v_ship_pct := 0;
    v_sale_out_pct := 0.65;
  ELSE
    v_tax_pct := COALESCE(v_settings.global_import_tax_pct, 0);
    v_ship_pct := COALESCE(v_settings.shipping_pct, 0);
    v_sale_out_pct := COALESCE(v_settings.default_msrp_pct_sale_out, 0.65);
    RAISE NOTICE 'CostSettings: tax_pct=%, ship_pct=%, sale_out_pct=%', v_tax_pct, v_ship_pct, v_sale_out_pct;
  END IF;
  
  -- Obtener ImportTaxRule si existe
  IF v_item.category_id IS NOT NULL THEN
    SELECT * INTO v_tax_rule
    FROM public."ImportTaxRules"
    WHERE organization_id = v_item.organization_id
      AND category_id = v_item.category_id
      AND COALESCE(is_active, true) = true
    LIMIT 1;
    
    IF v_tax_rule IS NOT NULL THEN
      v_tax_pct := COALESCE(v_tax_rule.import_tax_pct, v_tax_pct);
      RAISE NOTICE 'ImportTaxRule encontrado: tax_pct=%', v_tax_pct;
    END IF;
  END IF;
  
  -- Obtener CategoryMargin si existe
  IF v_item.category_id IS NOT NULL THEN
    SELECT * INTO v_margin
    FROM public."CategoryMargins"
    WHERE organization_id = v_item.organization_id
      AND category_id = v_item.category_id
    LIMIT 1;
    
    IF v_margin IS NOT NULL THEN
      v_sale_out_pct := COALESCE(v_margin.msrp_pct_sale_out, v_sale_out_pct);
      RAISE NOTICE 'CategoryMargin encontrado: sale_out_pct=%', v_sale_out_pct;
    END IF;
  END IF;
  
  -- Calcular
  v_cost_exw := COALESCE(v_item.cost_exw, 0);
  v_tax_cost := v_cost_exw * v_tax_pct;
  v_ship_cost := v_cost_exw * v_ship_pct;
  v_total_cost := v_cost_exw + v_tax_cost + v_ship_cost;
  
  -- Fórmula ACTUAL (posiblemente incorrecta)
  -- v_sale_out = v_sale_in / (1 - v_sale_out_pct)
  -- donde v_sale_in = v_total / (1 - v_sale_in_pct)
  -- Esto da: v_sale_out = (v_total / (1 - 0.35)) / (1 - 0.65) = v_total / 0.35
  
  -- Fórmula CORREGIDA (si sale_out es margen sobre costo total)
  v_msrp_sale_out := v_total_cost / (1 - v_sale_out_pct);
  
  -- Obtener valor actual en DB
  SELECT msrp_sale_out INTO v_actual_msrp_sale_out
  FROM public."CatalogItemsMSRP"
  WHERE catalog_item_id = v_item.id;
  
  RAISE NOTICE '--- Cálculo ---';
  RAISE NOTICE 'Cost EXW: %', v_cost_exw;
  RAISE NOTICE 'Import Tax (pct): % → Cost: %', v_tax_pct, v_tax_cost;
  RAISE NOTICE 'Shipping (pct): % → Cost: %', v_ship_pct, v_ship_cost;
  RAISE NOTICE 'Total Cost: %', v_total_cost;
  RAISE NOTICE 'MSRP Sale Out (pct): %', v_sale_out_pct;
  RAISE NOTICE 'MSRP Sale Out (calculado corregido): %', v_msrp_sale_out;
  RAISE NOTICE 'MSRP Sale Out (actual en DB): %', v_actual_msrp_sale_out;
  RAISE NOTICE 'Diferencia: %', v_msrp_sale_out - COALESCE(v_actual_msrp_sale_out, 0);
END $$;
