SET search_path = public;

UPDATE "WorkCenters"
SET routing_rule = '{"category_parent_names": ["Profiles"]}'::jsonb,
    updated_at = now()
WHERE code = 'CUT-PROFILE';

UPDATE "WorkCenters"
SET routing_rule = '{"category_parent_names": ["Rolls"], "part_roles": ["fabric"]}'::jsonb,
    updated_at = now()
WHERE code = 'CUT-ROLL';

UPDATE "WorkCenters"
SET is_active = false,
    updated_at = now()
WHERE code = 'PICK';

DROP FUNCTION IF EXISTS public.generate_work_orders_for_mo(uuid);
DROP FUNCTION IF EXISTS public.generate_work_orders_for_mo(uuid, boolean);

CREATE OR REPLACE FUNCTION public.generate_work_orders_for_mo(
  p_mo_id       uuid,
  p_regenerate   boolean DEFAULT false
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
BEGIN
  SELECT mo.*, mo.organization_id AS org_id
  INTO v_mo
  FROM "ManufacturingOrders" mo
  WHERE mo.id = p_mo_id AND mo.deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  v_org_id := v_mo.org_id;

  IF EXISTS (SELECT 1 FROM "WorkOrderTasks" WHERE manufacturing_order_id = p_mo_id AND deleted = false) THEN
    IF p_regenerate THEN
      DELETE FROM "WorkOrderTaskLines"
      WHERE task_id IN (
        SELECT id FROM "WorkOrderTasks"
        WHERE manufacturing_order_id = p_mo_id AND deleted = false
      );
      DELETE FROM "WorkOrderTasks"
      WHERE manufacturing_order_id = p_mo_id AND deleted = false;
    ELSE
      RETURN jsonb_build_object('ok', false, 'error',
        'Work order tasks already exist for this MO. Use p_regenerate=true to replace.');
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
        (task_id, bom_instance_line_id, catalog_item_id, sku, item_name,
         component_role, qty, uom, cut_length_mm, cut_width_mm)
      SELECT
        v_assembly_id, bil.id, bil.resolved_part_id, ci.sku, ci.name,
        bil.part_role, bil.qty, bil.uom, bil.cut_length_mm, bil.cut_width_mm
      FROM "BOMInstanceLines" bil
      JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
      LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
      WHERE bi.manufacturing_order_id = p_mo_id
        AND bil.deleted = false;

      v_line_count := v_line_count +
        (SELECT count(*) FROM "WorkOrderTaskLines" WHERE task_id = v_assembly_id);
      CONTINUE;
    END IF;

    IF v_rule ? 'category_parent_names' THEN
      SELECT array_agg(lower(elem)) INTO v_parent_names
      FROM jsonb_array_elements_text(v_rule->'category_parent_names') AS elem;
    ELSE
      v_parent_names := NULL;
    END IF;

    IF v_rule ? 'part_roles' THEN
      SELECT array_agg(elem) INTO v_part_roles
      FROM jsonb_array_elements_text(v_rule->'part_roles') AS elem;
    ELSE
      v_part_roles := NULL;
    END IF;

    v_task_id := NULL;

    FOR v_line IN
      SELECT
        bil.id           AS bil_id,
        bil.resolved_part_id,
        ci.sku,
        ci.name          AS item_name,
        bil.part_role,
        bil.qty,
        bil.uom,
        bil.cut_length_mm,
        bil.cut_width_mm,
        ci.measure_basis,
        ci.is_roll,
        cat.name         AS category_name,
        pcat.name        AS parent_category_name
      FROM "BOMInstanceLines" bil
      JOIN "BOMInstances" bi    ON bi.id  = bil.bom_instance_id
      LEFT JOIN "CatalogItems" ci        ON ci.id  = bil.resolved_part_id
      LEFT JOIN "CatalogCategories" cat  ON cat.id  = ci.category_id  AND cat.deleted = false
      LEFT JOIN "CatalogCategories" pcat ON pcat.id = cat.parent_id   AND pcat.deleted = false
      WHERE bi.manufacturing_order_id = p_mo_id
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

      IF NOT v_matched AND v_parent_names IS NULL AND v_part_roles IS NULL THEN
        v_matched := true;

        IF v_rule ? 'measure_basis' THEN
          IF COALESCE(v_line.measure_basis, '') <> (v_rule->>'measure_basis') THEN
            v_matched := false;
          END IF;
        END IF;

        IF v_matched AND v_rule ? 'is_roll' THEN
          IF (v_rule->>'is_roll')::boolean IS TRUE THEN
            IF NOT (COALESCE(v_line.is_roll, false) OR v_line.part_role = 'fabric') THEN
              v_matched := false;
            END IF;
          ELSE
            IF COALESCE(v_line.is_roll, false) OR v_line.part_role = 'fabric' THEN
              v_matched := false;
            END IF;
          END IF;
        END IF;
      END IF;

      IF v_matched THEN
        IF v_task_id IS NULL THEN
          INSERT INTO "WorkOrderTasks"
            (organization_id, manufacturing_order_id, work_center_id, sequence, status)
          VALUES (v_org_id, p_mo_id, v_wc.id, v_wc.sequence, 'pending')
          RETURNING id INTO v_task_id;
          v_task_count := v_task_count + 1;
        END IF;

        INSERT INTO "WorkOrderTaskLines"
          (task_id, bom_instance_line_id, catalog_item_id, sku, item_name,
           component_role, qty, uom, cut_length_mm, cut_width_mm)
        VALUES
          (v_task_id, v_line.bil_id, v_line.resolved_part_id, v_line.sku,
           v_line.item_name, v_line.part_role, v_line.qty, v_line.uom,
           v_line.cut_length_mm, v_line.cut_width_mm);
        v_line_count := v_line_count + 1;
      END IF;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'tasks_created', v_task_count, 'lines_created', v_line_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_work_orders_for_mo(uuid, boolean) TO authenticated;;
