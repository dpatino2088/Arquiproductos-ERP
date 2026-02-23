-- ============================================================================
-- Migración: MSRP desde CatalogItemsMSRP (sin legacy) y sync QuoteLines desde totals
-- Fecha: 2026-03-07
--
-- Objetivos:
-- 1) Dejar de usar columnas/tablas legacy: msrp_sale_out, msrp_sale_in, effective_from, BOMTemplateLines.
-- 2) Calcular MSRP usando public."CatalogItemsMSRP" (columnas: msrp, dealer_price, labor_msrp, total_cost).
-- 3) Guardar y sincronizar QuoteLines SOLO desde ConfiguredProducts.bom_preview_snapshot->totals.
--
-- Sin dependencia de BOMTemplateLines.
-- ============================================================================

-- ============================================================================
-- PARTE 1: calculate_configured_product_totals
--   - Roll MSRP/costo desde CatalogItemsMSRP (msrp, dealer_price, labor_msrp) + factor UOM.
--   - bom_total, accessories_total desde bom_preview_snapshot->totals (ya calculados por build_bom_preview_snapshot).
--   - Persiste total_msrp, roll_msrp_total, unit_dealer_price, etc. en columnas y en totals JSON.
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

  -- CatalogItemsMSRP (roll): solo columnas actuales (msrp, dealer_price, labor_msrp)
  v_cim_msrp        numeric := 0;
  v_cim_dealer      numeric := 0;
  v_cim_labor_msrp  numeric := 0;
  v_roll_factor     numeric := 0;

  v_roll_msrp_total    numeric := 0;
  v_roll_dealer_total  numeric := 0;
  v_bom_total          numeric := 0;
  v_accessories_total  numeric := 0;
  v_labor_msrp         numeric := 0;
  v_msrp_product_subtotal numeric := 0;
  v_unit_msrp_total    numeric := 0;
  v_unit_dealer_price  numeric := 0;

  v_roll_total_cost_landed numeric := 0;
  v_bom_total_cost_landed numeric := 0;
  v_accessories_total_cost_landed numeric := 0;
  v_unit_product_cost_landed numeric := 0;
  v_unit_labor_cost numeric := 0;
  v_total_cost_landed_without_labor numeric := 0;
  v_total_cost_with_labor numeric := 0;
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
  -- ROLL: leer msrp, dealer_price, labor_msrp desde CatalogItemsMSRP (sin legacy)
  -- Factor por UOM: per_unit=1, per_linear_meter=height_m, else area (roll_width * height_m)
  -- ══════════════════════════════════════════════════════════════════════════
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    DECLARE
      v_roll_pricing_mode text;
      v_roll_measure_basis text;
    BEGIN
      SELECT cim.msrp, cim.dealer_price, cim.labor_msrp
      INTO v_cim_msrp, v_cim_dealer, v_cim_labor_msrp
      FROM public."CatalogItemsMSRP" cim
      WHERE cim.catalog_item_id = v_cp.roll_catalog_item_id
        AND cim.organization_id = v_cp.organization_id
      LIMIT 1;

      IF v_cim_msrp IS NULL AND v_cim_dealer IS NULL THEN
        SELECT cim.msrp, cim.dealer_price, cim.labor_msrp
        INTO v_cim_msrp, v_cim_dealer, v_cim_labor_msrp
        FROM public."CatalogItemsMSRP" cim
        WHERE cim.catalog_item_id = v_cp.roll_catalog_item_id
        LIMIT 1;
      END IF;

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

      v_roll_msrp_total   := COALESCE(v_cim_msrp, 0) * GREATEST(v_roll_factor, 0);
      v_roll_dealer_total := COALESCE(v_cim_dealer, 0) * GREATEST(v_roll_factor, 0);
      v_labor_msrp        := COALESCE(v_cim_labor_msrp, 0);
    END;
  END IF;

  -- BOM y accesorios: desde snapshot (build_bom_preview_snapshot ya los calculó)
  v_bom_total         := COALESCE((v_snapshot_totals->>'bom_total')::numeric, v_cp.bom_total, 0);
  v_accessories_total := COALESCE((v_snapshot_totals->>'accessories_total')::numeric, v_cp.accessories_total, 0);

  -- msrp_product_subtotal = solo roll (por especificación); unit_msrp_total = roll + labor + bom + accessories
  v_msrp_product_subtotal := v_roll_msrp_total;

  -- Labor: si no vino de CIM, aplicar labor_pct sobre (roll + bom + accessories)
  IF v_labor_msrp = 0 AND COALESCE(v_cp.labor_pct, 0) > 0 THEN
    v_labor_msrp := (v_roll_msrp_total + v_bom_total + v_accessories_total)
      * CASE WHEN v_cp.labor_pct <= 1 THEN v_cp.labor_pct ELSE (v_cp.labor_pct / 100.0) END;
  END IF;

  v_unit_msrp_total := v_roll_msrp_total + v_labor_msrp + v_bom_total + v_accessories_total;
  -- Dealer price por unidad: roll desde CIM.dealer_price; BOM/accessories/labor usan MSRP (no hay dealer_price por componente)
  v_unit_dealer_price := v_roll_dealer_total + v_bom_total + v_accessories_total + v_labor_msrp;
  IF v_unit_dealer_price = 0 THEN
    v_unit_dealer_price := v_unit_msrp_total;
  END IF;

  -- ══════════════════════════════════════════════════════════════════════════
  -- COSTOS: resolve_catalog_item_landed_price_cost (usa CatalogItemsMSRP.total_cost)
  -- ══════════════════════════════════════════════════════════════════════════
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

  IF v_roll_total_cost_landed = 0 THEN
    v_roll_total_cost_landed := COALESCE(
      (v_snapshot_totals->>'roll_total_cost_landed')::numeric,
      (v_snapshot_totals->>'roll_total_cost')::numeric,
      0
    );
  END IF;

  v_bom_total_cost_landed := COALESCE(
    (v_snapshot_totals->>'bom_total_cost_landed')::numeric,
    (v_snapshot_totals->>'bom_total_cost')::numeric,
    0
  );

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

  v_unit_product_cost_landed := v_roll_total_cost_landed + v_bom_total_cost_landed + v_accessories_total_cost_landed;
  v_unit_labor_cost := COALESCE(v_cp.unit_labor_cost, 0);
  v_total_cost_landed_without_labor := v_unit_product_cost_landed;
  v_total_cost_with_labor := v_unit_product_cost_landed + v_unit_labor_cost;

  -- ══════════════════════════════════════════════════════════════════════════
  -- PERSISTIR en ConfiguredProducts y en bom_preview_snapshot.totals
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
    total_cost_with_labor           = v_total_cost_with_labor,
    bom_preview_snapshot = jsonb_set(
      COALESCE(v_snapshot, '{}'::jsonb),
      '{totals}',
      COALESCE(v_snapshot_totals, '{}'::jsonb) || jsonb_build_object(
        'roll_msrp_total',                v_roll_msrp_total,
        'roll_dealer_total',              v_roll_dealer_total,
        'bom_total',                      v_bom_total,
        'accessories_total',              v_accessories_total,
        'labor_amount',                   v_labor_msrp,
        'total_msrp',                     v_unit_msrp_total,
        'msrp_product_subtotal',          v_msrp_product_subtotal,
        'labor_msrp',                     v_labor_msrp,
        'unit_msrp_total',                v_unit_msrp_total,
        'unit_dealer_price',              v_unit_dealer_price,
        'unit_product_cost_landed',       v_unit_product_cost_landed,
        'unit_labor_cost',                v_unit_labor_cost,
        'roll_total_cost_landed',         v_roll_total_cost_landed,
        'bom_total_cost_landed',          v_bom_total_cost_landed,
        'accessories_total_cost_landed',  v_accessories_total_cost_landed,
        'total_cost_landed_without_labor', v_total_cost_landed_without_labor,
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
    'unit_msrp_total',                  v_unit_msrp_total,
    'total_msrp',                       v_unit_msrp_total,
    'unit_dealer_price',                v_unit_dealer_price,
    'roll_total_cost_landed',           v_roll_total_cost_landed,
    'bom_total_cost_landed',            v_bom_total_cost_landed,
    'total_cost_with_labor',            v_total_cost_with_labor
  );
END;
$$;

COMMENT ON FUNCTION public.calculate_configured_product_totals(uuid) IS
'Persiste totales en ConfiguredProducts. Roll MSRP/dealer desde CatalogItemsMSRP (msrp, dealer_price, labor_msrp). BOM/accessories desde bom_preview_snapshot.totals. Costos vía resolve_catalog_item_landed_price_cost. Escribe unit_dealer_price en totals para sync. Sin legacy (msrp_sale_out, msrp_sale_in, effective_from, BOMTemplateLines).';


-- ============================================================================
-- PARTE 2: sync_quote_line_pricing_from_configured_product
--   - Lee totals = ConfiguredProducts.bom_preview_snapshot->'totals'.
--   - Setea QuoteLines desde totals (unit_msrp_total_snapshot, msrp, total_cost).
--   - Sale-In: unit_dealer_price desde totals si existe; si no, tier sobre unit_msrp_total.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sync_quote_line_pricing_from_configured_product(p_quote_line_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ql     RECORD;
  v_totals jsonb;
  v_qty    numeric(12,4);
  v_unit_msrp    numeric(12,4);
  v_unit_cost    numeric(12,4);
  v_unit_dealer  numeric(12,4);
  v_dealer_tier_id uuid;
  v_discount_pct numeric(5,2);
  v_unit_sale_in numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'sync_quote_line_pricing_from_configured_product: p_quote_line_id is required';
  END IF;

  SELECT ql.id, ql.organization_id, ql.configured_product_id,
         ql.quantity, ql.pricing_locked, ql.quote_id
  INTO v_ql
  FROM public."QuoteLines" ql
  WHERE ql.id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;
  IF v_ql.configured_product_id IS NULL THEN RETURN; END IF;
  IF COALESCE(v_ql.pricing_locked, false) = true THEN RETURN; END IF;

  -- Recalcular CP para que totals esté al día
  PERFORM public.calculate_configured_product_totals(v_ql.configured_product_id);

  SELECT cp.bom_preview_snapshot->'totals' INTO v_totals
  FROM public."ConfiguredProducts" cp
  WHERE cp.id = v_ql.configured_product_id
    AND cp.organization_id = v_ql.organization_id
    AND cp.deleted = false;

  IF v_totals IS NULL OR v_totals = 'null'::jsonb THEN
    v_totals := '{}'::jsonb;
  END IF;

  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);

  -- Desde totals (fuente única para sync)
  v_unit_msrp := COALESCE((v_totals->>'unit_msrp_total')::numeric, (v_totals->>'total_msrp')::numeric, 0);
  v_unit_cost := COALESCE((v_totals->>'total_cost_with_labor')::numeric, (v_totals->>'unit_product_cost_landed')::numeric + COALESCE((v_totals->>'unit_labor_cost')::numeric, 0), 0);
  v_unit_dealer := COALESCE((v_totals->>'unit_dealer_price')::numeric, 0);

  -- Sale-In: preferir unit_dealer_price (CatalogItemsMSRP.dealer_price); fallback tier sobre MSRP
  IF v_unit_dealer > 0 THEN
    v_unit_sale_in := v_unit_dealer;
    v_discount_pct := NULL;
  ELSE
    SELECT d.dealer_tier_id INTO v_dealer_tier_id
    FROM public."Quotes" q
    JOIN public."Dealers" d ON d.id = q.dealer_id
    WHERE q.id = v_ql.quote_id
    LIMIT 1;

    SELECT COALESCE(dt.discount_pct, 35) INTO v_discount_pct
    FROM public."DealerTiers" dt
    WHERE dt.id = v_dealer_tier_id
    LIMIT 1;

    IF v_discount_pct IS NULL THEN
      v_discount_pct := 35;
    END IF;

    v_unit_sale_in := ROUND(v_unit_msrp * (1 - v_discount_pct / 100.0), 4);
  END IF;

  PERFORM set_config('app.write_source', 'rpc', true);

  UPDATE public."QuoteLines"
  SET
    roll_msrp_snapshot         = COALESCE((v_totals->>'roll_msrp_total')::numeric, 0),
    bom_msrp_snapshot          = COALESCE((v_totals->>'bom_total')::numeric, 0),
    roll_cost_snapshot         = COALESCE((v_totals->>'roll_total_cost_landed')::numeric, 0),
    bom_cost_snapshot          = COALESCE((v_totals->>'bom_total_cost_landed')::numeric, 0),
    unit_msrp_total_snapshot   = v_unit_msrp,
    unit_cost_total_snapshot   = v_unit_cost,
    msrp                       = ROUND(v_unit_msrp * v_qty, 2),
    total_cost                 = ROUND(v_unit_cost * v_qty, 2),
    unit_sale_in_price_snapshot = v_unit_sale_in,
    sale_in_total              = ROUND(v_unit_sale_in * v_qty, 2),
    sale_in_discount_pct       = v_discount_pct,
    last_priced_at             = now(),
    pricing_version            = COALESCE(pricing_version, 0) + 1,
    pricing_locked             = true
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;

COMMENT ON FUNCTION public.sync_quote_line_pricing_from_configured_product(uuid) IS
'Refreshes QuoteLine pricing from ConfiguredProducts.bom_preview_snapshot->totals only. Recalculates CP then sets unit_msrp_total_snapshot, msrp, total_cost from totals. Sale-In from totals.unit_dealer_price (CatalogItemsMSRP) or tier fallback.';


-- ============================================================================
-- PARTE 3: Verificación (tests manuales)
-- ============================================================================
-- Sustituir :cp_id y :ql_id por UUIDs reales al ejecutar en consola.
--
-- 1) ConfiguredProduct con total_msrp y total_cost:
--   SELECT id, roll_catalog_item_id, roll_msrp_total, bom_total, total_msrp,
--          unit_product_cost_landed, total_cost_with_labor,
--          bom_preview_snapshot->'totals'->>'unit_dealer_price' AS unit_dealer_price
--   FROM public."ConfiguredProducts"
--   WHERE id = :cp_id;
--
-- 2) QuoteLine coherente con totals:
--   SELECT ql.id, ql.unit_msrp_total_snapshot, ql.msrp, ql.total_cost,
--          ql.unit_sale_in_price_snapshot, ql.sale_in_total
--   FROM public."QuoteLines" ql
--   WHERE ql.id = :ql_id;
--
-- 3) Inconsistencias: CP con roll en CatalogItemsMSRP (msrp > 0) pero total_msrp o total_cost <= 0:
--   SELECT cp.id, cp.roll_catalog_item_id, cp.total_msrp, cp.total_cost_with_labor,
--          cim.msrp AS cim_msrp, cim.dealer_price AS cim_dealer
--   FROM public."ConfiguredProducts" cp
--   JOIN public."CatalogItemsMSRP" cim
--     ON cim.catalog_item_id = cp.roll_catalog_item_id AND cim.organization_id = cp.organization_id
--   WHERE cp.deleted = false
--     AND cim.msrp IS NOT NULL AND cim.msrp > 0
--     AND (cp.total_msrp IS NULL OR cp.total_msrp <= 0 OR cp.total_cost_with_labor IS NULL OR cp.total_cost_with_labor <= 0);
--   Esperado: 0 filas.
--
-- 4) Recalcular totals para un CP y revisar columnas:
--   SELECT public.calculate_configured_product_totals(:cp_id);
--   SELECT id, roll_msrp_total, bom_total, total_msrp, total_cost_with_labor
--   FROM public."ConfiguredProducts" WHERE id = :cp_id;
--
-- 5) Sincronizar una QuoteLine y revisar:
--   SELECT public.sync_quote_line_pricing_from_configured_product(:ql_id);
--   SELECT id, unit_msrp_total_snapshot, msrp, total_cost, unit_sale_in_price_snapshot, sale_in_total
--   FROM public."QuoteLines" WHERE id = :ql_id;
