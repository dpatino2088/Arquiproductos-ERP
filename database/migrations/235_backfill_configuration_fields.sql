-- ====================================================
-- Migration 235: Backfill Configuration Fields in QuoteLines
-- ====================================================
-- Infers and sets tube_type and operating_system_variant for existing QuoteLines
-- based on width_m and other available data
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Infer tube_type from operating_system_variant (PRIMARY) or width_m (FALLBACK)
-- ====================================================
-- Rule: Standard M → RTU-42, Standard L → RTU-65
-- Fallback: width < 0.042m = RTU-42, < 0.065m = RTU-65, else RTU-80
-- ====================================================

DO $$
DECLARE
    v_updated_count_variant integer;
    v_updated_count_width integer;
BEGIN
    -- PRIMARY: Infer from operating_system_variant
    UPDATE "QuoteLines"
    SET tube_type = CASE
        WHEN operating_system_variant ILIKE '%standard_m%' OR operating_system_variant ILIKE '%m%' THEN 'RTU-42'
        WHEN operating_system_variant ILIKE '%standard_l%' OR operating_system_variant ILIKE '%l%' THEN 'RTU-65'
        ELSE NULL
    END,
    updated_at = now()
    WHERE deleted = false
        AND tube_type IS NULL
        AND operating_system_variant IS NOT NULL
        AND (product_type ILIKE '%roller%shade%' OR product_type ILIKE '%dual%shade%' OR product_type ILIKE '%triple%shade%');
    
    GET DIAGNOSTICS v_updated_count_variant = ROW_COUNT;
    RAISE NOTICE '✅ Inferred tube_type for % QuoteLines based on operating_system_variant', v_updated_count_variant;
    
    -- FALLBACK: Infer from width_m if operating_system_variant is not available
    UPDATE "QuoteLines"
    SET tube_type = CASE
        WHEN width_m IS NOT NULL AND width_m < 0.042 THEN 'RTU-42'
        WHEN width_m IS NOT NULL AND width_m < 0.065 THEN 'RTU-65'
        WHEN width_m IS NOT NULL THEN 'RTU-80'
        ELSE NULL
    END,
    updated_at = now()
    WHERE deleted = false
        AND tube_type IS NULL
        AND operating_system_variant IS NULL  -- Only use width_m if variant is not set
        AND width_m IS NOT NULL
        AND (product_type ILIKE '%roller%shade%' OR product_type ILIKE '%dual%shade%' OR product_type ILIKE '%triple%shade%');
    
    GET DIAGNOSTICS v_updated_count_width = ROW_COUNT;
    RAISE NOTICE '✅ Inferred tube_type for % QuoteLines based on width_m (fallback)', v_updated_count_width;
END $$;

-- ====================================================
-- STEP 2: Set default operating_system_variant
-- ====================================================
-- Default to 'standard_m' if not set and drive_type is not null
-- ====================================================

DO $$
DECLARE
    v_updated_count integer;
BEGIN
    UPDATE "QuoteLines"
    SET operating_system_variant = 'standard_m',
        updated_at = now()
    WHERE deleted = false
        AND operating_system_variant IS NULL
        AND drive_type IS NOT NULL
        AND (product_type ILIKE '%roller%shade%' OR product_type ILIKE '%dual%shade%' OR product_type ILIKE '%triple%shade%');
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Set default operating_system_variant to standard_m for % QuoteLines', v_updated_count;
END $$;

-- ====================================================
-- STEP 3: Verify backfill results
-- ====================================================

DO $$
DECLARE
    v_total integer;
    v_with_tube_type integer;
    v_with_os_variant integer;
    v_with_both integer;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM "QuoteLines"
    WHERE deleted = false
        AND (product_type ILIKE '%roller%shade%' OR product_type ILIKE '%dual%shade%' OR product_type ILIKE '%triple%shade%')
        AND created_at > NOW() - INTERVAL '30 days';
    
    SELECT COUNT(*) INTO v_with_tube_type
    FROM "QuoteLines"
    WHERE deleted = false
        AND (product_type ILIKE '%roller%shade%' OR product_type ILIKE '%dual%shade%' OR product_type ILIKE '%triple%shade%')
        AND tube_type IS NOT NULL
        AND created_at > NOW() - INTERVAL '30 days';
    
    SELECT COUNT(*) INTO v_with_os_variant
    FROM "QuoteLines"
    WHERE deleted = false
        AND (product_type ILIKE '%roller%shade%' OR product_type ILIKE '%dual%shade%' OR product_type ILIKE '%triple%shade%')
        AND operating_system_variant IS NOT NULL
        AND created_at > NOW() - INTERVAL '30 days';
    
    SELECT COUNT(*) INTO v_with_both
    FROM "QuoteLines"
    WHERE deleted = false
        AND (product_type ILIKE '%roller%shade%' OR product_type ILIKE '%dual%shade%' OR product_type ILIKE '%triple%shade%')
        AND tube_type IS NOT NULL
        AND operating_system_variant IS NOT NULL
        AND created_at > NOW() - INTERVAL '30 days';
    
    RAISE NOTICE '📊 Backfill Results:';
    RAISE NOTICE '  Total QuoteLines: %', v_total;
    RAISE NOTICE '  With tube_type: % (%%%)', v_with_tube_type, ROUND(100.0 * v_with_tube_type / NULLIF(v_total, 0), 2);
    RAISE NOTICE '  With operating_system_variant: % (%%%)', v_with_os_variant, ROUND(100.0 * v_with_os_variant / NULLIF(v_total, 0), 2);
    RAISE NOTICE '  With both: % (%%%)', v_with_both, ROUND(100.0 * v_with_both / NULLIF(v_total, 0), 2);
END $$;

COMMIT;

