-- ====================================================
-- QUERY: Get Organization ID
-- ====================================================
-- Run this first to get your organization_id
-- Then use it in QUERY_3_REPLICATE_BOM_READINESS_REPORT.sql
-- ====================================================

-- Simple query to get organization ID (only column we need)
SELECT id
FROM "Organizations"
WHERE deleted = false
LIMIT 10;

