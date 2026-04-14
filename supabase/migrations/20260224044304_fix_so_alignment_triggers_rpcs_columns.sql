
-- =============================================================================
-- Phase 1: SO Alignment — Fix triggers, columns, and RPCs
-- =============================================================================

-- 1a. Disable legacy triggers that auto-create broken SOs on Quote approval
DROP TRIGGER IF EXISTS trg_quote_approved ON "Quotes";
DROP TRIGGER IF EXISTS trg_quote_approved_to_sales_order ON "Quotes";

-- 1b. Add missing columns to SaleOrderLines
ALTER TABLE "SaleOrderLines"
  ADD COLUMN IF NOT EXISTS line_number integer,
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS product_type text,
  ADD COLUMN IF NOT EXISTS product_type_id uuid,
  ADD COLUMN IF NOT EXISTS collection_name text,
  ADD COLUMN IF NOT EXISTS variant_name text,
  ADD COLUMN IF NOT EXISTS hardware_color text,
  ADD COLUMN IF NOT EXISTS configured_product_id uuid,
  ADD COLUMN IF NOT EXISTS area text,
  ADD COLUMN IF NOT EXISTS "position" text;

-- 1c. Fix create_sales_order_from_quote RPC
CREATE OR REPLACE FUNCTION create_sales_order_from_quote(
  p_quote_id uuid,
  p_user_id uuid,
  p_user_name text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_quote record;
  v_proposal record;
  v_so_id uuid;
  v_so_number text;
  v_org_id uuid;
  v_ql record;
  v_line_num int := 0;
  v_subtotal numeric;
  v_total numeric;
BEGIN
  -- Read and validate Quote
  SELECT * INTO v_quote FROM "Quotes" WHERE id = p_quote_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Quote not found'; END IF;
  IF v_quote.status != 'approved' THEN
    RAISE EXCEPTION 'Quote must be in "approved" status to convert (current: %)', v_quote.status;
  END IF;

  -- Check no existing SO for this quote
  IF EXISTS (SELECT 1 FROM "SalesOrders" WHERE quote_id = p_quote_id AND deleted = false) THEN
    RAISE EXCEPTION 'A Sales Order already exists for this quote';
  END IF;

  -- Find accepted proposal
  SELECT * INTO v_proposal FROM "Proposals"
    WHERE quote_id = p_quote_id AND status = 'accepted'
    ORDER BY updated_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No accepted proposal found for this quote';
  END IF;

  v_org_id := v_quote.organization_id;

  -- Calculate totals from QuoteLines (dealer price)
  SELECT COALESCE(SUM(COALESCE(dealer_price_total, 0)), 0)
  INTO v_subtotal
  FROM "QuoteLines"
  WHERE quote_id = p_quote_id;

  v_total := v_subtotal; -- tax = 0 for now

  -- Insert Sales Order
  INSERT INTO "SalesOrders" (
    organization_id, quote_id, proposal_id, status, tracking_status,
    dealer_id, customer_id, contact_id, priority,
    subtotal, tax_amount, total_amount, payment_status, notes
  ) VALUES (
    v_org_id, p_quote_id, v_proposal.id, 'confirmed', 'confirmed',
    v_quote.dealer_id, v_quote.customer_id, v_quote.contact_id,
    COALESCE(v_quote.priority, 'normal'),
    v_subtotal, 0, v_total,
    'pending', v_quote.notes
  )
  RETURNING id, sales_order_no INTO v_so_id, v_so_number;

  -- Copy QuoteLines to SaleOrderLines
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

  -- Update Quote status
  UPDATE "Quotes"
  SET status = 'converted',
      subtotal = v_subtotal,
      tax_amount = 0,
      total_amount = v_total,
      updated_at = now()
  WHERE id = p_quote_id;

  -- Update Proposal
  UPDATE "Proposals" SET updated_at = now() WHERE id = v_proposal.id;

  -- Timeline entries
  PERFORM _insert_timeline(v_org_id, 'quote', p_quote_id, 'converted',
    'Converted to Sales Order ' || v_so_number,
    p_user_id, p_user_name,
    jsonb_build_object('sales_order_id', v_so_id, 'so_number', v_so_number));

  PERFORM _insert_timeline(v_org_id, 'sales_order', v_so_id, 'created',
    'Created from Quote ' || v_quote.quote_no,
    p_user_id, p_user_name,
    jsonb_build_object('quote_id', p_quote_id, 'quote_no', v_quote.quote_no));

  RETURN jsonb_build_object('ok', true, 'sales_order_id', v_so_id, 'so_number', v_so_number);
END;
$$;

-- 1d. Fix create_manufacturing_order RPC
CREATE OR REPLACE FUNCTION create_manufacturing_order(
  p_sales_order_id uuid,
  p_user_id uuid,
  p_sales_order_line_id uuid DEFAULT NULL,
  p_user_name text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_so record;
  v_sol record;
  v_mo_id uuid;
  v_mo_number text;
  v_product_name text;
  v_quantity int;
BEGIN
  SELECT * INTO v_so FROM "SalesOrders" WHERE id = p_sales_order_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'Sales Order not found'; END IF;
  IF v_so.status NOT IN ('draft','confirmed') THEN
    RAISE EXCEPTION 'SO must be open to create MO (current: %)', v_so.status;
  END IF;

  -- Load line if provided, otherwise use defaults
  v_product_name := 'Product';
  v_quantity := 1;
  IF p_sales_order_line_id IS NOT NULL THEN
    SELECT * INTO v_sol FROM "SaleOrderLines"
    WHERE id = p_sales_order_line_id AND sales_order_id = p_sales_order_id;
    IF FOUND THEN
      v_product_name := COALESCE(v_sol.description, v_sol.collection_name, 'Product');
      v_quantity := COALESCE(v_sol.quantity::int, 1);
    END IF;
  END IF;

  INSERT INTO "ManufacturingOrders" (
    organization_id, sales_order_id, sales_order_line_id,
    status, mo_type, priority, dealer_id,
    product_name, quantity, created_by
  ) VALUES (
    v_so.organization_id, p_sales_order_id, p_sales_order_line_id,
    'draft', 'primary', COALESCE(v_so.priority, 'normal'), v_so.dealer_id,
    v_product_name, v_quantity, p_user_id
  )
  RETURNING id, manufacturing_order_no INTO v_mo_id, v_mo_number;

  PERFORM _insert_timeline(v_so.organization_id, 'manufacturing_order', v_mo_id, 'created',
    'Manufacturing Order created', p_user_id, p_user_name,
    jsonb_build_object('so_id', p_sales_order_id, 'so_number', v_so.sales_order_no));

  PERFORM _insert_timeline(v_so.organization_id, 'sales_order', p_sales_order_id, 'mo_created',
    'Manufacturing Order ' || v_mo_number || ' created', p_user_id, p_user_name,
    jsonb_build_object('mo_id', v_mo_id, 'mo_number', v_mo_number));

  RETURN jsonb_build_object('ok', true, 'mo_id', v_mo_id, 'mo_number', v_mo_number);
END;
$$;

-- 1e. Fix record_payment RPC with validations
CREATE OR REPLACE FUNCTION record_payment(
  p_so_id uuid,
  p_amount numeric,
  p_method text,
  p_reference text,
  p_user_id uuid,
  p_user_name text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_so record;
  v_new_paid numeric;
  v_new_status text;
  v_payment_id uuid;
  v_balance_due numeric;
BEGIN
  SELECT * INTO v_so FROM "SalesOrders" WHERE id = p_so_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'SO not found'; END IF;
  IF v_so.status IN ('closed','cancelled') THEN
    RAISE EXCEPTION 'Cannot record payment on % order', v_so.status;
  END IF;

  -- Validate total > 0
  IF COALESCE(v_so.total_amount, 0) <= 0 THEN
    RAISE EXCEPTION 'Cannot record payment — Sales Order has no total amount';
  END IF;

  -- Validate amount > 0
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Payment amount must be positive';
  END IF;

  -- Validate amount does not exceed balance
  v_balance_due := COALESCE(v_so.total_amount, 0) - COALESCE(v_so.amount_paid, 0);
  IF p_amount > v_balance_due THEN
    RAISE EXCEPTION 'Payment amount ($%) exceeds balance due ($%)', p_amount, v_balance_due;
  END IF;

  INSERT INTO "Payments" (organization_id, sales_order_id, amount, payment_method, reference_number, recorded_by)
  VALUES (v_so.organization_id, p_so_id, p_amount, p_method, p_reference, p_user_id)
  RETURNING id INTO v_payment_id;

  v_new_paid := COALESCE(v_so.amount_paid, 0) + p_amount;
  IF v_new_paid <= 0 THEN v_new_status := 'pending';
  ELSIF v_new_paid >= COALESCE(v_so.total_amount, 0) THEN v_new_status := 'paid';
  ELSE v_new_status := 'partial';
  END IF;

  UPDATE "SalesOrders" SET amount_paid = v_new_paid, payment_status = v_new_status, updated_at = now() WHERE id = p_so_id;

  PERFORM _insert_timeline(v_so.organization_id, 'sales_order', p_so_id, 'payment_recorded',
    'Payment of $' || p_amount::text || ' recorded (' || COALESCE(p_method,'') || ')',
    p_user_id, p_user_name,
    jsonb_build_object('amount', p_amount, 'method', p_method, 'reference', p_reference, 'payment_id', v_payment_id, 'new_status', v_new_status));

  RETURN jsonb_build_object('ok', true, 'payment_id', v_payment_id, 'new_paid', v_new_paid, 'payment_status', v_new_status);
END;
$$;
;
