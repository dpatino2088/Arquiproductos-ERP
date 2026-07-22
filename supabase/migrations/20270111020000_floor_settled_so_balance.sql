-- Floor the SO-based balance to zero once the order is financially settled.
--
-- After 20270111010000, an order can be fully invoiced + fully paid yet still
-- show a residual SO-based balance equal to the un-invoiceable rounding penny
-- (e.g. SO total 1463.26 vs invoiced 1463.25). That penny is immaterial and can
-- never be collected (payments only apply to issued invoices), so any consumer
-- of balance_due (SalesOrderDetail "Outstanding", the collection badge, etc.)
-- should treat a settled order as $0.00 owed.
--
-- delivery_financials_ok already means: fully invoiced (within rounding) AND all
-- issued invoices paid (within rounding). When true, balance_due = 0.

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
  -- SO-based balance, floored to 0 when the order is settled within rounding.
  CASE
    WHEN (
      (
        (COALESCE(max(so.total_amount), 0::numeric) - COALESCE(sum(di.total), 0::numeric))
        <= LEAST(0.05, 0.005 + 0.01 * count(DISTINCT di.id))
      )
      AND
      (
        (COALESCE(sum(di.total), 0::numeric)
         - COALESCE(sum(pa.applied), 0::numeric)
         - COALESCE(sum(cn.credited), 0::numeric))
        <= LEAST(0.05, 0.005 + 0.01 * count(DISTINCT di.id))
      )
    ) THEN 0::numeric
    ELSE GREATEST(
      COALESCE(max(so.total_amount), 0::numeric)
      - COALESCE(sum(pa.applied), 0::numeric)
      - COALESCE(sum(cn.credited), 0::numeric),
      0::numeric
    )
  END::numeric(14,2) AS balance_due,
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
  COALESCE(max(so.total_amount), 0::numeric)::numeric(14,2) AS so_total,
  COALESCE(sum(cn.credited), 0::numeric)::numeric(14,2) AS total_credited,
  GREATEST(COALESCE(max(so.total_amount), 0::numeric) - COALESCE(sum(di.total), 0::numeric), 0::numeric)::numeric(14,2) AS total_uninvoiced,
  (
    (COALESCE(max(so.total_amount), 0::numeric) - COALESCE(sum(di.total), 0::numeric))
    <= LEAST(0.05, 0.005 + 0.01 * count(DISTINCT di.id))
  ) AS fully_invoiced,
  GREATEST(
    COALESCE(sum(di.total), 0::numeric)
    - COALESCE(sum(pa.applied), 0::numeric)
    - COALESCE(sum(cn.credited), 0::numeric),
    0::numeric
  )::numeric(14,2) AS ar_balance,
  (
    (
      (COALESCE(max(so.total_amount), 0::numeric) - COALESCE(sum(di.total), 0::numeric))
      <= LEAST(0.05, 0.005 + 0.01 * count(DISTINCT di.id))
    )
    AND
    (
      (COALESCE(sum(di.total), 0::numeric)
       - COALESCE(sum(pa.applied), 0::numeric)
       - COALESCE(sum(cn.credited), 0::numeric))
      <= LEAST(0.05, 0.005 + 0.01 * count(DISTINCT di.id))
    )
  ) AS delivery_financials_ok
FROM "DealerInvoices" di
  LEFT JOIN pa_totals pa ON pa.invoice_id = di.id
  LEFT JOIN cn_totals cn ON cn.invoice_id = di.id
  LEFT JOIN "SalesOrders" so ON so.id = di.sales_order_id
WHERE di.sales_order_id IS NOT NULL AND di.deleted = false AND di.status <> 'void'::text
GROUP BY di.sales_order_id, di.organization_id, di.dealer_id;

NOTIFY pgrst, 'reload schema';
