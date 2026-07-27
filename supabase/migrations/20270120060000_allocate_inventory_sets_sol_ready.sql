-- When stock is reserved to a sales order (manual Reserve stock), mark covered
-- supply_only SaleOrderLines as delivery_status='ready' so they appear in Deliveries.
-- Mirrors allocate_received_po_to_sales_order, and requires reserved qty >= line qty.

CREATE OR REPLACE FUNCTION public.allocate_inventory_to_so(
    p_org_id          uuid,
    p_warehouse_id    uuid,
    p_sales_order_id  uuid,
    p_items           jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_item     jsonb;
    v_cat_id   uuid;
    v_qty      numeric;
    v_avail    numeric;
    v_alloc    numeric;
    v_results  jsonb := '[]'::jsonb;
BEGIN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_cat_id := (v_item ->> 'catalog_item_id')::uuid;
        v_qty    := ROUND((v_item ->> 'qty')::numeric, 4);

        IF v_qty IS NULL OR v_qty < 0.0001 THEN
            v_results := v_results || jsonb_build_object(
                'catalog_item_id', v_cat_id, 'ok', false, 'error', 'Invalid qty'
            );
            CONTINUE;
        END IF;

        SELECT COALESCE(SUM(ib.quantity), 0) INTO v_avail
        FROM public."InventoryBalances" ib
        WHERE ib.organization_id = p_org_id
          AND ib.warehouse_id    = p_warehouse_id
          AND ib.catalog_item_id = v_cat_id;

        SELECT COALESCE(SUM(ia.allocated_qty), 0) INTO v_alloc
        FROM public."InventoryAllocations" ia
        WHERE ia.organization_id = p_org_id
          AND ia.warehouse_id    = p_warehouse_id
          AND ia.catalog_item_id = v_cat_id
          AND ia.status = 'reserved';

        v_avail := v_avail - v_alloc;

        IF v_avail < v_qty THEN
            IF v_avail >= 0.0001 THEN
                v_qty := ROUND(v_avail, 4);
            ELSE
                v_results := v_results || jsonb_build_object(
                    'catalog_item_id', v_cat_id, 'ok', false, 'error', 'No available stock'
                );
                CONTINUE;
            END IF;
        END IF;

        INSERT INTO public."InventoryAllocations" (
            organization_id, warehouse_id, catalog_item_id,
            sales_order_id, allocated_qty, status, source
        ) VALUES (
            p_org_id, p_warehouse_id, v_cat_id,
            p_sales_order_id, v_qty, 'reserved', 'manual'
        );

        v_results := v_results || jsonb_build_object(
            'catalog_item_id', v_cat_id, 'ok', true, 'allocated_qty', v_qty
        );
    END LOOP;

    -- Supply lines fully covered by reserved stock → ready for Deliveries
    UPDATE public."SaleOrderLines" sol
    SET delivery_status = 'ready', updated_at = now()
    FROM public."ProductTypes" pt
    WHERE sol.sales_order_id = p_sales_order_id
      AND sol.deleted = false
      AND pt.code = sol.product_type AND pt.organization_id = sol.organization_id
      AND pt.fulfillment_type = 'supply_only'
      AND sol.catalog_item_id IS NOT NULL
      AND sol.delivery_status = 'pending'
      AND COALESCE((
        SELECT SUM(ia.allocated_qty)
        FROM public."InventoryAllocations" ia
        WHERE ia.sales_order_id = p_sales_order_id
          AND ia.catalog_item_id = sol.catalog_item_id
          AND ia.status = 'reserved'
      ), 0) >= sol.quantity - 0.0001;

    RETURN jsonb_build_object('ok', true, 'results', v_results);
END;
$$;

ALTER FUNCTION public.allocate_inventory_to_so(uuid, uuid, uuid, jsonb) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.allocate_inventory_to_so(uuid, uuid, uuid, jsonb) TO authenticated;

-- Backfill: supply lines already reserved enough but still pending
UPDATE public."SaleOrderLines" sol
SET delivery_status = 'ready', updated_at = now()
FROM public."ProductTypes" pt
WHERE sol.deleted = false
  AND pt.code = sol.product_type AND pt.organization_id = sol.organization_id
  AND pt.fulfillment_type = 'supply_only'
  AND sol.catalog_item_id IS NOT NULL
  AND sol.delivery_status = 'pending'
  AND COALESCE((
    SELECT SUM(ia.allocated_qty)
    FROM public."InventoryAllocations" ia
    WHERE ia.sales_order_id = sol.sales_order_id
      AND ia.catalog_item_id = sol.catalog_item_id
      AND ia.status = 'reserved'
  ), 0) >= sol.quantity - 0.0001;
