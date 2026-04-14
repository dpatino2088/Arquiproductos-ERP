-- Per-line material readiness for partial manufacturing.
-- Returns one row per sales_order_line_id in the MO.

SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_mo_line_material_readiness(p_mo_id uuid)
RETURNS TABLE (
  sales_order_line_id uuid,
  readiness_status text,
  has_shortage boolean,
  required_qty numeric,
  on_hand_qty numeric,
  on_order_qty numeric,
  missing_qty numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH mo AS (
    SELECT organization_id
    FROM public."ManufacturingOrders"
    WHERE id = p_mo_id
      AND deleted = false
    LIMIT 1
  ),
  mo_lines AS (
    SELECT DISTINCT mol.sales_order_line_id
    FROM public."ManufacturingOrderLines" mol
    WHERE mol.manufacturing_order_id = p_mo_id
      AND mol.deleted = false
      AND mol.sales_order_line_id IS NOT NULL
  ),
  demand_by_item AS (
    SELECT
      bi.sales_order_line_id,
      bil.resolved_part_id AS catalog_item_id,
      SUM(COALESCE(bil.qty, 0)::numeric) AS required_qty
    FROM public."BOMInstances" bi
    JOIN public."BOMInstanceLines" bil
      ON bil.bom_instance_id = bi.id
    WHERE bi.manufacturing_order_id = p_mo_id
      AND bi.deleted = false
      AND bil.deleted = false
      AND bi.sales_order_line_id IS NOT NULL
      AND bil.resolved_part_id IS NOT NULL
    GROUP BY bi.sales_order_line_id, bil.resolved_part_id
  ),
  demand_with_stock AS (
    SELECT
      d.sales_order_line_id,
      d.catalog_item_id,
      d.required_qty,
      COALESCE((
        SELECT SUM(h.on_hand_qty)::numeric
        FROM public.inventory_on_hand h
        JOIN mo ON TRUE
        WHERE h.organization_id = mo.organization_id
          AND h.catalog_item_id = d.catalog_item_id
      ), 0::numeric) AS on_hand_qty,
      COALESCE((
        SELECT SUM(o.on_order_qty)::numeric
        FROM public.inventory_on_order o
        JOIN mo ON TRUE
        WHERE o.organization_id = mo.organization_id
          AND o.catalog_item_id = d.catalog_item_id
      ), 0::numeric) AS on_order_qty
    FROM demand_by_item d
  ),
  line_rollup AS (
    SELECT
      dws.sales_order_line_id,
      SUM(dws.required_qty) AS required_qty,
      SUM(dws.on_hand_qty) AS on_hand_qty,
      SUM(dws.on_order_qty) AS on_order_qty,
      SUM(GREATEST(0::numeric, dws.required_qty - dws.on_hand_qty - dws.on_order_qty)) AS missing_qty
    FROM demand_with_stock dws
    GROUP BY dws.sales_order_line_id
  )
  SELECT
    ml.sales_order_line_id,
    CASE
      WHEN COALESCE(lr.required_qty, 0::numeric) = 0::numeric THEN 'incomplete'
      WHEN COALESCE(lr.missing_qty, 0::numeric) > 0::numeric THEN 'incomplete'
      ELSE 'ok'
    END AS readiness_status,
    CASE
      WHEN COALESCE(lr.required_qty, 0::numeric) = 0::numeric THEN true
      WHEN COALESCE(lr.missing_qty, 0::numeric) > 0::numeric THEN true
      ELSE false
    END AS has_shortage,
    COALESCE(lr.required_qty, 0::numeric) AS required_qty,
    COALESCE(lr.on_hand_qty, 0::numeric) AS on_hand_qty,
    COALESCE(lr.on_order_qty, 0::numeric) AS on_order_qty,
    COALESCE(lr.missing_qty, 0::numeric) AS missing_qty
  FROM mo_lines ml
  LEFT JOIN line_rollup lr
    ON lr.sales_order_line_id = ml.sales_order_line_id
  ORDER BY ml.sales_order_line_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_mo_line_material_readiness(uuid) TO authenticated;;
