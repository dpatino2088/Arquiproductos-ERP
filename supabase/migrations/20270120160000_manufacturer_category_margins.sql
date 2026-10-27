-- Minimum margin can be set for a manufacturer, and then for one category
-- of that manufacturer. More specific wins:
--   item override > manufacturer+category > manufacturer > category.

CREATE TABLE IF NOT EXISTS public."ManufacturerMargins" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  manufacturer_id uuid NOT NULL,
  minimum_margin_pct numeric NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT manufacturermargins_org_mfr_unique UNIQUE (organization_id, manufacturer_id),
  CONSTRAINT manufacturermargins_margin_range CHECK (minimum_margin_pct >= 0 AND minimum_margin_pct < 1)
);

CREATE TABLE IF NOT EXISTS public."ManufacturerCategoryMargins" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  manufacturer_id uuid NOT NULL,
  category_id uuid NOT NULL,
  minimum_margin_pct numeric NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT manufacturercategorymargins_org_mfr_cat_unique UNIQUE (organization_id, manufacturer_id, category_id),
  CONSTRAINT manufacturercategorymargins_margin_range CHECK (minimum_margin_pct >= 0 AND minimum_margin_pct < 1)
);

CREATE INDEX IF NOT EXISTS manufacturermargins_mfr_idx
  ON public."ManufacturerMargins" (manufacturer_id);
CREATE INDEX IF NOT EXISTS manufacturercategorymargins_mfr_cat_idx
  ON public."ManufacturerCategoryMargins" (manufacturer_id, category_id);

DROP TRIGGER IF EXISTS trg_manufacturermargins_updated_at ON public."ManufacturerMargins";
CREATE TRIGGER trg_manufacturermargins_updated_at
  BEFORE UPDATE ON public."ManufacturerMargins"
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_manufacturercategorymargins_updated_at ON public."ManufacturerCategoryMargins";
CREATE TRIGGER trg_manufacturercategorymargins_updated_at
  BEFORE UPDATE ON public."ManufacturerCategoryMargins"
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public."ManufacturerMargins" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."ManufacturerCategoryMargins" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rls_manufacturermargins_select ON public."ManufacturerMargins";
DROP POLICY IF EXISTS rls_manufacturermargins_insert ON public."ManufacturerMargins";
DROP POLICY IF EXISTS rls_manufacturermargins_update ON public."ManufacturerMargins";
DROP POLICY IF EXISTS rls_manufacturermargins_delete ON public."ManufacturerMargins";
CREATE POLICY rls_manufacturermargins_select ON public."ManufacturerMargins"
  FOR SELECT USING (is_org_user_member(organization_id));
CREATE POLICY rls_manufacturermargins_insert ON public."ManufacturerMargins"
  FOR INSERT WITH CHECK (is_org_owner_or_admin(organization_id));
CREATE POLICY rls_manufacturermargins_update ON public."ManufacturerMargins"
  FOR UPDATE USING (is_org_owner_or_admin(organization_id))
  WITH CHECK (is_org_owner_or_admin(organization_id));
CREATE POLICY rls_manufacturermargins_delete ON public."ManufacturerMargins"
  FOR DELETE USING (is_org_owner_or_admin(organization_id));

DROP POLICY IF EXISTS rls_manufacturercategorymargins_select ON public."ManufacturerCategoryMargins";
DROP POLICY IF EXISTS rls_manufacturercategorymargins_insert ON public."ManufacturerCategoryMargins";
DROP POLICY IF EXISTS rls_manufacturercategorymargins_update ON public."ManufacturerCategoryMargins";
DROP POLICY IF EXISTS rls_manufacturercategorymargins_delete ON public."ManufacturerCategoryMargins";
CREATE POLICY rls_manufacturercategorymargins_select ON public."ManufacturerCategoryMargins"
  FOR SELECT USING (is_org_user_member(organization_id));
CREATE POLICY rls_manufacturercategorymargins_insert ON public."ManufacturerCategoryMargins"
  FOR INSERT WITH CHECK (is_org_owner_or_admin(organization_id));
CREATE POLICY rls_manufacturercategorymargins_update ON public."ManufacturerCategoryMargins"
  FOR UPDATE USING (is_org_owner_or_admin(organization_id))
  WITH CHECK (is_org_owner_or_admin(organization_id));
CREATE POLICY rls_manufacturercategorymargins_delete ON public."ManufacturerCategoryMargins"
  FOR DELETE USING (is_org_owner_or_admin(organization_id));

GRANT SELECT, INSERT, UPDATE, DELETE ON public."ManufacturerMargins" TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public."ManufacturerCategoryMargins" TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.msrp_resolve_minimum_margin(
  p_item_id uuid,
  p_org_id uuid,
  p_category_id uuid,
  p_category_margin numeric
) RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
  v_manufacturer uuid;
  v_item_override numeric;
  v_mfr numeric;
  v_mfr_cat numeric;
  v_margin numeric;
BEGIN
  SELECT manufacturer_id, minimum_margin_pct_override
  INTO v_manufacturer, v_item_override
  FROM public."CatalogItems"
  WHERE id = p_item_id;

  v_margin := COALESCE(p_category_margin, 0);

  IF v_manufacturer IS NOT NULL THEN
    SELECT minimum_margin_pct INTO v_mfr
    FROM public."ManufacturerMargins"
    WHERE organization_id = p_org_id
      AND manufacturer_id = v_manufacturer
      AND is_active = true
    LIMIT 1;
    IF v_mfr IS NOT NULL THEN
      v_margin := v_mfr;
    END IF;

    SELECT minimum_margin_pct INTO v_mfr_cat
    FROM public."ManufacturerCategoryMargins"
    WHERE organization_id = p_org_id
      AND manufacturer_id = v_manufacturer
      AND category_id = p_category_id
      AND is_active = true
    LIMIT 1;
    IF v_mfr_cat IS NOT NULL THEN
      v_margin := v_mfr_cat;
    END IF;
  END IF;

  IF v_item_override IS NOT NULL THEN
    v_margin := v_item_override;
  END IF;

  RETURN COALESCE(v_margin, 0);
END;
$function$;

CREATE OR REPLACE FUNCTION public.msrp_recompute_for_manufacturer(
  p_manufacturer_id uuid,
  p_organization_id uuid
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_item record;
  v_count integer := 0;
BEGIN
  FOR v_item IN
    SELECT id
    FROM public."CatalogItems"
    WHERE manufacturer_id = p_manufacturer_id
      AND organization_id = p_organization_id
      AND organization_id IS NOT NULL
  LOOP
    BEGIN
      PERFORM public.msrp_compute_for_item(v_item.id);
      v_count := v_count + 1;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'Error recalculando item %: %', v_item.id, SQLERRM;
    END;
  END LOOP;
  RETURN v_count;
END;
$function$;

CREATE OR REPLACE FUNCTION public.msrp_recompute_for_manufacturer_category(
  p_manufacturer_id uuid,
  p_category_id uuid,
  p_organization_id uuid
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_item record;
  v_count integer := 0;
BEGIN
  FOR v_item IN
    SELECT id
    FROM public."CatalogItems"
    WHERE manufacturer_id = p_manufacturer_id
      AND category_id = p_category_id
      AND organization_id = p_organization_id
      AND organization_id IS NOT NULL
  LOOP
    BEGIN
      PERFORM public.msrp_compute_for_item(v_item.id);
      v_count := v_count + 1;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'Error recalculando item %: %', v_item.id, SQLERRM;
    END;
  END LOOP;
  RETURN v_count;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trig_recompute_msrp_on_manufacturer_margin()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.msrp_recompute_for_manufacturer(OLD.manufacturer_id, OLD.organization_id);
    RETURN OLD;
  END IF;
  PERFORM public.msrp_recompute_for_manufacturer(NEW.manufacturer_id, NEW.organization_id);
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trig_recompute_msrp_on_manufacturer_category_margin()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.msrp_recompute_for_manufacturer_category(OLD.manufacturer_id, OLD.category_id, OLD.organization_id);
    RETURN OLD;
  END IF;
  PERFORM public.msrp_recompute_for_manufacturer_category(NEW.manufacturer_id, NEW.category_id, NEW.organization_id);
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_recompute_msrp_on_manufacturer_margin ON public."ManufacturerMargins";
CREATE TRIGGER trg_recompute_msrp_on_manufacturer_margin
  AFTER INSERT OR UPDATE OR DELETE ON public."ManufacturerMargins"
  FOR EACH ROW EXECUTE FUNCTION public.trig_recompute_msrp_on_manufacturer_margin();

DROP TRIGGER IF EXISTS trg_recompute_msrp_on_manufacturer_category_margin ON public."ManufacturerCategoryMargins";
CREATE TRIGGER trg_recompute_msrp_on_manufacturer_category_margin
  AFTER INSERT OR UPDATE OR DELETE ON public."ManufacturerCategoryMargins"
  FOR EACH ROW EXECUTE FUNCTION public.trig_recompute_msrp_on_manufacturer_category_margin();

CREATE OR REPLACE FUNCTION public.trig_enforce_msrp_sources()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_org uuid; v_cat uuid; r record; v_tc numeric;
  v_supply_origin text;
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
  NEW.minimum_margin_pct := public.msrp_resolve_minimum_margin(
    NEW.catalog_item_id, NEW.organization_id, NEW.category_id, COALESCE(r.minimum_margin_pct, 0)
  );
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
         sku, name, collection_name, variant_name
  INTO   v_ci
  FROM   public."CatalogItems"
  WHERE  id = p_item_id;

  IF v_ci.organization_id IS NULL THEN RETURN; END IF;

  SELECT r.shipping_pct, r.import_tax_pct, r.minimum_margin_pct, r.msrp_pct
  INTO   v_shipping_pct, v_import_tax_pct, v_min_margin_pct, v_msrp_pct
  FROM   public.msrp_get_effective_rates(v_ci.organization_id, v_ci.category_id) r;

  v_min_margin_pct := public.msrp_resolve_minimum_margin(
    p_item_id, v_ci.organization_id, v_ci.category_id, COALESCE(v_min_margin_pct, 0)
  );

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

-- The Lutron 30% now lives on the manufacturer, not on each item.
UPDATE public."CatalogItems" ci
SET minimum_margin_pct_override = NULL
FROM public."Manufacturers" m
WHERE ci.manufacturer_id = m.id
  AND lower(m.name) = 'lutron'
  AND ci.minimum_margin_pct_override IS NOT NULL;

INSERT INTO public."ManufacturerMargins" (organization_id, manufacturer_id, minimum_margin_pct)
SELECT m.organization_id, m.id, 0.30
FROM public."Manufacturers" m
WHERE lower(m.name) = 'lutron'
ON CONFLICT (organization_id, manufacturer_id) DO UPDATE
SET minimum_margin_pct = EXCLUDED.minimum_margin_pct,
    is_active = true;
