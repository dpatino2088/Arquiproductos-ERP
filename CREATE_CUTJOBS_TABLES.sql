-- ====================================================
-- CREATE: CutJobs and CutJobLines tables
-- ====================================================
-- These tables store the cut list for Manufacturing Orders
-- Cut list is generated from BomInstanceLines (1:1 copy)
-- ====================================================

-- ====================================================
-- STEP 1: Create CutJobs table
-- ====================================================

CREATE TABLE IF NOT EXISTS "CutJobs" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL,
    manufacturing_order_id uuid NOT NULL,
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'planned', 'in_progress', 'completed')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    
    -- Foreign keys
    CONSTRAINT fk_cutjobs_organization FOREIGN KEY (organization_id) 
        REFERENCES "Organizations"(id) ON DELETE CASCADE,
    CONSTRAINT fk_cutjobs_manufacturing_order FOREIGN KEY (manufacturing_order_id) 
        REFERENCES "ManufacturingOrders"(id) ON DELETE CASCADE,
    
    -- Unique constraint: one CutJob per ManufacturingOrder
    CONSTRAINT uq_cutjobs_manufacturing_order UNIQUE (manufacturing_order_id, deleted)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_cutjobs_organization ON "CutJobs"(organization_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_cutjobs_manufacturing_order ON "CutJobs"(manufacturing_order_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_cutjobs_status ON "CutJobs"(status) WHERE deleted = false;

-- Comments
COMMENT ON TABLE "CutJobs" IS 'Cut jobs for Manufacturing Orders. One CutJob per MO.';
COMMENT ON COLUMN "CutJobs".status IS 'Status: draft, planned, in_progress, completed';
COMMENT ON COLUMN "CutJobs".manufacturing_order_id IS 'Reference to ManufacturingOrder. One CutJob per MO.';

-- ====================================================
-- STEP 2: Create CutJobLines table
-- ====================================================

CREATE TABLE IF NOT EXISTS "CutJobLines" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    cut_job_id uuid NOT NULL,
    bom_instance_line_id uuid NOT NULL,
    resolved_sku text,
    part_role text,
    qty numeric(10, 3) NOT NULL DEFAULT 0,
    cut_length_mm integer,
    cut_width_mm integer,
    cut_height_mm integer,
    uom text NOT NULL DEFAULT 'ea',
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    
    -- Foreign keys
    CONSTRAINT fk_cutjoblines_cut_job FOREIGN KEY (cut_job_id) 
        REFERENCES "CutJobs"(id) ON DELETE CASCADE,
    CONSTRAINT fk_cutjoblines_bom_instance_line FOREIGN KEY (bom_instance_line_id) 
        REFERENCES "BomInstanceLines"(id) ON DELETE SET NULL,
    
    -- Constraints
    CONSTRAINT chk_cutjoblines_qty_positive CHECK (qty >= 0)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_cutjoblines_cut_job ON "CutJobLines"(cut_job_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_cutjoblines_bom_instance_line ON "CutJobLines"(bom_instance_line_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_cutjoblines_part_role ON "CutJobLines"(part_role) WHERE deleted = false;

-- Comments
COMMENT ON TABLE "CutJobLines" IS 'Individual cut lines for a CutJob. 1:1 copy from BomInstanceLines.';
COMMENT ON COLUMN "CutJobLines".bom_instance_line_id IS 'Reference to BomInstanceLine (source of truth for dimensions)';
COMMENT ON COLUMN "CutJobLines".cut_length_mm IS 'Cut length in mm (copied from BomInstanceLines)';
COMMENT ON COLUMN "CutJobLines".cut_width_mm IS 'Cut width in mm (copied from BomInstanceLines)';
COMMENT ON COLUMN "CutJobLines".cut_height_mm IS 'Cut height in mm (copied from BomInstanceLines)';

-- ====================================================
-- STEP 3: RLS Policies (if RLS is enabled)
-- ====================================================

-- Enable RLS
ALTER TABLE "CutJobs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "CutJobLines" ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view CutJobs for their organization
CREATE POLICY "Users can view CutJobs for their organization"
    ON "CutJobs" FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id FROM "OrganizationUsers"
            WHERE user_id = auth.uid() AND deleted = false
        )
    );

-- Policy: Users can insert CutJobs for their organization
CREATE POLICY "Users can insert CutJobs for their organization"
    ON "CutJobs" FOR INSERT
    WITH CHECK (
        organization_id IN (
            SELECT organization_id FROM "OrganizationUsers"
            WHERE user_id = auth.uid() AND deleted = false
        )
    );

-- Policy: Users can update CutJobs for their organization
CREATE POLICY "Users can update CutJobs for their organization"
    ON "CutJobs" FOR UPDATE
    USING (
        organization_id IN (
            SELECT organization_id FROM "OrganizationUsers"
            WHERE user_id = auth.uid() AND deleted = false
        )
    );

-- Policy: Users can view CutJobLines for their organization
CREATE POLICY "Users can view CutJobLines for their organization"
    ON "CutJobLines" FOR SELECT
    USING (
        cut_job_id IN (
            SELECT id FROM "CutJobs"
            WHERE organization_id IN (
                SELECT organization_id FROM "OrganizationUsers"
                WHERE user_id = auth.uid() AND deleted = false
            )
        )
    );

-- Policy: Users can insert CutJobLines for their organization
CREATE POLICY "Users can insert CutJobLines for their organization"
    ON "CutJobLines" FOR INSERT
    WITH CHECK (
        cut_job_id IN (
            SELECT id FROM "CutJobs"
            WHERE organization_id IN (
                SELECT organization_id FROM "OrganizationUsers"
                WHERE user_id = auth.uid() AND deleted = false
            )
        )
    );

-- Policy: Users can update CutJobLines for their organization
CREATE POLICY "Users can update CutJobLines for their organization"
    ON "CutJobLines" FOR UPDATE
    USING (
        cut_job_id IN (
            SELECT id FROM "CutJobs"
            WHERE organization_id IN (
                SELECT organization_id FROM "OrganizationUsers"
                WHERE user_id = auth.uid() AND deleted = false
            )
        )
    );

-- ====================================================
-- VERIFICATION QUERIES
-- ====================================================

-- Verify tables exist
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name IN ('CutJobs', 'CutJobLines')
ORDER BY table_name, ordinal_position;






