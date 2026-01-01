-- ====================================================
-- Migration 247: Fix Tube Type Logic
-- ====================================================
-- Corrects the logic: tube_type should be inferred from operating_system_variant
-- Standard M → RTU-42, Standard L → RTU-65
-- width_m should only be used as fallback or capacity validation
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Update QuoteLines with correct tube_type based on operating_system_variant
-- ====================================================

DO $$
DECLARE
    v_updated_count integer;
BEGIN
    -- Update: Standard M → RTU-42, Standard L → RTU-65
    UPDATE "QuoteLines"
    SET tube_type = CASE
        WHEN operating_system_variant ILIKE '%standard_m%' OR operating_system_variant ILIKE '%m%' THEN 'RTU-42'
        WHEN operating_system_variant ILIKE '%standard_l%' OR operating_system_variant ILIKE '%l%' THEN 'RTU-65'
        ELSE tube_type  -- Keep existing if variant doesn't match
    END,
    updated_at = now()
    WHERE deleted = false
        AND operating_system_variant IS NOT NULL
        AND (
            -- Only update if tube_type is NULL or doesn't match the variant
            tube_type IS NULL
            OR (operating_system_variant ILIKE '%standard_m%' AND tube_type NOT IN ('RTU-42', 'RTU-38'))
            OR (operating_system_variant ILIKE '%standard_l%' AND tube_type NOT IN ('RTU-65', 'RTU-60'))
        )
        AND (product_type ILIKE '%roller%shade%' OR product_type ILIKE '%dual%shade%' OR product_type ILIKE '%triple%shade%');
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Updated tube_type for % QuoteLines based on operating_system_variant', v_updated_count;
END $$;

-- ====================================================
-- STEP 2: For QuoteLines without operating_system_variant, infer from width_m as fallback
-- ====================================================

DO $$
DECLARE
    v_updated_count integer;
BEGIN
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
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Updated tube_type for % QuoteLines based on width_m (fallback)', v_updated_count;
END $$;

-- ====================================================
-- STEP 3: Update the backfill function logic in 235 for future use
-- ====================================================
-- Note: This is just documentation - the actual backfill was already run
-- Future backfills should use operating_system_variant as primary source
-- ====================================================

-- ====================================================
-- STEP 4: Verify the corrections
-- ====================================================

DO $$
DECLARE
    v_total integer;
    v_standard_m_with_rtu42 integer;
    v_standard_l_with_rtu65 integer;
    v_mismatches integer;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM "QuoteLines"
    WHERE deleted = false
        AND operating_system_variant IS NOT NULL
        AND (product_type ILIKE '%roller%shade%' OR product_type ILIKE '%dual%shade%' OR product_type ILIKE '%triple%shade%')
        AND created_at > NOW() - INTERVAL '30 days';
    
    SELECT COUNT(*) INTO v_standard_m_with_rtu42
    FROM "QuoteLines"
    WHERE deleted = false
        AND operating_system_variant ILIKE '%standard_m%'
        AND tube_type IN ('RTU-42', 'RTU-38')
        AND (product_type ILIKE '%roller%shade%' OR product_type ILIKE '%dual%shade%' OR product_type ILIKE '%triple%shade%')
        AND created_at > NOW() - INTERVAL '30 days';
    
    SELECT COUNT(*) INTO v_standard_l_with_rtu65
    FROM "QuoteLines"
    WHERE deleted = false
        AND operating_system_variant ILIKE '%standard_l%'
        AND tube_type IN ('RTU-65', 'RTU-60')
        AND (product_type ILIKE '%roller%shade%' OR product_type ILIKE '%dual%shade%' OR product_type ILIKE '%triple%shade%')
        AND created_at > NOW() - INTERVAL '30 days';
    
    SELECT COUNT(*) INTO v_mismatches
    FROM "QuoteLines"
    WHERE deleted = false
        AND operating_system_variant IS NOT NULL
        AND (
            (operating_system_variant ILIKE '%standard_m%' AND tube_type NOT IN ('RTU-42', 'RTU-38', NULL))
            OR (operating_system_variant ILIKE '%standard_l%' AND tube_type NOT IN ('RTU-65', 'RTU-60', NULL))
        )
        AND (product_type ILIKE '%roller%shade%' OR product_type ILIKE '%dual%shade%' OR product_type ILIKE '%triple%shade%')
        AND created_at > NOW() - INTERVAL '30 days';
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Tube Type Correction Results:';
    RAISE NOTICE '  Total QuoteLines with operating_system_variant: %', v_total;
    RAISE NOTICE '  Standard M with RTU-42/38: %', v_standard_m_with_rtu42;
    RAISE NOTICE '  Standard L with RTU-65/60: %', v_standard_l_with_rtu65;
    RAISE NOTICE '  Mismatches remaining: %', v_mismatches;
    
    IF v_mismatches > 0 THEN
        RAISE WARNING '⚠️ There are still % mismatches between operating_system_variant and tube_type', v_mismatches;
    END IF;
END $$;

COMMIT;



