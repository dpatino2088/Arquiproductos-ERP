-- ====================================================
-- FIX: CutJobLines foreign key constraint
-- ====================================================
-- The constraint has ON DELETE SET NULL but bom_instance_line_id is NOT NULL
-- This causes errors when BomInstanceLines are deleted
-- Solution: Change to ON DELETE CASCADE
-- ====================================================

-- Drop the existing constraint
ALTER TABLE "CutJobLines" 
DROP CONSTRAINT IF EXISTS fk_cutjoblines_bom_instance_line;

-- Recreate with ON DELETE CASCADE
ALTER TABLE "CutJobLines"
ADD CONSTRAINT fk_cutjoblines_bom_instance_line 
    FOREIGN KEY (bom_instance_line_id) 
    REFERENCES "BomInstanceLines"(id) 
    ON DELETE CASCADE;

COMMENT ON CONSTRAINT fk_cutjoblines_bom_instance_line ON "CutJobLines" IS 
'Foreign key to BomInstanceLines. ON DELETE CASCADE ensures CutJobLines are deleted when BomInstanceLines are deleted (e.g., when BOM is regenerated).';






