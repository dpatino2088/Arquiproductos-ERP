
-- ============================================================
-- Fulfillment & Allocation RPCs
-- ============================================================

-- RPC: get_so_fulfillment_status
CREATE OR REPLACE FUNCTION public.get_so_fulfillment_status(p_sales_order_id uuid)
RETURNS TABLE(
    catalog_item_id   uuid,
    sku               text,
    item_name         text,
    part_role         text,
    manufacturer_id   uuid,
    manufacturer_name text,
    required_qty      numeric,
    uom               text,
    on_hand_qty       numeric,
    allocated_qty     numeric,
    on_order_qty      numeric,
    available_qty     numeric,
    shortage          numeric,
    purchase_unit     text,
    units_per_purchase_unit numeric,
    fulfillment_status text
)
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
WITH demand AS (
    SELECT
        bil.resolved_part_id AS catalog_item_id,
        bil.part_role,
        SUM(bil.qty) AS required_qty,
        MAX(bil.uom) AS uom
    FROM public."SaleOrderLines" sol
    JOIN public."BOMInstances" bi
        ON bi.sales_order_line_id = sol.id AND bi.deleted = false
    JOIN public."BOMInstanceLines" bil
        ON bil.bom_instance_id = bi.id AND bil.deleted = false
    WHERE sol.sales_order_id = p_sales_order_id
      AND sol.deleted = false
      AND bil.resolved_part_id IS NOT NULL
    GROUP BY bil.resolved_part_id, bil.part_role
),
alloc AS (
    SELECT
        catalog_item_id,
        SUM(allocated_qty) AS allocated_qty
    FROM public."InventoryAllocations"
    WHERE sales_order_id = p_sales_order_id
      AND status = 'reserved'
    GROUP BY catalog_item_id
),
po_on_order AS (
    SELECT
        pol.catalog_item_id,
        SUM(GREATEST(pol.ordered_qty - pol.received_qty, 0)) AS on_order_qty
    FROM public."PurchaseOrders" po
    JOIN public."PurchaseOrderLines" pol ON pol.purchase_order_id = po.id
    WHERE po.reference_type = 'sales_order'
      AND po.reference_id = p_sales_order_id
      AND po.status IN ('OPEN','PARTIAL')
      AND pol.catalog_item_id IS NOT NULL
    GROUP BY pol.catalog_item_id
),
inv AS (
    SELECT
        h.catalog_item_id,
        SUM(h.on_hand_qty) AS on_hand_qty
    FROM public.inventory_on_hand h
    WHERE h.organization_id = (
        SELECT organization_id FROM public."SalesOrders" WHERE id = p_sales_order_id LIMIT 1
    )
    GROUP BY h.catalog_item_id
)
SELECT
    d.catalog_item_id,
    COALESCE(ci.sku, '') AS sku,
    COALESCE(ci.name, '') AS item_name,
    d.part_role,
    ci.manufacturer_id,
    COALESCE(mfr.name, '') AS manufacturer_name,
    d.required_qty,
    d.uom,
    COALESCE(i.on_hand_qty, 0) AS on_hand_qty,
    COALESCE(a.allocated_qty, 0) AS allocated_qty,
    COALESCE(po.on_order_qty, 0) AS on_order_qty,
    GREATEST(COALESCE(i.on_hand_qty, 0) - COALESCE(a.allocated_qty, 0), 0) AS available_qty,
    GREATEST(d.required_qty - COALESCE(a.allocated_qty, 0) - COALESCE(po.on_order_qty, 0), 0) AS shortage,
    COALESCE(ci.purchase_unit::text, 'each') AS purchase_unit,
    COALESCE(ci.units_per_purchase_unit, 1) AS units_per_purchase_unit,
    CASE
        WHEN COALESCE(a.allocated_qty, 0) >= d.required_qty THEN 'fulfilled'
        WHEN COALESCE(a.allocated_qty, 0) + COALESCE(po.on_order_qty, 0) >= d.required_qty THEN 'partial'
        ELSE 'shortage'
    END AS fulfillment_status
FROM demand d
LEFT JOIN public."CatalogItems" ci ON ci.id = d.catalog_item_id
LEFT JOIN public."Manufacturers" mfr ON mfr.id = ci.manufacturer_id
LEFT JOIN alloc a ON a.catalog_item_id = d.catalog_item_id
LEFT JOIN po_on_order po ON po.catalog_item_id = d.catalog_item_id
LEFT JOIN inv i ON i.catalog_item_id = d.catalog_item_id
ORDER BY
    CASE
        WHEN COALESCE(a.allocated_qty, 0) >= d.required_qty THEN 3
        WHEN COALESCE(a.allocated_qty, 0) + COALESCE(po.on_order_qty, 0) >= d.required_qty THEN 2
        ELSE 1
    END,
    COALESCE(mfr.name, 'ZZZ'),
    ci.sku;
$$;

ALTER FUNCTION public.get_so_fulfillment_status(uuid) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.get_so_fulfillment_status(uuid) TO authenticated;

-- RPC: allocate_inventory_to_so
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
        v_qty    := (v_item ->> 'qty')::numeric;

        IF v_qty IS NULL OR v_qty <= 0 THEN
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
            IF v_avail > 0 THEN
                v_qty := v_avail;
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

    RETURN jsonb_build_object('ok', true, 'results', v_results);
END;
$$;

ALTER FUNCTION public.allocate_inventory_to_so(uuid, uuid, uuid, jsonb) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.allocate_inventory_to_so(uuid, uuid, uuid, jsonb) TO authenticated;

-- RPC: release_allocation
CREATE OR REPLACE FUNCTION public.release_allocation(p_allocation_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
    UPDATE public."InventoryAllocations"
    SET status = 'released', released_at = now(), updated_at = now()
    WHERE id = p_allocation_id AND status = 'reserved';

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'error', 'Allocation not found or already released/issued');
    END IF;

    RETURN jsonb_build_object('ok', true);
END;
$$;

ALTER FUNCTION public.release_allocation(uuid) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.release_allocation(uuid) TO authenticated;

-- RPC: issue_allocated_materials
CREATE OR REPLACE FUNCTION public.issue_allocated_materials(p_sales_order_id uuid, p_warehouse_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_count int;
BEGIN
    UPDATE public."InventoryAllocations"
    SET status = 'issued', issued_at = now(), updated_at = now()
    WHERE sales_order_id = p_sales_order_id
      AND warehouse_id   = p_warehouse_id
      AND status = 'reserved';

    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN jsonb_build_object('ok', true, 'issued_count', v_count);
END;
$$;

ALTER FUNCTION public.issue_allocated_materials(uuid, uuid) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.issue_allocated_materials(uuid, uuid) TO authenticated;
;
