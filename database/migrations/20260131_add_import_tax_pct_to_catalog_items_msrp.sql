-- ====================================================
-- Migration: Añadir import_tax_pct a CatalogItemsMSRP
-- Date: 2026-01-31
-- ====================================================
-- Fixes: "column import_tax_pct of relation CatalogItemsMSRP does not exist"
--
-- import_tax_pct viene de ImportTaxRules (por categoría) o CostSettings.global_import_tax_pct.
-- Se añade a CatalogItemsMSRP, se rellena en backfill y en msrp_compute_for_item.
--
-- Requiere: 20260130_add_shipping_pct_to_catalog_items_msrp.sql (msrp_compute_for_item
-- escribe shipping_pct e import_tax_pct).
-- ====================================================

-- 1) Añadir columna
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'CatalogItemsMSRP' AND column_name = 'import_tax_pct'
  ) THEN
    ALTER TABLE public."CatalogItemsMSRP" ADD COLUMN import_tax_pct numeric(7,4);
    RAISE NOTICE '✅ CatalogItemsMSRP: columna import_tax_pct añadida';
  END IF;
END $$;

-- 2) Backfill: ImportTaxRules por (org, category) o CostSettings.global_import_tax_pct
UPDATE public."CatalogItemsMSRP" cim
SET import_tax_pct = COALESCE(
  (SELECT itr.import_tax_pct FROM public."ImportTaxRules" itr
   WHERE itr.organization_id = cim.organization_id AND itr.category_id = cim.category_id
   LIMIT 1),
  (SELECT cs.global_import_tax_pct FROM public."CostSettings" cs
   WHERE cs.organization_id = cim.organization_id
   LIMIT 1),
  0
);

-- 3) msrp_compute_for_item: incluir import_tax_pct y shipping_pct en INSERT y ON CONFLICT
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
  SELECT organization_id, category_id, COALESCE(cost_exw, 0)
    INTO v_org_id, v_cat_id, v_cost
  FROM public."CatalogItems"
  WHERE id = item_id;

  IF v_org_id IS NULL THEN RETURN; END IF;

  v_ship_pct := 0;
  v_tax_pct := 0;
  v_sale_in_pct := 0.35;
  v_sale_out_pct := 0.65;

  SELECT COALESCE(shipping_pct, 0) INTO v_ship_pct
  FROM public."CostSettings" WHERE organization_id = v_org_id;
  v_ship_pct := COALESCE(v_ship_pct, 0);

  SELECT COALESCE(global_import_tax_pct, 0) INTO v_tax_pct
  FROM public."CostSettings" WHERE organization_id = v_org_id;
  v_tax_pct := COALESCE(v_tax_pct, 0);

  IF v_cat_id IS NOT NULL THEN
    v_tax_pct := public.get_import_tax_pct_for_category(v_org_id, v_cat_id, v_tax_pct);
  END IF;

  IF v_cat_id IS NOT NULL THEN
    SELECT msrp_pct_sale_in, msrp_pct_sale_out INTO v_sale_in_pct, v_sale_out_pct
    FROM public.get_category_margins_for_category(v_org_id, v_cat_id);
  END IF;

  IF v_sale_in_pct IS NULL THEN
    SELECT COALESCE(minimum_margin_pct, 0.35) INTO v_sale_in_pct
    FROM public."CostSettings" WHERE organization_id = v_org_id;
  END IF;

  IF v_sale_out_pct IS NULL THEN
    SELECT COALESCE(default_msrp_pct_sale_out, 0.65) INTO v_sale_out_pct
    FROM public."CostSettings" WHERE organization_id = v_org_id;
  END IF;

  v_sale_in_pct := COALESCE(v_sale_in_pct, 0.35);
  v_sale_out_pct := COALESCE(v_sale_out_pct, 0.65);

  v_ship_cost := COALESCE(v_cost, 0) * COALESCE(v_ship_pct, 0);
  v_tax_cost := (COALESCE(v_cost, 0) + COALESCE(v_ship_cost, 0)) * COALESCE(v_tax_pct, 0);
  v_total := COALESCE(v_cost, 0) + COALESCE(v_ship_cost, 0) + COALESCE(v_tax_cost, 0);

  IF (1 - COALESCE(v_sale_in_pct, 0.35)) <= 0 THEN v_sale_in_pct := 0.35; END IF;
  IF (1 - COALESCE(v_sale_out_pct, 0.65)) <= 0 THEN v_sale_out_pct := 0.65; END IF;

  v_sale_in := v_total / (1 - v_sale_in_pct);
  v_sale_out := v_total / (1 - v_sale_out_pct);

  v_tax_cost := COALESCE(v_tax_cost, 0);
  v_ship_cost := COALESCE(v_ship_cost, 0);
  v_total := COALESCE(v_total, 0);
  v_sale_in := COALESCE(v_sale_in, 0);
  v_sale_out := COALESCE(v_sale_out, 0);

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id, cost_exw,
    import_tax_cost, shipping_cost, total_cost,
    msrp_sale_in, msrp_sale_out,
    shipping_pct, import_tax_pct
  ) VALUES (
    item_id, v_org_id, v_cat_id, COALESCE(v_cost, 0),
    v_tax_cost, v_ship_cost, v_total,
    v_sale_in, v_sale_out,
    v_ship_pct, v_tax_pct
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    organization_id = EXCLUDED.organization_id,
    category_id = EXCLUDED.category_id,
    cost_exw = EXCLUDED.cost_exw,
    import_tax_cost = EXCLUDED.import_tax_cost,
    shipping_cost = EXCLUDED.shipping_cost,
    total_cost = EXCLUDED.total_cost,
    msrp_sale_in = EXCLUDED.msrp_sale_in,
    msrp_sale_out = EXCLUDED.msrp_sale_out,
    shipping_pct = EXCLUDED.shipping_pct,
    import_tax_pct = EXCLUDED.import_tax_pct;
END;
$$;

COMMENT ON FUNCTION "public"."msrp_compute_for_item"("item_id" "uuid") IS 
'Calcula MSRP para un CatalogItem. Guarda shipping_pct e import_tax_pct en CatalogItemsMSRP.
Fórmulas: shipping_cost = cost_exw * shipping_pct; import_tax_cost = (cost_exw + shipping_cost) * import_tax_pct;
total_cost = cost_exw + shipping_cost + import_tax_cost; msrp_sale_in/out = total_cost / (1 - margin_pct).';
