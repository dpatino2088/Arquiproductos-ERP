-- ====================================================
-- Migration: Sync UOM from CatalogItems (Source of Truth)
-- ====================================================
-- This migration ensures that:
-- 1. BOMComponents.uom is automatically synced from CatalogItems.uom
-- 2. All existing BOMComponents are updated to match CatalogItems.uom
-- 3. A trigger maintains synchronization automatically
-- 4. Functions use CatalogItems.uom directly when possible
-- ====================================================

-- Step 0: Ensure QuoteLineComponents.uom column exists (if migration 172 wasn't run)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'QuoteLineComponents' 
        AND column_name = 'uom'
    ) THEN
        ALTER TABLE "QuoteLineComponents"
        ADD COLUMN uom text;
        
        RAISE NOTICE '✅ Added uom column to QuoteLineComponents';
    ELSE
        RAISE NOTICE '⏭️  uom column already exists in QuoteLineComponents';
    END IF;
    
    -- Add constraint for valid UOMs if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'check_quote_line_components_uom_valid'
        AND conrelid = 'public."QuoteLineComponents"'::regclass
    ) THEN
        ALTER TABLE "QuoteLineComponents"
        ADD CONSTRAINT check_quote_line_components_uom_valid 
        CHECK (uom IS NULL OR uom IN ('mts', 'yd', 'ft', 'und', 'pcs', 'ea', 'set', 'pack', 'm2', 'yd2'));
        
        RAISE NOTICE '✅ Added UOM validation constraint to QuoteLineComponents';
    ELSE
        RAISE NOTICE '⏭️  UOM validation constraint already exists in QuoteLineComponents';
    END IF;
END $$;

-- Step 1: Normalize CatalogItems.uom values to match valid UOMs
-- Map common variations to canonical values
DO $$
DECLARE
    v_updated_count integer;
BEGIN
    -- Normalize UOM values in CatalogItems to match valid BOM UOMs
    UPDATE "CatalogItems" ci
    SET uom = CASE
        -- Linear units: normalize to mts, yd, ft
        WHEN UPPER(TRIM(ci.uom)) IN ('M', 'MTS', 'METERS', 'METRE', 'METRES', 'LINEAR_M', 'LINEAR_METER') THEN 'mts'
        WHEN UPPER(TRIM(ci.uom)) IN ('YD', 'YDS', 'YARD', 'YARDS') THEN 'yd'
        WHEN UPPER(TRIM(ci.uom)) IN ('FT', 'FEET', 'FOOT') THEN 'ft'
        -- Area units: normalize to m2, yd2
        WHEN UPPER(TRIM(ci.uom)) IN ('M2', 'M²', 'SQM', 'SQUARE_M', 'SQUARE_METER', 'SQUARE_METERS') THEN 'm2'
        WHEN UPPER(TRIM(ci.uom)) IN ('YD2', 'YD²', 'SQYD', 'SQUARE_YARD', 'SQUARE_YARDS') THEN 'yd2'
        -- Piece units: normalize to ea, pcs, und, set, pack
        WHEN UPPER(TRIM(ci.uom)) IN ('EA', 'EACH', 'UNIT', 'UNITS', 'UN', 'UNS') THEN 'ea'
        WHEN UPPER(TRIM(ci.uom)) IN ('PCS', 'PIECE', 'PIECES') THEN 'pcs'
        WHEN UPPER(TRIM(ci.uom)) IN ('UND', 'UNDS') THEN 'und'
        WHEN UPPER(TRIM(ci.uom)) = 'SET' THEN 'set'
        WHEN UPPER(TRIM(ci.uom)) = 'PACK' THEN 'pack'
        -- Keep valid values as-is
        WHEN UPPER(TRIM(ci.uom)) IN ('MTS', 'YD', 'FT', 'M2', 'YD2', 'EA', 'PCS', 'UND', 'SET', 'PACK') THEN LOWER(TRIM(ci.uom))
        -- Default to 'ea' for unknown values
        ELSE 'ea'
    END
    WHERE ci.uom IS NOT NULL
    AND ci.deleted = false
    AND UPPER(TRIM(ci.uom)) NOT IN ('MTS', 'YD', 'FT', 'M2', 'YD2', 'EA', 'PCS', 'UND', 'SET', 'PACK');
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Normalized % CatalogItems UOM values', v_updated_count;
    
    -- Also sync cost_uom with uom if cost_uom is NULL or empty
    -- Note: cost_uom can be different from uom if cost is in a different unit,
    -- but we'll sync it as a default if it's missing
    UPDATE "CatalogItems" ci
    SET cost_uom = ci.uom
    WHERE ci.cost_uom IS NULL
    AND ci.uom IS NOT NULL
    AND ci.deleted = false;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Synced % CatalogItems cost_uom values from uom', v_updated_count;
END $$;

-- Step 2: Sync all existing BOMComponents.uom from CatalogItems.uom
DO $$
DECLARE
    v_updated_count integer;
BEGIN
    UPDATE "BOMComponents" bc
    SET uom = COALESCE(ci.uom, 'ea')
    FROM "CatalogItems" ci
    WHERE bc.component_item_id = ci.id
    AND bc.deleted = false
    AND ci.deleted = false
    AND (bc.uom IS NULL OR bc.uom != COALESCE(ci.uom, 'ea'));
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Synced % BOMComponents UOM values from CatalogItems', v_updated_count;
END $$;

-- Step 3: For BOMComponents with component_role but no component_item_id, 
-- set UOM based on component_role (these are auto-selected components)
DO $$
DECLARE
    v_updated_count integer;
BEGIN
    UPDATE "BOMComponents" bc
    SET uom = CASE
        WHEN bc.component_role LIKE '%tube%' OR 
             bc.component_role LIKE '%rail%' OR 
             bc.component_role LIKE '%profile%' OR 
             bc.component_role LIKE '%cassette%' OR
             bc.component_role LIKE '%channel%' THEN 'mts'
        WHEN bc.component_role LIKE '%fabric%' THEN 'm2'
        ELSE 'ea'
    END
    WHERE bc.component_item_id IS NULL
    AND bc.deleted = false
    AND bc.component_role IS NOT NULL;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Set UOM for % auto-select BOMComponents based on component_role', v_updated_count;
END $$;

-- Step 4: Create function to sync UOM from CatalogItems
CREATE OR REPLACE FUNCTION sync_bom_component_uom_from_catalog()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_catalog_uom text;
BEGIN
    -- If component_item_id is set, sync UOM from CatalogItems
    IF NEW.component_item_id IS NOT NULL THEN
        SELECT COALESCE(ci.uom, 'ea') INTO v_catalog_uom
        FROM "CatalogItems" ci
        WHERE ci.id = NEW.component_item_id
        AND ci.deleted = false
        LIMIT 1;
        
        IF v_catalog_uom IS NOT NULL THEN
            NEW.uom := v_catalog_uom;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Step 5: Create trigger to auto-sync UOM on INSERT
DROP TRIGGER IF EXISTS trg_sync_bom_component_uom_insert ON "BOMComponents";
CREATE TRIGGER trg_sync_bom_component_uom_insert
    BEFORE INSERT ON "BOMComponents"
    FOR EACH ROW
    WHEN (NEW.component_item_id IS NOT NULL)
    EXECUTE FUNCTION sync_bom_component_uom_from_catalog();

-- Step 6: Create trigger to auto-sync UOM on UPDATE (only if component_item_id changes)
DROP TRIGGER IF EXISTS trg_sync_bom_component_uom_update ON "BOMComponents";
CREATE TRIGGER trg_sync_bom_component_uom_update
    BEFORE UPDATE ON "BOMComponents"
    FOR EACH ROW
    WHEN (NEW.component_item_id IS NOT NULL 
          AND (OLD.component_item_id IS DISTINCT FROM NEW.component_item_id 
               OR OLD.uom IS DISTINCT FROM NEW.uom))
    EXECUTE FUNCTION sync_bom_component_uom_from_catalog();

-- Step 7: Verify QuoteLineComponents.uom column exists before updating function
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'QuoteLineComponents' 
        AND column_name = 'uom'
    ) THEN
        RAISE EXCEPTION 'QuoteLineComponents.uom column does not exist. Please run migration 172 first or ensure Step 0 completed successfully.';
    END IF;
END $$;

-- Step 8: Update generate_configured_bom_for_quote_line to use CatalogItems.uom directly
-- This ensures we always use the source of truth
CREATE OR REPLACE FUNCTION public.generate_configured_bom_for_quote_line(
    p_quote_line_id uuid,
    p_product_type_id uuid,
    p_organization_id uuid,
    p_drive_type text, -- 'manual' | 'motor'
    p_bottom_rail_type text, -- 'standard' | 'wrapped'
    p_cassette boolean,
    p_cassette_type text, -- 'round' | 'square' | 'l-shape' (NULL if cassette = false)
    p_side_channel boolean,
    p_side_channel_type text, -- 'side_only' | 'side_and_bottom' (NULL if side_channel = false)
    p_hardware_color text, -- 'white' | 'black' | 'silver' | 'bronze' | etc.
    p_width_m numeric,
    p_height_m numeric,
    p_qty numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_line_record record;
    v_bom_template_record record;
    v_bom_component_record record;
    v_resolved_catalog_item_id uuid;
    v_catalog_item_record record;
    v_component_qty numeric;
    v_block_condition_match boolean;
    v_inserted_components jsonb := '[]'::jsonb;
    v_component_result jsonb;
    v_inserted_component_id uuid;
    v_area_sqm numeric;
    v_tube_width_rule text;
    v_catalog_uom text; -- UOM from CatalogItems (source of truth)
    v_canonical_uom text; -- Canonical UOM for cost calculation ('m', 'm2', or 'ea')
BEGIN
    RAISE NOTICE '🔧 Generating configured BOM for quote line: %', p_quote_line_id;
    
    -- Step 1: Load QuoteLine to get dimensions
    SELECT * INTO v_quote_line_record
    FROM "QuoteLines"
    WHERE id = p_quote_line_id AND organization_id = p_organization_id AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'QuoteLine not found: %', p_quote_line_id;
    END IF;
    
    -- Calculate area for area-based components
    v_area_sqm := COALESCE(p_width_m, v_quote_line_record.width_m, 0) * COALESCE(p_height_m, v_quote_line_record.height_m, 0);
    
    -- Determine tube width rule based on width
    IF COALESCE(p_width_m, v_quote_line_record.width_m, 0) <= 3.0 THEN
        v_tube_width_rule := '42';
    ELSIF COALESCE(p_width_m, v_quote_line_record.width_m, 0) <= 4.0 THEN
        v_tube_width_rule := '65';
    ELSE
        v_tube_width_rule := '80';
    END IF;
    
    -- Step 2: Delete existing configured components for this quote line
    DELETE FROM "QuoteLineComponents"
    WHERE quote_line_id = p_quote_line_id
    AND source = 'configured_component'
    AND organization_id = p_organization_id;
    
    -- Step 3: Find BOM Template by product_type_id
    SELECT * INTO v_bom_template_record
    FROM "BOMTemplates" bt
    WHERE bt.product_type_id = p_product_type_id
    AND bt.organization_id = p_organization_id
    AND bt.deleted = false
    AND bt.active = true
    ORDER BY bt.created_at DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No active BOM template found for product type: %', p_product_type_id;
    END IF;
    
    -- Step 4: Loop through BOM Components and resolve them
    FOR v_bom_component_record IN
        SELECT bc.*
        FROM "BOMComponents" bc
        WHERE bc.bom_template_id = v_bom_template_record.id
        AND bc.organization_id = p_organization_id
        AND bc.deleted = false
        ORDER BY bc.sequence_order, bc.id
    LOOP
        -- Step 4.1: Check block condition
        v_block_condition_match := true;
        
        IF v_bom_component_record.block_condition IS NOT NULL THEN
            -- Evaluate block condition JSON
            IF v_bom_component_record.block_type = 'drive' THEN
                IF (v_bom_component_record.block_condition->>'drive_type')::text != p_drive_type THEN
                    v_block_condition_match := false;
                END IF;
            ELSIF v_bom_component_record.block_type = 'bottom_rail' THEN
                IF (v_bom_component_record.block_condition->>'bottom_rail_type')::text != p_bottom_rail_type THEN
                    v_block_condition_match := false;
                END IF;
            ELSIF v_bom_component_record.block_type = 'cassette' THEN
                IF NOT p_cassette OR (v_bom_component_record.block_condition->>'cassette_type')::text != p_cassette_type THEN
                    v_block_condition_match := false;
                END IF;
            ELSIF v_bom_component_record.block_type = 'side_channel' THEN
                IF NOT p_side_channel OR (v_bom_component_record.block_condition->>'side_channel_type')::text != p_side_channel_type THEN
                    v_block_condition_match := false;
                END IF;
            END IF;
        END IF;
        
        -- Skip if block condition doesn't match
        IF NOT v_block_condition_match THEN
            CONTINUE;
        END IF;
        
        -- Step 4.2: Resolve catalog_item_id
        v_resolved_catalog_item_id := NULL;
        
        IF v_bom_component_record.component_item_id IS NOT NULL THEN
            -- Direct component_item_id
            v_resolved_catalog_item_id := v_bom_component_record.component_item_id;
        ELSIF v_bom_component_record.auto_select = true THEN
            -- Auto-select by rules (e.g., tube by width)
            IF v_bom_component_record.component_role = 'tube' THEN
                -- Resolve tube by width rule
                SELECT id INTO v_resolved_catalog_item_id
                FROM "CatalogItems"
                WHERE organization_id = p_organization_id
                AND deleted = false
                AND item_type = 'component'
                AND sku LIKE 'RTU-' || v_tube_width_rule || '%'
                LIMIT 1;
            END IF;
        END IF;
        
        IF v_resolved_catalog_item_id IS NULL THEN
            CONTINUE;
        END IF;
        
        -- Step 4.3: Apply hardware color mapping if applies_color = true
        IF v_bom_component_record.applies_color = true AND p_hardware_color IS NOT NULL THEN
            SELECT mapped_part_id INTO v_resolved_catalog_item_id
            FROM "HardwareColorMapping"
            WHERE organization_id = p_organization_id
            AND base_part_id = v_resolved_catalog_item_id
            AND hardware_color = LOWER(p_hardware_color)
            AND deleted = false
            LIMIT 1;
            
            -- If no mapping found, keep original
            IF v_resolved_catalog_item_id IS NULL THEN
                -- Try to find base_part_id again (might have been changed by previous mapping)
                SELECT bc.component_item_id INTO v_resolved_catalog_item_id
                FROM "BOMComponents" bc
                WHERE bc.id = v_bom_component_record.id;
            END IF;
        END IF;
        
        -- Step 4.4: Get CatalogItem to retrieve UOM (source of truth)
        SELECT * INTO v_catalog_item_record
        FROM "CatalogItems"
        WHERE id = v_resolved_catalog_item_id
        AND organization_id = p_organization_id
        AND deleted = false;
        
        IF NOT FOUND THEN
            CONTINUE;
        END IF;
        
        -- Use UOM from CatalogItems (source of truth)
        v_catalog_uom := COALESCE(v_catalog_item_record.uom, 'ea');
        
        -- Step 4.5: Calculate quantity
        v_component_qty := v_bom_component_record.qty_per_unit;
        
        -- Use UOM from CatalogItem to determine calculation method
        -- Handle linear UOMs (mts, yd, ft)
        IF v_catalog_uom IN ('mts', 'yd', 'ft') THEN
            -- Linear meters/yards: use width or height based on component_role
            IF v_bom_component_record.component_role = 'tube' OR 
               v_bom_component_record.component_role LIKE '%profile%' OR
               v_bom_component_record.component_role LIKE '%rail%' OR
               v_bom_component_record.component_role LIKE '%cassette%' THEN
                -- Use width for horizontal components
                v_component_qty := v_bom_component_record.qty_per_unit * COALESCE(p_width_m, v_quote_line_record.width_m, 0);
            ELSIF v_bom_component_record.component_role LIKE '%side%channel%' AND 
                  v_bom_component_record.component_role NOT LIKE '%bottom%' THEN
                -- Side channel profiles: height × 2 units (always 2 profiles)
                v_component_qty := COALESCE(p_height_m, v_quote_line_record.height_m, 0) * 2;
            ELSIF v_bom_component_record.component_role LIKE '%bottom%channel%' OR
                  v_bom_component_record.component_role LIKE '%bottom_channel%' THEN
                -- Bottom channel profile: width × 1 unit (single profile)
                v_component_qty := COALESCE(p_width_m, v_quote_line_record.width_m, 0) * 1;
            ELSE
                -- Use height for other vertical components
                v_component_qty := v_bom_component_record.qty_per_unit * COALESCE(p_height_m, v_quote_line_record.height_m, 0);
            END IF;
        -- Handle area UOMs (m2, yd2)
        ELSIF v_catalog_uom IN ('m2', 'yd2') THEN
            -- Square meters/yards: use area
            v_component_qty := v_bom_component_record.qty_per_unit * COALESCE(v_area_sqm, 0);
        END IF;
        -- For piece UOMs (ea, pcs, und, set, pack), qty_per_unit is already correct
        
        -- Multiply by quote line quantity
        v_component_qty := v_component_qty * COALESCE(p_qty, v_quote_line_record.qty, 1);
        
        -- Step 4.6: Convert to canonical UOM for cost calculation
        -- Canonical UOMs: 'm' (linear), 'm2' (area), 'ea' (pieces)
        IF v_catalog_uom IN ('mts', 'yd', 'ft') THEN
            v_canonical_uom := 'm';
        ELSIF v_catalog_uom IN ('m2', 'yd2') THEN
            v_canonical_uom := 'm2';
        ELSE
            -- All piece units (ea, pcs, und, set, pack) map to 'ea'
            v_canonical_uom := 'ea';
        END IF;
        
        -- Step 4.7: Insert into QuoteLineComponents with source='configured_component'
        -- Use CatalogItems.uom (source of truth) instead of BOMComponents.uom
        INSERT INTO "QuoteLineComponents" (
            organization_id,
            quote_line_id,
            catalog_item_id,
            qty,
            uom, -- Store UOM from CatalogItems (source of truth)
            unit_cost_exw,
            component_role,
            source
        )
        VALUES (
            p_organization_id,
            p_quote_line_id,
            v_resolved_catalog_item_id,
            v_component_qty,
            v_catalog_uom, -- Use UOM from CatalogItems (source of truth)
            public.get_unit_cost_in_uom(v_resolved_catalog_item_id, v_canonical_uom, p_organization_id),
            v_bom_component_record.component_role,
            'configured_component'
        )
        RETURNING id INTO v_inserted_component_id;
        
        -- Add to result array
        v_component_result := jsonb_build_object(
            'id', v_inserted_component_id,
            'catalog_item_id', v_resolved_catalog_item_id,
            'qty', v_component_qty,
            'uom', v_catalog_uom,
            'component_role', v_bom_component_record.component_role
        );
        v_inserted_components := v_inserted_components || v_component_result;
    END LOOP;
    
    -- Step 5: Return result
    RETURN jsonb_build_object(
        'success', true,
        'quote_line_id', p_quote_line_id,
        'components_count', jsonb_array_length(v_inserted_components),
        'components', v_inserted_components
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error generating BOM: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.generate_configured_bom_for_quote_line IS 
    'Generates BOM components using block-based system. Uses UOM from CatalogItems (source of truth) and stores it in QuoteLineComponents. Converts to canonical UOM (m, m2, ea) for cost calculations via get_unit_cost_in_uom. Each customer choice (drive_type, bottom_rail_type, cassette, side_channel, side_channel_type, hardware_color) activates specific BOM blocks.';

-- Step 9: Update comments
COMMENT ON COLUMN "BOMComponents".uom IS 
    'Unit of Measure for qty_per_unit. Automatically synced from CatalogItems.uom when component_item_id is set. Valid values: mts, yd, ft, m2, yd2, und, pcs, ea, set, pack. This UOM is stored in QuoteLineComponents when BOM is generated, but the source of truth is always CatalogItems.uom.';

COMMENT ON COLUMN "QuoteLineComponents".uom IS 
    'Unit of Measure for the component quantity. Source of truth is CatalogItems.uom. Valid values: mts (meters), yd (yards), ft (feet), m2 (square meters), yd2 (square yards), und (unit), pcs (pieces), ea (each), set, pack';

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration complete: UOM synchronization from CatalogItems';
    RAISE NOTICE '   - CatalogItems.uom is now the source of truth';
    RAISE NOTICE '   - BOMComponents.uom is automatically synced via triggers';
    RAISE NOTICE '   - generate_configured_bom_for_quote_line uses CatalogItems.uom directly';
    RAISE NOTICE '   - All existing records have been synchronized';
END $$;

