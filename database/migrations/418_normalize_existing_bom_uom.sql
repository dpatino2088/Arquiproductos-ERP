-- ====================================================
-- Migration 418: Normalize Existing BOM UOMs
-- ====================================================
-- Objective: Normalize UOMs in existing BomInstanceLines to canonical form
-- (ft->m, pcs->ea, set->ea) for BOMs generated before the fix
-- ====================================================

DO $$
DECLARE
    v_updated_count integer;
    v_bom_line RECORD;
BEGIN
    RAISE NOTICE '🔧 Starting UOM normalization for existing BomInstanceLines...';
    
    -- Update all BomInstanceLines where uom is not canonical
    UPDATE "BomInstanceLines" bil
    SET 
        uom = public.normalize_uom_to_canonical(bil.uom),
        updated_at = now()
    WHERE bil.deleted = false
      AND bil.uom IS NOT NULL
      AND bil.uom != public.normalize_uom_to_canonical(bil.uom);
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    RAISE NOTICE '✅ Normalized % BomInstanceLines UOMs to canonical form', v_updated_count;
    
    -- Log summary by UOM type
    RAISE NOTICE '';
    RAISE NOTICE '📊 Summary of normalized UOMs:';
    
    FOR v_bom_line IN
        SELECT 
            bil.uom as old_uom,
            public.normalize_uom_to_canonical(bil.uom) as new_uom,
            COUNT(*) as count
        FROM "BomInstanceLines" bil
        WHERE bil.deleted = false
          AND bil.uom IS NOT NULL
          AND bil.uom != public.normalize_uom_to_canonical(bil.uom)
        GROUP BY bil.uom, public.normalize_uom_to_canonical(bil.uom)
        ORDER BY count DESC
    LOOP
        RAISE NOTICE '   % -> %: % lines', v_bom_line.old_uom, v_bom_line.new_uom, v_bom_line.count;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration 418 completed successfully!';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error normalizing BOM UOMs: %', SQLERRM;
END $$;

-- ====================================================
-- Verification Query
-- ====================================================
-- Run this after the migration to verify all UOMs are normalized
-- Expected result: 0 rows (all UOMs should be canonical: m, m2, ea)

SELECT 
    bil.uom,
    public.normalize_uom_to_canonical(bil.uom) as uom_canonical,
    COUNT(*) as line_count,
    CASE 
        WHEN bil.uom != public.normalize_uom_to_canonical(bil.uom) THEN 'NEEDS_NORMALIZATION'
        ELSE 'OK'
    END as status
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bil.deleted = false
  AND bi.deleted = false
GROUP BY bil.uom, public.normalize_uom_to_canonical(bil.uom)
HAVING bil.uom != public.normalize_uom_to_canonical(bil.uom)
ORDER BY line_count DESC;


