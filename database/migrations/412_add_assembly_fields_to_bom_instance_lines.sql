-- ====================================================
-- Migration: Add Assembly Fields to BomInstanceLines
-- ====================================================
-- Objective: Add source and parent_part_id columns to BomInstanceLines
-- for tracing assembly relationships and avoiding double counting
-- ====================================================

-- Add source column (to distinguish 'bom_component', 'quote_line_component', 'assembly_child')
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'BomInstanceLines'
        AND column_name = 'source'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN source text DEFAULT 'bom_component';
        
        COMMENT ON COLUMN "BomInstanceLines".source IS 
            'Source of this line: bom_component (from BOMTemplate), quote_line_component (from QuoteLineComponents), or assembly_child (expanded from CatalogItemBOMLines)';
    END IF;
END $$;

-- Add parent_part_id column (to link assembly children to their parent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'BomInstanceLines'
        AND column_name = 'parent_part_id'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN parent_part_id uuid REFERENCES "CatalogItems"(id) ON DELETE SET NULL;
        
        COMMENT ON COLUMN "BomInstanceLines".parent_part_id IS 
            'If source=''assembly_child'', this is the parent CatalogItem that was expanded. NULL for direct components.';
        
        CREATE INDEX IF NOT EXISTS idx_bom_instance_lines_parent_part ON "BomInstanceLines"(parent_part_id) WHERE parent_part_id IS NOT NULL;
    END IF;
END $$;

-- Add check constraint for source values
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_schema = 'public'
        AND table_name = 'BomInstanceLines'
        AND constraint_name = 'check_bom_instance_lines_source_valid'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD CONSTRAINT check_bom_instance_lines_source_valid
        CHECK (source IN ('bom_component', 'quote_line_component', 'assembly_child'));
    END IF;
END $$;


