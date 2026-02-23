-- ============================================================================
-- Migration: Align CatalogItems UOM vs CatalogItemsMSRP pricing_uom
-- Date: 2026-02-19
-- Author: senior-pg-engineer
--
-- ANÁLISIS DEL DUMP v2
-- ─────────────────────────────────────────────────────────────────────────────
-- CatalogItemsMSRP ya tiene en v2:
--   shipping_cost   GENERATED ALWAYS AS (round(pricing_cost_exw * shipping_pct, 4)) STORED
--   import_tax_cost GENERATED ALWAYS AS (round(pricing_cost_exw * import_tax_pct, 4)) STORED  ← FÓRMULA PLANA (corregida en 20260219c)
--   total_cost      GENERATED ALWAYS AS (round(pricing_cost_exw*(1+shipping_pct+import_tax_pct),4)) STORED ← CORREGIDA EN 20260219c
--   pricing_uom     text (nullable, dos constraints duplicados)
--   pricing_cost_exw numeric(12,4) (nullable, sin backfill)
--   cost_exw        numeric(12,4) NOT NULL (legacy, purchase cost)
--
-- PROBLEMAS A RESOLVER
-- 1. Funciones msrp_compute_for_item, recompute_* todavía hacen INSERT/UPDATE
--    nombrando shipping_cost/import_tax_cost/total_cost → ROMPEN en Postgres
--    ("cannot insert into a generated column").
-- 2. Constraint duplicado: catalogitemsmsrp_pricing_uom_canonical_chk (mismo que _chk).
-- 3. cost_exw NOT NULL bloquea inserts donde no hay purchase cost.
-- 4. pricing_cost_exw sin backfill → total_cost = 0 para todos los rows existentes.
-- 5. pricing_uom sin backfill → NULL (viola intención).
-- 6. unit_of_measure en CIM no sincronizado con CatalogItems (purchase UOM).
-- 7. Fórmula de import_tax en funciones era compuesta:
--    import = (cost + shipping) * import_tax_pct
--    La GENERATED column usa: import = cost * import_tax_pct
--    → se alinean todas las funciones a la fórmula de la GENERATED column.
-- ============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECCIÓN 1: SCHEMA FIXES
-- ─────────────────────────────────────────────────────────────────────────────

-- 1A. Eliminar constraint duplicado (conservamos catalogitemsmsrp_pricing_uom_chk)
ALTER TABLE public."CatalogItemsMSRP"
  DROP CONSTRAINT IF EXISTS "catalogitemsmsrp_pricing_uom_canonical_chk";

-- 1B. cost_exw pasa a nullable: es el purchase-UOM cost, no el canónico de pricing.
--     La fuente canónica para cálculos es pricing_cost_exw.
ALTER TABLE public."CatalogItemsMSRP"
  ALTER COLUMN "cost_exw" DROP NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECCIÓN 2: DATA BACKFILLS (sin INSERT…ON CONFLICT; solo UPDATE JOIN)
-- ─────────────────────────────────────────────────────────────────────────────

-- 2A. Sync unit_of_measure → purchase UOM desde CatalogItems
UPDATE public."CatalogItemsMSRP" cim
SET    unit_of_measure = ci.unit_of_measure
FROM   public."CatalogItems" ci
WHERE  ci.id               = cim.catalog_item_id
  AND  ci.organization_id  = cim.organization_id
  AND  cim.unit_of_measure IS DISTINCT FROM ci.unit_of_measure;

-- 2B. Backfill pricing_cost_exw desde CatalogItems.cost_exw donde sea NULL.
--     Suposición inicial: pricing_cost_exw = cost_exw (misma UOM base).
--     Cuando se implemente conversión real (yd→m), este valor se recalculará.
UPDATE public."CatalogItemsMSRP" cim
SET    pricing_cost_exw = COALESCE(ci.cost_exw, 0)
FROM   public."CatalogItems" ci
WHERE  ci.id              = cim.catalog_item_id
  AND  ci.organization_id = cim.organization_id
  AND  cim.pricing_cost_exw IS NULL;

-- 2C. Backfill pricing_uom desde roll_pricing_mode (rolls) o 'ea' (no-rolls).
UPDATE public."CatalogItemsMSRP" cim
SET    pricing_uom = CASE
         WHEN ci.is_roll = true THEN
           CASE ci.roll_pricing_mode
             WHEN 'per_linear_meter'  THEN 'm'
             WHEN 'per_square_meter'  THEN 'm2'
             WHEN 'per_unit'          THEN 'ea'
             ELSE 'm'   -- default roll sin modo explícito
           END
         ELSE 'ea'
       END
FROM   public."CatalogItems" ci
WHERE  ci.id              = cim.catalog_item_id
  AND  ci.organization_id = cim.organization_id
  AND  cim.pricing_uom IS NULL;

-- 2D. Actualizar dealer_price y msrp para rows donde pricing_cost_exw > 0 pero
--     dealer_price/msrp siguen siendo 0 (consecuencia del backfill anterior).
--     La fórmula usa total_cost GENERATED (ya computada) y las tasas de margen.
UPDATE public."CatalogItemsMSRP" cim
SET
  dealer_price = round(cim.total_cost / NULLIF(1 - COALESCE(cim.minimum_margin_pct, 0.35), 0), 4),
  msrp         = round(
                   (cim.total_cost / NULLIF(1 - COALESCE(cim.minimum_margin_pct, 0.35), 0))
                   / NULLIF(1 - COALESCE(cim.msrp_pct, 0.65), 0),
                 4)
WHERE cim.pricing_cost_exw > 0
  AND (cim.dealer_price = 0 OR cim.msrp = 0);

-- ─────────────────────────────────────────────────────────────────────────────
-- SECCIÓN 3: REWRITE DE FUNCIONES
--   Regla: NUNCA nombrar shipping_cost, import_tax_cost, total_cost en INSERT/UPDATE.
--   Solo escribir pricing_cost_exw; las GENERATED columns se computan solas.
--   Fórmula alineada con GENERATED column:
--     total_cost_local = pricing_cost_exw * (1 + shipping_pct + import_tax_pct)
-- ─────────────────────────────────────────────────────────────────────────────

-- 3A. msrp_compute_for_item
CREATE OR REPLACE FUNCTION public."msrp_compute_for_item"("p_item_id" uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_org_id         uuid;
  v_category_id    uuid;
  v_cost_exw       numeric;  -- purchase UOM cost (from CatalogItems)
  v_unit_of_measure text;
  v_is_roll        boolean;
  v_roll_pricing_mode text;

  v_shipping_pct       numeric;
  v_import_tax_pct     numeric;
  v_min_margin_pct     numeric;
  v_msrp_pct_sale_in   numeric;
  v_msrp_pct           numeric;

  v_pricing_cost_exw   numeric;
  v_pricing_uom        text;
  v_total_cost_local   numeric;
  v_dealer_price       numeric;
  v_msrp               numeric;
BEGIN
  SELECT organization_id, category_id, COALESCE(cost_exw, 0),
         unit_of_measure, is_roll, roll_pricing_mode
  INTO   v_org_id, v_category_id, v_cost_exw,
         v_unit_of_measure, v_is_roll, v_roll_pricing_mode
  FROM   public."CatalogItems"
  WHERE  id = p_item_id;

  IF v_org_id IS NULL THEN RETURN; END IF;

  -- Tasas efectivas (shipping, import_tax, márgenes)
  SELECT r.shipping_pct, r.import_tax_pct, r.minimum_margin_pct,
         r.msrp_pct_sale_in, r.msrp_pct
  INTO   v_shipping_pct, v_import_tax_pct, v_min_margin_pct,
         v_msrp_pct_sale_in, v_msrp_pct
  FROM   public.msrp_get_effective_rates(v_org_id, v_category_id) r;

  -- pricing_cost_exw = cost_exw (punto de partida; conversión UOM futura aquí)
  v_pricing_cost_exw := COALESCE(v_cost_exw, 0);

  -- pricing_uom derivado de roll_pricing_mode
  v_pricing_uom := CASE
    WHEN v_is_roll = true THEN
      CASE v_roll_pricing_mode
        WHEN 'per_linear_meter' THEN 'm'
        WHEN 'per_square_meter' THEN 'm2'
        WHEN 'per_unit'         THEN 'ea'
        ELSE 'm'
      END
    ELSE 'ea'
  END;

  -- total_cost local (fórmula = GENERATED column formula)
  v_total_cost_local := round(
    v_pricing_cost_exw * (1
      + COALESCE(v_shipping_pct, 0)
      + COALESCE(v_import_tax_pct, 0)),
    4
  );

  -- dealer_price y msrp
  v_dealer_price := round(v_total_cost_local / NULLIF(1 - COALESCE(v_min_margin_pct, 0), 0), 4);
  v_msrp         := round(v_dealer_price     / NULLIF(1 - COALESCE(v_msrp_pct, 0), 0),       4);

  -- INSERT / UPDATE — NO nombrar shipping_cost, import_tax_cost, total_cost (GENERATED)
  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    sku, name, collection_name, variant_name,
    unit_of_measure,    -- purchase UOM
    pricing_uom,        -- canónico de pricing
    cost_exw,           -- purchase UOM cost (informativo)
    pricing_cost_exw,   -- base del cálculo de costos
    shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct,
    dealer_price, msrp, updated_at
  )
  SELECT
    p_item_id, v_org_id, v_category_id,
    ci.sku, ci.name, ci.collection_name, ci.variant_name,
    ci.unit_of_measure,
    v_pricing_uom,
    v_cost_exw,
    v_pricing_cost_exw,
    COALESCE(v_shipping_pct,    0),
    COALESCE(v_import_tax_pct,  0),
    COALESCE(v_min_margin_pct,  0),
    COALESCE(v_msrp_pct,        0),
    COALESCE(v_dealer_price,    0),
    COALESCE(v_msrp,            0),
    now()
  FROM public."CatalogItems" ci
  WHERE ci.id = p_item_id
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    organization_id   = EXCLUDED.organization_id,
    category_id       = EXCLUDED.category_id,
    unit_of_measure   = EXCLUDED.unit_of_measure,
    pricing_uom       = EXCLUDED.pricing_uom,
    cost_exw          = EXCLUDED.cost_exw,
    pricing_cost_exw  = EXCLUDED.pricing_cost_exw,
    shipping_pct      = EXCLUDED.shipping_pct,
    import_tax_pct    = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct,
    msrp_pct          = EXCLUDED.msrp_pct,
    dealer_price      = EXCLUDED.dealer_price,
    msrp              = EXCLUDED.msrp,
    updated_at        = now();
END;
$$;

COMMENT ON FUNCTION public."msrp_compute_for_item"(uuid) IS
'Calcula MSRP para un CatalogItem.
Regla (alineada con GENERATED columns):
  total_cost      = pricing_cost_exw * (1 + shipping_pct + import_tax_pct)
  dealer_price    = total_cost / (1 - minimum_margin_pct)
  msrp            = dealer_price / (1 - msrp_pct)
NO escribe shipping_cost, import_tax_cost, total_cost (son GENERATED ALWAYS STORED).
pricing_uom derivado de CatalogItems.roll_pricing_mode.';


-- 3B. recompute_catalog_item_msrp
CREATE OR REPLACE FUNCTION public."recompute_catalog_item_msrp"(
  "p_organization_id" uuid,
  "p_catalog_item_id" uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_cost_exw           numeric;
  v_category_id        uuid;
  v_unit_of_measure    text;
  v_is_roll            boolean;
  v_roll_pricing_mode  text;

  v_shipping_pct       numeric := 0;
  v_import_tax_pct     numeric := 0;
  v_min_margin_pct     numeric := 0.35;
  v_msrp_pct           numeric := 0.65;

  v_pricing_cost_exw   numeric;
  v_pricing_uom        text;
  v_total_cost_local   numeric;
  v_dealer_price       numeric;
  v_msrp               numeric;
BEGIN
  SELECT cost_exw, category_id, unit_of_measure, is_roll, roll_pricing_mode
  INTO   v_cost_exw, v_category_id, v_unit_of_measure, v_is_roll, v_roll_pricing_mode
  FROM   public."CatalogItems"
  WHERE  id = p_catalog_item_id;

  IF v_cost_exw IS NULL OR v_cost_exw < 0 THEN
    v_cost_exw := 0;
  END IF;

  -- Tasas org (CostSettings → CategoryMargins override)
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
    AND cm.category_id     = v_category_id
    AND COALESCE(cm.is_active, true)
  LIMIT 1;

  v_pricing_cost_exw := v_cost_exw;

  v_pricing_uom := CASE
    WHEN v_is_roll = true THEN
      CASE v_roll_pricing_mode
        WHEN 'per_linear_meter' THEN 'm'
        WHEN 'per_square_meter' THEN 'm2'
        WHEN 'per_unit'         THEN 'ea'
        ELSE 'm'
      END
    ELSE 'ea'
  END;

  v_total_cost_local := round(
    v_pricing_cost_exw * (1 + v_shipping_pct + v_import_tax_pct), 4
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
  SELECT
    p_catalog_item_id, p_organization_id, v_category_id,
    v_unit_of_measure, v_pricing_uom,
    v_cost_exw, v_pricing_cost_exw,
    v_shipping_pct, v_import_tax_pct, v_min_margin_pct, v_msrp_pct,
    COALESCE(v_dealer_price, 0),
    COALESCE(v_msrp,         0),
    now()
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
'Recompute CatalogItemsMSRP. Usa pricing_cost_exw (= cost_exw por ahora).
NO escribe columnas GENERATED (shipping_cost, import_tax_cost, total_cost).
pricing_uom derivado de roll_pricing_mode.';


-- 3C. recompute_catalogitems_msrp_for_category
--     Era una SQL function con INSERT inline. Reescrita como PLPGSQL para poder
--     excluir columnas GENERATED del INSERT.
CREATE OR REPLACE FUNCTION public."recompute_catalogitems_msrp_for_category"(
  "p_org_id"     uuid,
  "p_category_id" uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_item RECORD;
BEGIN
  FOR v_item IN
    WITH RECURSIVE descendants(category_id) AS (
      SELECT id FROM public."CatalogCategories" WHERE id = p_category_id
      UNION ALL
      SELECT cc.id
      FROM   public."CatalogCategories" cc
      JOIN   descendants d ON cc.parent_id = d.category_id
    )
    SELECT ci.id
    FROM   public."CatalogItems" ci
    WHERE  ci.organization_id = p_org_id
      AND  ci.category_id IN (SELECT category_id FROM descendants)
      AND  ci.is_active = true
  LOOP
    PERFORM public."recompute_catalog_item_msrp"(p_org_id, v_item.id);
  END LOOP;
END;
$$;

COMMENT ON FUNCTION public."recompute_catalogitems_msrp_for_category"(uuid, uuid) IS
'Recompute CatalogItemsMSRP para una categoría y sus descendientes.
Delega en recompute_catalog_item_msrp (no escribe columnas GENERATED).';


-- 3D. recompute_catalogitems_msrp_for_org
CREATE OR REPLACE FUNCTION public."recompute_catalogitems_msrp_for_org"("p_org" uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_item RECORD;
BEGIN
  FOR v_item IN
    SELECT id
    FROM   public."CatalogItems"
    WHERE  organization_id = p_org
      AND  is_active = true
  LOOP
    PERFORM public."recompute_catalog_item_msrp"(p_org, v_item.id);
  END LOOP;
END;
$$;

COMMENT ON FUNCTION public."recompute_catalogitems_msrp_for_org"(uuid) IS
'Recompute CatalogItemsMSRP para toda la org.
Delega en recompute_catalog_item_msrp (no escribe columnas GENERATED).';


-- 3E. sync_catalogitems_to_msrp (trigger)
--     Eliminar shipping_cost, import_tax_cost, total_cost del INSERT (son GENERATED).
--     Agregar pricing_cost_exw y pricing_uom.
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
    cost_exw,
    pricing_cost_exw,
    dealer_price, msrp
  )
  VALUES (
    NEW.id, NEW.organization_id, NEW.category_id,
    NEW.sku, NEW.name, NEW.collection_name, NEW.variant_name,
    NEW.unit_of_measure,
    CASE
      WHEN NEW.is_roll = true THEN
        CASE NEW.roll_pricing_mode
          WHEN 'per_linear_meter' THEN 'm'
          WHEN 'per_square_meter' THEN 'm2'
          WHEN 'per_unit'         THEN 'ea'
          ELSE 'm'
        END
      ELSE 'ea'
    END,
    COALESCE(NEW.cost_exw, 0),
    COALESCE(NEW.cost_exw, 0),
    0, 0
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    sku              = EXCLUDED.sku,
    name             = EXCLUDED.name,
    collection_name  = EXCLUDED.collection_name,
    variant_name     = EXCLUDED.variant_name,
    unit_of_measure  = EXCLUDED.unit_of_measure,
    pricing_uom      = EXCLUDED.pricing_uom,
    category_id      = EXCLUDED.category_id,
    updated_at       = now();

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public."sync_catalogitems_to_msrp"() IS
'Sync identity + pricing_uom desde CatalogItems a CatalogItemsMSRP.
Si no existe fila: INSERT con pricing_cost_exw = cost_exw, dealer_price/msrp = 0.
ON CONFLICT: solo actualiza identidad, NO toca pricing (lo maneja msrp_compute_for_item).
NO escribe columnas GENERATED (shipping_cost, import_tax_cost, total_cost).';


-- 3F. sync_catalogitems_to_msrp_safe (trigger)
CREATE OR REPLACE FUNCTION public."sync_catalogitems_to_msrp_safe"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    cost_exw,
    pricing_cost_exw,
    dealer_price, msrp,
    sku, name, collection_name, variant_name,
    unit_of_measure,
    pricing_uom,
    updated_at
  )
  VALUES (
    NEW.id,
    NEW.organization_id,
    NEW.category_id,
    COALESCE(NEW.cost_exw, 0),
    COALESCE(NEW.cost_exw, 0),
    0,
    0,
    NEW.sku,
    NEW.name,
    NEW.collection_name,
    NEW.variant_name,
    NEW.unit_of_measure,
    CASE
      WHEN NEW.is_roll = true THEN
        CASE NEW.roll_pricing_mode
          WHEN 'per_linear_meter' THEN 'm'
          WHEN 'per_square_meter' THEN 'm2'
          WHEN 'per_unit'         THEN 'ea'
          ELSE 'm'
        END
      ELSE 'ea'
    END,
    now()
  )
  ON CONFLICT (catalog_item_id)
  DO UPDATE SET
    organization_id  = EXCLUDED.organization_id,
    sku              = EXCLUDED.sku,
    name             = EXCLUDED.name,
    collection_name  = EXCLUDED.collection_name,
    variant_name     = EXCLUDED.variant_name,
    unit_of_measure  = EXCLUDED.unit_of_measure,
    pricing_uom      = EXCLUDED.pricing_uom,
    category_id      = EXCLUDED.category_id,
    updated_at       = now();
    -- NOTA: NO se actualiza cost_exw ni pricing_cost_exw aquí;
    -- eso lo maneja msrp_compute_for_item vía el trigger trg_recompute_msrp_on_catalog_item_change.

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public."sync_catalogitems_to_msrp_safe"() IS
'Sync identity + pricing_uom desde CatalogItems a CatalogItemsMSRP.
Si no existe fila: INSERT mínimo con pricing_cost_exw = cost_exw.
ON CONFLICT: solo toca identidad, NO cost_exw ni pricing_cost_exw (lo maneja msrp_compute_for_item).
NO escribe columnas GENERATED (shipping_cost, import_tax_cost, total_cost).';


-- ─────────────────────────────────────────────────────────────────────────────
-- SECCIÓN 4: TRIGGER trig_enforce_msrp_sources
--   Actualmente escribe shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct
--   en NEW (BEFORE trigger). Esas son columnas reales (no generated), OK.
--   Pero NO compute dealer_price/msrp aquí (lo hace la función llamante).
--   Re-creamos para asegurar que no toque columnas GENERATED.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public."trig_enforce_msrp_sources"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_org uuid;
  v_cat uuid;
  r     record;
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

  -- Solo actualiza tasas (no generated columns)
  NEW.shipping_pct      := COALESCE(r.shipping_pct,    0);
  NEW.import_tax_pct    := COALESCE(r.import_tax_pct,  0);
  NEW.minimum_margin_pct := COALESCE(r.minimum_margin_pct, 0);
  NEW.msrp_pct          := COALESCE(r.msrp_pct,        0);

  -- Recompute dealer/msrp usando pricing_cost_exw + tasas actualizadas.
  -- total_cost local para este trigger (la GENERATED column se computará con valores finales).
  IF COALESCE(NEW.pricing_cost_exw, 0) > 0 THEN
    DECLARE
      v_tc numeric;
    BEGIN
      v_tc := round(
        NEW.pricing_cost_exw * (1 + NEW.shipping_pct) * (1 + NEW.import_tax_pct), 4
      );
      NEW.dealer_price := round(v_tc / NULLIF(1 - NEW.minimum_margin_pct, 0), 4);
      NEW.msrp         := round(NEW.dealer_price / NULLIF(1 - NEW.msrp_pct, 0), 4);
    END;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public."trig_enforce_msrp_sources"() IS
'BEFORE trigger: sincroniza shipping_pct/import_tax_pct/minimum_margin_pct/msrp_pct
desde msrp_get_effective_rates. Si pricing_cost_exw > 0, recomputa dealer_price/msrp.
NO escribe a columnas GENERATED (shipping_cost, import_tax_cost, total_cost).';


-- ─────────────────────────────────────────────────────────────────────────────
-- SECCIÓN 5: RE-RUN pricing para todos los rows existentes
--   Ahora que pricing_cost_exw fue backfilleado y las funciones están correctas,
--   recalculamos dealer_price/msrp con la fórmula nueva.
--   Se hace UPDATE directo para no disparar el trigger de recompute (evitar N²).
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
-- SECCIÓN 6: COMENTARIOS / DOCUMENTACIÓN de columnas
-- ─────────────────────────────────────────────────────────────────────────────
COMMENT ON COLUMN public."CatalogItemsMSRP"."unit_of_measure" IS
'UOM de compra/origen del suplidor (ej: yd, ft, ea, set, box, pack).
Copia de CatalogItems.unit_of_measure. Solo informativo para compras; NO usar para pricing.';

COMMENT ON COLUMN public."CatalogItemsMSRP"."pricing_uom" IS
'UOM canónico de pricing. Solo valores: ea | m | m2.
Derivado de CatalogItems.roll_pricing_mode (rolls) o ea (no-rolls).
El precio msrp/dealer_price está expresado en esta UOM.';

COMMENT ON COLUMN public."CatalogItemsMSRP"."cost_exw" IS
'Costo EXW en la UOM de compra (purchase_uom). Informativo. Puede diferir de pricing_cost_exw
si el suplidor vende en yd/ft y pricing usa m/m2.';

COMMENT ON COLUMN public."CatalogItemsMSRP"."pricing_cost_exw" IS
'Costo EXW normalizado a pricing_uom (ea/m/m2). BASE de todos los cálculos de pricing.
shipping_cost, import_tax_cost, total_cost son GENERATED desde este valor.';

COMMENT ON COLUMN public."CatalogItemsMSRP"."shipping_cost" IS
'GENERATED ALWAYS AS (round(pricing_cost_exw * shipping_pct, 4)) STORED.
NO escribir directamente.';

COMMENT ON COLUMN public."CatalogItemsMSRP"."import_tax_cost" IS
'GENERATED ALWAYS AS (round(pricing_cost_exw*(1+shipping_pct)*import_tax_pct,4)) STORED.
Fórmula compuesta: import_tax se aplica sobre (pricing_cost_exw + shipping_cost).
Ver migración 20260219c para la definición final. NO escribir directamente.';

COMMENT ON COLUMN public."CatalogItemsMSRP"."total_cost" IS
'GENERATED ALWAYS AS (round(pricing_cost_exw*(1+shipping_pct)*(1+import_tax_pct),4)) STORED.
Fórmula compuesta: total = base * (1+shipping) * (1+import). Ver migración 20260219c.
Costo landed por pricing_uom. Base para dealer_price y msrp. NO escribir directamente.';


-- ─────────────────────────────────────────────────────────────────────────────
-- SECCIÓN 7: VERIFICACIÓN (comentada; ejecutar manualmente para confirmar)
-- ─────────────────────────────────────────────────────────────────────────────

/*
-- V1. pricing_uom fuera del set permitido (debe ser 0)
SELECT count(*)
FROM   public."CatalogItemsMSRP"
WHERE  pricing_uom NOT IN ('ea','m','m2');

-- V2. pricing_uom NULL sin backfill (debe ser 0 tras la migración)
SELECT count(*)
FROM   public."CatalogItemsMSRP"
WHERE  pricing_uom IS NULL;

-- V3. Separación purchase vs pricing: items con unit_of_measure yd/ft y pricing_uom m
SELECT cim.catalog_item_id, ci.sku, ci.name,
       cim.unit_of_measure   AS purchase_uom,
       cim.pricing_uom       AS pricing_uom,
       cim.pricing_cost_exw, cim.total_cost,
       cim.dealer_price,     cim.msrp
FROM   public."CatalogItemsMSRP" cim
JOIN   public."CatalogItems"     ci  ON ci.id = cim.catalog_item_id
WHERE  cim.unit_of_measure IN ('yd','ft')
  AND  cim.pricing_uom = 'm'
LIMIT 20;

-- V4. Verificar fórmula: total_cost ≈ pricing_cost_exw*(1+shipping_pct+import_tax_pct)
SELECT catalog_item_id,
       pricing_cost_exw,
       shipping_pct,
       import_tax_pct,
       total_cost AS total_generated,
       round(pricing_cost_exw * (1 + shipping_pct + import_tax_pct), 4) AS total_expected,
       abs(total_cost - round(pricing_cost_exw * (1 + shipping_pct + import_tax_pct), 4)) AS diff
FROM   public."CatalogItemsMSRP"
WHERE  pricing_cost_exw > 0
ORDER  BY diff DESC NULLS LAST
LIMIT 20;

-- V5. shipping_cost / import_tax_cost nunca NULL (GENERATED devuelve 0 si pricing_cost_exw=0)
SELECT count(*) FILTER (WHERE shipping_cost    IS NULL) AS null_shipping,
       count(*) FILTER (WHERE import_tax_cost  IS NULL) AS null_import,
       count(*) FILTER (WHERE total_cost        IS NULL) AS null_total
FROM   public."CatalogItemsMSRP";

-- V6. dealer_price y msrp > 0 para items con pricing_cost_exw > 0
SELECT count(*) FILTER (WHERE dealer_price = 0 OR msrp = 0) AS zero_prices,
       count(*) AS total
FROM   public."CatalogItemsMSRP"
WHERE  pricing_cost_exw > 0;

-- V7. Constraints: solo debe existir catalogitemsmsrp_pricing_uom_chk (no _canonical_chk)
SELECT conname, pg_get_constraintdef(oid)
FROM   pg_constraint
WHERE  conrelid = 'public."CatalogItemsMSRP"'::regclass
  AND  contype = 'c'
ORDER BY conname;
*/

COMMIT;
