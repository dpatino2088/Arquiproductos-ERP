-- Lines with no materializable BOM (e.g. catalog accessories without BOMInstance)
-- were treated as shortage because required_qty = 0. That made whole MOs show
-- "Shortage" even when every real SKU was fully allocated (incl. after sol.qty scale).
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
      -- No BOM materials on this line (supply/accessory without instance): not a shortage.
      WHEN lc.required_qty IS NULL OR lc.required_qty = 0 THEN 'ok'
      WHEN lc.all_covered THEN 'ok'
      ELSE 'incomplete'
    END AS readiness_status,
    CASE
      WHEN lc.required_qty IS NULL OR lc.required_qty = 0 THEN false
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
