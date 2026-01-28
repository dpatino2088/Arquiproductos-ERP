-- ====================================================
-- FIX MSRP: Ensure all values are NOT NULL before INSERT
-- ====================================================
-- This fixes the error: "null value in column 'import_tax_cost' of relation 'CatalogItemsMSRP' violates not-null constraint"
-- ====================================================

CREATE OR REPLACE FUNCTION "public"."msrp_compute_for_item"("item_id" "uuid") 
RETURNS void
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

  -- Get shipping and tax from CostSettings
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

  -- Calculate (ensure all values are numeric, never NULL)
  v_tax_cost := COALESCE(v_cost, 0) * COALESCE(v_tax_pct, 0);
  v_ship_cost := COALESCE(v_cost, 0) * COALESCE(v_ship_pct, 0);
  v_total := COALESCE(v_cost, 0) + COALESCE(v_tax_cost, 0) + COALESCE(v_ship_cost, 0);

  -- Validate percentages before division
  IF (1 - COALESCE(v_sale_in_pct, 0.35)) <= 0 THEN 
    v_sale_in_pct := 0.35;
  END IF;
  
  IF (1 - COALESCE(v_sale_out_pct, 0.65)) <= 0 THEN 
    v_sale_out_pct := 0.65;
  END IF;

  v_sale_in := v_total / (1 - v_sale_in_pct);
  v_sale_out := v_sale_in / (1 - v_sale_out_pct);

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
