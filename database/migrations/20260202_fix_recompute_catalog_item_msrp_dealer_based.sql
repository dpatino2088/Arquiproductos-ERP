-- ====================================================
-- MIGRATION: Fix recompute_catalog_item_msrp() MSRP formula
-- Date: 2026-02-02
--
-- Business rule:
-- - total_cost = cost_exw + shipping_cost + import_tax_cost
-- - dealer_price = total_cost / (1 - minimum_margin_pct)
-- - msrp = dealer_price / (1 - msrp_pct_sale_out)
--
-- Note: This is the function actually used by trigger:
--   catalog_items_recompute_msrp AFTER UPDATE OF cost_exw ON CatalogItems
-- ====================================================

BEGIN;

CREATE OR REPLACE FUNCTION "public"."recompute_catalog_item_msrp"(
  "p_organization_id" "uuid",
  "p_catalog_item_id" "uuid"
) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_cost_exw numeric;
  v_category_id uuid;
  v_unit_of_measure text;

  v_shipping_pct numeric := 0;
  v_import_tax_pct numeric := 0;

  v_min_margin_pct numeric := 0.35;
  v_msrp_pct_sale_out numeric := 0.65;

  v_material_cost numeric := 0;
  v_shipping_cost numeric := 0;
  v_import_tax_cost numeric := 0;
  v_total_cost numeric := 0;

  v_dealer_price numeric := 0;
  v_msrp numeric := 0;
BEGIN
  SELECT ci.cost_exw, ci.category_id, ci.unit_of_measure
    INTO v_cost_exw, v_category_id, v_unit_of_measure
  FROM public."CatalogItems" ci
  WHERE ci.id = p_catalog_item_id;

  IF v_cost_exw IS NULL THEN
    v_cost_exw := 0;
  END IF;

  IF v_unit_of_measure IS NULL OR v_unit_of_measure = '' THEN
    v_unit_of_measure := 'ea';
  END IF;

  -- Load defaults from CostSettings
  SELECT
    COALESCE(cs.shipping_pct, 0),
    COALESCE(cs.import_tax_pct, 0),
    COALESCE(cs.minimum_margin_pct, cs.default_margin_pct, v_min_margin_pct),
    COALESCE(cs.msrp_pct_sale_out, v_msrp_pct_sale_out)
  INTO
    v_shipping_pct,
    v_import_tax_pct,
    v_min_margin_pct,
    v_msrp_pct_sale_out
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_organization_id
  LIMIT 1;

  -- Override with CategoryMargins when present
  IF v_category_id IS NOT NULL THEN
    SELECT
      COALESCE(cm.minimum_margin_pct, v_min_margin_pct),
      COALESCE(cm.msrp_pct_sale_out, v_msrp_pct_sale_out)
    INTO
      v_min_margin_pct,
      v_msrp_pct_sale_out
    FROM public."CategoryMargins" cm
    WHERE cm.organization_id = p_organization_id
      AND cm.category_id = v_category_id
    LIMIT 1;
  END IF;

  v_material_cost := v_cost_exw;
  v_shipping_cost := v_material_cost * v_shipping_pct;
  v_import_tax_cost := (v_material_cost + v_shipping_cost) * v_import_tax_pct;
  v_total_cost := v_material_cost + v_shipping_cost + v_import_tax_cost;

  -- Dealer and MSRP formulas (dealer-based MSRP)
  v_dealer_price := round(v_total_cost / NULLIF(1 - v_min_margin_pct, 0), 4);
  v_msrp := round(v_dealer_price / NULLIF(1 - v_msrp_pct_sale_out, 0), 4);

  INSERT INTO public."CatalogItemsMSRP" (
    organization_id,
    catalog_item_id,
    unit_of_measure,
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
    p_organization_id,
    p_catalog_item_id,
    v_unit_of_measure,
    v_cost_exw,
    v_shipping_pct,
    v_import_tax_pct,
    v_min_margin_pct,
    v_msrp_pct_sale_out,

    v_shipping_cost,
    v_import_tax_cost,
    v_total_cost,
    v_dealer_price,
    v_msrp,
    now()
  )
  ON CONFLICT (organization_id, catalog_item_id)
  DO UPDATE SET
    unit_of_measure = EXCLUDED.unit_of_measure,
    cost_exw = EXCLUDED.cost_exw,
    shipping_pct = EXCLUDED.shipping_pct,
    import_tax_pct = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct,
    msrp_pct_sale_out = EXCLUDED.msrp_pct_sale_out,
    shipping_cost = EXCLUDED.shipping_cost,
    import_tax_cost = EXCLUDED.import_tax_cost,
    total_cost = EXCLUDED.total_cost,
    dealer_price = EXCLUDED.dealer_price,
    msrp = EXCLUDED.msrp,
    updated_at = now();
END;
$$;

COMMENT ON FUNCTION "public"."recompute_catalog_item_msrp"("p_organization_id" "uuid", "p_catalog_item_id" "uuid") IS
'Recompute CatalogItemsMSRP for one item.
Rule:
- dealer_price = total_cost / (1 - minimum_margin_pct)
- msrp = dealer_price / (1 - msrp_pct_sale_out)';

COMMIT;

