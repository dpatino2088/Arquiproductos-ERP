-- ====================================================
-- QUERY 12: Verify bom_readiness_report After Fix
-- ====================================================
-- This calls get_bom_readiness again to see if the fix worked
-- ====================================================

SELECT 
    jsonb_pretty(
        public.get_bom_readiness('4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid)
    ) as bom_readiness_result;

