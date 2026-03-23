-- Ensure invoices are created atomically with lines (all-or-nothing)
-- and prevent any new invoice from being committed without at least one line.

CREATE OR REPLACE FUNCTION public.create_dealer_invoice_with_lines(
  p_organization_id uuid,
  p_dealer_id uuid,
  p_sales_order_id uuid,
  p_invoice_number text,
  p_issue_date date,
  p_due_date date,
  p_currency_code text,
  p_subtotal numeric,
  p_tax_total numeric,
  p_total numeric,
  p_notes text,
  p_lines jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice_id uuid;
  v_line jsonb;
  v_line_count integer := 0;
  v_sort_order integer;
  v_description text;
  v_qty numeric;
  v_unit_price numeric;
  v_tax_pct numeric;
  v_line_subtotal numeric;
  v_line_tax numeric;
  v_line_total numeric;
BEGIN
  IF NOT public.can_create_financials_org(p_organization_id) THEN
    RAISE EXCEPTION 'Not authorized to create invoices'
      USING ERRCODE = '42501';
  END IF;

  IF p_lines IS NULL OR jsonb_typeof(p_lines) <> 'array' OR jsonb_array_length(p_lines) = 0 THEN
    RAISE EXCEPTION 'Invoice must include at least one line'
      USING ERRCODE = '23514';
  END IF;

  INSERT INTO public."DealerInvoices" (
    organization_id,
    dealer_id,
    sales_order_id,
    invoice_number,
    status,
    issue_date,
    due_date,
    currency_code,
    subtotal,
    tax_total,
    total,
    notes,
    deleted
  )
  VALUES (
    p_organization_id,
    p_dealer_id,
    p_sales_order_id,
    p_invoice_number,
    'draft',
    p_issue_date,
    p_due_date,
    COALESCE(NULLIF(TRIM(p_currency_code), ''), 'USD'),
    COALESCE(p_subtotal, 0),
    COALESCE(p_tax_total, 0),
    COALESCE(p_total, 0),
    NULLIF(TRIM(p_notes), ''),
    false
  )
  RETURNING id INTO v_invoice_id;

  FOR v_line IN
    SELECT value
    FROM jsonb_array_elements(p_lines)
  LOOP
    v_description := NULLIF(TRIM(COALESCE(v_line->>'description', '')), '');
    IF v_description IS NULL THEN
      CONTINUE;
    END IF;

    v_sort_order := COALESCE(NULLIF(v_line->>'sort_order', '')::integer, v_line_count + 1);
    v_qty := COALESCE(NULLIF(v_line->>'qty', '')::numeric, 0);
    v_unit_price := COALESCE(NULLIF(v_line->>'unit_price', '')::numeric, 0);
    v_tax_pct := COALESCE(NULLIF(v_line->>'tax_pct', '')::numeric, 0);
    v_line_subtotal := COALESCE(NULLIF(v_line->>'line_subtotal', '')::numeric, ROUND(v_qty * v_unit_price, 2));
    v_line_tax := COALESCE(NULLIF(v_line->>'line_tax', '')::numeric, ROUND(v_line_subtotal * v_tax_pct, 2));
    v_line_total := COALESCE(NULLIF(v_line->>'line_total', '')::numeric, v_line_subtotal + v_line_tax);

    IF v_qty <= 0 THEN
      RAISE EXCEPTION 'Invoice line qty must be greater than zero'
        USING ERRCODE = '23514';
    END IF;

    INSERT INTO public."DealerInvoiceLines" (
      invoice_id,
      sort_order,
      description,
      qty,
      unit_price,
      tax_pct,
      line_subtotal,
      line_tax,
      line_total
    )
    VALUES (
      v_invoice_id,
      v_sort_order,
      v_description,
      v_qty,
      v_unit_price,
      v_tax_pct,
      v_line_subtotal,
      v_line_tax,
      v_line_total
    );

    v_line_count := v_line_count + 1;
  END LOOP;

  IF v_line_count = 0 THEN
    RAISE EXCEPTION 'Invoice must include at least one valid line'
      USING ERRCODE = '23514';
  END IF;

  RETURN v_invoice_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_dealer_invoice_with_lines(
  uuid, uuid, uuid, text, date, date, text, numeric, numeric, numeric, text, jsonb
) TO authenticated;

CREATE OR REPLACE FUNCTION public.assert_invoice_has_lines()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF COALESCE(NEW.deleted, false) = false THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public."DealerInvoiceLines" l
      WHERE l.invoice_id = NEW.id
    ) THEN
      RAISE EXCEPTION 'Invoice % cannot be saved without lines', NEW.invoice_number
        USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_dealer_invoice_require_lines ON public."DealerInvoices";
CREATE CONSTRAINT TRIGGER trg_dealer_invoice_require_lines
AFTER INSERT ON public."DealerInvoices"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.assert_invoice_has_lines();
