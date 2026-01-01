-- ====================================================
-- Script: Regenerate BOM Categories
-- ====================================================
-- This script:
-- 1. Updates the derive_category_code_from_role function
-- 2. Regenerates category_code for all BomInstanceLines using the new function
-- ====================================================

-- Step 1: Update the function (idempotent)
CREATE OR REPLACE FUNCTION public.derive_category_code_from_role(
    p_component_role text
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_component_role IS NULL THEN
        RETURN 'accessory';
    END IF;
    
    -- Case-insensitive matching
    -- Fabric
    IF LOWER(p_component_role) LIKE '%fabric%' THEN
        RETURN 'fabric';
    
    -- Tube
    ELSIF LOWER(p_component_role) LIKE '%tube%' THEN
        RETURN 'tube';
    
    -- Motor / Drive
    ELSIF LOWER(p_component_role) LIKE '%motor%' 
       OR LOWER(p_component_role) LIKE '%drive%'
       OR LOWER(p_component_role) LIKE '%operating_system_drive%' THEN
        RETURN 'motor';
    
    -- Bracket
    ELSIF LOWER(p_component_role) LIKE '%bracket%' THEN
        RETURN 'bracket';
    
    -- Cassette
    ELSIF LOWER(p_component_role) LIKE '%cassette%' THEN
        RETURN 'cassette';
    
    -- Side Channel (includes side_channel_profile, side_channel_cover, etc.)
    ELSIF LOWER(p_component_role) LIKE '%side_channel%' 
       OR LOWER(p_component_role) LIKE '%side channel%' THEN
        RETURN 'side_channel';
    
    -- Bottom Rail / Bottom Channel (includes bottom_rail_profile, bottom_rail_end_cap, bottom_channel, etc.)
    ELSIF LOWER(p_component_role) LIKE '%bottom_rail%'
       OR LOWER(p_component_role) LIKE '%bottom rail%'
       OR LOWER(p_component_role) LIKE '%bottom_channel%'
       OR LOWER(p_component_role) LIKE '%bottom channel%' THEN
        RETURN 'bottom_channel';
    
    -- Default: accessory
    ELSE
        RETURN 'accessory';
    END IF;
END;
$$;

COMMENT ON FUNCTION public.derive_category_code_from_role IS 
    'Derives category_code from component_role using pattern matching. Maps new BOM roles: bottom_rail_profile, bottom_rail_end_cap, side_channel_profile, side_channel_cover, etc.';

-- Step 2: Regenerate category_code for all BomInstanceLines
DO $$
DECLARE
    v_updated_count integer;
    v_total_lines integer;
    rec record;
BEGIN
    RAISE NOTICE '🔄 Starting BOM category regeneration...';
    
    -- Count total lines to update
    SELECT COUNT(*) INTO v_total_lines
    FROM "BomInstanceLines"
    WHERE deleted = false;
    
    RAISE NOTICE '📊 Found % BomInstanceLines to update', v_total_lines;
    
    -- Regenerate category_code for all BomInstanceLines
    RAISE NOTICE '🔄 Regenerating category_code for all BomInstanceLines...';
    
    UPDATE "BomInstanceLines" bil
    SET 
        category_code = public.derive_category_code_from_role(bil.part_role),
        updated_at = NOW()
    WHERE 
        bil.deleted = false
        AND (
            -- Only update if category_code would change
            bil.category_code IS DISTINCT FROM public.derive_category_code_from_role(bil.part_role)
        );
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    RAISE NOTICE '✅ Updated % BomInstanceLines with new category_code', v_updated_count;
    
    -- Step 2: Count total lines to update
    SELECT COUNT(*) INTO v_total_lines
    FROM "BomInstanceLines"
    WHERE deleted = false;
    
    RAISE NOTICE '📊 Found % BomInstanceLines to update', v_total_lines;
    
    -- Step 3: Regenerate category_code for all BomInstanceLines
    RAISE NOTICE '🔄 Step 2: Regenerating category_code for all BomInstanceLines...';
    
    UPDATE "BomInstanceLines" bil
    SET 
        category_code = public.derive_category_code_from_role(bil.part_role),
        updated_at = NOW()
    WHERE 
        bil.deleted = false
        AND (
            -- Only update if category_code would change
            bil.category_code IS DISTINCT FROM public.derive_category_code_from_role(bil.part_role)
        );
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    RAISE NOTICE '✅ Updated % BomInstanceLines with new category_code', v_updated_count;
    
    -- Step 4: Show summary by category
    RAISE NOTICE '';
    RAISE NOTICE '📊 Summary by category_code:';
    
    FOR rec IN
        SELECT 
            category_code,
            COUNT(*) as count
        FROM "BomInstanceLines"
        WHERE deleted = false
        GROUP BY category_code
        ORDER BY count DESC
    LOOP
        RAISE NOTICE '   - %: % lines', rec.category_code, rec.count;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✨ BOM category regeneration completed successfully!';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Next steps:';
    RAISE NOTICE '   1. Check Manufacturing Order BOM tabs to verify all components are visible';
    RAISE NOTICE '   2. Verify that components are correctly grouped by category';
    RAISE NOTICE '   3. If some BOMs are still missing components, you may need to regenerate them from QuoteLines';
    
END $$;

