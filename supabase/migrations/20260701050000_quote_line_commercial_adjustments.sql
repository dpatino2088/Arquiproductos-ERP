BEGIN;

CREATE OR REPLACE FUNCTION public.apply_quote_line_commercial_adjustment(
  p_quote_line_id uuid,
  p_non_billable boolean DEFAULT false,
  p_extra_discount_pct numeric DEFAULT NULL,
  p_extra_discount_amount numeric DEFAULT NULL,
  p_reason text DEFAULT NULL,
  p_note text DEFAULT NULL,
  p_user_id uuid DEFAULT NULL,
  p_user_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_line public."QuoteLines"%ROWTYPE;
  v_quote_status text;
  v_qty numeric;
  v_base_unit numeric;
  v_base_total numeric;
  v_discount_amount numeric := 0;
  v_final_total numeric;
  v_final_unit numeric;
  v_effective_discount_pct numeric := 0;
  v_existing_meta jsonb;
  v_existing_adjust jsonb;
  v_new_adjust jsonb;
  v_new_meta jsonb;
  v_requires_reason boolean;
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'Quote line id is required';
  END IF;

  IF COALESCE(p_extra_discount_pct, 0) > 0 AND COALESCE(p_extra_discount_amount, 0) > 0 THEN
    RAISE EXCEPTION 'Use either extra discount percent or amount, not both';
  END IF;

  SELECT *
    INTO v_line
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quote line not found';
  END IF;

  SELECT lower(COALESCE(q.status::text, ''))
    INTO v_quote_status
  FROM public."Quotes" q
  WHERE q.id = v_line.quote_id;

  IF v_quote_status NOT IN ('draft', 'pending') THEN
    RAISE EXCEPTION 'Commercial adjustments are only allowed for draft/pending quotes';
  END IF;

  v_requires_reason := COALESCE(p_non_billable, false)
    OR COALESCE(p_extra_discount_pct, 0) > 0
    OR COALESCE(p_extra_discount_amount, 0) > 0;
  IF v_requires_reason AND btrim(COALESCE(p_reason, '')) = '' THEN
    RAISE EXCEPTION 'Reason is required for non-billable or extra discount';
  END IF;

  v_qty := GREATEST(1, COALESCE(v_line.quantity, 1));
  v_existing_meta := COALESCE(v_line.metadata, '{}'::jsonb);
  v_existing_adjust := COALESCE(v_existing_meta->'commercial_adjustment', '{}'::jsonb);

  v_base_unit := COALESCE(
    NULLIF(v_existing_adjust->>'base_unit_dealer_price', '')::numeric,
    v_line.unit_dealer_price_snapshot,
    CASE
      WHEN v_line.dealer_price_total IS NOT NULL THEN v_line.dealer_price_total / v_qty
      WHEN v_line.unit_msrp IS NOT NULL THEN v_line.unit_msrp
      WHEN v_line.msrp IS NOT NULL THEN v_line.msrp / v_qty
      ELSE 0
    END
  );
  v_base_unit := ROUND(COALESCE(v_base_unit, 0), 4);
  v_base_total := ROUND(v_base_unit * v_qty, 4);

  IF COALESCE(p_non_billable, false) THEN
    v_discount_amount := v_base_total;
  ELSIF COALESCE(p_extra_discount_amount, 0) > 0 THEN
    v_discount_amount := LEAST(ROUND(p_extra_discount_amount, 4), v_base_total);
  ELSIF COALESCE(p_extra_discount_pct, 0) > 0 THEN
    v_discount_amount := ROUND(v_base_total * LEAST(100, GREATEST(0, p_extra_discount_pct)) / 100.0, 4);
  ELSE
    v_discount_amount := 0;
  END IF;

  v_final_total := ROUND(GREATEST(v_base_total - v_discount_amount, 0), 4);
  v_final_unit := ROUND(v_final_total / v_qty, 4);
  IF COALESCE(p_non_billable, false)
     OR COALESCE(p_extra_discount_pct, 0) > 0
     OR COALESCE(p_extra_discount_amount, 0) > 0 THEN
    v_effective_discount_pct := CASE
      WHEN v_base_total > 0 THEN ROUND((v_discount_amount / v_base_total) * 100.0, 4)
      ELSE 0
    END;
  ELSE
    v_effective_discount_pct := COALESCE(v_line.dealer_discount_pct, 0);
  END IF;

  v_new_adjust := jsonb_build_object(
    'non_billable', COALESCE(p_non_billable, false),
    'reason', NULLIF(btrim(COALESCE(p_reason, '')), ''),
    'note', NULLIF(btrim(COALESCE(p_note, '')), ''),
    'extra_discount_pct', CASE
      WHEN COALESCE(p_non_billable, false) THEN NULL
      WHEN COALESCE(p_extra_discount_pct, 0) > 0 THEN ROUND(LEAST(100, GREATEST(0, p_extra_discount_pct)), 4)
      ELSE NULL
    END,
    'extra_discount_amount', CASE
      WHEN COALESCE(p_non_billable, false) THEN NULL
      WHEN COALESCE(p_extra_discount_amount, 0) > 0 THEN ROUND(LEAST(p_extra_discount_amount, v_base_total), 4)
      ELSE NULL
    END,
    'effective_discount_pct', v_effective_discount_pct,
    'base_unit_dealer_price', v_base_unit,
    'base_line_total', v_base_total,
    'applied_unit_dealer_price', v_final_unit,
    'applied_line_total', v_final_total,
    'applied_at', now(),
    'applied_by_user_id', p_user_id,
    'applied_by_user_name', p_user_name
  );

  v_new_meta := jsonb_set(v_existing_meta, '{commercial_adjustment}', v_new_adjust, true);
  PERFORM set_config('app.write_source', 'rpc', true);

  UPDATE public."QuoteLines"
  SET
    unit_dealer_price_snapshot = v_final_unit,
    dealer_price_total = v_final_total,
    dealer_discount_pct = v_effective_discount_pct,
    net_price = v_final_total,
    metadata = v_new_meta,
    updated_at = now()
  WHERE id = v_line.id;

  UPDATE public."Quotes"
  SET updated_at = now()
  WHERE id = v_line.quote_id;

  RETURN jsonb_build_object(
    'ok', true,
    'quote_line_id', v_line.id,
    'quote_id', v_line.quote_id,
    'non_billable', COALESCE(p_non_billable, false),
    'base_unit_dealer_price', v_base_unit,
    'base_line_total', v_base_total,
    'applied_unit_dealer_price', v_final_unit,
    'applied_line_total', v_final_total,
    'effective_discount_pct', v_effective_discount_pct
  );
END;
$$;

COMMENT ON FUNCTION public.apply_quote_line_commercial_adjustment(uuid, boolean, numeric, numeric, text, text, uuid, text)
IS 'Applies quote-line commercial adjustment (non-billable or extra discount) without changing internal cost snapshots.';

COMMIT;
