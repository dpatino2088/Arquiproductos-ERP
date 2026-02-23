-- ============================================================================
-- Migration B: Fix pricing_cost_exw conversions & pricing_uom from measure_basis
-- Date: 2026-02-19
-- Depends on: 20260219_align_uom_and_pricing_cost.sql
--
-- HUECOS IDENTIFICADOS EN MIGRACIÓN A
-- ─────────────────────────────────────────────────────────────────────────────
-- 1. pricing_uom derivado solo de roll_pricing_mode ignoraba measure_basis
--    en items no-roll lineales (perfiles, chains, etc.)
--
-- 2. pricing_cost_exw backfilleado con cost_exw sin convertir:
--    - purchase_uom=yd, pricing_uom=m  → pricing_cost_exw estaba en $/yd = ERROR
--    - purchase_uom=ft, pricing_uom=m  → pricing_cost_exw estaba en $/ft = ERROR
--    - purchase_uom=yd/ft, pricing_uom=m2 → necesita ÷ roll_width_m también
--
-- 3. Funciones (msrp_compute_for_item, recompute_catalog_item_msrp) deben
--    calcular pricing_cost_exw con conversión usando uom_factor y roll_width_m.
--
-- FUNCIONES DEL ECOSISTEMA YA DISPONIBLES (no reinventamos)
-- ─────────────────────────────────────────────────────────────────────────────
--   cost_to_per_m(cost, uom)               → $/m desde yd/ft/m  (IMMUTABLE)
--   compute_roll_conversions(cost, uom, w) → ($/m, $/m²)        (IMMUTABLE)
--   uom_factor(from, to)                   → factor numérico     (IMMUTABLE)
--     yd→m=0.9144, ft→m=0.3048, yd²→m²=0.83612736, etc.
--
-- REGLAS DEFINITIVAS
-- ─────────────────────────────────────────────────────────────────────────────
--   pricing_uom:
--     measure_basis='linear' → 'm'
--     measure_basis='area'   → 'm2'
--     measure_basis='unit'   → 'ea'
--     (Para rolls: roll_pricing_mode sigue siendo canónico si está seteado,
--      pero debe ser consistente con measure_basis. Se usa measure_basis como
--      fuente primaria para romper ambigüedad.)
--
--   pricing_cost_exw (por caso):
--     pricing_uom='ea'  → cost_exw / units_per_purchase_unit  (normaliza packs)
--     pricing_uom='m'   → cost_to_per_m(cost_exw, unit_of_measure)
--     pricing_uom='m2'  + uom lineal (yd/ft/m) → $/m ÷ roll_width_m
--     pricing_uom='m2'  + uom área (yd2/ft2)   → cost_exw / uom_factor(uom,'m2')
--     Sin conversión posible → NULL (auditado al final)
-- ============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 1: HELPER INTERNO — compute_pricing_cost_exw
--   Función centralizada que devuelve pricing_cost_exw dado un CatalogItem row.
--   La usan tanto el backfill como las funciones recurrentes (msrp_compute, etc.)
--   No persiste nada; solo retorna el valor calculado.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.compute_pricing_cost_exw(
  p_cost_exw             numeric,   -- CatalogItems.cost_exw (purchase UOM)
  p_purchase_uom         text,      -- CatalogItems.unit_of_measure
  p_pricing_uom          text,      -- pricing_uom canónico: 'ea'|'m'|'m2'
  p_units_per_purchase   numeric,   -- CatalogItems.units_per_purchase_unit (packs)
  p_roll_width_m         numeric    -- CatalogItems.roll_width_m (para m2 desde lineal)
)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_cost        numeric := COALESCE(p_cost_exw, 0);
  v_uom         text    := lower(trim(COALESCE(p_purchase_uom, 'ea')));
  v_pricing_uom text    := lower(trim(COALESCE(p_pricing_uom, 'ea')));
  v_per_unit    numeric := COALESCE(NULLIF(p_units_per_purchase, 0), 1);
  v_width_m     numeric := p_roll_width_m;
  v_per_m       numeric;
BEGIN
  -- ── ea: normaliza packs/sets/boxes a $/unidad
  IF v_pricing_uom = 'ea' THEN
    RETURN round(v_cost / v_per_unit, 6);
  END IF;

  -- ── m: costo por metro lineal
  IF v_pricing_uom = 'm' THEN
    -- Ya está en metros
    IF v_uom IN ('m','meter','meters','mt') THEN
      RETURN v_cost;
    END IF;
    -- Conversión lineal yd/ft/in → m
    IF v_uom IN ('yd','yard','yards') THEN RETURN round(v_cost / 0.9144, 6); END IF;
    IF v_uom IN ('ft','foot','feet')  THEN RETURN round(v_cost / 0.3048, 6); END IF;
    IF v_uom IN ('in','inch','inches') THEN RETURN round(v_cost / 0.0254, 6); END IF;
    -- No es lineal y pricing_uom='m' → imposible sin más info; retorna NULL
    RETURN NULL;
  END IF;

  -- ── m2: costo por metro cuadrado
  IF v_pricing_uom = 'm2' THEN
    -- Caso A: purchase UOM ya es área (yd2, ft2)
    IF v_uom IN ('yd2','yard2','sqyd','sq_yd','square_yard','square_yards') THEN
      RETURN round(v_cost / 0.83612736, 6);
    END IF;
    IF v_uom IN ('ft2','foot2','sqft','sq_ft','square_foot','square_feet') THEN
      RETURN round(v_cost / 0.09290304, 6);
    END IF;
    IF v_uom IN ('m2','sqm','sq_m','square_meter','square_meters') THEN
      RETURN v_cost;
    END IF;

    -- Caso B: purchase UOM es lineal → necesita roll_width_m para llegar a m2
    --   $/m2 = $/m ÷ roll_width_m
    --   $/m  = cost_to_per_m(cost_exw, uom)
    IF v_uom IN ('yd','yard','yards') THEN v_per_m := round(v_cost / 0.9144, 6); END IF;
    IF v_uom IN ('ft','foot','feet')  THEN v_per_m := round(v_cost / 0.3048, 6); END IF;
    IF v_uom IN ('in','inch','inches') THEN v_per_m := round(v_cost / 0.0254, 6); END IF;
    IF v_uom IN ('m','meter','meters','mt') THEN v_per_m := v_cost; END IF;

    IF v_per_m IS NOT NULL THEN
      IF v_width_m IS NOT NULL AND v_width_m > 0 THEN
        RETURN round(v_per_m / v_width_m, 6);
      ELSE
        -- Sin ancho, no podemos completar la conversión → NULL (auditado)
        RETURN NULL;
      END IF;
    END IF;

    -- Caso C: UOM no mapeado (ea, pack, set...) y pricing_uom=m2 → imposible
    RETURN NULL;
  END IF;

  -- pricing_uom desconocido
  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.compute_pricing_cost_exw(numeric, text, text, numeric, numeric) IS
'Convierte CatalogItems.cost_exw (purchase UOM) a pricing_cost_exw (pricing UOM canónico).
  pricing_uom=ea  : cost_exw / units_per_purchase_unit
  pricing_uom=m   : convierte yd/ft/in/m → $/m
  pricing_uom=m2  : convierte yd2/ft2/m2 directamente, o lineal ÷ roll_width_m
Retorna NULL si la conversión no es posible (sin ancho, UOM desconocido).
No persiste nada. Idempotente.';


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 2: HELPER INTERNO — derive_pricing_uom
--   Determina pricing_uom canónico desde measure_basis + roll_pricing_mode.
--   Fuente primaria: measure_basis. Si no hay measure_basis, fallback a
--   roll_pricing_mode. Para rolls, roll_pricing_mode gana sobre measure_basis
--   si está seteado explícitamente.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.derive_pricing_uom(
  p_measure_basis    text,
  p_roll_pricing_mode text,
  p_is_roll          boolean
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    -- Rolls con modo explícito (fuente más precisa para rolls)
    WHEN p_is_roll = true AND p_roll_pricing_mode = 'per_linear_meter'  THEN 'm'
    WHEN p_is_roll = true AND p_roll_pricing_mode = 'per_square_meter'  THEN 'm2'
    WHEN p_is_roll = true AND p_roll_pricing_mode = 'per_unit'          THEN 'ea'
    -- measure_basis canónico (rolls sin modo, y todos los no-rolls)
    WHEN p_measure_basis = 'linear'  THEN 'm'
    WHEN p_measure_basis = 'area'    THEN 'm2'
    WHEN p_measure_basis = 'unit'    THEN 'ea'
    -- Default conservador
    ELSE 'ea'
  END;
$$;

COMMENT ON FUNCTION public.derive_pricing_uom(text, text, boolean) IS
'Determina pricing_uom canónico (ea|m|m2) desde measure_basis y roll_pricing_mode.
Para rolls: roll_pricing_mode tiene prioridad. Para todos: measure_basis es fallback.';


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 3: CORRECCIÓN DE pricing_uom (re-derivar con regla correcta)
--   Ahora usamos derive_pricing_uom(measure_basis, roll_pricing_mode, is_roll)
--   en lugar del CASE anterior que ignoraba measure_basis para no-rolls.
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
  -- Actualiza siempre (sobrescribe el valor incorrecto de la migración A)
  AND  ci.measure_basis IS NOT NULL;


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 4: CORRECCIÓN DE pricing_cost_exw CON CONVERSIÓN REAL
--   Ahora que pricing_uom es correcto, recalcular pricing_cost_exw.
--   Usa compute_pricing_cost_exw (helper definido arriba).
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE public."CatalogItemsMSRP" cim
SET    pricing_cost_exw = public.compute_pricing_cost_exw(
                            ci.cost_exw,
                            ci.unit_of_measure,
                            cim.pricing_uom,
                            ci.units_per_purchase_unit,
                            COALESCE(ci.roll_width_m, ci.roll_width)
                          )
FROM   public."CatalogItems" ci
WHERE  ci.id              = cim.catalog_item_id
  AND  ci.organization_id = cim.organization_id
  AND  ci.cost_exw IS NOT NULL
  AND  ci.cost_exw > 0;


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 5: RECALCULAR dealer_price y msrp PARA TODOS LOS ROWS ACTUALIZADOS
--   total_cost ya es GENERATED (se actualizó solo cuando pricing_cost_exw cambió).
--   Solo necesitamos recomputar dealer_price y msrp.
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE public."CatalogItemsMSRP" cim
SET
  dealer_price = round(
    cim.total_cost / NULLIF(1 - COALESCE(cim.minimum_margin_pct, 0.35), 0),
    4
  ),
  msrp = round(
    (cim.total_cost / NULLIF(1 - COALESCE(cim.minimum_margin_pct, 0.35), 0))
    / NULLIF(1 - COALESCE(cim.msrp_pct, 0.65), 0),
    4
  ),
  updated_at = now()
WHERE cim.pricing_cost_exw IS NOT NULL
  AND cim.pricing_cost_exw > 0;


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 6: REWRITE DE FUNCIONES — incorporar conversión UOM real
-- ─────────────────────────────────────────────────────────────────────────────

-- 6A. msrp_compute_for_item — usa compute_pricing_cost_exw + derive_pricing_uom
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

  -- Tasas efectivas (shipping, import_tax, márgenes)
  SELECT r.shipping_pct, r.import_tax_pct, r.minimum_margin_pct,
         r.msrp_pct_sale_in, r.msrp_pct
  INTO   v_shipping_pct, v_import_tax_pct, v_min_margin_pct,
         v_msrp_pct_sale_in, v_msrp_pct
  FROM   public.msrp_get_effective_rates(v_ci.organization_id, v_ci.category_id) r;

  -- pricing_uom canónico
  v_pricing_uom := public.derive_pricing_uom(
    v_ci.measure_basis,
    v_ci.roll_pricing_mode,
    v_ci.is_roll
  );

  -- pricing_cost_exw con conversión UOM real
  v_pricing_cost_exw := public.compute_pricing_cost_exw(
    COALESCE(v_ci.cost_exw, 0),
    v_ci.unit_of_measure,
    v_pricing_uom,
    v_ci.units_per_purchase_unit,
    v_ci.roll_width_m
  );

  -- total_cost local (alineado con GENERATED column)
  v_total_cost_local := round(
    COALESCE(v_pricing_cost_exw, 0)
    * (1 + COALESCE(v_shipping_pct, 0) + COALESCE(v_import_tax_pct, 0)),
    4
  );

  v_dealer_price := round(v_total_cost_local / NULLIF(1 - COALESCE(v_min_margin_pct, 0), 0), 4);
  v_msrp         := round(v_dealer_price     / NULLIF(1 - COALESCE(v_msrp_pct, 0), 0),       4);

  -- INSERT / UPDATE — NO nombrar shipping_cost, import_tax_cost, total_cost (GENERATED)
  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    sku, name, collection_name, variant_name,
    unit_of_measure,
    pricing_uom,
    cost_exw,
    pricing_cost_exw,
    shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct,
    dealer_price, msrp, updated_at
  )
  VALUES (
    p_item_id, v_ci.organization_id, v_ci.category_id,
    v_ci.sku, v_ci.name, v_ci.collection_name, v_ci.variant_name,
    v_ci.unit_of_measure,
    v_pricing_uom,
    COALESCE(v_ci.cost_exw, 0),
    v_pricing_cost_exw,
    COALESCE(v_shipping_pct,    0),
    COALESCE(v_import_tax_pct,  0),
    COALESCE(v_min_margin_pct,  0),
    COALESCE(v_msrp_pct,        0),
    COALESCE(v_dealer_price,    0),
    COALESCE(v_msrp,            0),
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
    cost_exw           = EXCLUDED.cost_exw,
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
  pricing_cost_exw = compute_pricing_cost_exw(cost_exw, purchase_uom, pricing_uom, ...)
  total_cost       = GENERATED (pricing_cost_exw*(1+shipping+import))
  dealer_price     = total_cost / (1 - minimum_margin_pct)
  msrp             = dealer_price / (1 - msrp_pct)
NO escribe columnas GENERATED (shipping_cost, import_tax_cost, total_cost).';


-- 6B. recompute_catalog_item_msrp — misma lógica, para la versión org-scoped
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

  -- CostSettings base
  SELECT
    COALESCE(cs.shipping_pct, 0),
    COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0),
    COALESCE(cs.minimum_margin_pct, 0.35),
    COALESCE(cs.default_msrp_pct, 0.65)
  INTO v_shipping_pct, v_import_tax_pct, v_min_margin_pct, v_msrp_pct
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_organization_id
  LIMIT 1;

  -- CategoryMargins override
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
    COALESCE(v_pricing_cost_exw, 0) * (1 + v_shipping_pct + v_import_tax_pct), 4
  );
  v_dealer_price := round(v_total_cost_local / NULLIF(1 - v_min_margin_pct, 0), 4);
  v_msrp         := round(v_dealer_price     / NULLIF(1 - v_msrp_pct, 0),       4);

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    unit_of_measure, pricing_uom,
    cost_exw, pricing_cost_exw,
    shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct,
    dealer_price, msrp, updated_at
  )
  VALUES (
    p_catalog_item_id, p_organization_id, v_ci.category_id,
    v_ci.unit_of_measure, v_pricing_uom,
    COALESCE(v_ci.cost_exw, 0), v_pricing_cost_exw,
    v_shipping_pct, v_import_tax_pct, v_min_margin_pct, v_msrp_pct,
    COALESCE(v_dealer_price, 0),
    COALESCE(v_msrp,         0),
    now()
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    cost_exw           = EXCLUDED.cost_exw,
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
'Recompute CatalogItemsMSRP con conversión UOM correcta.
Usa derive_pricing_uom + compute_pricing_cost_exw.
NO escribe columnas GENERATED.';


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 7: AUDITORÍA — SELECT de diagnóstico (ejecutar ANTES y DESPUÉS)
--   Descomenta y corre en Supabase SQL Editor para verificar el estado.
-- ─────────────────────────────────────────────────────────────────────────────

/*
-- A1. Filas con riesgo: purchase_uom ≠ pricing_uom y pricing_cost_exw puede ser incorrecto
SELECT
  cim.catalog_item_id,
  ci.sku,
  ci.name,
  ci.unit_of_measure                 AS purchase_uom,
  cim.pricing_uom,
  ci.cost_exw                        AS cost_exw_purchase,
  cim.pricing_cost_exw,
  cim.total_cost,
  cim.dealer_price,
  cim.msrp,
  ci.measure_basis,
  ci.is_roll,
  ci.roll_pricing_mode,
  COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_m
FROM   public."CatalogItemsMSRP" cim
JOIN   public."CatalogItems"     ci ON ci.id = cim.catalog_item_id
WHERE  ci.unit_of_measure IN ('yd','ft','yd2','ft2')
ORDER  BY ci.unit_of_measure, cim.pricing_uom;

-- A2. Filas m2 que no pudieron convertirse (pricing_cost_exw NULL o 0 con cost_exw > 0)
SELECT
  cim.catalog_item_id,
  ci.sku,
  ci.name,
  ci.unit_of_measure  AS purchase_uom,
  cim.pricing_uom,
  ci.cost_exw,
  cim.pricing_cost_exw,
  COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_m,
  'NEEDS roll_width_m' AS issue
FROM   public."CatalogItemsMSRP" cim
JOIN   public."CatalogItems"     ci ON ci.id = cim.catalog_item_id
WHERE  cim.pricing_uom = 'm2'
  AND  (cim.pricing_cost_exw IS NULL OR cim.pricing_cost_exw = 0)
  AND  ci.cost_exw > 0;

-- A3. Verificar separación purchase vs pricing (muestra 20 filas yd→m)
SELECT
  ci.sku,
  ci.name,
  ci.unit_of_measure                  AS purchase_uom,
  cim.pricing_uom,
  ci.cost_exw                         AS cost_exw_in_yd,
  cim.pricing_cost_exw                AS cost_exw_in_m,
  round(cim.pricing_cost_exw * 0.9144, 4) AS back_to_yd_check,
  abs(ci.cost_exw - round(cim.pricing_cost_exw * 0.9144, 4)) AS diff
FROM   public."CatalogItemsMSRP" cim
JOIN   public."CatalogItems"     ci ON ci.id = cim.catalog_item_id
WHERE  ci.unit_of_measure = 'yd'
  AND  cim.pricing_uom   = 'm'
LIMIT 20;

-- A4. Verificar fórmula total_cost (debe ser 0 diferencia siempre)
SELECT
  catalog_item_id,
  pricing_cost_exw,
  shipping_pct,
  import_tax_pct,
  total_cost                                                          AS generated,
  round(pricing_cost_exw*(1+shipping_pct)*(1+import_tax_pct),4)       AS expected,
  abs(total_cost - round(pricing_cost_exw*(1+shipping_pct)*(1+import_tax_pct),4)) AS delta
FROM   public."CatalogItemsMSRP"
WHERE  pricing_cost_exw > 0
ORDER  BY delta DESC NULLS LAST
LIMIT 10;

-- A5. pricing_uom fuera del set permitido (debe ser 0)
SELECT count(*) AS bad_pricing_uom
FROM   public."CatalogItemsMSRP"
WHERE  pricing_uom NOT IN ('ea','m','m2');

-- A6. pricing_uom NULL que no pudo derivarse (debe ser 0 tras migración)
SELECT count(*) AS null_pricing_uom
FROM   public."CatalogItemsMSRP"
WHERE  pricing_uom IS NULL;

-- A7. pricing_cost_exw NULL con cost_exw > 0 (conversión imposible — requiere acción manual)
SELECT
  cim.catalog_item_id,
  ci.sku,
  ci.name,
  ci.unit_of_measure  AS purchase_uom,
  cim.pricing_uom,
  ci.cost_exw,
  ci.measure_basis,
  COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_m,
  'Cannot convert: missing roll_width_m or unknown UOM' AS action_needed
FROM   public."CatalogItemsMSRP" cim
JOIN   public."CatalogItems"     ci ON ci.id = cim.catalog_item_id
WHERE  cim.pricing_cost_exw IS NULL
  AND  ci.cost_exw > 0
ORDER  BY ci.sku;

-- A8. Resumen por pricing_uom
SELECT
  cim.pricing_uom,
  ci.unit_of_measure   AS purchase_uom,
  count(*)             AS items,
  count(*) FILTER (WHERE cim.pricing_cost_exw IS NULL OR cim.pricing_cost_exw = 0)
                       AS cant_convert
FROM   public."CatalogItemsMSRP" cim
JOIN   public."CatalogItems"     ci ON ci.id = cim.catalog_item_id
GROUP  BY cim.pricing_uom, ci.unit_of_measure
ORDER  BY cim.pricing_uom, ci.unit_of_measure;
*/

COMMIT;
