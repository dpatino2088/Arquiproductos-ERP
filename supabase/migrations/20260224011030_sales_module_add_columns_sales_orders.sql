
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='customer_id') THEN
    ALTER TABLE "SalesOrders" ADD COLUMN customer_id uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='contact_id') THEN
    ALTER TABLE "SalesOrders" ADD COLUMN contact_id uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='proposal_id') THEN
    ALTER TABLE "SalesOrders" ADD COLUMN proposal_id uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='payment_status') THEN
    ALTER TABLE "SalesOrders" ADD COLUMN payment_status text NOT NULL DEFAULT 'pending'
      CHECK (payment_status IN ('pending','partial','paid','refunded','overdue'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='priority') THEN
    ALTER TABLE "SalesOrders" ADD COLUMN priority text NOT NULL DEFAULT 'normal';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='subtotal') THEN
    ALTER TABLE "SalesOrders" ADD COLUMN subtotal numeric(12,2);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='tax_amount') THEN
    ALTER TABLE "SalesOrders" ADD COLUMN tax_amount numeric(12,2);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='discount_amount') THEN
    ALTER TABLE "SalesOrders" ADD COLUMN discount_amount numeric(12,2);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='total_amount') THEN
    ALTER TABLE "SalesOrders" ADD COLUMN total_amount numeric(12,2);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='amount_paid') THEN
    ALTER TABLE "SalesOrders" ADD COLUMN amount_paid numeric(12,2) NOT NULL DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='expected_delivery_date') THEN
    ALTER TABLE "SalesOrders" ADD COLUMN expected_delivery_date timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='completed_at') THEN
    ALTER TABLE "SalesOrders" ADD COLUMN completed_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='closed_at') THEN
    ALTER TABLE "SalesOrders" ADD COLUMN closed_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='notes') THEN
    ALTER TABLE "SalesOrders" ADD COLUMN notes text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='internal_notes') THEN
    ALTER TABLE "SalesOrders" ADD COLUMN internal_notes text;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_salesorders_status ON "SalesOrders" (status);
CREATE INDEX IF NOT EXISTS idx_salesorders_payment_status ON "SalesOrders" (payment_status);
CREATE INDEX IF NOT EXISTS idx_salesorders_dealer_id ON "SalesOrders" (dealer_id);
CREATE INDEX IF NOT EXISTS idx_salesorders_customer_id ON "SalesOrders" (customer_id);
CREATE INDEX IF NOT EXISTS idx_salesorders_quote_id ON "SalesOrders" (quote_id);
;
