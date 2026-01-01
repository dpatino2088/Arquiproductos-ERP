-- ====================================================
-- CREATE: generate_cut_list_for_manufacturing_order function
-- ====================================================
-- This function generates a cut list from BomInstanceLines
-- Rules:
-- - Only executes if MO.status = 'planned'
-- - Creates 1 CutJob per MO if not exists
-- - Idempotent: deletes previous lines
-- - Copies 1:1 from BomInstanceLines
-- - Does NOT modify dimensions
-- - Does NOT change MO status
-- - Raises error if no valid BomInstanceLines exist
-- ====================================================

CREATE OR REPLACE FUNCTION public.generate_cut_list_for_manufacturing_order(
    p_manufacturing_order_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mo_record RECORD;
    v_cut_job_id uuid;
    v_bom_line_record RECORD;
    v_lines_copied integer := 0;
    v_organization_id uuid;
BEGIN
    -- ====================================================
    -- STEP 1: Validate ManufacturingOrder exists and status = 'planned'
    -- ====================================================
    
    SELECT 
        mo.id,
        mo.sale_order_id,
        mo.status,
        mo.organization_id
    INTO v_mo_record
    FROM "ManufacturingOrders" mo
    WHERE mo.id = p_manufacturing_order_id
    AND mo.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder % not found', p_manufacturing_order_id;
    END IF;
    
    IF v_mo_record.status != 'planned' THEN
        RAISE EXCEPTION 'ManufacturingOrder % status must be "planned" to generate cut list. Current status: %', 
            p_manufacturing_order_id, v_mo_record.status;
    END IF;
    
    v_organization_id := v_mo_record.organization_id;
    
    IF v_organization_id IS NULL THEN
        RAISE EXCEPTION 'ManufacturingOrder % has no organization_id', p_manufacturing_order_id;
    END IF;
    
    RAISE NOTICE '🔧 Generating cut list for ManufacturingOrder % (status: %)', 
        p_manufacturing_order_id, v_mo_record.status;
    
    -- ====================================================
    -- STEP 2: Get or create CutJob
    -- ====================================================
    
    SELECT id INTO v_cut_job_id
    FROM "CutJobs"
    WHERE manufacturing_order_id = p_manufacturing_order_id
    AND deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        -- Create new CutJob
        INSERT INTO "CutJobs" (
            organization_id,
            manufacturing_order_id,
            status,
            created_at,
            updated_at,
            deleted
        ) VALUES (
            v_organization_id,
            p_manufacturing_order_id,
            'draft',
            now(),
            now(),
            false
        ) RETURNING id INTO v_cut_job_id;
        
        RAISE NOTICE '✅ Created CutJob % for ManufacturingOrder %', v_cut_job_id, p_manufacturing_order_id;
    ELSE
        RAISE NOTICE '✅ CutJob % already exists for ManufacturingOrder %', v_cut_job_id, p_manufacturing_order_id;
    END IF;
    
    -- ====================================================
    -- STEP 3: Delete existing CutJobLines (idempotent)
    -- ====================================================
    
    DELETE FROM "CutJobLines"
    WHERE cut_job_id = v_cut_job_id
    AND deleted = false;
    
    RAISE NOTICE '🧹 Deleted existing CutJobLines for CutJob %', v_cut_job_id;
    
    -- ====================================================
    -- STEP 4: Copy BomInstanceLines to CutJobLines (1:1)
    -- ====================================================
    
    FOR v_bom_line_record IN
        SELECT 
            bil.id as bom_instance_line_id,
            bil.resolved_sku,
            bil.part_role,
            bil.qty,
            bil.cut_length_mm,
            bil.cut_width_mm,
            bil.cut_height_mm,
            bil.uom,
            bil.calc_notes as notes,
            bi.sale_order_line_id,
            sol.sale_order_id
        FROM "BomInstanceLines" bil
        INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
        INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
        INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = sol.sale_order_id
        WHERE mo.id = p_manufacturing_order_id
        AND bil.deleted = false
        AND bi.deleted = false
        AND sol.deleted = false
        AND mo.deleted = false
        ORDER BY bil.part_role, bil.resolved_sku, bil.id
    LOOP
        BEGIN
            INSERT INTO "CutJobLines" (
                cut_job_id,
                bom_instance_line_id,
                resolved_sku,
                part_role,
                qty,
                cut_length_mm,
                cut_width_mm,
                cut_height_mm,
                uom,
                notes,
                created_at,
                deleted
            ) VALUES (
                v_cut_job_id,
                v_bom_line_record.bom_instance_line_id,
                v_bom_line_record.resolved_sku,
                v_bom_line_record.part_role,
                v_bom_line_record.qty,
                v_bom_line_record.cut_length_mm,
                v_bom_line_record.cut_width_mm,
                v_bom_line_record.cut_height_mm,
                v_bom_line_record.uom,
                v_bom_line_record.notes,
                now(),
                false
            );
            
            v_lines_copied := v_lines_copied + 1;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '⚠️ Error copying BomInstanceLine % to CutJobLines: % (SQLSTATE: %)', 
                    v_bom_line_record.bom_instance_line_id, SQLERRM, SQLSTATE;
        END;
    END LOOP;
    
    -- ====================================================
    -- STEP 5: Validate that lines were copied
    -- ====================================================
    
    IF v_lines_copied = 0 THEN
        RAISE EXCEPTION 'No valid BomInstanceLines found for ManufacturingOrder %. Cannot generate cut list.', 
            p_manufacturing_order_id;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Cut List Generation Complete';
    RAISE NOTICE '   ManufacturingOrder: %', p_manufacturing_order_id;
    RAISE NOTICE '   CutJob: %', v_cut_job_id;
    RAISE NOTICE '   Lines copied: %', v_lines_copied;
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in generate_cut_list_for_manufacturing_order: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
        RAISE;
END;
$$;

COMMENT ON FUNCTION public.generate_cut_list_for_manufacturing_order(uuid) IS 
'Generates a cut list for a ManufacturingOrder by copying BomInstanceLines to CutJobLines.
Rules:
- Only executes if MO.status = "planned"
- Creates 1 CutJob per MO if not exists
- Idempotent: deletes previous lines before insert
- Copies 1:1 from BomInstanceLines (no dimension modifications)
- Does NOT change MO status
- Raises error if no valid BomInstanceLines exist';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.generate_cut_list_for_manufacturing_order(uuid) TO authenticated;

-- ====================================================
-- VERIFICATION QUERY
-- ====================================================
-- Run this after calling the function to verify cut list was created
/*
SELECT 
    cj.id as cut_job_id,
    cj.manufacturing_order_id,
    cj.status as cut_job_status,
    COUNT(cjl.id) as cut_lines_count
FROM "CutJobs" cj
LEFT JOIN "CutJobLines" cjl ON cjl.cut_job_id = cj.id AND cjl.deleted = false
WHERE cj.manufacturing_order_id = 'YOUR_MO_ID_HERE'
AND cj.deleted = false
GROUP BY cj.id, cj.manufacturing_order_id, cj.status;
*/






