-- ====================================================
-- Migration: Añadir material_cost a CatalogItemsMSRP
-- Date: 2026-02-01
-- ====================================================
-- Fixes: "column material_cost of relation CatalogItemsMSRP does not exist"
--
-- En CatalogItemsMSRP, material_cost = coste base del ítem = cost_exw (Ex Works).
-- Es el mismo valor que cost_exw; se añade por compatibilidad con la UI/consultas
-- que esperan material_cost. Backfill desde cost_exw y msrp_compute_for_item.
--
-- Requiere: 20260133 (msrp_compute_for_item escribe msrp_pct_sale_out, etc.).
-- ====================================================

-- 1) Añadir columna
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'CatalogItemsMSRP' AND column_name = 'material_cost'
  ) THEN
    ALTER TABLE public."CatalogItemsMSRP" ADD COLUMN material_cost numeric(12,4);
    RAISE NOTICE '✅ CatalogItemsMSRP: columna material_cost añadida';
  END IF;
END $$;

-- 2) Backfill: material_cost = cost_exw (mismo concepto: coste base/material)
UPDATE public."CatalogItemsMSRP"
SET material_cost = cost_exw
WHERE material_cost IS DISTINCT FROM cost_exw;

-- 3) msrp_compute_for_item: incluir material_cost en INSERT y ON CONFLICT (= cost_exw)
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
  FROM public."CatalogItems" WHERE id = item_id;

  IF v_org_id IS NULL THEN RETURN; END IF;

  v_ship_pct := 0; v_tax_pct := 0; v_sale_in_pct := 0.35; v_sale_out_pct := 0.65;

  SELECT COALESCE(shipping_pct, 0) INTO v_ship_pct FROM public."CostSettings" WHERE organization_id = v_org_id;
  v_ship_pct := COALESCE(v_ship_pct, 0);

  SELECT COALESCE(global_import_tax_pct, 0) INTO v_tax_pct FROM public."CostSettings" WHERE organization_id = v_org_id;
  v_tax_pct := COALESCE(v_tax_pct, 0);

  IF v_cat_id IS NOT NULL THEN
    v_tax_pct := public.get_import_tax_pct_for_category(v_org_id, v_cat_id, v_tax_pct);
  END IF;

  IF v_cat_id IS NOT NULL THEN
    SELECT msrp_pct_sale_in, msrp_pct_sale_out INTO v_sale_in_pct, v_sale_out_pct
    FROM public.get_category_margins_for_category(v_org_id, v_cat_id);
  END IF;

  IF v_sale_in_pct IS NULL THEN
    SELECT COALESCE(minimum_margin_pct, 0.35) INTO v_sale_in_pct FROM public."CostSettings" WHERE organization_id = v_org_id;
  END IF;

  IF v_sale_out_pct IS NULL THEN
    SELECT COALESCE(default_msrp_pct_sale_out, 0.65) INTO v_sale_out_pct FROM public."CostSettings" WHERE organization_id = v_org_id;
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

  v_tax_cost := COALESCE(v_tax_cost, 0); v_ship_cost := COALESCE(v_ship_cost, 0);
  v_total := COALESCE(v_total, 0); v_sale_in := COALESCE(v_sale_in, 0); v_sale_out := COALESCE(v_sale_out, 0);

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id, cost_exw,
    import_tax_cost, shipping_cost, total_cost,
    msrp_sale_in, msrp_sale_out,
    shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct_sale_out,
    material_cost
  ) VALUES (
    item_id, v_org_id, v_cat_id, COALESCE(v_cost, 0),
    v_tax_cost, v_ship_cost, v_total,
    v_sale_in, v_sale_out,
    v_ship_pct, v_tax_pct, v_sale_in_pct, v_sale_out_pct,
    COALESCE(v_cost, 0)
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
    import_tax_pct = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct,
    msrp_pct_sale_out = EXCLUDED.msrp_pct_sale_out,
    material_cost = EXCLUDED.material_cost;
END;
$$;

COMMENT ON FUNCTION "public"."msrp_compute_for_item"("item_id" "uuid") IS 
'Calcula MSRP para un CatalogItem. Guarda material_cost (=cost_exw), shipping_pct, import_tax_pct, minimum_margin_pct y msrp_pct_sale_out en CatalogItemsMSRP.';
