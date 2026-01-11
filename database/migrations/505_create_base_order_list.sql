-- ====================================================
-- Migration: Create base OrderList table
-- ====================================================
-- OBJETIVO: Crear tabla OrderList (espejo de SalesOrders)
-- REGLA: tracking_status SIEMPRE espejo de SalesOrders.tracking_status
-- ====================================================

BEGIN;

-- Create OrderList table
CREATE TABLE IF NOT EXISTS public."OrderList" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE CASCADE,
    sales_order_id uuid NOT NULL UNIQUE REFERENCES public."SalesOrders"(id) ON DELETE CASCADE,
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

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_order_list_organization_id ON public."OrderList"(organization_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_order_list_sales_order_id ON public."OrderList"(sales_order_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_order_list_tracking_status ON public."OrderList"(tracking_status) WHERE deleted = false;

-- Add comments
COMMENT ON TABLE public."OrderList" IS 'OrderList table - mirror of SalesOrders for tracking. tracking_status always mirrors SalesOrders.tracking_status.';
COMMENT ON COLUMN public."OrderList".sales_order_id IS 'FK to SalesOrders (1:1 unique). OrderList always created with SalesOrder.';
COMMENT ON COLUMN public."OrderList".tracking_status IS 'Tracking status - always mirrors SalesOrders.tracking_status (via trigger).';

-- Enable RLS
ALTER TABLE public."OrderList" ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can read order list for their organizations
DROP POLICY IF EXISTS "Users can read own organization order list" ON public."OrderList";
CREATE POLICY "Users can read own organization order list"
    ON public."OrderList"
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "OrderList".organization_id
            AND ou.user_id = auth.uid()
            AND ou.deleted = false
            AND ou.status = 'active'
        )
        AND deleted = false
    );

-- Users can insert order list (via trigger only)
DROP POLICY IF EXISTS "Users can insert own organization order list" ON public."OrderList";
CREATE POLICY "Users can insert own organization order list"
    ON public."OrderList"
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "OrderList".organization_id
            AND ou.user_id = auth.uid()
            AND ou.deleted = false
            AND ou.status = 'active'
        )
    );

-- Users can update order list in their organizations
DROP POLICY IF EXISTS "Users can update own organization order list" ON public."OrderList";
CREATE POLICY "Users can update own organization order list"
    ON public."OrderList"
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "OrderList".organization_id
            AND ou.user_id = auth.uid()
            AND ou.deleted = false
            AND ou.status = 'active'
        )
        AND deleted = false
    );

-- Trigger to update updated_at
DROP TRIGGER IF EXISTS update_order_list_updated_at ON public."OrderList";
CREATE TRIGGER update_order_list_updated_at
    BEFORE UPDATE ON public."OrderList"
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

COMMIT;
