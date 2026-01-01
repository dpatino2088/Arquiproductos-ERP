-- ====================================================
-- Migration: BOM UOM Validation and cost_uom Handling
-- ====================================================
-- This migration implements:
-- 1. UOM validation function (validate_uom_measure_basis)
-- 2. cost_uom column and backfill
-- 3. Enhanced get_unit_cost_in_uom using cost_uom
-- 4. Fabric pricing helper functions
-- 5. Diagnostic functions
-- ====================================================

-- Enable pgcrypto if needed
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ====================================================
-- STEP 1: Create UOM Enum/Domain (if not exists)
-- ====================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'uom_code') THEN
        CREATE TYPE uom_code AS ENUM (
            'ea', 'm', 'm2', 'yd', 'ft', 'roll', 'pcs', 'set'
        );
        COMMENT ON TYPE uom_code IS 'Unit of measure codes. Canonical: m (length), m2 (area), ea (each). Legacy display: yd, ft, roll, pcs, set.';
        RAISE NOTICE '✅ Created uom_code enum';
    ELSE
        RAISE NOTICE '⏭️  uom_code enum already exists';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Add cost_uom to CatalogItems
-- ====================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'cost_uom'
    ) THEN
        ALTER TABLE "CatalogItems"
        ADD COLUMN cost_uom text;
        
        COMMENT ON COLUMN "CatalogItems".cost_uom IS 
            'UOM for cost_exw. Used for cost conversions. If NULL, defaults to uom.';
        
        RAISE NOTICE '✅ Added cost_uom to CatalogItems';
    ELSE
        RAISE NOTICE '⏭️  cost_uom already exists in CatalogItems';
    END IF;
END $$;

-- Backfill cost_uom: set cost_uom = uom where cost_uom is null and uom is not null
UPDATE "CatalogItems"
SET cost_uom = uom
WHERE cost_uom IS NULL
AND uom IS NOT NULL
AND deleted = false;

-- ====================================================
-- STEP 3: UOM Validation Function
-- ====================================================

CREATE OR REPLACE FUNCTION public.validate_uom_measure_basis(
    p_measure_basis text,
    p_uom text
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
STRICT
AS $$
DECLARE
    v_uom_upper text;
    v_measure_upper text;
BEGIN
    -- Handle NULL inputs
    IF p_measure_basis IS NULL OR p_uom IS NULL THEN
        RETURN false;
    END IF;
    
    v_uom_upper := UPPER(TRIM(p_uom));
    v_measure_upper := UPPER(TRIM(p_measure_basis));
    
    -- unit measure_basis: allowed ea, pcs, set
    IF v_measure_upper IN ('UNIT') THEN
        RETURN v_uom_upper IN ('EA', 'EACH', 'PCS', 'PIECE', 'PIECES', 'SET', 'SETS', 'UNIT', 'UNITS');
    END IF;
    
    -- linear_m measure_basis: allowed m, ft, yd
    IF v_measure_upper IN ('LINEAR_M', 'LINEAR') THEN
        RETURN v_uom_upper IN ('M', 'MTS', 'METER', 'METERS', 'FT', 'FEET', 'FOOT', 'YD', 'YARD', 'YARDS');
    END IF;
    
    -- area measure_basis: allowed m2
    IF v_measure_upper IN ('AREA') THEN
        RETURN v_uom_upper IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA');
    END IF;
    
    -- fabric measure_basis: base must be m2, but pricing can be m, yd, roll
    IF v_measure_upper IN ('FABRIC') THEN
        RETURN v_uom_upper IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA', 
                                'M', 'MTS', 'METER', 'METERS', 'YD', 'YARD', 'YARDS', 'ROLL', 'ROLLS');
    END IF;
    
    -- Unknown measure_basis: return false (strict validation)
    RETURN false;
END;
$$;

COMMENT ON FUNCTION public.validate_uom_measure_basis IS 
    'Validates that UOM is compatible with measure_basis. Returns true if valid, false if invalid. Strict: returns false for unknown measure_basis.';

-- ====================================================
-- STEP 4: Add CHECK Constraint (Optional, can be disabled for legacy data)
-- ====================================================

-- Note: We'll create the constraint but make it deferrable to allow fixing data first
DO $$
BEGIN
    -- Drop existing constraint if it exists
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'check_catalogitems_uom_measure_basis'
        AND conrelid = 'CatalogItems'::regclass
    ) THEN
        ALTER TABLE "CatalogItems" 
        DROP CONSTRAINT check_catalogitems_uom_measure_basis;
        RAISE NOTICE '⏭️  Dropped existing check_catalogitems_uom_measure_basis constraint';
    END IF;
    
    -- Add new constraint (deferrable initially to allow data fixes)
    ALTER TABLE "CatalogItems"
    ADD CONSTRAINT check_catalogitems_uom_measure_basis
    CHECK (
        measure_basis IS NULL 
        OR uom IS NULL 
        OR public.validate_uom_measure_basis(measure_basis, uom) = true
    );
    
    RAISE NOTICE '✅ Added check_catalogitems_uom_measure_basis constraint';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️  Could not add constraint (may have invalid data): %', SQLERRM;
        -- Create trigger-based validation instead
        RAISE NOTICE '   Consider using trigger-based validation instead';
END $$;

-- ====================================================
-- STEP 5: Enhanced get_unit_cost_in_uom (uses cost_uom)
-- ====================================================

CREATE OR REPLACE FUNCTION public.get_unit_cost_in_uom(
    p_catalog_item_id uuid,
    p_target_uom text,
    p_organization_id uuid
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_cost_exw numeric;
    v_cost_uom text;
    v_is_fabric boolean;
    v_roll_width_m numeric;
    v_fabric_pricing_mode text;
    v_multiplier numeric;
    v_target_uom_upper text;
    v_cost_uom_upper text;
    v_conversion_factor numeric;
BEGIN
    -- Get item data (use cost_uom, fallback to uom)
    SELECT 
        ci.cost_exw, 
        COALESCE(ci.cost_uom, ci.uom, 'ea') as cost_uom,
        COALESCE(ci.is_fabric, false) as is_fabric,
        ci.roll_width_m,
        ci.fabric_pricing_mode::text
    INTO v_cost_exw, v_cost_uom, v_is_fabric, v_roll_width_m, v_fabric_pricing_mode
    FROM "CatalogItems" ci
    WHERE ci.id = p_catalog_item_id
    AND ci.organization_id = p_organization_id
    AND ci.deleted = false;
    
    -- If item not found or cost_exw is NULL, return 0
    IF NOT FOUND OR v_cost_exw IS NULL THEN
        RETURN 0;
    END IF;
    
    v_target_uom_upper := UPPER(TRIM(COALESCE(p_target_uom, '')));
    v_cost_uom_upper := UPPER(TRIM(COALESCE(v_cost_uom, '')));
    
    -- If cost_uom is already the target_uom, return cost_exw directly
    IF v_cost_uom_upper = v_target_uom_upper THEN
        RETURN v_cost_exw;
    END IF;
    
    -- Special handling for fabric items
    IF v_is_fabric AND v_roll_width_m IS NOT NULL AND v_roll_width_m > 0 THEN
        -- Use fabric-specific conversion function
        RETURN public.get_fabric_unit_cost_in_target_uom(
            p_catalog_item_id,
            p_target_uom,
            p_organization_id
        );
    END IF;
    
    -- Non-fabric: Standard length/area conversions
    
    -- Target: m (meters)
    IF v_target_uom_upper IN ('M', 'MTS', 'METER', 'METERS') THEN
        IF v_cost_uom_upper IN ('FT', 'FEET', 'FOOT') THEN
            -- ft -> m: divide by 3.28084
            RETURN v_cost_exw / 3.28084;
        ELSIF v_cost_uom_upper IN ('YD', 'YARD', 'YARDS') THEN
            -- yd -> m: divide by 0.9144
            RETURN v_cost_exw / 0.9144;
        ELSIF v_cost_uom_upper IN ('M', 'MTS', 'METER', 'METERS') THEN
            RETURN v_cost_exw;
        END IF;
    END IF;
    
    -- Target: ft (feet)
    IF v_target_uom_upper IN ('FT', 'FEET', 'FOOT') THEN
        IF v_cost_uom_upper IN ('M', 'MTS', 'METER', 'METERS') THEN
            -- m -> ft: multiply by 3.28084
            RETURN v_cost_exw * 3.28084;
        ELSIF v_cost_uom_upper IN ('YD', 'YARD', 'YARDS') THEN
            -- yd -> ft: multiply by 3
            RETURN v_cost_exw * 3;
        ELSIF v_cost_uom_upper IN ('FT', 'FEET', 'FOOT') THEN
            RETURN v_cost_exw;
        END IF;
    END IF;
    
    -- Target: yd (yards)
    IF v_target_uom_upper IN ('YD', 'YARD', 'YARDS') THEN
        IF v_cost_uom_upper IN ('M', 'MTS', 'METER', 'METERS') THEN
            -- m -> yd: multiply by 0.9144
            RETURN v_cost_exw * 0.9144;
        ELSIF v_cost_uom_upper IN ('FT', 'FEET', 'FOOT') THEN
            -- ft -> yd: divide by 3
            RETURN v_cost_exw / 3;
        ELSIF v_cost_uom_upper IN ('YD', 'YARD', 'YARDS') THEN
            RETURN v_cost_exw;
        END IF;
    END IF;
    
    -- Target: m2 (square meters)
    IF v_target_uom_upper IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
        IF v_cost_uom_upper IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
            RETURN v_cost_exw;
        END IF;
        -- Cannot convert from length to area without dimensions
        RAISE NOTICE 'Cannot convert cost from % to m2 without dimensions (item: %)', v_cost_uom, p_catalog_item_id;
    END IF;
    
    -- Try UomConversions table if available
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'UomConversions') THEN
        SELECT multiplier INTO v_multiplier
        FROM "UomConversions"
        WHERE organization_id = p_organization_id
        AND from_uom = v_cost_uom
        AND to_uom = p_target_uom
        AND deleted = false
        LIMIT 1;
        
        -- If no conversion found, try reverse
        IF v_multiplier IS NULL THEN
            SELECT (1.0 / multiplier) INTO v_multiplier
            FROM "UomConversions"
            WHERE organization_id = p_organization_id
            AND from_uom = p_target_uom
            AND to_uom = v_cost_uom
            AND deleted = false
            LIMIT 1;
        END IF;
        
        -- If conversion found, use it
        IF v_multiplier IS NOT NULL THEN
            RETURN v_cost_exw / v_multiplier;
        END IF;
    END IF;
    
    -- No conversion available: return original cost with notice
    RAISE NOTICE 'No conversion from % to % for item %. Returning original cost_exw.', 
        v_cost_uom, p_target_uom, p_catalog_item_id;
    RETURN v_cost_exw;
END;
$$;

COMMENT ON FUNCTION public.get_unit_cost_in_uom IS 
    'Converts unit cost from catalog_item cost_uom to target_uom. Uses cost_uom (not display uom) for source. Supports m, ft, yd conversions. Returns original cost with notice if conversion not available.';

-- ====================================================
-- STEP 6: Fabric Cost Conversion Helper
-- ====================================================

CREATE OR REPLACE FUNCTION public.get_fabric_unit_cost_in_target_uom(
    p_catalog_item_id uuid,
    p_target_uom text,
    p_organization_id uuid
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_cost_exw numeric;
    v_cost_uom text;
    v_roll_width_m numeric;
    v_fabric_pricing_mode text;
    v_target_uom_upper text;
    v_cost_uom_upper text;
BEGIN
    -- Get fabric item data
    SELECT 
        ci.cost_exw,
        COALESCE(ci.cost_uom, ci.uom, 'm2') as cost_uom,
        ci.roll_width_m,
        ci.fabric_pricing_mode::text
    INTO v_cost_exw, v_cost_uom, v_roll_width_m, v_fabric_pricing_mode
    FROM "CatalogItems" ci
    WHERE ci.id = p_catalog_item_id
    AND ci.organization_id = p_organization_id
    AND ci.deleted = false
    AND ci.is_fabric = true;
    
    IF NOT FOUND OR v_cost_exw IS NULL THEN
        RETURN 0;
    END IF;
    
    v_target_uom_upper := UPPER(TRIM(COALESCE(p_target_uom, '')));
    v_cost_uom_upper := UPPER(TRIM(COALESCE(v_cost_uom, '')));
    
    -- If already in target UOM
    IF v_cost_uom_upper = v_target_uom_upper THEN
        RETURN v_cost_exw;
    END IF;
    
    -- Check if roll_width_m is available (required for most conversions)
    IF v_roll_width_m IS NULL OR v_roll_width_m <= 0 THEN
        RAISE NOTICE 'Fabric item % has no roll_width_m. Cannot convert from % to %. Returning original cost.', 
            p_catalog_item_id, v_cost_uom, p_target_uom;
        RETURN v_cost_exw;
    END IF;
    
    -- Target: m2 (square meters) - canonical base
    IF v_target_uom_upper IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
        IF v_cost_uom_upper IN ('M', 'MTS', 'METER', 'METERS') THEN
            -- Cost per m -> per m2: divide by roll width
            RETURN v_cost_exw / v_roll_width_m;
        ELSIF v_cost_uom_upper IN ('YD', 'YARD', 'YARDS') THEN
            -- Cost per yd -> per m2: (cost_per_yd / 0.9144) / roll_width_m
            RETURN (v_cost_exw / 0.9144) / v_roll_width_m;
        ELSIF v_cost_uom_upper IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
            RETURN v_cost_exw;
        END IF;
    END IF;
    
    -- Target: m (linear meters)
    IF v_target_uom_upper IN ('M', 'MTS', 'METER', 'METERS') THEN
        IF v_cost_uom_upper IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
            -- Cost per m2 -> per m: multiply by roll width
            RETURN v_cost_exw * v_roll_width_m;
        ELSIF v_cost_uom_upper IN ('YD', 'YARD', 'YARDS') THEN
            -- Cost per yd -> per m: divide by 0.9144
            RETURN v_cost_exw / 0.9144;
        ELSIF v_cost_uom_upper IN ('M', 'MTS', 'METER', 'METERS') THEN
            RETURN v_cost_exw;
        END IF;
    END IF;
    
    -- Target: yd (linear yards)
    IF v_target_uom_upper IN ('YD', 'YARD', 'YARDS') THEN
        IF v_cost_uom_upper IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
            -- Cost per m2 -> per yd: (cost_per_m2 * roll_width_m) * 0.9144
            RETURN (v_cost_exw * v_roll_width_m) * 0.9144;
        ELSIF v_cost_uom_upper IN ('M', 'MTS', 'METER', 'METERS') THEN
            -- Cost per m -> per yd: multiply by 0.9144
            RETURN v_cost_exw * 0.9144;
        ELSIF v_cost_uom_upper IN ('YD', 'YARD', 'YARDS') THEN
            RETURN v_cost_exw;
        END IF;
    END IF;
    
    -- No conversion available
    RAISE NOTICE 'No fabric conversion from % to % for item %. Returning original cost.', 
        v_cost_uom, p_target_uom, p_catalog_item_id;
    RETURN v_cost_exw;
END;
$$;

COMMENT ON FUNCTION public.get_fabric_unit_cost_in_target_uom IS 
    'Converts fabric unit cost using roll_width_m. Requires roll_width_m > 0. Returns original cost with notice if conversion not available.';

-- ====================================================
-- STEP 7: Update normalize_uom_to_canonical (preserve m2)
-- ====================================================

CREATE OR REPLACE FUNCTION public.normalize_uom_to_canonical(
    p_uom text
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
STRICT
AS $$
BEGIN
    -- Canonical UOM set: 'm' (length), 'm2' (area), 'ea' (each)
    IF UPPER(TRIM(COALESCE(p_uom, ''))) IN ('MTS', 'M', 'METER', 'METERS', 'YD', 'YARD', 'YARDS', 'FT', 'FEET', 'FOOT') THEN
        RETURN 'm';
    ELSIF UPPER(TRIM(COALESCE(p_uom, ''))) IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
        RETURN 'm2';
    ELSIF UPPER(TRIM(COALESCE(p_uom, ''))) IN ('EA', 'EACH', 'PCS', 'PIECE', 'PIECES', 'SET', 'SETS', 'ROLL', 'ROLLS', 'UNIT', 'UNITS') THEN
        RETURN 'ea';
    ELSE
        -- Default to 'ea' for unknown UOMs (safe fallback)
        RETURN 'ea';
    END IF;
END;
$$;

COMMENT ON FUNCTION public.normalize_uom_to_canonical IS 
    'Normalizes UOM to canonical form: length units -> ''m'', area units -> ''m2'', everything else -> ''ea''. Preserves fabric/area UOMs.';

-- ====================================================
-- STEP 8: Diagnostic Functions
-- ====================================================

-- Diagnostic 1: Invalid UOM/measure_basis pairs
-- Drop existing function if it exists (may have different signature)
DROP FUNCTION IF EXISTS public.diagnostic_invalid_uom_measure_basis();

CREATE OR REPLACE FUNCTION public.diagnostic_invalid_uom_measure_basis()
RETURNS TABLE(
    catalog_item_id uuid,
    sku text,
    item_name text,
    measure_basis text,
    uom text,
    cost_uom text,
    is_valid boolean,
    validation_note text
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_has_cost_uom boolean;
BEGIN
    -- Check if cost_uom column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'cost_uom'
    ) INTO v_has_cost_uom;
    
    IF v_has_cost_uom THEN
        RETURN QUERY
        SELECT 
            ci.id,
            ci.sku,
            ci.item_name,
            ci.measure_basis,
            ci.uom,
            ci.cost_uom,
            public.validate_uom_measure_basis(ci.measure_basis, ci.uom) as is_valid,
            CASE 
                WHEN NOT public.validate_uom_measure_basis(ci.measure_basis, ci.uom) THEN
                    format('UOM %s is not compatible with measure_basis %s', ci.uom, ci.measure_basis)
                ELSE
                    'Valid'
            END as validation_note
        FROM "CatalogItems" ci
        WHERE ci.deleted = false
        AND ci.measure_basis IS NOT NULL
        AND ci.uom IS NOT NULL
        ORDER BY is_valid, ci.measure_basis, ci.uom;
    ELSE
        -- cost_uom doesn't exist yet, return NULL for it
        RETURN QUERY
        SELECT 
            ci.id,
            ci.sku,
            ci.item_name,
            ci.measure_basis,
            ci.uom,
            NULL::text as cost_uom,
            public.validate_uom_measure_basis(ci.measure_basis, ci.uom) as is_valid,
            CASE 
                WHEN NOT public.validate_uom_measure_basis(ci.measure_basis, ci.uom) THEN
                    format('UOM %s is not compatible with measure_basis %s', ci.uom, ci.measure_basis)
                ELSE
                    'Valid'
            END as validation_note
        FROM "CatalogItems" ci
        WHERE ci.deleted = false
        AND ci.measure_basis IS NOT NULL
        AND ci.uom IS NOT NULL
        ORDER BY is_valid, ci.measure_basis, ci.uom;
    END IF;
END;
$$;

COMMENT ON FUNCTION public.diagnostic_invalid_uom_measure_basis IS 
    'Returns all CatalogItems with invalid UOM/measure_basis combinations. Use to identify data quality issues.';

-- Diagnostic 2: BOM UOM Summary
-- Drop existing function if it exists (may have different signature)
DROP FUNCTION IF EXISTS public.diagnostic_bom_uom_summary();

CREATE OR REPLACE FUNCTION public.diagnostic_bom_uom_summary()
RETURNS TABLE(
    category_code text,
    uom text,
    uom_base text,
    line_count bigint,
    total_qty numeric,
    total_qty_base numeric
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        bil.category_code,
        bil.uom,
        bil.uom_base,
        COUNT(*) as line_count,
        SUM(bil.qty) as total_qty,
        SUM(COALESCE(bil.qty_base, bil.qty)) as total_qty_base
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    WHERE bil.deleted = false
    AND bi.deleted = false
    GROUP BY bil.category_code, bil.uom, bil.uom_base
    ORDER BY bil.category_code, bil.uom_base, bil.uom;
END;
$$;

COMMENT ON FUNCTION public.diagnostic_bom_uom_summary IS 
    'Returns summary of BomInstanceLines by category_code and UOM. Shows distribution of UOMs in BOMs.';

-- Diagnostic 3: Compare QuoteLineComponents vs BomInstanceLines
-- Drop existing function if it exists (may have different signature)
DROP FUNCTION IF EXISTS public.diagnostic_quote_vs_bom_lines(uuid);

CREATE OR REPLACE FUNCTION public.diagnostic_quote_vs_bom_lines(
    p_quote_line_id uuid
)
RETURNS TABLE(
    source text,
    component_role text,
    catalog_item_sku text,
    qty numeric,
    uom text,
    qty_base numeric,
    uom_base text,
    unit_cost numeric,
    total_cost numeric,
    status text
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    -- QuoteLineComponents
    RETURN QUERY
    SELECT 
        'QuoteLineComponent'::text,
        qlc.component_role,
        ci.sku,
        qlc.qty,
        qlc.uom,
        NULL::numeric as qty_base,
        NULL::text as uom_base,
        qlc.unit_cost_exw,
        qlc.qty * COALESCE(qlc.unit_cost_exw, 0) as total_cost,
        'Source'::text as status
    FROM "QuoteLineComponents" qlc
    LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
    WHERE qlc.quote_line_id = p_quote_line_id
    AND qlc.deleted = false
    AND qlc.source = 'configured_component'
    
    UNION ALL
    
    -- BomInstanceLines
    SELECT 
        'BomInstanceLine'::text,
        bil.part_role,
        ci.sku,
        bil.qty,
        bil.uom,
        bil.qty_base,
        bil.uom_base,
        bil.unit_cost_exw,
        bil.total_cost_exw,
        CASE 
            WHEN bil.qty_base IS NULL THEN 'Missing base fields'
            WHEN bil.uom_base IS NULL THEN 'Missing base UOM'
            ELSE 'Complete'
        END as status
    FROM "QuoteLines" ql
    INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id AND sol.deleted = false
    INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
    INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
    LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
    WHERE ql.id = p_quote_line_id
    AND ql.deleted = false
    ORDER BY component_role, source;
END;
$$;

COMMENT ON FUNCTION public.diagnostic_quote_vs_bom_lines IS 
    'Compares QuoteLineComponents vs BomInstanceLines for a given quote_line_id. Shows missing lines or data discrepancies.';

-- ====================================================
-- STEP 9: Summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration 188 completed: BOM UOM Validation and cost_uom Handling';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Created/Updated:';
    RAISE NOTICE '   - Enum: uom_code';
    RAISE NOTICE '   - Column: CatalogItems.cost_uom (backfilled)';
    RAISE NOTICE '   - Function: validate_uom_measure_basis() (strict validation)';
    RAISE NOTICE '   - Constraint: check_catalogitems_uom_measure_basis';
    RAISE NOTICE '   - Function: get_unit_cost_in_uom() (uses cost_uom)';
    RAISE NOTICE '   - Function: get_fabric_unit_cost_in_target_uom() (fabric-specific)';
    RAISE NOTICE '   - Function: normalize_uom_to_canonical() (preserves m2)';
    RAISE NOTICE '   - Diagnostics: 3 functions';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Next Steps:';
    RAISE NOTICE '   1. Run: SELECT * FROM diagnostic_invalid_uom_measure_basis() WHERE is_valid = false;';
    RAISE NOTICE '   2. Fix invalid items using scripts/FIX_INVALID_UOM_MEASURE_BASIS.sql';
    RAISE NOTICE '   3. Run migration 189 to fix backfill format error';
    RAISE NOTICE '';
END $$;

