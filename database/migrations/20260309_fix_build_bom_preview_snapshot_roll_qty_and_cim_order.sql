-- ============================================================================
-- Fix: build_bom_preview_snapshot — roll_msrp_total y total_msrp en 0
-- Fecha: 2026-03-09
--
-- Problema:
-- - Roll qty usaba area_m2 = width_mm * height_mm; si width_mm=0 o no existe
--   width_total_mm en config_snapshot.measurements, qty=0.
-- - CatalogItemsMSRP sin ORDER BY updated_at puede leer fila con msrp=0 cuando hay duplicados.
--
-- Solución:
-- - Calcular roll qty con roll_pricing_mode/measure_basis como calculate_configured_product_totals.
-- - width desde config_snapshot.measurements.width_total_mm o cp.width_mm.
-- - CatalogItemsMSRP siempre ORDER BY updated_at DESC LIMIT 1 (get_roll_pricing ya lo hace).
-- - Selección por role desde config_snapshot (try_parse_uuid), no columnas CP.
-- - totals: roll_total_cost desde v_roll_total_cost o roll_total_cost_landed (NO roll_total_cost).
-- ============================================================================

-- Helper: parsear UUID seguro (retorna NULL si inválido)
CREATE OR REPLACE FUNCTION public.try_parse_uuid(p_text text)
RETURNS uuid
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_text IS NULL OR trim(p_text) = '' THEN
    RETURN NULL;
  END IF;
  RETURN p_text::uuid;
EXCEPTION WHEN invalid_text_representation OR OTHERS THEN
  RETURN NULL;
END;
$$;

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

  -- ══════════════════════════════════════════════════════════════════════════
  -- ROLL: qty con roll_pricing_mode/measure_basis (como calculate_configured_product_totals)
  -- per_unit => factor=1; per_linear_meter/linear => factor=height_m;
  -- else (per_m2/default) => factor=(roll_width*height_m) si roll_width>0, else (width_total_m*height_m)
  -- qty final = factor * COALESCE(cp.quantity, 1)
  -- msrp desde get_roll_pricing (ya usa ORDER BY updated_at DESC)
  -- ══════════════════════════════════════════════════════════════════════════
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT r.msrp, r.dealer_price, r.labor_msrp
    INTO v_roll_msrp_unit, v_roll_dealer_unit, v_roll_labor_unit
    FROM public.get_roll_pricing(p_org_id, v_cp.roll_catalog_item_id) r;

    SELECT ci.sku, ci.name, ci.unit_of_measure,
           ci.roll_pricing_mode, ci.measure_basis,
           COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_catalog
    INTO v_item_info
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id
      AND ci.organization_id = p_org_id
    LIMIT 1;

    v_roll_width_effective := COALESCE(v_cp.roll_width, (v_item_info.roll_width_catalog)::numeric, 0);

    -- Factor por UOM
    IF COALESCE(v_item_info.roll_pricing_mode, '') = 'per_unit' THEN
      v_roll_factor := 1;
    ELSIF COALESCE(v_item_info.roll_pricing_mode, '') = 'per_linear_meter'
       OR COALESCE(v_item_info.measure_basis, '') = 'linear' THEN
      v_roll_factor := v_height_m;
    ELSE
      -- per_m2, per_square_meter, default: area
      IF v_roll_width_effective > 0 THEN
        v_roll_factor := v_roll_width_effective * v_height_m;
      ELSE
        v_roll_factor := v_width_total_m * v_height_m;
      END IF;
    END IF;

    v_roll_qty := GREATEST(v_roll_factor, 0) * COALESCE(v_cp.quantity, 1);
    v_qty := v_roll_qty;
    v_unit_price := COALESCE(v_roll_msrp_unit, 0);
    v_line_total := ROUND(v_qty * v_unit_price, 2);

    -- total_cost desde CatalogItemsMSRP (ORDER BY updated_at DESC)
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
      'uom', 'm²',
      'unit_price', v_unit_price,
      'line_total', v_line_total,
      'children', '[]'::jsonb,
      'meta', jsonb_build_object(
        'collection_name', v_cp.roll_collection_name,
        'variant_name', v_cp.roll_variant_name,
        'roll_width', v_cp.roll_width,
        'roll_factor', v_roll_factor
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

  -- roll_qty para calculate_configured_product_totals (fallback cuando factor=0)
  -- NO usar v_cp.roll_total_cost (no existe en ConfiguredProducts)
  v_totals := jsonb_build_object(
    'roll_qty', v_roll_qty,
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_sum,
    'accessories_total', v_accessories_total,
    'labor_pct', COALESCE(v_cp.labor_pct, 0),
    'labor_amount', v_labor_amount,
    'total_msrp', v_total_msrp,
    'roll_total_cost', COALESCE(v_roll_total_cost, v_cp.roll_total_cost_landed, 0),
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
'BOM preview JSONB. Roll qty por roll_pricing_mode/measure_basis (per_unit=1, per_linear_meter=height_m, else area con roll_width o width_total). width desde config_snapshot.measurements.width_total_mm. CatalogItemsMSRP ORDER BY updated_at DESC.';


-- ============================================================================
-- TESTING / RECOVERY STEPS (IDs de ejemplo: cp e65a2101..., ql 978877f1...)
-- ============================================================================

/*
-- 1) Unlock QuoteLine (si quedó con pricing_locked=true y msrp=0)
UPDATE public."QuoteLines"
SET pricing_locked = false
WHERE id = '978877f1-90de-4505-94f8-68ef84b4ef0b'::uuid;

-- 2) Recalcular CP (build_bom_preview_snapshot + totals)
SELECT public.calculate_configured_product_totals('e65a2101-0989-40f4-bfbd-893fa72c3b78'::uuid);

-- 3) Sync a QuoteLine
SELECT public.sync_quote_line_pricing_from_configured_product('978877f1-90de-4505-94f8-68ef84b4ef0b'::uuid);

-- 4) Verificar
SELECT id, msrp, unit_msrp_total_snapshot, dealer_price_total, total_cost, pricing_locked
FROM public."QuoteLines"
WHERE id = '978877f1-90de-4505-94f8-68ef84b4ef0b'::uuid;
*/

/*
-- DIAGNÓSTICO (sustituir :cp_id y :ql_id)
-- 1) CP: dimensiones y roll
SELECT id, width_mm, height_mm, roll_width, roll_catalog_item_id,
       config_snapshot->'measurements' AS measurements,
       config_snapshot->>'drive_item_id' AS drive_from_config
FROM public."ConfiguredProducts" WHERE id = :cp_id;

-- 2) CatalogItemsMSRP del roll (ordenado por updated_at)
SELECT cim.catalog_item_id, cim.msrp, cim.dealer_price, cim.unit_of_measure, cim.updated_at
FROM public."CatalogItemsMSRP" cim
WHERE cim.catalog_item_id = (
  SELECT roll_catalog_item_id FROM public."ConfiguredProducts" WHERE id = :cp_id
) AND cim.organization_id = (SELECT organization_id FROM public."ConfiguredProducts" WHERE id = :cp_id)
ORDER BY cim.updated_at DESC;

-- 3) Recalcular snapshot manual
SELECT public.build_bom_preview_snapshot(
  (SELECT organization_id FROM public."ConfiguredProducts" WHERE id = :cp_id),
  :cp_id,
  (SELECT bom_template_id FROM public."ConfiguredProducts" WHERE id = :cp_id)
) AS snapshot_result;

-- 4) Después de calculate_configured_product_totals
SELECT id, roll_msrp_total, bom_total, total_msrp,
       bom_preview_snapshot->'totals'->>'roll_msrp_total' AS snap_roll,
       bom_preview_snapshot->'totals'->>'total_msrp' AS snap_total
FROM public."ConfiguredProducts" WHERE id = :cp_id;
*/
