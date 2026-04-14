SET search_path = public;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'confirmed' AND enumtypid = 'manufacturing_order_status'::regtype) THEN
    ALTER TYPE manufacturing_order_status ADD VALUE 'confirmed' AFTER 'draft';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'procurement' AND enumtypid = 'manufacturing_order_status'::regtype) THEN
    ALTER TYPE manufacturing_order_status ADD VALUE 'procurement' AFTER 'confirmed';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'materials_ready' AND enumtypid = 'manufacturing_order_status'::regtype) THEN
    ALTER TYPE manufacturing_order_status ADD VALUE 'materials_ready' AFTER 'procurement';
  END IF;
END $$;;
