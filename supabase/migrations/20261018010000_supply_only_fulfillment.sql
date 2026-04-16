-- Supply-Only Fulfillment: schema changes + views + RPC updates
-- Enables direct SO → DN flow for catalog items and window film

-- 1. DeliveryNoteLines: make mo_line_id nullable, add sale_order_line_id and line_type
ALTER TABLE public."DeliveryNoteLines"
  ALTER COLUMN mo_line_id DROP NOT NULL;

ALTER TABLE public."DeliveryNoteLines"
  ADD COLUMN IF NOT EXISTS sale_order_line_id uuid REFERENCES public."SaleOrderLines"(id),
  ADD COLUMN IF NOT EXISTS line_type text NOT NULL DEFAULT 'product';

DO $$ BEGIN
  ALTER TABLE public."DeliveryNoteLines"
    ADD CONSTRAINT chk_dnl_line_type CHECK (line_type IN ('product', 'supply', 'accessory'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public."DeliveryNoteLines"
    ADD CONSTRAINT chk_dnl_has_source CHECK (mo_line_id IS NOT NULL OR sale_order_line_id IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2. SaleOrderLines: add delivery_status for supply-only tracking
ALTER TABLE public."SaleOrderLines"
  ADD COLUMN IF NOT EXISTS delivery_status text NOT NULL DEFAULT 'pending';

DO $$ BEGIN
  ALTER TABLE public."SaleOrderLines"
    ADD CONSTRAINT chk_sol_delivery_status CHECK (delivery_status IN ('pending', 'ready', 'delivered'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3. Supply order material demand view
CREATE OR REPLACE VIEW public.supply_order_material_demand AS
SELECT
  sol.sales_order_id,
  sol.organization_id,
  sol.catalog_item_id,
  ci.sku,
  ci.name AS item_name,
  SUM(sol.quantity) AS required_qty,
  'ea' AS uom,
  so.sales_order_no,
  so.status AS so_status
FROM public."SaleOrderLines" sol
JOIN public."SalesOrders" so ON so.id = sol.sales_order_id
JOIN public."ProductTypes" pt ON pt.code = sol.product_type AND pt.organization_id = sol.organization_id
LEFT JOIN public."CatalogItems" ci ON ci.id = sol.catalog_item_id
WHERE sol.deleted = false
  AND so.deleted = false
  AND pt.fulfillment_type = 'supply_only'
  AND sol.catalog_item_id IS NOT NULL
GROUP BY sol.sales_order_id, sol.organization_id, sol.catalog_item_id,
         ci.sku, ci.name, so.sales_order_no, so.status;

-- 4. Update get_so_fulfillment_status to include supply-only demand
CREATE OR REPLACE FUNCTION public.get_so_fulfillment_status(p_sales_order_id uuid)
RETURNS TABLE(
  catalog_item_id uuid,
  sku text,
  item_name text,
  part_role text,
  manufacturer_id uuid,
  manufacturer_name text,
  required_qty numeric,
  uom text,
  on_hand_qty numeric,
  allocated_qty numeric,
  on_order_qty numeric,
  available_qty numeric,
  shortage numeric,
  purchase_unit text,
  units_per_purchase_unit numeric,
  fulfillment_status text
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
WITH bom_demand AS (
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
supply_demand AS (
    SELECT
        sol.catalog_item_id,
        'supply' AS part_role,
        SUM(sol.quantity) AS required_qty,
        'ea' AS uom
    FROM public."SaleOrderLines" sol
    JOIN public."ProductTypes" pt ON pt.code = sol.product_type
        AND pt.organization_id = sol.organization_id
    WHERE sol.sales_order_id = p_sales_order_id
      AND sol.deleted = false
      AND pt.fulfillment_type = 'supply_only'
      AND sol.catalog_item_id IS NOT NULL
    GROUP BY sol.catalog_item_id
),
demand AS (
    SELECT catalog_item_id, part_role, required_qty, uom FROM bom_demand
    UNION ALL
    SELECT catalog_item_id, part_role, required_qty, uom FROM supply_demand
),
alloc AS (
    SELECT
        ia.catalog_item_id,
        SUM(ia.allocated_qty) AS allocated_qty
    FROM public."InventoryAllocations" ia
    WHERE ia.sales_order_id = p_sales_order_id
      AND ia.status = 'reserved'
    GROUP BY ia.catalog_item_id
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

-- 5. Update complete_delivery_note to handle supply lines
CREATE OR REPLACE FUNCTION public.complete_delivery_note(p_delivery_note_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE
  v_dn        record;
  v_total     integer;
  v_checked   integer;
  v_mo_id     uuid;
  v_new_dn_status text;
  v_all_mol_delivered boolean;
  v_so_id     uuid;
  v_all_mo_delivered boolean;
  v_all_supply_delivered boolean;
  v_org_id    uuid;
  v_mo_no     text;
  v_gate      record;
  v_claim_id  uuid;
  v_claim_chargeable boolean;
BEGIN
  SELECT * INTO v_dn FROM public."DeliveryNotes"
  WHERE id = p_delivery_note_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Delivery note not found');
  END IF;

  v_mo_id := v_dn.manufacturing_order_id;
  v_org_id := v_dn.organization_id;
  v_so_id := v_dn.sales_order_id;

  IF v_mo_id IS NOT NULL THEN
    SELECT manufacturing_order_no, sales_order_id, claim_id
    INTO v_mo_no, v_so_id, v_claim_id
    FROM public."ManufacturingOrders"
    WHERE id = v_mo_id;
  ELSIF v_so_id IS NOT NULL THEN
    SELECT id INTO v_mo_id
    FROM public."ManufacturingOrders"
    WHERE sales_order_id = v_so_id AND deleted = false
      AND status IN ('ready_for_pickup', 'delivered')
    ORDER BY created_at DESC LIMIT 1;
    IF v_mo_id IS NOT NULL THEN
      SELECT manufacturing_order_no, claim_id
      INTO v_mo_no, v_claim_id
      FROM public."ManufacturingOrders"
      WHERE id = v_mo_id;
    END IF;
  END IF;

  -- Delivery gate
  IF v_claim_id IS NOT NULL THEN
    SELECT COALESCE(sc.chargeable, false) INTO v_claim_chargeable
    FROM public."ServiceClaims" sc WHERE sc.id = v_claim_id AND sc.deleted = false;
    IF v_claim_chargeable THEN
      IF NOT EXISTS (
        SELECT 1 FROM public."DealerInvoices" di
        WHERE di.claim_id = v_claim_id AND di.deleted = false
          AND di.status = 'paid'
      ) THEN
        RETURN jsonb_build_object(
          'ok', false,
          'error', 'Delivery blocked: claim invoice is not fully paid.'
        );
      END IF;
    END IF;
  ELSIF v_so_id IS NOT NULL THEN
    SELECT * INTO v_gate
    FROM public.get_sales_order_delivery_gate(v_so_id);

    IF NOT COALESCE(v_gate.delivery_allowed, false) THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', format('Delivery blocked: balance due is $%s. Financials must settle to 0.00 or issue override.', to_char(COALESCE(v_gate.balance_due, 0), 'FM999999990.00')),
        'balance_due', COALESCE(v_gate.balance_due, 0)
      );
    END IF;
  END IF;

  SELECT count(*), count(*) FILTER (WHERE checked = true)
  INTO v_total, v_checked
  FROM public."DeliveryNoteLines"
  WHERE delivery_note_id = p_delivery_note_id;

  IF v_total = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'No lines in delivery note');
  END IF;

  IF v_checked = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'No lines checked for delivery');
  END IF;

  v_new_dn_status := CASE WHEN v_checked >= v_total THEN 'completed' ELSE 'partial' END;

  UPDATE public."DeliveryNotes"
  SET status = v_new_dn_status,
      completed_at = CASE WHEN v_new_dn_status = 'completed' THEN now() ELSE completed_at END,
      updated_at = now()
  WHERE id = p_delivery_note_id;

  -- Mark MO-backed lines as delivered
  UPDATE public."ManufacturingOrderLines" mol
  SET delivery_status = 'delivered',
      delivered_at = now(),
      delivered_qty = mol.quantity,
      updated_at = now()
  FROM public."DeliveryNoteLines" dnl
  WHERE dnl.delivery_note_id = p_delivery_note_id
    AND dnl.mo_line_id IS NOT NULL
    AND dnl.mo_line_id = mol.id
    AND dnl.checked = true;

  -- Mark supply lines as delivered on SaleOrderLines
  UPDATE public."SaleOrderLines" sol
  SET delivery_status = 'delivered',
      updated_at = now()
  FROM public."DeliveryNoteLines" dnl
  WHERE dnl.delivery_note_id = p_delivery_note_id
    AND dnl.sale_order_line_id IS NOT NULL
    AND dnl.sale_order_line_id = sol.id
    AND dnl.checked = true;

  -- Check MO delivery completeness
  IF v_mo_id IS NOT NULL THEN
    SELECT NOT EXISTS (
      SELECT 1 FROM public."ManufacturingOrderLines"
      WHERE manufacturing_order_id = v_mo_id
        AND deleted = false
        AND delivery_status <> 'delivered'
    ) INTO v_all_mol_delivered;

    IF v_all_mol_delivered THEN
      UPDATE public."ManufacturingOrders"
      SET status = 'delivered', delivered_at = now(), updated_at = now()
      WHERE id = v_mo_id AND status <> 'delivered';
    END IF;

    INSERT INTO public."ActivityTimeline" (
      entity_type, entity_id, action, description, user_name, organization_id
    ) VALUES (
      'manufacturing_order', v_mo_id,
      CASE WHEN v_new_dn_status = 'completed' THEN 'delivery_completed' ELSE 'delivery_partial' END,
      format('%s: %s/%s lines delivered%s',
        v_dn.delivery_number, v_checked, v_total,
        CASE WHEN v_dn.received_by_name IS NOT NULL
          THEN format(' — received by %s', v_dn.received_by_name) ELSE '' END
      ),
      COALESCE(v_dn.delivered_by_name, 'System'),
      v_org_id
    );

    IF v_all_mol_delivered THEN
      INSERT INTO public."ActivityTimeline" (
        entity_type, entity_id, action, description, user_name, organization_id
      ) VALUES (
        'manufacturing_order', v_mo_id,
        'status_change',
        'Manufacturing order marked as Delivered — all lines delivered',
        COALESCE(v_dn.delivered_by_name, 'System'),
        v_org_id
      );
    END IF;
  END IF;

  -- Check SO delivery completeness (MOs + supply lines)
  IF v_so_id IS NOT NULL THEN
    SELECT NOT EXISTS (
      SELECT 1 FROM public."ManufacturingOrders"
      WHERE sales_order_id = v_so_id
        AND deleted = false
        AND status <> 'delivered'
        AND status <> 'cancelled'
    ) INTO v_all_mo_delivered;

    SELECT NOT EXISTS (
      SELECT 1 FROM public."SaleOrderLines" sol
      JOIN public."ProductTypes" pt ON pt.code = sol.product_type AND pt.organization_id = sol.organization_id
      WHERE sol.sales_order_id = v_so_id
        AND sol.deleted = false
        AND pt.fulfillment_type = 'supply_only'
        AND sol.delivery_status <> 'delivered'
    ) INTO v_all_supply_delivered;

    IF COALESCE(v_all_mo_delivered, true) AND COALESCE(v_all_supply_delivered, true) THEN
      UPDATE public."SalesOrders"
      SET status = 'delivered', updated_at = now()
      WHERE id = v_so_id AND status <> 'delivered';

      IF v_gate IS NOT NULL
         AND COALESCE(v_gate.payment_complete, false) = false
         AND v_gate.active_override_id IS NOT NULL THEN
        UPDATE public."SalesOrderDeliveryOverrides"
        SET status = 'used',
            used_by = v_dn.delivered_by_user_id,
            used_by_name = COALESCE(v_dn.delivered_by_name, 'System'),
            used_source = 'delivery_note',
            used_delivery_note_id = p_delivery_note_id,
            used_at = now(),
            updated_at = now()
        WHERE id = v_gate.active_override_id
          AND status = 'active'
          AND deleted = false;
      END IF;

      INSERT INTO public."ActivityTimeline" (
        entity_type, entity_id, action, description, user_name, organization_id
      ) VALUES (
        'sales_order', v_so_id,
        'status_change',
        'Sales order delivered — all lines delivered',
        'System (auto)',
        v_org_id
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'delivery_note_status', v_new_dn_status,
    'checked_count', v_checked,
    'total_count', v_total,
    'mo_delivered', COALESCE(v_all_mol_delivered, false)
  );
END;
$fn$;
