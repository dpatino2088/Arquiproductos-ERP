-- ====================================================
-- Migration: Eliminar material_cost (legacy) de CatalogItemsMSRP
-- Date: 2026-01-24
-- ====================================================
-- El monto base de productos es CatalogItems.cost_exw.
-- material_cost era redundante (= cost_exw). Se elimina de la tabla
-- y de todas las funciones/triggers que lo usaban.
--
-- NO tocar: QuoteLineCosts.base_material_cost, override_base_material_cost,
-- QuoteLines.material_cost ni otras tablas.
-- ====================================================

-- 1) msrp_compute_for_item: quitar material_cost del INSERT y ON CONFLICT
--    (mantener v_material_cost como variable local = cost_exw para cálculos)
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

  v_msrp_sale_in numeric;
  v_msrp_sale_out numeric;
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

  v_msrp_sale_in  := round(v_total_cost / NULLIF(1 - COALESCE(v_msrp_pct_sale_in, 0), 0), 6);
  v_msrp_sale_out := round(v_total_cost / NULLIF(1 - COALESCE(v_msrp_pct_sale_out, 0), 0), 6);

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

    msrp_sale_in,
    msrp_sale_out,

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

    COALESCE(v_msrp_sale_in, 0),
    COALESCE(v_msrp_sale_out, 0),

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

    msrp_sale_in    = EXCLUDED.msrp_sale_in,
    msrp_sale_out   = EXCLUDED.msrp_sale_out,

    updated_at      = now();

END;
$$;

COMMENT ON FUNCTION "public"."msrp_compute_for_item"("p_item_id" "uuid") IS
'Calcula MSRP para un CatalogItem. Usa CatalogItems.cost_exw como base. Escribe en CatalogItemsMSRP: cost_exw, shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct_sale_out, shipping_cost, import_tax_cost, total_cost, msrp_sale_in, msrp_sale_out.';


-- 2) recompute_catalog_item_msrp: quitar material_cost del INSERT y ON CONFLICT
CREATE OR REPLACE FUNCTION "public"."recompute_catalog_item_msrp"("p_organization_id" "uuid", "p_catalog_item_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
declare
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

  v_msrp_sale_in numeric := 0;
  v_msrp_sale_out numeric := 0;
begin
  select ci.cost_exw, ci.category_id
    into v_cost_exw, v_category_id
  from public."CatalogItems" ci
  where ci.id = p_catalog_item_id;

  if v_cost_exw is null then
    v_cost_exw := 0;
  end if;

  select
    coalesce(cs.shipping_pct, 0),
    coalesce(cs.import_tax_pct, 0),
    coalesce(cs.minimum_margin_pct, cs.default_margin_pct, v_min_margin_pct),
    coalesce(cs.msrp_pct_sale_out, v_msrp_pct_sale_out)
  into
    v_shipping_pct,
    v_import_tax_pct,
    v_min_margin_pct,
    v_msrp_pct_sale_out
  from public."CostSettings" cs
  where cs.organization_id = p_organization_id
  limit 1;

  if v_category_id is not null then
    select
      coalesce(cm.minimum_margin_pct, v_min_margin_pct),
      coalesce(cm.msrp_pct_sale_out, v_msrp_pct_sale_out)
    into
      v_min_margin_pct,
      v_msrp_pct_sale_out
    from public."CategoryMargins" cm
    where cm.organization_id = p_organization_id
      and cm.category_id = v_category_id
    limit 1;
  end if;

  v_material_cost := v_cost_exw;
  v_shipping_cost := v_material_cost * v_shipping_pct;
  v_import_tax_cost := (v_material_cost + v_shipping_cost) * v_import_tax_pct;
  v_total_cost := v_material_cost + v_shipping_cost + v_import_tax_cost;

  v_msrp_sale_in := round(v_total_cost / nullif(1 - v_min_margin_pct, 0), 4);
  v_msrp_sale_out := round(v_msrp_sale_in / nullif(1 - v_msrp_pct_sale_out, 0), 4);

  insert into public."CatalogItemsMSRP" (
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
    msrp_sale_in,
    msrp_sale_out,
    updated_at
  )
  values (
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
    v_msrp_sale_in,
    v_msrp_sale_out,
    now()
  )
  on conflict (organization_id, catalog_item_id)
  do update set
    cost_exw = excluded.cost_exw,
    shipping_pct = excluded.shipping_pct,
    import_tax_pct = excluded.import_tax_pct,
    minimum_margin_pct = excluded.minimum_margin_pct,
    msrp_pct_sale_out = excluded.msrp_pct_sale_out,

    shipping_cost = excluded.shipping_cost,
    import_tax_cost = excluded.import_tax_cost,
    total_cost = excluded.total_cost,
    msrp_sale_in = excluded.msrp_sale_in,
    msrp_sale_out = excluded.msrp_sale_out,
    updated_at = now();

end;
$$;


-- 3) sync_catalogitems_to_msrp: quitar material_cost del INSERT
CREATE OR REPLACE FUNCTION public.sync_catalogitems_to_msrp() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_cost numeric(12,4);
  v_total numeric(12,4);
BEGIN
  v_cost := COALESCE(NEW.cost_exw, 0);
  v_total := v_cost;

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id, cost_exw,
    import_tax_cost, shipping_cost, total_cost,
    msrp_sale_in, msrp_sale_out,
    shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct_sale_out,

    sku, name, collection_name, variant_name, unit_of_measure
  ) VALUES (
    NEW.id, NEW.organization_id, NEW.category_id, v_cost,
    0, 0, v_total,
    0, 0,
    0, 0, 0.35, 0.65,

    NEW.sku, NEW.name, NEW.collection_name, NEW.variant_name, NEW.unit_of_measure
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    sku             = EXCLUDED.sku,
    name            = EXCLUDED.name,
    collection_name = EXCLUDED.collection_name,
    variant_name    = EXCLUDED.variant_name,
    unit_of_measure = EXCLUDED.unit_of_measure;

  RETURN NEW;
END;
$$;


-- 4) sync_catalogitems_to_msrp_safe: sync SOLO identidad (sku, name, etc.)
--    NO tocar cost_exw ni total_cost en el UPDATE (eso lo maneja msrp_compute_for_item)
--    Si no existe fila, crear con valores mínimos para cumplir NOT NULL
CREATE OR REPLACE FUNCTION "public"."sync_catalogitems_to_msrp_safe"() RETURNS "trigger"
    LANGUAGE "plpgsql"
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

    msrp_sale_in,
    msrp_sale_out,

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
    -- Solo actualizar identidad, NO cost_exw ni total_cost (lo maneja msrp_compute_for_item)
    sku             = EXCLUDED.sku,
    name            = EXCLUDED.name,
    collection_name = EXCLUDED.collection_name,
    variant_name    = EXCLUDED.variant_name,
    unit_of_measure = EXCLUDED.unit_of_measure,
    updated_at      = now();

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION "public"."sync_catalogitems_to_msrp_safe"() IS
'Sync identidad (sku, name, collection_name, variant_name, unit_of_measure) de CatalogItems a CatalogItemsMSRP. Si no existe fila, INSERT con valores mínimos. En UPDATE solo toca identidad, NO cost_exw ni total_cost (eso lo maneja msrp_compute_for_item).';


-- 5) trig_enforce_msrp_sources: quitar la línea que asignaba material_cost
CREATE OR REPLACE FUNCTION "public"."trig_enforce_msrp_sources"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_org uuid;
  v_cat uuid;
  r record;
BEGIN
  v_org := NEW.organization_id;
  v_cat := NEW.category_id;

  IF v_org IS NULL OR v_cat IS NULL THEN
    SELECT organization_id, category_id INTO v_org, v_cat
    FROM public."CatalogItems"
    WHERE id = NEW.catalog_item_id;
    NEW.organization_id := COALESCE(NEW.organization_id, v_org);
    NEW.category_id := COALESCE(NEW.category_id, v_cat);
  END IF;

  IF NEW.organization_id IS NULL OR NEW.category_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO r
  FROM public.msrp_get_effective_rates(NEW.organization_id, NEW.category_id);

  NEW.shipping_pct       := COALESCE(r.shipping_pct, 0);
  NEW.import_tax_pct     := COALESCE(r.import_tax_pct, 0);
  NEW.minimum_margin_pct := COALESCE(r.minimum_margin_pct, 0);
  NEW.msrp_pct_sale_out  := COALESCE(r.msrp_pct_sale_out, 0);

  RETURN NEW;
END;
$$;


-- 6) Eliminar triggers redundantes que causan conflicto
--    a) sync_catalogitems_cost_to_msrp: sobrescribía msrp_sale_in=0, msrp_sale_out=0 sin calcular MSRP real
--    b) trg_sync_catalogitems_to_msrp: duplicado de trg_sync_catalogitems_to_msrp_safe
--    Dejamos solo: trg_recompute_msrp_on_catalog_item_change (msrp_compute_for_item) + trg_sync_catalogitems_to_msrp_safe
DROP TRIGGER IF EXISTS "trg_sync_catalogitems_cost_to_msrp" ON public."CatalogItems";
DROP FUNCTION IF EXISTS public.sync_catalogitems_cost_to_msrp();

DROP TRIGGER IF EXISTS "trg_sync_catalogitems_to_msrp" ON public."CatalogItems";

-- 7) Eliminar la columna material_cost de CatalogItemsMSRP (si existe)
ALTER TABLE public."CatalogItemsMSRP" DROP COLUMN IF EXISTS material_cost;

-- ====================================================
-- FLUJO CORRECTO después de esta migración:
-- ====================================================
-- 1. Usuario edita CatalogItems.cost_exw en el frontend
-- 2. Frontend guarda a CatalogItems.cost_exw (fuente de verdad)
-- 3. Triggers en CatalogItems:
--    a) trg_recompute_msrp_on_catalog_item_change
--       → trig_recompute_msrp_on_catalog_item_change()
--       → msrp_compute_for_item(NEW.id)
--       → Lee CatalogItems.cost_exw
--       → Calcula: shipping_cost, import_tax_cost, total_cost, msrp_sale_in, msrp_sale_out
--       → UPSERT a CatalogItemsMSRP con TODOS los campos calculados
--
--    b) trg_sync_catalogitems_to_msrp_safe
--       → sync_catalogitems_to_msrp_safe()
--       → UPSERT a CatalogItemsMSRP SOLO identidad (sku, name, collection_name, variant_name, unit_of_measure)
--       → NO toca cost_exw, total_cost, ni MSRP (ya calculados por msrp_compute_for_item)
--
-- 4. CatalogItemsMSRP.cost_exw queda sincronizado como espejo de CatalogItems.cost_exw
-- 5. Frontend lee de CatalogItemsMSRP para mostrar Rates tab (cost_exw, msrp_sale_in, msrp_sale_out, etc.)
-- ====================================================
