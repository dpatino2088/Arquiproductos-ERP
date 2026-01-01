-- ====================================================
-- Migration: Verify SaleOrders and SaleOrderLines Tables Exist
-- ====================================================
-- This migration verifies that SaleOrders and SaleOrderLines tables exist
-- If they don't exist, it will create them (idempotent)
-- ====================================================

-- Enable pgcrypto extension for gen_random_uuid() if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ====================================================
-- STEP 1: Verify and create SaleOrders table if missing
-- ====================================================

DO $$
BEGIN
    -- Check if SaleOrders table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrders'
    ) THEN
        RAISE NOTICE '⚠️ SaleOrders table does not exist. Creating it...';
        
        -- Create SaleOrders table
        CREATE TABLE "SaleOrders" (
            -- Primary key
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            
            -- Foreign keys
            organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
            quote_id uuid NOT NULL REFERENCES "Quotes"(id) ON DELETE RESTRICT,
            customer_id uuid NOT NULL REFERENCES "DirectoryCustomers"(id) ON DELETE RESTRICT,
            
            -- Sale Order details
            sale_order_no text NOT NULL,
            status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'confirmed', 'in_production', 'shipped', 'delivered', 'cancelled')),
            
            -- Financial information
            currency text NOT NULL DEFAULT 'USD',
            subtotal numeric(12,4) NOT NULL DEFAULT 0,
            tax numeric(12,4) NOT NULL DEFAULT 0,
            discount_amount numeric(12,4) NOT NULL DEFAULT 0,
            total numeric(12,4) NOT NULL DEFAULT 0,
            
            -- Additional metadata
            notes text,
            metadata jsonb DEFAULT '{}'::jsonb,
            
            -- Dates
            order_date date NOT NULL DEFAULT CURRENT_DATE,
            requested_delivery_date date,
            actual_delivery_date date,
            
            -- Audit fields
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            deleted boolean NOT NULL DEFAULT false,
            archived boolean NOT NULL DEFAULT false,
            created_by uuid REFERENCES auth.users(id),
            updated_by uuid REFERENCES auth.users(id)
        );
        
        RAISE NOTICE '✅ SaleOrders table created successfully';
    ELSE
        RAISE NOTICE '✅ SaleOrders table already exists';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Verify and create SaleOrderLines table if missing
-- ====================================================

DO $$
BEGIN
    -- Check if SaleOrderLines table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrderLines'
    ) THEN
        RAISE NOTICE '⚠️ SaleOrderLines table does not exist. Creating it...';
        
        -- Create SaleOrderLines table
        CREATE TABLE "SaleOrderLines" (
            -- Primary key
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            
            -- Foreign keys
            organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
            sale_order_id uuid NOT NULL REFERENCES "SaleOrders"(id) ON DELETE CASCADE,
            quote_line_id uuid REFERENCES "QuoteLines"(id) ON DELETE SET NULL,
            catalog_item_id uuid NOT NULL REFERENCES "CatalogItems"(id) ON DELETE RESTRICT,
            
            -- Line details
            line_number integer NOT NULL,
            description text,
            
            -- Quantity and pricing
            qty numeric(12,4) NOT NULL DEFAULT 1,
            unit_price numeric(12,4) NOT NULL DEFAULT 0,
            discount_percentage numeric(8,4) NOT NULL DEFAULT 0,
            discount_amount numeric(12,4) NOT NULL DEFAULT 0,
            line_total numeric(12,4) NOT NULL DEFAULT 0,
            
            -- Product configuration (copied from QuoteLine)
            width_m numeric(10,4),
            height_m numeric(10,4),
            area text,
            position text,
            collection_name text,
            variant_name text,
            product_type text,
            product_type_id uuid REFERENCES "ProductTypes"(id),
            drive_type text,
            bottom_rail_type text,
            cassette boolean DEFAULT false,
            cassette_type text,
            side_channel boolean DEFAULT false,
            side_channel_type text CHECK (side_channel_type IS NULL OR side_channel_type IN ('side_only', 'side_and_bottom')),
            hardware_color text,
            
            -- Additional metadata
            metadata jsonb DEFAULT '{}'::jsonb,
            
            -- Audit fields
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            deleted boolean NOT NULL DEFAULT false,
            archived boolean NOT NULL DEFAULT false,
            created_by uuid REFERENCES auth.users(id),
            updated_by uuid REFERENCES auth.users(id)
        );
        
        RAISE NOTICE '✅ SaleOrderLines table created successfully';
    ELSE
        RAISE NOTICE '✅ SaleOrderLines table already exists';
    END IF;
END $$;

-- ====================================================
-- STEP 3: Add constraints if they don't exist
-- ====================================================

-- Ensure sale_order_no is unique per organization
CREATE UNIQUE INDEX IF NOT EXISTS uq_sale_orders_org_no 
    ON "SaleOrders"(organization_id, sale_order_no) 
    WHERE deleted = false;

-- Ensure line_number is unique per sale order
CREATE UNIQUE INDEX IF NOT EXISTS uq_sale_order_lines_order_line 
    ON "SaleOrderLines"(sale_order_id, line_number) 
    WHERE deleted = false;

-- Add check constraints if they don't exist
DO $$
BEGIN
    -- Check if constraint exists before adding
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'check_sale_orders_totals_non_negative'
    ) THEN
        ALTER TABLE "SaleOrders"
            ADD CONSTRAINT check_sale_orders_totals_non_negative 
            CHECK (subtotal >= 0 AND tax >= 0 AND discount_amount >= 0 AND total >= 0);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'check_sale_order_lines_qty_non_negative'
    ) THEN
        ALTER TABLE "SaleOrderLines"
            ADD CONSTRAINT check_sale_order_lines_qty_non_negative 
            CHECK (qty >= 0);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'check_sale_order_lines_prices_non_negative'
    ) THEN
        ALTER TABLE "SaleOrderLines"
            ADD CONSTRAINT check_sale_order_lines_prices_non_negative 
            CHECK (unit_price >= 0 AND discount_amount >= 0 AND line_total >= 0);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'check_sale_order_lines_discount_percentage'
    ) THEN
        ALTER TABLE "SaleOrderLines"
            ADD CONSTRAINT check_sale_order_lines_discount_percentage 
            CHECK (discount_percentage >= 0 AND discount_percentage <= 100);
    END IF;
END $$;

-- ====================================================
-- STEP 4: Create indexes if they don't exist
-- ====================================================

CREATE INDEX IF NOT EXISTS idx_sale_orders_org_quote 
    ON "SaleOrders"(organization_id, quote_id);

CREATE INDEX IF NOT EXISTS idx_sale_orders_org_customer 
    ON "SaleOrders"(organization_id, customer_id);

CREATE INDEX IF NOT EXISTS idx_sale_orders_org_status 
    ON "SaleOrders"(organization_id, status) 
    WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_sale_orders_org_deleted 
    ON "SaleOrders"(organization_id, deleted);

CREATE INDEX IF NOT EXISTS idx_sale_order_lines_order 
    ON "SaleOrderLines"(sale_order_id);

CREATE INDEX IF NOT EXISTS idx_sale_order_lines_catalog_item 
    ON "SaleOrderLines"(catalog_item_id);

CREATE INDEX IF NOT EXISTS idx_sale_order_lines_quote_line 
    ON "SaleOrderLines"(quote_line_id) 
    WHERE quote_line_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sale_order_lines_org_deleted 
    ON "SaleOrderLines"(organization_id, deleted);

-- ====================================================
-- STEP 5: Add updated_at trigger
-- ====================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_sale_orders_updated_at ON "SaleOrders";
CREATE TRIGGER set_sale_orders_updated_at
    BEFORE UPDATE ON "SaleOrders"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS set_sale_order_lines_updated_at ON "SaleOrderLines";
CREATE TRIGGER set_sale_order_lines_updated_at
    BEFORE UPDATE ON "SaleOrderLines"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 6: Enable RLS
-- ====================================================

ALTER TABLE "SaleOrders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "SaleOrderLines" ENABLE ROW LEVEL SECURITY;

-- ====================================================
-- STEP 7: Create RLS policies (idempotent)
-- ====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "sale_orders_select_own_org" ON "SaleOrders";
DROP POLICY IF EXISTS "sale_orders_insert_own_org" ON "SaleOrders";
DROP POLICY IF EXISTS "sale_orders_update_own_org" ON "SaleOrders";
DROP POLICY IF EXISTS "sale_orders_delete_own_org" ON "SaleOrders";

DROP POLICY IF EXISTS "sale_order_lines_select_own_org" ON "SaleOrderLines";
DROP POLICY IF EXISTS "sale_order_lines_insert_own_org" ON "SaleOrderLines";
DROP POLICY IF EXISTS "sale_order_lines_update_own_org" ON "SaleOrderLines";
DROP POLICY IF EXISTS "sale_order_lines_delete_own_org" ON "SaleOrderLines";

-- SELECT: Users can see SaleOrders for their organization
CREATE POLICY "sale_orders_select_own_org"
    ON "SaleOrders"
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- INSERT: Users can create SaleOrders for their organization
CREATE POLICY "sale_orders_insert_own_org"
    ON "SaleOrders"
    FOR INSERT
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- UPDATE: Users can update SaleOrders for their organization
CREATE POLICY "sale_orders_update_own_org"
    ON "SaleOrders"
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
CREATE POLICY "sale_orders_delete_own_org"
    ON "SaleOrders"
    FOR DELETE
    USING (
        public.org_is_owner_or_admin(auth.uid(), organization_id)
    );

-- SELECT: Users can see SaleOrderLines for their organization
CREATE POLICY "sale_order_lines_select_own_org"
    ON "SaleOrderLines"
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- INSERT: Users can create SaleOrderLines for their organization
CREATE POLICY "sale_order_lines_insert_own_org"
    ON "SaleOrderLines"
    FOR INSERT
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- UPDATE: Users can update SaleOrderLines for their organization
CREATE POLICY "sale_order_lines_update_own_org"
    ON "SaleOrderLines"
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
CREATE POLICY "sale_order_lines_delete_own_org"
    ON "SaleOrderLines"
    FOR DELETE
    USING (
        public.org_is_owner_or_admin(auth.uid(), organization_id)
    );

-- ====================================================
-- STEP 8: Add comments
-- ====================================================

COMMENT ON TABLE "SaleOrders" IS 'Sale Orders created from approved Quotes';
COMMENT ON COLUMN "SaleOrders".quote_id IS 'Reference to the approved Quote that this Sale Order was created from';
COMMENT ON COLUMN "SaleOrders".status IS 'Order status: draft, confirmed, in_production, shipped, delivered, cancelled';
COMMENT ON COLUMN "SaleOrders".sale_order_no IS 'Unique sale order number per organization';

COMMENT ON TABLE "SaleOrderLines" IS 'Line items for Sale Orders';
COMMENT ON COLUMN "SaleOrderLines".quote_line_id IS 'Reference to the QuoteLine that this SaleOrderLine was created from (optional, for traceability)';
COMMENT ON COLUMN "SaleOrderLines".line_number IS 'Line number within the sale order (1, 2, 3, ...)';

-- ====================================================
-- STEP 9: Final summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration 178 completed successfully!';
    RAISE NOTICE '📋 Verified/Created:';
    RAISE NOTICE '   - Table: SaleOrders';
    RAISE NOTICE '   - Table: SaleOrderLines';
    RAISE NOTICE '   - Indexes: 8';
    RAISE NOTICE '   - Constraints: 5';
    RAISE NOTICE '   - RLS Policies: 8';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️ IMPORTANT: If tables were just created, you may need to refresh the Supabase schema cache.';
    RAISE NOTICE '   This can be done by:';
    RAISE NOTICE '   1. Going to Supabase Dashboard > Settings > API';
    RAISE NOTICE '   2. Clicking "Reload schema" or waiting a few minutes';
    RAISE NOTICE '   3. Or restarting the Supabase project';
END $$;








