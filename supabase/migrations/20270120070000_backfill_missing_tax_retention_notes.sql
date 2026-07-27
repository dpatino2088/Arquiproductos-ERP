-- Backfill missing ITBMS tax_retention credit notes for retention-agent dealers.
--
-- Symptom: invoices paid at the net amount (total − 50% of ITBMS) stayed
-- "partial" / balance_due > 0 because create_tax_retention_note was never run
-- when the invoice was issued (or was issued before retention support).
--
-- Eligibility (safe):
--   - dealer is_tax_retention_agent
--   - no active tax_retention credit note on the invoice
--   - tax_total > 0
--   - payment already covers the net (total − expected retention) within $0.05
--   - open balance is > 0 and ≤ expected retention + $0.05
--
-- Amount written = open balance (settles the invoice exactly; handles ±$0.01
-- rounding vs ROUND(tax * rate, 2)).

SET search_path = public;

DO $$
DECLARE
  r RECORD;
  v_next integer;
  v_number text;
  v_amount numeric(14,2);
  v_created int := 0;
BEGIN
  FOR r IN
    WITH rates AS (
      SELECT d.id AS dealer_id, d.organization_id, COALESCE(d.tax_retention_rate, 0.5) AS rate
      FROM public."Dealers" d
      WHERE COALESCE(d.is_tax_retention_agent, false) = true
        AND COALESCE(d.deleted, false) = false
    ),
    inv AS (
      SELECT
        di.id AS invoice_id,
        di.organization_id,
        di.dealer_id,
        di.invoice_number,
        di.total,
        di.tax_total,
        rates.rate,
        ROUND(di.tax_total * rates.rate, 2) AS expected_ret,
        COALESCE(pa.applied, 0)::numeric(14,2) AS paid,
        COALESCE(cn.credited, 0)::numeric(14,2) AS credited,
        ROUND(
          di.total - COALESCE(pa.applied, 0) - COALESCE(cn.credited, 0),
          2
        ) AS open_bal
      FROM public."DealerInvoices" di
      JOIN rates ON rates.dealer_id = di.dealer_id
      LEFT JOIN LATERAL (
        SELECT SUM(pa2.applied_amount) AS applied
        FROM public."PaymentApplications" pa2
        WHERE pa2.invoice_id = di.id
      ) pa ON true
      LEFT JOIN LATERAL (
        SELECT SUM(cn2.amount) AS credited
        FROM public."DealerCreditNotes" cn2
        WHERE cn2.invoice_id = di.id
          AND cn2.deleted = false
          AND cn2.status <> 'void'
      ) cn ON true
      WHERE di.deleted = false
        AND di.status <> 'void'
        AND di.tax_total > 0
        AND NOT EXISTS (
          SELECT 1
          FROM public."DealerCreditNotes" x
          WHERE x.invoice_id = di.id
            AND x.kind = 'tax_retention'
            AND x.deleted = false
            AND x.status <> 'void'
        )
    )
    SELECT *
    FROM inv
    WHERE paid >= (total - expected_ret - 0.05)
      AND open_bal > 0.009
      AND open_bal <= expected_ret + 0.05
    ORDER BY organization_id, invoice_number
  LOOP
    v_amount := r.open_bal;

    PERFORM pg_advisory_xact_lock(hashtext('dealer_credit_note_number:' || r.organization_id::text));

    SELECT COALESCE(MAX((regexp_match(credit_note_number, '^RET-(\d+)$'))[1]::int), 99) + 1
      INTO v_next
    FROM public."DealerCreditNotes"
    WHERE organization_id = r.organization_id
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
      r.organization_id, r.dealer_id, r.invoice_id, v_number,
      CURRENT_DATE, v_amount,
      'Retención de Impuesto ITBMS (backfill)',
      'issued', 'tax_retention', false
    );

    -- Trigger on DealerCreditNotes should recompute invoice status → paid.
    -- Call explicitly in case trigger is absent in some environments.
    PERFORM public.compute_invoice_totals(r.invoice_id);

    v_created := v_created + 1;
    RAISE NOTICE 'Created % for % amount=%', v_number, r.invoice_number, v_amount;
  END LOOP;

  RAISE NOTICE 'Tax retention backfill created % credit notes', v_created;
END $$;
