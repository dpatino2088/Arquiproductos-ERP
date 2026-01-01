-- ====================================================
-- Migration: Add Fabric QuoteLineComponent Support
-- ====================================================
-- This migration creates a function to automatically create/update
-- a QuoteLineComponent with component_role='fabric' when a QuoteLine
-- is created/updated with a fabric variant (CatalogItems.is_fabric=true)
-- ====================================================

-- ====================================================
-- STEP 1: Create function to upsert fabric QuoteLineComponent
-- ====================================================

CREATE OR REPLACE FUNCTION public.upsert_fabric_quote_line_component(
    p_quote_line_id uuid,
    p_organization_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_line_record record;
    v_fabric_item record;
    v_fabric_qty numeric(12,4);
    v_canonical_uom text;
    v_unit_cost_exw numeric(12,4);
    v_fabric_component_id uuid;
    v_fabric_rotation boolean;
    v_fabric_heatseal boolean;
    v_width_m numeric;
    v_height_m numeric;
    v_roll_width_m numeric;
    v_drops numeric;
    v_linear_meters numeric;
BEGIN
    RAISE NOTICE '🔧 Upserting fabric QuoteLineComponent for quote_line_id: %', p_quote_line_id;
    
    -- Step 1: Load QuoteLine
    SELECT * INTO v_quote_line_record
    FROM "QuoteLines"
    WHERE id = p_quote_line_id 
      AND organization_id = p_organization_id 
      AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'QuoteLine not found: %', p_quote_line_id;
    END IF;
    
    -- Step 2: Load fabric CatalogItem
    SELECT * INTO v_fabric_item
    FROM "CatalogItems"
    WHERE id = v_quote_line_record.catalog_item_id
      AND organization_id = p_organization_id
      AND deleted = false
      AND is_fabric = true;
    
    IF NOT FOUND THEN
        -- Not a fabric item, soft-delete any existing fabric components
        UPDATE "QuoteLineComponents"
        SET deleted = true, updated_at = NOW()
        WHERE quote_line_id = p_quote_line_id
          AND component_role = 'fabric'
          AND deleted = false;
        
        RAISE NOTICE 'ℹ️  QuoteLine does not have a fabric item, removed any existing fabric components';
        RETURN jsonb_build_object('success', true, 'action', 'removed', 'reason', 'not_fabric');
    END IF;
    
    -- Step 3: Get fabric rotation and heatseal from QuoteLine metadata or config
    -- These might be stored in QuoteLines.metadata or as separate columns
    -- For now, we'll check if there are any metadata columns
    v_fabric_rotation := COALESCE(
        (v_quote_line_record.metadata->>'fabric_rotation')::boolean,
        false
    );
    v_fabric_heatseal := COALESCE(
        (v_quote_line_record.metadata->>'fabric_heatseal')::boolean,
        false
    );
    
    -- Step 4: Get dimensions
    v_width_m := COALESCE(v_quote_line_record.width_m, 0);
    v_height_m := COALESCE(v_quote_line_record.height_m, 0);
    v_roll_width_m := COALESCE(v_fabric_item.roll_width_m, 3.0); -- Default 3m if not set
    
    -- Step 5: Calculate fabric consumption based on pricing mode
    IF v_fabric_item.fabric_pricing_mode = 'per_sqm' THEN
        -- Area-based pricing: qty_m2 = width_m * height_m * qty
        v_fabric_qty := v_width_m * v_height_m * COALESCE(v_quote_line_record.qty, 1);
        v_canonical_uom := 'm2';
    ELSIF v_fabric_item.fabric_pricing_mode = 'per_linear_m' THEN
        -- Linear pricing: calculate drops and linear meters
        IF v_fabric_item.can_rotate AND v_fabric_rotation AND v_height_m > v_width_m THEN
            -- Rotated: use height as width, width as height
            v_drops := CEIL(GREATEST(v_height_m, 0.001) / GREATEST(v_roll_width_m, 0.001));
            v_linear_meters := v_drops * v_width_m;
        ELSE
            -- Not rotated: use width as width, height as height
            v_drops := CEIL(GREATEST(v_width_m, 0.001) / GREATEST(v_roll_width_m, 0.001));
            v_linear_meters := v_drops * v_height_m;
        END IF;
        
        -- Multiply by quote line quantity
        v_fabric_qty := v_linear_meters * COALESCE(v_quote_line_record.qty, 1);
        v_canonical_uom := 'm';
    ELSE
        -- Default: assume area-based if pricing mode is not set
        v_fabric_qty := v_width_m * v_height_m * COALESCE(v_quote_line_record.qty, 1);
        v_canonical_uom := 'm2';
    END IF;
    
    -- Step 6: Get unit cost in canonical UOM
    v_unit_cost_exw := public.get_unit_cost_in_uom(
        v_fabric_item.id,
        v_canonical_uom,
        p_organization_id
    );
    
    -- Step 7: Soft-delete existing fabric components for this quote line
    UPDATE "QuoteLineComponents"
    SET deleted = true, updated_at = NOW()
    WHERE quote_line_id = p_quote_line_id
      AND component_role = 'fabric'
      AND deleted = false;
    
    -- Step 8: Insert new fabric QuoteLineComponent
    INSERT INTO "QuoteLineComponents" (
        organization_id,
        quote_line_id,
        catalog_item_id,
        component_role,
        qty,
        uom,
        unit_cost_exw,
        source
    )
    VALUES (
        p_organization_id,
        p_quote_line_id,
        v_fabric_item.id,
        'fabric',
        v_fabric_qty,
        v_canonical_uom,
        v_unit_cost_exw,
        'configured_component'
    )
    RETURNING id INTO v_fabric_component_id;
    
    RAISE NOTICE '✅ Created fabric QuoteLineComponent: id=%, qty=%, uom=%, unit_cost_exw=%', 
                 v_fabric_component_id, v_fabric_qty, v_canonical_uom, v_unit_cost_exw;
    
    RETURN jsonb_build_object(
        'success', true,
        'action', 'created',
        'component_id', v_fabric_component_id,
        'qty', v_fabric_qty,
        'uom', v_canonical_uom,
        'unit_cost_exw', v_unit_cost_exw,
        'total_cost_exw', v_fabric_qty * v_unit_cost_exw
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error upserting fabric QuoteLineComponent: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.upsert_fabric_quote_line_component IS 
    'Creates or updates a QuoteLineComponent with component_role=''fabric'' for a QuoteLine. Calculates fabric consumption based on fabric_pricing_mode (per_sqm or per_linear_m), dimensions, rotation, and roll_width_m. Only ONE active fabric component per QuoteLine.';

-- ====================================================
-- STEP 2: Create trigger to auto-call function on QuoteLine insert/update
-- ====================================================

CREATE OR REPLACE FUNCTION public.trigger_upsert_fabric_component()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only process if catalog_item_id changed or is new
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND (
        OLD.catalog_item_id IS DISTINCT FROM NEW.catalog_item_id OR
        OLD.width_m IS DISTINCT FROM NEW.width_m OR
        OLD.height_m IS DISTINCT FROM NEW.height_m OR
        OLD.qty IS DISTINCT FROM NEW.qty
    )) THEN
        -- Call function to upsert fabric component
        PERFORM public.upsert_fabric_quote_line_component(NEW.id, NEW.organization_id);
    END IF;
    
    RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_upsert_fabric_component ON "QuoteLines";

-- Create trigger
CREATE TRIGGER trg_upsert_fabric_component
    AFTER INSERT OR UPDATE OF catalog_item_id, width_m, height_m, qty, metadata
    ON "QuoteLines"
    FOR EACH ROW
    WHEN (NEW.deleted = false)
    EXECUTE FUNCTION public.trigger_upsert_fabric_component();

COMMENT ON TRIGGER trg_upsert_fabric_component ON "QuoteLines" IS 
    'Automatically creates/updates fabric QuoteLineComponent when QuoteLine is created/updated with fabric variant.';

-- ====================================================
-- STEP 3: Backfill existing QuoteLines with fabric components
-- ====================================================

DO $$
DECLARE
    v_quote_line_record record;
    v_processed_count integer := 0;
    v_error_count integer := 0;
BEGIN
    RAISE NOTICE '🔄 Backfilling fabric QuoteLineComponents for existing QuoteLines...';
    
    FOR v_quote_line_record IN
        SELECT ql.id, ql.organization_id, ql.catalog_item_id
        FROM "QuoteLines" ql
        JOIN "CatalogItems" ci ON ql.catalog_item_id = ci.id
        WHERE ql.deleted = false
          AND ci.is_fabric = true
          AND ci.deleted = false
          AND NOT EXISTS (
              SELECT 1
              FROM "QuoteLineComponents" qlc
              WHERE qlc.quote_line_id = ql.id
                AND qlc.component_role = 'fabric'
                AND qlc.deleted = false
          )
    LOOP
        BEGIN
            PERFORM public.upsert_fabric_quote_line_component(
                v_quote_line_record.id,
                v_quote_line_record.organization_id
            );
            v_processed_count := v_processed_count + 1;
        EXCEPTION
            WHEN OTHERS THEN
                v_error_count := v_error_count + 1;
                RAISE WARNING 'Error processing QuoteLine %: %', v_quote_line_record.id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '✅ Backfill completed: % processed, % errors', v_processed_count, v_error_count;
END $$;

-- ====================================================
-- STEP 4: Summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Fabric QuoteLineComponent Support Added';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Created:';
    RAISE NOTICE '  - Function: upsert_fabric_quote_line_component()';
    RAISE NOTICE '  - Trigger: trg_upsert_fabric_component';
    RAISE NOTICE '';
    RAISE NOTICE 'Behavior:';
    RAISE NOTICE '  - Automatically creates/updates fabric QuoteLineComponent';
    RAISE NOTICE '  - Calculates consumption based on fabric_pricing_mode';
    RAISE NOTICE '  - Handles rotation and roll_width_m for linear pricing';
    RAISE NOTICE '  - Only ONE active fabric component per QuoteLine';
    RAISE NOTICE '';
END $$;








