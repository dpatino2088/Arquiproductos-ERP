-- ============================================================================
-- Add 'excluded' flag to BOMInstanceLines for Service MOs.
-- Excluded lines are skipped during material issuance, demand calculation,
-- and readiness checks. This allows operators to selectively choose which
-- materials are needed for rework/replacement claims.
-- ============================================================================

SET search_path = public;

-- 1) Add column
ALTER TABLE public."BOMInstanceLines"
  ADD COLUMN IF NOT EXISTS excluded boolean NOT NULL DEFAULT false;

-- 2) Recreate manufacturing_order_material_demand view filtering excluded lines
CREATE OR REPLACE VIEW public.manufacturing_order_material_demand AS
SELECT
  bi.manufacturing_order_id,
  bi.organization_id,
  bil.resolved_part_id AS catalog_item_id,
  ci.sku,
  ci.name AS item_name,
  SUM(bil.qty) * mo.quantity AS required_qty,
  bil.uom,
  mo.manufacturing_order_no,
  mo.status AS mo_status
FROM "BOMInstanceLines" bil
JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
JOIN "ManufacturingOrders" mo ON mo.id = bi.manufacturing_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE bi.deleted = false
  AND bil.deleted = false
  AND bil.excluded = false
  AND mo.deleted = false
GROUP BY bi.manufacturing_order_id, bi.organization_id, bil.resolved_part_id,
         ci.sku, ci.name, bil.uom, mo.manufacturing_order_no, mo.status,
         mo.quantity;

-- 3) Update issue_materials_for_manufacturing_order to skip excluded lines
CREATE OR REPLACE FUNCTION public.issue_materials_for_manufacturing_order(p_manufacturing_order_id uuid, p_warehouse_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_mo RECORD;
  v_movement_id uuid;
  v_movement_no text;
  v_line_count integer := 0;
  v_bil RECORD;
BEGIN
  SELECT id, organization_id, status, manufacturing_order_no
  INTO v_mo
  FROM "ManufacturingOrders"
  WHERE id = p_manufacturing_order_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Manufacturing Order not found or deleted.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM "InventoryMovements"
    WHERE reference_type = 'manufacturing_order'
      AND reference_id = p_manufacturing_order_id
      AND movement_type = 'issue_to_production'
      AND status = 'confirmed'
      AND deleted = false
  ) THEN
    RETURN jsonb_build_object('ok', true, 'skipped', true, 'message', 'Materials already issued for this MO.');
  END IF;

  SELECT 'INV-' || LPAD((COALESCE(MAX(
    CASE WHEN movement_no ~ '^INV-\d+$' THEN CAST(SUBSTRING(movement_no FROM 'INV-(\d+)') AS integer) ELSE 0 END
  ), 0) + 1)::text, 6, '0')
  INTO v_movement_no
  FROM "InventoryMovements"
  WHERE organization_id = v_mo.organization_id;

  INSERT INTO "InventoryMovements" (
    organization_id, warehouse_id, movement_type, reference_type, reference_id,
    movement_no, movement_date, status, confirmed_at, notes, created_at, updated_at
  ) VALUES (
    v_mo.organization_id, p_warehouse_id, 'issue_to_production',
    'manufacturing_order', p_manufacturing_order_id,
    v_movement_no, CURRENT_DATE, 'confirmed', now(),
    'Auto-issued materials for ' || v_mo.manufacturing_order_no,
    now(), now()
  ) RETURNING id INTO v_movement_id;

  FOR v_bil IN
    SELECT bil.resolved_part_id AS catalog_item_id, SUM(bil.qty) AS total_qty, bil.uom
    FROM "BOMInstanceLines" bil
    JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
    WHERE bi.manufacturing_order_id = p_manufacturing_order_id
      AND bi.deleted = false AND bil.deleted = false
      AND bil.excluded = false
      AND bil.resolved_part_id IS NOT NULL
    GROUP BY bil.resolved_part_id, bil.uom
  LOOP
    INSERT INTO "InventoryMovementLines" (
      inventory_movement_id, catalog_item_id, quantity, unit, created_at, updated_at
    ) VALUES (
      v_movement_id, v_bil.catalog_item_id, -(v_bil.total_qty), COALESCE(v_bil.uom, 'ea'), now(), now()
    );
    v_line_count := v_line_count + 1;

    INSERT INTO "InventoryBalances" (organization_id, warehouse_id, catalog_item_id, quantity, updated_at)
    VALUES (v_mo.organization_id, p_warehouse_id, v_bil.catalog_item_id, -(v_bil.total_qty), now())
    ON CONFLICT (organization_id, warehouse_id, catalog_item_id)
    DO UPDATE SET quantity = "InventoryBalances".quantity - v_bil.total_qty, updated_at = now();
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'movement_id', v_movement_id,
    'movement_no', v_movement_no,
    'lines_count', v_line_count,
    'manufacturing_order_no', v_mo.manufacturing_order_no
  );
END;
$function$;

-- 4) Update get_mo_line_material_readiness to skip excluded lines
CREATE OR REPLACE FUNCTION public.get_mo_line_material_readiness(p_mo_id uuid)
RETURNS TABLE (
  sales_order_line_id uuid,
  readiness_status    text,
  has_shortage        boolean,
  required_qty        numeric,
  allocated_qty       numeric,
  on_hand_qty         numeric,
  missing_qty         numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
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
      SUM(COALESCE(bil.qty, 0)::numeric) AS line_required_qty
    FROM "BOMInstances" bi
    JOIN "BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
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
$$;

GRANT EXECUTE ON FUNCTION public.get_mo_line_material_readiness(uuid) TO authenticated;

-- 5) Update get_mo_line_materials_detail to skip excluded lines + return excluded flag
DROP FUNCTION IF EXISTS public.get_mo_line_materials_detail(uuid, uuid);

CREATE OR REPLACE FUNCTION public.get_mo_line_materials_detail(
  p_mo_id               uuid,
  p_sales_order_line_id uuid
)
RETURNS TABLE (
  bom_instance_line_id uuid,
  catalog_item_id      uuid,
  sku                  text,
  item_name            text,
  part_role            text,
  qty                  numeric,
  uom                  text,
  unit_cost            numeric,
  total_cost           numeric,
  on_hand_qty          numeric,
  on_order_qty         numeric,
  allocated_qty        numeric,
  missing_qty          numeric,
  readiness            text,
  excluded             boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
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
$$;

GRANT EXECUTE ON FUNCTION public.get_mo_line_materials_detail(uuid, uuid) TO authenticated;
