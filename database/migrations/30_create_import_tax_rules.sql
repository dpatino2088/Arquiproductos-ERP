-- ====================================================
-- Migration: Create ImportTaxRules Table
-- ====================================================
-- Category-based import tax rules
-- Overrides global default from CostSettings
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
-- STEP 1: Create ImportTaxRules table
-- ====================================================

CREATE TABLE IF NOT EXISTS "ImportTaxRules" (
    -- Primary key
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign keys
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    category_id uuid NOT NULL REFERENCES "ItemCategories"(id) ON DELETE RESTRICT,
    
    -- Tax rule
    import_tax_percentage numeric(8,4) NOT NULL DEFAULT 0,
    active boolean NOT NULL DEFAULT true,
    
    -- Audit fields
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    
    -- Unique constraint: one rule per organization + category
    CONSTRAINT unique_org_category UNIQUE (organization_id, category_id)
);

-- ====================================================
-- STEP 2: Add constraints
-- ====================================================

-- Ensure import_tax_percentage is non-negative
ALTER TABLE "ImportTaxRules"
    ADD CONSTRAINT check_import_tax_percentage_non_negative 
    CHECK (import_tax_percentage >= 0);

-- ====================================================
-- STEP 3: Create indexes
-- ====================================================

CREATE INDEX IF NOT EXISTS idx_import_tax_rules_org_category 
    ON "ImportTaxRules"(organization_id, category_id);

CREATE INDEX IF NOT EXISTS idx_import_tax_rules_org_active 
    ON "ImportTaxRules"(organization_id, active, deleted);

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

DROP TRIGGER IF EXISTS set_import_tax_rules_updated_at ON "ImportTaxRules";
CREATE TRIGGER set_import_tax_rules_updated_at
    BEFORE UPDATE ON "ImportTaxRules"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 5: Enable RLS
-- ====================================================

ALTER TABLE "ImportTaxRules" ENABLE ROW LEVEL SECURITY;

-- ====================================================
-- STEP 6: Create RLS policies
-- ====================================================

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "import_tax_rules_select_own_org" ON "ImportTaxRules";
DROP POLICY IF EXISTS "import_tax_rules_insert_own_org" ON "ImportTaxRules";
DROP POLICY IF EXISTS "import_tax_rules_update_own_org" ON "ImportTaxRules";
DROP POLICY IF EXISTS "import_tax_rules_delete_own_org" ON "ImportTaxRules";

-- SELECT: Users can see ImportTaxRules for their organization
CREATE POLICY "import_tax_rules_select_own_org"
    ON "ImportTaxRules"
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- INSERT: Only owners/admins can create ImportTaxRules
CREATE POLICY "import_tax_rules_insert_own_org"
    ON "ImportTaxRules"
    FOR INSERT
    WITH CHECK (
        public.org_is_owner_or_admin(auth.uid(), organization_id)
    );

-- UPDATE: Only owners/admins can update ImportTaxRules
CREATE POLICY "import_tax_rules_update_own_org"
    ON "ImportTaxRules"
    FOR UPDATE
    USING (
        public.org_is_owner_or_admin(auth.uid(), organization_id)
    )
    WITH CHECK (
        public.org_is_owner_or_admin(auth.uid(), organization_id)
    );

-- DELETE: Only owners/admins can delete (soft delete via deleted flag)
CREATE POLICY "import_tax_rules_delete_own_org"
    ON "ImportTaxRules"
    FOR DELETE
    USING (
        public.org_is_owner_or_admin(auth.uid(), organization_id)
    );

-- ====================================================
-- STEP 7: Add comments
-- ====================================================

COMMENT ON TABLE "ImportTaxRules" IS 'Category-based import tax rules that override global default';
COMMENT ON COLUMN "ImportTaxRules".import_tax_percentage IS 'Import tax percentage for this category (e.g., 10.5000 for 10.5%%)';
COMMENT ON COLUMN "ImportTaxRules".active IS 'Whether this rule is currently active';

-- ====================================================
-- STEP 8: Final summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '📋 Created:';
    RAISE NOTICE '   - Table: ImportTaxRules';
    RAISE NOTICE '   - Indexes: 2';
    RAISE NOTICE '   - Constraints: 2 (non-negative check + unique)';
    RAISE NOTICE '   - RLS Policies: 4';
END $$;





