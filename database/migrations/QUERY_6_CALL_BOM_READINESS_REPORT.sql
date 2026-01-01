-- ====================================================
-- QUERY 6: Call get_bom_readiness Directly
-- ====================================================
-- This calls the actual function that the dashboard uses
-- Copy and paste this entire query
-- ====================================================

SELECT 
    jsonb_pretty(
        public.get_bom_readiness('4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid)
    ) as bom_readiness_result;

