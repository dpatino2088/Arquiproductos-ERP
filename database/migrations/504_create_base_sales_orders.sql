-- ====================================================
-- Migration: Create base SalesOrders table
-- ====================================================
-- OBJETIVO: Crear tabla SalesOrders (1:1 con Quotes)
-- REGLA: SalesOrders SIEMPRE nacen desde Quotes (trigger)
-- ====================================================

BEGIN;

-- Create SalesOrders table
CREATE TABLE IF NOT EXISTS public."SalesOrders" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE CASCADE,
    quote_id uuid NOT NULL UNIQUE REFERENCES public."Quotes"(id) ON DELETE RESTRICT,
    sales_order_no text NOT NULL,
    tracking_status text NOT NULL DEFAULT 'pending_confirmation' CHECK (
        tracking_status IN (
            'pending_confirmation',
            'confirmed',
            'in_production',
            'ready_for_delivery',
            'delivered',
            'canceled'
        )
    ),
    deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Create unique index for sales_order_no per organization
CREATE UNIQUE INDEX IF NOT EXISTS sales_orders_org_so_no_unique
    ON public."SalesOrders" (organization_id, sales_order_no)
    WHERE deleted = false;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_sales_orders_organization_id ON public."SalesOrders"(organization_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_sales_orders_quote_id ON public."SalesOrders"(quote_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_sales_orders_tracking_status ON public."SalesOrders"(tracking_status) WHERE deleted = false;

-- Add comments
COMMENT ON TABLE public."SalesOrders" IS 'SalesOrders table - always created from approved Quotes via trigger';
COMMENT ON COLUMN public."SalesOrders".quote_id IS 'FK to Quotes (1:1 unique). SalesOrder always created from Quote.';
COMMENT ON COLUMN public."SalesOrders".tracking_status IS 'Tracking status - source of truth. Mirrored to OrderList.';

-- Enable RLS
ALTER TABLE public."SalesOrders" ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can read sales orders for their organizations
DROP POLICY IF EXISTS "Users can read own organization sales orders" ON public."SalesOrders";
CREATE POLICY "Users can read own organization sales orders"
    ON public."SalesOrders"
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "SalesOrders".organization_id
            AND ou.user_id = auth.uid()
            AND ou.deleted = false
            AND ou.status = 'active'
        )
        AND deleted = false
    );

-- Users can insert sales orders (via trigger only)
DROP POLICY IF EXISTS "Users can insert own organization sales orders" ON public."SalesOrders";
CREATE POLICY "Users can insert own organization sales orders"
    ON public."SalesOrders"
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "SalesOrders".organization_id
            AND ou.user_id = auth.uid()
            AND ou.deleted = false
            AND ou.status = 'active'
        )
    );

-- Users can update sales orders in their organizations
DROP POLICY IF EXISTS "Users can update own organization sales orders" ON public."SalesOrders";
CREATE POLICY "Users can update own organization sales orders"
    ON public."SalesOrders"
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "SalesOrders".organization_id
            AND ou.user_id = auth.uid()
            AND ou.deleted = false
            AND ou.status = 'active'
        )
        AND deleted = false
    );

-- Trigger to update updated_at
DROP TRIGGER IF EXISTS update_sales_orders_updated_at ON public."SalesOrders";
CREATE TRIGGER update_sales_orders_updated_at
    BEFORE UPDATE ON public."SalesOrders"
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

COMMIT;
