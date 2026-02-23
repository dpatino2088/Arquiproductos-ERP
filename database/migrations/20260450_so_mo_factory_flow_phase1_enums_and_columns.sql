-- ====================================================
-- Migration: SO/MO Factory Flow Phase 1 — Enums & New Columns
-- ====================================================
-- Creates new enums and adds columns for order_status, payment_status,
-- production_status, mo_type. Does NOT drop legacy columns yet.
-- ====================================================

SET search_path = public;

-- ====================================================
-- STEP 1: Create enums
-- ====================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_status_so') THEN
    CREATE TYPE order_status_so AS ENUM (
      'Open', 'On Hold', 'Cancelled', 'Completed', 'Closed'
    );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status_so') THEN
    CREATE TYPE payment_status_so AS ENUM (
      'Deposit Pending', 'Deposit Paid', 'Balance Pending', 'Paid in Full'
    );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'mo_type_enum') THEN
    CREATE TYPE mo_type_enum AS ENUM (
      'PRIMARY', 'SPLIT', 'BACKORDER', 'REWORK'
    );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'production_status_mo') THEN
    CREATE TYPE production_status_mo AS ENUM (
      'Pending Review', 'Planned', 'In Production',
      'Completed', 'Ready for Pickup', 'Delivered'
    );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'priority_code_enum') THEN
    CREATE TYPE priority_code_enum AS ENUM (
      'Low', 'Normal', 'High', 'Rush'
    );
  END IF;
END $$;

-- ====================================================
-- STEP 2: SalesOrders — Add new columns
-- ====================================================

ALTER TABLE public."SalesOrders"
  ADD COLUMN IF NOT EXISTS order_status order_status_so DEFAULT 'Open',
  ADD COLUMN IF NOT EXISTS order_status_reason text,
  ADD COLUMN IF NOT EXISTS order_status_changed_at timestamptz,
  ADD COLUMN IF NOT EXISTS order_status_changed_by_user_id uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS payment_status payment_status_so DEFAULT 'Deposit Pending',
  ADD COLUMN IF NOT EXISTS payment_status_reason text,
  ADD COLUMN IF NOT EXISTS payment_status_changed_at timestamptz,
  ADD COLUMN IF NOT EXISTS payment_status_changed_by_user_id uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS priority_code priority_code_enum DEFAULT 'Normal',
  ADD COLUMN IF NOT EXISTS priority_rank integer,
  ADD COLUMN IF NOT EXISTS requested_ship_date date;

-- dealer_id: add if not exists (company_id may have been renamed)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'SalesOrders' AND column_name = 'dealer_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'SalesOrders' AND column_name = 'company_id'
  ) THEN
    ALTER TABLE public."SalesOrders" ADD COLUMN dealer_id uuid REFERENCES public."Dealers"(id);
  ELSIF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'SalesOrders' AND column_name = 'dealer_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'SalesOrders' AND column_name = 'company_id'
  ) THEN
    ALTER TABLE public."SalesOrders" RENAME COLUMN company_id TO dealer_id;
  END IF;
EXCEPTION
  WHEN undefined_object THEN NULL; -- Dealers table may not exist
  WHEN undefined_column THEN NULL;
END $$;

-- Migrate existing status → order_status
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT id, status, tracking_status
    FROM public."SalesOrders"
    WHERE deleted = false
    AND (order_status IS NULL OR order_status = 'Open')
    AND (
      status IS NOT NULL OR tracking_status IS NOT NULL
    )
  ) LOOP
    UPDATE public."SalesOrders" so
    SET order_status = CASE
      WHEN COALESCE(r.status::text, r.tracking_status::text) IN ('delivered', 'Delivered') THEN 'Completed'::order_status_so
      WHEN COALESCE(r.status::text, r.tracking_status::text) IN ('cancelled', 'Cancelled', 'canceled', 'Canceled') THEN 'Cancelled'::order_status_so
      ELSE 'Open'::order_status_so
    END,
    order_status_changed_at = COALESCE(so.updated_at, now())
    WHERE so.id = r.id;
  END LOOP;
END $$;

-- ====================================================
-- STEP 3: ManufacturingOrders — Add new columns
-- ====================================================

ALTER TABLE public."ManufacturingOrders"
  ADD COLUMN IF NOT EXISTS mo_type mo_type_enum DEFAULT 'PRIMARY',
  ADD COLUMN IF NOT EXISTS production_status production_status_mo DEFAULT 'Pending Review',
  ADD COLUMN IF NOT EXISTS production_status_reason text,
  ADD COLUMN IF NOT EXISTS status_changed_at timestamptz,
  ADD COLUMN IF NOT EXISTS status_changed_by_user_id uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS priority_code priority_code_enum DEFAULT 'Normal',
  ADD COLUMN IF NOT EXISTS priority_rank integer,
  ADD COLUMN IF NOT EXISTS notes text;

-- dealer_id for MO
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ManufacturingOrders' AND column_name = 'dealer_id'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'ManufacturingOrders' AND column_name = 'company_id'
    ) THEN
      ALTER TABLE public."ManufacturingOrders" RENAME COLUMN company_id TO dealer_id;
    ELSE
      ALTER TABLE public."ManufacturingOrders" ADD COLUMN dealer_id uuid REFERENCES public."Dealers"(id);
    END IF;
  END IF;
EXCEPTION
  WHEN undefined_object THEN NULL;
  WHEN undefined_column THEN NULL;
END $$;

-- Migrate status → production_status
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT id, status
    FROM public."ManufacturingOrders"
    WHERE deleted = false
    AND (production_status IS NULL OR production_status = 'Pending Review')
    AND status IS NOT NULL
  ) LOOP
    UPDATE public."ManufacturingOrders" mo
    SET production_status = CASE
      WHEN r.status::text IN ('draft', 'planned') THEN 'Planned'::production_status_mo
      WHEN r.status::text = 'in_production' THEN 'In Production'::production_status_mo
      WHEN r.status::text = 'completed' THEN 'Completed'::production_status_mo
      WHEN r.status::text = 'cancelled' THEN 'Completed'::production_status_mo
      ELSE 'Pending Review'::production_status_mo
    END,
    status_changed_at = COALESCE(mo.updated_at, now())
    WHERE mo.id = r.id;
  END LOOP;
END $$;

-- Backfill dealer_id on MO from SO
UPDATE public."ManufacturingOrders" mo
SET dealer_id = so.dealer_id
FROM public."SalesOrders" so
WHERE mo.sales_order_id = so.id
  AND mo.dealer_id IS NULL
  AND so.dealer_id IS NOT NULL;

-- Backfill dealer_id on SO from Quote (Quotes has dealer_id or company_id)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Quotes' AND column_name='dealer_id') THEN
    UPDATE public."SalesOrders" so
    SET dealer_id = q.dealer_id
    FROM public."Quotes" q
    WHERE so.quote_id = q.id AND so.dealer_id IS NULL AND q.dealer_id IS NOT NULL;
  ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Quotes' AND column_name='company_id') THEN
    UPDATE public."SalesOrders" so
    SET dealer_id = q.company_id
    FROM public."Quotes" q
    WHERE so.quote_id = q.id AND so.dealer_id IS NULL AND q.company_id IS NOT NULL;
  END IF;
END $$;

-- ====================================================
-- STEP 4: ManufacturingOrderLines — Add configured_product_id, quantity
-- ====================================================

ALTER TABLE public."ManufacturingOrderLines"
  ADD COLUMN IF NOT EXISTS configured_product_id uuid REFERENCES public."ConfiguredProducts"(id),
  ADD COLUMN IF NOT EXISTS quantity numeric(12,4) DEFAULT 1;

-- Backfill configured_product_id from SalesOrderLine -> QuoteLine
UPDATE public."ManufacturingOrderLines" mol
SET configured_product_id = ql.configured_product_id,
    quantity = COALESCE(sol.quantity, sol.qty, sol.computed_qty, mol.quantity, 1)
FROM public."SalesOrderLines" sol
LEFT JOIN public."QuoteLines" ql ON ql.id = sol.quote_line_id
WHERE mol.sales_order_line_id = sol.id
  AND (mol.configured_product_id IS NULL OR mol.quantity IS NULL);
