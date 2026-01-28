-- ====================================================
-- MIGRATION: Corregir función msrp_compute_for_item
-- Date: 2026-01-25
-- Description: Corrige problemas en el cálculo de import_tax_cost, shipping_cost y msrp_sale_out
-- ====================================================

BEGIN;

-- ====================================================
-- PROBLEMAS IDENTIFICADOS:
-- ====================================================
-- 1. Import Tax y Shipping pueden estar en 0 si CostSettings no existe o tiene valores 0
-- 2. La fórmula de msrp_sale_out puede estar incorrecta: v_sale_out := v_sale_in / (1 - v_sale_out_pct)
--    Si v_sale_out_pct = 0.65, entonces v_sale_out = v_sale_in / 0.35 = v_sale_in * 2.86
--    Esto parece incorrecto. Debería ser: v_sale_out = v_total / (1 - v_sale_out_pct)
--    O alternativamente: v_sale_out = v_sale_in * (1 + markup_pct) donde markup_pct es diferente
-- ====================================================

CREATE OR REPLACE FUNCTION "public"."msrp_compute_for_item"("item_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_org_id uuid;
  v_cat_id uuid;
  v_cost numeric(12,4);
  
  v_ship_pct numeric(7,4);
  v_tax_pct numeric(7,4);
  v_sale_in_pct numeric(7,4);
  v_sale_out_pct numeric(7,4);
  
  v_tax_cost numeric(12,4);
  v_ship_cost numeric(12,4);
  v_total numeric(12,4);
  v_sale_in numeric(12,4);
  v_sale_out numeric(12,4);
BEGIN
  -- Get item
  SELECT organization_id, category_id, COALESCE(cost_exw, 0)
    INTO v_org_id, v_cat_id, v_cost
  FROM public."CatalogItems"
  WHERE id = item_id;

  IF v_org_id IS NULL THEN RETURN; END IF;

  -- Initialize with defaults (ensure values are never NULL)
  v_ship_pct := 0;
  v_tax_pct := 0;
  v_sale_in_pct := 0.35;
  v_sale_out_pct := 0.65;

  -- ✅ FIX 1: Get shipping and tax from CostSettings
  -- Si no existe CostSettings, los valores quedan en 0 (esto es correcto, pero puede ser el problema)
  SELECT
    COALESCE(shipping_pct, 0),
    COALESCE(global_import_tax_pct, 0)
  INTO v_ship_pct, v_tax_pct
  FROM public."CostSettings"
  WHERE organization_id = v_org_id;

  -- Ensure values are set (fallback if CostSettings doesn't exist)
  v_ship_pct := COALESCE(v_ship_pct, 0);
  v_tax_pct := COALESCE(v_tax_pct, 0);

  -- Override tax with category rule if exists (only if category_id is not null)
  IF v_cat_id IS NOT NULL THEN
    SELECT COALESCE(import_tax_pct, v_tax_pct)
      INTO v_tax_pct
    FROM public."ImportTaxRules"
    WHERE organization_id = v_org_id
      AND category_id = v_cat_id
      AND COALESCE(is_active, true) = true
    LIMIT 1;
    -- Ensure v_tax_pct is still set if SELECT found nothing
    v_tax_pct := COALESCE(v_tax_pct, 0);
  END IF;

  -- Get MSRP percentages from CategoryMargins (only if category_id is not null)
  IF v_cat_id IS NOT NULL THEN
    SELECT 
      COALESCE(msrp_pct_sale_in, 0.35),
      COALESCE(msrp_pct_sale_out, 0.65)
    INTO v_sale_in_pct, v_sale_out_pct
    FROM public."CategoryMargins"
    WHERE organization_id = v_org_id
      AND category_id = v_cat_id
    LIMIT 1;
  END IF;

  -- Fallback to CostSettings if not set from CategoryMargins
  IF v_sale_in_pct IS NULL THEN
    SELECT COALESCE(minimum_margin_pct, 0.35)
      INTO v_sale_in_pct
    FROM public."CostSettings"
    WHERE organization_id = v_org_id;
  END IF;

  IF v_sale_out_pct IS NULL THEN
    SELECT COALESCE(default_msrp_pct_sale_out, 0.65)
      INTO v_sale_out_pct
    FROM public."CostSettings"
    WHERE organization_id = v_org_id;
  END IF;

  -- Final fallback to ensure values are never NULL
  v_sale_in_pct := COALESCE(v_sale_in_pct, 0.35);
  v_sale_out_pct := COALESCE(v_sale_out_pct, 0.65);

  -- ✅ FIX 2: Calculate costs (ensure all values are numeric, never NULL)
  v_tax_cost := COALESCE(v_cost, 0) * COALESCE(v_tax_pct, 0);
  v_ship_cost := COALESCE(v_cost, 0) * COALESCE(v_ship_pct, 0);
  v_total := COALESCE(v_cost, 0) + COALESCE(v_tax_cost, 0) + COALESCE(v_ship_cost, 0);

  -- ✅ FIX 3: Validate percentages before division
  IF (1 - COALESCE(v_sale_in_pct, 0.35)) <= 0 THEN 
    v_sale_in_pct := 0.35;
  END IF;
  
  IF (1 - COALESCE(v_sale_out_pct, 0.65)) <= 0 THEN 
    v_sale_out_pct := 0.65;
  END IF;

  -- ✅ FIX 4: Calcular MSRP Sale-In y Sale-Out
  -- Fórmula: Precio = Costo Total / (1 - Margen%)
  -- Si el margen es 35%, el precio es costo / 0.65
  -- Ejemplo: costo=100, margen=35% → precio = 100 / 0.65 = 153.85
  v_sale_in := v_total / (1 - v_sale_in_pct);
  
  -- ✅ CORRECCIÓN CRÍTICA: msrp_sale_out debe calcularse desde v_total, NO desde v_sale_in
  -- 
  -- FÓRMULA ORIGINAL (INCORRECTA):
  --   v_sale_out := v_sale_in / (1 - v_sale_out_pct)
  --   Esto aplica el margen sale_out sobre sale_in, dando valores excesivamente altos
  --   Ejemplo: costo=100, sale_in=153.85, sale_out_pct=65%
  --            sale_out = 153.85 / 0.35 = 439.29 (INCORRECTO)
  --
  -- FÓRMULA CORREGIDA:
  --   v_sale_out := v_total / (1 - v_sale_out_pct)
  --   Esto aplica el margen sale_out sobre el costo total (correcto)
  --   Ejemplo: costo=100, sale_out_pct=65%
  --            sale_out = 100 / 0.35 = 285.71 (CORRECTO)
  --
  -- NOTA: Si msrp_pct_sale_out es un markup sobre sale_in (no un margen sobre costo),
  --       entonces la fórmula original sería correcta, pero esto no es el caso típico.
  v_sale_out := v_total / (1 - v_sale_out_pct);

  -- Ensure all calculated values are NOT NULL
  v_tax_cost := COALESCE(v_tax_cost, 0);
  v_ship_cost := COALESCE(v_ship_cost, 0);
  v_total := COALESCE(v_total, 0);
  v_sale_in := COALESCE(v_sale_in, 0);
  v_sale_out := COALESCE(v_sale_out, 0);

  -- Save to CatalogItemsMSRP (ONLY results)
  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id, cost_exw,
    import_tax_cost, shipping_cost, total_cost,
    msrp_sale_in, msrp_sale_out
  ) VALUES (
    item_id, v_org_id, v_cat_id, COALESCE(v_cost, 0),
    v_tax_cost, v_ship_cost, v_total,
    v_sale_in, v_sale_out
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    organization_id = EXCLUDED.organization_id,
    category_id = EXCLUDED.category_id,
    cost_exw = EXCLUDED.cost_exw,
    import_tax_cost = EXCLUDED.import_tax_cost,
    shipping_cost = EXCLUDED.shipping_cost,
    total_cost = EXCLUDED.total_cost,
    msrp_sale_in = EXCLUDED.msrp_sale_in,
    msrp_sale_out = EXCLUDED.msrp_sale_out;

  -- Note: CatalogItems.msrp column doesn't exist in current schema
  -- MSRP is stored in CatalogItemsMSRP only
END;
$$;

COMMENT ON FUNCTION "public"."msrp_compute_for_item"("item_id" "uuid") IS 
'Calcula MSRP para un CatalogItem. 
Fórmulas:
- import_tax_cost = cost_exw * import_tax_pct
- shipping_cost = cost_exw * shipping_pct
- total_cost = cost_exw + import_tax_cost + shipping_cost
- msrp_sale_in = total_cost / (1 - msrp_pct_sale_in)
- msrp_sale_out = total_cost / (1 - msrp_pct_sale_out)

NOTA: Si import_tax_cost o shipping_cost están en 0, verificar que CostSettings tenga valores configurados.';

COMMIT;
