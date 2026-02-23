-- ============================================================================
-- Arreglar cálculo MSRP/Total MSRP en ConfiguredProducts + QuoteLines
-- Fecha: 2026-03-08
--
-- Contexto: Schema actual. No existen msrp_sale_out / msrp_sale_in ni BOMTemplateLines.
-- CatalogItemsMSRP: msrp (sale-out), dealer_price (sale-in), total_cost, updated_at,
--   unit_of_measure, labor_msrp, msrp_pct, minimum_margin_pct.
-- BOM en JSON: ConfiguredProducts.config_snapshot / bom_preview_snapshot.
--
-- Tareas:
-- 1) Helper get_roll_pricing(org_id, roll_catalog_item_id) desde CatalogItemsMSRP.
-- 2) build_bom_preview_snapshot: sin legacy; usar get_roll_pricing para roll.
-- 3) calculate_configured_product_totals: get_roll_pricing; parche roll_qty mínimo (no devolver 0 si hay msrp).
-- 4) sync_quote_line_pricing_from_configured_product: msrp/unit desde cp.total_msrp × quantity.
-- ============================================================================

-- ============================================================================
-- 1) Helper: get_roll_pricing(org_id, roll_catalog_item_id)
-- Retorna una fila desde CatalogItemsMSRP ordenada por updated_at DESC LIMIT 1.
-- Columnas: msrp, dealer_price, labor_msrp, msrp_pct, minimum_margin_pct.
-- Compatible con msrp_pct o msrp_pct_sale_out.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_roll_pricing(
  p_org_id uuid,
  p_roll_catalog_item_id uuid
)
RETURNS TABLE(
  msrp numeric,
  dealer_price numeric,
  labor_msrp numeric,
  msrp_pct numeric,
  minimum_margin_pct numeric
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_use_msrp_pct_sale_out boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'CatalogItemsMSRP' AND column_name = 'msrp_pct_sale_out'
  )
  AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'CatalogItemsMSRP' AND column_name = 'msrp_pct'
  )
  INTO v_use_msrp_pct_sale_out;

  IF v_use_msrp_pct_sale_out THEN
    RETURN QUERY
    SELECT
      cim.msrp,
      cim.dealer_price,
      COALESCE(cim.labor_msrp, 0),
      cim.msrp_pct_sale_out,
      COALESCE(cim.minimum_margin_pct, 0)
    FROM public."CatalogItemsMSRP" cim
    WHERE cim.organization_id = p_org_id
      AND cim.catalog_item_id = p_roll_catalog_item_id
    ORDER BY cim.updated_at DESC NULLS LAST
    LIMIT 1;
  ELSE
    RETURN QUERY
    SELECT
      cim.msrp,
      cim.dealer_price,
      COALESCE(cim.labor_msrp, 0),
      COALESCE(cim.msrp_pct, 0),
      COALESCE(cim.minimum_margin_pct, 0)
    FROM public."CatalogItemsMSRP" cim
    WHERE cim.organization_id = p_org_id
      AND cim.catalog_item_id = p_roll_catalog_item_id
    ORDER BY cim.updated_at DESC NULLS LAST
    LIMIT 1;
  END IF;
END;
$$;

COMMENT ON FUNCTION public.get_roll_pricing(uuid, uuid) IS
'Precios del roll desde CatalogItemsMSRP. Una fila por (org, catalog_item_id), ordenada por updated_at DESC. Columnas: msrp (sale-out), dealer_price (sale-in), labor_msrp, msrp_pct, minimum_margin_pct. Sin legacy (msrp_sale_out, msrp_sale_in, effective_from/to).';


-- ============================================================================
-- 2) build_bom_preview_snapshot
-- Usar get_roll_pricing para el roll. Sin referencias a msrp_sale_out, msrp_sale_in,
-- effective_from/effective_to ni BOMTemplateLines (ya usa BOMComponents).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.build_bom_preview_snapshot(
  p_org_id uuid,
  p_configured_product_id uuid,
  p_bom_template_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_cp RECORD;
  v_items jsonb := '[]'::jsonb;
  v_totals jsonb;
  v_comp RECORD;
  v_child RECORD;
  v_item_info RECORD;
  v_msrp_info RECORD;
  v_roll_msrp_unit numeric := 0;
  v_roll_dealer_unit numeric := 0;
  v_roll_labor_unit numeric := 0;
  v_qty numeric;
  v_unit_price numeric;
  v_line_total numeric;
  v_width_mm numeric;
  v_height_mm numeric;
  v_width_m numeric;
  v_height_m numeric;
  v_area_m2 numeric;
  v_roll_item jsonb;
  v_parent_items jsonb := '[]'::jsonb;
  v_children jsonb;
  v_item_id text;
  v_selected boolean;
  v_roll_msrp_total numeric;
  v_bom_sum numeric;
  v_labor_amount numeric;
  v_accessories_total numeric;
  v_total_msrp numeric;
  v_child_unit_price numeric;
  v_child_line_total numeric;
  v_roll_total_cost numeric;
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  v_width_mm := COALESCE(v_cp.width_mm, 0);
  v_height_mm := COALESCE(v_cp.height_mm, 0);
  v_width_m := v_width_mm / 1000.0;
  v_height_m := v_height_mm / 1000.0;
  v_area_m2 := v_width_m * v_height_m;

  -- Roll: precios desde get_roll_pricing (CatalogItemsMSRP, sin legacy)
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT r.msrp, r.dealer_price, r.labor_msrp
    INTO v_roll_msrp_unit, v_roll_dealer_unit, v_roll_labor_unit
    FROM public.get_roll_pricing(p_org_id, v_cp.roll_catalog_item_id) r;

    SELECT ci.sku, ci.name, ci.unit_of_measure
      INTO v_item_info
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id
      AND ci.organization_id = p_org_id
    LIMIT 1;

    -- total_cost desde CatalogItemsMSRP (misma fila: updated_at desc limit 1)
    SELECT cim.total_cost INTO v_roll_total_cost
    FROM public."CatalogItemsMSRP" cim
    WHERE cim.catalog_item_id = v_cp.roll_catalog_item_id
      AND cim.organization_id = p_org_id
    ORDER BY cim.updated_at DESC NULLS LAST
    LIMIT 1;

    v_qty := v_area_m2 * COALESCE(v_cp.quantity, 1);
    v_unit_price := COALESCE(v_roll_msrp_unit, 0);
    v_line_total := ROUND(v_qty * v_unit_price, 2);

    v_roll_item := jsonb_build_object(
      'id', COALESCE(v_cp.roll_catalog_item_id::text, 'roll:' || COALESCE(v_cp.roll_sku, 'unknown')),
      'kind', 'roll',
      'role', 'fabric',
      'level', 0,
      'selected', true,
      'catalog_item_id', v_cp.roll_catalog_item_id,
      'sku', v_cp.roll_sku,
      'name', COALESCE(v_cp.roll_variant_name, v_item_info.name, v_cp.roll_sku),
      'qty', ROUND(v_qty, 3),
      'uom', 'm²',
      'unit_price', v_unit_price,
      'line_total', v_line_total,
      'children', '[]'::jsonb,
      'meta', jsonb_build_object(
        'collection_name', v_cp.roll_collection_name,
        'variant_name', v_cp.roll_variant_name,
        'roll_width', v_cp.roll_width
      )
    );
    v_items := v_items || v_roll_item;
  ELSE
    v_roll_total_cost := 0;
  END IF;

  -- BOM: desde BOMComponents (no BOMTemplateLines)
  IF p_bom_template_id IS NOT NULL THEN
    FOR v_comp IN
      SELECT
        bc.id,
        bc.component_role,
        bc.component_item_id,
        bc.qty_type,
        bc.qty_value,
        bc.qty_delta_mm,
        bc.uom,
        bc.parent_component_id,
        bc.sort_order
      FROM public."BOMComponents" bc
      WHERE bc.bom_template_id = p_bom_template_id
        AND bc.organization_id = p_org_id
        AND bc.deleted = false
        AND bc.archived = false
        AND bc.parent_component_id IS NULL
      ORDER BY bc.sort_order ASC
    LOOP
      v_selected := false;
      DECLARE
        v_role_lower text := lower(v_comp.component_role);
        v_selected_id uuid;
      BEGIN
        CASE v_role_lower
          WHEN 'bottom_bar' THEN v_selected_id := v_cp.bottom_bar_item_id;
          WHEN 'headbox' THEN v_selected_id := v_cp.headbox_item_id;
          WHEN 'side_channel' THEN v_selected_id := v_cp.side_channel_item_id;
          WHEN 'bottom_channel' THEN v_selected_id := v_cp.bottom_channel_item_id;
          WHEN 'motor' THEN v_selected_id := v_cp.motor_item_id;
          WHEN 'drive' THEN v_selected_id := v_cp.drive_item_id;
          WHEN 'tube' THEN v_selected_id := v_cp.tube_item_id;
          ELSE v_selected_id := NULL;
        END CASE;
        IF v_selected_id IS NOT NULL THEN
          v_comp.component_item_id := v_selected_id;
          v_selected := true;
        END IF;
      END;

      IF v_comp.component_item_id IS NULL THEN
        CONTINUE;
      END IF;

      SELECT ci.sku, ci.name, ci.unit_of_measure
        INTO v_item_info
      FROM public."CatalogItems" ci
      WHERE ci.id = v_comp.component_item_id
        AND ci.organization_id = p_org_id
      LIMIT 1;

      SELECT cim.msrp, cim.total_cost INTO v_msrp_info
      FROM public."CatalogItemsMSRP" cim
      WHERE cim.catalog_item_id = v_comp.component_item_id
        AND cim.organization_id = p_org_id
      ORDER BY cim.updated_at DESC NULLS LAST
      LIMIT 1;

      v_qty := COALESCE(v_comp.qty_value, 1);
      CASE COALESCE(v_comp.qty_type, 'fixed')
        WHEN 'per_width', 'width' THEN
          v_qty := GREATEST(0, (v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
        WHEN 'per_height', 'height' THEN
          v_qty := GREATEST(0, (v_height_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
        WHEN 'per_m2', 'area' THEN
          v_qty := GREATEST(0, v_area_m2);
        ELSE
          v_qty := COALESCE(v_comp.qty_value, 1);
      END CASE;

      v_unit_price := COALESCE(v_msrp_info.msrp, 0);
      v_line_total := ROUND(v_qty * v_unit_price, 2);

      v_children := '[]'::jsonb;
      FOR v_child IN
        SELECT
          bc.id,
          bc.component_role,
          bc.component_item_id,
          bc.qty_type,
          bc.qty_value,
          bc.qty_delta_mm,
          bc.uom
        FROM public."BOMComponents" bc
        WHERE bc.parent_component_id = v_comp.id
          AND bc.organization_id = p_org_id
          AND bc.deleted = false
          AND bc.archived = false
        ORDER BY bc.sort_order ASC
      LOOP
        IF v_child.component_item_id IS NULL THEN
          CONTINUE;
        END IF;

        SELECT ci.sku, ci.name, ci.unit_of_measure
          INTO v_item_info
        FROM public."CatalogItems" ci
        WHERE ci.id = v_child.component_item_id
          AND ci.organization_id = p_org_id
        LIMIT 1;

        SELECT cim.msrp, cim.total_cost INTO v_msrp_info
        FROM public."CatalogItemsMSRP" cim
        WHERE cim.catalog_item_id = v_child.component_item_id
          AND cim.organization_id = p_org_id
        ORDER BY cim.updated_at DESC NULLS LAST
        LIMIT 1;

        DECLARE
          v_child_qty numeric;
          v_child_line_total numeric;
        BEGIN
          v_child_qty := COALESCE(v_child.qty_value, 1);
          CASE COALESCE(v_child.qty_type, 'fixed')
            WHEN 'per_width', 'width' THEN
              v_child_qty := GREATEST(0, (v_width_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
            WHEN 'per_height', 'height' THEN
              v_child_qty := GREATEST(0, (v_height_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
            WHEN 'per_m2', 'area' THEN
              v_child_qty := GREATEST(0, v_area_m2);
            ELSE
              v_child_qty := COALESCE(v_child.qty_value, 1);
          END CASE;

          v_child_unit_price := COALESCE(v_msrp_info.msrp, 0);
          v_child_line_total := ROUND(v_child_qty * v_child_unit_price, 2);

          v_children := v_children || jsonb_build_object(
            'id', v_child.id::text,
            'kind', 'child',
            'role', COALESCE(v_child.component_role, 'child'),
            'level', 1,
            'selected', false,
            'catalog_item_id', v_child.component_item_id,
            'sku', v_item_info.sku,
            'name', v_item_info.name,
            'qty', ROUND(v_child_qty, 3),
            'uom', COALESCE(v_child.uom, v_item_info.unit_of_measure, 'ea'),
            'unit_price', v_child_unit_price,
            'line_total', v_child_line_total,
            'children', '[]'::jsonb,
            'meta', '{}'::jsonb
          );
        END;
      END LOOP;

      v_items := v_items || jsonb_build_object(
        'id', v_comp.id::text,
        'kind', 'parent',
        'role', COALESCE(v_comp.component_role, 'component'),
        'level', 0,
        'selected', v_selected,
        'catalog_item_id', v_comp.component_item_id,
        'sku', v_item_info.sku,
        'name', v_item_info.name,
        'qty', ROUND(v_qty, 3),
        'uom', COALESCE(v_comp.uom, v_item_info.unit_of_measure, 'ea'),
        'unit_price', v_unit_price,
        'line_total', v_line_total,
        'children', v_children,
        'meta', '{}'::jsonb
      );
    END LOOP;
  END IF;

  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id;

  SELECT COALESCE(SUM((item->>'line_total')::numeric), 0)
  INTO v_roll_msrp_total
  FROM jsonb_array_elements(v_items) AS item
  WHERE item->>'kind' = 'roll';

  IF v_roll_msrp_total = 0 THEN
    v_roll_msrp_total := COALESCE(v_cp.roll_msrp_total, 0);
  END IF;

  SELECT COALESCE(SUM(
    (item->>'line_total')::numeric +
    COALESCE((
      SELECT SUM((c->>'line_total')::numeric)
      FROM jsonb_array_elements(COALESCE(item->'children', '[]'::jsonb)) c
    ), 0)
  ), 0)
  INTO v_bom_sum
  FROM jsonb_array_elements(v_items) AS item
  WHERE item->>'kind' = 'parent';

  IF v_bom_sum = 0 THEN
    v_bom_sum := COALESCE(v_cp.bom_total, 0);
  END IF;

  v_labor_amount := COALESCE(v_cp.labor_amount, 0);
  v_accessories_total := COALESCE(v_cp.accessories_total, 0);

  IF v_labor_amount = 0 AND COALESCE(v_cp.labor_pct, 0) > 0 THEN
    v_labor_amount := (v_roll_msrp_total + v_bom_sum) * (v_cp.labor_pct / 100.0);
  END IF;

  v_total_msrp := v_roll_msrp_total + v_bom_sum + v_labor_amount + v_accessories_total;

  v_totals := jsonb_build_object(
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_sum,
    'accessories_total', v_accessories_total,
    'labor_pct', COALESCE(v_cp.labor_pct, 0),
    'labor_amount', v_labor_amount,
    'total_msrp', v_total_msrp,
    'roll_total_cost', COALESCE(v_roll_total_cost, v_cp.roll_total_cost_landed, v_cp.roll_total_cost, 0),
    'bom_total_cost', COALESCE(v_cp.bom_total_cost_landed, v_cp.bom_total_cost, 0)
  );

  RETURN jsonb_build_object(
    'version', '1',
    'product_type_id', v_cp.product_type_id,
    'bom_template_id', p_bom_template_id,
    'price_basis', 'msrp',
    'currency', 'USD',
    'totals', v_totals,
    'items', v_items
  );
END;
$$;

COMMENT ON FUNCTION public.build_bom_preview_snapshot(uuid, uuid, uuid) IS
'Construye bom_preview_snapshot JSONB. Roll desde get_roll_pricing (CatalogItemsMSRP). BOM desde BOMComponents. Sin msrp_sale_out, msrp_sale_in, effective_from/to, BOMTemplateLines.';


-- ============================================================================
-- 3) calculate_configured_product_totals
-- Roll con get_roll_pricing. Si no hay roll_qty en JSON, parche mínimo: usar msrp unitario (factor 1) para no devolver 0.
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

  v_roll RECORD;
  v_roll_factor numeric := 0;
  v_roll_msrp_total numeric := 0;
  v_roll_dealer_total numeric := 0;
  v_bom_total numeric := 0;
  v_accessories_total numeric := 0;
  v_labor_msrp numeric := 0;
  v_msrp_product_subtotal numeric := 0;
  v_unit_msrp_total numeric := 0;
  v_unit_dealer_price numeric := 0;

  v_item_id uuid;
  v_item_qty numeric;
  v_item_msrp numeric;
  v_item_cost numeric;
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

  -- Roll: get_roll_pricing (CatalogItemsMSRP; sin legacy)
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT r.msrp, r.dealer_price, r.labor_msrp
    INTO v_roll
    FROM public.get_roll_pricing(v_cp.organization_id, v_cp.roll_catalog_item_id) r;

    IF FOUND THEN
      DECLARE
        v_roll_pricing_mode text;
        v_roll_measure_basis text;
        v_qty_from_json numeric;
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

        -- Parche mínimo: si factor es 0, usar 1 para no devolver total_msrp=0 cuando hay msrp en CatalogItemsMSRP
        v_qty_from_json := (v_snapshot_totals->>'roll_qty')::numeric;
        IF COALESCE(v_roll_factor, 0) = 0 AND v_qty_from_json IS NULL THEN
          v_roll_factor := 1;
        ELSIF v_qty_from_json IS NOT NULL AND v_qty_from_json > 0 THEN
          v_roll_factor := v_qty_from_json;
        END IF;

        v_roll_msrp_total   := COALESCE(v_roll.msrp, 0) * GREATEST(v_roll_factor, 0);
        v_roll_dealer_total := COALESCE(v_roll.dealer_price, 0) * GREATEST(v_roll_factor, 0);
        v_labor_msrp        := COALESCE(v_roll.labor_msrp, 0);
      END;
    END IF;
  END IF;

  v_bom_total         := COALESCE((v_snapshot_totals->>'bom_total')::numeric, v_cp.bom_total, 0);
  v_accessories_total := COALESCE((v_snapshot_totals->>'accessories_total')::numeric, v_cp.accessories_total, 0);

  v_msrp_product_subtotal := v_roll_msrp_total;

  IF v_labor_msrp = 0 AND COALESCE(v_cp.labor_pct, 0) > 0 THEN
    v_labor_msrp := (v_roll_msrp_total + v_bom_total + v_accessories_total)
      * CASE WHEN v_cp.labor_pct <= 1 THEN v_cp.labor_pct ELSE (v_cp.labor_pct / 100.0) END;
  END IF;

  v_unit_msrp_total := v_roll_msrp_total + v_labor_msrp + v_bom_total + v_accessories_total;
  v_unit_dealer_price := v_roll_dealer_total + v_bom_total + v_accessories_total + v_labor_msrp;
  IF v_unit_dealer_price = 0 THEN
    v_unit_dealer_price := v_unit_msrp_total;
  END IF;

  -- Costos (sin cambiar lógica)
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
      IF COALESCE(v_roll_factor, 0) = 0 THEN
        v_roll_factor := 1;
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
        'bom_total_cost_landed',           v_bom_total_cost_landed,
        'accessories_total_cost_landed',  v_accessories_total_cost_landed,
        'total_cost_landed_without_labor', v_total_cost_landed_without_labor,
        'total_cost_with_labor',          v_total_cost_with_labor
      ),
      true
    ),
    updated_at = now()
  WHERE id = p_configured_product_id;

  RETURN jsonb_build_object(
    'configured_product_id',   p_configured_product_id,
    'roll_msrp_total',         v_roll_msrp_total,
    'bom_total',               v_bom_total,
    'total_msrp',              v_unit_msrp_total,
    'unit_msrp_total',         v_unit_msrp_total,
    'unit_dealer_price',       v_unit_dealer_price,
    'total_cost_with_labor',   v_total_cost_with_labor
  );
END;
$$;

COMMENT ON FUNCTION public.calculate_configured_product_totals(uuid) IS
'Totales desde get_roll_pricing (CatalogItemsMSRP) para roll; BOM/accessories desde bom_preview_snapshot.totals. Parche: si roll_qty no está en JSON y factor=0, usa factor 1 para no devolver total_msrp=0. Sin legacy.';


-- ============================================================================
-- 4) sync_quote_line_pricing_from_configured_product
-- msrp y unit_msrp_total_snapshot desde cp.total_msrp; multiplicar por quantity. msrp = sale-out (no usar "sale_out").
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sync_quote_line_pricing_from_configured_product(p_quote_line_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ql     RECORD;
  v_cp     RECORD;
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

  PERFORM public.calculate_configured_product_totals(v_ql.configured_product_id);

  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = v_ql.configured_product_id
    AND organization_id = v_ql.organization_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found for QuoteLine %', v_ql.configured_product_id, p_quote_line_id;
  END IF;

  v_totals := COALESCE(v_cp.bom_preview_snapshot->'totals', '{}'::jsonb);
  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);

  -- msrp = sale-out. Copiar desde cp.total_msrp (unit) y multiplicar por quantity
  v_unit_msrp := COALESCE(v_cp.total_msrp, (v_totals->>'unit_msrp_total')::numeric, (v_totals->>'total_msrp')::numeric, 0);
  v_unit_cost := COALESCE(v_cp.unit_product_cost_landed, 0) + COALESCE(v_cp.unit_labor_cost, 0);
  IF v_unit_cost = 0 THEN
    v_unit_cost := COALESCE((v_totals->>'total_cost_with_labor')::numeric, (v_totals->>'unit_product_cost_landed')::numeric + COALESCE((v_totals->>'unit_labor_cost')::numeric, 0), 0);
  END IF;

  v_unit_dealer := COALESCE((v_totals->>'unit_dealer_price')::numeric, 0);

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
    roll_msrp_snapshot         = COALESCE(v_cp.roll_msrp_total, (v_totals->>'roll_msrp_total')::numeric, 0),
    bom_msrp_snapshot          = COALESCE(v_cp.bom_total, (v_totals->>'bom_total')::numeric, 0),
    roll_cost_snapshot         = COALESCE(v_cp.roll_total_cost_landed, (v_totals->>'roll_total_cost_landed')::numeric, 0),
    bom_cost_snapshot          = COALESCE(v_cp.bom_total_cost_landed, (v_totals->>'bom_total_cost_landed')::numeric, 0),
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
'Actualiza QuoteLines desde ConfiguredProduct. unit_msrp_total_snapshot y msrp desde cp.total_msrp (msrp = sale-out), msrp = total_msrp * quantity. Sin referencias a sale_out.';


-- ============================================================================
-- Verificación caso de prueba: configured_product_id e65a... / catalog_item_id 2b22...
-- Asegurar que total_msrp > 0 cuando existe msrp en CatalogItemsMSRP para el roll.
-- ============================================================================
-- SELECT public.calculate_configured_product_totals('e65a...'::uuid);
-- SELECT id, roll_catalog_item_id, roll_msrp_total, total_msrp
-- FROM public."ConfiguredProducts" WHERE id = 'e65a...'::uuid;
-- SELECT cim.msrp, cim.dealer_price FROM public."CatalogItemsMSRP" cim
-- WHERE cim.catalog_item_id = '2b22...'::uuid LIMIT 1;
