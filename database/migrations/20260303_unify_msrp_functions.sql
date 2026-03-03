-- ============================================================================
-- Migration: Unify MSRP pricing functions into a single canonical source
-- Date: 2026-03-03
--
-- Problem: 26+ migrations redefined MSRP functions with conflicting logic.
--   - msrp_compute_for_item(uuid) had the NEW correct formula (UOM conversion,
--     compound import_tax, msrp_get_effective_rates).
--   - recompute_catalog_item_msrp(uuid,uuid) had its own inline logic reading
--     CostSettings/CategoryMargins directly (could diverge from rates function).
--   - recompute_catalogitems_msrp_for_org(uuid) used OLD flat formula inline
--     (no UOM conversion, no compound import_tax).
--
-- Solution: Make msrp_compute_for_item the SINGLE canonical implementation.
--   - recompute_catalog_item_msrp delegates to msrp_compute_for_item.
--   - recompute_catalogitems_msrp_for_org iterates calling msrp_compute_for_item.
--   - trig_enforce_msrp_sources kept (compound formula, msrp_get_effective_rates).
--   - Backfill all active orgs at the end.
--
-- Formula:
--   pricing_cost_exw = compute_pricing_cost_exw(cost_exw, purchase_uom -> pricing_uom)
--   shipping_cost    = pricing_cost_exw * shipping_pct                              [GENERATED]
--   import_tax_cost  = pricing_cost_exw * (1 + shipping_pct) * import_tax_pct       [GENERATED]
--   total_cost       = pricing_cost_exw * (1 + shipping_pct) * (1 + import_tax_pct) [GENERATED]
--   dealer_price     = total_cost / (1 - minimum_margin_pct)   -- default 0.35
--   msrp             = dealer_price / (1 - msrp_pct)           -- default 0.65
--
-- IDEMPOTENT: safe to re-run.
-- ============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. CANONICAL: msrp_compute_for_item(uuid)
--    Single source of truth for MSRP calculation.
--    Uses derive_pricing_uom, compute_pricing_cost_exw, msrp_get_effective_rates.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public."msrp_compute_for_item"("p_item_id" uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_ci               record;
  v_shipping_pct     numeric;
  v_import_tax_pct   numeric;
  v_min_margin_pct   numeric;
  v_msrp_pct         numeric;
  v_pricing_uom      text;
  v_pricing_cost_exw numeric;
  v_total_cost_local numeric;
  v_dealer_price     numeric;
  v_msrp             numeric;
BEGIN
  SELECT id, organization_id, category_id,
         cost_exw, unit_of_measure, units_per_purchase_unit,
         measure_basis, is_roll, roll_pricing_mode,
         COALESCE(roll_width_m, roll_width) AS roll_width_m,
         sku, name, collection_name, variant_name
  INTO   v_ci
  FROM   public."CatalogItems"
  WHERE  id = p_item_id;

  IF v_ci.organization_id IS NULL THEN RETURN; END IF;

  SELECT r.shipping_pct, r.import_tax_pct, r.minimum_margin_pct, r.msrp_pct
  INTO   v_shipping_pct, v_import_tax_pct, v_min_margin_pct, v_msrp_pct
  FROM   public.msrp_get_effective_rates(v_ci.organization_id, v_ci.category_id) r;

  v_pricing_uom := public.derive_pricing_uom(
    v_ci.measure_basis, v_ci.roll_pricing_mode, v_ci.is_roll
  );

  v_pricing_cost_exw := public.compute_pricing_cost_exw(
    COALESCE(v_ci.cost_exw, 0),
    v_ci.unit_of_measure,
    v_pricing_uom,
    v_ci.units_per_purchase_unit,
    v_ci.roll_width_m
  );

  IF v_pricing_cost_exw IS NULL OR v_pricing_cost_exw = 0 THEN
    v_total_cost_local := 0;
    v_dealer_price     := 0;
    v_msrp             := 0;
  ELSE
    v_total_cost_local := round(
      v_pricing_cost_exw
      * (1 + COALESCE(v_shipping_pct, 0))
      * (1 + COALESCE(v_import_tax_pct, 0)),
      4
    );
    v_dealer_price := round(v_total_cost_local / NULLIF(1 - COALESCE(v_min_margin_pct, 0), 0), 4);
    v_msrp         := round(v_dealer_price     / NULLIF(1 - COALESCE(v_msrp_pct, 0), 0),       4);
  END IF;

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    sku, name, collection_name, variant_name,
    unit_of_measure, pricing_uom, pricing_cost_exw,
    shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct,
    dealer_price, msrp, updated_at
  )
  VALUES (
    p_item_id, v_ci.organization_id, v_ci.category_id,
    v_ci.sku, v_ci.name, v_ci.collection_name, v_ci.variant_name,
    v_ci.unit_of_measure, v_pricing_uom, v_pricing_cost_exw,
    COALESCE(v_shipping_pct,   0),
    COALESCE(v_import_tax_pct, 0),
    COALESCE(v_min_margin_pct, 0),
    COALESCE(v_msrp_pct,       0),
    COALESCE(v_dealer_price,   0),
    COALESCE(v_msrp,           0),
    now()
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    organization_id    = EXCLUDED.organization_id,
    category_id        = EXCLUDED.category_id,
    sku                = EXCLUDED.sku,
    name               = EXCLUDED.name,
    collection_name    = EXCLUDED.collection_name,
    variant_name       = EXCLUDED.variant_name,
    unit_of_measure    = EXCLUDED.unit_of_measure,
    pricing_uom        = EXCLUDED.pricing_uom,
    pricing_cost_exw   = EXCLUDED.pricing_cost_exw,
    shipping_pct       = EXCLUDED.shipping_pct,
    import_tax_pct     = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct,
    msrp_pct           = EXCLUDED.msrp_pct,
    dealer_price       = EXCLUDED.dealer_price,
    msrp               = EXCLUDED.msrp,
    updated_at         = now();
END;
$$;

COMMENT ON FUNCTION public."msrp_compute_for_item"(uuid) IS
'CANONICAL MSRP function. Single source of truth.
  pricing_uom      = derive_pricing_uom(measure_basis, roll_pricing_mode, is_roll)
  pricing_cost_exw = compute_pricing_cost_exw(cost_exw, purchase_uom -> pricing_uom)
  shipping_cost    = pricing_cost_exw * shipping_pct                              [GENERATED]
  import_tax_cost  = pricing_cost_exw * (1+shipping_pct) * import_tax_pct         [GENERATED]
  total_cost       = pricing_cost_exw * (1+shipping_pct) * (1+import_tax_pct)     [GENERATED]
  dealer_price     = total_cost / (1 - minimum_margin_pct)
  msrp             = dealer_price / (1 - msrp_pct)';


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. DELEGATE: recompute_catalog_item_msrp(uuid, uuid) -> msrp_compute_for_item
--    Legacy callers pass (org_id, item_id). We only need item_id.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public."recompute_catalog_item_msrp"(
  "p_organization_id" uuid,
  "p_catalog_item_id" uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM public.msrp_compute_for_item(p_catalog_item_id);
END;
$$;

COMMENT ON FUNCTION public."recompute_catalog_item_msrp"(uuid, uuid) IS
'Delegate to msrp_compute_for_item. Kept for backward compatibility with triggers and ImportCatalog.';


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. BULK: recompute_catalogitems_msrp_for_org(uuid)
--    Iterates all active items calling the canonical function.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public."recompute_catalogitems_msrp_for_org"("p_org" uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_item_id uuid;
  v_count   int := 0;
BEGIN
  FOR v_item_id IN
    SELECT id FROM public."CatalogItems"
    WHERE organization_id = p_org AND is_active = true
  LOOP
    PERFORM public.msrp_compute_for_item(v_item_id);
    v_count := v_count + 1;
  END LOOP;

  RAISE NOTICE 'recompute_catalogitems_msrp_for_org: processed % items for org %', v_count, p_org;
END;
$$;

COMMENT ON FUNCTION public."recompute_catalogitems_msrp_for_org"(uuid) IS
'Bulk recompute: iterates active items calling msrp_compute_for_item (canonical).
Uses UOM conversion, compound import_tax, msrp_get_effective_rates.';


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. TRIGGER: trig_enforce_msrp_sources (BEFORE INSERT/UPDATE on CatalogItemsMSRP)
--    Kept as-is: enforces rates from msrp_get_effective_rates, compound formula.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public."trig_enforce_msrp_sources"()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_org uuid; v_cat uuid; r record; v_tc numeric;
BEGIN
  v_org := NEW.organization_id; v_cat := NEW.category_id;
  IF v_org IS NULL OR v_cat IS NULL THEN
    SELECT organization_id, category_id INTO v_org, v_cat
    FROM   public."CatalogItems" WHERE id = NEW.catalog_item_id;
    NEW.organization_id := COALESCE(NEW.organization_id, v_org);
    NEW.category_id     := COALESCE(NEW.category_id, v_cat);
  END IF;
  IF NEW.organization_id IS NULL OR NEW.category_id IS NULL THEN RETURN NEW; END IF;

  SELECT * INTO r FROM public.msrp_get_effective_rates(NEW.organization_id, NEW.category_id);
  NEW.shipping_pct       := COALESCE(r.shipping_pct, 0);
  NEW.import_tax_pct     := COALESCE(r.import_tax_pct, 0);
  NEW.minimum_margin_pct := COALESCE(r.minimum_margin_pct, 0);
  NEW.msrp_pct           := COALESCE(r.msrp_pct, 0);

  IF COALESCE(NEW.pricing_cost_exw, 0) > 0 THEN
    v_tc := round(
      NEW.pricing_cost_exw * (1 + NEW.shipping_pct) * (1 + NEW.import_tax_pct), 4
    );
    NEW.dealer_price := round(v_tc / NULLIF(1 - NEW.minimum_margin_pct, 0), 4);
    NEW.msrp         := round(NEW.dealer_price / NULLIF(1 - NEW.msrp_pct, 0), 4);
  END IF;
  RETURN NEW;
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. BACKFILL: Recompute all active orgs
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
DECLARE
  v_org_id uuid;
BEGIN
  FOR v_org_id IN
    SELECT id FROM public."Organizations" WHERE COALESCE(deleted, false) = false
  LOOP
    PERFORM public.recompute_catalogitems_msrp_for_org(v_org_id);
    RAISE NOTICE 'Backfill complete for org %', v_org_id;
  END LOOP;
END;
$$;

COMMIT;
