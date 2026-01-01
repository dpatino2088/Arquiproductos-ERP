-- ====================================================
-- Migration 317: Final Verification - SalesOrder Creation
-- ====================================================

-- Query 1: Verify trigger is enabled
SELECT 
    tgname,
    CASE tgenabled
        WHEN 'O' THEN '✅ Enabled'
        WHEN 'D' THEN '❌ Disabled'
        WHEN 'R' THEN '⚠️ Replica'
        WHEN 'A' THEN '⚠️ Always'
        ELSE '⚠️ Unknown (' || tgenabled::text || ')'
    END as trigger_status,
    tgenabled as raw_value
FROM pg_trigger 
WHERE tgname = 'trg_on_quote_approved_create_operational_docs';

-- Query 2: Check for duplicate quotes (same quote_no)
SELECT 
    quote_no,
    COUNT(*) as duplicate_count,
    STRING_AGG(id::text, ', ') as quote_ids,
    STRING_AGG(status::text, ', ') as statuses,
    STRING_AGG(deleted::text, ', ') as deleted_flags
FROM "Quotes"
WHERE quote_no = 'QT-000004'
GROUP BY quote_no
HAVING COUNT(*) > 1;

-- Query 3: Current status of QT-000004 (only non-deleted, most recent)
SELECT 
    q.id,
    q.quote_no,
    q.status,
    q.deleted,
    q.created_at,
    so.id as sales_order_id,
    so.sale_order_no,
    so.status as so_status,
    CASE 
        WHEN q.status IS NOT NULL 
        AND (q.status::text ILIKE 'approved' OR q.status::text = 'Approved')
        AND so.id IS NULL THEN '❌ PROBLEM: Approved but no SalesOrder'
        WHEN q.status IS NOT NULL 
        AND (q.status::text ILIKE 'approved' OR q.status::text = 'Approved')
        AND so.id IS NOT NULL THEN '✅ OK: Approved with SalesOrder'
        ELSE 'ℹ️ Not approved (no SalesOrder needed)'
    END as verification_status
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000004'
AND q.deleted = false
ORDER BY q.created_at DESC
LIMIT 1;

-- Query 4: All approved quotes - summary
SELECT 
    COUNT(*) FILTER (WHERE so.id IS NOT NULL) as approved_with_so,
    COUNT(*) FILTER (WHERE so.id IS NULL) as approved_without_so,
    COUNT(*) as total_approved,
    CASE 
        WHEN COUNT(*) FILTER (WHERE so.id IS NULL) = 0 THEN '✅ All approved quotes have SalesOrders'
        ELSE '❌ Some approved quotes missing SalesOrders'
    END as overall_status
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status IS NOT NULL
AND (q.status::text ILIKE 'approved' OR q.status::text = 'Approved')
AND q.deleted = false;

-- Query 5: List approved quotes without SalesOrder (if any)
SELECT 
    q.id,
    q.quote_no,
    q.status,
    q.created_at,
    q.organization_id
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status IS NOT NULL
AND (q.status::text ILIKE 'approved' OR q.status::text = 'Approved')
AND q.deleted = false
AND so.id IS NULL
ORDER BY q.created_at DESC;


