-- Scale MO materials / WO task lines by SaleOrderLines.quantity.
-- BOMInstanceLines stay per-unit; demand already used bil.qty * sol.quantity.
-- Gaps fixed here:
--   1) ManufacturingOrderLines.quantity was defaulting to 1 (INSERT omitted quantity)
--   2) get_mo_line_materials_detail returned per-unit bil.qty
--   3) get_mo_line_material_readiness line_demand ignored sol.quantity
--   4) generate_work_orders_for_line copied bil.qty without × sol.quantity

-- ---------------------------------------------------------------------------
-- 1) Backfill MOL.quantity from SaleOrderLines
-- ---------------------------------------------------------------------------
UPDATE public."ManufacturingOrderLines" mol
SET quantity = COALESCE(sol.quantity, 1),
    updated_at = now()
FROM public."SaleOrderLines" sol
WHERE mol.sales_order_line_id = sol.id
  AND mol.deleted = false
  AND COALESCE(mol.quantity, 1) IS DISTINCT FROM COALESCE(sol.quantity, 1);

-- ---------------------------------------------------------------------------
-- 2) Patch generate_bom_for_manufacturing_order: set quantity on MOL insert
--    + sync existing MOL quantities for the MO on every BOM gen
-- ---------------------------------------------------------------------------
DO $patch$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'generate_bom_for_manufacturing_order';

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'generate_bom_for_manufacturing_order not found';
  END IF;

  v_old := $old$INSERT INTO public."ManufacturingOrderLines"(manufacturing_order_id, sales_order_line_id, organization_id, status)
        SELECT p_manufacturing_order_id, sol.id, COALESCE(v_mo.organization_id, sol.organization_id), 'draft'
        FROM public."SaleOrderLines" sol
        WHERE sol.sales_order_id = v_mo.sales_order_id AND COALESCE(sol.deleted, false) = false
          AND (v_mo.sales_order_line_id IS NULL OR sol.id = v_mo.sales_order_line_id)
          AND NOT EXISTS (SELECT 1 FROM public."ManufacturingOrderLines" m2 WHERE m2.manufacturing_order_id = p_manufacturing_order_id AND m2.sales_order_line_id = sol.id);
        GET DIAGNOSTICS v_cml = ROW_COUNT;$old$;

  v_new := $new$INSERT INTO public."ManufacturingOrderLines"(manufacturing_order_id, sales_order_line_id, organization_id, status, quantity)
        SELECT p_manufacturing_order_id, sol.id, COALESCE(v_mo.organization_id, sol.organization_id), 'draft', COALESCE(sol.quantity, 1)
        FROM public."SaleOrderLines" sol
        WHERE sol.sales_order_id = v_mo.sales_order_id AND COALESCE(sol.deleted, false) = false
          AND (v_mo.sales_order_line_id IS NULL OR sol.id = v_mo.sales_order_line_id)
          AND NOT EXISTS (SELECT 1 FROM public."ManufacturingOrderLines" m2 WHERE m2.manufacturing_order_id = p_manufacturing_order_id AND m2.sales_order_line_id = sol.id);
        GET DIAGNOSTICS v_cml = ROW_COUNT;

        -- Keep MOL.quantity aligned with SOL units (BOM is still 1 instance per SOL).
        UPDATE public."ManufacturingOrderLines" mol
        SET quantity = COALESCE(sol.quantity, 1),
            updated_at = now()
        FROM public."SaleOrderLines" sol
        WHERE mol.manufacturing_order_id = p_manufacturing_order_id
          AND mol.sales_order_line_id = sol.id
          AND mol.deleted = false
          AND COALESCE(mol.quantity, 1) IS DISTINCT FROM COALESCE(sol.quantity, 1);$new$;

  IF position(v_old IN v_def) = 0 THEN
    -- Already patched, or function text drifted — skip replace if quantity already present on insert.
    IF position('ManufacturingOrderLines"(manufacturing_order_id, sales_order_line_id, organization_id, status, quantity)' IN v_def) > 0 THEN
      RAISE NOTICE 'generate_bom_for_manufacturing_order already includes MOL.quantity; skip patch';
    ELSE
      RAISE EXCEPTION 'Could not locate MOL INSERT block to patch in generate_bom_for_manufacturing_order';
    END IF;
  ELSE
    v_def := replace(v_def, v_old, v_new);
    EXECUTE v_def;
  END IF;
END;
$patch$;

-- ---------------------------------------------------------------------------
-- 3) get_mo_line_materials_detail — expose qty as per-unit × SOL quantity
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_mo_line_materials_detail(p_mo_id uuid, p_sales_order_line_id uuid)
 RETURNS TABLE(
   bom_instance_line_id uuid,
   catalog_item_id uuid,
   sku text,
   item_name text,
   part_role text,
   qty numeric,
   uom text,
   unit_cost numeric,
   total_cost numeric,
   on_hand_qty numeric,
   on_order_qty numeric,
   allocated_qty numeric,
   missing_qty numeric,
   readiness text,
   excluded boolean
 )
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  WITH mo AS (
    SELECT organization_id
    FROM "ManufacturingOrders"
    WHERE id = p_mo_id AND deleted = false
    LIMIT 1
  ),
  mo_alloc AS (
    SELECT catalog_item_id, SUM(allocated_qty) AS total_alloc
    FROM "InventoryAllocations"
    WHERE manufacturing_order_id = p_mo_id
      AND status = 'reserved'
    GROUP BY catalog_item_id
  ),
  mo_demand AS (
    SELECT catalog_item_id, required_qty
    FROM manufacturing_order_material_demand
    WHERE manufacturing_order_id = p_mo_id
  ),
  bom_lines AS (
    SELECT
      bil.id AS bom_instance_line_id,
      bil.resolved_part_id AS catalog_item_id,
      ci.sku,
      ci.name AS item_name,
      bil.part_role,
      (COALESCE(bil.qty, 0) * COALESCE(sol.quantity, 1))::numeric AS qty,
      bil.uom,
      COALESCE(bil.unit_cost_exw, 0)::numeric AS unit_cost,
      (COALESCE(bil.total_cost_exw, 0) * COALESCE(sol.quantity, 1))::numeric AS total_cost,
      bil.excluded
    FROM "BOMInstances" bi
    JOIN "BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
    JOIN "SaleOrderLines" sol ON sol.id = bi.sales_order_line_id
    LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
    WHERE bi.manufacturing_order_id = p_mo_id
      AND bi.sales_order_line_id = p_sales_order_line_id
      AND bi.deleted = false
      AND bil.deleted = false
      AND bil.resolved_part_id IS NOT NULL
  )
  SELECT
    l.bom_instance_line_id,
    l.catalog_item_id,
    l.sku,
    l.item_name,
    l.part_role,
    l.qty,
    l.uom,
    l.unit_cost,
    l.total_cost,
    COALESCE((
      SELECT SUM(h.on_hand_qty)::numeric
      FROM inventory_on_hand h, mo
      WHERE h.organization_id = mo.organization_id
        AND h.catalog_item_id = l.catalog_item_id
    ), 0) AS on_hand_qty,
    COALESCE((
      SELECT SUM(o.on_order_qty)::numeric
      FROM inventory_on_order o, mo
      WHERE o.organization_id = mo.organization_id
        AND o.catalog_item_id = l.catalog_item_id
    ), 0) AS on_order_qty,
    COALESCE(ma.total_alloc, 0) AS allocated_qty,
    CASE WHEN l.excluded THEN 0
         ELSE GREATEST(0, COALESCE(md.required_qty, l.qty) - COALESCE(ma.total_alloc, 0))
    END AS missing_qty,
    CASE
      WHEN l.excluded THEN 'excluded'
      WHEN COALESCE(ma.total_alloc, 0) >= COALESCE(md.required_qty, l.qty) - 0.0001
        THEN 'ok'
      ELSE 'shortage'
    END AS readiness,
    l.excluded
  FROM bom_lines l
  LEFT JOIN mo_alloc ma ON ma.catalog_item_id = l.catalog_item_id
  LEFT JOIN mo_demand md ON md.catalog_item_id = l.catalog_item_id
  ORDER BY
    CASE l.part_role
      WHEN 'fabric' THEN 1
      WHEN 'tube' THEN 2
      WHEN 'motor' THEN 3
      WHEN 'drive' THEN 4
      WHEN 'bracket' THEN 5
      WHEN 'intermediate_bracket' THEN 6
      WHEN 'intermediate_connector' THEN 7
      WHEN 'headbox' THEN 8
      WHEN 'bottom_bar' THEN 9
      WHEN 'bottom_bar_profile' THEN 10
      WHEN 'end_cap' THEN 11
      WHEN 'end_plug' THEN 12
      WHEN 'chain' THEN 13
      WHEN 'track' THEN 14
      WHEN 'carrier' THEN 15
      WHEN 'glider' THEN 16
      WHEN 'hook' THEN 17
      WHEN 'accessory' THEN 18
      ELSE 19
    END,
    l.sku;
$function$;

-- ---------------------------------------------------------------------------
-- 4) get_mo_line_material_readiness — line demand × sol.quantity
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_mo_line_material_readiness(p_mo_id uuid)
 RETURNS TABLE(
   sales_order_line_id uuid,
   readiness_status text,
   has_shortage boolean,
   required_qty numeric,
   allocated_qty numeric,
   on_hand_qty numeric,
   missing_qty numeric
 )
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  WITH mo_alloc AS (
    SELECT catalog_item_id, SUM(allocated_qty) AS total_alloc
    FROM "InventoryAllocations"
    WHERE manufacturing_order_id = p_mo_id
      AND status = 'reserved'
    GROUP BY catalog_item_id
  ),
  mo_demand AS (
    SELECT catalog_item_id, required_qty
    FROM manufacturing_order_material_demand
    WHERE manufacturing_order_id = p_mo_id
  ),
  sku_ok AS (
    SELECT
      md.catalog_item_id,
      md.required_qty,
      COALESCE(ma.total_alloc, 0) AS allocated_qty,
      CASE WHEN COALESCE(ma.total_alloc, 0) >= md.required_qty - 0.0001
           THEN true ELSE false END AS is_covered
    FROM mo_demand md
    LEFT JOIN mo_alloc ma ON ma.catalog_item_id = md.catalog_item_id
  ),
  mo_lines AS (
    SELECT DISTINCT mol.sales_order_line_id
    FROM "ManufacturingOrderLines" mol
    WHERE mol.manufacturing_order_id = p_mo_id
      AND mol.deleted = false
      AND mol.sales_order_line_id IS NOT NULL
  ),
  line_demand AS (
    SELECT
      bi.sales_order_line_id,
      bil.resolved_part_id AS catalog_item_id,
      SUM(COALESCE(bil.qty, 0)::numeric * COALESCE(sol.quantity, 1)) AS line_required_qty
    FROM "BOMInstances" bi
    JOIN "BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
    JOIN "SaleOrderLines" sol ON sol.id = bi.sales_order_line_id
    WHERE bi.manufacturing_order_id = p_mo_id
      AND bi.deleted = false
      AND bil.deleted = false
      AND bil.excluded = false
      AND bi.sales_order_line_id IS NOT NULL
      AND bil.resolved_part_id IS NOT NULL
    GROUP BY bi.sales_order_line_id, bil.resolved_part_id
  ),
  line_check AS (
    SELECT
      ld.sales_order_line_id,
      SUM(ld.line_required_qty)                            AS required_qty,
      SUM(COALESCE(so.allocated_qty, 0))                   AS allocated_qty,
      SUM(GREATEST(0, ld.line_required_qty - COALESCE(so.allocated_qty, 0))) AS missing_qty,
      BOOL_AND(COALESCE(so.is_covered, false))             AS all_covered
    FROM line_demand ld
    LEFT JOIN sku_ok so ON so.catalog_item_id = ld.catalog_item_id
    GROUP BY ld.sales_order_line_id
  ),
  org AS (
    SELECT organization_id FROM "ManufacturingOrders"
    WHERE id = p_mo_id AND deleted = false LIMIT 1
  )
  SELECT
    ml.sales_order_line_id,
    CASE
      WHEN lc.required_qty IS NULL OR lc.required_qty = 0 THEN 'incomplete'
      WHEN lc.all_covered THEN 'ok'
      ELSE 'incomplete'
    END AS readiness_status,
    CASE
      WHEN lc.required_qty IS NULL OR lc.required_qty = 0 THEN true
      WHEN lc.all_covered THEN false
      ELSE true
    END AS has_shortage,
    COALESCE(lc.required_qty, 0)   AS required_qty,
    COALESCE(lc.allocated_qty, 0)  AS allocated_qty,
    COALESCE((
      SELECT SUM(h.on_hand_qty)::numeric
      FROM inventory_on_hand h, org
      WHERE h.organization_id = org.organization_id
    ), 0) AS on_hand_qty,
    COALESCE(lc.missing_qty, 0) AS missing_qty
  FROM mo_lines ml
  LEFT JOIN line_check lc ON lc.sales_order_line_id = ml.sales_order_line_id
  ORDER BY ml.sales_order_line_id;
$function$;

-- ---------------------------------------------------------------------------
-- 5) generate_work_orders_for_line — WO task line qty × sol.quantity
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_work_orders_for_line(
  p_mo_id                uuid,
  p_sales_order_line_id  uuid,
  p_regenerate           boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
  v_assembly_lines int := 0;
  v_sol_qty       numeric := 1;
BEGIN
  SELECT mo.*, mo.organization_id AS org_id INTO v_mo
  FROM "ManufacturingOrders" mo
  WHERE mo.id = p_mo_id AND mo.deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  v_org_id := v_mo.org_id;

  SELECT COALESCE(quantity, 1) INTO v_sol_qty
  FROM "SaleOrderLines"
  WHERE id = p_sales_order_line_id;

  IF v_sol_qty IS NULL OR v_sol_qty < 1 THEN
    v_sol_qty := 1;
  END IF;

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

    -- ASSEMBLY station: includes all active BOM lines as reference
    IF (v_rule->>'is_assembly')::boolean IS TRUE THEN
      INSERT INTO "WorkOrderTasks" (organization_id, manufacturing_order_id, work_center_id, sequence, status, sales_order_line_id)
      VALUES (v_org_id, p_mo_id, v_wc.id, v_wc.sequence, 'pending', p_sales_order_line_id)
      RETURNING id INTO v_assembly_id;

      INSERT INTO "WorkOrderTaskLines"
        (task_id, bom_instance_line_id, catalog_item_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm)
      SELECT v_assembly_id, bil.id, bil.resolved_part_id, ci.sku, ci.name, bil.part_role,
             bil.qty * v_sol_qty, bil.uom, bil.cut_length_mm, bil.cut_height_mm
      FROM "BOMInstanceLines" bil
      JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
      LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
      WHERE bi.manufacturing_order_id = p_mo_id
        AND bi.sales_order_line_id = p_sales_order_line_id
        AND bil.deleted = false
        AND COALESCE(bil.excluded, false) = false;

      SELECT count(*) INTO v_assembly_lines FROM "WorkOrderTaskLines" WHERE task_id = v_assembly_id;

      IF v_assembly_lines = 0 THEN
        DELETE FROM "WorkOrderTasks" WHERE id = v_assembly_id;
      ELSE
        v_task_count := v_task_count + 1;
        v_line_count := v_line_count + v_assembly_lines;
      END IF;
      CONTINUE;
    END IF;

    -- PICK station: only active (non-excluded) BOM lines not routed to a cutting station
    v_is_pick := COALESCE((v_rule->>'is_pick')::boolean, false);
    IF v_is_pick THEN
      v_task_id := NULL;
      FOR v_line IN
        SELECT bil.id AS bil_id, bil.resolved_part_id, ci.sku, ci.name AS item_name,
               bil.part_role, (bil.qty * v_sol_qty) AS qty, bil.uom, bil.cut_length_mm, bil.cut_height_mm
        FROM "BOMInstanceLines" bil
        JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
        LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
        WHERE bi.manufacturing_order_id = p_mo_id
          AND bi.sales_order_line_id = p_sales_order_line_id
          AND bil.deleted = false
          AND COALESCE(bil.excluded, false) = false
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

    -- CUTTING stations: only active (non-excluded) BOM lines matching routing rules
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
      SELECT bil.id AS bil_id, bil.resolved_part_id, ci.sku, ci.name AS item_name, bil.part_role,
             (bil.qty * v_sol_qty) AS qty, bil.uom,
             bil.cut_length_mm, bil.cut_height_mm, ci.measure_basis, ci.is_roll, cat.name AS category_name, pcat.name AS parent_category_name
      FROM "BOMInstanceLines" bil
      JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
      LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
      LEFT JOIN "CatalogCategories" cat ON cat.id = ci.category_id AND cat.deleted = false
      LEFT JOIN "CatalogCategories" pcat ON pcat.id = cat.parent_id AND pcat.deleted = false
      WHERE bi.manufacturing_order_id = p_mo_id
        AND bi.sales_order_line_id = p_sales_order_line_id
        AND bil.deleted = false
        AND COALESCE(bil.excluded, false) = false
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

  RETURN jsonb_build_object('ok', true, 'tasks_created', v_task_count, 'lines_created', v_line_count, 'sol_quantity', v_sol_qty);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.generate_work_orders_for_line(uuid, uuid, boolean) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6) Backfill pending WO task line qtys (not started / not done)
-- ---------------------------------------------------------------------------
UPDATE public."WorkOrderTaskLines" wotl
SET qty = bil.qty * COALESCE(sol.quantity, 1)
FROM public."BOMInstanceLines" bil,
     public."BOMInstances" bi,
     public."SaleOrderLines" sol,
     public."WorkOrderTasks" wot
WHERE wotl.bom_instance_line_id = bil.id
  AND bi.id = bil.bom_instance_id
  AND sol.id = bi.sales_order_line_id
  AND wot.id = wotl.task_id
  AND COALESCE(wot.deleted, false) = false
  AND COALESCE(wot.status, 'pending') IN ('pending', 'ready', 'in_progress')
  AND COALESCE(sol.quantity, 1) > 1
  AND ABS(COALESCE(wotl.qty, 0) - (bil.qty * COALESCE(sol.quantity, 1))) > 0.0001;
