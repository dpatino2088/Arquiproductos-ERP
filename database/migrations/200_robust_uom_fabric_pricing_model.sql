-- ====================================================
-- Migration: Robust UOM and Fabric Pricing Model for BOM
-- ====================================================
-- This migration implements:
-- 1. Strong UOM enums and validation (m, m2, ea as canonical)
-- 2. Fabric pricing mode support (per_sqm, per_linear_m, per_linear_yd)
-- 3. Base and pricing quantities in BomInstanceLines
-- 4. Updated cost conversion functions with roll_width_m support
-- 5. Validation rules for UOM vs measure_basis compatibility
-- ====================================================

-- Enable pgcrypto if needed
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ====================================================
-- STEP 0: Create/Update Enums
-- ====================================================

-- Create uom_code enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'uom_code') THEN
        CREATE TYPE uom_code AS ENUM (
            'ea', 'm', 'm2', 'yd', 'ft', 'roll', 'pcs', 'set'
        );
        COMMENT ON TYPE uom_code IS 'Unit of measure codes. Canonical: m (length), m2 (area), ea (each). Legacy display: yd, ft, roll, pcs, set.';
    ELSE
        -- Enum exists, check if we need to add values
        -- Note: PostgreSQL doesn't support adding enum values easily, so we'll handle this carefully
        RAISE NOTICE '⏭️  uom_code enum already exists';
    END IF;
END $$;

-- Create measure_basis_code enum (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'measure_basis_code') THEN
        CREATE TYPE measure_basis_code AS ENUM (
            'unit', 'linear_m', 'area', 'fabric'
        );
        COMMENT ON TYPE measure_basis_code IS 'Measure basis codes: unit (each), linear_m (length), area (square meters), fabric (special case of area with pricing modes).';
    ELSE
        RAISE NOTICE '⏭️  measure_basis_code enum already exists';
    END IF;
END $$;

-- Create fabric_pricing_mode enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'fabric_pricing_mode') THEN
        CREATE TYPE fabric_pricing_mode AS ENUM (
            'per_sqm', 'per_linear_m', 'per_linear_yd', 'per_roll'
        );
        COMMENT ON TYPE fabric_pricing_mode IS 'Fabric pricing modes: per_sqm (per square meter), per_linear_m (per linear meter of roll), per_linear_yd (per linear yard of roll), per_roll (per entire roll).';
    ELSE
        RAISE NOTICE '⏭️  fabric_pricing_mode enum already exists';
    END IF;
END $$;

-- ====================================================
-- STEP 1: CatalogItems - Add Fabric Pricing Fields
-- ====================================================

DO $$
BEGIN
    -- Add fabric_pricing_mode (nullable, only for fabrics)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'fabric_pricing_mode'
    ) THEN
        ALTER TABLE "CatalogItems"
        ADD COLUMN fabric_pricing_mode fabric_pricing_mode;
        
        COMMENT ON COLUMN "CatalogItems".fabric_pricing_mode IS 
            'Pricing mode for fabric items. NULL for non-fabric items. per_sqm, per_linear_m, per_linear_yd, or per_roll.';
        
        RAISE NOTICE '✅ Added fabric_pricing_mode to CatalogItems';
    ELSE
        RAISE NOTICE '⏭️  fabric_pricing_mode already exists in CatalogItems';
    END IF;
    
    -- Ensure roll_width_m exists (it should already exist, but check)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'roll_width_m'
    ) THEN
        ALTER TABLE "CatalogItems"
        ADD COLUMN roll_width_m numeric(10,4);
        
        COMMENT ON COLUMN "CatalogItems".roll_width_m IS 
            'Roll width in meters for fabric items. Used for converting between sqm and linear meters.';
        
        RAISE NOTICE '✅ Added roll_width_m to CatalogItems';
    ELSE
        RAISE NOTICE '⏭️  roll_width_m already exists in CatalogItems';
    END IF;
    
    -- Add pricing_uom (optional, for explicit pricing UOM if different from base uom)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'pricing_uom'
    ) THEN
        ALTER TABLE "CatalogItems"
        ADD COLUMN pricing_uom text;
        
        COMMENT ON COLUMN "CatalogItems".pricing_uom IS 
            'Explicit pricing UOM if different from base uom. For fabrics, this is derived from fabric_pricing_mode.';
        
        RAISE NOTICE '✅ Added pricing_uom to CatalogItems';
    ELSE
        RAISE NOTICE '⏭️  pricing_uom already exists in CatalogItems';
    END IF;
END $$;

-- ====================================================
-- STEP 2: BomInstanceLines - Add Base and Pricing Fields
-- ====================================================

DO $$
BEGIN
    -- Add base quantity fields
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'qty_base'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN qty_base numeric(12,4);
        
        COMMENT ON COLUMN "BomInstanceLines".qty_base IS 
            'Base consumption quantity in canonical UOM (m, m2, or ea). For fabric, always m2.';
        
        RAISE NOTICE '✅ Added qty_base to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  qty_base already exists in BomInstanceLines';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'uom_base'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN uom_base text;
        
        COMMENT ON COLUMN "BomInstanceLines".uom_base IS 
            'Base UOM (canonical): m (length), m2 (area), ea (each). Frozen snapshot.';
        
        RAISE NOTICE '✅ Added uom_base to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  uom_base already exists in BomInstanceLines';
    END IF;
    
    -- Add pricing quantity fields
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'qty_pricing'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN qty_pricing numeric(12,4);
        
        COMMENT ON COLUMN "BomInstanceLines".qty_pricing IS 
            'Pricing/purchase quantity in pricing UOM. For fabric, may be linear m/yd or sqm depending on fabric_pricing_mode. Frozen snapshot.';
        
        RAISE NOTICE '✅ Added qty_pricing to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  qty_pricing already exists in BomInstanceLines';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'uom_pricing'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN uom_pricing text;
        
        COMMENT ON COLUMN "BomInstanceLines".uom_pricing IS 
            'Pricing UOM (may be m, m2, yd, ea, etc.). For fabric, depends on fabric_pricing_mode. Frozen snapshot.';
        
        RAISE NOTICE '✅ Added uom_pricing to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  uom_pricing already exists in BomInstanceLines';
    END IF;
    
    -- Add base cost fields (if unit_cost_exw and total_cost_exw exist, these are additional)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'unit_cost_base'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN unit_cost_base numeric(12,4);
        
        COMMENT ON COLUMN "BomInstanceLines".unit_cost_base IS 
            'Unit cost in base UOM. Frozen snapshot.';
        
        RAISE NOTICE '✅ Added unit_cost_base to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  unit_cost_base already exists in BomInstanceLines';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'total_cost_base'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN total_cost_base numeric(12,4);
        
        COMMENT ON COLUMN "BomInstanceLines".total_cost_base IS 
            'Total cost in base UOM (qty_base * unit_cost_base). Frozen snapshot.';
        
        RAISE NOTICE '✅ Added total_cost_base to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  total_cost_base already exists in BomInstanceLines';
    END IF;
    
    -- Add pricing cost fields
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'unit_cost_pricing'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN unit_cost_pricing numeric(12,4);
        
        COMMENT ON COLUMN "BomInstanceLines".unit_cost_pricing IS 
            'Unit cost in pricing UOM. Frozen snapshot.';
        
        RAISE NOTICE '✅ Added unit_cost_pricing to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  unit_cost_pricing already exists in BomInstanceLines';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'total_cost_pricing'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN total_cost_pricing numeric(12,4);
        
        COMMENT ON COLUMN "BomInstanceLines".total_cost_pricing IS 
            'Total cost in pricing UOM (qty_pricing * unit_cost_pricing). Frozen snapshot.';
        
        RAISE NOTICE '✅ Added total_cost_pricing to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  total_cost_pricing already exists in BomInstanceLines';
    END IF;
    
    -- Ensure calc_notes exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'calc_notes'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN calc_notes text;
        
        COMMENT ON COLUMN "BomInstanceLines".calc_notes IS 
            'Calculation notes explaining how quantities and costs were derived.';
        
        RAISE NOTICE '✅ Added calc_notes to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  calc_notes already exists in BomInstanceLines';
    END IF;
END $$;

-- ====================================================
-- STEP 3: UOM Normalization Functions
-- ====================================================

-- Replace normalize_uom_to_canonical to preserve m2
CREATE OR REPLACE FUNCTION public.normalize_uom_to_canonical(
    p_uom text
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
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

-- New function: normalize to pricing UOM (preserves display UOMs like yd, ft)
CREATE OR REPLACE FUNCTION public.normalize_uom_to_pricing(
    p_uom text
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- For pricing, we preserve more UOMs for display purposes
    IF UPPER(TRIM(COALESCE(p_uom, ''))) IN ('MTS', 'M', 'METER', 'METERS') THEN
        RETURN 'm';
    ELSIF UPPER(TRIM(COALESCE(p_uom, ''))) IN ('YD', 'YARD', 'YARDS') THEN
        RETURN 'yd';
    ELSIF UPPER(TRIM(COALESCE(p_uom, ''))) IN ('FT', 'FEET', 'FOOT') THEN
        RETURN 'ft';
    ELSIF UPPER(TRIM(COALESCE(p_uom, ''))) IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
        RETURN 'm2';
    ELSIF UPPER(TRIM(COALESCE(p_uom, ''))) IN ('ROLL', 'ROLLS') THEN
        RETURN 'roll';
    ELSIF UPPER(TRIM(COALESCE(p_uom, ''))) IN ('EA', 'EACH', 'PCS', 'PIECE', 'PIECES', 'SET', 'SETS', 'UNIT', 'UNITS') THEN
        RETURN 'ea';
    ELSE
        RETURN 'ea'; -- Safe fallback
    END IF;
END;
$$;

COMMENT ON FUNCTION public.normalize_uom_to_pricing IS 
    'Normalizes UOM to pricing form, preserving display UOMs like yd, ft, roll for purchase/display purposes.';

-- ====================================================
-- STEP 4: UOM vs Measure Basis Validation
-- ====================================================

CREATE OR REPLACE FUNCTION public.validate_uom_measure_basis(
    p_measure_basis text,
    p_uom text
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_uom_upper text;
    v_measure_upper text;
BEGIN
    v_uom_upper := UPPER(TRIM(COALESCE(p_uom, '')));
    v_measure_upper := UPPER(TRIM(COALESCE(p_measure_basis, '')));
    
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
        -- Base UOM must be m2, but pricing UOM can vary
        RETURN v_uom_upper IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA', 
                                'M', 'MTS', 'METER', 'METERS', 'YD', 'YARD', 'YARDS', 'ROLL', 'ROLLS');
    END IF;
    
    -- Unknown measure_basis: allow all (permissive for legacy data)
    RETURN true;
END;
$$;

COMMENT ON FUNCTION public.validate_uom_measure_basis IS 
    'Validates that UOM is compatible with measure_basis. Returns true if valid, false if invalid.';

-- ====================================================
-- STEP 5: Enhanced Cost Conversion Functions
-- ====================================================

-- Update get_unit_cost_in_uom to support m2 and fabric conversions
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
BEGIN
    -- Get item data
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
        -- Fabric conversions using roll_width_m
        
        -- Target: m2
        IF v_target_uom_upper IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
            IF v_cost_uom_upper IN ('M', 'MTS', 'METER', 'METERS') THEN
                -- Cost per m -> per m2: divide by roll width
                RETURN v_cost_exw / v_roll_width_m;
            ELSIF v_cost_uom_upper IN ('YD', 'YARD', 'YARDS') THEN
                -- Cost per yd -> per m2: (cost_per_yd / 0.9144) / roll_width_m
                RETURN (v_cost_exw / 0.9144) / v_roll_width_m;
            ELSIF v_cost_uom_upper IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
                -- Already m2
                RETURN v_cost_exw;
            END IF;
        END IF;
        
        -- Target: m (linear)
        IF v_target_uom_upper IN ('M', 'MTS', 'METER', 'METERS') THEN
            IF v_cost_uom_upper IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
                -- Cost per m2 -> per m: multiply by roll width
                RETURN v_cost_exw * v_roll_width_m;
            ELSIF v_cost_uom_upper IN ('YD', 'YARD', 'YARDS') THEN
                -- Cost per yd -> per m: cost_per_yd / 0.9144
                RETURN v_cost_exw / 0.9144;
            ELSIF v_cost_uom_upper IN ('M', 'MTS', 'METER', 'METERS') THEN
                -- Already m
                RETURN v_cost_exw;
            END IF;
        END IF;
        
        -- Target: yd (linear)
        IF v_target_uom_upper IN ('YD', 'YARD', 'YARDS') THEN
            IF v_cost_uom_upper IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
                -- Cost per m2 -> per yd: (cost_per_m2 * roll_width_m) * 0.9144
                RETURN (v_cost_exw * v_roll_width_m) * 0.9144;
            ELSIF v_cost_uom_upper IN ('M', 'MTS', 'METER', 'METERS') THEN
                -- Cost per m -> per yd: multiply by 0.9144
                RETURN v_cost_exw * 0.9144;
            ELSIF v_cost_uom_upper IN ('YD', 'YARD', 'YARDS') THEN
                -- Already yd
                RETURN v_cost_exw;
            END IF;
        END IF;
    END IF;
    
    -- Non-fabric or fallback: use UomConversions table if available
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
    
    -- Simple conversions for length units (non-fabric fallback)
    IF v_target_uom_upper IN ('M', 'MTS', 'METER', 'METERS') THEN
        IF v_cost_uom_upper IN ('YD', 'YARD', 'YARDS') THEN
            RETURN v_cost_exw / 0.9144;
        ELSIF v_cost_uom_upper IN ('FT', 'FEET', 'FOOT') THEN
            RETURN v_cost_exw / 3.28084;
        ELSIF v_cost_uom_upper IN ('M', 'MTS', 'METER', 'METERS') THEN
            RETURN v_cost_exw;
        END IF;
    END IF;
    
    -- For 'ea' or other cases, just return cost_exw (assume same cost)
    RETURN v_cost_exw;
END;
$$;

COMMENT ON FUNCTION public.get_unit_cost_in_uom IS 
    'Converts unit cost from catalog_item cost_uom to target_uom. Supports m2, m, yd conversions for fabrics using roll_width_m. Uses UomConversions table if available, otherwise uses simple conversions.';

-- New function: get unit cost in pricing UOM
CREATE OR REPLACE FUNCTION public.get_unit_cost_in_pricing_uom(
    p_catalog_item_id uuid,
    p_pricing_uom text,
    p_organization_id uuid
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    -- For now, this is an alias to get_unit_cost_in_uom
    -- In the future, this could have different logic for pricing vs base
    RETURN public.get_unit_cost_in_uom(p_catalog_item_id, p_pricing_uom, p_organization_id);
END;
$$;

COMMENT ON FUNCTION public.get_unit_cost_in_pricing_uom IS 
    'Gets unit cost in pricing UOM. Currently uses same logic as get_unit_cost_in_uom, but separated for future pricing-specific logic.';

-- ====================================================
-- STEP 6: Helper Function - Calculate Fabric Pricing Quantities
-- ====================================================

CREATE OR REPLACE FUNCTION public.calculate_fabric_pricing_qty(
    p_qty_base_m2 numeric,
    p_fabric_pricing_mode text,
    p_roll_width_m numeric
)
RETURNS TABLE(
    qty_pricing numeric,
    uom_pricing text
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_qty_pricing numeric;
    v_uom_pricing text;
BEGIN
    -- Default: same as base
    v_qty_pricing := p_qty_base_m2;
    v_uom_pricing := 'm2';
    
    IF p_roll_width_m IS NULL OR p_roll_width_m <= 0 THEN
        -- No roll width: cannot convert, return base
        RETURN QUERY SELECT v_qty_pricing, v_uom_pricing;
        RETURN;
    END IF;
    
    IF p_fabric_pricing_mode = 'per_sqm' THEN
        v_qty_pricing := p_qty_base_m2;
        v_uom_pricing := 'm2';
    ELSIF p_fabric_pricing_mode = 'per_linear_m' THEN
        v_qty_pricing := p_qty_base_m2 / p_roll_width_m;
        v_uom_pricing := 'm';
    ELSIF p_fabric_pricing_mode = 'per_linear_yd' THEN
        v_qty_pricing := (p_qty_base_m2 / p_roll_width_m) / 0.9144;
        v_uom_pricing := 'yd';
    ELSIF p_fabric_pricing_mode = 'per_roll' THEN
        -- Per roll: would need roll_length_m, which we don't have yet
        -- For now, return base (can be enhanced later)
        v_qty_pricing := p_qty_base_m2;
        v_uom_pricing := 'm2';
        RAISE NOTICE 'per_roll pricing mode not fully supported yet (needs roll_length_m)';
    ELSE
        -- Unknown mode: return base
        v_qty_pricing := p_qty_base_m2;
        v_uom_pricing := 'm2';
    END IF;
    
    RETURN QUERY SELECT v_qty_pricing, v_uom_pricing;
END;
$$;

COMMENT ON FUNCTION public.calculate_fabric_pricing_qty IS 
    'Calculates pricing quantity and UOM for fabric based on pricing mode and roll width. Base quantity must be in m2.';

-- ====================================================
-- STEP 7: Update BOM Creation Logic (Trigger Function)
-- ====================================================

-- This will be called from the existing trigger function
-- We'll create a helper function that can be called during BOM creation

CREATE OR REPLACE FUNCTION public.populate_bom_line_base_pricing_fields(
    p_bom_instance_line_id uuid,
    p_catalog_item_id uuid,
    p_component_qty numeric,
    p_component_uom text,
    p_component_role text,
    p_organization_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_catalog_item RECORD;
    v_qty_base numeric;
    v_uom_base text;
    v_qty_pricing numeric;
    v_uom_pricing text;
    v_unit_cost_base numeric;
    v_unit_cost_pricing numeric;
    v_total_cost_base numeric;
    v_total_cost_pricing numeric;
    v_calc_notes text;
    v_pricing_result RECORD;
BEGIN
    -- Get catalog item data
    SELECT 
        ci.is_fabric,
        ci.roll_width_m,
        ci.fabric_pricing_mode::text,
        ci.measure_basis,
        ci.uom
    INTO v_catalog_item
    FROM "CatalogItems" ci
    WHERE ci.id = p_catalog_item_id
    AND ci.organization_id = p_organization_id
    AND ci.deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING 'CatalogItem % not found for BOM line %', p_catalog_item_id, p_bom_instance_line_id;
        RETURN;
    END IF;
    
    -- Determine base UOM and quantity
    IF v_catalog_item.is_fabric THEN
        -- Fabric: base is always m2
        v_uom_base := 'm2';
        -- Convert component qty to m2 if needed
        IF UPPER(TRIM(COALESCE(p_component_uom, ''))) IN ('M2', 'SQM', 'SQ_M', 'SQUARE_METER', 'SQUARE_METERS', 'AREA') THEN
            v_qty_base := p_component_qty;
        ELSIF UPPER(TRIM(COALESCE(p_component_uom, ''))) IN ('M', 'MTS', 'METER', 'METERS') THEN
            -- Linear meters -> m2: multiply by roll width
            IF v_catalog_item.roll_width_m IS NOT NULL AND v_catalog_item.roll_width_m > 0 THEN
                v_qty_base := p_component_qty * v_catalog_item.roll_width_m;
            ELSE
                -- No roll width: cannot convert, use component qty as-is (will be wrong, but better than NULL)
                v_qty_base := p_component_qty;
                v_calc_notes := 'WARNING: No roll_width_m for fabric, cannot convert linear m to m2';
            END IF;
        ELSE
            -- Unknown UOM: use component qty as-is
            v_qty_base := p_component_qty;
            v_calc_notes := 'WARNING: Unknown fabric UOM, using component qty as base';
        END IF;
    ELSE
        -- Non-fabric: normalize to canonical
        v_uom_base := public.normalize_uom_to_canonical(p_component_uom);
        v_qty_base := p_component_qty;
    END IF;
    
    -- Determine pricing UOM and quantity
    IF v_catalog_item.is_fabric AND v_catalog_item.fabric_pricing_mode IS NOT NULL THEN
        -- Use fabric pricing mode
        SELECT * INTO v_pricing_result
        FROM public.calculate_fabric_pricing_qty(
            v_qty_base,
            v_catalog_item.fabric_pricing_mode,
            v_catalog_item.roll_width_m
        );
        v_qty_pricing := v_pricing_result.qty_pricing;
        v_uom_pricing := v_pricing_result.uom_pricing;
    ELSE
        -- Non-fabric or no pricing mode: same as base
        v_qty_pricing := v_qty_base;
        v_uom_pricing := v_uom_base;
    END IF;
    
    -- Calculate costs
    v_unit_cost_base := public.get_unit_cost_in_uom(p_catalog_item_id, v_uom_base, p_organization_id);
    v_unit_cost_pricing := public.get_unit_cost_in_pricing_uom(p_catalog_item_id, v_uom_pricing, p_organization_id);
    
    -- If costs are 0 or NULL, try to use existing unit_cost_exw from BomInstanceLines
    IF (v_unit_cost_base IS NULL OR v_unit_cost_base = 0) THEN
        SELECT unit_cost_exw INTO v_unit_cost_base
        FROM "BomInstanceLines"
        WHERE id = p_bom_instance_line_id;
    END IF;
    
    IF (v_unit_cost_pricing IS NULL OR v_unit_cost_pricing = 0) THEN
        v_unit_cost_pricing := v_unit_cost_base;
    END IF;
    
    v_total_cost_base := v_qty_base * COALESCE(v_unit_cost_base, 0);
    v_total_cost_pricing := v_qty_pricing * COALESCE(v_unit_cost_pricing, 0);
    
    -- Build calc_notes
    IF v_calc_notes IS NULL THEN
        v_calc_notes := '';
    END IF;
    
    IF v_catalog_item.is_fabric THEN
        v_calc_notes := v_calc_notes || 
            format('Fabric: base=%s %s, pricing=%s %s (mode=%s, roll_width=%s m)',
                v_qty_base::text, v_uom_base, v_qty_pricing::text, v_uom_pricing,
                COALESCE(v_catalog_item.fabric_pricing_mode::text, 'none'),
                ROUND(COALESCE(v_catalog_item.roll_width_m, 0), 4)::text);
    ELSE
        v_calc_notes := v_calc_notes || 
            format('Base=%s %s, pricing=%s %s',
                v_qty_base::text, v_uom_base, v_qty_pricing::text, v_uom_pricing);
    END IF;
    
    -- Update BomInstanceLine
    UPDATE "BomInstanceLines"
    SET
        qty_base = v_qty_base,
        uom_base = v_uom_base,
        qty_pricing = v_qty_pricing,
        uom_pricing = v_uom_pricing,
        unit_cost_base = v_unit_cost_base,
        unit_cost_pricing = v_unit_cost_pricing,
        total_cost_base = v_total_cost_base,
        total_cost_pricing = v_total_cost_pricing,
        calc_notes = COALESCE(calc_notes, '') || CASE WHEN calc_notes IS NOT NULL THEN '; ' ELSE '' END || v_calc_notes
    WHERE id = p_bom_instance_line_id;
END;
$$;

COMMENT ON FUNCTION public.populate_bom_line_base_pricing_fields IS 
    'Populates base and pricing quantity/UOM fields in BomInstanceLines. Called during BOM creation or as a backfill.';

-- ====================================================
-- STEP 8: Backfill Existing BomInstanceLines
-- ====================================================

-- Function to backfill existing BomInstanceLines with new fields
CREATE OR REPLACE FUNCTION public.backfill_bom_lines_base_pricing()
RETURNS TABLE(
    bom_line_id uuid,
    updated boolean,
    error_message text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_bom_line RECORD;
    v_error_message text;
BEGIN
    FOR v_bom_line IN
        SELECT 
            bil.id,
            bil.bom_instance_id,
            bil.resolved_part_id,
            bil.qty,
            bil.uom,
            bil.part_role,
            bi.organization_id
        FROM "BomInstanceLines" bil
        INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
        WHERE bil.deleted = false
        AND (bil.qty_base IS NULL OR bil.uom_base IS NULL)
    LOOP
        BEGIN
            PERFORM public.populate_bom_line_base_pricing_fields(
                v_bom_line.id,
                v_bom_line.resolved_part_id,
                v_bom_line.qty,
                v_bom_line.uom,
                v_bom_line.part_role,
                v_bom_line.organization_id
            );
            
            RETURN QUERY SELECT v_bom_line.id, true, NULL::text;
        EXCEPTION WHEN OTHERS THEN
            v_error_message := SQLERRM;
            RETURN QUERY SELECT v_bom_line.id, false, v_error_message;
        END;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION public.backfill_bom_lines_base_pricing IS 
    'Backfills existing BomInstanceLines with base and pricing fields. Returns results showing which lines were updated and any errors.';

-- ====================================================
-- STEP 9: Diagnostic Queries
-- ====================================================

-- Query 1: Show BOM lines for a SaleOrderLine with base/pricing qty/uom and costs
-- Usage: SELECT * FROM diagnostic_bom_lines_for_sale_order_line('<sale_order_line_id>');
CREATE OR REPLACE FUNCTION diagnostic_bom_lines_for_sale_order_line(
    p_sale_order_line_id uuid
)
RETURNS TABLE(
    bom_line_id uuid,
    catalog_item_sku text,
    part_role text,
    category_code text,
    qty_base numeric,
    uom_base text,
    qty_pricing numeric,
    uom_pricing text,
    unit_cost_base numeric,
    unit_cost_pricing numeric,
    total_cost_base numeric,
    total_cost_pricing numeric,
    calc_notes text
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        bil.id,
        ci.sku,
        bil.part_role,
        bil.category_code,
        bil.qty_base,
        bil.uom_base,
        bil.qty_pricing,
        bil.uom_pricing,
        bil.unit_cost_base,
        bil.unit_cost_pricing,
        bil.total_cost_base,
        bil.total_cost_pricing,
        bil.calc_notes
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
    WHERE bi.sale_order_line_id = p_sale_order_line_id
    AND bil.deleted = false
    ORDER BY bil.category_code, bil.part_role;
END;
$$;

-- Query 2: Find invalid (measure_basis, uom) pairs in CatalogItems
CREATE OR REPLACE FUNCTION diagnostic_invalid_uom_measure_basis()
RETURNS TABLE(
    catalog_item_id uuid,
    sku text,
    item_name text,
    measure_basis text,
    uom text,
    is_valid boolean,
    validation_note text
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ci.id,
        ci.sku,
        ci.item_name,
        ci.measure_basis,
        ci.uom,
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
END;
$$;

-- Query 3: Compare QuoteLineComponents vs BomInstanceLines for a given quote_line_id
CREATE OR REPLACE FUNCTION diagnostic_quote_vs_bom_lines(
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
    qty_pricing numeric,
    uom_pricing text,
    unit_cost numeric,
    total_cost numeric
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
        NULL::numeric as qty_pricing,
        NULL::text as uom_pricing,
        qlc.unit_cost_exw,
        qlc.qty * COALESCE(qlc.unit_cost_exw, 0) as total_cost
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
        bil.qty_pricing,
        bil.uom_pricing,
        bil.unit_cost_exw,
        bil.total_cost_exw
    FROM "QuoteLines" ql
    INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
    INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id
    INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
    LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
    WHERE ql.id = p_quote_line_id
    AND bil.deleted = false
    ORDER BY component_role, source;
END;
$$;

-- ====================================================
-- STEP 10: Summary and Final Notes
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration completed: Robust UOM and Fabric Pricing Model';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Created/Updated:';
    RAISE NOTICE '   - Enums: uom_code, measure_basis_code, fabric_pricing_mode';
    RAISE NOTICE '   - CatalogItems: fabric_pricing_mode, pricing_uom (if missing)';
    RAISE NOTICE '   - BomInstanceLines: qty_base, uom_base, qty_pricing, uom_pricing, unit_cost_base, unit_cost_pricing, total_cost_base, total_cost_pricing';
    RAISE NOTICE '   - Functions: normalize_uom_to_canonical (updated), normalize_uom_to_pricing (new), validate_uom_measure_basis (new)';
    RAISE NOTICE '   - Functions: get_unit_cost_in_uom (enhanced), get_unit_cost_in_pricing_uom (new), calculate_fabric_pricing_qty (new)';
    RAISE NOTICE '   - Functions: populate_bom_line_base_pricing_fields (new), backfill_bom_lines_base_pricing (new)';
    RAISE NOTICE '   - Diagnostic functions: 3 queries for troubleshooting';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Next Steps:';
    RAISE NOTICE '   1. Update trigger function on_quote_approved_create_operational_docs() to call populate_bom_line_base_pricing_fields()';
    RAISE NOTICE '   2. Run backfill: SELECT * FROM backfill_bom_lines_base_pricing();';
    RAISE NOTICE '   3. Verify: SELECT * FROM diagnostic_invalid_uom_measure_basis();';
    RAISE NOTICE '';
END $$;

