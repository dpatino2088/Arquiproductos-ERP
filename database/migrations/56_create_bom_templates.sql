-- Migration: Create BOMTemplates table and update BOMComponents structure
-- This implements BOM by ProductType instead of by individual item

DO $$
DECLARE
  target_org_id UUID := '4de856e8-36ce-480a-952b-a2f5083c69d6'::UUID;
BEGIN
  -- STEP 1: Create BOMTemplates table
  CREATE TABLE IF NOT EXISTS public."BOMTemplates" (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    product_type_id UUID NOT NULL, -- FK to Profiles (ProductTypes)
    name TEXT, -- Optional: "Roller Shade Standard BOM", "Roller Shade Premium BOM"
    description TEXT,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted BOOLEAN NOT NULL DEFAULT false,
    archived BOOLEAN NOT NULL DEFAULT false,
    
    -- Constraints
    CONSTRAINT fk_bomtemplates_organization 
      FOREIGN KEY (organization_id) 
      REFERENCES public."Organizations"(id) 
      ON DELETE CASCADE,
    CONSTRAINT fk_bomtemplates_product_type 
      FOREIGN KEY (product_type_id) 
      REFERENCES public."Profiles"(id) 
      ON DELETE RESTRICT,
    CONSTRAINT check_bomtemplates_name_not_empty 
      CHECK (name IS NULL OR length(trim(name)) > 0)
  );

  -- STEP 2: Add bom_template_id to BOMComponents
  -- First, check if column exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents' 
    AND column_name = 'bom_template_id'
  ) THEN
    ALTER TABLE public."BOMComponents" 
    ADD COLUMN bom_template_id UUID;
  END IF;

  -- STEP 3: Create foreign key for bom_template_id
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_schema = 'public' 
    AND constraint_name = 'fk_bomcomponents_bom_template'
  ) THEN
    ALTER TABLE public."BOMComponents"
    ADD CONSTRAINT fk_bomcomponents_bom_template
      FOREIGN KEY (bom_template_id)
      REFERENCES public."BOMTemplates"(id)
      ON DELETE CASCADE;
  END IF;

  -- STEP 4: Create indexes
  CREATE INDEX IF NOT EXISTS idx_bomtemplates_organization_id 
    ON public."BOMTemplates"(organization_id);
  CREATE INDEX IF NOT EXISTS idx_bomtemplates_product_type_id 
    ON public."BOMTemplates"(product_type_id);
  CREATE INDEX IF NOT EXISTS idx_bomtemplates_active 
    ON public."BOMTemplates"(organization_id, active) 
    WHERE deleted = false AND active = true;
  
  CREATE INDEX IF NOT EXISTS idx_bomcomponents_bom_template_id 
    ON public."BOMComponents"(bom_template_id);

  -- STEP 5: Enable RLS on BOMTemplates
  ALTER TABLE public."BOMTemplates" ENABLE ROW LEVEL SECURITY;

  -- STEP 6: Create RLS policies for BOMTemplates
  -- Policy: Users can view BOMTemplates for their organization
  DROP POLICY IF EXISTS "Users can view BOMTemplates for their organization" ON public."BOMTemplates";
  CREATE POLICY "Users can view BOMTemplates for their organization"
    ON public."BOMTemplates" FOR SELECT
    USING (
      organization_id IN (
        SELECT organization_id FROM public."OrganizationUsers"
        WHERE user_id = auth.uid() AND deleted = false
      )
    );

  -- Policy: Users can insert BOMTemplates for their organization (if admin/owner)
  DROP POLICY IF EXISTS "Users can insert BOMTemplates for their organization" ON public."BOMTemplates";
  CREATE POLICY "Users can insert BOMTemplates for their organization"
    ON public."BOMTemplates" FOR INSERT
    WITH CHECK (
      organization_id IN (
        SELECT organization_id FROM public."OrganizationUsers"
        WHERE user_id = auth.uid() 
        AND deleted = false
        AND role IN ('owner', 'admin', 'super_admin')
      )
    );

  -- Policy: Users can update BOMTemplates for their organization (if admin/owner)
  DROP POLICY IF EXISTS "Users can update BOMTemplates for their organization" ON public."BOMTemplates";
  CREATE POLICY "Users can update BOMTemplates for their organization"
    ON public."BOMTemplates" FOR UPDATE
    USING (
      organization_id IN (
        SELECT organization_id FROM public."OrganizationUsers"
        WHERE user_id = auth.uid() 
        AND deleted = false
        AND role IN ('owner', 'admin', 'super_admin')
      )
    );

  -- Policy: Users can delete BOMTemplates for their organization (if admin/owner)
  DROP POLICY IF EXISTS "Users can delete BOMTemplates for their organization" ON public."BOMTemplates";
  CREATE POLICY "Users can delete BOMTemplates for their organization"
    ON public."BOMTemplates" FOR DELETE
    USING (
      organization_id IN (
        SELECT organization_id FROM public."OrganizationUsers"
        WHERE user_id = auth.uid() 
        AND deleted = false
        AND role IN ('owner', 'admin', 'super_admin')
      )
    );

  RAISE NOTICE '✅ BOMTemplates table created successfully';
  RAISE NOTICE '✅ bom_template_id column added to BOMComponents';
  RAISE NOTICE '✅ Indexes and RLS policies created';
END $$;





