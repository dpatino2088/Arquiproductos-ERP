-- Deliveries queue: expose supply_only lines that are ready/allocated even when
-- the SO still has manufacture lines pending (Partial delivery).
-- SECURITY DEFINER so portal + org users can resolve fulfillment_type via ProductTypes.

SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_deliveries_supply_ready_lines(p_org_id uuid)
RETURNS TABLE (
  line_id uuid,
  sales_order_id uuid,
  sales_order_no text,
  dealer_id uuid,
  dealer_name text,
  customer_id uuid,
  customer_name text,
  description text,
  product_type text,
  area text,
  "position" text,
  catalog_item_id uuid,
  catalog_item_name text,
  catalog_item_sku text,
  quantity numeric,
  delivery_status text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    sol.id AS line_id,
    sol.sales_order_id,
    so.sales_order_no,
    so.dealer_id,
    d.dealer_name,
    so.customer_id,
    dc.customer_name,
    sol.description,
    sol.product_type,
    sol.area,
    sol."position",
    sol.catalog_item_id,
    ci.name AS catalog_item_name,
    ci.sku AS catalog_item_sku,
    sol.quantity,
    sol.delivery_status
  FROM public."SaleOrderLines" sol
  JOIN public."SalesOrders" so
    ON so.id = sol.sales_order_id
   AND COALESCE(so.deleted, false) = false
  JOIN public."ProductTypes" pt
    ON pt.code = sol.product_type
   AND pt.organization_id = sol.organization_id
   AND pt.fulfillment_type = 'supply_only'
  LEFT JOIN public."Dealers" d ON d.id = so.dealer_id
  LEFT JOIN public."DirectoryCustomers" dc ON dc.id = so.customer_id
  LEFT JOIN public."CatalogItems" ci ON ci.id = sol.catalog_item_id
  WHERE sol.organization_id = p_org_id
    AND COALESCE(sol.deleted, false) = false
    AND sol.catalog_item_id IS NOT NULL
    AND sol.delivery_status IN ('ready', 'delivered')
    AND (
      public.is_org_user_member(p_org_id)
      OR public.is_portal_user_in_org(p_org_id)
    )
    AND (
      -- Internal org users see all dealers (acting-as is UI-side for inventory)
      public.is_internal_org_user(p_org_id)
      OR so.dealer_id = ANY (public.current_user_dealer_ids(p_org_id))
    );
$$;

GRANT EXECUTE ON FUNCTION public.get_deliveries_supply_ready_lines(uuid) TO authenticated;

-- Progress for Partial / Ready / Delivered badges (manufacture MOL + supply SOL)
CREATE OR REPLACE FUNCTION public.get_so_deliverable_progress(p_org_id uuid, p_so_ids uuid[])
RETURNS TABLE (
  sales_order_id uuid,
  total_count integer,
  ready_count integer,
  delivered_count integer,
  pending_count integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH supply_codes AS (
    SELECT pt.code
    FROM public."ProductTypes" pt
    WHERE pt.organization_id = p_org_id
      AND pt.fulfillment_type = 'supply_only'
  ),
  mol AS (
    SELECT
      mo.sales_order_id,
      mol.delivery_status
    FROM public."ManufacturingOrderLines" mol
    JOIN public."ManufacturingOrders" mo ON mo.id = mol.manufacturing_order_id
    JOIN public."SaleOrderLines" sol ON sol.id = mol.sales_order_line_id
    WHERE mo.organization_id = p_org_id
      AND mo.deleted = false
      AND mol.deleted = false
      AND mo.sales_order_id = ANY (p_so_ids)
      AND COALESCE(sol.product_type, '') NOT IN (SELECT code FROM supply_codes)
  ),
  supply AS (
    SELECT
      sol.sales_order_id,
      sol.delivery_status
    FROM public."SaleOrderLines" sol
    WHERE sol.organization_id = p_org_id
      AND COALESCE(sol.deleted, false) = false
      AND sol.sales_order_id = ANY (p_so_ids)
      AND sol.catalog_item_id IS NOT NULL
      AND sol.product_type IN (SELECT code FROM supply_codes)
  ),
  all_lines AS (
    SELECT * FROM mol
    UNION ALL
    SELECT * FROM supply
  )
  SELECT
    al.sales_order_id,
    COUNT(*)::integer AS total_count,
    COUNT(*) FILTER (WHERE al.delivery_status = 'ready')::integer AS ready_count,
    COUNT(*) FILTER (WHERE al.delivery_status = 'delivered')::integer AS delivered_count,
    COUNT(*) FILTER (WHERE COALESCE(al.delivery_status, 'pending') NOT IN ('ready', 'delivered'))::integer AS pending_count
  FROM all_lines al
  GROUP BY al.sales_order_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_so_deliverable_progress(uuid, uuid[]) TO authenticated;
