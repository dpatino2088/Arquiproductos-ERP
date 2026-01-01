-- ====================================================
-- Migration 379: Simple debug query to test ProductTypes access
-- ====================================================
-- Simple query to verify we can access ProductTypes and count them
-- ====================================================

-- First, let's verify the query works directly:
-- Run this query manually:
/*
SELECT 
    COUNT(*) as total_count,
    jsonb_agg(jsonb_build_object(
        'id', pt.id,
        'name', pt.name,
        'code', pt.code,
        'organization_id', pt.organization_id,
        'deleted', pt.deleted
    )) as product_types
FROM "ProductTypes" pt
WHERE pt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
AND pt.deleted = false;
*/

-- Now create a simpler debug function that returns a table:
CREATE OR REPLACE FUNCTION public.bom_readiness_simple_debug(
    p_organization_id uuid
)
RETURNS TABLE (
    debug_message text,
    product_type_count bigint,
    sample_product_type jsonb
)
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_count bigint;
    v_sample jsonb;
BEGIN
    -- Count ProductTypes
    SELECT COUNT(*) INTO v_count
    FROM "ProductTypes" pt
    WHERE pt.organization_id = p_organization_id
    AND pt.deleted = false;
    
    -- Get sample ProductType
    SELECT jsonb_build_object(
        'id', pt.id,
        'name', pt.name,
        'code', pt.code
    ) INTO v_sample
    FROM "ProductTypes" pt
    WHERE pt.organization_id = p_organization_id
    AND pt.deleted = false
    LIMIT 1;
    
    RETURN QUERY SELECT 
        'Found ProductTypes'::text,
        v_count,
        COALESCE(v_sample, 'null'::jsonb);
END;
$$;

COMMENT ON FUNCTION public.bom_readiness_simple_debug(uuid) IS 
'Simple debug function that returns ProductTypes count as a table (easier to see in Supabase UI).';

