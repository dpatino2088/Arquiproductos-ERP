-- =========================================
-- Migration 57: Rename MSRP columns (final cleanup)
-- =========================================
-- Rename msrp_sale_in → dealer_price
-- Rename msrp_sale_out → msrp
-- Eliminates legacy columns completely
-- =========================================

BEGIN;

-- =========================================
-- STEP 1: Check if old columns exist and backfill if they do
-- =========================================
DO $$
DECLARE
  v_has_old_columns boolean;
BEGIN
  -- Check if old columns exist
  SELECT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItemsMSRP' 
    AND column_name IN ('msrp_sale_in', 'msrp_sale_out')
  ) INTO v_has_old_columns;
  
  IF v_has_old_columns THEN
    -- Backfill new columns from old
    UPDATE public."CatalogItemsMSRP"
    SET 
      dealer_price = COALESCE(dealer_price, msrp_sale_in),
      msrp = COALESCE(msrp, msrp_sale_out)
    WHERE dealer_price IS NULL OR msrp IS NULL;
    
    RAISE NOTICE '✅ Backfilled dealer_price and msrp from old columns';
  ELSE
    RAISE NOTICE 'ℹ️ Old columns already removed, skipping backfill';
  END IF;
END $$;

-- =========================================
-- STEP 2: Ensure new columns exist and make them NOT NULL
-- =========================================
-- Add columns if they don't exist
ALTER TABLE public."CatalogItemsMSRP"
  ADD COLUMN IF NOT EXISTS dealer_price numeric;

ALTER TABLE public."CatalogItemsMSRP"
  ADD COLUMN IF NOT EXISTS msrp numeric;

-- Set default value to 0 for existing NULL rows
UPDATE public."CatalogItemsMSRP"
SET dealer_price = 0
WHERE dealer_price IS NULL;

UPDATE public."CatalogItemsMSRP"
SET msrp = 0
WHERE msrp IS NULL;

-- Make NOT NULL with default
ALTER TABLE public."CatalogItemsMSRP"
  ALTER COLUMN dealer_price SET DEFAULT 0,
  ALTER COLUMN dealer_price SET NOT NULL;

ALTER TABLE public."CatalogItemsMSRP"
  ALTER COLUMN msrp SET DEFAULT 0,
  ALTER COLUMN msrp SET NOT NULL;

-- =========================================
-- STEP 3: Drop sync trigger (no longer needed)
-- =========================================
DROP TRIGGER IF EXISTS trg_catalogitemsmsrp_sync_prices ON public."CatalogItemsMSRP";
DROP FUNCTION IF EXISTS public.catalogitemsmsrp_sync_prices();

-- =========================================
-- STEP 4: Update guard trigger
-- =========================================
CREATE OR REPLACE FUNCTION public.catalogitemsmsrp_guard_not_null()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.dealer_price := COALESCE(NEW.dealer_price, 0);
  NEW.msrp         := COALESCE(NEW.msrp, 0);
  RETURN NEW;
END;
$$;

-- =========================================
-- STEP 5: Update msrp_compute_for_item
-- =========================================
DROP FUNCTION IF EXISTS public.msrp_compute_for_item(uuid) CASCADE;

CREATE OR REPLACE FUNCTION public.msrp_compute_for_item(p_item_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
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

  v_dealer_price := round(v_total_cost / NULLIF(1 - COALESCE(v_msrp_pct_sale_in, 0), 0), 6);
  v_msrp := round(v_total_cost / NULLIF(1 - COALESCE(v_msrp_pct_sale_out, 0), 0), 6);

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
    minimum_margin_pct   = EXCLUDED.minimum_margin_pct,
    msrp_pct_sale_out   = EXCLUDED.msrp_pct_sale_out,

    shipping_cost   = EXCLUDED.shipping_cost,
    import_tax_cost = EXCLUDED.import_tax_cost,
    total_cost      = EXCLUDED.total_cost,

    dealer_price    = EXCLUDED.dealer_price,
    msrp            = EXCLUDED.msrp,

    updated_at      = now();

END;
$$;

COMMENT ON FUNCTION public.msrp_compute_for_item(uuid) IS 'Calcula MSRP para un CatalogItem. Usa CatalogItems.cost_exw como base. Escribe en CatalogItemsMSRP: cost_exw, shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct_sale_out, shipping_cost, import_tax_cost, total_cost, dealer_price, msrp.';

-- =========================================
-- STEP 6: Update recompute_catalog_item_msrp
-- =========================================
DROP FUNCTION IF EXISTS public.recompute_catalog_item_msrp(uuid, uuid) CASCADE;

CREATE OR REPLACE FUNCTION public.recompute_catalog_item_msrp(p_organization_id uuid, p_catalog_item_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_cost_exw numeric;
  v_category_id uuid;

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
  SELECT ci.cost_exw, ci.category_id
    INTO v_cost_exw, v_category_id
  FROM public."CatalogItems" ci
  WHERE ci.id = p_catalog_item_id;

  IF v_cost_exw IS NULL THEN
    v_cost_exw := 0;
  END IF;

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
    'ea',
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

-- =========================================
-- STEP 7: Update recompute_catalogitems_msrp_for_category
-- =========================================
DROP FUNCTION IF EXISTS public.recompute_catalogitems_msrp_for_category(uuid, uuid) CASCADE;

CREATE OR REPLACE FUNCTION public.recompute_catalogitems_msrp_for_category(p_org_id uuid, p_category_id uuid)
RETURNS void
LANGUAGE sql
AS $$
  INSERT INTO public."CatalogItemsMSRP" (
    organization_id,
    catalog_item_id,
    category_id,
    sku,
    name,
    collection_name,
    variant_name,
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
  SELECT
    p_org_id,
    ci.id,
    ci.category_id,
    ci.sku,
    ci.name,
    ci.collection_name,
    ci.variant_name,
    ci.unit_of_measure,
    COALESCE(ci.cost_exw, 0),
    COALESCE(rates.shipping_pct, 0),
    COALESCE(rates.import_tax_pct, 0),
    COALESCE(rates.minimum_margin_pct, 0.35),
    COALESCE(rates.msrp_pct_sale_out, 0.65),
    round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4) as shipping_cost,
    round(
      (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4))
      * COALESCE(rates.import_tax_pct, 0),
      4
    ) as import_tax_cost,
    round(
      COALESCE(ci.cost_exw, 0) +
      round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4) +
      round(
        (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4))
        * COALESCE(rates.import_tax_pct, 0),
        4
      ),
      4
    ) as total_cost,
    round(
      (COALESCE(ci.cost_exw, 0) +
       round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4) +
       round(
         (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4))
         * COALESCE(rates.import_tax_pct, 0),
         4
       ))
      / NULLIF(1 - COALESCE(rates.minimum_margin_pct, 0.35), 0),
      4
    ) as dealer_price,
    round(
      round(
        (COALESCE(ci.cost_exw, 0) +
         round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4) +
         round(
           (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4))
           * COALESCE(rates.import_tax_pct, 0),
           4
         ))
        / NULLIF(1 - COALESCE(rates.minimum_margin_pct, 0.35), 0),
        4
      )
      / NULLIF(1 - COALESCE(rates.msrp_pct_sale_out, 0.65), 0),
      4
    ) as msrp,
    now()
  FROM public."CatalogItems" ci
  LEFT JOIN public.msrp_get_effective_rates(p_org_id, ci.category_id) rates ON true
  WHERE ci.organization_id = p_org_id
    AND ci.category_id = p_category_id
    AND ci.is_active = true
  ON CONFLICT (catalog_item_id)
  DO UPDATE SET
    cost_exw           = EXCLUDED.cost_exw,
    shipping_pct       = EXCLUDED.shipping_pct,
    import_tax_pct     = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct,
    msrp_pct_sale_out  = EXCLUDED.msrp_pct_sale_out,
    shipping_cost      = EXCLUDED.shipping_cost,
    import_tax_cost    = EXCLUDED.import_tax_cost,
    total_cost         = EXCLUDED.total_cost,
    dealer_price       = EXCLUDED.dealer_price,
    msrp               = EXCLUDED.msrp,
    updated_at         = now();
$$;

-- =========================================
-- STEP 8: Update recompute_catalogitems_msrp_for_org
-- =========================================
DROP FUNCTION IF EXISTS public.recompute_catalogitems_msrp_for_org(uuid) CASCADE;

CREATE OR REPLACE FUNCTION public.recompute_catalogitems_msrp_for_org(p_org uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public."CatalogItemsMSRP" (
    organization_id,
    catalog_item_id,
    category_id,
    sku,
    name,
    collection_name,
    variant_name,
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
  SELECT
    ci.organization_id,
    ci.id,
    ci.category_id,
    ci.sku,
    ci.name,
    ci.collection_name,
    ci.variant_name,
    ci.unit_of_measure,
    COALESCE(ci.cost_exw, 0),
    COALESCE(cs.shipping_pct, 0),
    COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0),
    COALESCE(cm.minimum_margin_pct, cs.minimum_margin_pct, cs.default_margin_pct, 0.35),
    COALESCE(cm.msrp_pct_sale_out, cs.msrp_pct_sale_out, cs.default_msrp_pct_sale_out, 0.65),

    round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4),
    round(
      (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4))
      * COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0),
      4
    ),
    round(
      COALESCE(ci.cost_exw, 0) +
      round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4) +
      round(
        (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4))
        * COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0),
        4
      ),
      4
    ),
    round(
      (COALESCE(ci.cost_exw, 0) +
       round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4) +
       round(
         (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4))
         * COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0),
         4
       ))
      / NULLIF(1 - COALESCE(cm.minimum_margin_pct, cs.minimum_margin_pct, cs.default_margin_pct, 0.35), 0),
      4
    ),
    round(
      round(
        (COALESCE(ci.cost_exw, 0) +
         round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4) +
         round(
           (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4))
           * COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0),
           4
         ))
        / NULLIF(1 - COALESCE(cm.minimum_margin_pct, cs.minimum_margin_pct, cs.default_margin_pct, 0.35), 0),
        4
      )
      / NULLIF(1 - COALESCE(cm.msrp_pct_sale_out, cs.msrp_pct_sale_out, cs.default_msrp_pct_sale_out, 0.65), 0),
      4
    ),
    now()
  FROM public."CatalogItems" ci
  LEFT JOIN public."CostSettings" cs ON cs.organization_id = ci.organization_id
  LEFT JOIN public."CategoryMargins" cm ON cm.organization_id = ci.organization_id AND cm.category_id = ci.category_id
  WHERE ci.organization_id = p_org
    AND ci.is_active = true
  ON CONFLICT (catalog_item_id)
  DO UPDATE SET
    cost_exw           = EXCLUDED.cost_exw,
    shipping_pct       = EXCLUDED.shipping_pct,
    import_tax_pct     = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct,
    msrp_pct_sale_out  = EXCLUDED.msrp_pct_sale_out,
    shipping_cost      = EXCLUDED.shipping_cost,
    import_tax_cost    = EXCLUDED.import_tax_cost,
    total_cost         = EXCLUDED.total_cost,
    dealer_price       = EXCLUDED.dealer_price,
    msrp               = EXCLUDED.msrp,
    updated_at         = now();
END;
$$;

-- =========================================
-- STEP 9: Update sync_catalogitems_to_msrp (with CASCADE to drop triggers)
-- =========================================
DROP FUNCTION IF EXISTS public.sync_catalogitems_to_msrp() CASCADE;
DROP FUNCTION IF EXISTS public.sync_catalogitems_to_msrp_safe() CASCADE;

CREATE OR REPLACE FUNCTION public.sync_catalogitems_to_msrp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    sku, name, collection_name, variant_name, unit_of_measure,
    cost_exw, shipping_cost, import_tax_cost, total_cost,
    dealer_price, msrp
  )
  VALUES (
    NEW.id, NEW.organization_id, NEW.category_id,
    NEW.sku, NEW.name, NEW.collection_name, NEW.variant_name, NEW.unit_of_measure,
    0, 0, 0, 0,
    0, 0
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    sku = EXCLUDED.sku,
    name = EXCLUDED.name,
    collection_name = EXCLUDED.collection_name,
    variant_name = EXCLUDED.variant_name,
    unit_of_measure = EXCLUDED.unit_of_measure,
    category_id = EXCLUDED.category_id,
    updated_at = now();
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.sync_catalogitems_to_msrp() IS 'Sync identity (sku, name, collection_name, variant_name, unit_of_measure) from CatalogItems to CatalogItemsMSRP. If row does not exist, INSERT with dealer_price=0, msrp=0 to satisfy NOT NULL.';

-- =========================================
-- STEP 9B: Update sync_catalogitems_to_msrp_safe (critical - this causes the error)
-- =========================================
CREATE OR REPLACE FUNCTION public.sync_catalogitems_to_msrp_safe()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id,
    organization_id,
    category_id,

    cost_exw,
    shipping_cost,
    import_tax_cost,
    total_cost,

    dealer_price,
    msrp,

    sku,
    name,
    collection_name,
    variant_name,
    unit_of_measure,

    updated_at
  )
  VALUES (
    NEW.id,
    NEW.organization_id,
    NEW.category_id,

    COALESCE(NEW.cost_exw, 0),
    0,
    0,
    COALESCE(NEW.cost_exw, 0),

    0,
    0,

    NEW.sku,
    NEW.name,
    NEW.collection_name,
    NEW.variant_name,
    NEW.unit_of_measure,

    now()
  )
  ON CONFLICT (catalog_item_id)
  DO UPDATE SET
    organization_id = EXCLUDED.organization_id,
    sku = EXCLUDED.sku,
    name = EXCLUDED.name,
    collection_name = EXCLUDED.collection_name,
    variant_name = EXCLUDED.variant_name,
    unit_of_measure = EXCLUDED.unit_of_measure,
    category_id = EXCLUDED.category_id,
    updated_at = now();

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.sync_catalogitems_to_msrp_safe() IS 'Sync identity (sku, name, collection_name, variant_name, unit_of_measure) from CatalogItems to CatalogItemsMSRP. If row does not exist, INSERT with minimal values. On UPDATE only touches identity, NOT cost_exw or total_cost (handled by msrp_compute_for_item).';

-- Recreate trigger (was dropped with CASCADE)
DROP TRIGGER IF EXISTS trg_sync_catalogitems_to_msrp_safe ON public."CatalogItems";
CREATE TRIGGER trg_sync_catalogitems_to_msrp_safe
  AFTER INSERT OR UPDATE OF sku, name, collection_name, variant_name, unit_of_measure, category_id, cost_exw
  ON public."CatalogItems"
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_catalogitems_to_msrp_safe();

-- =========================================
-- STEP 10: Update calculate_configured_product_totals
-- =========================================
DROP FUNCTION IF EXISTS public.calculate_configured_product_totals(uuid) CASCADE;

CREATE OR REPLACE FUNCTION public.calculate_configured_product_totals(p_configured_product_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_cp RECORD;
    v_bom_instance_id uuid;
    v_part RECORD;
    v_roll_msrp numeric := 0;
    v_roll_total_cost_per_unit numeric := 0;
    v_roll_area_sqm numeric := 0;
    v_accessories_msrp numeric := 0;
    v_accessories_total_cost numeric := 0;
    v_total_msrp numeric := 0;
    v_total_cost numeric := 0;
    v_part_msrp numeric;
    v_part_total_cost numeric;
BEGIN
    -- Get configured product
    SELECT * INTO v_cp
    FROM public."ConfiguredProducts"
    WHERE id = p_configured_product_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
    END IF;
    
    v_bom_instance_id := v_cp.bom_instance_id;
    IF v_bom_instance_id IS NULL THEN
        RETURN jsonb_build_object('error', 'No BOMInstance');
    END IF;
    
    -- Get roll MSRP and total cost
    IF v_cp.roll_catalog_item_id IS NOT NULL THEN
        SELECT 
            msrp,
            total_cost
        INTO v_roll_msrp, v_roll_total_cost_per_unit
        FROM public."CatalogItemsMSRP"
        WHERE catalog_item_id = v_cp.roll_catalog_item_id
        AND organization_id = v_cp.organization_id
        LIMIT 1;

        -- Fallback without organization_id filter
        IF v_roll_msrp IS NULL THEN
            SELECT 
                msrp,
                total_cost
            INTO v_roll_msrp, v_roll_total_cost_per_unit
            FROM public."CatalogItemsMSRP"
            WHERE catalog_item_id = v_cp.roll_catalog_item_id
            LIMIT 1;
        END IF;
        
        v_roll_area_sqm := COALESCE(v_cp.fabric_cut_width_mm, 0) * COALESCE(v_cp.fabric_cut_height_mm, 0) / 1000000.0;
        v_roll_msrp := COALESCE(v_roll_msrp, 0) * v_roll_area_sqm;
        v_roll_total_cost_per_unit := COALESCE(v_roll_total_cost_per_unit, 0) * v_roll_area_sqm;
    END IF;
    
    -- Get accessories/parts MSRP and costs
    FOR v_part IN
        SELECT 
            bil.resolved_part_id,
            bil.qty
        FROM public."BOMInstanceLines" bil
        WHERE bil.bom_instance_id = v_bom_instance_id
                AND bil.deleted = false
                AND bil.resolved_part_id IS NOT NULL
    LOOP
        SELECT 
            msrp,
            total_cost
        INTO v_part_msrp, v_part_total_cost
        FROM public."CatalogItemsMSRP"
        WHERE catalog_item_id = v_part.resolved_part_id
        AND organization_id = v_cp.organization_id
        LIMIT 1;

        -- Fallback without organization_id filter
        IF v_part_msrp IS NULL THEN
            SELECT 
                msrp,
                total_cost
            INTO v_part_msrp, v_part_total_cost
            FROM public."CatalogItemsMSRP"
            WHERE catalog_item_id = v_part.resolved_part_id
            LIMIT 1;
        END IF;
        
        v_accessories_msrp := v_accessories_msrp + (COALESCE(v_part_msrp, 0) * v_part.qty);
        v_accessories_total_cost := v_accessories_total_cost + (COALESCE(v_part_total_cost, 0) * v_part.qty);
    END LOOP;
    
    v_total_msrp := v_roll_msrp + v_accessories_msrp;
    v_total_cost := v_roll_total_cost_per_unit + v_accessories_total_cost;
    
    RETURN jsonb_build_object(
        'roll_msrp', v_roll_msrp,
        'roll_total_cost', v_roll_total_cost_per_unit,
        'accessories_msrp', v_accessories_msrp,
        'accessories_total_cost', v_accessories_total_cost,
        'total_msrp', v_total_msrp,
        'total_cost', v_total_cost
    );
END;
$$;

-- =========================================
-- STEP 11: Verify all functions updated before dropping columns
-- =========================================
-- This ensures we don't drop columns while functions still reference them

-- List of functions that should now use dealer_price/msrp:
-- ✅ msrp_compute_for_item
-- ✅ recompute_catalog_item_msrp
-- ✅ recompute_catalogitems_msrp_for_category
-- ✅ recompute_catalogitems_msrp_for_org
-- ✅ sync_catalogitems_to_msrp
-- ✅ sync_catalogitems_to_msrp_safe
-- ✅ calculate_configured_product_totals

-- =========================================
-- STEP 12: Drop old columns (CASCADE will drop dependencies)
-- =========================================
ALTER TABLE public."CatalogItemsMSRP"
  DROP COLUMN IF EXISTS msrp_sale_in CASCADE;

ALTER TABLE public."CatalogItemsMSRP"
  DROP COLUMN IF EXISTS msrp_sale_out CASCADE;

-- =========================================
-- STEP 13: Verification query
-- =========================================
DO $$
DECLARE
  v_count_null_dealer integer;
  v_count_null_msrp integer;
BEGIN
  SELECT COUNT(*) INTO v_count_null_dealer
  FROM public."CatalogItemsMSRP"
  WHERE dealer_price IS NULL;
  
  SELECT COUNT(*) INTO v_count_null_msrp
  FROM public."CatalogItemsMSRP"
  WHERE msrp IS NULL;
  
  IF v_count_null_dealer > 0 OR v_count_null_msrp > 0 THEN
    RAISE WARNING 'Found % rows with NULL dealer_price and % with NULL msrp', v_count_null_dealer, v_count_null_msrp;
  ELSE
    RAISE NOTICE '✅ All rows have dealer_price and msrp populated';
  END IF;
END $$;

COMMIT;
