-- ============================================================================
-- MO material completeness: block WO generation and transition to production
-- when materials are incomplete. No pricing/cost calculations modified.
-- ============================================================================
-- 1. get_mo_material_readiness(p_mo_id) → { status: 'complete'|'incomplete', has_shortage }
-- 2. transition_mo_status: reject in_production (and planned) if incomplete
-- 3. generate_work_orders_for_mo: return error if MO material incomplete
-- ============================================================================

SET search_path = public;

-- --------------------------------------------------------------------------
-- 1. Function: get_mo_material_readiness
-- Uses same logic as Material Demand: need = required - on_hand - on_order
-- (no item_min_qty / reorder logic; only MO requirement coverage)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_mo_material_readiness(p_mo_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_org_id    uuid;
  v_demand    record;
  v_on_hand   numeric;
  v_on_order  numeric;
  v_need      numeric;
  v_has_shortage boolean := false;
BEGIN
  SELECT mo.organization_id INTO v_org_id
  FROM "ManufacturingOrders" mo
  WHERE mo.id = p_mo_id AND mo.deleted = false;

  IF v_org_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found', 'status', 'incomplete', 'has_shortage', true);
  END IF;

  FOR v_demand IN
    SELECT d.manufacturing_order_id, d.catalog_item_id, d.required_qty
    FROM manufacturing_order_material_demand d
    WHERE d.manufacturing_order_id = p_mo_id
  LOOP
    v_on_hand := COALESCE((
      SELECT SUM(h.on_hand_qty)
      FROM inventory_on_hand h
      WHERE h.organization_id = v_org_id AND h.catalog_item_id = v_demand.catalog_item_id
    ), 0);
    v_on_order := COALESCE((
      SELECT SUM(o.on_order_qty)
      FROM inventory_on_order o
      WHERE o.organization_id = v_org_id AND o.catalog_item_id = v_demand.catalog_item_id
    ), 0);
    v_need := GREATEST(0, (v_demand.required_qty::numeric - v_on_hand - v_on_order));
    IF v_need > 0 THEN
      v_has_shortage := true;
      EXIT;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'status', CASE WHEN v_has_shortage THEN 'incomplete' ELSE 'complete' END,
    'has_shortage', v_has_shortage
  );
END;
$$;

COMMENT ON FUNCTION public.get_mo_material_readiness(uuid) IS
  'Returns material readiness for an MO. status=complete when (on_hand+on_order) >= required for all demand lines; otherwise incomplete. Used to block WO generation and transition to production.';

GRANT EXECUTE ON FUNCTION public.get_mo_material_readiness(uuid) TO authenticated;

-- Batch version for list views (avoid N+1)
CREATE OR REPLACE FUNCTION public.get_mo_material_readiness_batch(p_mo_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_mo_id    uuid;
  v_result   jsonb;
  v_results  jsonb := '[]'::jsonb;
BEGIN
  IF p_mo_ids IS NULL OR array_length(p_mo_ids, 1) IS NULL THEN
    RETURN v_results;
  END IF;
  FOREACH v_mo_id IN ARRAY p_mo_ids
  LOOP
    v_result := public.get_mo_material_readiness(v_mo_id);
    v_results := v_results || jsonb_build_array(jsonb_build_object('mo_id', v_mo_id, 'status', v_result->>'status', 'has_shortage', COALESCE((v_result->>'has_shortage')::boolean, true)));
  END LOOP;
  RETURN v_results;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_mo_material_readiness_batch(uuid[]) TO authenticated;

-- --------------------------------------------------------------------------
-- 2. transition_mo_status: reject transition to in_production (and planned)
--    when MO has material shortage. Create if not exists; else replace.
-- --------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.transition_mo_status(uuid, text, uuid, text);

CREATE OR REPLACE FUNCTION public.transition_mo_status(
  p_mo_id     uuid,
  p_new_status text,
  p_user_id   uuid,
  p_user_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mo     record;
  v_readiness jsonb;
  v_has_shortage boolean;
  v_from   text;
BEGIN
  SELECT * INTO v_mo FROM "ManufacturingOrders" WHERE id = p_mo_id AND deleted = false;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  v_from := COALESCE(v_mo.status::text, '');

  -- Block transition to planned or in_production when materials incomplete
  IF lower(trim(p_new_status)) IN ('planned', 'in_production') THEN
    v_readiness := public.get_mo_material_readiness(p_mo_id);
    v_has_shortage := (v_readiness->>'has_shortage')::boolean = true;
    IF v_has_shortage THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'Materials incomplete. Cover material demand (or receive POs) before advancing. Use Material Demand or Buy Materials.',
        'from', v_from,
        'to', p_new_status,
        'material_readiness', v_readiness
      );
    END IF;
  END IF;

  UPDATE "ManufacturingOrders"
  SET status = trim(p_new_status)::manufacturing_order_status,
      updated_at = now(),
      production_started_at = CASE WHEN lower(trim(p_new_status)) = 'in_production' AND (production_started_at IS NULL) THEN now() ELSE production_started_at END
  WHERE id = p_mo_id AND deleted = false;

  RETURN jsonb_build_object('ok', true, 'from', v_from, 'to', trim(p_new_status));
END;
$$;

GRANT EXECUTE ON FUNCTION public.transition_mo_status(uuid, text, uuid, text) TO authenticated;

-- --------------------------------------------------------------------------
-- 3. generate_work_orders_for_mo: at start, reject if MO material incomplete
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_work_orders_for_mo(
  p_mo_id       uuid,
  p_regenerate  boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mo          record;
  v_org_id      uuid;
  v_wc          record;
  v_task_id     uuid;
  v_line        record;
  v_matched     boolean;
  v_rule        jsonb;
  v_task_count  int := 0;
  v_line_count  int := 0;
  v_assembly_id uuid;
  v_parent_names text[];
  v_part_roles   text[];
  v_readiness   jsonb;
  v_has_shortage boolean;
BEGIN
  SELECT mo.*, mo.organization_id AS org_id INTO v_mo
  FROM "ManufacturingOrders" mo
  WHERE mo.id = p_mo_id AND mo.deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  -- Block WO generation when materials incomplete
  v_readiness := public.get_mo_material_readiness(p_mo_id);
  v_has_shortage := (v_readiness->>'has_shortage')::boolean = true;
  IF v_has_shortage THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Materials incomplete. Cannot generate Work Orders until material demand is covered. Use Material Demand or Buy Materials.',
      'material_readiness', v_readiness
    );
  END IF;

  v_org_id := v_mo.org_id;

  IF EXISTS (SELECT 1 FROM "WorkOrderTasks" WHERE manufacturing_order_id = p_mo_id AND deleted = false) THEN
    IF p_regenerate THEN
      DELETE FROM "WorkOrderTaskLines"
      WHERE task_id IN (SELECT id FROM "WorkOrderTasks" WHERE manufacturing_order_id = p_mo_id AND deleted = false);
      DELETE FROM "WorkOrderTasks" WHERE manufacturing_order_id = p_mo_id AND deleted = false;
    ELSE
      RETURN jsonb_build_object('ok', false, 'error', 'Work order tasks already exist for this MO. Use p_regenerate=true to replace.');
    END IF;
  END IF;

  FOR v_wc IN
    SELECT * FROM "WorkCenters"
    WHERE organization_id = v_org_id AND is_active = true AND deleted = false
    ORDER BY sequence
  LOOP
    v_rule := v_wc.routing_rule;

    IF (v_rule->>'is_assembly')::boolean IS TRUE THEN
      INSERT INTO "WorkOrderTasks" (organization_id, manufacturing_order_id, work_center_id, sequence, status)
      VALUES (v_org_id, p_mo_id, v_wc.id, v_wc.sequence, 'pending')
      RETURNING id INTO v_assembly_id;
      v_task_count := v_task_count + 1;
      INSERT INTO "WorkOrderTaskLines"
        (task_id, bom_instance_line_id, catalog_item_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm)
      SELECT v_assembly_id, bil.id, bil.resolved_part_id, ci.sku, ci.name, bil.part_role, bil.qty, bil.uom, bil.cut_length_mm, bil.cut_height_mm
      FROM "BOMInstanceLines" bil
      JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
      LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
      WHERE bi.manufacturing_order_id = p_mo_id AND bil.deleted = false;
      v_line_count := v_line_count + (SELECT count(*) FROM "WorkOrderTaskLines" WHERE task_id = v_assembly_id);
      CONTINUE;
    END IF;

    IF v_rule ? 'category_parent_names' THEN
      SELECT array_agg(lower(elem)) INTO v_parent_names FROM jsonb_array_elements_text(v_rule->'category_parent_names') AS elem;
    ELSE v_parent_names := NULL; END IF;
    IF v_rule ? 'part_roles' THEN
      SELECT array_agg(elem) INTO v_part_roles FROM jsonb_array_elements_text(v_rule->'part_roles') AS elem;
    ELSE v_part_roles := NULL; END IF;
    v_task_id := NULL;

    FOR v_line IN
      SELECT bil.id AS bil_id, bil.resolved_part_id, ci.sku, ci.name AS item_name, bil.part_role, bil.qty, bil.uom,
             bil.cut_length_mm, bil.cut_height_mm, ci.measure_basis, ci.is_roll, cat.name AS category_name, pcat.name AS parent_category_name
      FROM "BOMInstanceLines" bil
      JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
      LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
      LEFT JOIN "CatalogCategories" cat ON cat.id = ci.category_id AND cat.deleted = false
      LEFT JOIN "CatalogCategories" pcat ON pcat.id = cat.parent_id AND pcat.deleted = false
      WHERE bi.manufacturing_order_id = p_mo_id AND bil.deleted = false
    LOOP
      v_matched := false;
      IF v_parent_names IS NOT NULL THEN
        IF lower(COALESCE(v_line.parent_category_name, '')) = ANY(v_parent_names) OR lower(COALESCE(v_line.category_name, '')) = ANY(v_parent_names) THEN v_matched := true; END IF;
      END IF;
      IF NOT v_matched AND v_part_roles IS NOT NULL THEN
        IF COALESCE(v_line.part_role, '') = ANY(v_part_roles) THEN v_matched := true; END IF;
      END IF;
      IF NOT v_matched AND v_parent_names IS NULL AND v_part_roles IS NULL THEN
        v_matched := true;
        IF v_rule ? 'measure_basis' AND COALESCE(v_line.measure_basis, '') <> (v_rule->>'measure_basis') THEN v_matched := false; END IF;
        IF v_matched AND v_rule ? 'is_roll' THEN
          IF (v_rule->>'is_roll')::boolean THEN
            IF NOT (COALESCE(v_line.is_roll, false) OR v_line.part_role = 'fabric') THEN v_matched := false; END IF;
          ELSE
            IF COALESCE(v_line.is_roll, false) OR v_line.part_role = 'fabric' THEN v_matched := false; END IF;
          END IF;
        END IF;
      END IF;
      IF v_matched THEN
        IF v_task_id IS NULL THEN
          INSERT INTO "WorkOrderTasks" (organization_id, manufacturing_order_id, work_center_id, sequence, status)
          VALUES (v_org_id, p_mo_id, v_wc.id, v_wc.sequence, 'pending')
          RETURNING id INTO v_task_id;
          v_task_count := v_task_count + 1;
        END IF;
        INSERT INTO "WorkOrderTaskLines" (task_id, bom_instance_line_id, catalog_item_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm)
        VALUES (v_task_id, v_line.bil_id, v_line.resolved_part_id, v_line.sku, v_line.item_name, v_line.part_role, v_line.qty, v_line.uom, v_line.cut_length_mm, v_line.cut_height_mm);
        v_line_count := v_line_count + 1;
      END IF;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'tasks_created', v_task_count, 'lines_created', v_line_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_work_orders_for_mo(uuid, boolean) TO authenticated;

DO $$ BEGIN RAISE NOTICE 'MO material readiness: get_mo_material_readiness, transition_mo_status and generate_work_orders_for_mo updated'; END $$;
