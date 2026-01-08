-- ====================================================
-- Migration 439: Backfill manufacturing_order_id in BomInstances
-- ====================================================
-- OBJETIVO: Para MOs existentes que tienen BomInstances por sales_order_line_id
-- pero sin manufacturing_order_id, actualizar esas filas para vincularlas al MO.
-- ====================================================

SET search_path = public;

BEGIN;

-- ====================================================
-- STEP 1: Update BomInstances that have sales_order_line_id but missing manufacturing_order_id
-- ====================================================

UPDATE "BomInstances" bi
SET 
    manufacturing_order_id = mol.manufacturing_order_id,
    updated_at = now()
FROM "ManufacturingOrderLines" mol
WHERE bi.sales_order_line_id = mol.sales_order_line_id
    AND bi.manufacturing_order_id IS NULL
    AND bi.deleted = false
    AND mol.deleted = false
    AND mol.archived = false;

-- ====================================================
-- STEP 2: Also handle legacy sale_order_line_id (if exists)
-- ====================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances' 
        AND column_name = 'sale_order_line_id'
    ) THEN
        UPDATE "BomInstances" bi
        SET 
            manufacturing_order_id = mol.manufacturing_order_id,
            updated_at = now()
        FROM "ManufacturingOrderLines" mol
        WHERE bi.sale_order_line_id = mol.sales_order_line_id
            AND bi.manufacturing_order_id IS NULL
            AND bi.deleted = false
            AND mol.deleted = false
            AND mol.archived = false;
    END IF;
END $$;

-- ====================================================
-- STEP 3: Report results
-- ====================================================

DO $$
DECLARE
    v_count_updated integer;
    v_count_missing integer;
BEGIN
    SELECT COUNT(*) INTO v_count_updated
    FROM "BomInstances"
    WHERE manufacturing_order_id IS NOT NULL
    AND deleted = false;
    
    SELECT COUNT(*) INTO v_count_missing
    FROM "BomInstances" bi
    WHERE bi.manufacturing_order_id IS NULL
    AND bi.deleted = false
    AND EXISTS (
        SELECT 1 FROM "ManufacturingOrderLines" mol
        WHERE (bi.sales_order_line_id = mol.sales_order_line_id 
               OR (bi.sale_order_line_id IS NOT NULL AND bi.sale_order_line_id = mol.sales_order_line_id))
        AND mol.deleted = false
        AND mol.archived = false
    );
    
    RAISE NOTICE '✅ Backfill complete:';
    RAISE NOTICE '   - BomInstances with manufacturing_order_id: %', v_count_updated;
    RAISE NOTICE '   - BomInstances still missing manufacturing_order_id (may need manual review): %', v_count_missing;
END $$;

COMMIT;

