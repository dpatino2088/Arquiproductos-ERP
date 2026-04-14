-- ============================================================================
-- Per-line Work Order generation
-- When a MOL transitions to 'confirmed', auto-generate WO tasks for that line.
-- WorkOrderTasks gains sales_order_line_id for per-line tracking.
-- ============================================================================

SET search_path = public;

-- 1. Add sales_order_line_id to WorkOrderTasks
ALTER TABLE public."WorkOrderTasks"
  ADD COLUMN IF NOT EXISTS sales_order_line_id uuid REFERENCES public."SaleOrderLines"(id);

CREATE INDEX IF NOT EXISTS idx_wot_sol_id ON public."WorkOrderTasks" (sales_order_line_id)
  WHERE sales_order_line_id IS NOT NULL;

-- 2. Per-line WO generation RPC
CREATE OR REPLACE FUNCTION public.generate_work_orders_for_line(
  p_mo_id                uuid,
  p_sales_order_line_id  uuid,
  p_regenerate           boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mo            record;
  v_org_id        uuid;
  v_wc            record;
  v_task_id       uuid;
  v_line          record;
  v_matched       boolean;
  v_rule          jsonb;
  v_task_count    int := 0;
  v_line_count    int := 0;
  v_assembly_id   uuid;
  v_parent_names  text[];
  v_part_roles    text[];
  v_require_linear boolean;
  v_is_pick       boolean;
  v_routed_bils   uuid[] := ARRAY[]::uuid[];
BEGIN
  SELECT mo.*, mo.organization_id AS org_id INTO v_mo
  FROM "ManufacturingOrders" mo
  WHERE mo.id = p_mo_id AND mo.deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  v_org_id := v_mo.org_id;

  IF EXISTS (
    SELECT 1 FROM "WorkOrderTasks"
    WHERE manufacturing_order_id = p_mo_id
      AND sales_order_line_id = p_sales_order_line_id
      AND deleted = false
  ) THEN
    IF p_regenerate THEN
      DELETE FROM "WorkOrderTaskLines"
      WHERE task_id IN (
        SELECT id FROM "WorkOrderTasks"
        WHERE manufacturing_order_id = p_mo_id
          AND sales_order_line_id = p_sales_order_line_id
          AND deleted = false
      );
      DELETE FROM "WorkOrderTasks"
      WHERE manufacturing_order_id = p_mo_id
        AND sales_order_line_id = p_sales_order_line_id
        AND deleted = false;
    ELSE
      RETURN jsonb_build_object('ok', false, 'error', 'Work order tasks already exist for this line.');
    END IF;
  END IF;

  FOR v_wc IN
    SELECT * FROM "WorkCenters"
    WHERE organization_id = v_org_id AND is_active = true AND deleted = false
    ORDER BY sequence
  LOOP
    v_rule := v_wc.routing_rule;

    -- ASSEMBLY station
    IF (v_rule->>'is_assembly')::boolean IS TRUE THEN
      INSERT INTO "WorkOrderTasks" (organization_id, manufacturing_order_id, work_center_id, sequence, status, sales_order_line_id)
      VALUES (v_org_id, p_mo_id, v_wc.id, v_wc.sequence, 'pending', p_sales_order_line_id)
      RETURNING id INTO v_assembly_id;
      v_task_count := v_task_count + 1;

      INSERT INTO "WorkOrderTaskLines"
        (task_id, bom_instance_line_id, catalog_item_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm)
      SELECT v_assembly_id, bil.id, bil.resolved_part_id, ci.sku, ci.name, bil.part_role, bil.qty, bil.uom, bil.cut_length_mm, bil.cut_height_mm
      FROM "BOMInstanceLines" bil
      JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
      LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
      WHERE bi.manufacturing_order_id = p_mo_id
        AND bi.sales_order_line_id = p_sales_order_line_id
        AND bil.deleted = false;

      v_line_count := v_line_count + (SELECT count(*) FROM "WorkOrderTaskLines" WHERE task_id = v_assembly_id);
      CONTINUE;
    END IF;

    -- PICK station
    v_is_pick := COALESCE((v_rule->>'is_pick')::boolean, false);
    IF v_is_pick THEN
      v_task_id := NULL;
      FOR v_line IN
        SELECT bil.id AS bil_id, bil.resolved_part_id, ci.sku, ci.name AS item_name,
               bil.part_role, bil.qty, bil.uom, bil.cut_length_mm, bil.cut_height_mm
        FROM "BOMInstanceLines" bil
        JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
        LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
        WHERE bi.manufacturing_order_id = p_mo_id
          AND bi.sales_order_line_id = p_sales_order_line_id
          AND bil.deleted = false
          AND bil.id <> ALL(v_routed_bils)
      LOOP
        IF v_task_id IS NULL THEN
          INSERT INTO "WorkOrderTasks" (organization_id, manufacturing_order_id, work_center_id, sequence, status, sales_order_line_id)
          VALUES (v_org_id, p_mo_id, v_wc.id, v_wc.sequence, 'pending', p_sales_order_line_id)
          RETURNING id INTO v_task_id;
          v_task_count := v_task_count + 1;
        END IF;

        INSERT INTO "WorkOrderTaskLines" (task_id, bom_instance_line_id, catalog_item_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm)
        VALUES (v_task_id, v_line.bil_id, v_line.resolved_part_id, v_line.sku, v_line.item_name, v_line.part_role, v_line.qty, v_line.uom, v_line.cut_length_mm, v_line.cut_height_mm);
        v_line_count := v_line_count + 1;
      END LOOP;
      CONTINUE;
    END IF;

    -- CUTTING stations
    IF v_rule ? 'category_parent_names' THEN
      SELECT array_agg(lower(elem)) INTO v_parent_names FROM jsonb_array_elements_text(v_rule->'category_parent_names') AS elem;
    ELSE
      v_parent_names := NULL;
    END IF;

    IF v_rule ? 'part_roles' THEN
      SELECT array_agg(elem) INTO v_part_roles FROM jsonb_array_elements_text(v_rule->'part_roles') AS elem;
    ELSE
      v_part_roles := NULL;
    END IF;

    v_require_linear := COALESCE((v_rule->>'require_linear')::boolean, false);
    v_task_id := NULL;

    FOR v_line IN
      SELECT bil.id AS bil_id, bil.resolved_part_id, ci.sku, ci.name AS item_name, bil.part_role, bil.qty, bil.uom,
             bil.cut_length_mm, bil.cut_height_mm, ci.measure_basis, ci.is_roll, cat.name AS category_name, pcat.name AS parent_category_name
      FROM "BOMInstanceLines" bil
      JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
      LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
      LEFT JOIN "CatalogCategories" cat ON cat.id = ci.category_id AND cat.deleted = false
      LEFT JOIN "CatalogCategories" pcat ON pcat.id = cat.parent_id AND pcat.deleted = false
      WHERE bi.manufacturing_order_id = p_mo_id
        AND bi.sales_order_line_id = p_sales_order_line_id
        AND bil.deleted = false
    LOOP
      v_matched := false;

      IF v_parent_names IS NOT NULL THEN
        IF lower(COALESCE(v_line.parent_category_name, '')) = ANY(v_parent_names)
           OR lower(COALESCE(v_line.category_name, '')) = ANY(v_parent_names) THEN
          v_matched := true;
        END IF;
      END IF;

      IF NOT v_matched AND v_part_roles IS NOT NULL THEN
        IF COALESCE(v_line.part_role, '') = ANY(v_part_roles) THEN
          v_matched := true;
        END IF;
      END IF;

      IF v_matched AND v_require_linear THEN
        IF COALESCE(v_line.measure_basis, '') NOT IN ('linear', 'area') THEN
          v_matched := false;
        END IF;
      END IF;

      IF v_matched THEN
        IF v_task_id IS NULL THEN
          INSERT INTO "WorkOrderTasks" (organization_id, manufacturing_order_id, work_center_id, sequence, status, sales_order_line_id)
          VALUES (v_org_id, p_mo_id, v_wc.id, v_wc.sequence, 'pending', p_sales_order_line_id)
          RETURNING id INTO v_task_id;
          v_task_count := v_task_count + 1;
        END IF;

        INSERT INTO "WorkOrderTaskLines" (task_id, bom_instance_line_id, catalog_item_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm)
        VALUES (v_task_id, v_line.bil_id, v_line.resolved_part_id, v_line.sku, v_line.item_name, v_line.part_role, v_line.qty, v_line.uom, v_line.cut_length_mm, v_line.cut_height_mm);
        v_line_count := v_line_count + 1;
        v_routed_bils := array_append(v_routed_bils, v_line.bil_id);
      END IF;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'tasks_created', v_task_count, 'lines_created', v_line_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_work_orders_for_line(uuid, uuid, boolean) TO authenticated;

-- 3. Update advance_mo_line_status to auto-generate WOs on confirmed
CREATE OR REPLACE FUNCTION public.advance_mo_line_status(
  p_line_id uuid,
  p_new_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_line RECORD;
  v_mo   RECORD;
  v_readiness RECORD;
  v_wo_result jsonb;
  v_valid_transitions jsonb := '{
    "draft":         ["reviewed", "cancelled"],
    "reviewed":      ["confirmed", "cancelled"],
    "confirmed":     ["in_production", "cancelled"],
    "in_production": ["completed", "cancelled"],
    "completed":     []
  }'::jsonb;
  v_allowed jsonb;
BEGIN
  SELECT mol.*, mo.id AS mo_id, mo.organization_id, mo.status AS mo_status
  INTO v_line
  FROM "ManufacturingOrderLines" mol
  JOIN "ManufacturingOrders" mo ON mo.id = mol.manufacturing_order_id
  WHERE mol.id = p_line_id
    AND mol.deleted = false
    AND mo.deleted = false;

  IF v_line IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Line not found');
  END IF;

  v_allowed := v_valid_transitions -> v_line.status;
  IF v_allowed IS NULL OR NOT v_allowed ? p_new_status THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', format('Cannot transition from %s to %s', v_line.status, p_new_status)
    );
  END IF;

  -- Gate: confirmed requires material readiness = ok
  IF p_new_status = 'confirmed' THEN
    SELECT r.readiness_status INTO v_readiness
    FROM get_mo_line_material_readiness(v_line.mo_id) r
    WHERE r.sales_order_line_id = v_line.sales_order_line_id
    LIMIT 1;

    IF v_readiness IS NULL OR v_readiness.readiness_status != 'ok' THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'Cannot confirm: materials are not ready for this line'
      );
    END IF;
  END IF;

  UPDATE "ManufacturingOrderLines"
  SET status = p_new_status, updated_at = now()
  WHERE id = p_line_id;

  -- Auto-generate Work Orders when line is confirmed
  IF p_new_status = 'confirmed' AND v_line.sales_order_line_id IS NOT NULL THEN
    v_wo_result := public.generate_work_orders_for_line(
      v_line.mo_id,
      v_line.sales_order_line_id,
      false
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'status', p_new_status,
    'wo_generated', COALESCE(v_wo_result->>'ok' = 'true', false)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.advance_mo_line_status(uuid, text) TO authenticated;

-- 4. Relax WO insert gate: allow when MO has any confirmed/in_production lines
CREATE OR REPLACE FUNCTION public.enforce_workorder_insert_on_confirmed_mo()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_status text;
  v_has_confirmed_lines boolean;
BEGIN
  SELECT mo.status::text
  INTO v_status
  FROM public."ManufacturingOrders" mo
  WHERE mo.id = NEW.manufacturing_order_id
    AND mo.deleted = false;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Manufacturing Order not found for Work Order task.';
  END IF;

  IF v_status IN ('materials_ready', 'planned', 'in_production') THEN
    RETURN NEW;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public."ManufacturingOrderLines"
    WHERE manufacturing_order_id = NEW.manufacturing_order_id
      AND deleted = false
      AND status IN ('confirmed', 'in_production', 'completed')
  ) INTO v_has_confirmed_lines;

  IF v_has_confirmed_lines THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Work Orders can only be generated when MO or its lines are confirmed / materials ready (current MO status: %).', v_status;
END;
$$;
