-- ====================================================
-- Migration: Create CostSettings Table
-- ====================================================
-- Cost Engine v1: Organization-level default cost settings
-- Table: PascalCase (CostSettings)
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

-- Function: Check if user is owner or superadmin
CREATE OR REPLACE FUNCTION public.org_is_owner_or_superadmin(
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
  
  -- Return true if owner
  RETURN v_role = 'owner';
END;
$$;

-- ====================================================
-- STEP 1: Create CostSettings table
-- ====================================================

CREATE TABLE IF NOT EXISTS "CostSettings" (
    -- Primary key
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign key (unique: one setting per organization)
    organization_id uuid NOT NULL UNIQUE REFERENCES "Organizations"(id) ON DELETE CASCADE,
    
    -- Currency
    currency_code text NOT NULL DEFAULT 'USD',
    
    -- Labor settings
    labor_rate_per_hour numeric(12,4) NOT NULL DEFAULT 0,
    default_labor_minutes_per_unit numeric(12,4) NOT NULL DEFAULT 0,
    
    -- Shipping settings
    shipping_base_cost numeric(12,4) NOT NULL DEFAULT 0,
    shipping_cost_per_kg numeric(12,4) NOT NULL DEFAULT 0,
    
    -- Tax and handling
    import_tax_percent numeric(8,4) NOT NULL DEFAULT 0,
    handling_fee numeric(12,4) NOT NULL DEFAULT 0,
    
    -- Audit fields
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false
);

-- ====================================================
-- STEP 2: Add constraints
-- ====================================================

-- Ensure all numeric fields are non-negative
ALTER TABLE "CostSettings"
    ADD CONSTRAINT check_labor_rate_per_hour_non_negative 
    CHECK (labor_rate_per_hour >= 0);

ALTER TABLE "CostSettings"
    ADD CONSTRAINT check_default_labor_minutes_per_unit_non_negative 
    CHECK (default_labor_minutes_per_unit >= 0);

ALTER TABLE "CostSettings"
    ADD CONSTRAINT check_shipping_base_cost_non_negative 
    CHECK (shipping_base_cost >= 0);

ALTER TABLE "CostSettings"
    ADD CONSTRAINT check_shipping_cost_per_kg_non_negative 
    CHECK (shipping_cost_per_kg >= 0);

ALTER TABLE "CostSettings"
    ADD CONSTRAINT check_import_tax_percent_non_negative 
    CHECK (import_tax_percent >= 0);

ALTER TABLE "CostSettings"
    ADD CONSTRAINT check_handling_fee_non_negative 
    CHECK (handling_fee >= 0);

-- ====================================================
-- STEP 3: Create indexes
-- ====================================================

CREATE INDEX IF NOT EXISTS idx_cost_settings_organization_id 
    ON "CostSettings"(organization_id);

CREATE INDEX IF NOT EXISTS idx_cost_settings_organization_deleted 
    ON "CostSettings"(organization_id, deleted);

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

DROP TRIGGER IF EXISTS set_cost_settings_updated_at ON "CostSettings";
CREATE TRIGGER set_cost_settings_updated_at
    BEFORE UPDATE ON "CostSettings"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 5: Enable RLS
-- ====================================================

ALTER TABLE "CostSettings" ENABLE ROW LEVEL SECURITY;

-- ====================================================
-- STEP 6: Create RLS policies
-- ====================================================

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "cost_settings_select_own_org" ON "CostSettings";
DROP POLICY IF EXISTS "cost_settings_insert_own_org" ON "CostSettings";
DROP POLICY IF EXISTS "cost_settings_update_own_org" ON "CostSettings";
DROP POLICY IF EXISTS "cost_settings_delete_own_org" ON "CostSettings";

-- SELECT: Users can see CostSettings for their organization
CREATE POLICY "cost_settings_select_own_org"
    ON "CostSettings"
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

-- INSERT: Only owners/admins can create CostSettings
CREATE POLICY "cost_settings_insert_own_org"
    ON "CostSettings"
    FOR INSERT
    WITH CHECK (
        public.org_is_owner_or_admin(auth.uid(), organization_id)
    );

-- UPDATE: Only owners/admins can update CostSettings
CREATE POLICY "cost_settings_update_own_org"
    ON "CostSettings"
    FOR UPDATE
    USING (
        public.org_is_owner_or_admin(auth.uid(), organization_id)
    )
    WITH CHECK (
        public.org_is_owner_or_admin(auth.uid(), organization_id)
    );

-- DELETE: Only owners can delete (soft delete via deleted flag)
CREATE POLICY "cost_settings_delete_own_org"
    ON "CostSettings"
    FOR DELETE
    USING (
        public.org_is_owner_or_superadmin(auth.uid(), organization_id)
    );

-- ====================================================
-- STEP 7: Add comments
-- ====================================================

COMMENT ON TABLE "CostSettings" IS 'Organization-level default cost settings for Cost Engine v1';
COMMENT ON COLUMN "CostSettings".labor_rate_per_hour IS 'Hourly labor rate in organization currency';
COMMENT ON COLUMN "CostSettings".default_labor_minutes_per_unit IS 'Default labor time per unit (in minutes)';
COMMENT ON COLUMN "CostSettings".shipping_base_cost IS 'Base shipping cost per shipment';
COMMENT ON COLUMN "CostSettings".shipping_cost_per_kg IS 'Additional shipping cost per kilogram';
COMMENT ON COLUMN "CostSettings".import_tax_percent IS 'Import tax percentage (e.g., 10.5 for 10.5%%)';
COMMENT ON COLUMN "CostSettings".handling_fee IS 'Fixed handling fee per item';

-- ====================================================
-- STEP 8: Final summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '📋 Created:';
    RAISE NOTICE '   - Table: CostSettings';
    RAISE NOTICE '   - Indexes: 2';
    RAISE NOTICE '   - Constraints: 6 (non-negative checks)';
    RAISE NOTICE '   - RLS Policies: 4';
END $$;

