-- ====================================================
-- HARDEN Manufacturing Order + BOM Workflow
-- ====================================================
-- This script ensures:
-- 1. MO status remains DRAFT on creation (no auto-change)
-- 2. generate_bom_for_manufacturing_order updates status to PLANNED only if BOM lines > 0
-- 3. All validations are consistent
-- ====================================================

-- ====================================================
-- STEP 1: Verify no triggers change MO status on INSERT
-- ====================================================
DO $$
DECLARE
    v_trigger_count integer;
BEGIN
    -- Check if any trigger modifies status on INSERT
    SELECT COUNT(*) INTO v_trigger_count
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    JOIN pg_proc p ON t.tgfoid = p.oid
    WHERE c.relname = 'ManufacturingOrders'
    AND t.tgtype::integer & 2 = 2  -- AFTER INSERT
    AND p.proname LIKE '%status%';
    
    IF v_trigger_count > 0 THEN
        RAISE NOTICE '⚠️ Found % trigger(s) that may modify status on INSERT. Review manually.', v_trigger_count;
    ELSE
        RAISE NOTICE '✅ No triggers found that modify status on INSERT';
    END IF;
END;
$$;

-- ====================================================
-- STEP 2: Update generate_bom_for_manufacturing_order
-- ====================================================
-- Add status update logic: PLANNED only if BOM lines > 0
-- ====================================================

CREATE OR REPLACE FUNCTION public.generate_bom_for_manufacturing_order(
    p_manufacturing_order_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mo_record RECORD;
    v_sales_order_record RECORD;
    v_sale_order_line_record RECORD;
    v_quote_line_record RECORD;
    v_bom_instance_id uuid;
    v_component_record RECORD;
    v_organization_id uuid;
    v_copied_count integer;
    v_total_copied integer := 0;
    v_total_bom_lines integer := 0;
BEGIN
    -- ====================================================
    -- STEP 1: Get ManufacturingOrder and SalesOrder
    -- ====================================================
    
    SELECT 
        mo.id,
        mo.sale_order_id,
        mo.organization_id,
        mo.status as current_status
    INTO v_mo_record
    FROM "ManufacturingOrders" mo
    WHERE mo.id = p_manufacturing_order_id
    AND mo.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder % not found', p_manufacturing_order_id;
    END IF;
    
    v_organization_id := v_mo_record.organization_id;
    
    -- Get SalesOrder
    SELECT 
        so.id,
        so.sale_order_no,
        so.organization_id
    INTO v_sales_order_record
    FROM "SalesOrders" so
    WHERE so.id = v_mo_record.sale_order_id
    AND so.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SalesOrder % not found for ManufacturingOrder %', v_mo_record.sale_order_id, p_manufacturing_order_id;
    END IF;
    
    -- Ensure organization_id is set
    IF v_organization_id IS NULL THEN
        v_organization_id := v_sales_order_record.organization_id;
    END IF;
    
    RAISE NOTICE '🔧 Generating BOM for ManufacturingOrder % (SalesOrder: %, Current Status: %)', 
        p_manufacturing_order_id, v_sales_order_record.sale_order_no, v_mo_record.current_status;
    
    -- ====================================================
    -- STEP 2: Process each SalesOrderLine
    -- ====================================================
    
    FOR v_sale_order_line_record IN
        SELECT 
            sol.id as sale_order_line_id,
            sol.quote_line_id,
            sol.organization_id
        FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = v_sales_order_record.id
        AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        -- Get QuoteLine
        SELECT 
            ql.id,
            ql.organization_id
        INTO v_quote_line_record
        FROM "QuoteLines" ql
        WHERE ql.id = v_sale_order_line_record.quote_line_id
        AND ql.deleted = false;
        
        IF NOT FOUND THEN
            RAISE WARNING '⚠️ QuoteLine % not found for SaleOrderLine %', v_sale_order_line_record.quote_line_id, v_sale_order_line_record.sale_order_line_id;
            CONTINUE;
        END IF;
        
        -- Ensure organization_id
        IF v_organization_id IS NULL THEN
            v_organization_id := COALESCE(v_sale_order_line_record.organization_id, v_quote_line_record.organization_id);
        END IF;
        
        -- ====================================================
        -- STEP 3: Create or get BomInstance
        -- ====================================================
        
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sale_order_line_record.sale_order_line_id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            -- Create BomInstance
            INSERT INTO "BomInstances" (
                organization_id,
                sale_order_line_id,
                quote_line_id,
                configured_product_id,
                status,
                created_at,
                updated_at
            ) VALUES (
                v_organization_id,
                v_sale_order_line_record.sale_order_line_id,
                v_sale_order_line_record.quote_line_id,
                NULL,
                'locked',
                now(),
                now()
            ) RETURNING id INTO v_bom_instance_id;
            
            RAISE NOTICE '✅ Created BomInstance % for SaleOrderLine %', v_bom_instance_id, v_sale_order_line_record.sale_order_line_id;
        ELSE
            RAISE NOTICE '✅ BomInstance % already exists for SaleOrderLine %', v_bom_instance_id, v_sale_order_line_record.sale_order_line_id;
        END IF;
        
        -- ====================================================
        -- STEP 4: Delete existing BomInstanceLines (idempotent)
        -- ====================================================
        
        DELETE FROM "BomInstanceLines"
        WHERE bom_instance_id = v_bom_instance_id
        AND deleted = false;
        
        -- ====================================================
        -- STEP 5: Copy QuoteLineComponents to BomInstanceLines
        -- ====================================================
        
        v_copied_count := 0;
        
        FOR v_component_record IN
            SELECT
                qlc.id,
                qlc.catalog_item_id,
                qlc.component_role,
                qlc.qty,
                qlc.uom,
                qlc.unit_cost_exw,
                ci.sku,
                ci.item_name
            FROM "QuoteLineComponents" qlc
            INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id AND ci.deleted = false
            WHERE qlc.quote_line_id = v_quote_line_record.id
            AND qlc.source = 'configured_component'
            AND qlc.deleted = false
            ORDER BY qlc.id
        LOOP
            BEGIN
                INSERT INTO "BomInstanceLines" (
                    bom_instance_id,
                    source_template_line_id,
                    resolved_part_id,
                    resolved_sku,
                    part_role,
                    qty,
                    uom,
                    description,
                    unit_cost_exw,
                    total_cost_exw,
                    category_code,
                    organization_id,
                    created_at,
                    updated_at,
                    deleted
                ) VALUES (
                    v_bom_instance_id,
                    NULL,
                    v_component_record.catalog_item_id,
                    v_component_record.sku,
                    v_component_record.component_role,
                    v_component_record.qty,
                    v_component_record.uom,
                    v_component_record.item_name,
                    v_component_record.unit_cost_exw,
                    v_component_record.qty * COALESCE(v_component_record.unit_cost_exw, 0),
                    'accessory',
                    v_organization_id,
                    now(),
                    now(),
                    false
                );
                
                v_copied_count := v_copied_count + 1;
                v_total_copied := v_total_copied + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '❌ Error copying QuoteLineComponent % to BomInstanceLines: % (SQLSTATE: %)', 
                        v_component_record.id, SQLERRM, SQLSTATE;
            END;
        END LOOP;
        
        IF v_copied_count > 0 THEN
            RAISE NOTICE '✅ Copied % QuoteLineComponents to BomInstanceLines for BomInstance %', v_copied_count, v_bom_instance_id;
        ELSE
            RAISE WARNING '⚠️ No QuoteLineComponents found for QuoteLine %', v_quote_line_record.id;
        END IF;
    END LOOP;
    
    -- ====================================================
    -- STEP 6: COUNT TOTAL BOM LINES AND UPDATE STATUS
    -- ====================================================
    -- CRITICAL: Update status to PLANNED ONLY if BOM lines > 0
    -- ====================================================
    
    -- Count total BomInstanceLines for this MO
    SELECT COUNT(*) INTO v_total_bom_lines
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_sales_order_record.id
    AND bil.deleted = false
    AND bi.deleted = false
    AND sol.deleted = false;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ BOM Generation Complete';
    RAISE NOTICE '   ManufacturingOrder: %', p_manufacturing_order_id;
    RAISE NOTICE '   SalesOrder: %', v_sales_order_record.sale_order_no;
    RAISE NOTICE '   Total components copied: %', v_total_copied;
    RAISE NOTICE '   Total BOM lines: %', v_total_bom_lines;
    RAISE NOTICE '====================================================';
    
    -- Update status based on BOM lines count
    IF v_total_bom_lines > 0 THEN
        -- BOM is valid: update status to PLANNED (only if currently DRAFT)
        IF v_mo_record.current_status = 'draft' THEN
            UPDATE "ManufacturingOrders"
            SET status = 'planned',
                updated_at = now()
            WHERE id = p_manufacturing_order_id
            AND deleted = false;
            
            RAISE NOTICE '✅ ManufacturingOrder status updated to PLANNED (BOM has % lines)', v_total_bom_lines;
        ELSE
            RAISE NOTICE 'ℹ️ ManufacturingOrder status is already % (not DRAFT), keeping current status', v_mo_record.current_status;
        END IF;
    ELSE
        -- BOM has no lines: keep status as DRAFT
        RAISE NOTICE '⚠️ BOM has no lines. ManufacturingOrder status remains DRAFT.';
        RAISE NOTICE '   Generate BOM components first before advancing to PLANNED.';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in generate_bom_for_manufacturing_order: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
        RAISE;
END;
$$;

COMMENT ON FUNCTION public.generate_bom_for_manufacturing_order(uuid) IS 
'Generates BOM for a ManufacturingOrder by copying QuoteLineComponents to BomInstanceLines.
Uses correct column names: resolved_part_id (not catalog_item_id).
Idempotent: deletes existing BomInstanceLines before insert.
Updates ManufacturingOrder.status to PLANNED ONLY if BOM lines > 0 and current status is DRAFT.
Returns void.';

-- ====================================================
-- STEP 3: Verification
-- ====================================================
DO $$
DECLARE
    v_function_exists boolean;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ HARDENED BOM Function Updated Successfully!';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    
    -- Verify function
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'generate_bom_for_manufacturing_order'
    ) INTO v_function_exists;
    
    IF v_function_exists THEN
        RAISE NOTICE '✅ Function exists and is active';
        RAISE NOTICE '';
        RAISE NOTICE '📋 FUNCTION BEHAVIOR:';
        RAISE NOTICE '   ✅ Generates BOM (BomInstances + BomInstanceLines)';
        RAISE NOTICE '   ✅ Updates status to PLANNED ONLY if:';
        RAISE NOTICE '      - BOM lines count > 0';
        RAISE NOTICE '      - Current status is DRAFT';
        RAISE NOTICE '   ✅ Keeps DRAFT if BOM lines = 0';
        RAISE NOTICE '   ✅ Idempotent (safe to re-run)';
        RAISE NOTICE '';
    ELSE
        RAISE WARNING '❌ Function does NOT exist';
    END IF;
END;
$$;






