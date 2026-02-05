-- ============================================================================
-- Eliminar tabla QuoteLineCosts
-- Fecha: 2026-02-04
-- Motivo: Los costos de las líneas de cotización provienen del snapshot JSON
--         de ConfiguredProduct (roll_cost_snapshot, bom_cost_snapshot, total_cost
--         en QuoteLines). La tabla QuoteLineCosts es redundante y no se usa
--         en el flujo configurador.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1) Eliminar triggers que dependen de QuoteLineCosts
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_recalculate_price_on_cost_update ON public."QuoteLineCosts";
DROP TRIGGER IF EXISTS trigger_quote_lines_compute_cost ON public."QuoteLines";

-- ----------------------------------------------------------------------------
-- 2) save_quote_line_cost_snapshot: ya no escribe en QuoteLineCosts (no-op)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.save_quote_line_cost_snapshot(p_quote_line_id uuid)
RETURNS uuid
LANGUAGE plpgsql
AS $$
BEGIN
  -- Tabla QuoteLineCosts eliminada; costos vienen de ConfiguredProduct/QuoteLines.
  RETURN NULL;
END;
$$;

-- ----------------------------------------------------------------------------
-- 3) save_quote_line_prices_snapshot: leer costo desde QuoteLines en lugar de QuoteLineCosts
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.save_quote_line_prices_snapshot(p_quote_line_id uuid)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_q record;
  v_default_margin numeric := 0.65;
  v_total_cost numeric;
  v_version int;
BEGIN
  SELECT id, total_cost, COALESCE(roll_cost_snapshot, 0) + COALESCE(bom_cost_snapshot, 0) AS snapshot_cost,
         pricing_version
  INTO v_q
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  v_total_cost := COALESCE(v_q.total_cost, v_q.snapshot_cost, 0);
  IF v_total_cost <= 0 THEN
    RETURN p_quote_line_id;
  END IF;

  v_version := COALESCE(v_q.pricing_version, 0) + 1;

  -- MSRP desde costo (margin por defecto; columnas default_margin_pct/discount_pct ya eliminadas)
  UPDATE public."QuoteLines"
  SET msrp = round(v_total_cost / nullif(1 - v_default_margin, 0), 4),
      total_cost = v_total_cost,
      pricing_version = v_version,
      pricing_locked = true,
      last_priced_at = now(),
      updated_at = now()
  WHERE id = p_quote_line_id;

  RETURN p_quote_line_id;
END;
$$;

-- ----------------------------------------------------------------------------
-- 4) calculate_quote_line_price: usar QuoteLines.total_cost (no QuoteLineCosts)
--    Prioridad: QuoteLines.total_cost > roll_cost_snapshot+bom_cost_snapshot > CatalogItem.cost_exw
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_quote_line_price(p_quote_line_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_quote_line_record record;
  v_catalog_item_record record;
  v_category_margin_record record;
  v_base_cost_per_unit numeric := 0;
  v_unit_price numeric;
  v_margin_percentage numeric;
  v_margin_source text;
  v_qty numeric;
BEGIN
  SELECT id, catalog_item_id, organization_id, quantity, width_m, height_m,
         total_cost, roll_cost_snapshot, bom_cost_snapshot, configured_product_id
  INTO v_quote_line_record
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF NOT FOUND THEN
    RETURN p_quote_line_id;
  END IF;

  v_qty := GREATEST(COALESCE(v_quote_line_record.quantity, 1), 1);

  -- Costo: 1) total_cost en QuoteLines, 2) roll+bom snapshot, 3) CatalogItem.cost_exw
  IF COALESCE(v_quote_line_record.total_cost, 0) > 0 THEN
    v_base_cost_per_unit := v_quote_line_record.total_cost / v_qty;
  ELSIF (COALESCE(v_quote_line_record.roll_cost_snapshot, 0) + COALESCE(v_quote_line_record.bom_cost_snapshot, 0)) > 0 THEN
    v_base_cost_per_unit := (v_quote_line_record.roll_cost_snapshot + v_quote_line_record.bom_cost_snapshot) / v_qty;
  ELSIF v_quote_line_record.catalog_item_id IS NOT NULL THEN
    SELECT cost_exw, category_id, default_margin_pct INTO v_catalog_item_record
    FROM public."CatalogItems"
    WHERE id = v_quote_line_record.catalog_item_id;
    IF FOUND AND COALESCE(v_catalog_item_record.cost_exw, 0) > 0 THEN
      v_base_cost_per_unit := v_catalog_item_record.cost_exw;
    ELSE
      RETURN p_quote_line_id;
    END IF;
  ELSE
    RETURN p_quote_line_id;
  END IF;

  -- Margin: category > item default > 35%
  IF v_quote_line_record.catalog_item_id IS NOT NULL THEN
    SELECT margin_percentage INTO v_category_margin_record
    FROM public."CategoryMargins"
    WHERE organization_id = v_quote_line_record.organization_id
      AND category_id = v_catalog_item_record.category_id
      AND active = true AND deleted = false
    LIMIT 1;
    IF FOUND THEN
      v_margin_percentage := v_category_margin_record.margin_percentage;
      v_margin_source := 'category';
    ELSIF COALESCE(v_catalog_item_record.default_margin_pct, 0) > 0 THEN
      v_margin_percentage := v_catalog_item_record.default_margin_pct;
      v_margin_source := 'item';
    ELSE
      v_margin_percentage := 35;
      v_margin_source := 'default';
    END IF;
  ELSE
    v_margin_percentage := 35;
    v_margin_source := 'default';
  END IF;

  v_unit_price := v_base_cost_per_unit * (1 + v_margin_percentage / 100);

  UPDATE public."QuoteLines"
  SET msrp = v_unit_price,
      total_cost = COALESCE(total_cost, v_base_cost_per_unit * v_qty),
      updated_at = now()
  WHERE id = p_quote_line_id;

  RETURN p_quote_line_id;
END;
$$;

COMMENT ON FUNCTION public.calculate_quote_line_price(uuid) IS
'Calculates unit price for a QuoteLine. Uses QuoteLines.total_cost or roll_cost_snapshot+bom_cost_snapshot (from ConfiguredProduct), fallback CatalogItem.cost_exw. QuoteLineCosts table removed.';

-- ----------------------------------------------------------------------------
-- 5) compute_quote_line_cost: stub que no escribe en QuoteLineCosts
--    Opcionalmente actualiza QuoteLines.total_cost desde CatalogItem para líneas simples.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.compute_quote_line_cost(p_quote_line_id uuid, p_options jsonb DEFAULT '{}'::jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ql record;
  v_ci record;
BEGIN
  -- QuoteLineCosts eliminada. Para líneas con configured_product_id el costo viene del snapshot.
  -- Para líneas legacy con catalog_item_id, podemos actualizar QuoteLines.total_cost desde CatalogItem.
  SELECT id, catalog_item_id, quantity, total_cost, configured_product_id
  INTO v_ql FROM public."QuoteLines" WHERE id = p_quote_line_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  IF v_ql.configured_product_id IS NOT NULL THEN
    RETURN p_quote_line_id; -- Costo ya en QuoteLines desde commit
  END IF;
  IF v_ql.catalog_item_id IS NULL THEN
    RETURN p_quote_line_id;
  END IF;
  SELECT cost_exw INTO v_ci FROM public."CatalogItems" WHERE id = v_ql.catalog_item_id LIMIT 1;
  IF FOUND AND v_ci.cost_exw IS NOT NULL AND (v_ql.total_cost IS NULL OR v_ql.total_cost = 0) THEN
    UPDATE public."QuoteLines"
    SET total_cost = v_ci.cost_exw * GREATEST(COALESCE(v_ql.quantity, 1), 1), updated_at = now()
    WHERE id = p_quote_line_id;
  END IF;
  RETURN p_quote_line_id;
END;
$$;

COMMENT ON FUNCTION public.compute_quote_line_cost(uuid, jsonb) IS
'Legacy cost computation. QuoteLineCosts removed; only updates QuoteLines.total_cost from CatalogItem for simple lines when total_cost is null/zero.';

-- ----------------------------------------------------------------------------
-- 6) Eliminar tabla QuoteLineCosts
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS public."QuoteLineCosts" CASCADE;

COMMIT;

-- ============================================================================
-- NOTAS
-- ============================================================================
-- Frontend: useQuoteLineCosts / QuoteLineCostsSection(V1) consultan QuoteLineCosts.
-- Tras esta migración, esas pantallas no tendrán datos (tabla eliminada).
-- Opciones: 1) Ocultar la sección de costes para líneas con configured_product_id
--           y mostrar total_cost/roll_cost_snapshot/bom_cost_snapshot de QuoteLines;
--           2) Adaptar useQuoteLineCosts para leer de QuoteLines cuando la tabla
--           no exista o no haya fila.
-- ============================================================================
