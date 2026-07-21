-- Make ITBMS tax retention robust regardless of how the tax was invoiced.
--
-- Problem: create_tax_retention_note computed the retained amount strictly as
-- invoice.tax_total * rate. When the 7% ITBMS is invoiced as a SEPARATE invoice
-- (a "tax-only" document whose tax_total does not represent the full ITBMS),
-- the auto-computed retention is wrong and the withheld 3.5% stays as an
-- outstanding balance, blocking the delivery gate.
--
-- Fix: allow callers to pass an explicit retained amount (p_amount). When
-- provided, it is used verbatim (and works even if the invoice tax_total is 0).
-- When omitted, behavior is unchanged: amount = ROUND(tax_total * rate, 2).

SET search_path = public;

-- Drop the old single-argument signature to avoid overload ambiguity.
DROP FUNCTION IF EXISTS public.create_tax_retention_note(uuid);

CREATE OR REPLACE FUNCTION public.create_tax_retention_note(
  p_invoice_id uuid,
  p_amount numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org uuid;
  v_dealer uuid;
  v_tax numeric;
  v_status text;
  v_deleted boolean;
  v_is_agent boolean;
  v_rate numeric;
  v_amount numeric;
  v_existing uuid;
  v_next integer;
  v_number text;
  v_cn_id uuid;
BEGIN
  SELECT di.organization_id, di.dealer_id, COALESCE(di.tax_total, 0), di.status, COALESCE(di.deleted, false)
    INTO v_org, v_dealer, v_tax, v_status, v_deleted
  FROM public."DealerInvoices" di
  WHERE di.id = p_invoice_id;

  IF v_org IS NULL THEN
    RAISE EXCEPTION 'Invoice not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.can_create_financials_org(v_org) THEN
    RAISE EXCEPTION 'Not authorized to create credit notes' USING ERRCODE = '42501';
  END IF;

  IF v_deleted OR v_status = 'void' THEN
    RAISE EXCEPTION 'Cannot add a retention note to a void/deleted invoice' USING ERRCODE = '23514';
  END IF;

  SELECT d.is_tax_retention_agent, COALESCE(d.tax_retention_rate, 0.5)
    INTO v_is_agent, v_rate
  FROM public."Dealers" d
  WHERE d.id = v_dealer;

  IF NOT COALESCE(v_is_agent, false) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'dealer_not_retention_agent');
  END IF;

  -- Idempotency: reuse the existing active retention note if present.
  SELECT id INTO v_existing
  FROM public."DealerCreditNotes"
  WHERE invoice_id = p_invoice_id
    AND kind = 'tax_retention'
    AND deleted = false
    AND status <> 'void'
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'credit_note_id', v_existing, 'already_exists', true);
  END IF;

  -- Explicit amount wins (needed when the ITBMS is invoiced separately or when
  -- an operator confirms the exact retained value). Otherwise derive it from tax.
  IF p_amount IS NOT NULL AND p_amount > 0 THEN
    v_amount := ROUND(p_amount, 2);
  ELSE
    IF v_tax <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'no_tax');
    END IF;
    v_amount := ROUND(v_tax * v_rate, 2);
  END IF;

  IF v_amount <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'zero_amount');
  END IF;

  -- Atomic org-scoped numbering for RET-##### (starts at RET-00100).
  PERFORM pg_advisory_xact_lock(hashtext('dealer_credit_note_number:' || v_org::text));

  SELECT COALESCE(MAX((regexp_match(credit_note_number, '^RET-(\d+)$'))[1]::int), 99) + 1
    INTO v_next
  FROM public."DealerCreditNotes"
  WHERE organization_id = v_org
    AND deleted = false
    AND credit_note_number ~ '^RET-\d+$';

  IF v_next IS NULL OR v_next < 100 THEN
    v_next := 100;
  END IF;
  v_number := 'RET-' || lpad(v_next::text, 5, '0');

  INSERT INTO public."DealerCreditNotes" (
    organization_id, dealer_id, invoice_id, credit_note_number,
    issue_date, amount, reason, status, kind, deleted
  ) VALUES (
    v_org, v_dealer, p_invoice_id, v_number,
    CURRENT_DATE, v_amount, 'Retención de Impuesto ITBMS', 'issued', 'tax_retention', false
  )
  RETURNING id INTO v_cn_id;

  RETURN jsonb_build_object(
    'ok', true,
    'credit_note_id', v_cn_id,
    'amount', v_amount,
    'credit_note_number', v_number
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_tax_retention_note(uuid, numeric) TO authenticated;
