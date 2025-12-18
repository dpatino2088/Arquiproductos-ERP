-- ====================================================
-- Migration: Create CategoryMargins Table
-- ====================================================
-- Stores global margin percentages per category
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Creating CategoryMargins table';
  RAISE NOTICE '====================================================';

  -- Step 1: Create CategoryMargins table
  CREATE TABLE IF NOT EXISTS public."CategoryMargins" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL,
    category_id uuid NOT NULL,
    margin_percentage numeric(8,4) NOT NULL DEFAULT 35.0000,
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    
    -- Constraints
    CONSTRAINT check_margin_percentage_non_negative 
      CHECK (margin_percentage >= 0),
    CONSTRAINT check_margin_percentage_max 
      CHECK (margin_percentage <= 100),
    
    -- Unique constraint: one margin per category per organization
    CONSTRAINT unique_category_margin_per_org 
      UNIQUE (organization_id, category_id),
    
    -- Foreign Keys
    CONSTRAINT fk_category_margins_organization 
      FOREIGN KEY (organization_id) 
      REFERENCES public."Organizations"(id) 
      ON DELETE CASCADE,
    
    CONSTRAINT fk_category_margins_category 
      FOREIGN KEY (category_id) 
      REFERENCES public."ItemCategories"(id) 
      ON DELETE CASCADE
  );

  RAISE NOTICE '✅ Created CategoryMargins table';

  -- Step 2: Create indexes
  CREATE INDEX IF NOT EXISTS idx_category_margins_organization_id 
    ON public."CategoryMargins"(organization_id) 
    WHERE deleted = false;

  CREATE INDEX IF NOT EXISTS idx_category_margins_category_id 
    ON public."CategoryMargins"(category_id) 
    WHERE deleted = false;

  CREATE INDEX IF NOT EXISTS idx_category_margins_active 
    ON public."CategoryMargins"(active) 
    WHERE active = true AND deleted = false;

  RAISE NOTICE '✅ Created indexes';

  -- Step 3: Enable RLS
  ALTER TABLE public."CategoryMargins" ENABLE ROW LEVEL SECURITY;

  RAISE NOTICE '✅ Enabled RLS';

  -- Step 4: Create RLS policies
  -- Policy: Users can view margins for their organization
  DROP POLICY IF EXISTS "Users can view category margins for their organization" ON public."CategoryMargins";
  CREATE POLICY "Users can view category margins for their organization"
    ON public."CategoryMargins"
    FOR SELECT
    USING (
      EXISTS (
        SELECT 1 FROM public."OrganizationUsers" ou
        WHERE ou.organization_id = "CategoryMargins".organization_id
          AND ou.user_id = auth.uid()
          AND ou.deleted = false
      )
    );

  -- Policy: Only owners/admins can insert margins
  DROP POLICY IF EXISTS "Only owners/admins can insert category margins" ON public."CategoryMargins";
  CREATE POLICY "Only owners/admins can insert category margins"
    ON public."CategoryMargins"
    FOR INSERT
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM public."OrganizationUsers" ou
        WHERE ou.organization_id = "CategoryMargins".organization_id
          AND ou.user_id = auth.uid()
          AND ou.role IN ('owner', 'admin')
          AND ou.deleted = false
      )
    );

  -- Policy: Only owners/admins can update margins
  DROP POLICY IF EXISTS "Only owners/admins can update category margins" ON public."CategoryMargins";
  CREATE POLICY "Only owners/admins can update category margins"
    ON public."CategoryMargins"
    FOR UPDATE
    USING (
      EXISTS (
        SELECT 1 FROM public."OrganizationUsers" ou
        WHERE ou.organization_id = "CategoryMargins".organization_id
          AND ou.user_id = auth.uid()
          AND ou.role IN ('owner', 'admin')
          AND ou.deleted = false
      )
    );

  -- Policy: Only owners/admins can delete margins
  DROP POLICY IF EXISTS "Only owners/admins can delete category margins" ON public."CategoryMargins";
  CREATE POLICY "Only owners/admins can delete category margins"
    ON public."CategoryMargins"
    FOR DELETE
    USING (
      EXISTS (
        SELECT 1 FROM public."OrganizationUsers" ou
        WHERE ou.organization_id = "CategoryMargins".organization_id
          AND ou.user_id = auth.uid()
          AND ou.role IN ('owner', 'admin')
          AND ou.deleted = false
      )
    );

  RAISE NOTICE '✅ Created RLS policies';

  -- Step 5: Create trigger to update updated_at
  DROP TRIGGER IF EXISTS trg_category_margins_updated_at ON public."CategoryMargins";
  CREATE TRIGGER trg_category_margins_updated_at
    BEFORE UPDATE ON public."CategoryMargins"
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

  RAISE NOTICE '✅ Created updated_at trigger';

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Migration completed successfully';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Summary:';
  RAISE NOTICE '   - Created CategoryMargins table';
  RAISE NOTICE '   - Added indexes and constraints';
  RAISE NOTICE '   - Enabled RLS with organization-based policies';
  RAISE NOTICE '';
END $$;

