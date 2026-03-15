-- ============================================================
-- Quote: measures_confirmed lifecycle
-- ============================================================
-- 1) Add measures_confirmed flag + timestamps to Quotes
-- 2) Replace proposal-based lock with measures_confirmed lock
--    (Quotes are freely editable until measures are confirmed)
-- 3) Guard SO creation: require measures_confirmed = true
-- ============================================================

BEGIN;

-- ============================================================
-- 1) New columns on Quotes
-- ============================================================
ALTER TABLE public."Quotes"
  ADD COLUMN IF NOT EXISTS measures_confirmed boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS measures_confirmed_at timestamptz,
  ADD COLUMN IF NOT EXISTS measures_confirmed_by uuid REFERENCES auth.users(id);

COMMENT ON COLUMN public."Quotes"."measures_confirmed"
  IS 'True when rectified measures have been confirmed for production. Locks the Quote permanently.';
COMMENT ON COLUMN public."Quotes"."measures_confirmed_at"
  IS 'Timestamp when measures were confirmed.';
COMMENT ON COLUMN public."Quotes"."measures_confirmed_by"
  IS 'User who confirmed the measures.';

-- ============================================================
-- 2) RPC: confirm_quote_measures(p_quote_id, p_user_id)
-- ============================================================
CREATE OR REPLACE FUNCTION public.confirm_quote_measures(
  p_quote_id uuid,
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_quote record;
BEGIN
  SELECT id, status, measures_confirmed
  INTO v_quote
  FROM "Quotes"
  WHERE id = p_quote_id AND deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quote not found';
  END IF;

  IF v_quote.measures_confirmed THEN
    RETURN jsonb_build_object('ok', true, 'already_confirmed', true);
  END IF;

  UPDATE "Quotes"
  SET measures_confirmed = true,
      measures_confirmed_at = now(),
      measures_confirmed_by = p_user_id,
      updated_at = now()
  WHERE id = p_quote_id;

  INSERT INTO "ActivityTimeline" (entity_type, entity_id, action, description, user_name, organization_id)
  SELECT 'quote', p_quote_id, 'measures_confirmed',
         'Rectified measures confirmed for production',
         COALESCE(au.display_name, au.email, p_user_id::text),
         q.organization_id
  FROM "Quotes" q
  LEFT JOIN auth.users au ON au.id = p_user_id
  WHERE q.id = p_quote_id;

  RETURN jsonb_build_object('ok', true, 'confirmed_at', now());
END;
$$;

-- ============================================================
-- 3) RPC: reopen_quote_measures(p_quote_id, p_user_id)
--    Allows reopening if the user needs to fix measures
--    (only if no SO has been created yet)
-- ============================================================
CREATE OR REPLACE FUNCTION public.reopen_quote_measures(
  p_quote_id uuid,
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_quote record;
BEGIN
  SELECT id, status, measures_confirmed
  INTO v_quote
  FROM "Quotes"
  WHERE id = p_quote_id AND deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quote not found';
  END IF;

  IF NOT v_quote.measures_confirmed THEN
    RETURN jsonb_build_object('ok', true, 'already_open', true);
  END IF;

  IF v_quote.status = 'converted' THEN
    RAISE EXCEPTION 'Cannot reopen measures: Quote has already been converted to a Sales Order.';
  END IF;

  IF EXISTS (SELECT 1 FROM "SalesOrders" WHERE quote_id = p_quote_id AND deleted = false) THEN
    RAISE EXCEPTION 'Cannot reopen measures: A Sales Order already exists for this Quote.';
  END IF;

  UPDATE "Quotes"
  SET measures_confirmed = false,
      updated_at = now()
  WHERE id = p_quote_id;

  INSERT INTO "ActivityTimeline" (entity_type, entity_id, action, description, user_name, organization_id)
  SELECT 'quote', p_quote_id, 'measures_reopened',
         'Measures confirmation reverted for corrections',
         COALESCE(au.display_name, au.email, p_user_id::text),
         q.organization_id
  FROM "Quotes" q
  LEFT JOIN auth.users au ON au.id = p_user_id
  WHERE q.id = p_quote_id;

  RETURN jsonb_build_object('ok', true, 'reopened_at', now());
END;
$$;

-- ============================================================
-- 4) Replace lock triggers: use measures_confirmed instead of proposal-based
-- ============================================================

-- 4a) Replace QuoteLines lock function
CREATE OR REPLACE FUNCTION public.tg_block_quote_lines_if_locked()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_confirmed boolean;
BEGIN
  SELECT measures_confirmed INTO v_confirmed
  FROM public."Quotes"
  WHERE id = COALESCE(OLD.quote_id, NEW.quote_id);

  IF COALESCE(v_confirmed, false) THEN
    RAISE EXCEPTION 'Quote is locked: measures have been confirmed for production. Reopen measures before editing.'
      USING ERRCODE = 'P0001';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

-- 4b) Replace Quotes lock function
CREATE OR REPLACE FUNCTION public.tg_block_quotes_if_locked()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.measures_confirmed AND NEW.measures_confirmed THEN
    IF NEW.measures_confirmed_at IS DISTINCT FROM OLD.measures_confirmed_at
       OR NEW.measures_confirmed_by IS DISTINCT FROM OLD.measures_confirmed_by
       OR NEW.status IS DISTINCT FROM OLD.status
    THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Quote is locked: measures have been confirmed for production. Reopen measures before editing.'
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

-- ============================================================
-- 5) Guard SO creation: require measures_confirmed
-- ============================================================
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

COMMIT;
