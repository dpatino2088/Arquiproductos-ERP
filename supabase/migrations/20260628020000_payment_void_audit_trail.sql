-- Payments: add status + void_reason so void preserves audit trail instead of soft-delete
ALTER TABLE public."Payments"
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS void_reason text;

-- Backfill: deleted payments become status='void'
UPDATE public."Payments" SET status = 'void' WHERE deleted = true AND status = 'active';

-- DealerInvoices: add void_reason as dedicated column
ALTER TABLE public."DealerInvoices"
  ADD COLUMN IF NOT EXISTS void_reason text;

-- Backfill: extract VOID REASON from notes for voided invoices
UPDATE public."DealerInvoices"
SET void_reason = TRIM(SUBSTRING(notes FROM 'VOID REASON: (.+)$'))
WHERE status = 'void' AND notes LIKE '%VOID REASON:%' AND void_reason IS NULL;
