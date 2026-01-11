-- ====================================================
-- Migration: Create base Quotes table
-- ====================================================
-- OBJETIVO: Crear tabla Quotes con estructura canónica
-- REGLA: tracking_status solo se actualiza cuando status='approved'
-- ====================================================

BEGIN;

-- Create Quotes table
CREATE TABLE IF NOT EXISTS public."Quotes" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE CASCADE,
    quote_no text NOT NULL,
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'sent', 'approved', 'canceled')),
    tracking_status text CHECK (
        tracking_status IS NULL OR tracking_status IN (
            'pending_confirmation',
            'confirmed',
            'in_production',
            'ready_for_delivery',
            'delivered',
            'canceled'
        )
    ),
    CONSTRAINT quotes_tracking_status_only_when_approved CHECK (
        (status = 'approved' AND tracking_status IS NOT NULL)
        OR
        (status <> 'approved' AND tracking_status IS NULL)
    ),
    customer_id uuid, -- NULL permitido
    contact_id uuid, -- NULL permitido
    created_by_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Create unique index for quote_no per organization
CREATE UNIQUE INDEX IF NOT EXISTS quotes_org_quote_no_unique
    ON public."Quotes" (organization_id, quote_no)
    WHERE deleted = false;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_quotes_organization_id ON public."Quotes"(organization_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_quotes_status ON public."Quotes"(status) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_quotes_tracking_status ON public."Quotes"(tracking_status) WHERE deleted = false AND tracking_status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_quotes_created_by ON public."Quotes"(created_by_user_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_quotes_customer_id ON public."Quotes"(customer_id) WHERE customer_id IS NOT NULL AND deleted = false;

-- Add comments
COMMENT ON TABLE public."Quotes" IS 'Quotes table - quotes are converted to SalesOrders when approved';
COMMENT ON COLUMN public."Quotes".status IS 'Status: draft, sent, approved, canceled';
COMMENT ON COLUMN public."Quotes".tracking_status IS 'Tracking status. Only set when status=approved. NULL otherwise.';
COMMENT ON COLUMN public."Quotes".customer_id IS 'FK to customer (nullable)';
COMMENT ON COLUMN public."Quotes".contact_id IS 'FK to contact (nullable)';

-- Enable RLS
ALTER TABLE public."Quotes" ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can read quotes for their organizations
DROP POLICY IF EXISTS "Users can read own organization quotes" ON public."Quotes";
CREATE POLICY "Users can read own organization quotes"
    ON public."Quotes"
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "Quotes".organization_id
            AND ou.user_id = auth.uid()
            AND ou.deleted = false
            AND ou.status = 'active'
        )
        AND deleted = false
    );

-- Users can insert quotes in their organizations
DROP POLICY IF EXISTS "Users can insert own organization quotes" ON public."Quotes";
CREATE POLICY "Users can insert own organization quotes"
    ON public."Quotes"
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "Quotes".organization_id
            AND ou.user_id = auth.uid()
            AND ou.deleted = false
            AND ou.status = 'active'
        )
        AND created_by_user_id = auth.uid()
    );

-- Users can update quotes in their organizations
DROP POLICY IF EXISTS "Users can update own organization quotes" ON public."Quotes";
CREATE POLICY "Users can update own organization quotes"
    ON public."Quotes"
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "Quotes".organization_id
            AND ou.user_id = auth.uid()
            AND ou.deleted = false
            AND ou.status = 'active'
        )
        AND deleted = false
    );

-- Trigger to update updated_at
DROP TRIGGER IF EXISTS update_quotes_updated_at ON public."Quotes";
CREATE TRIGGER update_quotes_updated_at
    BEFORE UPDATE ON public."Quotes"
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

COMMIT;
