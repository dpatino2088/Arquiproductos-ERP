-- ============================================================================
-- Migration: Pricing/costing semantic split + ConfiguredProducts landed costs
-- Date: 2026-02-21
--
-- Goal:
-- - Keep MSRP as final public price.
-- - Add explicit product subtotal vs labor split (per unit).
-- - Ensure ConfiguredProducts has real landed costs (roll/bom/accessories), not zeros.
-- - Ensure QuoteLines stores coherent unit fields and line totals (unit * quantity).
-- - Keep backend (RPCs/functions) as source of truth.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Schema: add explicit semantic columns
-- ----------------------------------------------------------------------------
DO $$
BEGIN
  -- ConfiguredProducts
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'msrp_product_subtotal'
  ) THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN msrp_product_subtotal numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'labor_msrp'
  ) THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN labor_msrp numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'unit_msrp_total'
  ) THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN unit_msrp_total numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'unit_product_cost_landed'
  ) THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN unit_product_cost_landed numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'unit_labor_cost'
  ) THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN unit_labor_cost numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'roll_total_cost_landed'
  ) THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN roll_total_cost_landed numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'bom_total_cost_landed'
  ) THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN bom_total_cost_landed numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'accessories_total_cost_landed'
  ) THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN accessories_total_cost_landed numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'total_cost_landed_without_labor'
  ) THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN total_cost_landed_without_labor numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'total_cost_with_labor'
  ) THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN total_cost_with_labor numeric(12,4) DEFAULT 0;
  END IF;

  -- QuoteLines
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'unit_msrp_product_subtotal'
  ) THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN unit_msrp_product_subtotal numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'unit_labor_msrp'
  ) THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN unit_labor_msrp numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'unit_product_cost'
  ) THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN unit_product_cost numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'unit_labor_cost'
  ) THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN unit_labor_cost numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'accessories_msrp_snapshot'
  ) THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN accessories_msrp_snapshot numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'labor_msrp_snapshot'
  ) THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN labor_msrp_snapshot numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'accessories_cost_snapshot'
  ) THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN accessories_cost_snapshot numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'labor_cost_snapshot'
  ) THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN labor_cost_snapshot numeric(12,4) DEFAULT 0;
  END IF;
END $$;

COMMENT ON COLUMN public."ConfiguredProducts".msrp_product_subtotal IS
'Per-unit MSRP product subtotal (roll + BOM + accessories), without labor.';
COMMENT ON COLUMN public."ConfiguredProducts".labor_msrp IS
'Per-unit labor portion added after msrp_product_subtotal.';
COMMENT ON COLUMN public."ConfiguredProducts".unit_msrp_total IS
'Final per-unit MSRP = msrp_product_subtotal + labor_msrp.';
COMMENT ON COLUMN public."ConfiguredProducts".unit_product_cost_landed IS
'Per-unit landed product cost (roll + BOM + accessories), without labor.';
COMMENT ON COLUMN public."ConfiguredProducts".total_cost_with_labor IS
'Per-unit total cost including labor cost.';

COMMENT ON COLUMN public."QuoteLines".unit_msrp_product_subtotal IS
'Per-unit MSRP subtotal without labor.';
COMMENT ON COLUMN public."QuoteLines".unit_labor_msrp IS
'Per-unit labor MSRP.';
COMMENT ON COLUMN public."QuoteLines".unit_product_cost IS
'Per-unit landed product cost (without labor).';
COMMENT ON COLUMN public."QuoteLines".unit_labor_cost IS
'Per-unit labor cost.';

-- ----------------------------------------------------------------------------
-- 2) Helper: resolve landed MSRP + landed cost from catalog
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resolve_catalog_item_landed_price_cost(
  p_org_id uuid,
  p_item_id uuid
) RETURNS TABLE(unit_msrp numeric, unit_cost numeric)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_msrp numeric := 0;
  v_total_cost numeric := 0;
  v_cost_exw numeric := 0;
  v_shipping_pct numeric := 0;
  v_import_tax_pct numeric := 0;
BEGIN
  IF p_item_id IS NULL THEN
    RETURN QUERY SELECT 0::numeric, 0::numeric;
    RETURN;
  END IF;

  SELECT m.msrp, m.total_cost
  INTO v_msrp, v_total_cost
  FROM public."CatalogItemsMSRP" m
  WHERE m.catalog_item_id = p_item_id
    AND m.organization_id = p_org_id
  LIMIT 1;

  IF v_msrp IS NULL THEN
    SELECT m.msrp, m.total_cost
    INTO v_msrp, v_total_cost
    FROM public."CatalogItemsMSRP" m
    WHERE m.catalog_item_id = p_item_id
    LIMIT 1;
  END IF;

  IF v_total_cost IS NULL THEN
    SELECT COALESCE(ci.cost_exw, 0)
    INTO v_cost_exw
    FROM public."CatalogItems" ci
    WHERE ci.id = p_item_id
    LIMIT 1;

    SELECT COALESCE(cs.shipping_pct, 0), COALESCE(cs.import_tax_pct, 0)
    INTO v_shipping_pct, v_import_tax_pct
    FROM public."CostSettings" cs
    WHERE cs.organization_id = p_org_id
    LIMIT 1;

    v_total_cost := v_cost_exw + (v_cost_exw * v_shipping_pct) + ((v_cost_exw + (v_cost_exw * v_shipping_pct)) * v_import_tax_pct);
  END IF;

  RETURN QUERY SELECT COALESCE(v_msrp, v_total_cost, 0), COALESCE(v_total_cost, 0);
END;
$$;

COMMENT ON FUNCTION public.resolve_catalog_item_landed_price_cost(uuid, uuid) IS
'Resolves landed MSRP and landed cost for one catalog item. Uses CatalogItemsMSRP first, then CostSettings fallback from CatalogItems.cost_exw.';

-- ----------------------------------------------------------------------------
-- 3) Rework calculate_configured_product_totals (unit semantics + real costs)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_configured_product_totals(p_configured_product_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_cp RECORD;
  v_snapshot jsonb;
  v_snapshot_totals jsonb;
  v_item jsonb;
  v_child jsonb;
  v_acc jsonb;

  v_roll_pricing_mode text;
  v_roll_measure_basis text;
  v_roll_factor numeric := 0;
  v_roll_width_m numeric := 0;
  v_height_m numeric := 0;

  v_item_id uuid;
  v_item_qty numeric;
  v_item_msrp numeric;
  v_item_cost numeric;

  v_roll_msrp_total numeric := 0;
  v_bom_total numeric := 0;
  v_accessories_total numeric := 0;
  v_labor_msrp numeric := 0;
  v_unit_msrp_total numeric := 0;
  v_msrp_product_subtotal numeric := 0;

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

  -- Roll landed MSRP + landed cost (per unit, never multiplied by ConfiguredProducts.quantity)
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT ci.roll_pricing_mode, ci.measure_basis
    INTO v_roll_pricing_mode, v_roll_measure_basis
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id
    LIMIT 1;

    v_roll_width_m := COALESCE(v_cp.roll_width, 0);
    v_height_m := COALESCE(v_cp.height_mm, 0) / 1000.0;

    IF v_roll_pricing_mode = 'per_unit' THEN
      v_roll_factor := 1;
    ELSIF v_roll_pricing_mode = 'per_linear_meter' OR v_roll_measure_basis = 'linear' THEN
      v_roll_factor := v_height_m;
    ELSE
      v_roll_factor := (v_roll_width_m * v_height_m);
    END IF;

    SELECT unit_msrp, unit_cost
    INTO v_item_msrp, v_item_cost
    FROM public.resolve_catalog_item_landed_price_cost(v_cp.organization_id, v_cp.roll_catalog_item_id);

    v_roll_msrp_total := COALESCE(v_item_msrp, 0) * COALESCE(v_roll_factor, 0);
    v_roll_total_cost_landed := COALESCE(v_item_cost, 0) * COALESCE(v_roll_factor, 0);
  END IF;

  -- BOM landed MSRP + landed cost from snapshot items (parents + children)
  IF v_snapshot->>'version' = '1' AND jsonb_typeof(v_snapshot->'items') = 'array' THEN
    FOR v_item IN SELECT value FROM jsonb_array_elements(v_snapshot->'items')
    LOOP
      IF COALESCE(v_item->>'kind', '') = 'parent' THEN
        v_item_qty := COALESCE((v_item->>'qty')::numeric, 0);
        v_item_id := CASE
          WHEN COALESCE(v_item->>'catalog_item_id', '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            THEN (v_item->>'catalog_item_id')::uuid
          ELSE NULL
        END;

        IF v_item_id IS NOT NULL THEN
          SELECT unit_msrp, unit_cost INTO v_item_msrp, v_item_cost
          FROM public.resolve_catalog_item_landed_price_cost(v_cp.organization_id, v_item_id);
          v_bom_total := v_bom_total + (COALESCE(v_item_qty, 0) * COALESCE(v_item_msrp, 0));
          v_bom_total_cost_landed := v_bom_total_cost_landed + (COALESCE(v_item_qty, 0) * COALESCE(v_item_cost, 0));
        ELSE
          v_bom_total := v_bom_total + COALESCE((v_item->>'line_total')::numeric, 0);
        END IF;

        IF jsonb_typeof(v_item->'children') = 'array' THEN
          FOR v_child IN SELECT value FROM jsonb_array_elements(v_item->'children')
          LOOP
            v_item_qty := COALESCE((v_child->>'qty')::numeric, 0);
            v_item_id := CASE
              WHEN COALESCE(v_child->>'catalog_item_id', '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                THEN (v_child->>'catalog_item_id')::uuid
              ELSE NULL
            END;

            IF v_item_id IS NOT NULL THEN
              SELECT unit_msrp, unit_cost INTO v_item_msrp, v_item_cost
              FROM public.resolve_catalog_item_landed_price_cost(v_cp.organization_id, v_item_id);
              v_bom_total := v_bom_total + (COALESCE(v_item_qty, 0) * COALESCE(v_item_msrp, 0));
              v_bom_total_cost_landed := v_bom_total_cost_landed + (COALESCE(v_item_qty, 0) * COALESCE(v_item_cost, 0));
            ELSE
              v_bom_total := v_bom_total + COALESCE((v_child->>'line_total')::numeric, 0);
            END IF;
          END LOOP;
        END IF;
      END IF;
    END LOOP;
  END IF;

  -- Accessories MSRP + landed cost (if array exists in config snapshot)
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
        v_item_msrp := 0;
        v_item_cost := 0;
      END IF;

      -- If accessory has explicit public price in config, keep it as MSRP
      v_item_msrp := COALESCE(NULLIF((v_acc->>'price')::numeric, 0), v_item_msrp, 0);

      v_accessories_total := v_accessories_total + (v_item_qty * COALESCE(v_item_msrp, 0));
      v_accessories_total_cost_landed := v_accessories_total_cost_landed + (v_item_qty * COALESCE(v_item_cost, 0));
    END LOOP;
  ELSE
    v_accessories_total := COALESCE(v_cp.accessories_total, COALESCE((v_snapshot_totals->>'accessories_total')::numeric, 0), 0);
    v_accessories_total_cost_landed := COALESCE((v_snapshot_totals->>'accessories_total_cost_landed')::numeric, 0);
  END IF;

  v_msrp_product_subtotal := COALESCE(v_roll_msrp_total, 0) + COALESCE(v_bom_total, 0) + COALESCE(v_accessories_total, 0);
  v_labor_msrp := COALESCE(v_cp.labor_msrp, v_cp.labor_amount, 0);
  -- labor_pct: CostSettings and CP store as 0-1 (e.g. 0.05 = 5%). If value > 1, treat as 0-100 for backward compatibility.
  IF v_labor_msrp = 0 AND COALESCE(v_cp.labor_pct, 0) > 0 THEN
    v_labor_msrp := v_msrp_product_subtotal * CASE WHEN v_cp.labor_pct <= 1 THEN v_cp.labor_pct ELSE (v_cp.labor_pct / 100.0) END;
  END IF;
  v_unit_msrp_total := v_msrp_product_subtotal + v_labor_msrp;

  v_unit_product_cost_landed := COALESCE(v_roll_total_cost_landed, 0) + COALESCE(v_bom_total_cost_landed, 0) + COALESCE(v_accessories_total_cost_landed, 0);
  v_unit_labor_cost := COALESCE(v_cp.unit_labor_cost, 0);
  v_total_cost_landed_without_labor := v_unit_product_cost_landed;
  v_total_cost_with_labor := v_unit_product_cost_landed + v_unit_labor_cost;

  -- Usar msrp_product_subtotal (no roll_plus_bom_total).
  UPDATE public."ConfiguredProducts"
  SET
    roll_msrp_total = v_roll_msrp_total,
    bom_total = v_bom_total,
    accessories_total = v_accessories_total,
    labor_amount = v_labor_msrp,
    total_msrp = v_unit_msrp_total,
    bom_total_cost = v_bom_total_cost_landed,
    msrp_product_subtotal = v_msrp_product_subtotal,
    labor_msrp = v_labor_msrp,
    unit_msrp_total = v_unit_msrp_total,
    unit_product_cost_landed = v_unit_product_cost_landed,
    unit_labor_cost = v_unit_labor_cost,
    roll_total_cost_landed = v_roll_total_cost_landed,
    bom_total_cost_landed = v_bom_total_cost_landed,
    accessories_total_cost_landed = v_accessories_total_cost_landed,
    total_cost_landed_without_labor = v_total_cost_landed_without_labor,
    total_cost_with_labor = v_total_cost_with_labor,
    bom_preview_snapshot = jsonb_set(
      COALESCE(v_snapshot, '{}'::jsonb),
      '{totals}',
      COALESCE(v_snapshot_totals, '{}'::jsonb) || jsonb_build_object(
        'roll_msrp_total', v_roll_msrp_total,
        'bom_total', v_bom_total,
        'accessories_total', v_accessories_total,
        'labor_amount', v_labor_msrp,
        'total_msrp', v_unit_msrp_total,
        'roll_total_cost', v_roll_total_cost_landed,
        'bom_total_cost', v_bom_total_cost_landed,
        'msrp_product_subtotal', v_msrp_product_subtotal,
        'labor_msrp', v_labor_msrp,
        'unit_msrp_total', v_unit_msrp_total,
        'unit_product_cost_landed', v_unit_product_cost_landed,
        'unit_labor_cost', v_unit_labor_cost,
        'roll_total_cost_landed', v_roll_total_cost_landed,
        'bom_total_cost_landed', v_bom_total_cost_landed,
        'accessories_total_cost_landed', v_accessories_total_cost_landed,
        'total_cost_landed_without_labor', v_total_cost_landed_without_labor,
        'total_cost_with_labor', v_total_cost_with_labor
      ),
      true
    ),
    updated_at = now()
  WHERE id = p_configured_product_id;

  RETURN jsonb_build_object(
    'configured_product_id', p_configured_product_id,
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_total,
    'accessories_total', v_accessories_total,
    'msrp_product_subtotal', v_msrp_product_subtotal,
    'labor_msrp', v_labor_msrp,
    'unit_msrp_total', v_unit_msrp_total,
    'total_msrp', v_unit_msrp_total,
    'roll_total_cost_landed', v_roll_total_cost_landed,
    'bom_total_cost_landed', v_bom_total_cost_landed,
    'accessories_total_cost_landed', v_accessories_total_cost_landed,
    'unit_product_cost_landed', v_unit_product_cost_landed,
    'unit_labor_cost', v_unit_labor_cost,
    'total_cost_landed_without_labor', v_total_cost_landed_without_labor,
    'total_cost_with_labor', v_total_cost_with_labor,
    'roll_total_cost', v_roll_total_cost_landed,
    'bom_total_cost', v_bom_total_cost_landed,
    'total_cost', v_total_cost_with_labor
  );
END;
$$;

COMMENT ON FUNCTION public.calculate_configured_product_totals(uuid) IS
'Computes per-unit MSRP and landed costs for ConfiguredProducts: product subtotal vs labor split, then writes compatible legacy + new columns and snapshot totals.';

-- ----------------------------------------------------------------------------
-- 4) QuoteLine RPCs: commit + sync + recompute with split fields
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.commit_configured_product_to_quote_line(
  p_org_id uuid,
  p_quote_id uuid,
  p_configured_product_id uuid,
  p_dealer_id uuid DEFAULT NULL,
  p_position text DEFAULT NULL,
  p_area text DEFAULT NULL,
  p_fabric_drop text DEFAULT NULL,
  p_installation_type text DEFAULT NULL,
  p_installation_location text DEFAULT NULL
)
RETURNS TABLE(quote_line_id uuid, bom_instance_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cp RECORD;
  v_roll_item RECORD;
  v_quote_line_id uuid;
  v_bom_instance_id uuid;
  v_width_m numeric(12,4);
  v_height_m numeric(12,4);
  v_line_quantity numeric(12,4);
  v_operating_type text;
  v_unit_msrp_product_subtotal numeric(12,4);
  v_unit_labor_msrp numeric(12,4);
  v_unit_msrp numeric(12,4);
  v_unit_product_cost numeric(12,4);
  v_unit_labor_cost numeric(12,4);
  v_unit_cost numeric(12,4);
BEGIN
  IF p_org_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_org_id is required'; END IF;
  IF p_quote_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_quote_id is required'; END IF;
  IF p_configured_product_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_configured_product_id is required'; END IF;

  -- Always recompute to avoid stale/zero landed costs.
  PERFORM public.calculate_configured_product_totals(p_configured_product_id);

  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found or does not belong to org %', p_configured_product_id, p_org_id;
  END IF;

  v_line_quantity := GREATEST(COALESCE(v_cp.quantity, 1), 1);
  v_width_m := COALESCE(v_cp.width_mm / 1000.0, 0);
  v_height_m := COALESCE(v_cp.height_mm / 1000.0, 0);
  v_operating_type := COALESCE(v_cp.config_snapshot->>'operating_type', v_cp.config_snapshot->>'drive_type', v_cp.config_snapshot->>'operation_type');

  v_unit_msrp_product_subtotal := COALESCE(v_cp.msrp_product_subtotal, COALESCE(v_cp.roll_msrp_total, 0) + COALESCE(v_cp.bom_total, 0) + COALESCE(v_cp.accessories_total, 0));
  v_unit_labor_msrp := COALESCE(v_cp.labor_msrp, v_cp.labor_amount, 0);
  v_unit_msrp := v_unit_msrp_product_subtotal + v_unit_labor_msrp;

  v_unit_product_cost := COALESCE(v_cp.unit_product_cost_landed, COALESCE(v_cp.roll_total_cost_landed, 0) + COALESCE(v_cp.bom_total_cost_landed, 0) + COALESCE(v_cp.accessories_total_cost_landed, 0));
  v_unit_labor_cost := COALESCE(v_cp.unit_labor_cost, 0);
  v_unit_cost := v_unit_product_cost + v_unit_labor_cost;

  SELECT ci.sku, ci.name, ci.category_id, ci.manufacturer_id, m.name AS manufacturer_name,
         ci.collection_name, ci.variant_name, COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_m
  INTO v_roll_item
  FROM public."CatalogItems" ci
  LEFT JOIN public."Manufacturers" m ON m.id = ci.manufacturer_id
  WHERE ci.id = v_cp.roll_catalog_item_id
    AND ci.is_active = true
  LIMIT 1;

  INSERT INTO public."QuoteLines" (
    organization_id, dealer_id, quote_id,
    product_type_id, configured_product_id, bom_template_id,
    catalog_item_id, sku, name, category_id, manufacturer_id, manufacturer, collection_name, variant_name, is_roll, roll_type, roll_width_m,
    width_m, height_m, quantity,
    hardware_color, drive_type, position, area, fabric_drop, installation_type, installation_location,
    roll_msrp_snapshot, bom_msrp_snapshot, accessories_msrp_snapshot, labor_msrp_snapshot,
    roll_cost_snapshot, bom_cost_snapshot, accessories_cost_snapshot, labor_cost_snapshot,
    unit_msrp_product_subtotal, unit_labor_msrp, unit_msrp, msrp,
    unit_product_cost, unit_labor_cost, unit_cost, total_cost,
    pricing_locked, last_priced_at, pricing_version
  )
  VALUES (
    p_org_id,
    COALESCE(p_dealer_id, (SELECT dealer_id FROM public."Quotes" WHERE id = p_quote_id LIMIT 1)),
    p_quote_id,
    v_cp.product_type_id, v_cp.id, v_cp.bom_template_id,
    v_cp.roll_catalog_item_id, COALESCE(v_cp.roll_sku, v_roll_item.sku), v_roll_item.name, v_roll_item.category_id, v_roll_item.manufacturer_id, v_roll_item.manufacturer_name,
    COALESCE(v_cp.roll_collection_name, v_roll_item.collection_name), COALESCE(v_cp.roll_variant_name, v_roll_item.variant_name),
    v_cp.roll_catalog_item_id IS NOT NULL, CASE WHEN v_cp.roll_catalog_item_id IS NOT NULL THEN 'fabric' ELSE NULL END, COALESCE(v_cp.roll_width, v_roll_item.roll_width_m),
    v_width_m, v_height_m, v_line_quantity,
    v_cp.hardware_color, v_operating_type, p_position, p_area, p_fabric_drop, p_installation_type, p_installation_location,
    COALESCE(v_cp.roll_msrp_total, 0), COALESCE(v_cp.bom_total, 0), COALESCE(v_cp.accessories_total, 0), v_unit_labor_msrp,
    COALESCE(v_cp.roll_total_cost_landed, 0), COALESCE(v_cp.bom_total_cost_landed, 0), COALESCE(v_cp.accessories_total_cost_landed, 0), v_unit_labor_cost,
    v_unit_msrp_product_subtotal, v_unit_labor_msrp, v_unit_msrp, ROUND(v_unit_msrp * v_line_quantity, 2),
    v_unit_product_cost, v_unit_labor_cost, v_unit_cost, ROUND(v_unit_cost * v_line_quantity, 2),
    true, now(), 1
  )
  RETURNING id INTO v_quote_line_id;

  v_bom_instance_id := NULL;
  RETURN QUERY SELECT v_quote_line_id, v_bom_instance_id;
END;
$$;

COMMENT ON FUNCTION public.commit_configured_product_to_quote_line(uuid, uuid, uuid, uuid, text, text, text, text, text) IS
'Creates QuoteLine from ConfiguredProduct with per-unit semantic split: product subtotal vs labor MSRP/cost, then scales by quantity.';

CREATE OR REPLACE FUNCTION public.sync_quote_line_pricing_from_configured_product(p_quote_line_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ql RECORD;
  v_cp RECORD;
  v_qty numeric(12,4);
  v_unit_msrp_product_subtotal numeric(12,4);
  v_unit_labor_msrp numeric(12,4);
  v_unit_msrp numeric(12,4);
  v_unit_product_cost numeric(12,4);
  v_unit_labor_cost numeric(12,4);
  v_unit_cost numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'sync_quote_line_pricing_from_configured_product: p_quote_line_id is required';
  END IF;

  SELECT id, organization_id, configured_product_id, quantity
  INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;
  IF v_ql.configured_product_id IS NULL THEN
    RETURN;
  END IF;

  PERFORM public.calculate_configured_product_totals(v_ql.configured_product_id);

  SELECT *
  INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = v_ql.configured_product_id
    AND organization_id = v_ql.organization_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found for QuoteLine %', v_ql.configured_product_id, p_quote_line_id;
  END IF;

  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);

  v_unit_msrp_product_subtotal := COALESCE(v_cp.msrp_product_subtotal, COALESCE(v_cp.roll_msrp_total, 0) + COALESCE(v_cp.bom_total, 0) + COALESCE(v_cp.accessories_total, 0));
  v_unit_labor_msrp := COALESCE(v_cp.labor_msrp, v_cp.labor_amount, 0);
  v_unit_msrp := v_unit_msrp_product_subtotal + v_unit_labor_msrp;

  v_unit_product_cost := COALESCE(v_cp.unit_product_cost_landed, COALESCE(v_cp.roll_total_cost_landed, 0) + COALESCE(v_cp.bom_total_cost_landed, 0) + COALESCE(v_cp.accessories_total_cost_landed, 0));
  v_unit_labor_cost := COALESCE(v_cp.unit_labor_cost, 0);
  v_unit_cost := v_unit_product_cost + v_unit_labor_cost;

  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  UPDATE public."QuoteLines"
  SET
    roll_msrp_snapshot = COALESCE(v_cp.roll_msrp_total, 0),
    bom_msrp_snapshot = COALESCE(v_cp.bom_total, 0),
    accessories_msrp_snapshot = COALESCE(v_cp.accessories_total, 0),
    labor_msrp_snapshot = v_unit_labor_msrp,
    roll_cost_snapshot = COALESCE(v_cp.roll_total_cost_landed, 0),
    bom_cost_snapshot = COALESCE(v_cp.bom_total_cost_landed, 0),
    accessories_cost_snapshot = COALESCE(v_cp.accessories_total_cost_landed, 0),
    labor_cost_snapshot = v_unit_labor_cost,
    unit_msrp_product_subtotal = v_unit_msrp_product_subtotal,
    unit_labor_msrp = v_unit_labor_msrp,
    unit_msrp = v_unit_msrp,
    msrp = ROUND(v_unit_msrp * v_qty, 2),
    unit_product_cost = v_unit_product_cost,
    unit_labor_cost = v_unit_labor_cost,
    unit_cost = v_unit_cost,
    total_cost = ROUND(v_unit_cost * v_qty, 2),
    last_priced_at = now(),
    pricing_version = COALESCE(pricing_version, 0) + 1,
    pricing_locked = true
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;

COMMENT ON FUNCTION public.sync_quote_line_pricing_from_configured_product(uuid) IS
'Syncs QuoteLine from ConfiguredProduct after recomputing CP totals. Writes split fields and enforces unit*quantity invariants.';

CREATE OR REPLACE FUNCTION public.recompute_quote_line_costs(p_quote_line_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ql RECORD;
  v_qty numeric(12,4);
  v_unit_msrp numeric(12,4);
  v_unit_labor_msrp numeric(12,4);
  v_unit_msrp_product_subtotal numeric(12,4);
  v_unit_cost numeric(12,4);
  v_unit_labor_cost numeric(12,4);
  v_unit_product_cost numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'recompute_quote_line_costs: p_quote_line_id is required';
  END IF;

  SELECT *
  INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  IF v_ql.configured_product_id IS NOT NULL THEN
    PERFORM public.sync_quote_line_pricing_from_configured_product(p_quote_line_id);
    RETURN;
  END IF;

  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);

  v_unit_labor_msrp := COALESCE(v_ql.unit_labor_msrp, v_ql.labor_msrp_snapshot, 0);
  v_unit_msrp_product_subtotal := COALESCE(v_ql.unit_msrp_product_subtotal, COALESCE(v_ql.roll_msrp_snapshot, 0) + COALESCE(v_ql.bom_msrp_snapshot, 0) + COALESCE(v_ql.accessories_msrp_snapshot, 0));
  v_unit_msrp := COALESCE(v_ql.unit_msrp, v_unit_msrp_product_subtotal + v_unit_labor_msrp, 0);

  v_unit_labor_cost := COALESCE(v_ql.unit_labor_cost, v_ql.labor_cost_snapshot, 0);
  v_unit_product_cost := COALESCE(v_ql.unit_product_cost, COALESCE(v_ql.roll_cost_snapshot, 0) + COALESCE(v_ql.bom_cost_snapshot, 0) + COALESCE(v_ql.accessories_cost_snapshot, 0));
  v_unit_cost := COALESCE(v_ql.unit_cost, v_unit_product_cost + v_unit_labor_cost, 0);

  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  UPDATE public."QuoteLines"
  SET
    unit_labor_msrp = v_unit_labor_msrp,
    unit_msrp_product_subtotal = v_unit_msrp_product_subtotal,
    unit_msrp = v_unit_msrp,
    msrp = ROUND(v_unit_msrp * v_qty, 2),
    unit_labor_cost = v_unit_labor_cost,
    unit_product_cost = v_unit_product_cost,
    unit_cost = v_unit_cost,
    total_cost = ROUND(v_unit_cost * v_qty, 2),
    last_priced_at = now()
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;

COMMENT ON FUNCTION public.recompute_quote_line_costs(uuid) IS
'Recomputes QuoteLine pricing/costs. Delegates to sync if configured_product_id exists; otherwise enforces split + unit*qty invariants.';

-- ----------------------------------------------------------------------------
-- 5) Guard rail: extend trigger to new pricing columns
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_quote_lines_guard_pricing_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pricing_changed boolean := false;
  v_allowed text;
BEGIN
  v_allowed := current_setting('app.allow_quote_line_pricing_update', true);

  IF (OLD.msrp IS DISTINCT FROM NEW.msrp)
     OR (OLD.unit_msrp IS DISTINCT FROM NEW.unit_msrp)
     OR (OLD.unit_msrp_product_subtotal IS DISTINCT FROM NEW.unit_msrp_product_subtotal)
     OR (OLD.unit_labor_msrp IS DISTINCT FROM NEW.unit_labor_msrp)
     OR (OLD.roll_msrp_snapshot IS DISTINCT FROM NEW.roll_msrp_snapshot)
     OR (OLD.bom_msrp_snapshot IS DISTINCT FROM NEW.bom_msrp_snapshot)
     OR (OLD.accessories_msrp_snapshot IS DISTINCT FROM NEW.accessories_msrp_snapshot)
     OR (OLD.labor_msrp_snapshot IS DISTINCT FROM NEW.labor_msrp_snapshot)
     OR (OLD.roll_cost_snapshot IS DISTINCT FROM NEW.roll_cost_snapshot)
     OR (OLD.bom_cost_snapshot IS DISTINCT FROM NEW.bom_cost_snapshot)
     OR (OLD.accessories_cost_snapshot IS DISTINCT FROM NEW.accessories_cost_snapshot)
     OR (OLD.labor_cost_snapshot IS DISTINCT FROM NEW.labor_cost_snapshot)
     OR (OLD.unit_product_cost IS DISTINCT FROM NEW.unit_product_cost)
     OR (OLD.unit_labor_cost IS DISTINCT FROM NEW.unit_labor_cost)
     OR (OLD.unit_cost IS DISTINCT FROM NEW.unit_cost)
     OR (OLD.total_cost IS DISTINCT FROM NEW.total_cost)
     OR (OLD.last_priced_at IS DISTINCT FROM NEW.last_priced_at)
     OR (OLD.pricing_version IS DISTINCT FROM NEW.pricing_version)
     OR (OLD.pricing_locked IS DISTINCT FROM NEW.pricing_locked)
  THEN
    v_pricing_changed := true;
  END IF;

  IF v_pricing_changed AND COALESCE(trim(v_allowed), '') <> 'true' THEN
    RAISE EXCEPTION 'QuoteLines pricing columns can only be updated via pricing RPCs.';
  END IF;

  RETURN NEW;
END;
$$;

-- ----------------------------------------------------------------------------
-- 6) Backfill: recompute all ConfiguredProducts + QuoteLines consistency
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_cp RECORD;
  v_ql RECORD;
  v_qty numeric(12,4);
BEGIN
  -- A) Recompute all configured products to populate landed costs and splits
  FOR v_cp IN
    SELECT id
    FROM public."ConfiguredProducts"
    WHERE deleted = false
  LOOP
    BEGIN
      PERFORM public.calculate_configured_product_totals(v_cp.id);
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;

  -- B) Sync quote lines linked to configured products
  FOR v_ql IN
    SELECT id
    FROM public."QuoteLines"
    WHERE configured_product_id IS NOT NULL
  LOOP
    BEGIN
      PERFORM public.sync_quote_line_pricing_from_configured_product(v_ql.id);
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;

  -- C) Legacy quote lines (without configured_product_id): derive split and enforce invariants
  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  UPDATE public."QuoteLines"
  SET
    unit_labor_msrp = COALESCE(unit_labor_msrp, labor_msrp_snapshot, 0),
    unit_msrp_product_subtotal = COALESCE(unit_msrp_product_subtotal, COALESCE(unit_msrp, 0) - COALESCE(unit_labor_msrp, labor_msrp_snapshot, 0)),
    unit_product_cost = COALESCE(unit_product_cost, COALESCE(roll_cost_snapshot, 0) + COALESCE(bom_cost_snapshot, 0) + COALESCE(accessories_cost_snapshot, 0)),
    unit_labor_cost = COALESCE(unit_labor_cost, labor_cost_snapshot, 0),
    unit_cost = COALESCE(unit_cost, COALESCE(unit_product_cost, COALESCE(roll_cost_snapshot, 0) + COALESCE(bom_cost_snapshot, 0) + COALESCE(accessories_cost_snapshot, 0)) + COALESCE(unit_labor_cost, labor_cost_snapshot, 0)),
    unit_msrp = COALESCE(unit_msrp, COALESCE(unit_msrp_product_subtotal, 0) + COALESCE(unit_labor_msrp, 0))
  WHERE configured_product_id IS NULL;

  UPDATE public."QuoteLines"
  SET
    msrp = ROUND(COALESCE(unit_msrp, 0) * GREATEST(COALESCE(quantity, 1), 0.001), 2),
    total_cost = ROUND(COALESCE(unit_cost, 0) * GREATEST(COALESCE(quantity, 1), 0.001), 2),
    last_priced_at = COALESCE(last_priced_at, now())
  WHERE configured_product_id IS NULL;

  -- D) Unify on msrp_product_subtotal: fix rows where it is 0 (derive from roll + bom + accessories)
  UPDATE public."ConfiguredProducts"
  SET msrp_product_subtotal = COALESCE(roll_msrp_total, 0) + COALESCE(bom_total, 0) + COALESCE(accessories_total, 0)
  WHERE deleted = false
    AND (msrp_product_subtotal IS NULL OR msrp_product_subtotal = 0)
    AND (COALESCE(roll_msrp_total, 0) + COALESCE(bom_total, 0) + COALESCE(accessories_total, 0)) > 0;
END $$;

