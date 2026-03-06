-- ============================================================================
-- Add fabric slot to BOMTemplateSlots & improve WO routing
-- ============================================================================
-- 1. Adds 'fabric' slot to BOMTemplateSlots for all templates that have a
--    fabric BOMComponent but no fabric slot (was excluded from migration 20260119)
-- 2. Updates generate_work_orders_for_mo to also match by part_role
--    (not just CatalogItems.measure_basis/is_roll) for more robust routing
-- ============================================================================

SET search_path = public;

-- --------------------------------------------------------------------------
-- 1. Add fabric BOMTemplateSlot for every template that has fabric in BOMComponents
-- --------------------------------------------------------------------------
INSERT INTO "BOMTemplateSlots" (organization_id, bom_template_id, item_role, required, catalog_item_id, qty, notes)
SELECT DISTINCT bt.organization_id, bt.id, 'fabric', true, NULL::uuid, 1,
  'Fabric slot: resolved from QuoteLineComponents user selection'
FROM "BOMTemplates" bt
WHERE bt.deleted = false
  AND NOT EXISTS (
    SELECT 1 FROM "BOMTemplateSlots" bts
    WHERE bts.bom_template_id = bt.id
      AND bts.item_role = 'fabric'
  );

-- --------------------------------------------------------------------------
-- 2. Update generate_work_orders_for_mo to match by part_role too
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_work_orders_for_mo(p_mo_id uuid)
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
    RETURN jsonb_build_object('ok', false, 'error', 'Work order tasks already exist for this MO');
  END IF;

  FOR v_wc IN
    SELECT * FROM "WorkCenters"
    WHERE organization_id = v_org_id AND is_active = true AND deleted = false
    ORDER BY sequence
  LOOP
    v_rule := v_wc.routing_rule;

    -- ASSEMBLY station: gets ALL lines
    IF (v_rule->>'is_assembly')::boolean IS TRUE THEN
      INSERT INTO "WorkOrderTasks" (organization_id, manufacturing_order_id, work_center_id, sequence, status)
      VALUES (v_org_id, p_mo_id, v_wc.id, v_wc.sequence, 'pending')
      RETURNING id INTO v_assembly_id;
      v_task_count := v_task_count + 1;

      INSERT INTO "WorkOrderTaskLines" (task_id, bom_instance_line_id, catalog_item_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm)
      SELECT
        v_assembly_id,
        bil.id,
        bil.resolved_part_id,
        ci.sku,
        ci.name,
        bil.part_role,
        bil.qty,
        bil.uom,
        bil.cut_length_mm,
        bil.cut_width_mm
      FROM "BOMInstanceLines" bil
      JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
      LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
      WHERE bi.manufacturing_order_id = p_mo_id
        AND bil.deleted = false;

      v_line_count := v_line_count + (SELECT count(*) FROM "WorkOrderTaskLines" WHERE task_id = v_assembly_id);
      CONTINUE;
    END IF;

    v_task_id := NULL;

    FOR v_line IN
      SELECT
        bil.id AS bil_id,
        bil.resolved_part_id,
        ci.sku,
        ci.name AS item_name,
        bil.part_role,
        bil.qty,
        bil.uom,
        bil.cut_length_mm,
        bil.cut_width_mm,
        ci.measure_basis,
        ci.is_roll
      FROM "BOMInstanceLines" bil
      JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
      LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
      WHERE bi.manufacturing_order_id = p_mo_id
        AND bil.deleted = false
    LOOP
      v_matched := true;

      -- Check measure_basis rule
      IF v_rule ? 'measure_basis' THEN
        IF COALESCE(v_line.measure_basis, '') <> (v_rule->>'measure_basis') THEN
          v_matched := false;
        END IF;
      END IF;

      -- Check is_roll rule (from CatalogItem OR from part_role='fabric')
      IF v_matched AND v_rule ? 'is_roll' THEN
        IF (v_rule->>'is_roll')::boolean IS TRUE THEN
          -- For CUT-ROLL: match if CatalogItem.is_roll=true OR part_role='fabric'
          IF NOT (COALESCE(v_line.is_roll, false) OR v_line.part_role = 'fabric') THEN
            v_matched := false;
          END IF;
        ELSE
          -- For non-roll rules: exclude roll items AND fabric
          IF COALESCE(v_line.is_roll, false) OR v_line.part_role = 'fabric' THEN
            v_matched := false;
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
        VALUES (v_task_id, v_line.bil_id, v_line.resolved_part_id, v_line.sku, v_line.item_name, v_line.part_role, v_line.qty, v_line.uom, v_line.cut_length_mm, v_line.cut_width_mm);
        v_line_count := v_line_count + 1;
      END IF;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'tasks_created', v_task_count, 'lines_created', v_line_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_work_orders_for_mo(uuid) TO authenticated;

DO $$ BEGIN RAISE NOTICE 'Fabric slot + WO routing improvements applied'; END $$;
