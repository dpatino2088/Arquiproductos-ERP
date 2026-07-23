-- When a Purchase Order is linked to a Sales Order (reference_type='sales_order'),
-- reserve the received quantities for that SO so supply-only lines can be dispatched.
-- Idempotent: never reserves more than what has been received for the SO, and never
-- more than what is physically available at the warehouse.
SET search_path = public;

CREATE OR REPLACE FUNCTION public.allocate_received_po_to_sales_order(p_po_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_po        record;
  v_so_id     uuid;
  v_wh        uuid;
  v_org       uuid;
  v_line      record;
  v_reserved  numeric;
  v_balance   numeric;
  v_res_all   numeric;
  v_available numeric;
  v_to_add    numeric;
  v_added     int := 0;
BEGIN
  SELECT id, organization_id, warehouse_id, reference_type, reference_id
    INTO v_po
  FROM public."PurchaseOrders"
  WHERE id = p_po_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'PO not found');
  END IF;

  IF v_po.reference_type <> 'sales_order' OR v_po.reference_id IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'skipped', true, 'reason', 'PO not linked to a sales order');
  END IF;

  v_so_id := v_po.reference_id;
  v_wh    := v_po.warehouse_id;
  v_org   := v_po.organization_id;

  FOR v_line IN
    SELECT pol.catalog_item_id, SUM(pol.received_qty) AS received_qty
    FROM public."PurchaseOrderLines" pol
    WHERE pol.purchase_order_id = p_po_id
      AND pol.catalog_item_id IS NOT NULL
      AND pol.received_qty > 0
    GROUP BY pol.catalog_item_id
  LOOP
    -- Already reserved to THIS sales order for this item
    SELECT COALESCE(SUM(allocated_qty), 0) INTO v_reserved
    FROM public."InventoryAllocations"
    WHERE sales_order_id = v_so_id
      AND catalog_item_id = v_line.catalog_item_id
      AND status = 'reserved';

    v_to_add := ROUND(v_line.received_qty - v_reserved, 4);
    IF v_to_add <= 0 THEN CONTINUE; END IF;

    -- Overall availability at the warehouse (balance - all reserved allocations)
    SELECT COALESCE(quantity, 0) INTO v_balance
    FROM public."InventoryBalances"
    WHERE organization_id = v_org AND warehouse_id = v_wh AND catalog_item_id = v_line.catalog_item_id;

    SELECT COALESCE(SUM(allocated_qty), 0) INTO v_res_all
    FROM public."InventoryAllocations"
    WHERE organization_id = v_org AND warehouse_id = v_wh
      AND catalog_item_id = v_line.catalog_item_id AND status = 'reserved';

    v_available := ROUND(COALESCE(v_balance, 0) - COALESCE(v_res_all, 0), 4);
    IF v_available <= 0 THEN CONTINUE; END IF;

    v_to_add := LEAST(v_to_add, v_available);
    IF v_to_add <= 0 THEN CONTINUE; END IF;

    INSERT INTO public."InventoryAllocations" (
      organization_id, warehouse_id, catalog_item_id,
      sales_order_id, allocated_qty, status, source
    ) VALUES (
      v_org, v_wh, v_line.catalog_item_id,
      v_so_id, v_to_add, 'reserved', 'auto_receipt'
    );
    v_added := v_added + 1;
  END LOOP;

  -- Reflect availability on supply-only SO lines that now have reserved stock
  UPDATE public."SaleOrderLines" sol
  SET delivery_status = 'ready', updated_at = now()
  FROM public."ProductTypes" pt
  WHERE sol.sales_order_id = v_so_id
    AND sol.deleted = false
    AND pt.code = sol.product_type AND pt.organization_id = sol.organization_id
    AND pt.fulfillment_type = 'supply_only'
    AND sol.catalog_item_id IS NOT NULL
    AND sol.delivery_status = 'pending'
    AND EXISTS (
      SELECT 1 FROM public."InventoryAllocations" ia
      WHERE ia.sales_order_id = v_so_id
        AND ia.catalog_item_id = sol.catalog_item_id
        AND ia.status = 'reserved'
    );

  RETURN jsonb_build_object('ok', true, 'allocations_created', v_added, 'sales_order_id', v_so_id);
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.allocate_received_po_to_sales_order(uuid) TO authenticated, service_role;
