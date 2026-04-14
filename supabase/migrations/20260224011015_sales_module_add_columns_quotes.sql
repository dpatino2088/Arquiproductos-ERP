
-- Add missing columns to Quotes (only if they don't exist)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Quotes' AND column_name='priority') THEN
    ALTER TABLE "Quotes" ADD COLUMN priority text NOT NULL DEFAULT 'normal';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Quotes' AND column_name='subtotal') THEN
    ALTER TABLE "Quotes" ADD COLUMN subtotal numeric(12,2);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Quotes' AND column_name='tax_amount') THEN
    ALTER TABLE "Quotes" ADD COLUMN tax_amount numeric(12,2);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Quotes' AND column_name='total_amount') THEN
    ALTER TABLE "Quotes" ADD COLUMN total_amount numeric(12,2);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Quotes' AND column_name='expires_at') THEN
    ALTER TABLE "Quotes" ADD COLUMN expires_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Quotes' AND column_name='approved_at') THEN
    ALTER TABLE "Quotes" ADD COLUMN approved_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Quotes' AND column_name='approved_by') THEN
    ALTER TABLE "Quotes" ADD COLUMN approved_by uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Quotes' AND column_name='converted_at') THEN
    ALTER TABLE "Quotes" ADD COLUMN converted_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Quotes' AND column_name='internal_notes') THEN
    ALTER TABLE "Quotes" ADD COLUMN internal_notes text;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_quotes_status ON "Quotes" (status);
CREATE INDEX IF NOT EXISTS idx_quotes_dealer_id ON "Quotes" (dealer_id);
CREATE INDEX IF NOT EXISTS idx_quotes_customer_id ON "Quotes" (customer_id);
;
