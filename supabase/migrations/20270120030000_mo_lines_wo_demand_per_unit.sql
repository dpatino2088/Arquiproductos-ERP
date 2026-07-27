-- WO / materials / demand keyed by manufacturing_order_line_id; no bil × sol.quantity.

DROP FUNCTION IF EXISTS public.generate_work_orders_for_line(uuid, uuid, boolean);
DROP FUNCTION IF EXISTS public.get_mo_line_materials_detail(uuid, uuid);
DROP FUNCTION IF EXISTS public.get_mo_line_material_readiness(uuid);

-- ============================================================================
-- 1) generate_work_orders_for_line(p_mo_id, p_manufacturing_order_line_id, ...)
--    Same (uuid,uuid,boolean) identity; second arg is now MOL id.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.generate_work_orders_for_line(
  p_mo_id uuid,
  p_manufacturing_order_line_id uuid,
  p_regenerate boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_mo            record;
  v_mol           record;
  v_org_id        uuid;
  v_sol_id        uuid;
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
BEGIN
  SELECT mo.*, mo.organization_id AS org_id INTO v_mo
  FROM "ManufacturingOrders" mo
  WHERE mo.id = p_mo_id AND mo.deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  SELECT * INTO v_mol
  FROM "ManufacturingOrderLines"
  WHERE id = p_manufacturing_order_line_id
    AND manufacturing_order_id = p_mo_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Manufacturing order line not found');
  END IF;

  v_org_id := v_mo.org_id;
  v_sol_id := v_mol.sales_order_line_id;

  IF EXISTS (
    SELECT 1 FROM "WorkOrderTasks"
    WHERE manufacturing_order_id = p_mo_id
      AND manufacturing_order_line_id = p_manufacturing_order_line_id
      AND deleted = false
  ) THEN
    IF p_regenerate THEN
      DELETE FROM "WorkOrderTaskLines"
      WHERE task_id IN (
        SELECT id FROM "WorkOrderTasks"
        WHERE manufacturing_order_id = p_mo_id
          AND manufacturing_order_line_id = p_manufacturing_order_line_id
          AND deleted = false
      );
      DELETE FROM "WorkOrderTasks"
      WHERE manufacturing_order_id = p_mo_id
        AND manufacturing_order_line_id = p_manufacturing_order_line_id
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

    IF (v_rule->>'is_assembly')::boolean IS TRUE THEN
      INSERT INTO "WorkOrderTasks" (
        organization_id, manufacturing_order_id, work_center_id, sequence, status,
        sales_order_line_id, manufacturing_order_line_id
      )
      VALUES (
        v_org_id, p_mo_id, v_wc.id, v_wc.sequence, 'pending',
        v_sol_id, p_manufacturing_order_line_id
      )
      RETURNING id INTO v_assembly_id;

      INSERT INTO "WorkOrderTaskLines"
        (task_id, bom_instance_line_id, catalog_item_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm)
      SELECT v_assembly_id, bil.id, bil.resolved_part_id, ci.sku, ci.name, bil.part_role,
             bil.qty, bil.uom, bil.cut_length_mm, bil.cut_height_mm
      FROM "BOMInstanceLines" bil
      JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
      LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
      WHERE bi.manufacturing_order_id = p_mo_id
        AND bi.manufacturing_order_line_id = p_manufacturing_order_line_id
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
          AND bi.manufacturing_order_line_id = p_manufacturing_order_line_id
          AND bil.deleted = false
          AND COALESCE(bil.excluded, false) = false
          AND bil.id <> ALL(v_routed_bils)
      LOOP
        IF v_task_id IS NULL THEN
          INSERT INTO "WorkOrderTasks" (
            organization_id, manufacturing_order_id, work_center_id, sequence, status,
            sales_order_line_id, manufacturing_order_line_id
          )
          VALUES (
            v_org_id, p_mo_id, v_wc.id, v_wc.sequence, 'pending',
            v_sol_id, p_manufacturing_order_line_id
          )
          RETURNING id INTO v_task_id;
          v_task_count := v_task_count + 1;
        END IF;

        INSERT INTO "WorkOrderTaskLines" (task_id, bom_instance_line_id, catalog_item_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm)
        VALUES (v_task_id, v_line.bil_id, v_line.resolved_part_id, v_line.sku, v_line.item_name, v_line.part_role, v_line.qty, v_line.uom, v_line.cut_length_mm, v_line.cut_height_mm);
        v_line_count := v_line_count + 1;
      END LOOP;
      CONTINUE;
    END IF;

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
             bil.qty, bil.uom,
             bil.cut_length_mm, bil.cut_height_mm, ci.measure_basis, ci.is_roll,
             cat.name AS category_name, pcat.name AS parent_category_name
      FROM "BOMInstanceLines" bil
      JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
      LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
      LEFT JOIN "CatalogCategories" cat ON cat.id = ci.category_id AND cat.deleted = false
      LEFT JOIN "CatalogCategories" pcat ON pcat.id = cat.parent_id AND pcat.deleted = false
      WHERE bi.manufacturing_order_id = p_mo_id
        AND bi.manufacturing_order_line_id = p_manufacturing_order_line_id
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
          INSERT INTO "WorkOrderTasks" (
            organization_id, manufacturing_order_id, work_center_id, sequence, status,
            sales_order_line_id, manufacturing_order_line_id
          )
          VALUES (
            v_org_id, p_mo_id, v_wc.id, v_wc.sequence, 'pending',
            v_sol_id, p_manufacturing_order_line_id
          )
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

  RETURN jsonb_build_object(
    'ok', true,
    'tasks_created', v_task_count,
    'lines_created', v_line_count,
    'manufacturing_order_line_id', p_manufacturing_order_line_id
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.generate_work_orders_for_line(uuid, uuid, boolean) TO authenticated;

-- ============================================================================
-- 2) advance_mo_line_status → pass MOL id
-- ============================================================================
DO $patch$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'advance_mo_line_status';

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'advance_mo_line_status not found';
  END IF;

  IF position('v_line.sales_order_line_id,' IN v_def) > 0
     AND position('generate_work_orders_for_line' IN v_def) > 0 THEN
    v_def := replace(
      v_def,
      $old$v_wo_result := public.generate_work_orders_for_line(
      v_line.mo_id,
      v_line.sales_order_line_id,
      false
    );$old$,
      $new$v_wo_result := public.generate_work_orders_for_line(
      v_line.mo_id,
      v_line.id,
      false
    );$new$
    );
    -- alternate spacing variants
    v_def := replace(
      v_def,
      'generate_work_orders_for_line(
      v_line.manufacturing_order_id,
      v_line.sales_order_line_id,',
      'generate_work_orders_for_line(
      v_line.manufacturing_order_id,
      v_line.id,'
    );
    EXECUTE v_def;
  END IF;
END;
$patch$;

-- ============================================================================
-- 3) get_mo_line_materials_detail — per MOL, no × sol.quantity
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_mo_line_materials_detail(
  p_mo_id uuid,
  p_manufacturing_order_line_id uuid
)
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
      COALESCE(bil.qty, 0)::numeric AS qty,
      bil.uom,
      COALESCE(bil.unit_cost_exw, 0)::numeric AS unit_cost,
      COALESCE(bil.total_cost_exw, 0)::numeric AS total_cost,
      bil.excluded
    FROM "BOMInstances" bi
    JOIN "BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
    LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
    WHERE bi.manufacturing_order_id = p_mo_id
      AND bi.manufacturing_order_line_id = p_manufacturing_order_line_id
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
  ORDER BY l.part_role, l.sku;
$function$;

GRANT EXECUTE ON FUNCTION public.get_mo_line_materials_detail(uuid, uuid) TO authenticated;

-- ============================================================================
-- 4) get_mo_line_material_readiness — per MOL id
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_mo_line_material_readiness(p_mo_id uuid)
RETURNS TABLE(
  manufacturing_order_line_id uuid,
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
    SELECT mol.id AS manufacturing_order_line_id, mol.sales_order_line_id
    FROM "ManufacturingOrderLines" mol
    WHERE mol.manufacturing_order_id = p_mo_id
      AND mol.deleted = false
  ),
  line_demand AS (
    SELECT
      bi.manufacturing_order_line_id,
      bil.resolved_part_id AS catalog_item_id,
      SUM(COALESCE(bil.qty, 0)::numeric) AS line_required_qty
    FROM "BOMInstances" bi
    JOIN "BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
    WHERE bi.manufacturing_order_id = p_mo_id
      AND bi.deleted = false
      AND bil.deleted = false
      AND bil.excluded = false
      AND bi.manufacturing_order_line_id IS NOT NULL
      AND bil.resolved_part_id IS NOT NULL
    GROUP BY bi.manufacturing_order_line_id, bil.resolved_part_id
  ),
  line_check AS (
    SELECT
      ld.manufacturing_order_line_id,
      SUM(ld.line_required_qty) AS required_qty,
      SUM(COALESCE(so.allocated_qty, 0)) AS allocated_qty,
      SUM(GREATEST(0, ld.line_required_qty - COALESCE(so.allocated_qty, 0))) AS missing_qty,
      BOOL_AND(COALESCE(so.is_covered, false)) AS all_covered
    FROM line_demand ld
    LEFT JOIN sku_ok so ON so.catalog_item_id = ld.catalog_item_id
    GROUP BY ld.manufacturing_order_line_id
  ),
  org AS (
    SELECT organization_id FROM "ManufacturingOrders"
    WHERE id = p_mo_id AND deleted = false LIMIT 1
  )
  SELECT
    ml.manufacturing_order_line_id,
    ml.sales_order_line_id,
    CASE
      WHEN lc.required_qty IS NULL OR lc.required_qty = 0 THEN 'ok'
      WHEN lc.all_covered THEN 'ok'
      ELSE 'incomplete'
    END AS readiness_status,
    CASE
      WHEN lc.required_qty IS NULL OR lc.required_qty = 0 THEN false
      WHEN lc.all_covered THEN false
      ELSE true
    END AS has_shortage,
    COALESCE(lc.required_qty, 0) AS required_qty,
    COALESCE(lc.allocated_qty, 0) AS allocated_qty,
    COALESCE((
      SELECT SUM(h.on_hand_qty)::numeric
      FROM inventory_on_hand h, org
      WHERE h.organization_id = org.organization_id
    ), 0) AS on_hand_qty,
    COALESCE(lc.missing_qty, 0) AS missing_qty
  FROM mo_lines ml
  LEFT JOIN line_check lc ON lc.manufacturing_order_line_id = ml.manufacturing_order_line_id
  ORDER BY ml.manufacturing_order_line_id;
$function$;

GRANT EXECUTE ON FUNCTION public.get_mo_line_material_readiness(uuid) TO authenticated;

-- ============================================================================
-- 5) material demand view — sum(bil.qty) only (N instances already)
-- ============================================================================
CREATE OR REPLACE VIEW public.manufacturing_order_material_demand AS
WITH base AS (
  SELECT
    bi.manufacturing_order_id,
    bi.organization_id,
    bil.resolved_part_id AS catalog_item_id,
    ci.sku,
    ci.name AS item_name,
    sum(bil.qty) AS linear_qty,
    bil.uom,
    mo.manufacturing_order_no,
    mo.status AS mo_status,
    bool_or(lower(COALESCE(bil.part_role, '')) = 'fabric') AS has_fabric_role
  FROM "BOMInstanceLines" bil
  JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
  JOIN "ManufacturingOrders" mo ON mo.id = bi.manufacturing_order_id
  JOIN "ManufacturingOrderLines" mol
    ON mol.id = bi.manufacturing_order_line_id
   AND mol.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
  WHERE bi.deleted = false
    AND bil.deleted = false
    AND bil.excluded = false
    AND mo.deleted = false
    AND (mol.status = ANY (ARRAY[
      'reviewed'::text, 'confirmed'::text, 'procurement'::text,
      'material_available'::text, 'materials_ready'::text, 'in_production'::text
    ]))
  GROUP BY
    bi.manufacturing_order_id, bi.organization_id, bil.resolved_part_id,
    ci.sku, ci.name, bil.uom, mo.manufacturing_order_no, mo.status
)
SELECT
  b.manufacturing_order_id,
  b.organization_id,
  b.catalog_item_id,
  b.sku,
  b.item_name,
  CASE
    WHEN b.has_fabric_role AND fp.purchase_qty IS NOT NULL AND fp.purchase_qty > 0
      THEN fp.purchase_qty
    ELSE b.linear_qty
  END AS required_qty,
  b.uom,
  b.manufacturing_order_no,
  b.mo_status
FROM base b
LEFT JOIN "ManufacturingOrderFabricPurchase" fp
  ON fp.manufacturing_order_id = b.manufacturing_order_id
 AND fp.catalog_item_id = b.catalog_item_id;
