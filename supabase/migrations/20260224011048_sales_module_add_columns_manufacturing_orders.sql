
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ManufacturingOrders' AND column_name='sales_order_line_id') THEN
    ALTER TABLE "ManufacturingOrders" ADD COLUMN sales_order_line_id uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ManufacturingOrders' AND column_name='mo_type') THEN
    ALTER TABLE "ManufacturingOrders" ADD COLUMN mo_type text NOT NULL DEFAULT 'primary'
      CHECK (mo_type IN ('primary','split','backorder','rework'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ManufacturingOrders' AND column_name='product_id') THEN
    ALTER TABLE "ManufacturingOrders" ADD COLUMN product_id uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ManufacturingOrders' AND column_name='product_name') THEN
    ALTER TABLE "ManufacturingOrders" ADD COLUMN product_name text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ManufacturingOrders' AND column_name='configuration') THEN
    ALTER TABLE "ManufacturingOrders" ADD COLUMN configuration jsonb;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ManufacturingOrders' AND column_name='quantity') THEN
    ALTER TABLE "ManufacturingOrders" ADD COLUMN quantity integer NOT NULL DEFAULT 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ManufacturingOrders' AND column_name='released_at') THEN
    ALTER TABLE "ManufacturingOrders" ADD COLUMN released_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ManufacturingOrders' AND column_name='production_started_at') THEN
    ALTER TABLE "ManufacturingOrders" ADD COLUMN production_started_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ManufacturingOrders' AND column_name='completed_at') THEN
    ALTER TABLE "ManufacturingOrders" ADD COLUMN completed_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ManufacturingOrders' AND column_name='delivered_at') THEN
    ALTER TABLE "ManufacturingOrders" ADD COLUMN delivered_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ManufacturingOrders' AND column_name='notes') THEN
    ALTER TABLE "ManufacturingOrders" ADD COLUMN notes text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ManufacturingOrders' AND column_name='internal_notes') THEN
    ALTER TABLE "ManufacturingOrders" ADD COLUMN internal_notes text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ManufacturingOrders' AND column_name='parent_mo_id') THEN
    ALTER TABLE "ManufacturingOrders" ADD COLUMN parent_mo_id uuid REFERENCES "ManufacturingOrders"(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ManufacturingOrders' AND column_name='created_by') THEN
    ALTER TABLE "ManufacturingOrders" ADD COLUMN created_by uuid;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_mo_status ON "ManufacturingOrders" (status);
CREATE INDEX IF NOT EXISTS idx_mo_sales_order_id ON "ManufacturingOrders" (sales_order_id);
CREATE INDEX IF NOT EXISTS idx_mo_dealer_id ON "ManufacturingOrders" (dealer_id);
;
