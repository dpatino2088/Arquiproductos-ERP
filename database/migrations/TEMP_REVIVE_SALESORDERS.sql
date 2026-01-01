-- ====================================================
-- TEMPORARY FIX: Revive Soft-Deleted SalesOrders (Safe Version)
-- ====================================================
-- Use this ONLY as a temporary fix while migration 213 is being applied
-- This will revive deleted SalesOrders, handling duplicate sale_order_no conflicts
-- ====================================================
-- WARNING: This is a temporary workaround. The proper solution is migration 213.
-- ====================================================

DO $$
DECLARE
    v_conflict_count integer;
    v_revived_count integer;
    v_total_deleted integer;
    v_conflict_rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔍 Checking for conflicts before reviving...';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- Count total deleted SalesOrders
    SELECT COUNT(*) INTO v_total_deleted
    FROM "SalesOrders"
    WHERE deleted = true;
    
    RAISE NOTICE 'Total soft-deleted SalesOrders: %', v_total_deleted;
    
    -- Find conflicts: deleted SalesOrders with sale_order_no that already exists in active ones
    SELECT COUNT(*) INTO v_conflict_count
    FROM "SalesOrders" so_deleted
    WHERE so_deleted.deleted = true
    AND EXISTS (
        SELECT 1
        FROM "SalesOrders" so_active
        WHERE so_active.deleted = false
        AND so_active.organization_id = so_deleted.organization_id
        AND so_active.sale_order_no = so_deleted.sale_order_no
    );
    
    RAISE NOTICE 'Conflicts found (duplicate sale_order_no): %', v_conflict_count;
    RAISE NOTICE '';
    
    -- Show conflicts
    IF v_conflict_count > 0 THEN
        RAISE NOTICE '⚠️  CONFLICTS DETECTED:';
        RAISE NOTICE '';
        
        FOR v_conflict_rec IN
            SELECT 
                so_deleted.id,
                so_deleted.sale_order_no,
                so_deleted.organization_id,
                so_deleted.created_at,
                so_active.id as active_id,
                so_active.created_at as active_created_at
            FROM "SalesOrders" so_deleted
            INNER JOIN "SalesOrders" so_active ON (
                so_active.organization_id = so_deleted.organization_id
                AND so_active.sale_order_no = so_deleted.sale_order_no
                AND so_active.deleted = false
            )
            WHERE so_deleted.deleted = true
            ORDER BY so_deleted.created_at
        LOOP
            RAISE NOTICE '  Conflict: sale_order_no = %', v_conflict_rec.sale_order_no;
            RAISE NOTICE '    - Deleted SO id: % (created: %)', v_conflict_rec.id, v_conflict_rec.created_at;
            RAISE NOTICE '    - Active SO id: % (created: %)', v_conflict_rec.active_id, v_conflict_rec.active_created_at;
            RAISE NOTICE '';
        END LOOP;
        
        RAISE NOTICE '⚠️  Will SKIP conflicting records (keeping only active ones)';
        RAISE NOTICE '';
    END IF;
    
    -- Revive only non-conflicting SalesOrders
    -- IMPORTANT: Only revive ONE record per (organization_id, sale_order_no) combination
    -- If multiple deleted records exist with same sale_order_no, revive only the most recent one
    -- AND only if there's no active record with that sale_order_no
    
    -- First, identify candidates to revive (one per org+number, most recent)
    CREATE TEMP TABLE IF NOT EXISTS candidates_to_revive AS
    WITH ranked_deleted AS (
        SELECT 
            id,
            organization_id,
            sale_order_no,
            created_at,
            ROW_NUMBER() OVER (
                PARTITION BY organization_id, sale_order_no 
                ORDER BY created_at DESC
            ) as rn
        FROM "SalesOrders"
        WHERE deleted = true
    )
    SELECT id
    FROM ranked_deleted
    WHERE rn = 1  -- Only the most recent deleted one per (org, sale_order_no)
    AND NOT EXISTS (
        SELECT 1
        FROM "SalesOrders" so_active
        WHERE so_active.deleted = false
        AND so_active.organization_id = ranked_deleted.organization_id
        AND so_active.sale_order_no = ranked_deleted.sale_order_no
    );
    
    -- Now revive only the candidates
    UPDATE "SalesOrders" so
    SET deleted = false,
        updated_at = NOW()
    FROM candidates_to_revive ctr
    WHERE so.id = ctr.id;
    
    GET DIAGNOSTICS v_revived_count = ROW_COUNT;
    
    -- Clean up temp table
    DROP TABLE IF EXISTS candidates_to_revive;
    
    -- Final count
    SELECT COUNT(*) INTO v_total_deleted
    FROM "SalesOrders"
    WHERE deleted = false;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Revival completed';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Results:';
    RAISE NOTICE '   - Revived: % SalesOrders', v_revived_count;
    RAISE NOTICE '   - Skipped (conflicts): % SalesOrders', v_conflict_count;
    RAISE NOTICE '   - Total active SalesOrders: %', v_total_deleted;
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  REMINDER: This is a temporary fix.';
    RAISE NOTICE '   Apply migration 213 to prevent future auto-deletion.';
    RAISE NOTICE '';
END $$;

