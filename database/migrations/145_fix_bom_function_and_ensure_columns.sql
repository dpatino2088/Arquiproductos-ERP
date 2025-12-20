-- ====================================================
-- Migration: Fix BOM function and ensure QuoteLines columns exist
-- ====================================================
-- 1. Recreate generate_configured_bom_for_quote_line function to ensure it's found
-- 2. Ensure area and position columns exist in QuoteLines
-- ====================================================

-- Step 1: Drop ALL existing versions of the function
DO $$ 
BEGIN
    -- Drop by signature (all possible combinations)
    DROP FUNCTION IF EXISTS public.generate_configured_bom_for_quote_line(uuid, uuid, uuid, text, text, boolean, text, boolean, text, text, numeric, numeric, numeric);
    DROP FUNCTION IF EXISTS public.generate_configured_bom_for_quote_line(uuid, uuid, uuid, text, text, boolean, text, boolean, text, text, numeric, numeric);
    -- Drop by name (CASCADE to handle dependencies)
    DROP FUNCTION IF EXISTS public.generate_configured_bom_for_quote_line CASCADE;
EXCEPTION WHEN OTHERS THEN
    -- Ignore errors if function doesn't exist
    NULL;
END $$;

-- Step 2: Recreate the function (copy from migration 134)
CREATE OR REPLACE FUNCTION public.generate_configured_bom_for_quote_line(
    p_quote_line_id uuid,
    p_product_type_id uuid,
    p_organization_id uuid,
    p_drive_type text, -- 'manual' | 'motor'
    p_bottom_rail_type text, -- 'standard' | 'wrapped'
    p_cassette boolean,
    p_cassette_type text, -- 'standard' | 'recessed' | 'surface' (NULL if cassette = false)
    p_side_channel boolean,
    p_side_channel_type text, -- 'left' | 'right' | 'both' (NULL if side_channel = false)
    p_hardware_color text, -- 'white' | 'black' | 'silver' | 'bronze'
    p_width_m numeric,
    p_height_m numeric,
    p_qty numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_line_record RECORD;
    v_bom_template_record RECORD;
    v_bom_component_record RECORD;
    v_resolved_catalog_item_id uuid;
    v_component_qty numeric;
    v_block_condition_match boolean;
    v_color_match boolean;
    v_inserted_components jsonb := '[]'::jsonb;
    v_component_result jsonb;
    v_inserted_component_id uuid;
    v_area_sqm numeric;
    v_tube_width_rule text;
BEGIN
    RAISE NOTICE '🔧 Generating configured BOM for quote line: %', p_quote_line_id;
    
    -- Step 1: Load QuoteLine to get dimensions
    SELECT 
        id,
        organization_id,
        quote_id,
        width_m,
        height_m,
        qty
    INTO v_quote_line_record
    FROM "QuoteLines"
    WHERE id = p_quote_line_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'QuoteLine with id % not found or deleted', p_quote_line_id;
    END IF;
    
    -- Use provided dimensions or fallback to QuoteLine dimensions
    v_area_sqm := COALESCE(p_width_m * p_height_m, v_quote_line_record.width_m * v_quote_line_record.height_m, 0);
    
    -- Step 2: Find BOM Template by product_type_id and hardware_color
    SELECT * INTO v_bom_template_record
    FROM "BOMTemplates"
    WHERE product_type_id = p_product_type_id
    AND organization_id = p_organization_id
    AND deleted = false
    AND (
        -- Match by hardware_color in template name (e.g., "Roller Shade - White")
        (LOWER(name) LIKE '%' || LOWER(p_hardware_color) || '%')
        OR
        -- Fallback: use first template for this product type
        (SELECT COUNT(*) FROM "BOMTemplates" 
         WHERE product_type_id = p_product_type_id 
         AND organization_id = p_organization_id 
         AND deleted = false) = 1
    )
    ORDER BY 
        CASE WHEN LOWER(name) LIKE '%' || LOWER(p_hardware_color) || '%' THEN 0 ELSE 1 END
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE WARNING 'No BOM Template found for product_type_id: %, hardware_color: %', p_product_type_id, p_hardware_color;
        RETURN jsonb_build_object(
            'success', false,
            'message', 'No BOM Template found',
            'components', '[]'::jsonb
        );
    END IF;
    
    RAISE NOTICE '✅ Found BOM Template: % (id: %)', v_bom_template_record.name, v_bom_template_record.id;
    
    -- Step 3: Get BOM Components for this template
    -- Filter by block_condition, hardware_color, cassette_type, and side_channel_type
    FOR v_bom_component_record IN
        SELECT *
        FROM "BOMComponents"
        WHERE bom_template_id = v_bom_template_record.id
        AND organization_id = p_organization_id
        AND deleted = false
        AND (
            -- Check block_condition matches
            (
                block_condition IS NULL 
                OR block_condition = '{}'::jsonb
                OR (
                    -- Drive block: check drive_type
                    (block_type = 'drive' AND (block_condition->>'drive_type')::text = p_drive_type)
                    OR
                    -- Bottom rail block: check bottom_rail_type
                    (block_type = 'bottom_rail' AND (block_condition->>'bottom_rail_type')::text = p_bottom_rail_type)
                    OR
                    -- Cassette block: check cassette and cassette_type
                    (block_type = 'cassette' AND p_cassette = true 
                     AND (block_condition->>'cassette')::boolean = true
                     AND (block_condition->>'cassette_type' IS NULL OR (block_condition->>'cassette_type')::text = p_cassette_type))
                    OR
                    -- Side channel block: check side_channel and side_channel_type
                    (block_type = 'side_channel' AND p_side_channel = true
                     AND (block_condition->>'side_channel')::boolean = true
                     AND (block_condition->>'side_channel_type' IS NULL OR (block_condition->>'side_channel_type')::text = p_side_channel_type))
                    OR
                    -- Brackets block: always active (no condition)
                    (block_type = 'brackets')
                )
            )
        )
        AND (
            -- Check hardware_color match
            hardware_color IS NULL 
            OR hardware_color = p_hardware_color
            OR (applies_color = false)
        )
        ORDER BY sequence_order, id
    LOOP
        -- Step 4: Resolve component SKU
        IF v_bom_component_record.auto_select = true AND v_bom_component_record.component_item_id IS NULL THEN
            -- Component needs to be resolved by rule
            -- For now, skip components that need rule resolution (will be implemented later)
            RAISE NOTICE '⚠️  Component % needs rule resolution, skipping for now', v_bom_component_record.component_role;
            CONTINUE;
        ELSIF v_bom_component_record.component_item_id IS NOT NULL THEN
            -- Direct SKU reference
            v_resolved_catalog_item_id := v_bom_component_record.component_item_id;
        ELSE
            -- No SKU available, skip
            RAISE NOTICE '⚠️  Component % has no SKU, skipping', v_bom_component_record.component_role;
            CONTINUE;
        END IF;
        
        -- Step 5: Calculate component quantity
        -- For now, use qty_per_unit from BOMComponent
        -- TODO: Apply rules for tube width selection, etc.
        v_component_qty := v_bom_component_record.qty_per_unit * COALESCE(p_qty, v_quote_line_record.qty, 1);
        
        -- Step 6: Insert into QuoteLineComponents
        INSERT INTO "QuoteLineComponents" (
            organization_id,
            quote_line_id,
            catalog_item_id,
            component_role,
            qty,
            source,
            unit_cost_exw
        )
        VALUES (
            p_organization_id,
            p_quote_line_id,
            v_resolved_catalog_item_id,
            v_bom_component_record.component_role,
            v_component_qty,
            'configured_component',
            NULL -- Will be calculated by cost engine
        )
        RETURNING id INTO v_inserted_component_id;
        
        -- Add to results
        v_component_result := jsonb_build_object(
            'id', v_inserted_component_id,
            'catalog_item_id', v_resolved_catalog_item_id,
            'component_role', v_bom_component_record.component_role,
            'qty', v_component_qty
        );
        v_inserted_components := v_inserted_components || jsonb_build_array(v_component_result);
        
        RAISE NOTICE '✅ Inserted component: % (role: %, qty: %)', 
            v_resolved_catalog_item_id, 
            v_bom_component_record.component_role,
            v_component_qty;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'bom_template_id', v_bom_template_record.id,
        'bom_template_name', v_bom_template_record.name,
        'components', v_inserted_components
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error generating BOM: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'components', '[]'::jsonb
        );
END;
$$;

-- Step 3: Ensure area and position columns exist in QuoteLines
DO $$
BEGIN
  -- Add area column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'QuoteLines' 
      AND column_name = 'area'
  ) THEN
    ALTER TABLE public."QuoteLines"
      ADD COLUMN area text NULL;
    RAISE NOTICE '✅ Added area column to QuoteLines';
  ELSE
    RAISE NOTICE '⚠️  area column already exists in QuoteLines';
  END IF;

  -- Add position column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'QuoteLines' 
      AND column_name = 'position'
  ) THEN
    ALTER TABLE public."QuoteLines"
      ADD COLUMN position text NULL;
    RAISE NOTICE '✅ Added position column to QuoteLines';
  ELSE
    RAISE NOTICE '⚠️  position column already exists in QuoteLines';
  END IF;
END $$;

-- Add comment
COMMENT ON FUNCTION public.generate_configured_bom_for_quote_line IS 
'Generates BOM components using the block-based system. Each customer choice activates a BOM block.
Components are filtered by block_condition and hardware_color. Recreated to ensure proper function resolution.';

