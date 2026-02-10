-- ============================================================================
-- BOM preview: reglas por paño vs por ancho total (visible en BOM breakdown y detalles)
--
-- Por paño (width_total = suma de anchos de cada paño):
--   - Roll/Fabric: área = width_total × height
--   - Tubo: per_width per each panel → longitud = width_total (como siempre)
--   - Bottom bar: per_width → longitud = width_total
--
-- Por ancho total (mismo width_total; headbox/bottom channel por longitud total):
--   - Headbox: longitud = width_total
--   - Bottom channel: longitud = width_total
--
-- create_configured_product: persiste width_total_mm desde config_snapshot.measurements
-- build_bom_preview_snapshot: aplica las reglas arriba (items y totals)
-- ============================================================================

-- 1) build_bom_preview_snapshot: width from measurements.width_total_mm, panel_count for qty
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
  v_roll_msrp_total numeric := 0;
  v_bom_sum numeric := 0;
  v_labor_amount numeric := 0;
  v_accessories_total numeric := 0;
  v_total_msrp numeric := 0;
  v_child_unit_price numeric;
  v_child_line_total numeric;
  v_selected_id uuid;
  v_labor_pct numeric(12,4);
  v_panel_count int := 1;  -- 1, 2 or 3 paños (para dimensiones; tubo/bottom bar = per_width)
  v_role_lower text;
  v_by_total_width boolean;  -- headbox/bottom_channel: qty por ancho total (suma paños)
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  SELECT COALESCE(cs.labor_pct, 0) INTO v_labor_pct
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_org_id
  LIMIT 1;
  IF v_labor_pct IS NULL THEN
    v_labor_pct := COALESCE(v_cp.labor_pct, 0);
  END IF;

  v_config := COALESCE(v_cp.config_snapshot, '{}'::jsonb);

  -- Paños: use total width and panel count from measurements (default 1)
  v_panel_count := LEAST(3, GREATEST(1, COALESCE((v_config->'measurements'->>'panel_count')::int, 1)));
  v_width_mm := COALESCE(
    (v_config->'measurements'->>'width_total_mm')::numeric,
    v_cp.width_mm,
    0
  );
  v_height_mm := COALESCE(v_cp.height_mm, 0);
  v_width_m := v_width_mm / 1000.0;
  v_height_m := v_height_mm / 1000.0;
  v_area_m2 := v_width_m * v_height_m;

  IF jsonb_typeof(v_config->'accessories') = 'array' THEN
    SELECT COALESCE(SUM(
      (elem->>'price')::numeric * GREATEST(COALESCE((elem->>'qty')::numeric, 0), 0)
    ), 0) INTO v_accessories_total
    FROM jsonb_array_elements(v_config->'accessories') AS elem;
  END IF;
  v_accessories_total := ROUND(COALESCE(v_accessories_total, 0), 2);

  -- 1) ROLL/FABRIC
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT ci.sku, ci.name, ci.unit_of_measure
      INTO v_item_info
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id
      AND ci.organization_id = p_org_id
    LIMIT 1;

    SELECT msrp, total_cost INTO v_msrp_info
    FROM public."CatalogItemsMSRP"
    WHERE catalog_item_id = v_cp.roll_catalog_item_id
      AND organization_id = p_org_id
    LIMIT 1;

    v_qty := v_area_m2 * COALESCE(v_cp.quantity, 1);
    v_unit_price := COALESCE(v_msrp_info.msrp, 0);
    v_line_total := ROUND(v_qty * v_unit_price, 2);
    v_roll_msrp_total := v_line_total;

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
  END IF;

  -- 2) BOM Components
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
      v_selected_id := NULL;
      v_role_lower := lower(COALESCE(v_comp.component_role, ''));

      CASE v_role_lower
        WHEN 'bottom_bar' THEN v_selected_id := (v_config->>'bottom_bar_item_id')::uuid;
        WHEN 'headbox' THEN v_selected_id := (v_config->>'headbox_item_id')::uuid;
        WHEN 'side_channel' THEN v_selected_id := (v_config->>'side_channel_item_id')::uuid;
        WHEN 'bottom_channel' THEN v_selected_id := (v_config->>'bottom_channel_item_id')::uuid;
        WHEN 'motor' THEN v_selected_id := (v_config->>'motor_item_id')::uuid;
        WHEN 'drive' THEN v_selected_id := (v_config->>'drive_item_id')::uuid;
        WHEN 'tube' THEN v_selected_id := (v_config->>'tube_item_id')::uuid;
        ELSE v_selected_id := NULL;
      END CASE;

      IF v_selected_id IS NOT NULL THEN
        v_comp.component_item_id := v_selected_id;
        v_selected := true;
      END IF;

      IF v_comp.component_item_id IS NULL THEN
        CONTINUE;
      END IF;

      SELECT ci.sku, ci.name, ci.unit_of_measure
        INTO v_item_info
      FROM public."CatalogItems" ci
      WHERE ci.id = v_comp.component_item_id
        AND ci.organization_id = p_org_id
      LIMIT 1;

      SELECT msrp, total_cost INTO v_msrp_info
      FROM public."CatalogItemsMSRP"
      WHERE catalog_item_id = v_comp.component_item_id
        AND organization_id = p_org_id
      LIMIT 1;

      -- Tubo = per_width per each panel (longitud = width_total). Headbox/bottom channel = por ancho total
      v_qty := COALESCE(v_comp.qty_value, 1);
      v_by_total_width := v_role_lower IN ('headbox', 'bottom_channel');

      -- Tube (tubo) siempre per_width: longitud = ancho total (suma anchos por paño)
      IF v_role_lower = 'tube' THEN
        v_qty := GREATEST(0, (v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
      ELSE
        CASE COALESCE(v_comp.qty_type, 'fixed')
          WHEN 'per_width', 'width' THEN
            v_qty := GREATEST(0, (v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
          WHEN 'per_height', 'height' THEN
            v_qty := GREATEST(0, (v_height_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
          WHEN 'per_m2', 'area' THEN
            v_qty := GREATEST(0, v_area_m2);
          ELSE
            IF v_by_total_width THEN
              v_qty := GREATEST(0, (v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
            ELSE
              v_qty := COALESCE(v_comp.qty_value, 1);
            END IF;
        END CASE;
      END IF;

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

        SELECT ci.sku, ci.name, ci.unit_of_measure INTO v_item_info
        FROM public."CatalogItems" ci
        WHERE ci.id = v_child.component_item_id AND ci.organization_id = p_org_id
        LIMIT 1;

        SELECT msrp INTO v_child_unit_price
        FROM public."CatalogItemsMSRP"
        WHERE catalog_item_id = v_child.component_item_id AND organization_id = p_org_id
        LIMIT 1;

        DECLARE v_child_qty numeric;
              v_child_role_lower text;
        BEGIN
          v_child_qty := COALESCE(v_child.qty_value, 1);
          v_child_role_lower := lower(COALESCE(v_child.component_role, ''));
          IF v_child_role_lower = 'tube' THEN
            v_child_qty := GREATEST(0, (v_width_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
          ELSE
            CASE COALESCE(v_child.qty_type, 'fixed')
              WHEN 'per_width', 'width' THEN
                v_child_qty := GREATEST(0, (v_width_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
              WHEN 'per_height', 'height' THEN
                v_child_qty := GREATEST(0, (v_height_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
              ELSE
                IF v_child_role_lower IN ('headbox', 'bottom_channel') THEN
                  v_child_qty := GREATEST(0, (v_width_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
                ELSE
                  v_child_qty := COALESCE(v_child.qty_value, 1);
                END IF;
            END CASE;
          END IF;
          v_child_line_total := ROUND(v_child_qty * COALESCE(v_child_unit_price, 0), 2);
          v_bom_sum := v_bom_sum + v_child_line_total;

          v_children := v_children || jsonb_build_object(
            'id', v_child.component_item_id::text,
            'kind', 'child',
            'role', v_child.component_role,
            'level', 1,
            'selected', false,
            'catalog_item_id', v_child.component_item_id,
            'sku', v_item_info.sku,
            'name', v_item_info.name,
            'qty', ROUND(v_child_qty, 3),
            'uom', COALESCE(v_child.uom, v_item_info.unit_of_measure, 'ea'),
            'unit_price', COALESCE(v_child_unit_price, 0),
            'line_total', v_child_line_total,
            'children', '[]'::jsonb,
            'meta', '{}'::jsonb
          );
        END;
      END LOOP;

      v_bom_sum := v_bom_sum + v_line_total;
      v_items := v_items || jsonb_build_object(
        'id', v_comp.component_item_id::text,
        'kind', 'parent',
        'role', v_comp.component_role,
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

  v_labor_amount := ROUND((v_roll_msrp_total + v_bom_sum) * v_labor_pct, 2);
  v_total_msrp := v_roll_msrp_total + v_bom_sum + v_labor_amount + v_accessories_total;

  v_totals := jsonb_build_object(
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_sum,
    'accessories_total', v_accessories_total,
    'labor_pct', v_labor_pct,
    'labor_amount', v_labor_amount,
    'total_msrp', v_total_msrp,
    'roll_total_cost', 0,
    'bom_total_cost', 0
  );

  UPDATE public."ConfiguredProducts"
  SET roll_msrp_total = v_roll_msrp_total,
      bom_total = v_bom_sum,
      labor_pct = v_labor_pct,
      labor_amount = v_labor_amount,
      roll_plus_bom_total = v_roll_msrp_total + v_bom_sum,
      accessories_total = v_accessories_total,
      total_msrp = v_total_msrp,
      updated_at = now()
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id;

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

-- 2) create_configured_product_and_bom_preview: persist width_total_mm when multi-panel
CREATE OR REPLACE FUNCTION public.create_configured_product_and_bom_preview(
  p_org_id uuid,
  p_product_type_id uuid,
  p_config_snapshot jsonb,
  p_quote_id uuid DEFAULT NULL,
  p_quote_line_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_configured_product_id uuid;
  v_bom_template_id uuid;
  v_bom_instance_id uuid;
  v_totals jsonb;
  v_preview_snapshot jsonb;
  v_hardware_color text;
  v_fabric_item_id uuid;
  v_width_mm numeric(12,4);
  v_height_mm numeric(12,4);
  v_quantity numeric(12,4);
  v_roll_sku text;
  v_roll_collection_name text;
  v_roll_variant_name text;
  v_roll_width numeric(12,4);
  v_labor_pct numeric(12,4);
BEGIN
  SELECT COALESCE(cs.labor_pct, 0) INTO v_labor_pct
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_org_id
  LIMIT 1;
  IF v_labor_pct IS NULL THEN
    v_labor_pct := 0;
  END IF;

  v_bom_template_id := (p_config_snapshot->>'bom_template_id')::uuid;

  IF v_bom_template_id IS NULL THEN
    BEGIN
      SELECT public.select_best_bom_template_v2_strict(
        p_org_id,
        p_product_type_id,
        p_config_snapshot
      ) INTO v_bom_template_id;
    EXCEPTION WHEN OTHERS THEN
      v_bom_template_id := NULL;
    END;
  END IF;

  IF v_bom_template_id IS NULL THEN
    RAISE EXCEPTION 'No matching BOMTemplate found for product_type_id=% with config=%',
      p_product_type_id, p_config_snapshot::text;
  END IF;

  v_hardware_color := COALESCE(
    p_config_snapshot->>'hardware_color',
    p_config_snapshot->>'hardwareColor'
  );
  v_fabric_item_id := (p_config_snapshot->>'variantId')::uuid;
  IF v_fabric_item_id IS NULL THEN
    v_fabric_item_id := (p_config_snapshot->>'roll_catalog_item_id')::uuid;
  END IF;

  -- Use total width when multi-panel (config_snapshot.measurements.width_total_mm)
  v_width_mm := COALESCE(
    (p_config_snapshot->'measurements'->>'width_total_mm')::numeric(12,4),
    (p_config_snapshot->>'width_mm')::numeric(12,4)
  );
  v_height_mm := (p_config_snapshot->>'height_mm')::numeric(12,4);
  v_quantity := COALESCE((p_config_snapshot->>'quantity')::numeric(12,4), 1);

  IF v_fabric_item_id IS NOT NULL THEN
    SELECT ci.sku, ci.collection_name, ci.variant_name, ci.roll_width
      INTO v_roll_sku, v_roll_collection_name, v_roll_variant_name, v_roll_width
    FROM public."CatalogItems" ci
    WHERE ci.id = v_fabric_item_id
      AND ci.organization_id = p_org_id
    LIMIT 1;
  END IF;

  INSERT INTO public."ConfiguredProducts" (
    organization_id,
    quote_id,
    bom_template_id,
    product_type_id,
    width_mm,
    height_mm,
    quantity,
    hardware_color,
    roll_catalog_item_id,
    roll_sku,
    roll_collection_name,
    roll_variant_name,
    roll_width,
    config_snapshot,
    roll_msrp_total,
    bom_total,
    roll_plus_bom_total,
    labor_pct,
    accessories_total,
    total_msrp
  )
  VALUES (
    p_org_id,
    p_quote_id,
    v_bom_template_id,
    p_product_type_id,
    v_width_mm,
    v_height_mm,
    v_quantity,
    v_hardware_color,
    v_fabric_item_id,
    v_roll_sku,
    v_roll_collection_name,
    v_roll_variant_name,
    v_roll_width,
    p_config_snapshot,
    0, 0, 0,
    v_labor_pct,
    0, 0
  )
  RETURNING id INTO v_configured_product_id;

  v_preview_snapshot := public.build_bom_preview_snapshot(
    p_org_id,
    v_configured_product_id,
    v_bom_template_id
  );

  UPDATE public."ConfiguredProducts"
  SET bom_preview_snapshot = v_preview_snapshot,
      updated_at = now()
  WHERE id = v_configured_product_id
    AND organization_id = p_org_id;

  v_totals := v_preview_snapshot->'totals';
  v_bom_instance_id := NULL;

  RETURN jsonb_build_object(
    'configured_product_id', v_configured_product_id,
    'bom_instance_id', v_bom_instance_id,
    'bom_template_id', v_bom_template_id,
    'totals', v_totals,
    'bom_preview_snapshot', v_preview_snapshot
  );
END;
$$;

COMMENT ON FUNCTION public.build_bom_preview_snapshot(uuid, uuid, uuid) IS
'BOM breakdown: Roll=area width_total×height. Tubo=per_width per each panel (qty=width_total). Bottom bar/Headbox/Bottom channel=ancho total (qty=width_total).';

COMMENT ON FUNCTION public.create_configured_product_and_bom_preview(uuid, uuid, jsonb, uuid, uuid) IS
'Creates ConfiguredProduct; width_mm from measurements.width_total_mm when present (multi-panel).';
