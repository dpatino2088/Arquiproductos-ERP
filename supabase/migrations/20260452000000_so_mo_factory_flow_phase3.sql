-- ====================================================
-- Migration: SO/MO Factory Flow Phase 3 — Drop Legacy Columns & Tables
-- ====================================================
-- Drops old triggers, legacy columns (status, tracking_status, order_progress_status),
-- and the OrderList table. Updates quote-approved trigger to use order_status.
-- ====================================================

SET search_path = public;

-- ====================================================
-- STEP 1: Drop old triggers (MO sync, SO confirmed create MO, OrderList sync)
-- ====================================================

DROP TRIGGER IF EXISTS trg_sale_order_confirmed_create_mo ON public."SalesOrders";
DROP TRIGGER IF EXISTS trg_mo_status_sync_sale_order ON public."ManufacturingOrders";
DROP TRIGGER IF EXISTS sync_order_list_tracking_status ON public."SalesOrders";
DROP TRIGGER IF EXISTS trg_sync_sale_order_progress_on_mo_insert ON public."ManufacturingOrders";
DROP TRIGGER IF EXISTS trg_sync_sale_order_progress_on_mo_status_update ON public."ManufacturingOrders";
-- Drop legacy quote-approved trigger that creates OrderList (redundant with on_quote_approved_create_operational_docs)
DROP TRIGGER IF EXISTS trg_quote_approved_to_sales_order ON public."Quotes";

-- ====================================================
-- STEP 2: Update on_quote_approved to set order_status (not status)
-- ====================================================

CREATE OR REPLACE FUNCTION public.on_quote_approved_create_operational_docs()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sale_order_id uuid;
  v_sale_order_no text;
  v_quote_record record;
  v_quote_line_record record;
  v_sale_order_line_id uuid;
  v_line_number integer;
  v_subtotal numeric(12,4);
  v_tax numeric(12,4);
  v_total numeric(12,4);
  v_validated_side_channel_type text;
BEGIN
  IF NEW.status != 'approved' THEN RETURN NEW; END IF;
  IF OLD.status = 'approved' THEN RETURN NEW; END IF;

  SELECT * INTO v_quote_record FROM "Quotes" WHERE id = NEW.id AND deleted = false;
  IF NOT FOUND THEN RETURN NEW; END IF;

  v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
  v_tax := COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0);
  v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);

  SELECT id INTO v_sale_order_id FROM "SalesOrders" WHERE quote_id = NEW.id AND deleted = false LIMIT 1;

  IF NOT FOUND THEN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_next_sequential_number') THEN
      SELECT public.get_next_sequential_number('SaleOrders', 'sale_order_no', 'SO-') INTO v_sale_order_no;
    ELSE
      v_sale_order_no := 'SO-' || LPAD(public.get_next_counter_value(v_quote_record.organization_id, 'sale_order')::text, 6, '0');
    END IF;

    INSERT INTO "SalesOrders" (
      organization_id, quote_id, customer_id, sale_order_no,
      order_status, payment_status,
      currency, subtotal, tax, total, notes, order_date, created_by, updated_by, dealer_id
    )
    VALUES (
      v_quote_record.organization_id, NEW.id, v_quote_record.customer_id, v_sale_order_no,
      'Open'::order_status_so, 'Deposit Pending'::payment_status_so,
      COALESCE(v_quote_record.currency, 'USD'), v_subtotal, v_tax, v_total, v_quote_record.notes,
      CURRENT_DATE, NEW.created_by, NEW.updated_by, v_quote_record.dealer_id
    );
    SELECT id INTO v_sale_order_id FROM "SalesOrders" WHERE quote_id = NEW.id AND deleted = false LIMIT 1;
  END IF;

  IF v_sale_order_id IS NULL THEN RETURN NEW; END IF;

  FOR v_quote_line_record IN
    SELECT ql.* FROM "QuoteLines" ql
    WHERE ql.quote_id = NEW.id AND ql.deleted = false
    ORDER BY ql.created_at ASC
  LOOP
    SELECT id INTO v_sale_order_line_id FROM "SalesOrderLines"
    WHERE sale_order_id = v_sale_order_id AND quote_line_id = v_quote_line_record.id AND deleted = false LIMIT 1;

    IF NOT FOUND THEN
      SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number FROM "SalesOrderLines" WHERE sale_order_id = v_sale_order_id AND deleted = false;
      v_validated_side_channel_type := CASE
        WHEN v_quote_line_record.side_channel_type IS NULL THEN NULL
        WHEN LOWER(v_quote_line_record.side_channel_type) IN ('side_only','side_and_bottom') THEN LOWER(v_quote_line_record.side_channel_type)
        ELSE NULL
      END;
      INSERT INTO "SalesOrderLines" (
        organization_id, sale_order_id, quote_line_id, catalog_item_id, line_number, description,
        qty, unit_price_snapshot, line_total, width_m, height_m, area, position, collection_name, variant_name,
        product_type, product_type_id, drive_type, bottom_rail_type, cassette, cassette_type, side_channel, side_channel_type, hardware_color, metadata, created_by, updated_by
      )
      SELECT
        v_quote_record.organization_id, v_sale_order_id, v_quote_line_record.id, v_quote_line_record.catalog_item_id, v_line_number, v_quote_line_record.description,
        v_quote_line_record.qty, v_quote_line_record.unit_price_snapshot, v_quote_line_record.line_total, v_quote_line_record.width_m, v_quote_line_record.height_m, v_quote_line_record.area, v_quote_line_record.position, v_quote_line_record.collection_name, v_quote_line_record.variant_name,
        v_quote_line_record.product_type, v_quote_line_record.product_type_id, v_quote_line_record.drive_type, v_quote_line_record.bottom_rail_type, v_quote_line_record.cassette, v_quote_line_record.cassette_type, COALESCE(v_quote_line_record.side_channel, false), v_validated_side_channel_type, v_quote_line_record.hardware_color, v_quote_line_record.metadata, NEW.created_by, NEW.updated_by
      FROM "QuoteLines" ql WHERE ql.id = v_quote_line_record.id LIMIT 1;
    END IF;
  END LOOP;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error in on_quote_approved_create_operational_docs: %', SQLERRM;
  RETURN NEW;
END;
$$;


-- ====================================================
-- STEP 3: Drop legacy columns from SalesOrders
-- ====================================================

ALTER TABLE public."SalesOrders" DROP COLUMN IF EXISTS status;
ALTER TABLE public."SalesOrders" DROP COLUMN IF EXISTS tracking_status;
ALTER TABLE public."SalesOrders" DROP COLUMN IF EXISTS order_progress_status;

-- ====================================================
-- STEP 4: Drop legacy columns from ManufacturingOrders
-- ====================================================

ALTER TABLE public."ManufacturingOrders" DROP COLUMN IF EXISTS status;
-- Keep priority if it was text; we now have priority_code. Drop old priority if redundant.
ALTER TABLE public."ManufacturingOrders" DROP COLUMN IF EXISTS priority;

-- ====================================================
-- STEP 5: Drop OrderList table (redundant; UI uses SalesOrders)
-- ====================================================

DROP TRIGGER IF EXISTS enforce_orderlist_dealer_matches_salesorder ON public."OrderList";
DROP TRIGGER IF EXISTS update_order_list_updated_at ON public."OrderList";
DROP TABLE IF EXISTS public."OrderList" CASCADE;

-- ====================================================
-- STEP 6: Update convert_quote_to_sale_order (if exists) to use order_status
-- ====================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'convert_quote_to_sale_order') THEN
    EXECUTE '
    CREATE OR REPLACE FUNCTION public.convert_quote_to_sale_order(p_quote_id uuid, p_organization_id uuid, p_user_id uuid DEFAULT auth.uid())
    RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER AS $fn$
    DECLARE v_so_id uuid; v_so_no text; v_rec record;
    BEGIN
      SELECT id INTO v_so_id FROM "SalesOrders" WHERE quote_id = p_quote_id AND organization_id = p_organization_id AND deleted = false LIMIT 1;
      IF FOUND THEN RETURN v_so_id; END IF;
      SELECT * INTO v_rec FROM "Quotes" WHERE id = p_quote_id AND organization_id = p_organization_id AND deleted = false;
      IF NOT FOUND OR v_rec.status != ''approved'' THEN RAISE EXCEPTION ''Quote not found or not approved''; END IF;
      v_so_no := ''SO-'' || LPAD(public.get_next_counter_value(p_organization_id, ''sale_order'')::text, 6, ''0'');
      INSERT INTO "SalesOrders" (organization_id, quote_id, customer_id, sale_order_no, order_status, payment_status, currency, subtotal, tax, total, notes, order_date, created_by, updated_by, dealer_id)
      SELECT p_organization_id, p_quote_id, v_rec.customer_id, v_so_no, ''Open''::order_status_so, ''Deposit Pending''::payment_status_so, COALESCE(v_rec.currency,''USD''), COALESCE((v_rec.totals->>''subtotal'')::numeric,0), COALESCE((v_rec.totals->>''tax'')::numeric,0), COALESCE((v_rec.totals->>''total'')::numeric,0), v_rec.notes, CURRENT_DATE, p_user_id, p_user_id, v_rec.dealer_id;
      SELECT id INTO v_so_id FROM "SalesOrders" WHERE quote_id = p_quote_id AND organization_id = p_organization_id AND deleted = false LIMIT 1;
      RETURN v_so_id;
    END;
    $fn$;';
  END IF;
END $$;
