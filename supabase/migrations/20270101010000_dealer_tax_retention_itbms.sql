-- Panama ITBMS tax retention for dealers.
-- Some dealers are "agentes de retención": they withhold 50% of the 7% ITBMS
-- (i.e. 3.5% of the taxable base). The withheld portion must NOT be treated as
-- an outstanding balance. It is recorded as a dedicated retention note on the
-- invoice (DealerCreditNotes.kind = 'tax_retention'), which both balance views
-- already subtract, so the invoice balance reaches 0.00 once the net is paid and
-- the delivery-note (DN) "paz y salvo" gate is unblocked automatically.

SET search_path = public;

-- 1) Dealer retention profile flags -----------------------------------------
ALTER TABLE public."Dealers"
  ADD COLUMN IF NOT EXISTS is_tax_retention_agent boolean NOT NULL DEFAULT false;

-- Fraction of the ITBMS that is retained (0.5 = 50% of the tax = 3.5% of base).
ALTER TABLE public."Dealers"
  ADD COLUMN IF NOT EXISTS tax_retention_rate numeric(5,4) NOT NULL DEFAULT 0.5;

-- 2) Distinguish tax-retention notes from manual credit notes ----------------
ALTER TABLE public."DealerCreditNotes"
  ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'credit';

-- Only one active retention note per invoice (idempotency guard).
CREATE UNIQUE INDEX IF NOT EXISTS ux_dealer_credit_notes_one_retention_per_invoice
  ON public."DealerCreditNotes" (invoice_id)
  WHERE kind = 'tax_retention' AND deleted = false AND status <> 'void';

-- 3) RPC: create (or return existing) tax-retention note for an invoice -------
CREATE OR REPLACE FUNCTION public.create_tax_retention_note(p_invoice_id uuid)
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

  IF v_tax <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'no_tax');
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

  v_amount := ROUND(v_tax * v_rate, 2);
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

GRANT EXECUTE ON FUNCTION public.create_tax_retention_note(uuid) TO authenticated;
