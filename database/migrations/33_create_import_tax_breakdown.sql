-- ====================================================
-- Migration: Create QuoteLineImportTaxBreakdown Table
-- ====================================================
-- Stores breakdown of import tax by category for each quote line
-- Shows which categories contributed to the total import tax
-- ====================================================

-- Enable pgcrypto extension for gen_random_uuid() if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ====================================================
-- STEP 1: Create QuoteLineImportTaxBreakdown table
-- ====================================================

CREATE TABLE IF NOT EXISTS "QuoteLineImportTaxBreakdown" (
    -- Primary key
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign keys
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    quote_line_id uuid NOT NULL REFERENCES "QuoteLines"(id) ON DELETE CASCADE,
    category_id uuid REFERENCES "ItemCategories"(id) ON DELETE SET NULL,
    
    -- Breakdown details
    category_name text, -- Denormalized for quick display
    extended_cost numeric(12,4) NOT NULL DEFAULT 0, -- Total cost for this category
    import_tax_percentage numeric(8,4) NOT NULL DEFAULT 0, -- Tax percentage applied
    import_tax_amount numeric(12,4) NOT NULL DEFAULT 0, -- Tax amount for this category
    
    -- Audit fields
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false
);

-- ====================================================
-- STEP 2: Add constraints (idempotent)
-- ====================================================

-- Ensure all numeric fields are non-negative
DO $$
DECLARE
    v_table_exists boolean;
BEGIN
    -- Check if table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'QuoteLineImportTaxBreakdown'
    ) INTO v_table_exists;
    
    IF v_table_exists THEN
        -- Check and add extended_cost constraint
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conname = 'check_extended_cost_non_negative' 
            AND conrelid = '"QuoteLineImportTaxBreakdown"'::regclass
        ) THEN
            ALTER TABLE "QuoteLineImportTaxBreakdown"
                ADD CONSTRAINT check_extended_cost_non_negative 
                CHECK (extended_cost >= 0);
        END IF;

        -- Check and add import_tax_percentage constraint
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conname = 'check_import_tax_percentage_non_negative' 
            AND conrelid = '"QuoteLineImportTaxBreakdown"'::regclass
        ) THEN
            ALTER TABLE "QuoteLineImportTaxBreakdown"
                ADD CONSTRAINT check_import_tax_percentage_non_negative 
                CHECK (import_tax_percentage >= 0);
        END IF;

        -- Check and add import_tax_amount constraint
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conname = 'check_import_tax_amount_non_negative' 
            AND conrelid = '"QuoteLineImportTaxBreakdown"'::regclass
        ) THEN
            ALTER TABLE "QuoteLineImportTaxBreakdown"
                ADD CONSTRAINT check_import_tax_amount_non_negative 
                CHECK (import_tax_amount >= 0);
        END IF;
    END IF;
END $$;

-- ====================================================
-- STEP 3: Create indexes (idempotent)
-- ====================================================

CREATE INDEX IF NOT EXISTS idx_import_tax_breakdown_quote_line 
    ON "QuoteLineImportTaxBreakdown"(quote_line_id, deleted);

CREATE INDEX IF NOT EXISTS idx_import_tax_breakdown_org_quote_line 
    ON "QuoteLineImportTaxBreakdown"(organization_id, quote_line_id);

CREATE INDEX IF NOT EXISTS idx_import_tax_breakdown_category 
    ON "QuoteLineImportTaxBreakdown"(category_id) WHERE category_id IS NOT NULL;

-- ====================================================
-- STEP 4: Add updated_at trigger (idempotent)
-- ====================================================

-- Create or replace the function (idempotent)
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists, then create (idempotent)
DROP TRIGGER IF EXISTS set_import_tax_breakdown_updated_at ON "QuoteLineImportTaxBreakdown";
CREATE TRIGGER set_import_tax_breakdown_updated_at
    BEFORE UPDATE ON "QuoteLineImportTaxBreakdown"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 5: Enable RLS
-- ====================================================

ALTER TABLE "QuoteLineImportTaxBreakdown" ENABLE ROW LEVEL SECURITY;

-- ====================================================
-- STEP 6: Create RLS policies
-- ====================================================

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "import_tax_breakdown_select_own_org" ON "QuoteLineImportTaxBreakdown";
DROP POLICY IF EXISTS "import_tax_breakdown_insert_own_org" ON "QuoteLineImportTaxBreakdown";
DROP POLICY IF EXISTS "import_tax_breakdown_update_own_org" ON "QuoteLineImportTaxBreakdown";
DROP POLICY IF EXISTS "import_tax_breakdown_delete_own_org" ON "QuoteLineImportTaxBreakdown";

-- SELECT: Users can see breakdown for their organization
CREATE POLICY "import_tax_breakdown_select_own_org"
    ON "QuoteLineImportTaxBreakdown"
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- INSERT: System can insert breakdown (via function)
CREATE POLICY "import_tax_breakdown_insert_own_org"
    ON "QuoteLineImportTaxBreakdown"
    FOR INSERT
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- UPDATE: System can update breakdown
CREATE POLICY "import_tax_breakdown_update_own_org"
    ON "QuoteLineImportTaxBreakdown"
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

-- DELETE: System can delete breakdown
CREATE POLICY "import_tax_breakdown_delete_own_org"
    ON "QuoteLineImportTaxBreakdown"
    FOR DELETE
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- ====================================================
-- STEP 7: Add comments
-- ====================================================

COMMENT ON TABLE "QuoteLineImportTaxBreakdown" IS 'Breakdown of import tax by category for each quote line';
COMMENT ON COLUMN "QuoteLineImportTaxBreakdown".extended_cost IS 'Total cost for items in this category';
COMMENT ON COLUMN "QuoteLineImportTaxBreakdown".import_tax_percentage IS 'Tax percentage applied to this category';
COMMENT ON COLUMN "QuoteLineImportTaxBreakdown".import_tax_amount IS 'Tax amount calculated for this category';

-- ====================================================
-- STEP 8: Final summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '📋 Created:';
    RAISE NOTICE '   - Table: QuoteLineImportTaxBreakdown';
    RAISE NOTICE '   - Indexes: 3';
    RAISE NOTICE '   - Constraints: 3 (non-negative checks)';
    RAISE NOTICE '   - RLS Policies: 4';
END $$;

