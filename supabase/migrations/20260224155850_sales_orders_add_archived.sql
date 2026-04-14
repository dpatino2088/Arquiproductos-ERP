-- Dealer can archive SO (not delete). Org users can delete.
ALTER TABLE public."SalesOrders"
  ADD COLUMN IF NOT EXISTS archived boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public."SalesOrders".archived IS 'Set by dealer to archive the order (hide from list). Org users use deleted for hard delete.';;
