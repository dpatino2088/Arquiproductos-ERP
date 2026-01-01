-- ====================================================
-- QUERY 13: Debug Fixed Components Count
-- ====================================================
-- This shows exactly which components are being counted
-- and why they are valid or invalid
-- ====================================================

SELECT 
    product_type_name,
    component_role,
    is_fixed,
    is_valid,
    validation_reason,
    COUNT(*) as component_count
FROM public.bom_readiness_report_debug_fixed('4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid)
WHERE product_type_name = 'Roller Shade'
GROUP BY 
    product_type_name,
    component_role,
    is_fixed,
    is_valid,
    validation_reason
ORDER BY 
    is_fixed DESC,
    is_valid DESC,
    component_role;

-- Also show all individual components:
SELECT 
    product_type_name,
    component_role,
    component_item_id,
    is_fixed,
    is_valid,
    validation_reason
FROM public.bom_readiness_report_debug_fixed('4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid)
WHERE product_type_name = 'Roller Shade'
ORDER BY 
    is_fixed DESC,
    is_valid DESC,
    component_role;

