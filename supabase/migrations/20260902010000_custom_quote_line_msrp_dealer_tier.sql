-- Custom quote lines: give the dealer their default margin in the Proposal.
--
-- Before: set_custom_quote_line_pricing wrote the SAME value into the dealer
-- price (unit_dealer_price_snapshot / dealer_price_total) and the customer
-- price (unit_msrp / msrp). Proposals inherit unit_msrp, so the end customer
-- saw exactly what the dealer pays -> zero dealer margin on custom lines.
--
-- Now: unit_msrp is uplifted with the dealer's tier discount using the SAME
-- formula as regular products (dealer_price = msrp x (1 - discount)):
--
--   unit_msrp = unit_dealer_price / (1 - tier_discount_pct / 100)
--
-- e.g. Gold (50%): dealer pays $100 -> proposal shows $200.
-- If the quote has no dealer / tier, behavior is unchanged (msrp = price).
-- Dealer-facing quote totals are untouched (they read dealer_price_total).
-- Applies to lines saved from now on; existing lines are NOT recalculated.

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
  v_quote_id uuid;
  v_qty   numeric;
  v_cost  numeric;
  v_markup numeric;
  v_price numeric;
  v_is_mtm boolean;
  v_width numeric;
  v_height numeric;
  v_tier_disc numeric;
  v_msrp_unit numeric;
BEGIN
  SELECT id, quote_id INTO v_ql_id, v_quote_id
  FROM public."QuoteLines" WHERE id = p_quote_line_id;
  IF v_ql_id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  v_qty    := GREATEST(COALESCE(p_qty, 1), 1);
  v_cost   := GREATEST(COALESCE(p_unit_cost, 0), 0);
  v_markup := COALESCE(p_markup_pct, 0);
  v_price  := COALESCE(NULLIF(p_unit_price, 0), v_cost * (1 + v_markup / 100.0));
  v_price  := GREATEST(COALESCE(v_price, 0), 0);

  -- Dealer's default margin = their tier discount (same rule as catalog pricing).
  SELECT dt.discount_pct
  INTO v_tier_disc
  FROM public."Quotes" q
  JOIN public."Dealers" d ON d.id = q.dealer_id AND d.deleted IS NOT TRUE
  JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id
  WHERE q.id = v_quote_id;

  v_msrp_unit := CASE
    WHEN v_tier_disc IS NOT NULL AND v_tier_disc > 0 AND v_tier_disc < 100
      THEN ROUND(v_price / (1 - v_tier_disc / 100.0), 2)
    ELSE v_price
  END;

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
    unit_msrp                  = v_msrp_unit,
    msrp                       = ROUND(v_msrp_unit * v_qty, 2),
    net_price                  = ROUND(v_price * v_qty, 2),
    unit_msrp_total_snapshot   = v_msrp_unit,
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

COMMENT ON FUNCTION public.set_custom_quote_line_pricing(uuid, text, numeric, numeric, numeric, numeric, text, text, text, numeric, numeric) IS
  'Prices a custom/service quote line. unit_price is the DEALER price; unit_msrp (customer price shown in Proposals) is derived with the dealer tier discount: msrp = price / (1 - tier_pct/100).';
