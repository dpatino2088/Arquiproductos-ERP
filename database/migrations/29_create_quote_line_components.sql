-- ====================================================
-- Migration: Create QuoteLineComponents Table
-- ====================================================
-- Stores REAL SKUs included in each quote line
-- Used for accurate import tax calculation by category
-- ====================================================

-- Enable pgcrypto extension for gen_random_uuid() if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ====================================================
-- STEP 0: Ensure RLS helper functions exist
-- ====================================================

CREATE OR REPLACE FUNCTION public.org_is_owner_or_admin(
  p_user_id uuid,
  p_org_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_role text;
  v_is_superadmin boolean;
BEGIN
  -- Check if user is superadmin
  SELECT EXISTS (
    SELECT 1 
    FROM "PlatformAdmins" 
    WHERE user_id = p_user_id
  ) INTO v_is_superadmin;
  
  IF v_is_superadmin THEN
    RETURN true;
  END IF;
  
  -- Get user's role in organization
  SELECT role INTO v_role
  FROM "OrganizationUsers"
  WHERE user_id = p_user_id
    AND organization_id = p_org_id
    AND deleted = false
  LIMIT 1;
  
  -- Return true if owner or admin
  RETURN v_role IN ('owner', 'admin');
END;
$$;

-- ====================================================
-- STEP 1: Create QuoteLineComponents table
-- ====================================================

CREATE TABLE IF NOT EXISTS "QuoteLineComponents" (
    -- Primary key
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign keys
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    quote_line_id uuid NOT NULL REFERENCES "QuoteLines"(id) ON DELETE CASCADE,
    catalog_item_id uuid NOT NULL REFERENCES "CatalogItems"(id) ON DELETE RESTRICT,
    
    -- Component details
    qty numeric(12,4) NOT NULL DEFAULT 1,
    unit_cost_exw numeric(12,4) NULL, -- Optional: if NULL, use CatalogItems.cost_exw
    
    -- Audit fields
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false
);

-- ====================================================
-- STEP 2: Add constraints
-- ====================================================

-- Ensure qty is non-negative
ALTER TABLE "QuoteLineComponents"
    ADD CONSTRAINT check_qty_non_negative 
    CHECK (qty >= 0);

-- Ensure unit_cost_exw is non-negative when not null
ALTER TABLE "QuoteLineComponents"
    ADD CONSTRAINT check_unit_cost_exw_non_negative 
    CHECK (unit_cost_exw IS NULL OR unit_cost_exw >= 0);

-- ====================================================
-- STEP 3: Create indexes
-- ====================================================

CREATE INDEX IF NOT EXISTS idx_quote_line_components_org_quote_line 
    ON "QuoteLineComponents"(organization_id, quote_line_id);

CREATE INDEX IF NOT EXISTS idx_quote_line_components_catalog_item 
    ON "QuoteLineComponents"(catalog_item_id);

CREATE INDEX IF NOT EXISTS idx_quote_line_components_quote_line_deleted 
    ON "QuoteLineComponents"(quote_line_id, deleted);

-- ====================================================
-- STEP 4: Add updated_at trigger
-- ====================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_quote_line_components_updated_at ON "QuoteLineComponents";
CREATE TRIGGER set_quote_line_components_updated_at
    BEFORE UPDATE ON "QuoteLineComponents"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 5: Enable RLS
-- ====================================================

ALTER TABLE "QuoteLineComponents" ENABLE ROW LEVEL SECURITY;

-- ====================================================
-- STEP 6: Create RLS policies
-- ====================================================

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "quote_line_components_select_own_org" ON "QuoteLineComponents";
DROP POLICY IF EXISTS "quote_line_components_insert_own_org" ON "QuoteLineComponents";
DROP POLICY IF EXISTS "quote_line_components_update_own_org" ON "QuoteLineComponents";
DROP POLICY IF EXISTS "quote_line_components_delete_own_org" ON "QuoteLineComponents";

-- SELECT: Users can see QuoteLineComponents for their organization
CREATE POLICY "quote_line_components_select_own_org"
    ON "QuoteLineComponents"
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- INSERT: Users can create QuoteLineComponents for their organization
CREATE POLICY "quote_line_components_insert_own_org"
    ON "QuoteLineComponents"
    FOR INSERT
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- UPDATE: Users can update QuoteLineComponents for their organization
CREATE POLICY "quote_line_components_update_own_org"
    ON "QuoteLineComponents"
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
CREATE POLICY "quote_line_components_delete_own_org"
    ON "QuoteLineComponents"
    FOR DELETE
    USING (
        public.org_is_owner_or_admin(auth.uid(), organization_id)
    );

-- ====================================================
-- STEP 7: Add comments
-- ====================================================

COMMENT ON TABLE "QuoteLineComponents" IS 'Real SKUs included in each quote line for accurate cost and tax calculation';
COMMENT ON COLUMN "QuoteLineComponents".unit_cost_exw IS 'Optional unit cost. If NULL, uses CatalogItems.cost_exw';
COMMENT ON COLUMN "QuoteLineComponents".qty IS 'Quantity of this component in the quote line';

-- ====================================================
-- STEP 8: Final summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '📋 Created:';
    RAISE NOTICE '   - Table: QuoteLineComponents';
    RAISE NOTICE '   - Indexes: 3';
    RAISE NOTICE '   - Constraints: 2 (non-negative checks)';
    RAISE NOTICE '   - RLS Policies: 4';
END $$;













