-- ====================================================
-- Migration: Create QuoteLineCosts Table
-- ====================================================
-- Cost Engine v1: Stores full cost breakdown per quote line
-- Table: PascalCase (QuoteLineCosts)
-- Columns: snake_case
-- ====================================================

-- Enable pgcrypto extension for gen_random_uuid() if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ====================================================
-- STEP 0: Ensure RLS helper functions exist
-- ====================================================

-- Function: Check if user is owner or admin (or superadmin)
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
-- STEP 1: Create QuoteLineCosts table
-- ====================================================

CREATE TABLE IF NOT EXISTS "QuoteLineCosts" (
    -- Primary key
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign keys
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    quote_id uuid NOT NULL REFERENCES "Quotes"(id) ON DELETE CASCADE,
    quote_line_id uuid NOT NULL UNIQUE REFERENCES "QuoteLines"(id) ON DELETE CASCADE,
    
    -- Currency
    currency_code text NOT NULL DEFAULT 'USD',
    
    -- Base cost components
    base_material_cost numeric(12,4) NOT NULL DEFAULT 0,
    labor_cost numeric(12,4) NOT NULL DEFAULT 0,
    shipping_cost numeric(12,4) NOT NULL DEFAULT 0,
    import_tax_cost numeric(12,4) NOT NULL DEFAULT 0,
    handling_cost numeric(12,4) NOT NULL DEFAULT 0,
    additional_cost numeric(12,4) NOT NULL DEFAULT 0,
    
    -- Total
    total_cost numeric(12,4) NOT NULL DEFAULT 0,
    
    -- Overrides
    is_overridden boolean NOT NULL DEFAULT false,
    override_reason text,
    override_base_material_cost numeric(12,4),
    override_labor_cost numeric(12,4),
    override_shipping_cost numeric(12,4),
    override_import_tax_cost numeric(12,4),
    override_handling_cost numeric(12,4),
    override_additional_cost numeric(12,4),
    
    -- Audit fields
    calculated_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false
);

-- ====================================================
-- STEP 2: Add constraints
-- ====================================================

-- Ensure all cost fields are non-negative
ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_base_material_cost_non_negative 
    CHECK (base_material_cost >= 0);

ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_labor_cost_non_negative 
    CHECK (labor_cost >= 0);

ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_shipping_cost_non_negative 
    CHECK (shipping_cost >= 0);

ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_import_tax_cost_non_negative 
    CHECK (import_tax_cost >= 0);

ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_handling_cost_non_negative 
    CHECK (handling_cost >= 0);

ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_additional_cost_non_negative 
    CHECK (additional_cost >= 0);

ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_total_cost_non_negative 
    CHECK (total_cost >= 0);

-- Override fields constraints (when not null, must be >= 0)
ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_override_base_material_cost_non_negative 
    CHECK (override_base_material_cost IS NULL OR override_base_material_cost >= 0);

ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_override_labor_cost_non_negative 
    CHECK (override_labor_cost IS NULL OR override_labor_cost >= 0);

ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_override_shipping_cost_non_negative 
    CHECK (override_shipping_cost IS NULL OR override_shipping_cost >= 0);

ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_override_import_tax_cost_non_negative 
    CHECK (override_import_tax_cost IS NULL OR override_import_tax_cost >= 0);

ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_override_handling_cost_non_negative 
    CHECK (override_handling_cost IS NULL OR override_handling_cost >= 0);

ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_override_additional_cost_non_negative 
    CHECK (override_additional_cost IS NULL OR override_additional_cost >= 0);

-- ====================================================
-- STEP 3: Create indexes
-- ====================================================

CREATE INDEX IF NOT EXISTS idx_quote_line_costs_organization_id_quote_id 
    ON "QuoteLineCosts"(organization_id, quote_id);

CREATE INDEX IF NOT EXISTS idx_quote_line_costs_quote_line_id 
    ON "QuoteLineCosts"(quote_line_id);

CREATE INDEX IF NOT EXISTS idx_quote_line_costs_organization_deleted 
    ON "QuoteLineCosts"(organization_id, deleted);

-- ====================================================
-- STEP 4: Add updated_at trigger
-- ====================================================

-- Ensure set_updated_at function exists (from previous migrations)
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_quote_line_costs_updated_at ON "QuoteLineCosts";
CREATE TRIGGER set_quote_line_costs_updated_at
    BEFORE UPDATE ON "QuoteLineCosts"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 5: Enable RLS
-- ====================================================

ALTER TABLE "QuoteLineCosts" ENABLE ROW LEVEL SECURITY;

-- ====================================================
-- STEP 6: Create RLS policies
-- ====================================================

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "quote_line_costs_select_own_org" ON "QuoteLineCosts";
DROP POLICY IF EXISTS "quote_line_costs_insert_own_org" ON "QuoteLineCosts";
DROP POLICY IF EXISTS "quote_line_costs_update_own_org" ON "QuoteLineCosts";
DROP POLICY IF EXISTS "quote_line_costs_delete_own_org" ON "QuoteLineCosts";

-- SELECT: Users can see QuoteLineCosts for their organization
CREATE POLICY "quote_line_costs_select_own_org"
    ON "QuoteLineCosts"
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- INSERT: Users can create QuoteLineCosts for their organization
CREATE POLICY "quote_line_costs_insert_own_org"
    ON "QuoteLineCosts"
    FOR INSERT
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- UPDATE: Users can update QuoteLineCosts for their organization
CREATE POLICY "quote_line_costs_update_own_org"
    ON "QuoteLineCosts"
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
CREATE POLICY "quote_line_costs_delete_own_org"
    ON "QuoteLineCosts"
    FOR DELETE
    USING (
        public.org_is_owner_or_admin(auth.uid(), organization_id)
    );

-- ====================================================
-- STEP 7: Add comments
-- ====================================================

COMMENT ON TABLE "QuoteLineCosts" IS 'Cost breakdown per quote line - Cost Engine v1';
COMMENT ON COLUMN "QuoteLineCosts".base_material_cost IS 'Base material cost from CatalogItems.cost_exw';
COMMENT ON COLUMN "QuoteLineCosts".labor_cost IS 'Calculated labor cost based on CostSettings';
COMMENT ON COLUMN "QuoteLineCosts".shipping_cost IS 'Calculated shipping cost based on CostSettings';
COMMENT ON COLUMN "QuoteLineCosts".import_tax_cost IS 'Calculated import tax based on CostSettings';
COMMENT ON COLUMN "QuoteLineCosts".handling_cost IS 'Handling fee from CostSettings';
COMMENT ON COLUMN "QuoteLineCosts".total_cost IS 'Sum of all cost components (or overrides if is_overridden = true)';
COMMENT ON COLUMN "QuoteLineCosts".is_overridden IS 'If true, use override_* values instead of calculated values';
COMMENT ON COLUMN "QuoteLineCosts".calculated_at IS 'Timestamp when cost was last calculated';

-- ====================================================
-- STEP 8: Final summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '📋 Created:';
    RAISE NOTICE '   - Table: QuoteLineCosts';
    RAISE NOTICE '   - Indexes: 3';
    RAISE NOTICE '   - Constraints: 13 (non-negative checks)';
    RAISE NOTICE '   - RLS Policies: 4';
END $$;

