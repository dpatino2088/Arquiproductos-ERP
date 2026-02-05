-- ====================================================
-- MIGRATION: Fix MSRP calculation from Dealer Price
-- Date: 2026-02-02
--
-- Business rule (confirmed):
-- - Dealer Price = Total Cost / (1 - minimum_margin_pct)
-- - MSRP (Retail) = Dealer Price / (1 - msrp_pct_sale_out)
--
-- Current behavior in DB dump computes MSRP from Total Cost,
-- which makes MSRP too low vs Dealer when msrp_pct_sale_out = 0.65.
-- ====================================================

BEGIN;

CREATE OR REPLACE FUNCTION "public"."msrp_compute_for_item"("p_item_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_org_id uuid;
  v_category_id uuid;
  v_cost_exw numeric;

  v_shipping_pct numeric;
  v_import_tax_pct numeric;
  v_min_margin_pct numeric;
  v_msrp_pct_sale_in numeric;
  v_msrp_pct_sale_out numeric;

  v_material_cost numeric;
  v_shipping_cost numeric;
  v_import_tax_cost numeric;
  v_total_cost numeric;

  v_dealer_price numeric;
  v_msrp numeric;
BEGIN
  SELECT organization_id, category_id, COALESCE(cost_exw, 0)
    INTO v_org_id, v_category_id, v_cost_exw
  FROM public."CatalogItems"
  WHERE id = p_item_id;

  IF v_org_id IS NULL THEN
    RETURN;
  END IF;

  SELECT
    r.shipping_pct,
    r.import_tax_pct,
    r.minimum_margin_pct,
    r.msrp_pct_sale_in,
    r.msrp_pct_sale_out
  INTO
    v_shipping_pct,
    v_import_tax_pct,
    v_min_margin_pct,
    v_msrp_pct_sale_in,
    v_msrp_pct_sale_out
  FROM public.msrp_get_effective_rates(v_org_id, v_category_id) r;

  v_material_cost := COALESCE(v_cost_exw, 0);

  v_shipping_cost := round(v_material_cost * COALESCE(v_shipping_pct, 0), 6);
  v_import_tax_cost := round((v_material_cost + v_shipping_cost) * COALESCE(v_import_tax_pct, 0), 6);
  v_total_cost := round(v_material_cost + v_shipping_cost + v_import_tax_cost, 6);

  -- Dealer Price uses minimum margin (margin-on-sale from Total Cost)
  v_dealer_price := round(v_total_cost / NULLIF(1 - COALESCE(v_min_margin_pct, 0), 0), 6);

  -- MSRP uses margin-on-sale from Dealer Price (NOT from Total Cost)
  v_msrp := round(v_dealer_price / NULLIF(1 - COALESCE(v_msrp_pct_sale_out, 0), 0), 6);

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id,
    organization_id,
    category_id,

    cost_exw,

    shipping_pct,
    import_tax_pct,
    minimum_margin_pct,
    msrp_pct_sale_out,

    shipping_cost,
    import_tax_cost,
    total_cost,

    dealer_price,
    msrp,

    updated_at
  )
  VALUES (
    p_item_id,
    v_org_id,
    v_category_id,

    v_cost_exw,

    COALESCE(v_shipping_pct, 0),
    COALESCE(v_import_tax_pct, 0),
    COALESCE(v_min_margin_pct, 0),
    COALESCE(v_msrp_pct_sale_out, 0),

    COALESCE(v_shipping_cost, 0),
    COALESCE(v_import_tax_cost, 0),
    COALESCE(v_total_cost, 0),

    COALESCE(v_dealer_price, 0),
    COALESCE(v_msrp, 0),

    now()
  )
  ON CONFLICT (catalog_item_id)
  DO UPDATE SET
    organization_id = EXCLUDED.organization_id,
    category_id     = EXCLUDED.category_id,

    cost_exw        = EXCLUDED.cost_exw,

    shipping_pct        = EXCLUDED.shipping_pct,
    import_tax_pct      = EXCLUDED.import_tax_pct,
    minimum_margin_pct  = EXCLUDED.minimum_margin_pct,
    msrp_pct_sale_out   = EXCLUDED.msrp_pct_sale_out,

    shipping_cost   = EXCLUDED.shipping_cost,
    import_tax_cost = EXCLUDED.import_tax_cost,
    total_cost      = EXCLUDED.total_cost,

    dealer_price    = EXCLUDED.dealer_price,
    msrp            = EXCLUDED.msrp,

    updated_at      = now();
END;
$$;

COMMENT ON FUNCTION "public"."msrp_compute_for_item"("p_item_id" "uuid") IS
'Calcula MSRP para un CatalogItem.

Regla:
- total_cost = cost_exw + shipping_cost + import_tax_cost
- dealer_price = total_cost / (1 - minimum_margin_pct)
- msrp = dealer_price / (1 - msrp_pct_sale_out)

Nota: msrp_pct_sale_out es margen sobre la venta (margin-on-sale), aplicado sobre dealer_price.';

COMMIT;

