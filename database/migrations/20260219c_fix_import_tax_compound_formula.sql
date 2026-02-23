-- ============================================================================
-- Migration C: Fix import_tax compound formula in CatalogItemsMSRP
-- Date: 2026-02-19
-- Depends on: 20260219_align_uom_and_pricing_cost.sql
--             20260219b_fix_pricing_cost_exw_conversions.sql
--
-- PROBLEMA
-- ─────────────────────────────────────────────────────────────────────────────
-- Las GENERATED columns actuales usan:
--   shipping_cost   = pricing_cost_exw * shipping_pct
--   import_tax_cost = pricing_cost_exw * import_tax_pct          ← MAL
--   total_cost      = pricing_cost_exw * (1 + shipping_pct + import_tax_pct) ← MAL
--
-- El error: import_tax se aplica SOBRE (cost + shipping), no solo sobre cost.
-- El shipping también paga impuesto de importación.
--
-- FÓRMULA CORRECTA (aduanera estándar)
-- ─────────────────────────────────────────────────────────────────────────────
--   shipping_cost   = pricing_cost_exw × shipping_pct
--   import_tax_cost = (pricing_cost_exw + shipping_cost) × import_tax_pct
--                   = pricing_cost_exw × (1 + shipping_pct) × import_tax_pct
--   total_cost      = pricing_cost_exw + shipping_cost + import_tax_cost
--                   = pricing_cost_exw × (1 + shipping_pct) × (1 + import_tax_pct)
--
-- La diferencia con la fórmula "plana" es el término cruzado s×t:
--   (1+s)(1+t) = 1 + s + t + s·t   vs.   1 + s + t
-- Ejemplo: cost=10, shipping=5%, import=7%
--   Fórmula plana:    total = 10 × 1.12 = 11.20
--   Fórmula correcta: total = 10 × 1.05 × 1.07 = 11.235
--
-- ACCIÓN
-- ─────────────────────────────────────────────────────────────────────────────
-- 1. DROP + ADD de las 3 GENERATED columns con la fórmula correcta.
--    (Postgres no permite ALTER COLUMN en generated columns; drop+add es obligatorio.)
-- 2. Corregir v_total_cost_local en funciones que lo calculan localmente.
-- ============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 1: Recrear GENERATED columns con fórmula correcta
--   Se hace DROP + ADD en una sola transacción.
--   El orden importa: shipping primero (sin dependencia), luego import y total.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1A. Drop las tres columnas GENERATED actuales
ALTER TABLE public."CatalogItemsMSRP"
  DROP COLUMN IF EXISTS shipping_cost,
  DROP COLUMN IF EXISTS import_tax_cost,
  DROP COLUMN IF EXISTS total_cost;

-- 1B. Recrear con fórmula correcta (compuesta)
ALTER TABLE public."CatalogItemsMSRP"
  ADD COLUMN "shipping_cost" numeric
    GENERATED ALWAYS AS (
      round(
        COALESCE(pricing_cost_exw, 0) * COALESCE(shipping_pct, 0),
        4
      )
    ) STORED,

  ADD COLUMN "import_tax_cost" numeric
    GENERATED ALWAYS AS (
      round(
        COALESCE(pricing_cost_exw, 0)
        * (1 + COALESCE(shipping_pct, 0))
        * COALESCE(import_tax_pct, 0),
        4
      )
    ) STORED,

  ADD COLUMN "total_cost" numeric
    GENERATED ALWAYS AS (
      round(
        COALESCE(pricing_cost_exw, 0)
        * (1 + COALESCE(shipping_pct, 0))
        * (1 + COALESCE(import_tax_pct, 0)),
        4
      )
    ) STORED;

-- 1C. Comentarios de documentación
COMMENT ON COLUMN public."CatalogItemsMSRP"."shipping_cost" IS
'GENERATED: pricing_cost_exw × shipping_pct. NO escribir directamente.';

COMMENT ON COLUMN public."CatalogItemsMSRP"."import_tax_cost" IS
'GENERATED: pricing_cost_exw × (1 + shipping_pct) × import_tax_pct.
El impuesto se aplica sobre (costo + envío), no solo sobre el costo base.
NO escribir directamente.';

COMMENT ON COLUMN public."CatalogItemsMSRP"."total_cost" IS
'GENERATED: pricing_cost_exw × (1 + shipping_pct) × (1 + import_tax_pct).
Costo landed por pricing_uom. Base para dealer_price y msrp.
NO escribir directamente.';


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 2: Recalcular dealer_price y msrp (total_cost ya se recalculó automáticamente)
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
WHERE COALESCE(cim.pricing_cost_exw, 0) > 0;


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 3: Corregir funciones que calculan v_total_cost_local localmente
--   Cualquier función que compute total_cost "por su cuenta" debe usar
--   la misma fórmula compuesta que la GENERATED column.
-- ─────────────────────────────────────────────────────────────────────────────

-- 3A. msrp_compute_for_item
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

  -- Fórmula compuesta: import_tax se aplica sobre (cost + shipping)
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
    unit_of_measure, pricing_uom,
    cost_exw, pricing_cost_exw,
    shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct,
    dealer_price, msrp, updated_at
  )
  VALUES (
    p_item_id, v_ci.organization_id, v_ci.category_id,
    v_ci.sku, v_ci.name, v_ci.collection_name, v_ci.variant_name,
    v_ci.unit_of_measure, v_pricing_uom,
    COALESCE(v_ci.cost_exw, 0), v_pricing_cost_exw,
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
'Calcula y persiste CatalogItemsMSRP.
  pricing_uom      = derive_pricing_uom(measure_basis, roll_pricing_mode, is_roll)
  pricing_cost_exw = compute_pricing_cost_exw(cost_exw, purchase_uom, pricing_uom, ...)
  shipping_cost    = pricing_cost_exw × shipping_pct                        [GENERATED]
  import_tax_cost  = pricing_cost_exw × (1+shipping_pct) × import_tax_pct  [GENERATED]
  total_cost       = pricing_cost_exw × (1+shipping_pct) × (1+import_tax_pct) [GENERATED]
  dealer_price     = total_cost / (1 - minimum_margin_pct)
  msrp             = dealer_price / (1 - msrp_pct)
NO escribe columnas GENERATED.';


-- 3B. recompute_catalog_item_msrp
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

  -- Fórmula compuesta: import_tax sobre (cost + shipping)
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
'Recompute CatalogItemsMSRP con fórmula compuesta de import_tax.
import_tax = pricing_cost_exw × (1+shipping_pct) × import_tax_pct.
NO escribe columnas GENERATED.';


-- 3C. trig_enforce_msrp_sources — mismo fix de fórmula en el trigger
CREATE OR REPLACE FUNCTION public."trig_enforce_msrp_sources"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_org uuid;
  v_cat uuid;
  r     record;
  v_tc  numeric;
BEGIN
  v_org := NEW.organization_id;
  v_cat := NEW.category_id;

  IF v_org IS NULL OR v_cat IS NULL THEN
    SELECT organization_id, category_id
    INTO   v_org, v_cat
    FROM   public."CatalogItems"
    WHERE  id = NEW.catalog_item_id;

    NEW.organization_id := COALESCE(NEW.organization_id, v_org);
    NEW.category_id     := COALESCE(NEW.category_id, v_cat);
  END IF;

  IF NEW.organization_id IS NULL OR NEW.category_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO r
  FROM   public.msrp_get_effective_rates(NEW.organization_id, NEW.category_id);

  NEW.shipping_pct       := COALESCE(r.shipping_pct,       0);
  NEW.import_tax_pct     := COALESCE(r.import_tax_pct,     0);
  NEW.minimum_margin_pct := COALESCE(r.minimum_margin_pct, 0);
  NEW.msrp_pct           := COALESCE(r.msrp_pct,           0);

  -- Recompute dealer/msrp usando fórmula compuesta
  IF COALESCE(NEW.pricing_cost_exw, 0) > 0 THEN
    v_tc := round(
      NEW.pricing_cost_exw
      * (1 + NEW.shipping_pct)
      * (1 + NEW.import_tax_pct),
      4
    );
    NEW.dealer_price := round(v_tc / NULLIF(1 - NEW.minimum_margin_pct, 0), 4);
    NEW.msrp         := round(NEW.dealer_price / NULLIF(1 - NEW.msrp_pct, 0), 4);
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public."trig_enforce_msrp_sources"() IS
'BEFORE trigger: sincroniza tasas desde msrp_get_effective_rates.
Si pricing_cost_exw > 0, recomputa dealer/msrp con fórmula compuesta:
  total = pricing_cost_exw × (1+shipping_pct) × (1+import_tax_pct)
NO escribe columnas GENERATED.';


-- ─────────────────────────────────────────────────────────────────────────────
-- PASO 4: VERIFICACIÓN
-- ─────────────────────────────────────────────────────────────────────────────
/*
-- V1. shipping_cost correcto
SELECT
  catalog_item_id,
  pricing_cost_exw                                AS base,
  shipping_pct,
  shipping_cost                                   AS shipping_generated,
  round(pricing_cost_exw * shipping_pct, 4)       AS shipping_expected,
  abs(shipping_cost - round(pricing_cost_exw * shipping_pct, 4)) AS delta_shipping
FROM public."CatalogItemsMSRP"
WHERE pricing_cost_exw > 0
ORDER BY delta_shipping DESC NULLS LAST
LIMIT 10;

-- V2. import_tax_cost correcto (fórmula compuesta)
SELECT
  catalog_item_id,
  pricing_cost_exw                                         AS base,
  shipping_pct,
  import_tax_pct,
  import_tax_cost                                          AS import_generated,
  round(pricing_cost_exw*(1+shipping_pct)*import_tax_pct, 4) AS import_expected,
  abs(import_tax_cost - round(pricing_cost_exw*(1+shipping_pct)*import_tax_pct,4)) AS delta
FROM public."CatalogItemsMSRP"
WHERE pricing_cost_exw > 0
ORDER BY delta DESC NULLS LAST
LIMIT 10;

-- V3. total_cost correcto (fórmula compuesta)
SELECT
  catalog_item_id,
  pricing_cost_exw,
  shipping_pct,
  import_tax_pct,
  total_cost                                                          AS total_generated,
  round(pricing_cost_exw*(1+shipping_pct)*(1+import_tax_pct), 4)    AS total_expected,
  abs(total_cost - round(pricing_cost_exw*(1+shipping_pct)*(1+import_tax_pct),4)) AS delta
FROM public."CatalogItemsMSRP"
WHERE pricing_cost_exw > 0
ORDER BY delta DESC NULLS LAST
LIMIT 10;

-- V4. Ejemplo numérico concreto (shipping=5%, import=7%, cost=10)
-- Fórmula plana (vieja):    total = 10 * 1.12 = 11.20
-- Fórmula compuesta (nueva): total = 10 * 1.05 * 1.07 = 11.235
SELECT
  pricing_cost_exw,
  shipping_pct,
  import_tax_pct,
  shipping_cost,
  import_tax_cost,
  total_cost,
  -- diferencia vs fórmula plana (debe ser ≠ 0 cuando shipping_pct > 0 y import_tax_pct > 0)
  round(pricing_cost_exw*(1+shipping_pct+import_tax_pct), 4) AS total_flat_OLD,
  total_cost - round(pricing_cost_exw*(1+shipping_pct+import_tax_pct),4) AS diff_vs_old
FROM public."CatalogItemsMSRP"
WHERE pricing_cost_exw > 0
  AND shipping_pct > 0
  AND import_tax_pct > 0
LIMIT 20;
*/

COMMIT;
