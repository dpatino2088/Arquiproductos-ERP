-- Make "Confirm Measurements" conditional and let custom lines carry dimensions.
--
-- Business rule (from user): a Custom Item can be a Service, a generic Product,
-- Shipping, or a made-to-measure Product. Only made-to-measure items have real
-- dimensions, so only quotes that actually contain a measurable line should
-- require the "Confirm Measurements" step before a Sales Order can be created.
--
-- A quote line "requires measures" when it is a configured/manufactured product
-- (has a configured product and is not a catalog accessory) OR it is a custom
-- line whose category is 'made_to_measure'. Service / Product / Shipping / catalog
-- lines never require measures.

SET search_path = public;

-- 1) Central predicate reused by the SO gate (and available to the UI/RPCs).
CREATE OR REPLACE FUNCTION public.quote_requires_measures(p_quote_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public."QuoteLines" ql
    WHERE ql.quote_id = p_quote_id
      AND (
        (ql.configured_product_id IS NOT NULL AND COALESCE(ql.product_type, '') <> 'catalog')
        OR COALESCE(ql.custom_category, '') = 'made_to_measure'
      )
  );
$$;

GRANT EXECUTE ON FUNCTION public.quote_requires_measures(uuid) TO authenticated;

-- 2) Custom-line pricing RPC now accepts optional made-to-measure dimensions.
--    Non-measured categories clear width/height so lines stay clean.
DROP FUNCTION IF EXISTS public.set_custom_quote_line_pricing(uuid, text, numeric, numeric, numeric, numeric, text, text, text);

CREATE OR REPLACE FUNCTION public.set_custom_quote_line_pricing(
  p_quote_line_id uuid,
  p_name text,
  p_unit_cost numeric,
  p_markup_pct numeric,
  p_unit_price numeric,
  p_qty numeric,
  p_category text DEFAULT NULL::text,
  p_area text DEFAULT NULL::text,
  p_position text DEFAULT NULL::text,
  p_width_m numeric DEFAULT NULL::numeric,
  p_height_m numeric DEFAULT NULL::numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ql_id uuid;
  v_qty   numeric;
  v_cost  numeric;
  v_markup numeric;
  v_price numeric;
  v_is_mtm boolean;
  v_width numeric;
  v_height numeric;
BEGIN
  SELECT id INTO v_ql_id FROM public."QuoteLines" WHERE id = p_quote_line_id;
  IF v_ql_id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  v_qty    := GREATEST(COALESCE(p_qty, 1), 1);
  v_cost   := GREATEST(COALESCE(p_unit_cost, 0), 0);
  v_markup := COALESCE(p_markup_pct, 0);
  v_price  := COALESCE(NULLIF(p_unit_price, 0), v_cost * (1 + v_markup / 100.0));
  v_price  := GREATEST(COALESCE(v_price, 0), 0);

  v_is_mtm := (COALESCE(p_category, '') = 'made_to_measure');
  v_width  := CASE WHEN v_is_mtm THEN NULLIF(p_width_m, 0) ELSE NULL END;
  v_height := CASE WHEN v_is_mtm THEN NULLIF(p_height_m, 0) ELSE NULL END;

  PERFORM set_config('app.write_source', 'rpc', true);
  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  UPDATE public."QuoteLines"
  SET
    name                       = p_name,
    quantity                   = v_qty,
    area                       = p_area,
    position                   = p_position,
    custom_category            = p_category,
    width_m                    = v_width,
    height_m                   = v_height,
    markup_pct                 = v_markup,
    unit_msrp                  = v_price,
    msrp                       = ROUND(v_price * v_qty, 2),
    net_price                  = ROUND(v_price * v_qty, 2),
    unit_msrp_total_snapshot   = v_price,
    unit_dealer_price_snapshot = v_price,
    dealer_price_total         = ROUND(v_price * v_qty, 2),
    unit_cost_total_snapshot   = v_cost,
    total_cost                 = v_cost,
    pricing_locked             = true,
    last_priced_at             = now(),
    pricing_version            = COALESCE(pricing_version, 0) + 1
  WHERE id = p_quote_line_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.set_custom_quote_line_pricing(uuid, text, numeric, numeric, numeric, numeric, text, text, text, numeric, numeric) TO authenticated;

-- 3) Sales Order creation only requires confirmed measures when the quote has
--    at least one measurable line. Service/Product/Shipping-only quotes proceed.
CREATE OR REPLACE FUNCTION public.create_sales_order_from_quote(p_quote_id uuid, p_user_id uuid, p_user_name text DEFAULT NULL::text)
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
  v_subtotal numeric := 0;
  v_quote_lines_count int := 0;
  v_line_total numeric := 0;
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

  -- Only made-to-measure / manufactured lines need confirmed measures.
  IF public.quote_requires_measures(p_quote_id)
     AND NOT COALESCE(v_quote.measures_confirmed, false) THEN
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

  SELECT COUNT(*) INTO v_quote_lines_count FROM "QuoteLines" WHERE quote_id = p_quote_id;
  IF v_quote_lines_count = 0 THEN
    RAISE EXCEPTION 'Cannot create a Sales Order for a custom-only quote: it has no Arquiproductos product lines.';
  END IF;

  SELECT COALESCE(SUM(
    COALESCE(dealer_price_total,
      COALESCE(quantity, 1) * COALESCE(unit_dealer_price_snapshot, unit_msrp, 0)
    )
  ), 0)
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
    v_line_total := COALESCE(v_ql.dealer_price_total,
      (COALESCE(v_ql.quantity, 1) * COALESCE(v_ql.unit_dealer_price_snapshot, v_ql.unit_msrp, 0)));
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
      COALESCE(v_ql.unit_dealer_price_snapshot, v_ql.unit_msrp, 0),
      v_line_total,
      v_ql.area, v_ql."position", v_ql.name, v_ql.product_type, v_ql.product_type_id,
      v_ql.collection_name, v_ql.variant_name, v_ql.hardware_color,
      v_ql.width_m, v_ql.height_m, COALESCE(v_ql.width_m, 0) * COALESCE(v_ql.height_m, 0)
    );
  END LOOP;

  INSERT INTO "SaleOrderAccessories" (
    organization_id, sales_order_id, catalog_item_id,
    qty, unit_cost_exw, unit_price
  )
  SELECT DISTINCT ON (qlc.catalog_item_id)
    v_org_id, v_so_id, qlc.catalog_item_id,
    SUM(qlc.qty) OVER (PARTITION BY qlc.catalog_item_id),
    qlc.unit_cost_exw, qlc.unit_cost_exw
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

NOTIFY pgrst, 'reload schema';
