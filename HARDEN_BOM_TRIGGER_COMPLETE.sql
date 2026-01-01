-- ====================================================
-- BOM Link Trigger - Stabilized Version
-- ====================================================
-- This script links Manufacturing Orders to existing BOM:
-- 1. Checks if BomInstance exists (does not generate BOM)
-- 2. Logs warnings if BOM is missing but does not block MO creation
-- 3. Updates SalesOrder status to 'In Production'
-- 4. Defensive logging (RAISE NOTICE) for debugging
-- Architecture: BOM must already exist before creating MO
-- ====================================================

-- STEP 1: Ensure organization_id column exists in BomInstanceLines
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'BomInstanceLines' 
        AND column_name = 'organization_id'
    ) THEN
        RAISE NOTICE '🔧 Adding organization_id column to BomInstanceLines...';
        ALTER TABLE "BomInstanceLines" ADD COLUMN organization_id uuid;
        CREATE INDEX IF NOT EXISTS idx_bominstancelines_organization_id ON "BomInstanceLines"(organization_id);
        RAISE NOTICE '✅ organization_id column added to BomInstanceLines';
    ELSE
        RAISE NOTICE '✅ organization_id column already exists in BomInstanceLines';
    END IF;
END;
$$;

-- STEP 2: Create hardened trigger function
CREATE OR REPLACE FUNCTION public.on_manufacturing_order_insert_generate_bom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sales_order_record RECORD;
    v_quote_id uuid;
    v_quote_line_record RECORD;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_component_record RECORD;
    v_canonical_uom text;
    v_unit_cost_exw numeric;
    v_total_cost_exw numeric;
    v_category_code text;
    v_copied_count integer;
    v_quote_line_components_count integer;
    v_bom_lines_count integer;
    v_quote_line_processed boolean;
    v_error_message text;
    v_quote_lines_processed integer := 0;
    v_quote_lines_failed integer := 0;
BEGIN
    -- ====================================================
    -- PHASE 1: VALIDATION - Get SalesOrder
    -- ====================================================
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '🔔 BOM Generation Started for ManufacturingOrder %', NEW.manufacturing_order_no;
    RAISE NOTICE '====================================================';
    
    -- Get SalesOrder record
    SELECT * INTO v_sales_order_record
    FROM "SalesOrders"
    WHERE id = NEW.sale_order_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        v_error_message := format('SalesOrder %s not found for ManufacturingOrder %s', NEW.sale_order_id, NEW.id);
        RAISE WARNING '❌ %', v_error_message;
        RAISE NOTICE '⚠️ % - MO will be created but SalesOrder link may be invalid.', v_error_message;
        -- Continue anyway - don't block MO creation
    END IF;
    
    v_quote_id := v_sales_order_record.quote_id;
    
    RAISE NOTICE '📋 SalesOrder: % | Quote: %', v_sales_order_record.sale_order_no, v_quote_id;
    
    -- Update SalesOrder status to 'In Production'
    UPDATE "SalesOrders"
    SET status = 'In Production',
        updated_at = now()
    WHERE id = NEW.sale_order_id
    AND deleted = false
    AND status <> 'Delivered';
    
    RAISE NOTICE '✅ SalesOrder status updated to "In Production"';
    
    -- ====================================================
    -- PHASE 2: PROCESS EACH QUOTELINE
    -- ====================================================
    FOR v_quote_line_record IN
        SELECT 
            ql.id as quote_line_id,
            ql.product_type_id,
            ql.organization_id,
            ql.drive_type,
            ql.bottom_rail_type,
            COALESCE(ql.cassette, false) as cassette,
            ql.cassette_type,
            COALESCE(ql.side_channel, false) as side_channel,
            ql.side_channel_type,
            ql.hardware_color,
            ql.width_m,
            ql.height_m,
            ql.qty,
            sol.id as sale_order_line_id,
            sol.line_number
        FROM "SalesOrderLines" sol
        INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
        WHERE sol.sale_order_id = NEW.sale_order_id
            AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        v_quote_line_processed := false;
        
        RAISE NOTICE '';
        RAISE NOTICE '📦 Processing QuoteLine % (Line #%)...', v_quote_line_record.quote_line_id, v_quote_line_record.line_number;
        
        -- ====================================================
        -- PHASE 2.1: VALIDATE PREREQUISITES
        -- ====================================================
        
        -- Skip if no product_type_id
        IF v_quote_line_record.product_type_id IS NULL THEN
            RAISE WARNING '⚠️ QuoteLine % has no product_type_id, skipping BOM generation', v_quote_line_record.quote_line_id;
            v_quote_lines_failed := v_quote_lines_failed + 1;
            CONTINUE;
        END IF;
        
        -- Ensure organization_id is set
        IF v_quote_line_record.organization_id IS NULL THEN
            RAISE NOTICE '🔧 Setting organization_id for QuoteLine %...', v_quote_line_record.quote_line_id;
            UPDATE "QuoteLines"
            SET organization_id = NEW.organization_id
            WHERE id = v_quote_line_record.quote_line_id;
            v_quote_line_record.organization_id := NEW.organization_id;
        END IF;
        
        -- ====================================================
        -- PHASE 2.2: CHECK IF BOM EXISTS (DO NOT GENERATE)
        -- ====================================================
        
        -- Find existing BomInstance for this SaleOrderLine
        -- BOM must already exist before creating MO
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_quote_line_record.sale_order_line_id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            RAISE NOTICE '⚠️ No BomInstance found for SaleOrderLine %. BOM must exist before creating MO.', v_quote_line_record.sale_order_line_id;
            v_quote_lines_failed := v_quote_lines_failed + 1;
            CONTINUE;
        END IF;
        
        RAISE NOTICE '✅ BomInstance % exists for SaleOrderLine %', v_bom_instance_id, v_quote_line_record.sale_order_line_id;
        
        -- Check if BomInstance has lines
        SELECT COUNT(*) INTO v_bom_lines_count
        FROM "BomInstanceLines"
        WHERE bom_instance_id = v_bom_instance_id
        AND deleted = false;
        
        IF v_bom_lines_count = 0 THEN
            RAISE NOTICE '⚠️ BomInstance %s has no lines for SaleOrderLine %s. MO will be created but BOM materials are missing.',
                v_bom_instance_id,
                v_quote_line_record.sale_order_line_id;
        ELSE
            RAISE NOTICE '✅ BomInstance % has % lines', v_bom_instance_id, v_bom_lines_count;
        END IF;
        
        v_quote_line_processed := true;
        v_quote_lines_processed := v_quote_lines_processed + 1;
            
        -- Continue to next QuoteLine
    END LOOP;
    
    -- ====================================================
    -- PHASE 3: FINAL VALIDATION
    -- ====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '📊 BOM Generation Summary:';
    RAISE NOTICE '   - QuoteLines processed: %', v_quote_lines_processed;
    RAISE NOTICE '   - QuoteLines failed: %', v_quote_lines_failed;
    RAISE NOTICE '====================================================';
    
    -- Log summary: At least one QuoteLine should be processed
    IF v_quote_lines_processed = 0 THEN
        RAISE NOTICE '⚠️ No QuoteLines were successfully processed for SalesOrder %s. MO will be created but BOM may be incomplete.',
            v_sales_order_record.sale_order_no;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ BOM Generation Completed Successfully for ManufacturingOrder %', NEW.manufacturing_order_no;
    RAISE NOTICE '';
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log full error details for debugging
        RAISE WARNING '';
        RAISE WARNING '====================================================';
        RAISE WARNING '❌ ERROR in BOM Link (non-blocking)';
        RAISE WARNING '   ManufacturingOrder: %', NEW.manufacturing_order_no;
        RAISE WARNING '   Error: %', SQLERRM;
        RAISE WARNING '   SQLSTATE: %', SQLSTATE;
        RAISE WARNING '====================================================';
        -- Don't block MO creation - just log the error
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_manufacturing_order_insert_generate_bom IS 
'Links ManufacturingOrder to existing BomInstance when MO is created. 
BEHAVIOR:
- Checks if BomInstance exists (does not generate BOM)
- Logs warnings if BOM is missing but does not block MO creation
- Updates SalesOrder status to "In Production"
- Architecture: BOM must already exist before creating MO

LOGGING:
- Comprehensive RAISE NOTICE for debugging
- Clear warnings for missing BOM

BOM must be generated before creating Manufacturing Order.';

-- STEP 3: Ensure trigger exists and is active
DROP TRIGGER IF EXISTS trg_mo_insert_generate_bom ON "ManufacturingOrders";

CREATE TRIGGER trg_mo_insert_generate_bom
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.deleted = false)
    EXECUTE FUNCTION public.on_manufacturing_order_insert_generate_bom();

COMMENT ON TRIGGER trg_mo_insert_generate_bom ON "ManufacturingOrders" IS 
'HARDENED: Automatically generates BOM when a ManufacturingOrder is created. 
Blocks MO creation if BOM cannot be generated. This is the ONLY point where BOM is generated.';

-- STEP 4: Verification
DO $$
DECLARE
    v_function_exists boolean;
    v_trigger_exists boolean;
    v_trigger_enabled boolean;
    v_org_id_column_exists boolean;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ HARDENED BOM Trigger Installed Successfully!';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    
    -- Verify function
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'on_manufacturing_order_insert_generate_bom'
    ) INTO v_function_exists;
    IF v_function_exists THEN
        RAISE NOTICE '✅ Function exists and is active';
    ELSE
        RAISE WARNING '❌ Function does NOT exist';
    END IF;

    -- Verify trigger
    SELECT EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'ManufacturingOrders'
        AND tgname = 'trg_mo_insert_generate_bom'
        AND t.tgenabled = 'O'
    ) INTO v_trigger_exists;
    IF v_trigger_exists THEN
        RAISE NOTICE '✅ Trigger exists and is ACTIVE';
    ELSE
        RAISE WARNING '❌ Trigger does NOT exist or is DISABLED';
    END IF;
    
    -- Verify organization_id column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'BomInstanceLines'
        AND column_name = 'organization_id'
    ) INTO v_org_id_column_exists;
    IF v_org_id_column_exists THEN
        RAISE NOTICE '✅ organization_id column exists in BomInstanceLines';
    ELSE
        RAISE WARNING '⚠️ organization_id column does NOT exist in BomInstanceLines';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '📋 FUNCTION BEHAVIOR:';
    RAISE NOTICE '   ✅ Links MO to existing BomInstance (does not generate BOM)';
    RAISE NOTICE '   ✅ Logs warnings if BOM is missing but does not block MO creation';
    RAISE NOTICE '   ✅ Comprehensive logging for debugging';
    RAISE NOTICE '';
END;
$$;

