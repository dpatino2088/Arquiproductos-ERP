-- ============================================================================
-- Migration E: Fix pricing_cost_exw UOM conversion + compound import_tax formula
-- Date: 2026-02-19
-- Estado de producción que corrige (visto en screenshot):
--   pricing_cost_exw = cost_exw (sin conversión yd→m)
--   import_tax_cost  = pricing_cost_exw × import_tax_pct  (fórmula plana, WRONG)
--   total_cost       = pricing_cost_exw × (1+shipping+import)  (plana, WRONG)
--
-- IDEMPOTENTE: puede re-ejecutarse. Usa IF EXISTS / ON CONFLICT / COALESCE.
-- ============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 1: Helpers de conversión (idempotentes con CREATE OR REPLACE)
-- ─────────────────────────────────────────────────────────────────────────────

-- 1A: pricing_uom desde measure_basis + roll_pricing_mode
CREATE OR REPLACE FUNCTION public.derive_pricing_uom(
  p_measure_basis     text,
  p_roll_pricing_mode text,
  p_is_roll           boolean
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_is_roll = true AND p_roll_pricing_mode = 'per_linear_meter'  THEN 'm'
    WHEN p_is_roll = true AND p_roll_pricing_mode = 'per_square_meter'  THEN 'm2'
    WHEN p_is_roll = true AND p_roll_pricing_mode = 'per_unit'          THEN 'ea'
    WHEN p_measure_basis = 'linear'  THEN 'm'
    WHEN p_measure_basis = 'area'    THEN 'm2'
    WHEN p_measure_basis = 'unit'    THEN 'ea'
    ELSE 'ea'
  END;
$$;

-- 1B: Convierte cost_exw (purchase UOM) → pricing_cost_exw (pricing UOM canónico)
CREATE OR REPLACE FUNCTION public.compute_pricing_cost_exw(
  p_cost_exw           numeric,  -- CatalogItems.cost_exw en purchase UOM
  p_purchase_uom       text,     -- CatalogItems.unit_of_measure
  p_pricing_uom        text,     -- 'ea' | 'm' | 'm2'
  p_units_per_purchase numeric,  -- CatalogItems.units_per_purchase_unit
  p_roll_width_m       numeric   -- CatalogItems.roll_width_m (para m2 desde lineal)
)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_cost    numeric := COALESCE(p_cost_exw, 0);
  v_uom     text    := lower(trim(COALESCE(p_purchase_uom, 'ea')));
  v_puom    text    := lower(trim(COALESCE(p_pricing_uom, 'ea')));
  v_units   numeric := COALESCE(NULLIF(p_units_per_purchase, 0), 1);
  v_width   numeric := p_roll_width_m;
  v_per_m   numeric;
BEGIN
  -- ea: normaliza packs/sets
  IF v_puom = 'ea' THEN
    RETURN round(v_cost / v_units, 6);
  END IF;

  -- m: costo por metro lineal
  IF v_puom = 'm' THEN
    IF v_uom IN ('m','meter','meters','mt')         THEN RETURN v_cost; END IF;
    IF v_uom IN ('yd','yard','yards')               THEN RETURN round(v_cost / 0.9144, 6); END IF;
    IF v_uom IN ('ft','foot','feet')                THEN RETURN round(v_cost / 0.3048, 6); END IF;
    IF v_uom IN ('in','inch','inches')              THEN RETURN round(v_cost / 0.0254, 6); END IF;
    RETURN NULL; -- conversión imposible
  END IF;

  -- m2: costo por metro cuadrado
  IF v_puom = 'm2' THEN
    -- purchase UOM ya es área
    IF v_uom IN ('m2','sqm','sq_m','square_meter','square_meters')      THEN RETURN v_cost; END IF;
    IF v_uom IN ('yd2','yard2','sqyd','sq_yd','square_yard','square_yards') THEN
      RETURN round(v_cost / 0.83612736, 6);
    END IF;
    IF v_uom IN ('ft2','foot2','sqft','sq_ft','square_foot','square_feet')  THEN
      RETURN round(v_cost / 0.09290304, 6);
    END IF;
    -- purchase UOM lineal → necesita roll_width_m
    IF v_uom IN ('yd','yard','yards')   THEN v_per_m := round(v_cost / 0.9144, 6); END IF;
    IF v_uom IN ('ft','foot','feet')    THEN v_per_m := round(v_cost / 0.3048, 6); END IF;
    IF v_uom IN ('in','inch','inches')  THEN v_per_m := round(v_cost / 0.0254, 6); END IF;
    IF v_uom IN ('m','meter','meters','mt') THEN v_per_m := v_cost; END IF;

    IF v_per_m IS NOT NULL THEN
      IF v_width IS NOT NULL AND v_width > 0 THEN
        RETURN round(v_per_m / v_width, 6);
      ELSE
        RETURN NULL; -- falta roll_width_m
      END IF;
    END IF;

    RETURN NULL;
  END IF;

  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.compute_pricing_cost_exw(numeric,text,text,numeric,numeric) IS
'Convierte CatalogItems.cost_exw (purchase UOM) a pricing UOM canónico.
  ea : cost / units_per_purchase_unit
  m  : divide por factor lineal (yd→/0.9144, ft→/0.3048, in→/0.0254)
  m2 : divide por factor área o ($/m) / roll_width_m para UOMs lineales
Retorna NULL si conversión imposible.';


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 2: Eliminar constraint duplicado (idempotente)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public."CatalogItemsMSRP"
  DROP CONSTRAINT IF EXISTS "catalogitemsmsrp_pricing_uom_canonical_chk";


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 3: Corregir GENERATED columns — fórmula compuesta
--   import_tax = pricing_cost_exw × (1 + shipping_pct) × import_tax_pct
--   total_cost = pricing_cost_exw × (1 + shipping_pct) × (1 + import_tax_pct)
--
--   El DROP se hace en un ALTER TABLE separado antes del ADD para evitar
--   que Postgres rechace la transacción si hay dependencias.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public."CatalogItemsMSRP"
  DROP COLUMN IF EXISTS shipping_cost,
  DROP COLUMN IF EXISTS import_tax_cost,
  DROP COLUMN IF EXISTS total_cost;

ALTER TABLE public."CatalogItemsMSRP"
  ADD COLUMN "shipping_cost" numeric
      GENERATED ALWAYS AS (
        round(
          COALESCE("pricing_cost_exw", 0) * COALESCE("shipping_pct", 0),
          4
        )
      ) STORED,

  ADD COLUMN "import_tax_cost" numeric
      GENERATED ALWAYS AS (
        round(
          COALESCE("pricing_cost_exw", 0)
          * (1 + COALESCE("shipping_pct", 0))
          * COALESCE("import_tax_pct", 0),
          4
        )
      ) STORED,

  ADD COLUMN "total_cost" numeric
      GENERATED ALWAYS AS (
        round(
          COALESCE("pricing_cost_exw", 0)
          * (1 + COALESCE("shipping_pct", 0))
          * (1 + COALESCE("import_tax_pct", 0)),
          4
        )
      ) STORED;

COMMENT ON COLUMN public."CatalogItemsMSRP"."shipping_cost"    IS 'GENERATED: pricing_cost_exw × shipping_pct. NO escribir.';
COMMENT ON COLUMN public."CatalogItemsMSRP"."import_tax_cost"  IS 'GENERATED: pricing_cost_exw × (1+shipping_pct) × import_tax_pct. Impuesto sobre (costo+envío). NO escribir.';
COMMENT ON COLUMN public."CatalogItemsMSRP"."total_cost"       IS 'GENERATED: pricing_cost_exw × (1+shipping_pct) × (1+import_tax_pct). Base para dealer_price/msrp. NO escribir.';


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 4: Backfill pricing_uom (para filas con NULL o derivación incorrecta)
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE public."CatalogItemsMSRP" cim
SET    pricing_uom = public.derive_pricing_uom(
                       ci.measure_basis,
                       ci.roll_pricing_mode,
                       ci.is_roll
                     )
FROM   public."CatalogItems" ci
WHERE  ci.id              = cim.catalog_item_id
  AND  ci.organization_id = cim.organization_id
  AND  ci.measure_basis   IS NOT NULL;


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 5: Backfill pricing_cost_exw CON conversión UOM real
--   Este es el fix central: yd → m, ft → m, etc.
--   Después de este UPDATE, las GENERATED columns se recalculan automáticamente.
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE public."CatalogItemsMSRP" cim
SET    pricing_cost_exw = public.compute_pricing_cost_exw(
                            COALESCE(ci.cost_exw, 0),
                            ci.unit_of_measure,
                            cim.pricing_uom,
                            ci.units_per_purchase_unit,
                            COALESCE(ci.roll_width_m, ci.roll_width)
                          )
FROM   public."CatalogItems" ci
WHERE  ci.id              = cim.catalog_item_id
  AND  ci.organization_id = cim.organization_id
  AND  COALESCE(ci.cost_exw, 0) > 0;


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 6A: Si pricing_cost_exw = NULL o 0 → dealer_price y msrp deben ser 0.
--   Estas filas tenían valores viejos (del esquema pre-migración) que ya no
--   tienen base de cálculo válida.
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE public."CatalogItemsMSRP"
SET
  dealer_price = 0,
  msrp         = 0,
  updated_at   = now()
WHERE COALESCE(pricing_cost_exw, 0) = 0
  AND (dealer_price != 0 OR msrp != 0);

-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 6B: Recalcular dealer_price y msrp desde total_cost para filas válidas.
--   total_cost fue recalculado automáticamente por la GENERATED column
--   al cambiar pricing_cost_exw en el paso 5.
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE public."CatalogItemsMSRP"
SET
  dealer_price = round(
    total_cost / NULLIF(1 - COALESCE(minimum_margin_pct, 0.35), 0),
    4
  ),
  msrp = round(
    (total_cost / NULLIF(1 - COALESCE(minimum_margin_pct, 0.35), 0))
    / NULLIF(1 - COALESCE(msrp_pct, 0.65), 0),
    4
  ),
  updated_at = now()
WHERE COALESCE(pricing_cost_exw, 0) > 0;


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 7: cost_exw ya fue eliminado de CatalogItemsMSRP en migración anterior.
--         No se requiere acción.
-- ─────────────────────────────────────────────────────────────────────────────


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 8: Actualizar funciones (sin cost_exw en CIM, fórmula compuesta)
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

  -- Si la conversión UOM fue imposible (NULL), pricing = 0
  IF v_pricing_cost_exw IS NULL OR v_pricing_cost_exw = 0 THEN
    v_total_cost_local := 0;
    v_dealer_price     := 0;
    v_msrp             := 0;
  ELSE
    -- Fórmula compuesta (alineada con GENERATED columns)
    v_total_cost_local := round(
      v_pricing_cost_exw
      * (1 + COALESCE(v_shipping_pct, 0))
      * (1 + COALESCE(v_import_tax_pct, 0)),
      4
    );
    v_dealer_price := round(v_total_cost_local / NULLIF(1 - COALESCE(v_min_margin_pct, 0), 0), 4);
    v_msrp         := round(v_dealer_price     / NULLIF(1 - COALESCE(v_msrp_pct, 0), 0),       4);
  END IF;

  -- NO incluye columnas GENERATED (shipping_cost, import_tax_cost, total_cost)
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
'Calcula y persiste CatalogItemsMSRP.
  pricing_uom      = derive_pricing_uom(measure_basis, roll_pricing_mode, is_roll)
  pricing_cost_exw = compute_pricing_cost_exw(cost_exw yd/ft/m → m/m2/ea)
  shipping_cost    = pricing_cost_exw × shipping_pct                        [GENERATED]
  import_tax_cost  = pricing_cost_exw × (1+shipping_pct) × import_tax_pct  [GENERATED]
  total_cost       = pricing_cost_exw × (1+shipping_pct) × (1+import_tax_pct) [GENERATED]
  dealer_price     = total_cost / (1 - minimum_margin_pct)
  msrp             = dealer_price / (1 - msrp_pct)';


CREATE OR REPLACE FUNCTION public."recompute_catalog_item_msrp"(
  "p_organization_id" uuid,
  "p_catalog_item_id" uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_ci               record;
  v_shipping_pct     numeric := 0;
  v_import_tax_pct   numeric := 0;
  v_min_margin_pct   numeric := 0.35;
  v_msrp_pct         numeric := 0.65;
  v_pricing_uom      text;
  v_pricing_cost_exw numeric;
  v_total_cost_local numeric;
  v_dealer_price     numeric;
  v_msrp             numeric;
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
  WHERE cs.organization_id = p_organization_id LIMIT 1;

  SELECT COALESCE(cm.minimum_margin_pct, v_min_margin_pct),
         COALESCE(cm.msrp_pct, v_msrp_pct)
  INTO   v_min_margin_pct, v_msrp_pct
  FROM   public."CategoryMargins" cm
  WHERE  cm.organization_id = p_organization_id
    AND  cm.category_id     = v_ci.category_id
    AND  COALESCE(cm.is_active, true)
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

  IF v_pricing_cost_exw IS NULL OR v_pricing_cost_exw = 0 THEN
    v_total_cost_local := 0;
    v_dealer_price     := 0;
    v_msrp             := 0;
  ELSE
    v_total_cost_local := round(
      v_pricing_cost_exw * (1 + v_shipping_pct) * (1 + v_import_tax_pct), 4
    );
    v_dealer_price := round(v_total_cost_local / NULLIF(1 - v_min_margin_pct, 0), 4);
    v_msrp         := round(v_dealer_price     / NULLIF(1 - v_msrp_pct, 0),       4);
  END IF;

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    unit_of_measure, pricing_uom, pricing_cost_exw,
    shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct,
    dealer_price, msrp, updated_at
  )
  VALUES (
    p_catalog_item_id, p_organization_id, v_ci.category_id,
    v_ci.unit_of_measure, v_pricing_uom, v_pricing_cost_exw,
    v_shipping_pct, v_import_tax_pct, v_min_margin_pct, v_msrp_pct,
    COALESCE(v_dealer_price, 0), COALESCE(v_msrp, 0), now()
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

  -- Recomputa dealer/msrp con fórmula compuesta si hay pricing_cost_exw
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
-- PASO 9: VERIFICACIÓN (descomenta y ejecuta en SQL Editor)
-- ─────────────────────────────────────────────────────────────────────────────
/*
-- 1. Items yd → m: pricing_cost_exw debe ser cost_exw / 0.9144
SELECT
  ci.sku,
  ci.unit_of_measure                                  AS purchase_uom,
  cim.pricing_uom,
  ci.cost_exw                                         AS cost_in_yd,
  cim.pricing_cost_exw                                AS cost_in_m,
  round(ci.cost_exw / 0.9144, 4)                     AS expected_cost_in_m,
  abs(cim.pricing_cost_exw - round(ci.cost_exw/0.9144,4)) AS diff
FROM   public."CatalogItemsMSRP" cim
JOIN   public."CatalogItems"     ci ON ci.id = cim.catalog_item_id
WHERE  ci.unit_of_measure = 'yd'
  AND  cim.pricing_uom    = 'm'
LIMIT 20;

-- 2. Fórmula compuesta: import_tax = pricing_cost_exw × (1+shipping_pct) × import_tax_pct
SELECT
  cim.pricing_cost_exw,
  cim.shipping_pct,
  cim.import_tax_pct,
  cim.shipping_cost,
  cim.import_tax_cost,
  cim.total_cost,
  round(cim.pricing_cost_exw * cim.shipping_pct, 4)                      AS shipping_expected,
  round(cim.pricing_cost_exw * (1+cim.shipping_pct) * cim.import_tax_pct, 4) AS import_expected,
  round(cim.pricing_cost_exw * (1+cim.shipping_pct) * (1+cim.import_tax_pct), 4) AS total_expected
FROM   public."CatalogItemsMSRP" cim
WHERE  cim.pricing_cost_exw > 0
LIMIT 20;

-- 3. Ningún delta debe ser > 0.0001 (diferencias son solo de redondeo)
SELECT
  count(*) FILTER (WHERE abs(shipping_cost   - round(pricing_cost_exw*shipping_pct,4)) > 0.0001)   AS bad_shipping,
  count(*) FILTER (WHERE abs(import_tax_cost - round(pricing_cost_exw*(1+shipping_pct)*import_tax_pct,4)) > 0.0001) AS bad_import,
  count(*) FILTER (WHERE abs(total_cost      - round(pricing_cost_exw*(1+shipping_pct)*(1+import_tax_pct),4)) > 0.0001) AS bad_total
FROM public."CatalogItemsMSRP"
WHERE pricing_cost_exw > 0;

-- 4. Items que no pudieron convertirse (falta roll_width_m para m2)
SELECT ci.sku, ci.unit_of_measure, cim.pricing_uom,
       ci.cost_exw                                AS cost_exw_in_catalogitems,
       COALESCE(ci.roll_width_m, ci.roll_width)   AS roll_width_m
FROM   public."CatalogItemsMSRP" cim
JOIN   public."CatalogItems"     ci ON ci.id = cim.catalog_item_id
WHERE  cim.pricing_cost_exw IS NULL AND COALESCE(ci.cost_exw, 0) > 0;
*/

COMMIT;
