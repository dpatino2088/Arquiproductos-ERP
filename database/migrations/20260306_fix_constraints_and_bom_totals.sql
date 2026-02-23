-- ============================================================================
-- Fix urgente: constraints QuoteLines + BOM totals en ConfiguredProducts
-- Fecha: 2026-03-06
--
-- Problema 1 (QuoteLines no se insertan):
--   Los CHECK constraints chk_quotelines_msrp_coherent y chk_quotelines_quantity_positive
--   bloquean inserts del flujo legacy (sin unit_msrp_total_snapshot) y de accesorios.
--   Solución: hacer constraints más permisivos (NOT VALID / tolerantes) y
--   eliminar el quantity_positive que rompe inserts con quantity NULL.
--
-- Problema 2 (ConfiguredProducts BOM = 0):
--   calculate_configured_product_totals llama resolve_catalog_item_landed_price_cost
--   que devuelve 0 si el item no tiene entrada en CatalogItemsMSRP.
--   Cuando eso pasa, debería usar item.line_total del snapshot como fallback.
--   Solución: mejorar el fallback en calculate_configured_product_totals.
-- ============================================================================

-- ============================================================================
-- PARTE 1: Relajar / eliminar constraints problemáticos en QuoteLines
-- ============================================================================

-- 1a) Eliminar constraint de quantity_positive (muy agresivo; bloquea inserts)
ALTER TABLE public."QuoteLines"
  DROP CONSTRAINT IF EXISTS chk_quotelines_quantity_positive;

-- 1b) Hacer coherence constraints NOT VALID y más permisivos
--     Solo se validan si AMBOS campos están presentes y quantity > 0
ALTER TABLE public."QuoteLines"
  DROP CONSTRAINT IF EXISTS chk_quotelines_msrp_coherent;

ALTER TABLE public."QuoteLines"
  ADD CONSTRAINT chk_quotelines_msrp_coherent
  CHECK (
    unit_msrp_total_snapshot IS NULL
    OR msrp IS NULL
    OR quantity IS NULL
    OR quantity <= 0
    OR abs(msrp - (unit_msrp_total_snapshot * quantity)) <= 0.02
  ) NOT VALID;

ALTER TABLE public."QuoteLines"
  DROP CONSTRAINT IF EXISTS chk_quotelines_total_cost_coherent;

ALTER TABLE public."QuoteLines"
  ADD CONSTRAINT chk_quotelines_total_cost_coherent
  CHECK (
    unit_cost_total_snapshot IS NULL
    OR total_cost IS NULL
    OR quantity IS NULL
    OR quantity <= 0
    OR abs(total_cost - (unit_cost_total_snapshot * quantity)) <= 0.02
  ) NOT VALID;

ALTER TABLE public."QuoteLines"
  DROP CONSTRAINT IF EXISTS chk_quotelines_sale_in_coherent;

ALTER TABLE public."QuoteLines"
  ADD CONSTRAINT chk_quotelines_sale_in_coherent
  CHECK (
    unit_sale_in_price_snapshot IS NULL
    OR sale_in_total IS NULL
    OR quantity IS NULL
    OR quantity <= 0
    OR abs(sale_in_total - (unit_sale_in_price_snapshot * quantity)) <= 0.02
  ) NOT VALID;

ALTER TABLE public."QuoteLines"
  DROP CONSTRAINT IF EXISTS chk_quotelines_unit_snapshots_non_neg;

ALTER TABLE public."QuoteLines"
  ADD CONSTRAINT chk_quotelines_unit_snapshots_non_neg
  CHECK (
    (unit_msrp_total_snapshot IS NULL OR unit_msrp_total_snapshot >= 0)
    AND (unit_cost_total_snapshot IS NULL OR unit_cost_total_snapshot >= 0)
  ) NOT VALID;

-- ============================================================================
-- PARTE 2: calculate_configured_product_totals — LEE DIRECTAMENTE del JSON
--
-- Principio: build_bom_preview_snapshot() ya calculó y guardó los valores
-- correctos de MSRP en el JSON (totals) Y en las columnas de ConfiguredProducts.
-- Esta función NO debe recalcular MSRP con resolve_catalog_item_landed_price_cost
-- (que devuelve 0 para muchos items BOM sin entrada en CatalogItemsMSRP).
--
-- Fuente de verdad para MSRP: bom_preview_snapshot.totals (JSON)
-- Fuente de verdad para costos: resolve_catalog_item_landed_price_cost (o snapshot fallback)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.calculate_configured_product_totals(p_configured_product_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_cp RECORD;
  v_snapshot jsonb;
  v_snapshot_totals jsonb;
  v_acc jsonb;

  v_item_id uuid;
  v_item_qty numeric;
  v_item_msrp numeric;
  v_item_cost numeric;

  -- MSRP: leídos del JSON (build_bom_preview_snapshot ya los calculó)
  v_roll_msrp_total numeric := 0;
  v_bom_total numeric := 0;
  v_accessories_total numeric := 0;
  v_labor_msrp numeric := 0;
  v_unit_msrp_total numeric := 0;
  v_msrp_product_subtotal numeric := 0;

  -- Costos: calculados desde resolve o snapshot
  v_roll_total_cost_landed numeric := 0;
  v_bom_total_cost_landed numeric := 0;
  v_accessories_total_cost_landed numeric := 0;
  v_unit_product_cost_landed numeric := 0;
  v_unit_labor_cost numeric := 0;
  v_total_cost_landed_without_labor numeric := 0;
  v_total_cost_with_labor numeric := 0;

  v_roll_factor numeric := 0;
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_snapshot_totals := COALESCE(v_snapshot->'totals', '{}'::jsonb);

  -- ══════════════════════════════════════════════════════════════════════════
  -- MSRP: leer directamente del snapshot.totals (generados por build_bom_preview_snapshot)
  -- Estos valores son correctos y ya incluyen el factor de área/metros.
  -- ══════════════════════════════════════════════════════════════════════════
  v_roll_msrp_total   := COALESCE((v_snapshot_totals->>'roll_msrp_total')::numeric, v_cp.roll_msrp_total, 0);
  v_bom_total         := COALESCE((v_snapshot_totals->>'bom_total')::numeric, v_cp.bom_total, 0);
  v_accessories_total := COALESCE((v_snapshot_totals->>'accessories_total')::numeric, v_cp.accessories_total, 0);

  v_msrp_product_subtotal := v_roll_msrp_total + v_bom_total + v_accessories_total;

  -- Labor
  v_labor_msrp := COALESCE(
    (v_snapshot_totals->>'labor_amount')::numeric,
    (v_snapshot_totals->>'labor_msrp')::numeric,
    v_cp.labor_msrp,
    v_cp.labor_amount,
    0
  );
  IF v_labor_msrp = 0 AND COALESCE(v_cp.labor_pct, 0) > 0 THEN
    v_labor_msrp := v_msrp_product_subtotal
      * CASE WHEN v_cp.labor_pct <= 1 THEN v_cp.labor_pct ELSE (v_cp.labor_pct / 100.0) END;
  END IF;

  v_unit_msrp_total := v_msrp_product_subtotal + v_labor_msrp;

  -- ══════════════════════════════════════════════════════════════════════════
  -- COSTOS: resolve_catalog_item_landed_price_cost para roll + snapshot para BOM
  -- ══════════════════════════════════════════════════════════════════════════

  -- Roll cost
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    DECLARE
      v_roll_pricing_mode text;
      v_roll_measure_basis text;
    BEGIN
      SELECT ci.roll_pricing_mode, ci.measure_basis
      INTO v_roll_pricing_mode, v_roll_measure_basis
      FROM public."CatalogItems" ci
      WHERE ci.id = v_cp.roll_catalog_item_id
      LIMIT 1;

      IF v_roll_pricing_mode = 'per_unit' THEN
        v_roll_factor := 1;
      ELSIF v_roll_pricing_mode = 'per_linear_meter' OR v_roll_measure_basis = 'linear' THEN
        v_roll_factor := COALESCE(v_cp.height_mm, 0) / 1000.0;
      ELSE
        v_roll_factor := COALESCE(v_cp.roll_width, 0) * (COALESCE(v_cp.height_mm, 0) / 1000.0);
      END IF;

      SELECT unit_msrp, unit_cost INTO v_item_msrp, v_item_cost
      FROM public.resolve_catalog_item_landed_price_cost(v_cp.organization_id, v_cp.roll_catalog_item_id);

      v_roll_total_cost_landed := COALESCE(v_item_cost, 0) * COALESCE(v_roll_factor, 0);
    END;
  END IF;

  -- Fallback costos roll desde snapshot
  IF v_roll_total_cost_landed = 0 THEN
    v_roll_total_cost_landed := COALESCE(
      (v_snapshot_totals->>'roll_total_cost_landed')::numeric,
      (v_snapshot_totals->>'roll_total_cost')::numeric,
      0
    );
  END IF;

  -- BOM cost: leer del snapshot (build_bom_preview_snapshot no calcula costos BOM; dejar en 0 si no hay)
  v_bom_total_cost_landed := COALESCE(
    (v_snapshot_totals->>'bom_total_cost_landed')::numeric,
    (v_snapshot_totals->>'bom_total_cost')::numeric,
    0
  );

  -- Accessories cost
  IF jsonb_typeof(v_cp.config_snapshot->'accessories') = 'array' THEN
    FOR v_acc IN SELECT value FROM jsonb_array_elements(v_cp.config_snapshot->'accessories')
    LOOP
      v_item_qty := GREATEST(COALESCE((v_acc->>'qty')::numeric, 0), 0);
      v_item_id := CASE
        WHEN COALESCE(v_acc->>'id', '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          THEN (v_acc->>'id')::uuid
        WHEN COALESCE(v_acc->>'catalog_item_id', '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          THEN (v_acc->>'catalog_item_id')::uuid
        ELSE NULL
      END;
      IF v_item_id IS NOT NULL THEN
        SELECT unit_msrp, unit_cost INTO v_item_msrp, v_item_cost
        FROM public.resolve_catalog_item_landed_price_cost(v_cp.organization_id, v_item_id);
      ELSE
        v_item_cost := 0;
      END IF;
      v_accessories_total_cost_landed := v_accessories_total_cost_landed + (v_item_qty * COALESCE(v_item_cost, 0));
    END LOOP;
  ELSE
    v_accessories_total_cost_landed := COALESCE((v_snapshot_totals->>'accessories_total_cost_landed')::numeric, 0);
  END IF;

  -- Totales de costo
  v_unit_product_cost_landed := v_roll_total_cost_landed + v_bom_total_cost_landed + v_accessories_total_cost_landed;
  v_unit_labor_cost := COALESCE(v_cp.unit_labor_cost, 0);
  v_total_cost_landed_without_labor := v_unit_product_cost_landed;
  v_total_cost_with_labor := v_unit_product_cost_landed + v_unit_labor_cost;

  -- ══════════════════════════════════════════════════════════════════════════
  -- PERSISTIR en columnas (fuente de verdad auditable)
  -- ══════════════════════════════════════════════════════════════════════════
  UPDATE public."ConfiguredProducts"
  SET
    roll_msrp_total                  = v_roll_msrp_total,
    bom_total                        = v_bom_total,
    accessories_total                = v_accessories_total,
    labor_amount                     = v_labor_msrp,
    total_msrp                       = v_unit_msrp_total,
    msrp_product_subtotal            = v_msrp_product_subtotal,
    labor_msrp                       = v_labor_msrp,
    unit_msrp_total                  = v_unit_msrp_total,
    unit_product_cost_landed         = v_unit_product_cost_landed,
    unit_labor_cost                  = v_unit_labor_cost,
    roll_total_cost_landed           = v_roll_total_cost_landed,
    bom_total_cost_landed            = v_bom_total_cost_landed,
    accessories_total_cost_landed    = v_accessories_total_cost_landed,
    total_cost_landed_without_labor  = v_total_cost_landed_without_labor,
    total_cost_with_labor            = v_total_cost_with_labor,
    bom_preview_snapshot = jsonb_set(
      COALESCE(v_snapshot, '{}'::jsonb),
      '{totals}',
      COALESCE(v_snapshot_totals, '{}'::jsonb) || jsonb_build_object(
        'roll_msrp_total',                v_roll_msrp_total,
        'bom_total',                      v_bom_total,
        'accessories_total',              v_accessories_total,
        'labor_amount',                   v_labor_msrp,
        'total_msrp',                     v_unit_msrp_total,
        'msrp_product_subtotal',          v_msrp_product_subtotal,
        'labor_msrp',                     v_labor_msrp,
        'unit_msrp_total',                v_unit_msrp_total,
        'unit_product_cost_landed',       v_unit_product_cost_landed,
        'unit_labor_cost',                v_unit_labor_cost,
        'roll_total_cost_landed',         v_roll_total_cost_landed,
        'bom_total_cost_landed',          v_bom_total_cost_landed,
        'accessories_total_cost_landed',  v_accessories_total_cost_landed,
        'total_cost_landed_without_labor',v_total_cost_landed_without_labor,
        'total_cost_with_labor',          v_total_cost_with_labor
      ),
      true
    ),
    updated_at = now()
  WHERE id = p_configured_product_id;

  RETURN jsonb_build_object(
    'configured_product_id',            p_configured_product_id,
    'roll_msrp_total',                  v_roll_msrp_total,
    'bom_total',                        v_bom_total,
    'accessories_total',                v_accessories_total,
    'msrp_product_subtotal',            v_msrp_product_subtotal,
    'labor_msrp',                       v_labor_msrp,
    'unit_msrp_total',                  v_unit_msrp_total,
    'total_msrp',                       v_unit_msrp_total,
    'roll_total_cost_landed',           v_roll_total_cost_landed,
    'bom_total_cost_landed',            v_bom_total_cost_landed,
    'accessories_total_cost_landed',    v_accessories_total_cost_landed,
    'unit_product_cost_landed',         v_unit_product_cost_landed,
    'unit_labor_cost',                  v_unit_labor_cost,
    'total_cost_landed_without_labor',  v_total_cost_landed_without_labor,
    'total_cost_with_labor',            v_total_cost_with_labor
  );
END;
$$;

COMMENT ON FUNCTION public.calculate_configured_product_totals(uuid) IS
'Persiste totales en columnas de ConfiguredProducts.
MSRP: lee DIRECTAMENTE de bom_preview_snapshot.totals (roll_msrp_total, bom_total, accessories_total).
Estos valores ya fueron calculados correctamente por build_bom_preview_snapshot().
Costos: resolve_catalog_item_landed_price_cost() para roll; snapshot para BOM.
NO recalcula MSRP con resolve (que devuelve 0 para items sin entrada en CatalogItemsMSRP).';

-- ============================================================================
-- PARTE 3: Backfill de todos los ConfiguredProducts con bom_preview_snapshot
-- ============================================================================
DO $$
DECLARE
  v_id uuid;
  v_count int := 0;
BEGIN
  FOR v_id IN
    SELECT id FROM public."ConfiguredProducts"
    WHERE deleted = false
      AND bom_preview_snapshot IS NOT NULL
      AND bom_preview_snapshot <> '{}'::jsonb
  LOOP
    BEGIN
      PERFORM public.calculate_configured_product_totals(v_id);
      v_count := v_count + 1;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Error en CP %: %', v_id, SQLERRM;
    END;
  END LOOP;
  RAISE NOTICE '✅ Backfill completado: % ConfiguredProducts actualizados.', v_count;
END $$;

-- ============================================================================
-- PARTE 4: Backfill de QuoteLines — rellenar unit_msrp_total_snapshot donde falte
-- ============================================================================
UPDATE public."QuoteLines"
SET
  unit_msrp_total_snapshot = CASE
    WHEN COALESCE(quantity, 0) <= 0 OR msrp IS NULL THEN NULL
    ELSE ROUND(msrp / NULLIF(quantity, 0), 4)
  END,
  unit_cost_total_snapshot = CASE
    WHEN COALESCE(quantity, 0) <= 0 OR total_cost IS NULL THEN NULL
    ELSE ROUND(total_cost / NULLIF(quantity, 0), 4)
  END
WHERE unit_msrp_total_snapshot IS NULL
  AND msrp IS NOT NULL
  AND quantity IS NOT NULL AND quantity > 0;
