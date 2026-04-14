-- ============================================================================
-- SO Accessories & SO-Level Delivery Notes
-- ============================================================================
-- 1. Create SaleOrderAccessories table (accessories at SO level, no MO)
-- 2. Add sales_order_id to DeliveryNotes, make manufacturing_order_id nullable
-- 3. Add bom_instance_line_id + line_type to DeliveryNoteLines
-- 4. Rewrite complete_delivery_note for SO-level delivery
-- 5. Update finished_goods_stock view to include accessories
-- ============================================================================

SET search_path = public;

-- ────────────────────────────────────────────────────────────
-- 1. SaleOrderAccessories
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public."SaleOrderAccessories" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  sales_order_id uuid NOT NULL REFERENCES public."SalesOrders"(id),
  catalog_item_id uuid NOT NULL REFERENCES public."CatalogItems"(id),
  qty numeric(12,4) NOT NULL DEFAULT 1,
  unit_cost_exw numeric(14,4),
  unit_price numeric(14,4),
  line_total numeric(14,4),
  delivery_status text NOT NULL DEFAULT 'pending',
  delivered_qty numeric(12,4) NOT NULL DEFAULT 0,
  delivered_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_so_accessories_org
  ON public."SaleOrderAccessories"(organization_id);
CREATE INDEX IF NOT EXISTS idx_so_accessories_so
  ON public."SaleOrderAccessories"(sales_order_id);
CREATE INDEX IF NOT EXISTS idx_so_accessories_catalog
  ON public."SaleOrderAccessories"(catalog_item_id);

ALTER TABLE public."SaleOrderAccessories" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "so_accessories_org_access" ON public."SaleOrderAccessories";
CREATE POLICY "so_accessories_org_access" ON public."SaleOrderAccessories"
  FOR ALL USING (
    organization_id IN (
      SELECT organization_id FROM public."AppUsers"
      WHERE auth_user_id = auth.uid()
        AND deleted = false
        AND status = 'active'
    )
  );

-- ────────────────────────────────────────────────────────────
-- 2. DeliveryNotes: add sales_order_id, make manufacturing_order_id nullable
-- ────────────────────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'DeliveryNotes'
      AND column_name = 'sales_order_id'
  ) THEN
    ALTER TABLE public."DeliveryNotes"
      ADD COLUMN sales_order_id uuid REFERENCES public."SalesOrders"(id);
  END IF;
END $$;

-- Backfill sales_order_id from existing DeliveryNotes → MO → SO
UPDATE public."DeliveryNotes" dn
SET sales_order_id = mo.sales_order_id
FROM public."ManufacturingOrders" mo
WHERE dn.manufacturing_order_id = mo.id
  AND dn.sales_order_id IS NULL
  AND mo.sales_order_id IS NOT NULL;

-- Make manufacturing_order_id nullable (DN can now be SO-level)
ALTER TABLE public."DeliveryNotes"
  ALTER COLUMN manufacturing_order_id DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_delivery_notes_so
  ON public."DeliveryNotes"(sales_order_id);

-- ────────────────────────────────────────────────────────────
-- 3. DeliveryNoteLines: add so_accessory_id + line_type, make mo_line_id nullable
-- ────────────────────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'DeliveryNoteLines'
      AND column_name = 'so_accessory_id'
  ) THEN
    ALTER TABLE public."DeliveryNoteLines"
      ADD COLUMN so_accessory_id uuid REFERENCES public."SaleOrderAccessories"(id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'DeliveryNoteLines'
      AND column_name = 'line_type'
  ) THEN
    ALTER TABLE public."DeliveryNoteLines"
      ADD COLUMN line_type text NOT NULL DEFAULT 'product';
  END IF;
END $$;

-- Make mo_line_id nullable (accessory lines don't have an MOLine)
ALTER TABLE public."DeliveryNoteLines"
  ALTER COLUMN mo_line_id DROP NOT NULL;

-- Constraint: must reference either mo_line_id or so_accessory_id
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'dnl_product_or_accessory'
  ) THEN
    ALTER TABLE public."DeliveryNoteLines"
      ADD CONSTRAINT dnl_product_or_accessory
      CHECK (mo_line_id IS NOT NULL OR so_accessory_id IS NOT NULL);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_dnl_so_accessory
  ON public."DeliveryNoteLines"(so_accessory_id);

-- ────────────────────────────────────────────────────────────
-- 4. Rewrite complete_delivery_note for SO-level delivery
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.complete_delivery_note(p_delivery_note_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
  v_dn        record;
  v_total     integer;
  v_checked   integer;
  v_new_dn_status text;
  v_so_id     uuid;
  v_org_id    uuid;
  v_gate      record;
  v_all_mo_delivered boolean;
BEGIN
  SELECT * INTO v_dn FROM public."DeliveryNotes"
  WHERE id = p_delivery_note_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Delivery note not found');
  END IF;

  v_so_id  := v_dn.sales_order_id;
  v_org_id := v_dn.organization_id;

  -- Payment gate check (at SO level)
  IF v_so_id IS NOT NULL THEN
    SELECT * INTO v_gate
    FROM public.get_sales_order_delivery_gate(v_so_id);

    IF NOT COALESCE(v_gate.delivery_allowed, false) THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', format('Delivery blocked: balance due is $%s. Financials must settle to 0.00 or issue override.',
                        to_char(COALESCE(v_gate.balance_due, 0), 'FM999999990.00')),
        'balance_due', COALESCE(v_gate.balance_due, 0)
      );
    END IF;
  END IF;

  -- Count checked lines
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

  -- Update DN status
  UPDATE public."DeliveryNotes"
  SET status = v_new_dn_status,
      completed_at = CASE WHEN v_new_dn_status = 'completed' THEN now() ELSE completed_at END,
      updated_at = now()
  WHERE id = p_delivery_note_id;

  -- ── Product lines (MOLines) ──
  UPDATE public."ManufacturingOrderLines" mol
  SET delivery_status = 'delivered',
      delivered_at = now(),
      delivered_qty = mol.quantity,
      updated_at = now()
  FROM public."DeliveryNoteLines" dnl
  WHERE dnl.delivery_note_id = p_delivery_note_id
    AND dnl.mo_line_id = mol.id
    AND dnl.line_type = 'product'
    AND dnl.checked = true;

  -- ── Accessory lines (SaleOrderAccessories) ──
  UPDATE public."SaleOrderAccessories" soa
  SET delivery_status = 'delivered',
      delivered_at = now(),
      delivered_qty = soa.qty,
      updated_at = now()
  FROM public."DeliveryNoteLines" dnl
  WHERE dnl.delivery_note_id = p_delivery_note_id
    AND dnl.so_accessory_id = soa.id
    AND dnl.line_type = 'accessory'
    AND dnl.checked = true;

  -- ── Auto-advance MOs where all MOLines are delivered ──
  IF v_so_id IS NOT NULL THEN
    -- For each MO in this SO, check if all its lines are delivered
    UPDATE public."ManufacturingOrders" mo
    SET status = 'delivered', delivered_at = now(), updated_at = now()
    WHERE mo.sales_order_id = v_so_id
      AND mo.deleted = false
      AND mo.status = 'ready_for_pickup'
      AND NOT EXISTS (
        SELECT 1 FROM public."ManufacturingOrderLines" mol2
        WHERE mol2.manufacturing_order_id = mo.id
          AND mol2.deleted = false
          AND mol2.delivery_status <> 'delivered'
      );

    -- Check if ALL MOs for this SO are now delivered (or cancelled)
    SELECT NOT EXISTS (
      SELECT 1 FROM public."ManufacturingOrders"
      WHERE sales_order_id = v_so_id
        AND deleted = false
        AND status NOT IN ('delivered', 'completed', 'cancelled')
    ) INTO v_all_mo_delivered;

    -- Also check if ALL accessories are delivered
    IF v_all_mo_delivered THEN
      SELECT NOT EXISTS (
        SELECT 1 FROM public."SaleOrderAccessories"
        WHERE sales_order_id = v_so_id
          AND deleted = false
          AND delivery_status <> 'delivered'
      ) INTO v_all_mo_delivered;
    END IF;

    IF v_all_mo_delivered THEN
      UPDATE public."SalesOrders"
      SET status = 'Delivered', updated_at = now()
      WHERE id = v_so_id AND status <> 'Delivered';
    END IF;

    -- Consume delivery override if used
    IF COALESCE(v_gate.payment_complete, false) = false
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
  END IF;

  -- ── Timeline ──
  IF v_so_id IS NOT NULL THEN
    INSERT INTO public."ActivityTimeline" (
      entity_type, entity_id, action, description, user_name, organization_id
    ) VALUES (
      'sales_order', v_so_id,
      CASE WHEN v_new_dn_status = 'completed' THEN 'delivery_completed' ELSE 'delivery_partial' END,
      format('%s: %s/%s lines delivered%s',
        v_dn.delivery_number, v_checked, v_total,
        CASE WHEN v_dn.received_by_name IS NOT NULL
          THEN format(' — received by %s', v_dn.received_by_name) ELSE '' END
      ),
      COALESCE(v_dn.delivered_by_name, 'System'),
      v_org_id
    );
  END IF;

  IF v_all_mo_delivered AND v_so_id IS NOT NULL THEN
    INSERT INTO public."ActivityTimeline" (
      entity_type, entity_id, action, description, user_name, organization_id
    ) VALUES (
      'sales_order', v_so_id,
      'status_change',
      'Sales order delivered — all products and accessories delivered',
      'System (auto)',
      v_org_id
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'delivery_note_status', v_new_dn_status,
    'checked_count', v_checked,
    'total_count', v_total,
    'all_delivered', COALESCE(v_all_mo_delivered, false)
  );
END;
$fn$;

-- ────────────────────────────────────────────────────────────
-- 5. View: finished_goods_by_so
--    Groups products + accessories at SO level for delivery UI
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.finished_goods_by_so AS
-- Product lines from MOs
SELECT
  'product' AS line_type,
  mol.id AS line_id,
  mo.sales_order_id,
  mo.id AS manufacturing_order_id,
  mo.manufacturing_order_no,
  mo.status AS mo_status,
  mo.organization_id,
  mol.delivery_status,
  mol.quantity,
  mol.delivered_qty,
  mol.delivered_at,
  so.sales_order_no,
  d.dealer_name,
  dc.customer_name,
  sol.description AS line_description,
  sol.product_type,
  sol.area,
  sol.position,
  ci.name AS catalog_item_name,
  ci.sku AS catalog_item_sku,
  mo.released_at
FROM public."ManufacturingOrderLines" mol
JOIN public."ManufacturingOrders" mo ON mo.id = mol.manufacturing_order_id
LEFT JOIN public."SalesOrders" so ON so.id = mo.sales_order_id
LEFT JOIN public."Dealers" d ON d.id = so.dealer_id
LEFT JOIN public."DirectoryCustomers" dc ON dc.id = so.customer_id
LEFT JOIN public."SaleOrderLines" sol ON sol.id = mol.sales_order_line_id
LEFT JOIN public."CatalogItems" ci ON ci.id = sol.catalog_item_id
WHERE mol.deleted = false
  AND mo.deleted = false
  AND mo.status IN ('ready_for_pickup', 'delivered')
  AND mol.delivery_status IN ('ready', 'delivered')

UNION ALL

-- Accessory lines from SO
SELECT
  'accessory' AS line_type,
  soa.id AS line_id,
  soa.sales_order_id,
  NULL::uuid AS manufacturing_order_id,
  NULL::text AS manufacturing_order_no,
  NULL::text AS mo_status,
  soa.organization_id,
  soa.delivery_status,
  soa.qty AS quantity,
  soa.delivered_qty,
  soa.delivered_at,
  so.sales_order_no,
  d.dealer_name,
  dc.customer_name,
  ci.name AS line_description,
  NULL::text AS product_type,
  NULL::text AS area,
  NULL::text AS position,
  ci.name AS catalog_item_name,
  ci.sku AS catalog_item_sku,
  NULL::timestamptz AS released_at
FROM public."SaleOrderAccessories" soa
JOIN public."SalesOrders" so ON so.id = soa.sales_order_id
LEFT JOIN public."Dealers" d ON d.id = so.dealer_id
LEFT JOIN public."DirectoryCustomers" dc ON dc.id = so.customer_id
LEFT JOIN public."CatalogItems" ci ON ci.id = soa.catalog_item_id
WHERE soa.deleted = false
  AND so.deleted = false;

-- ────────────────────────────────────────────────────────────
-- 6. Patch create_sales_order_on_quote_approve to copy accessories
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_sales_order_on_quote_approve(
  p_quote_id uuid,
  p_user_id uuid DEFAULT NULL,
  p_user_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_quote record;
  v_so_id uuid;
  v_so_number text;
  v_org_id uuid;
  v_ql record;
  v_line_num int := 0;
  v_subtotal numeric := 0;
  v_line_total numeric := 0;
  v_tax_pct numeric := 0;
  v_tax numeric := 0;
  v_total numeric := 0;
  v_exempt boolean;
BEGIN
  SELECT * INTO v_quote FROM "Quotes" WHERE id = p_quote_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'Quote not found'; END IF;
  IF v_quote.status != 'approved' THEN
    RAISE EXCEPTION 'Quote must be approved (current: %)', v_quote.status;
  END IF;
  IF EXISTS (SELECT 1 FROM "SalesOrders" WHERE quote_id = p_quote_id AND deleted = false) THEN
    RETURN jsonb_build_object('ok', true,
      'sales_order_id', (SELECT id FROM "SalesOrders" WHERE quote_id = p_quote_id AND deleted = false LIMIT 1),
      'so_number', (SELECT sales_order_no FROM "SalesOrders" WHERE quote_id = p_quote_id AND deleted = false LIMIT 1));
  END IF;

  v_org_id := v_quote.organization_id;
  v_exempt := COALESCE(v_quote.exempt_tax, false);

  SELECT COALESCE(SUM(
    COALESCE(dealer_price_total,
      COALESCE(quantity, 1) * COALESCE(unit_dealer_price_snapshot, unit_msrp, 0)
    )
  ), 0) INTO v_subtotal
  FROM "QuoteLines" WHERE quote_id = p_quote_id;

  IF v_exempt THEN
    v_tax_pct := 0;
  ELSE
    SELECT COALESCE(cs.tax_pct, 0) INTO v_tax_pct
    FROM "CostSettings" cs WHERE cs.organization_id = v_org_id LIMIT 1;
  END IF;

  v_tax := ROUND(v_subtotal * v_tax_pct, 2);
  v_total := v_subtotal + v_tax;

  INSERT INTO "SalesOrders" (
    organization_id, quote_id, status, tracking_status,
    dealer_id, customer_id, contact_id, priority,
    subtotal, tax_amount, total_amount, exempt_tax, notes
  ) VALUES (
    v_org_id, p_quote_id, 'confirmed', 'pending_confirmation',
    v_quote.dealer_id, v_quote.customer_id, v_quote.contact_id,
    COALESCE(v_quote.priority, 'normal'),
    v_subtotal, v_tax, v_total, v_exempt, v_quote.notes
  )
  RETURNING id, sales_order_no INTO v_so_id, v_so_number;

  FOR v_ql IN
    SELECT * FROM "QuoteLines" WHERE quote_id = p_quote_id ORDER BY sort_order ASC NULLS LAST, created_at ASC
  LOOP
    v_line_num := v_line_num + 1;
    v_line_total := COALESCE(v_ql.dealer_price_total,
      (COALESCE(v_ql.quantity, 1) * COALESCE(v_ql.unit_dealer_price_snapshot, v_ql.unit_msrp, 0)));
    INSERT INTO "SaleOrderLines" (
      organization_id, sales_order_id, quote_line_id, catalog_item_id, configured_product_id, line_number,
      quantity, unit_price, line_total, description, product_type, product_type_id,
      collection_name, variant_name, hardware_color, width_m, height_m, sqm, area, "position"
    ) VALUES (
      v_org_id, v_so_id, v_ql.id, v_ql.catalog_item_id, v_ql.configured_product_id, v_line_num,
      COALESCE(v_ql.quantity, 1),
      COALESCE(v_ql.unit_dealer_price_snapshot, v_ql.unit_msrp, 0),
      v_line_total,
      v_ql.name, v_ql.product_type, v_ql.product_type_id,
      v_ql.collection_name, v_ql.variant_name, v_ql.hardware_color,
      v_ql.width_m, v_ql.height_m, (COALESCE(v_ql.width_m, 0) * COALESCE(v_ql.height_m, 0)),
      v_ql.area, v_ql."position"
    );
  END LOOP;

  -- Copy accessories from QuoteLineComponents to SaleOrderAccessories
  INSERT INTO "SaleOrderAccessories" (
    organization_id, sales_order_id, catalog_item_id,
    qty, unit_cost_exw, unit_price
  )
  SELECT DISTINCT ON (qlc.catalog_item_id)
    v_org_id,
    v_so_id,
    qlc.catalog_item_id,
    SUM(qlc.qty) OVER (PARTITION BY qlc.catalog_item_id),
    qlc.unit_cost_exw,
    qlc.unit_cost_exw
  FROM "QuoteLineComponents" qlc
  JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
  WHERE ql.quote_id = p_quote_id
    AND COALESCE(qlc.deleted, false) = false
    AND (qlc.component_role = 'accessory' OR qlc.source = 'accessory');

  IF p_user_id IS NOT NULL THEN
    PERFORM _insert_timeline(v_org_id, 'sales_order', v_so_id, 'created',
      'Sales Order created from Quote', p_user_id, p_user_name,
      jsonb_build_object('quote_id', p_quote_id, 'quote_no', v_quote.quote_no));
  END IF;

  RETURN jsonb_build_object('ok', true, 'sales_order_id', v_so_id, 'so_number', v_so_number);
END;
$function$;

-- ────────────────────────────────────────────────────────────
-- 7. Patch create_sales_order_from_quote to copy accessories
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_sales_order_from_quote(
  p_quote_id uuid,
  p_user_id uuid,
  p_user_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_quote record;
  v_proposal record;
  v_so_id uuid;
  v_so_number text;
  v_org_id uuid;
  v_ql record;
  v_line_num int := 0;
  v_subtotal numeric;
  v_tax_pct numeric := 0;
  v_tax numeric := 0;
  v_total numeric;
  v_exempt boolean;
BEGIN
  SELECT * INTO v_quote FROM "Quotes" WHERE id = p_quote_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Quote not found'; END IF;
  IF v_quote.status != 'approved' THEN
    RAISE EXCEPTION 'Quote must be in "approved" status to convert (current: %)', v_quote.status;
  END IF;

  IF NOT COALESCE(v_quote.measures_confirmed, false) THEN
    RAISE EXCEPTION 'Measures must be confirmed for production before creating a Sales Order.';
  END IF;

  IF EXISTS (SELECT 1 FROM "SalesOrders" WHERE quote_id = p_quote_id AND deleted = false) THEN
    RAISE EXCEPTION 'A Sales Order already exists for this quote';
  END IF;

  SELECT * INTO v_proposal FROM "Proposals"
    WHERE quote_id = p_quote_id AND status = 'accepted'
    ORDER BY updated_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No accepted proposal found for this quote';
  END IF;

  v_org_id := v_quote.organization_id;
  v_exempt := COALESCE(v_quote.exempt_tax, false);

  SELECT COALESCE(SUM(COALESCE(dealer_price_total, 0)), 0)
  INTO v_subtotal
  FROM "QuoteLines"
  WHERE quote_id = p_quote_id;

  IF v_exempt THEN
    v_tax_pct := 0;
  ELSE
    SELECT COALESCE(cs.tax_pct, 0) INTO v_tax_pct
    FROM "CostSettings" cs WHERE cs.organization_id = v_org_id LIMIT 1;
  END IF;

  v_tax := ROUND(v_subtotal * v_tax_pct, 2);
  v_total := v_subtotal + v_tax;

  INSERT INTO "SalesOrders" (
    organization_id, quote_id, proposal_id, status, tracking_status,
    dealer_id, customer_id, contact_id, priority,
    subtotal, tax_amount, total_amount, exempt_tax, payment_status, notes
  ) VALUES (
    v_org_id, p_quote_id, v_proposal.id, 'confirmed', 'confirmed',
    v_quote.dealer_id, v_quote.customer_id, v_quote.contact_id,
    COALESCE(v_quote.priority, 'normal'),
    v_subtotal, v_tax, v_total, v_exempt,
    'pending', v_quote.notes
  )
  RETURNING id, sales_order_no INTO v_so_id, v_so_number;

  FOR v_ql IN
    SELECT * FROM "QuoteLines"
    WHERE quote_id = p_quote_id
    ORDER BY sort_order ASC NULLS LAST, created_at ASC
  LOOP
    v_line_num := v_line_num + 1;
    INSERT INTO "SaleOrderLines" (
      organization_id, sales_order_id, quote_line_id,
      catalog_item_id, configured_product_id, line_number,
      quantity, unit_price, line_total,
      area, "position", description, product_type, product_type_id,
      collection_name, variant_name, hardware_color,
      width_m, height_m, sqm
    ) VALUES (
      v_org_id, v_so_id, v_ql.id,
      v_ql.catalog_item_id, v_ql.configured_product_id, v_line_num,
      COALESCE(v_ql.quantity, 1),
      COALESCE(v_ql.unit_dealer_price_snapshot, 0),
      COALESCE(v_ql.dealer_price_total, 0),
      v_ql.area, v_ql."position", v_ql.name, v_ql.product_type, v_ql.product_type_id,
      v_ql.collection_name, v_ql.variant_name, v_ql.hardware_color,
      v_ql.width_m, v_ql.height_m, v_ql.width_m * v_ql.height_m
    );
  END LOOP;

  -- Copy accessories from QuoteLineComponents to SaleOrderAccessories
  INSERT INTO "SaleOrderAccessories" (
    organization_id, sales_order_id, catalog_item_id,
    qty, unit_cost_exw, unit_price
  )
  SELECT DISTINCT ON (qlc.catalog_item_id)
    v_org_id,
    v_so_id,
    qlc.catalog_item_id,
    SUM(qlc.qty) OVER (PARTITION BY qlc.catalog_item_id),
    qlc.unit_cost_exw,
    qlc.unit_cost_exw
  FROM "QuoteLineComponents" qlc
  JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
  WHERE ql.quote_id = p_quote_id
    AND COALESCE(qlc.deleted, false) = false
    AND (qlc.component_role = 'accessory' OR qlc.source = 'accessory');

  UPDATE "Quotes"
  SET status = 'converted',
      subtotal = v_subtotal,
      tax_amount = v_tax,
      total_amount = v_total,
      updated_at = now()
  WHERE id = p_quote_id;

  UPDATE "Proposals" SET updated_at = now() WHERE id = v_proposal.id;

  INSERT INTO "ActivityTimeline" (entity_type, entity_id, action, description, user_name, organization_id)
  VALUES ('quote', p_quote_id, 'converted_to_so',
          format('Sales Order %s created', v_so_number),
          COALESCE(p_user_name, p_user_id::text),
          v_org_id);

  RETURN jsonb_build_object('ok', true, 'sales_order_id', v_so_id, 'so_number', v_so_number);
END;
$function$;

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
