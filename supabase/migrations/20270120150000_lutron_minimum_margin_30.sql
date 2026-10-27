-- Lutron components use a 30% minimum margin. The category rate stays 35%
-- so non-Lutron items in the same category are unchanged. MSRP sale-out stays
-- on the category (60% motors, 65% hardware).

ALTER TABLE public."CatalogItems"
  ADD COLUMN IF NOT EXISTS minimum_margin_pct_override numeric;

ALTER TABLE public."CatalogItems"
  DROP CONSTRAINT IF EXISTS catalogitems_minimum_margin_pct_override_range;

ALTER TABLE public."CatalogItems"
  ADD CONSTRAINT catalogitems_minimum_margin_pct_override_range
  CHECK (
    minimum_margin_pct_override IS NULL
    OR (minimum_margin_pct_override >= 0 AND minimum_margin_pct_override < 1)
  );

COMMENT ON COLUMN public."CatalogItems".minimum_margin_pct_override IS
  'When set, this item uses this minimum margin instead of the category rate. MSRP sale-out still comes from the category.';

CREATE OR REPLACE FUNCTION public.trig_enforce_msrp_sources()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_org uuid; v_cat uuid; r record; v_tc numeric;
  v_supply_origin text;
  v_margin_override numeric;
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

  SELECT minimum_margin_pct_override INTO v_margin_override
  FROM   public."CatalogItems"
  WHERE  id = NEW.catalog_item_id;

  NEW.shipping_pct       := COALESCE(r.shipping_pct, 0);
  NEW.import_tax_pct     := COALESCE(r.import_tax_pct, 0);
  NEW.minimum_margin_pct := COALESCE(v_margin_override, r.minimum_margin_pct, 0);
  NEW.msrp_pct           := COALESCE(r.msrp_pct, 0);

  SELECT supply_origin INTO v_supply_origin
  FROM   public."CatalogItemSupply"
  WHERE  catalog_item_id = NEW.catalog_item_id
    AND  organization_id = NEW.organization_id
  LIMIT 1;

  IF COALESCE(v_supply_origin, 'import') = 'local' THEN
    NEW.import_tax_pct := 0;
  END IF;

  IF COALESCE(NEW.pricing_cost_exw, 0) > 0 THEN
    v_tc := round(
      NEW.pricing_cost_exw * (1 + NEW.shipping_pct) * (1 + NEW.import_tax_pct), 4
    );
    NEW.dealer_price := round(v_tc / NULLIF(1 - NEW.minimum_margin_pct, 0), 4);
    NEW.msrp         := round(NEW.dealer_price / NULLIF(1 - NEW.msrp_pct, 0), 4);
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.msrp_compute_for_item(p_item_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
  v_supply_origin    text;
BEGIN
  SELECT id, organization_id, category_id,
         cost_exw, unit_of_measure, units_per_purchase_unit,
         measure_basis, is_roll, roll_pricing_mode,
         COALESCE(roll_width_m, roll_width) AS roll_width_m,
         sku, name, collection_name, variant_name,
         minimum_margin_pct_override
  INTO   v_ci
  FROM   public."CatalogItems"
  WHERE  id = p_item_id;

  IF v_ci.organization_id IS NULL THEN RETURN; END IF;

  SELECT r.shipping_pct, r.import_tax_pct, r.minimum_margin_pct, r.msrp_pct
  INTO   v_shipping_pct, v_import_tax_pct, v_min_margin_pct, v_msrp_pct
  FROM   public.msrp_get_effective_rates(v_ci.organization_id, v_ci.category_id) r;

  IF v_ci.minimum_margin_pct_override IS NOT NULL THEN
    v_min_margin_pct := v_ci.minimum_margin_pct_override;
  END IF;

  SELECT supply_origin INTO v_supply_origin
  FROM   public."CatalogItemSupply"
  WHERE  catalog_item_id = p_item_id
    AND  organization_id = v_ci.organization_id
  LIMIT 1;

  IF COALESCE(v_supply_origin, 'import') = 'local' THEN
    v_import_tax_pct := 0;
  END IF;

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
$function$;

UPDATE public."CatalogItems" ci
SET minimum_margin_pct_override = 0.30
FROM public."Manufacturers" m
WHERE ci.manufacturer_id = m.id
  AND lower(m.name) = 'lutron';

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT ci.id
    FROM public."CatalogItems" ci
    JOIN public."Manufacturers" m ON m.id = ci.manufacturer_id
    WHERE lower(m.name) = 'lutron'
  LOOP
    PERFORM public.msrp_compute_for_item(r.id);
  END LOOP;
END $$;
