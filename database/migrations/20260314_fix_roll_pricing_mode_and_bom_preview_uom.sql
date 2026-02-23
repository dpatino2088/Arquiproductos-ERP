-- ============================================================================
-- Fix: roll_pricing_mode vs fabric_pricing_mode + BOM preview UOM correcto
-- Fecha: 2026-03-14
--
-- BUG #1 (populate_bom_line_base_pricing_fields):
--   Usaba ci.fabric_pricing_mode; los CatalogItems tienen roll_pricing_mode.
--   Si fabric_pricing_mode=NULL, caía al ELSE y quedaba qty/uom en m² aunque
--   el item fuera per_linear_meter.
--
-- BUG #2 (build_bom_preview_snapshot):
--   Calculaba bien v_roll_factor para per_linear_meter (height_m) pero
--   hardcodeaba 'uom'='m²' en el JSON. Debe ser 'm' cuando es lineal.
--
-- BUG #3 (build_bom_preview_snapshot):
--   COALESCE(ci.roll_width_m, ci.roll_width) puede traer legacy no normalizado.
--   Usar solo roll_width_m para roll_width_catalog.
--
-- ============================================================================

-- ----------------------------------------------------------------------------
-- A) populate_bom_line_base_pricing_fields: usar roll_pricing_mode como fuente
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.populate_bom_line_base_pricing_fields(
    p_bom_instance_line_id uuid,
    p_catalog_item_id uuid,
    p_component_qty numeric,
    p_component_uom text,
    p_component_role text,
    p_organization_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_catalog_item RECORD;
    v_effective_mode text;  -- modo mapeado para calculate_fabric_pricing_qty
    v_qty_base numeric;
    v_uom_base text;
    v_qty_pricing numeric;
    v_uom_pricing text;
    v_unit_cost_base numeric;
    v_unit_cost_pricing numeric;
    v_total_cost_base numeric;
    v_total_cost_pricing numeric;
    v_calc_notes text;
    v_pricing_result RECORD;
    v_rule_result RECORD;
    v_quote_line RECORD;
    v_msrp_rec RECORD;
    v_roll_width_m numeric;
    v_msrp_per_m numeric;
BEGIN
    -- Fuente de verdad: roll_pricing_mode; fallback fabric_pricing_mode (legacy)
    SELECT
        ci.is_fabric,
        ci.roll_width_m,
        COALESCE(ci.roll_pricing_mode::text, ci.fabric_pricing_mode::text) AS fabric_pricing_mode,
        ci.measure_basis,
        COALESCE(ci.unit_of_measure, ci.uom) AS uom
    INTO v_catalog_item
    FROM "CatalogItems" ci
    WHERE ci.id = p_catalog_item_id
      AND ci.organization_id = p_organization_id
      AND ci.deleted = false;

    IF NOT FOUND THEN
        RAISE WARNING 'CatalogItem % not found for BOM line %', p_catalog_item_id, p_bom_instance_line_id;
        RETURN;
    END IF;

    -- Base UOM and quantity (unchanged)
    IF v_catalog_item.is_fabric THEN
        v_uom_base := 'm2';
        IF UPPER(TRIM(COALESCE(p_component_uom, ''))) IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
            v_qty_base := p_component_qty;
        ELSIF UPPER(TRIM(COALESCE(p_component_uom, ''))) IN ('M', 'MTS', 'METER', 'METERS') THEN
            IF v_catalog_item.roll_width_m IS NOT NULL AND v_catalog_item.roll_width_m > 0 THEN
                v_qty_base := p_component_qty * v_catalog_item.roll_width_m;
            ELSE
                v_qty_base := p_component_qty;
                v_calc_notes := 'WARNING: No roll_width_m for fabric, cannot convert linear m to m2';
            END IF;
        ELSE
            v_qty_base := p_component_qty;
            v_calc_notes := 'WARNING: Unknown fabric UOM, using component qty as base';
        END IF;
    ELSE
        v_uom_base := public.normalize_uom_to_canonical(p_component_uom);
        v_qty_base := p_component_qty;
    END IF;

    -- Pricing path: FABRIC + rule available -> compute_fabric_pricing_from_rule; else legacy
    IF v_catalog_item.is_fabric THEN
        v_roll_width_m := v_catalog_item.roll_width_m;
        -- Resolve quote line context from BOM instance (for product_type_id, width_m, height_m)
        SELECT ql.product_type_id, ql.width_m, ql.height_m
        INTO v_quote_line
        FROM "BomInstanceLines" bil
        JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
        LEFT JOIN "QuoteLines" ql ON ql.id = bi.quote_line_id AND ql.deleted = false
        WHERE bil.id = p_bom_instance_line_id;

        -- MSRP: get per-m equivalent from CatalogItemsMSRP (source of truth)
        SELECT cim.msrp, cim.pricing_uom
        INTO v_msrp_rec
        FROM "CatalogItemsMSRP" cim
        WHERE cim.catalog_item_id = p_catalog_item_id
          AND cim.organization_id = p_organization_id
        LIMIT 1;

        IF FOUND AND v_msrp_rec.msrp IS NOT NULL AND v_roll_width_m IS NOT NULL AND v_roll_width_m > 0 THEN
            IF UPPER(TRIM(COALESCE(v_msrp_rec.pricing_uom, ''))) = 'M' THEN
                v_msrp_per_m := v_msrp_rec.msrp;
            ELSE
                v_msrp_per_m := v_msrp_rec.msrp / v_roll_width_m;
            END IF;
        ELSE
            v_msrp_per_m := NULL;
        END IF;

        -- Try rule: need org, product_type_id, height_m, width_m, roll_width_m, msrp_per_m
        IF v_quote_line.product_type_id IS NOT NULL AND v_roll_width_m IS NOT NULL AND v_roll_width_m > 0 AND v_msrp_per_m IS NOT NULL THEN
            SELECT * INTO v_rule_result
            FROM public.compute_fabric_pricing_from_rule(
                p_organization_id,
                v_quote_line.product_type_id,
                NULL,
                v_quote_line.height_m,
                v_quote_line.width_m,
                v_roll_width_m,
                v_msrp_per_m
            ) LIMIT 1;

            IF FOUND AND v_rule_result.qty IS NOT NULL THEN
                v_qty_pricing := v_rule_result.qty;
                v_uom_pricing := COALESCE(v_rule_result.pricing_uom, 'm2');
                v_unit_cost_pricing := v_rule_result.unit_price;
                v_total_cost_pricing := v_qty_pricing * COALESCE(v_rule_result.unit_price, 0);
                v_calc_notes := COALESCE(v_calc_notes, '') ||
                    format(' FabricRule: area_base=%s m2, qty=%s %s, waste_pct=%s',
                        COALESCE(v_rule_result.area_base_m2::text, '?'),
                        v_qty_pricing::text, v_uom_pricing,
                        COALESCE(v_rule_result.waste_pct::text, '0'));
                -- Skip legacy path below
                v_unit_cost_base := public.get_unit_cost_in_uom(p_catalog_item_id, v_uom_base, p_organization_id);
                IF (v_unit_cost_base IS NULL OR v_unit_cost_base = 0) THEN
                    SELECT unit_cost_exw INTO v_unit_cost_base FROM "BomInstanceLines" WHERE id = p_bom_instance_line_id;
                END IF;
                v_total_cost_base := v_qty_base * COALESCE(v_unit_cost_base, 0);
                UPDATE "BomInstanceLines"
                SET qty_base = v_qty_base, uom_base = v_uom_base,
                    qty_pricing = v_qty_pricing, uom_pricing = v_uom_pricing,
                    unit_cost_base = v_unit_cost_base, unit_cost_pricing = v_unit_cost_pricing,
                    total_cost_base = v_total_cost_base, total_cost_pricing = v_total_cost_pricing,
                    calc_notes = COALESCE(calc_notes, '') || CASE WHEN calc_notes IS NOT NULL AND calc_notes <> '' THEN '; ' ELSE '' END || v_calc_notes
                WHERE id = p_bom_instance_line_id;
                RETURN;
            END IF;
        END IF;

        -- Fallback: legacy calculate_fabric_pricing_qty (usa per_sqm, per_linear_m, etc.)
        -- Mapeo: roll_pricing_mode (per_square_meter, per_linear_meter, per_unit) -> calculate_fabric_pricing_qty
        v_effective_mode := CASE
            WHEN v_catalog_item.fabric_pricing_mode IN ('per_square_meter', 'per_sqm') THEN 'per_sqm'
            WHEN v_catalog_item.fabric_pricing_mode IN ('per_linear_meter', 'per_linear_m') THEN 'per_linear_m'
            WHEN v_catalog_item.fabric_pricing_mode IN ('per_linear_yd', 'per_roll') THEN v_catalog_item.fabric_pricing_mode
            ELSE v_catalog_item.fabric_pricing_mode
        END;

        IF v_catalog_item.fabric_pricing_mode = 'per_unit' THEN
            v_qty_pricing := 1;
            v_uom_pricing := 'ea';
        ELSIF v_effective_mode IS NOT NULL AND v_effective_mode IN ('per_sqm', 'per_linear_m', 'per_linear_yd', 'per_roll') THEN
            SELECT * INTO v_pricing_result
            FROM public.calculate_fabric_pricing_qty(
                v_qty_base,
                v_effective_mode,
                v_catalog_item.roll_width_m
            );
            v_qty_pricing := v_pricing_result.qty_pricing;
            v_uom_pricing := v_pricing_result.uom_pricing;
        ELSE
            v_qty_pricing := v_qty_base;
            v_uom_pricing := v_uom_base;
        END IF;
    ELSE
        v_qty_pricing := v_qty_base;
        v_uom_pricing := v_uom_base;
    END IF;

    -- Costs (unchanged)
    v_unit_cost_base := public.get_unit_cost_in_uom(p_catalog_item_id, v_uom_base, p_organization_id);
    v_unit_cost_pricing := public.get_unit_cost_in_pricing_uom(p_catalog_item_id, v_uom_pricing, p_organization_id);
    IF (v_unit_cost_base IS NULL OR v_unit_cost_base = 0) THEN
        SELECT unit_cost_exw INTO v_unit_cost_base FROM "BomInstanceLines" WHERE id = p_bom_instance_line_id;
    END IF;
    IF (v_unit_cost_pricing IS NULL OR v_unit_cost_pricing = 0) THEN
        v_unit_cost_pricing := v_unit_cost_base;
    END IF;
    v_total_cost_base := v_qty_base * COALESCE(v_unit_cost_base, 0);
    v_total_cost_pricing := v_qty_pricing * COALESCE(v_unit_cost_pricing, 0);

    IF v_calc_notes IS NULL THEN v_calc_notes := ''; END IF;
    IF v_catalog_item.is_fabric THEN
        v_calc_notes := v_calc_notes || format(' Fabric: base=%s %s, pricing=%s %s (mode=%s, roll_width=%s m)',
            v_qty_base::text, v_uom_base, v_qty_pricing::text, v_uom_pricing,
            COALESCE(v_catalog_item.fabric_pricing_mode::text, 'none'),
            ROUND(COALESCE(v_catalog_item.roll_width_m, 0), 4)::text);
    ELSE
        v_calc_notes := v_calc_notes || format(' Base=%s %s, pricing=%s %s', v_qty_base::text, v_uom_base, v_qty_pricing::text, v_uom_pricing);
    END IF;

    UPDATE "BomInstanceLines"
    SET qty_base = v_qty_base, uom_base = v_uom_base,
        qty_pricing = v_qty_pricing, uom_pricing = v_uom_pricing,
        unit_cost_base = v_unit_cost_base, unit_cost_pricing = v_unit_cost_pricing,
        total_cost_base = v_total_cost_base, total_cost_pricing = v_total_cost_pricing,
        calc_notes = COALESCE(calc_notes, '') || CASE WHEN calc_notes IS NOT NULL AND calc_notes <> '' THEN '; ' ELSE '' END || v_calc_notes
    WHERE id = p_bom_instance_line_id;
END;
$$;

COMMENT ON FUNCTION public.populate_bom_line_base_pricing_fields(uuid, uuid, numeric, text, text, uuid) IS
'Populates base and pricing qty/UOM in BomInstanceLines. Uses roll_pricing_mode (fallback fabric_pricing_mode). For fabric: FabricRules first, else calculate_fabric_pricing_qty. Maps per_square_meter->per_sqm, per_linear_meter->per_linear_m.';


-- ----------------------------------------------------------------------------
-- B) build_bom_preview_snapshot: v_roll_uom dinámico + solo roll_width_m
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.build_bom_preview_snapshot(
  p_org_id uuid,
  p_configured_product_id uuid,
  p_bom_template_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_cp RECORD;
  v_config jsonb;
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
  v_roll_factor numeric := 0;
  v_roll_qty numeric := 0;
  v_roll_width_effective numeric;
  v_width_total_m numeric;
  v_roll_pricing_mode text;
  v_roll_measure_basis text;
  v_roll_uom text := 'm²';  -- UOM correcto según roll_pricing_mode/measure_basis
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  v_config := COALESCE(v_cp.config_snapshot, '{}'::jsonb);

  -- Dimensiones: width desde measurements.width_total_mm o cp.width_mm
  v_width_mm := COALESCE(
    (v_config->'measurements'->>'width_total_mm')::numeric,
    v_cp.width_mm,
    0
  );
  v_height_mm := COALESCE(v_cp.height_mm, 0);
  v_width_m := v_width_mm / 1000.0;
  v_height_m := v_height_mm / 1000.0;
  v_area_m2 := v_width_m * v_height_m;
  v_width_total_m := v_width_m;

  -- ROLL: qty + UOM según roll_pricing_mode/measure_basis
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT r.msrp, r.dealer_price, r.labor_msrp
    INTO v_roll_msrp_unit, v_roll_dealer_unit, v_roll_labor_unit
    FROM public.get_roll_pricing(p_org_id, v_cp.roll_catalog_item_id) r;

    -- Solo roll_width_m (evitar ci.roll_width legacy no normalizado)
    SELECT ci.sku, ci.name, ci.unit_of_measure,
           ci.roll_pricing_mode, ci.measure_basis,
           ci.roll_width_m AS roll_width_catalog
    INTO v_item_info
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id
      AND ci.organization_id = p_org_id
    LIMIT 1;

    v_roll_width_effective := COALESCE(v_cp.roll_width, (v_item_info.roll_width_catalog)::numeric, 0);

    -- Factor y UOM según modo
    IF COALESCE(v_item_info.roll_pricing_mode, '') = 'per_unit' THEN
      v_roll_factor := 1;
      v_roll_uom := 'ea';
    ELSIF COALESCE(v_item_info.roll_pricing_mode, '') = 'per_linear_meter'
       OR COALESCE(v_item_info.measure_basis, '') = 'linear' THEN
      v_roll_factor := v_height_m;
      v_roll_uom := 'm';
    ELSE
      -- per_m2, per_square_meter, default: área del producto = width × height (1.2×1.2 = 1.44 m²)
      v_roll_factor := v_width_total_m * v_height_m;
      v_roll_uom := 'm²';
    END IF;

    v_roll_qty := GREATEST(v_roll_factor, 0) * COALESCE(v_cp.quantity, 1);
    v_qty := v_roll_qty;
    v_unit_price := COALESCE(v_roll_msrp_unit, 0);
    v_line_total := ROUND(v_qty * v_unit_price, 2);

    SELECT cim.total_cost INTO v_roll_total_cost
    FROM public."CatalogItemsMSRP" cim
    WHERE cim.catalog_item_id = v_cp.roll_catalog_item_id
      AND cim.organization_id = p_org_id
    ORDER BY cim.updated_at DESC NULLS LAST
    LIMIT 1;

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
      'uom', v_roll_uom,
      'unit_price', v_unit_price,
      'line_total', v_line_total,
      'children', '[]'::jsonb,
      'meta', jsonb_build_object(
        'collection_name', v_cp.roll_collection_name,
        'variant_name', v_cp.roll_variant_name,
        'roll_width', v_cp.roll_width,
        'roll_width_m', v_roll_width_effective,
        'roll_factor', v_roll_factor
      )
    );
    v_items := v_items || v_roll_item;
  ELSE
    v_roll_total_cost := 0;
  END IF;

  -- BOM: desde BOMComponents
  IF p_bom_template_id IS NOT NULL THEN
    FOR v_comp IN
      SELECT bc.id, bc.component_role, bc.component_item_id, bc.qty_type, bc.qty_value,
             bc.qty_delta_mm, bc.uom, bc.parent_component_id, bc.sort_order
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
        v_role_lower text := lower(COALESCE(v_comp.component_role, ''));
        v_selected_id uuid;
        v_config jsonb := COALESCE(v_cp.config_snapshot, '{}'::jsonb);
      BEGIN
        CASE v_role_lower
          WHEN 'bottom_bar'     THEN v_selected_id := public.try_parse_uuid(v_config->>'bottom_bar_item_id');
          WHEN 'headbox'        THEN v_selected_id := public.try_parse_uuid(v_config->>'headbox_item_id');
          WHEN 'side_channel'   THEN v_selected_id := public.try_parse_uuid(v_config->>'side_channel_item_id');
          WHEN 'bottom_channel' THEN v_selected_id := public.try_parse_uuid(v_config->>'bottom_channel_item_id');
          WHEN 'motor'          THEN v_selected_id := public.try_parse_uuid(v_config->>'motor_item_id');
          WHEN 'drive'          THEN v_selected_id := public.try_parse_uuid(v_config->>'drive_item_id');
          WHEN 'tube'           THEN v_selected_id := public.try_parse_uuid(v_config->>'tube_item_id');
          ELSE v_selected_id := NULL;
        END CASE;
        IF v_selected_id IS NOT NULL THEN
          v_comp.component_item_id := v_selected_id;
          v_selected := true;
        END IF;
      END;

      IF v_comp.component_item_id IS NULL THEN CONTINUE; END IF;

      SELECT ci.sku, ci.name, ci.unit_of_measure INTO v_item_info
      FROM public."CatalogItems" ci
      WHERE ci.id = v_comp.component_item_id AND ci.organization_id = p_org_id
      LIMIT 1;

      SELECT cim.msrp, cim.total_cost INTO v_msrp_info
      FROM public."CatalogItemsMSRP" cim
      WHERE cim.catalog_item_id = v_comp.component_item_id AND cim.organization_id = p_org_id
      ORDER BY cim.updated_at DESC NULLS LAST
      LIMIT 1;

      v_qty := COALESCE(v_comp.qty_value, 1);
      CASE COALESCE(v_comp.qty_type, 'fixed')
        WHEN 'per_width', 'width' THEN v_qty := GREATEST(0, (v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
        WHEN 'per_height', 'height' THEN v_qty := GREATEST(0, (v_height_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
        WHEN 'per_m2', 'area' THEN v_qty := GREATEST(0, v_area_m2);
        ELSE v_qty := COALESCE(v_comp.qty_value, 1);
      END CASE;

      v_unit_price := COALESCE(v_msrp_info.msrp, 0);
      v_line_total := ROUND(v_qty * v_unit_price, 2);

      v_children := '[]'::jsonb;
      FOR v_child IN
        SELECT bc.id, bc.component_role, bc.component_item_id, bc.qty_type, bc.qty_value, bc.qty_delta_mm, bc.uom
        FROM public."BOMComponents" bc
        WHERE bc.parent_component_id = v_comp.id
          AND bc.organization_id = p_org_id
          AND bc.deleted = false
          AND bc.archived = false
        ORDER BY bc.sort_order ASC
      LOOP
        IF v_child.component_item_id IS NULL THEN CONTINUE; END IF;

        SELECT ci.sku, ci.name, ci.unit_of_measure INTO v_item_info
        FROM public."CatalogItems" ci
        WHERE ci.id = v_child.component_item_id AND ci.organization_id = p_org_id
        LIMIT 1;

        SELECT cim.msrp, cim.total_cost INTO v_msrp_info
        FROM public."CatalogItemsMSRP" cim
        WHERE cim.catalog_item_id = v_child.component_item_id AND cim.organization_id = p_org_id
        ORDER BY cim.updated_at DESC NULLS LAST
        LIMIT 1;

        DECLARE
          v_child_qty numeric;
        BEGIN
          v_child_qty := COALESCE(v_child.qty_value, 1);
          CASE COALESCE(v_child.qty_type, 'fixed')
            WHEN 'per_width', 'width' THEN v_child_qty := GREATEST(0, (v_width_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
            WHEN 'per_height', 'height' THEN v_child_qty := GREATEST(0, (v_height_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
            WHEN 'per_m2', 'area' THEN v_child_qty := GREATEST(0, v_area_m2);
            ELSE v_child_qty := COALESCE(v_child.qty_value, 1);
          END CASE;
          v_child_unit_price := COALESCE(v_msrp_info.msrp, 0);
          v_child_line_total := ROUND(v_child_qty * v_child_unit_price, 2);
          v_children := v_children || jsonb_build_object(
            'id', v_child.id::text, 'kind', 'child', 'role', COALESCE(v_child.component_role, 'child'),
            'level', 1, 'selected', false, 'catalog_item_id', v_child.component_item_id,
            'sku', v_item_info.sku, 'name', v_item_info.name,
            'qty', ROUND(v_child_qty, 3),
            'uom', COALESCE(v_child.uom, v_item_info.unit_of_measure, 'ea'),
            'unit_price', v_child_unit_price, 'line_total', v_child_line_total,
            'children', '[]'::jsonb, 'meta', '{}'::jsonb
          );
        END;
      END LOOP;

      v_items := v_items || jsonb_build_object(
        'id', v_comp.id::text, 'kind', 'parent', 'role', COALESCE(v_comp.component_role, 'component'),
        'level', 0, 'selected', v_selected, 'catalog_item_id', v_comp.component_item_id,
        'sku', v_item_info.sku, 'name', v_item_info.name,
        'qty', ROUND(v_qty, 3),
        'uom', COALESCE(v_comp.uom, v_item_info.unit_of_measure, 'ea'),
        'unit_price', v_unit_price, 'line_total', v_line_total,
        'children', v_children, 'meta', '{}'::jsonb
      );
    END LOOP;
  END IF;

  SELECT * INTO v_cp FROM public."ConfiguredProducts" WHERE id = p_configured_product_id AND organization_id = p_org_id;

  SELECT COALESCE(SUM((item->>'line_total')::numeric), 0) INTO v_roll_msrp_total
  FROM jsonb_array_elements(v_items) AS item WHERE item->>'kind' = 'roll';
  IF v_roll_msrp_total = 0 THEN v_roll_msrp_total := COALESCE(v_cp.roll_msrp_total, 0); END IF;

  SELECT COALESCE(SUM(
    (item->>'line_total')::numeric +
    COALESCE((SELECT SUM((c->>'line_total')::numeric) FROM jsonb_array_elements(COALESCE(item->'children', '[]'::jsonb)) c), 0)
  ), 0) INTO v_bom_sum
  FROM jsonb_array_elements(v_items) AS item WHERE item->>'kind' = 'parent';
  IF v_bom_sum = 0 THEN v_bom_sum := COALESCE(v_cp.bom_total, 0); END IF;

  v_labor_amount := COALESCE(v_cp.labor_amount, 0);
  v_accessories_total := COALESCE(v_cp.accessories_total, 0);
  IF v_labor_amount = 0 AND COALESCE(v_cp.labor_pct, 0) > 0 THEN
    v_labor_amount := (v_roll_msrp_total + v_bom_sum) * (v_cp.labor_pct / 100.0);
  END IF;
  v_total_msrp := v_roll_msrp_total + v_bom_sum + v_labor_amount + v_accessories_total;

  v_totals := jsonb_build_object(
    'roll_qty', v_roll_qty,
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_sum,
    'accessories_total', v_accessories_total,
    'labor_pct', COALESCE(v_cp.labor_pct, 0),
    'labor_amount', v_labor_amount,
    'total_msrp', v_total_msrp,
    'roll_total_cost', COALESCE(v_roll_total_cost, v_cp.roll_total_cost, 0),
    'bom_total_cost', COALESCE(v_cp.bom_total_cost, 0)
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
'BOM preview JSONB. Roll qty y uom por roll_pricing_mode/measure_basis (per_unit=ea, per_linear_meter=m, else m²). roll_width solo desde roll_width_m. totals sin _landed.';


DO $$
BEGIN
  RAISE NOTICE '✅ Migration 20260314: populate_bom_line_base_pricing_fields usa roll_pricing_mode; build_bom_preview_snapshot uom dinámico (m/m²/ea) y roll_width_m solo.';
END $$;
