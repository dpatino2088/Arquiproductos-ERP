-- ============================================================================
-- Migration D: Drop redundant cost_exw from CatalogItemsMSRP
-- Date: 2026-02-19
-- Depends on: 20260219_align_uom_and_pricing_cost.sql (ya hizo DROP NOT NULL)
--             20260219b (funciones con pricing_cost_exw)
--             20260219c (fórmula import_tax compuesta)
--
-- ANÁLISIS DE ELIMINABILIDAD (post-migraciones A/B/C)
-- ─────────────────────────────────────────────────────────────────────────────
-- ✅ cost_exw         → ELIMINABLE. Nadie la lee de CIM. Solo se escribía
--                        como copia informativa de CatalogItems.cost_exw.
--                        La base real de pricing es pricing_cost_exw.
--
-- ❌ shipping_pct     → NO eliminable: es input de la GENERATED column
--                        shipping_cost = pricing_cost_exw × shipping_pct
-- ❌ import_tax_pct   → NO eliminable: input de import_tax_cost GENERATED
-- ❌ minimum_margin_pct → NO eliminable: requerida para calcular dealer_price
--                          desde total_cost (total_cost / (1-min_margin))
-- ❌ msrp_pct         → NO eliminable: requerida para calcular msrp
--                          desde dealer_price (dealer / (1-msrp_pct))
--
-- NOTA: Si en el futuro se quisiera hacer dealer_price y msrp también GENERATED,
-- se necesitaría definirlos como:
--   dealer_price = total_cost / (1 - minimum_margin_pct)  GENERATED
--   msrp         = dealer_price / (1 - msrp_pct)          GENERATED
-- Pero Postgres no soporta GENERATED que referencie otra GENERATED column
-- (restricción del motor), así que no es posible en Supabase/PG actual.
-- ============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 1: DROP cost_exw de CatalogItemsMSRP
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public."CatalogItemsMSRP"
  DROP COLUMN IF EXISTS "cost_exw";


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 2: Actualizar funciones — quitar cost_exw de INSERT/UPDATE en CIM
--   Las funciones siguen leyendo CatalogItems.cost_exw (para pasarlo a
--   compute_pricing_cost_exw), pero ya NO lo persisten en CIM.
-- ─────────────────────────────────────────────────────────────────────────────

-- 2A. msrp_compute_for_item
CREATE OR REPLACE FUNCTION public."msrp_compute_for_item"("p_item_id" uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_ci                 record;
  v_shipping_pct       numeric;
  v_import_tax_pct     numeric;
  v_min_margin_pct     numeric;
  v_msrp_pct_sale_in   numeric;
  v_msrp_pct           numeric;
  v_pricing_uom        text;
  v_pricing_cost_exw   numeric;
  v_total_cost_local   numeric;
  v_dealer_price       numeric;
  v_msrp               numeric;
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

  SELECT r.shipping_pct, r.import_tax_pct, r.minimum_margin_pct,
         r.msrp_pct_sale_in, r.msrp_pct
  INTO   v_shipping_pct, v_import_tax_pct, v_min_margin_pct,
         v_msrp_pct_sale_in, v_msrp_pct
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

  -- Fórmula compuesta: import_tax sobre (cost + shipping)
  v_total_cost_local := round(
    COALESCE(v_pricing_cost_exw, 0)
    * (1 + COALESCE(v_shipping_pct, 0))
    * (1 + COALESCE(v_import_tax_pct, 0)),
    4
  );

  v_dealer_price := round(v_total_cost_local / NULLIF(1 - COALESCE(v_min_margin_pct, 0), 0), 4);
  v_msrp         := round(v_dealer_price     / NULLIF(1 - COALESCE(v_msrp_pct, 0), 0),       4);

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    sku, name, collection_name, variant_name,
    unit_of_measure,
    pricing_uom,
    pricing_cost_exw,
    shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct,
    dealer_price, msrp, updated_at
  )
  VALUES (
    p_item_id, v_ci.organization_id, v_ci.category_id,
    v_ci.sku, v_ci.name, v_ci.collection_name, v_ci.variant_name,
    v_ci.unit_of_measure,
    v_pricing_uom,
    v_pricing_cost_exw,
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
'Calcula y persiste CatalogItemsMSRP para un CatalogItem.
  pricing_uom      = derive_pricing_uom(measure_basis, roll_pricing_mode, is_roll)
  pricing_cost_exw = compute_pricing_cost_exw(CatalogItems.cost_exw, purchase_uom, ...)
  shipping_cost    = pricing_cost_exw × shipping_pct                        [GENERATED]
  import_tax_cost  = pricing_cost_exw × (1+shipping_pct) × import_tax_pct  [GENERATED]
  total_cost       = pricing_cost_exw × (1+shipping_pct) × (1+import_tax_pct) [GENERATED]
  dealer_price     = total_cost / (1 - minimum_margin_pct)
  msrp             = dealer_price / (1 - msrp_pct)
NO almacena cost_exw (purchase cost vive en CatalogItems).
NO escribe columnas GENERATED.';


-- 2B. recompute_catalog_item_msrp
CREATE OR REPLACE FUNCTION public."recompute_catalog_item_msrp"(
  "p_organization_id" uuid,
  "p_catalog_item_id" uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_ci                 record;
  v_shipping_pct       numeric := 0;
  v_import_tax_pct     numeric := 0;
  v_min_margin_pct     numeric := 0.35;
  v_msrp_pct           numeric := 0.65;
  v_pricing_uom        text;
  v_pricing_cost_exw   numeric;
  v_total_cost_local   numeric;
  v_dealer_price       numeric;
  v_msrp               numeric;
BEGIN
  SELECT id, category_id, cost_exw, unit_of_measure,
         units_per_purchase_unit, measure_basis, is_roll, roll_pricing_mode,
         COALESCE(roll_width_m, roll_width) AS roll_width_m
  INTO   v_ci
  FROM   public."CatalogItems"
  WHERE  id = p_catalog_item_id;

  SELECT
    COALESCE(cs.shipping_pct, 0),
    COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0),
    COALESCE(cs.minimum_margin_pct, 0.35),
    COALESCE(cs.default_msrp_pct, 0.65)
  INTO v_shipping_pct, v_import_tax_pct, v_min_margin_pct, v_msrp_pct
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_organization_id
  LIMIT 1;

  SELECT
    COALESCE(cm.minimum_margin_pct, v_min_margin_pct),
    COALESCE(cm.msrp_pct, v_msrp_pct)
  INTO v_min_margin_pct, v_msrp_pct
  FROM public."CategoryMargins" cm
  WHERE cm.organization_id = p_organization_id
    AND cm.category_id     = v_ci.category_id
    AND COALESCE(cm.is_active, true)
  LIMIT 1;

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

  v_total_cost_local := round(
    COALESCE(v_pricing_cost_exw, 0)
    * (1 + v_shipping_pct)
    * (1 + v_import_tax_pct),
    4
  );
  v_dealer_price := round(v_total_cost_local / NULLIF(1 - v_min_margin_pct, 0), 4);
  v_msrp         := round(v_dealer_price     / NULLIF(1 - v_msrp_pct, 0),       4);

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    unit_of_measure, pricing_uom,
    pricing_cost_exw,
    shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct,
    dealer_price, msrp, updated_at
  )
  VALUES (
    p_catalog_item_id, p_organization_id, v_ci.category_id,
    v_ci.unit_of_measure, v_pricing_uom,
    v_pricing_cost_exw,
    v_shipping_pct, v_import_tax_pct, v_min_margin_pct, v_msrp_pct,
    COALESCE(v_dealer_price, 0),
    COALESCE(v_msrp,         0),
    now()
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    pricing_cost_exw   = EXCLUDED.pricing_cost_exw,
    unit_of_measure    = EXCLUDED.unit_of_measure,
    pricing_uom        = EXCLUDED.pricing_uom,
    shipping_pct       = EXCLUDED.shipping_pct,
    import_tax_pct     = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct,
    msrp_pct           = EXCLUDED.msrp_pct,
    dealer_price       = EXCLUDED.dealer_price,
    msrp               = EXCLUDED.msrp,
    updated_at         = now();
END;
$$;

COMMENT ON FUNCTION public."recompute_catalog_item_msrp"(uuid, uuid) IS
'Recompute CatalogItemsMSRP con conversión UOM y fórmula compuesta.
NO almacena cost_exw (purchase cost vive en CatalogItems).
NO escribe columnas GENERATED.';


-- 2C. sync_catalogitems_to_msrp (trigger de identidad)
CREATE OR REPLACE FUNCTION public."sync_catalogitems_to_msrp"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    sku, name, collection_name, variant_name,
    unit_of_measure,
    pricing_uom,
    pricing_cost_exw,
    dealer_price, msrp
  )
  VALUES (
    NEW.id, NEW.organization_id, NEW.category_id,
    NEW.sku, NEW.name, NEW.collection_name, NEW.variant_name,
    NEW.unit_of_measure,
    public.derive_pricing_uom(NEW.measure_basis, NEW.roll_pricing_mode, NEW.is_roll),
    COALESCE(NEW.cost_exw, 0),
    0, 0
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    sku             = EXCLUDED.sku,
    name            = EXCLUDED.name,
    collection_name = EXCLUDED.collection_name,
    variant_name    = EXCLUDED.variant_name,
    unit_of_measure = EXCLUDED.unit_of_measure,
    pricing_uom     = EXCLUDED.pricing_uom,
    category_id     = EXCLUDED.category_id,
    updated_at      = now();
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public."sync_catalogitems_to_msrp"() IS
'Sync identidad + pricing_uom desde CatalogItems a CatalogItemsMSRP.
INSERT: pricing_cost_exw = cost_exw inicial (sin conversión); msrp_compute_for_item corrige después.
ON CONFLICT: solo toca identidad. NO escribe cost_exw en CIM (fue eliminado).
NO escribe columnas GENERATED.';


-- 2D. sync_catalogitems_to_msrp_safe (trigger de identidad)
CREATE OR REPLACE FUNCTION public."sync_catalogitems_to_msrp_safe"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    pricing_cost_exw,
    dealer_price, msrp,
    sku, name, collection_name, variant_name,
    unit_of_measure,
    pricing_uom,
    updated_at
  )
  VALUES (
    NEW.id, NEW.organization_id, NEW.category_id,
    COALESCE(NEW.cost_exw, 0),
    0, 0,
    NEW.sku, NEW.name, NEW.collection_name, NEW.variant_name,
    NEW.unit_of_measure,
    public.derive_pricing_uom(NEW.measure_basis, NEW.roll_pricing_mode, NEW.is_roll),
    now()
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    organization_id = EXCLUDED.organization_id,
    sku             = EXCLUDED.sku,
    name            = EXCLUDED.name,
    collection_name = EXCLUDED.collection_name,
    variant_name    = EXCLUDED.variant_name,
    unit_of_measure = EXCLUDED.unit_of_measure,
    pricing_uom     = EXCLUDED.pricing_uom,
    category_id     = EXCLUDED.category_id,
    updated_at      = now();
    -- pricing_cost_exw y tasas NO se actualizan aquí; lo hace msrp_compute_for_item.
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public."sync_catalogitems_to_msrp_safe"() IS
'Sync identidad + pricing_uom desde CatalogItems a CatalogItemsMSRP.
ON CONFLICT: solo toca identidad. NO toca pricing_cost_exw ni tasas.
NO almacena cost_exw en CIM. NO escribe columnas GENERATED.';


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 3: Verificación rápida
-- ─────────────────────────────────────────────────────────────────────────────
/*
-- cost_exw ya no debe existir en CatalogItemsMSRP
SELECT column_name
FROM   information_schema.columns
WHERE  table_schema = 'public'
  AND  table_name   = 'CatalogItemsMSRP'
ORDER  BY ordinal_position;

-- Columnas definitivas esperadas:
-- catalog_item_id, organization_id, category_id
-- sku, name, collection_name, variant_name
-- unit_of_measure     ← purchase UOM
-- pricing_uom         ← canónico: ea | m | m2
-- pricing_cost_exw    ← costo en pricing UOM
-- shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct  ← tasas
-- shipping_cost       ← GENERATED
-- import_tax_cost     ← GENERATED
-- total_cost          ← GENERATED
-- dealer_price, msrp  ← precios
-- updated_at
*/

COMMIT;
