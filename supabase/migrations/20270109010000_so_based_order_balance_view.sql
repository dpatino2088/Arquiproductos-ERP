-- Align the sales order financial summary with the SO-based delivery rule.
--
-- Business rule (confirmed with the user): a Sales Order can only be released
-- for delivery when it is 100% invoiced AND 100% paid. The debt/balance a dealer
-- owes is always measured against the SALES ORDER total, not against a single
-- (possibly partial) invoice.
--
-- The server-side delivery gate (get_sales_order_delivery_gate) already computes
-- balance against SO.total_amount. This migration makes the UI-facing view
-- consistent so the dealer/staff always see the SO-based balance instead of the
-- misleading invoice-only balance.
--
-- CREATE OR REPLACE VIEW keeps the first 10 columns in the exact same name/type/
-- order; new columns are appended at the end. The `balance_due` expression is
-- switched from invoice-based to SO-based (same name and numeric(14,2) type).

SET search_path = public;

CREATE OR REPLACE VIEW public.sales_order_financial_summary AS
WITH pa_totals AS (
  SELECT "PaymentApplications".invoice_id,
         sum("PaymentApplications".applied_amount) AS applied
  FROM "PaymentApplications"
  GROUP BY "PaymentApplications".invoice_id
), cn_totals AS (
  SELECT "DealerCreditNotes".invoice_id,
         sum("DealerCreditNotes".amount) AS credited
  FROM "DealerCreditNotes"
  WHERE "DealerCreditNotes".deleted = false
    AND "DealerCreditNotes".status <> 'void'::text
  GROUP BY "DealerCreditNotes".invoice_id
)
SELECT di.sales_order_id,
  di.organization_id,
  di.dealer_id,
  count(DISTINCT di.id)::integer AS invoice_count,
  COALESCE(sum(di.total), 0::numeric)::numeric(14,2) AS total_invoiced,
  COALESCE(sum(pa.applied), 0::numeric)::numeric(14,2) AS total_paid,
  -- SO-based balance: what still must be collected on the whole order.
  GREATEST(
    COALESCE(max(so.total_amount), 0::numeric)
    - COALESCE(sum(pa.applied), 0::numeric)
    - COALESCE(sum(cn.credited), 0::numeric),
    0::numeric
  )::numeric(14,2) AS balance_due,
  CASE
    WHEN COALESCE(sum(di.total), 0::numeric) = 0::numeric THEN 'none'::text
    WHEN (COALESCE(sum(pa.applied), 0::numeric) + COALESCE(sum(cn.credited), 0::numeric)) <= 0::numeric THEN 'issued'::text
    WHEN (COALESCE(sum(pa.applied), 0::numeric) + COALESCE(sum(cn.credited), 0::numeric)) < (COALESCE(sum(di.total), 0::numeric) - 0.005) THEN 'partial'::text
    ELSE 'paid'::text
  END AS invoice_status,
  ( SELECT di2.id
      FROM "DealerInvoices" di2
     WHERE di2.sales_order_id = di.sales_order_id AND di2.deleted = false AND di2.status <> 'void'::text
     ORDER BY di2.created_at DESC
     LIMIT 1) AS latest_invoice_id,
  ( SELECT di2.invoice_number
      FROM "DealerInvoices" di2
     WHERE di2.sales_order_id = di.sales_order_id AND di2.deleted = false AND di2.status <> 'void'::text
     ORDER BY di2.created_at DESC
     LIMIT 1) AS latest_invoice_number,
  -- New (appended) columns:
  COALESCE(max(so.total_amount), 0::numeric)::numeric(14,2) AS so_total,
  COALESCE(sum(cn.credited), 0::numeric)::numeric(14,2) AS total_credited,
  GREATEST(COALESCE(max(so.total_amount), 0::numeric) - COALESCE(sum(di.total), 0::numeric), 0::numeric)::numeric(14,2) AS total_uninvoiced,
  (COALESCE(sum(di.total), 0::numeric) >= (COALESCE(max(so.total_amount), 0::numeric) - 0.005)) AS fully_invoiced,
  -- Invoice-only (AR) balance, kept for accounting displays that need it.
  GREATEST(
    COALESCE(sum(di.total), 0::numeric)
    - COALESCE(sum(pa.applied), 0::numeric)
    - COALESCE(sum(cn.credited), 0::numeric),
    0::numeric
  )::numeric(14,2) AS ar_balance
FROM "DealerInvoices" di
  LEFT JOIN pa_totals pa ON pa.invoice_id = di.id
  LEFT JOIN cn_totals cn ON cn.invoice_id = di.id
  LEFT JOIN "SalesOrders" so ON so.id = di.sales_order_id
WHERE di.sales_order_id IS NOT NULL AND di.deleted = false AND di.status <> 'void'::text
GROUP BY di.sales_order_id, di.organization_id, di.dealer_id;

NOTIFY pgrst, 'reload schema';
