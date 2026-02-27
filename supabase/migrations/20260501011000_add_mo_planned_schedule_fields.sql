ALTER TABLE public."ManufacturingOrders"
  ADD COLUMN IF NOT EXISTS planned_start_at timestamptz NULL,
  ADD COLUMN IF NOT EXISTS planned_end_at timestamptz NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'manufacturing_orders_planned_end_after_start_check'
  ) THEN
    ALTER TABLE public."ManufacturingOrders"
      ADD CONSTRAINT manufacturing_orders_planned_end_after_start_check
      CHECK (
        planned_end_at IS NULL
        OR planned_start_at IS NULL
        OR planned_end_at >= planned_start_at
      );
  END IF;
END $$;
