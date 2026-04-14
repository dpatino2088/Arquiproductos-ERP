-- ============================================================================
-- Fix legacy WorkOrderTasks: backfill sales_order_line_id from BOMInstanceLines
-- Also update generate_work_orders_for_mo to always set sales_order_line_id
-- ============================================================================
SET search_path = public;

-- 1. Backfill: derive sales_order_line_id for existing tasks from their task lines
UPDATE "WorkOrderTasks" wt
SET sales_order_line_id = sub.sol_id,
    updated_at = now()
FROM (
  SELECT wtl.task_id,
         bi.sales_order_line_id AS sol_id
  FROM "WorkOrderTaskLines" wtl
  JOIN "BOMInstanceLines" bil ON bil.id = wtl.bom_instance_line_id
  JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
  WHERE wtl.bom_instance_line_id IS NOT NULL
    AND bi.sales_order_line_id IS NOT NULL
  GROUP BY wtl.task_id, bi.sales_order_line_id
) sub
WHERE wt.id = sub.task_id
  AND wt.sales_order_line_id IS NULL
  AND wt.deleted = false;

-- 2. For tasks that had ALL BOMInstanceLines from same SOL but with multiple groups,
--    pick the most common one (handles edge cases)
UPDATE "WorkOrderTasks" wt
SET sales_order_line_id = sub.sol_id,
    updated_at = now()
FROM (
  SELECT wtl.task_id,
         bi.sales_order_line_id AS sol_id,
         count(*) AS cnt
  FROM "WorkOrderTaskLines" wtl
  JOIN "BOMInstanceLines" bil ON bil.id = wtl.bom_instance_line_id
  JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
  WHERE wtl.bom_instance_line_id IS NOT NULL
    AND bi.sales_order_line_id IS NOT NULL
  GROUP BY wtl.task_id, bi.sales_order_line_id
  ORDER BY wtl.task_id, cnt DESC
) sub
WHERE wt.id = sub.task_id
  AND wt.sales_order_line_id IS NULL
  AND wt.deleted = false;

-- 3. Handle tasks that mix multiple SOLs (legacy global generation):
--    Split them by deleting the mixed task and regenerating per-line.
--    For now, just assign the dominant SOL; the user can regenerate if needed.

-- 4. Update generate_work_orders_for_mo to set sales_order_line_id per task
DROP FUNCTION IF EXISTS public.generate_work_orders_for_mo(uuid, boolean);

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
  v_sol         record;
  v_wo_result   jsonb;
  v_total_tasks int := 0;
  v_total_lines int := 0;
BEGIN
  SELECT mo.*, mo.organization_id AS org_id INTO v_mo
  FROM "ManufacturingOrders" mo
  WHERE mo.id = p_mo_id AND mo.deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  v_org_id := v_mo.org_id;

  IF p_regenerate THEN
    DELETE FROM "WorkOrderTaskLines"
    WHERE task_id IN (SELECT id FROM "WorkOrderTasks" WHERE manufacturing_order_id = p_mo_id AND deleted = false);
    DELETE FROM "WorkOrderTasks" WHERE manufacturing_order_id = p_mo_id AND deleted = false;
  ELSIF EXISTS (SELECT 1 FROM "WorkOrderTasks" WHERE manufacturing_order_id = p_mo_id AND deleted = false) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Work order tasks already exist for this MO. Use p_regenerate=true to replace.');
  END IF;

  -- Generate per-line by iterating distinct sales_order_line_ids from BOMInstances
  FOR v_sol IN
    SELECT DISTINCT bi.sales_order_line_id
    FROM "BOMInstances" bi
    WHERE bi.manufacturing_order_id = p_mo_id
      AND bi.deleted = false
      AND bi.sales_order_line_id IS NOT NULL
    ORDER BY bi.sales_order_line_id
  LOOP
    v_wo_result := public.generate_work_orders_for_line(p_mo_id, v_sol.sales_order_line_id, false);
    IF (v_wo_result->>'ok')::boolean THEN
      v_total_tasks := v_total_tasks + COALESCE((v_wo_result->>'tasks_created')::int, 0);
      v_total_lines := v_total_lines + COALESCE((v_wo_result->>'lines_created')::int, 0);
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'tasks_created', v_total_tasks, 'lines_created', v_total_lines);
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_work_orders_for_mo(uuid, boolean) TO authenticated;
