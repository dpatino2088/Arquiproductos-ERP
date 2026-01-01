-- ====================================================
-- Migration: Create ManufacturingOrders Table
-- ====================================================
-- This migration creates the ManufacturingOrders table for production management
-- ====================================================

-- Enable pgcrypto extension for gen_random_uuid() if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ====================================================
-- STEP 1: Create ManufacturingOrders table
-- ====================================================

CREATE TABLE IF NOT EXISTS "ManufacturingOrders" (
    -- Primary key
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign keys
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    sale_order_id uuid NOT NULL REFERENCES "SaleOrders"(id) ON DELETE RESTRICT,
    
    -- Manufacturing Order details
    manufacturing_order_no text NOT NULL,
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'planned', 'in_production', 'completed', 'cancelled')),
    priority text DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    
    -- Scheduling
    scheduled_start_date date,
    scheduled_end_date date,
    actual_start_date date,
    actual_end_date date,
    
    -- Additional metadata
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb,
    
    -- Audit fields
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    created_by uuid REFERENCES auth.users(id),
    updated_by uuid REFERENCES auth.users(id)
);

-- ====================================================
-- STEP 2: Add constraints
-- ====================================================

-- Ensure manufacturing_order_no is unique per organization
CREATE UNIQUE INDEX IF NOT EXISTS uq_manufacturing_orders_org_no 
    ON "ManufacturingOrders"(organization_id, manufacturing_order_no) 
    WHERE deleted = false;

-- Index for sale_order_id lookups
CREATE INDEX IF NOT EXISTS idx_manufacturing_orders_sale_order 
    ON "ManufacturingOrders"(sale_order_id);

-- Index for organization and status
CREATE INDEX IF NOT EXISTS idx_manufacturing_orders_org_status 
    ON "ManufacturingOrders"(organization_id, status) 
    WHERE deleted = false;

-- Index for scheduling
CREATE INDEX IF NOT EXISTS idx_manufacturing_orders_scheduled_dates 
    ON "ManufacturingOrders"(scheduled_start_date, scheduled_end_date) 
    WHERE deleted = false AND scheduled_start_date IS NOT NULL;

-- ====================================================
-- STEP 3: Add updated_at trigger
-- ====================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_manufacturing_orders_updated_at ON "ManufacturingOrders";
CREATE TRIGGER set_manufacturing_orders_updated_at
    BEFORE UPDATE ON "ManufacturingOrders"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 4: Enable RLS
-- ====================================================

ALTER TABLE "ManufacturingOrders" ENABLE ROW LEVEL SECURITY;

-- ====================================================
-- STEP 5: Create RLS policies
-- ====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "manufacturing_orders_select_own_org" ON "ManufacturingOrders";
DROP POLICY IF EXISTS "manufacturing_orders_insert_own_org" ON "ManufacturingOrders";
DROP POLICY IF EXISTS "manufacturing_orders_update_own_org" ON "ManufacturingOrders";
DROP POLICY IF EXISTS "manufacturing_orders_delete_own_org" ON "ManufacturingOrders";

-- SELECT: Users can see ManufacturingOrders for their organization
CREATE POLICY "manufacturing_orders_select_own_org"
    ON "ManufacturingOrders"
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- INSERT: Users can create ManufacturingOrders for their organization
CREATE POLICY "manufacturing_orders_insert_own_org"
    ON "ManufacturingOrders"
    FOR INSERT
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- UPDATE: Users can update ManufacturingOrders for their organization
CREATE POLICY "manufacturing_orders_update_own_org"
    ON "ManufacturingOrders"
    FOR UPDATE
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    )
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- DELETE: Only owners/admins can delete (soft delete via deleted flag)
CREATE POLICY "manufacturing_orders_delete_own_org"
    ON "ManufacturingOrders"
    FOR DELETE
    USING (
        public.org_is_owner_or_admin(auth.uid(), organization_id)
    );

-- ====================================================
-- STEP 6: Add comments
-- ====================================================

COMMENT ON TABLE "ManufacturingOrders" IS 'Manufacturing Orders created from Sale Orders';
COMMENT ON COLUMN "ManufacturingOrders".sale_order_id IS 'Reference to the Sale Order that this Manufacturing Order is based on';
COMMENT ON COLUMN "ManufacturingOrders".status IS 'Order status: draft, planned, in_production, completed, cancelled';
COMMENT ON COLUMN "ManufacturingOrders".manufacturing_order_no IS 'Unique manufacturing order number per organization';
COMMENT ON COLUMN "ManufacturingOrders".priority IS 'Order priority: low, normal, high, urgent';

-- ====================================================
-- STEP 7: Final summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration 181 completed successfully!';
    RAISE NOTICE '📋 Created:';
    RAISE NOTICE '   - Table: ManufacturingOrders';
    RAISE NOTICE '   - Indexes: 4';
    RAISE NOTICE '   - Constraints: 3';
    RAISE NOTICE '   - RLS Policies: 4';
END $$;








