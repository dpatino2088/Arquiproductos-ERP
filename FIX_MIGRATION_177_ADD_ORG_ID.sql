-- ====================================================
-- Script: Fix Migration 177 - Add organization_id to BomInstanceLines INSERT
-- ====================================================
-- This script updates the on_quote_approved_create_operational_docs function
-- to include organization_id when inserting into BomInstanceLines
-- ====================================================

-- Step 1: Check current function definition
SELECT 
    'Step 1: Current Function Check' as check_type,
    proname as function_name,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'on_quote_approved_create_operational_docs'
LIMIT 1;

-- Step 2: Update the function to include organization_id
CREATE OR REPLACE FUNCTION public.on_quote_approved_create_operational_docs()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_record record;
    v_quote_line_record record;
    v_component_record record;
    v_sale_order_id uuid;
    v_sale_order_line_id uuid;
    v_bom_instance_id uuid;
    v_canonical_uom text;
    v_unit_cost_exw numeric;
    v_total_cost_exw numeric;
    v_category_code text;
BEGIN
    -- Only process if status changed to 'approved'
    IF NEW.status != 'approved' OR OLD.status = 'approved' THEN
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '🔧 Quote approved: % - Creating operational documents', NEW.id;
    
    -- Get quote details
    SELECT * INTO v_quote_record
    FROM "Quotes"
    WHERE id = NEW.id AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING 'Quote not found: %', NEW.id;
        RETURN NEW;
    END IF;
    
    -- Step A: Create SaleOrder
    INSERT INTO "SaleOrders" (
        organization_id,
        quote_id,
        sale_order_no,
        customer_id,
        total,
        currency,
        status,
        created_at,
        updated_at,
        deleted
    )
    VALUES (
        v_quote_record.organization_id,
        v_quote_record.id,
        'SO-TEMP-' || EXTRACT(EPOCH FROM NOW())::bigint, -- Temporary number, will be updated by trigger
        v_quote_record.customer_id,
        v_quote_record.total,
        v_quote_record.currency,
        'draft',
        NOW(),
        NOW(),
        false
    )
    RETURNING id INTO v_sale_order_id;
    
    RAISE NOTICE '  ✅ Created SaleOrder: %', v_sale_order_id;
    
    -- Step B: Create SaleOrderLines from QuoteLines
    FOR v_quote_line_record IN
        SELECT * FROM "QuoteLines"
        WHERE quote_id = v_quote_record.id
        AND deleted = false
    LOOP
        INSERT INTO "SaleOrderLines" (
            organization_id,
            sale_order_id,
            quote_line_id,
            catalog_item_id,
            product_type_id,
            qty,
            unit_price,
            total_price,
            width_m,
            height_m,
            drive_type,
            bottom_rail_type,
            cassette,
            cassette_type,
            side_channel,
            side_channel_type,
            hardware_color,
            created_at,
            updated_at,
            deleted
        )
        VALUES (
            v_quote_line_record.organization_id,
            v_sale_order_id,
            v_quote_line_record.id,
            v_quote_line_record.catalog_item_id,
            v_quote_line_record.product_type_id,
            v_quote_line_record.qty,
            v_quote_line_record.unit_price,
            v_quote_line_record.total_price,
            v_quote_line_record.width_m,
            v_quote_line_record.height_m,
            v_quote_line_record.drive_type,
            v_quote_line_record.bottom_rail_type,
            v_quote_line_record.cassette,
            v_quote_line_record.cassette_type,
            v_quote_line_record.side_channel,
            v_quote_line_record.side_channel_type,
            v_quote_line_record.hardware_color,
            NOW(),
            NOW(),
            false
        )
        RETURNING id INTO v_sale_order_line_id;
        
        RAISE NOTICE '  ✅ Created SaleOrderLine: % for QuoteLine: %', v_sale_order_line_id, v_quote_line_record.id;
        
        -- Step C: Create BomInstance
        INSERT INTO "BomInstances" (
            organization_id,
            sale_order_line_id,
            quote_line_id,
            created_at,
            updated_at,
            deleted
        )
        VALUES (
            v_quote_line_record.organization_id,
            v_sale_order_line_id,
            v_quote_line_record.id,
            NOW(),
            NOW(),
            false
        )
        RETURNING id INTO v_bom_instance_id;
        
        RAISE NOTICE '  ✅ Created BomInstance: %', v_bom_instance_id;
        
        -- Step D: Populate BomInstanceLines from QuoteLineComponents (frozen snapshot)
        FOR v_component_record IN
            SELECT 
                qlc.*,
                ci.item_name
            FROM "QuoteLineComponents" qlc
            INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE qlc.quote_line_id = v_quote_line_record.id
            AND qlc.source = 'configured_component'
            AND qlc.deleted = false
            AND ci.deleted = false
        LOOP
            -- Compute canonical UOM
            v_canonical_uom := public.normalize_uom_to_canonical(v_component_record.uom);
            
            -- Compute unit_cost_exw using get_unit_cost_in_uom
            v_unit_cost_exw := public.get_unit_cost_in_uom(
                v_component_record.catalog_item_id,
                v_canonical_uom,
                v_quote_record.organization_id
            );
            
            -- Compute total_cost_exw
            v_total_cost_exw := v_component_record.qty * COALESCE(v_unit_cost_exw, 0);
            
            -- Derive category_code from component_role
            v_category_code := public.derive_category_code_from_role(v_component_record.component_role);
            
            -- Insert BomInstanceLine with organization_id
            INSERT INTO "BomInstanceLines" (
                organization_id,
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
                created_at,
                updated_at,
                deleted
            ) VALUES (
                v_quote_record.organization_id, -- CRITICAL: Include organization_id for multi-org support
                v_bom_instance_id,
                NULL, -- source_template_line_id (optional)
                v_component_record.catalog_item_id,
                NULL, -- resolved_sku (can be populated later if needed)
                v_component_record.component_role,
                v_component_record.qty,
                v_canonical_uom,
                v_component_record.item_name,
                v_unit_cost_exw,
                v_total_cost_exw,
                v_category_code,
                now(),
                now(),
                false
            );
        END LOOP;
        
        RAISE NOTICE '  ✅ Populated BomInstanceLines for BomInstance: %', v_bom_instance_id;
    END LOOP;
    
    RAISE NOTICE '✨ Operational documents created for Quote: %', NEW.id;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error creating operational documents: %', SQLERRM;
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_quote_approved_create_operational_docs() IS 
    'Trigger function that creates SaleOrder, SaleOrderLines, BomInstances, and BomInstanceLines when a Quote is approved. INCLUDES organization_id in BomInstanceLines for multi-organization support.';

-- Step 3: Verify function was updated
SELECT 
    'Step 3: Function Updated' as check_type,
    CASE 
        WHEN pg_get_functiondef(oid) LIKE '%organization_id%' THEN '✅ Function includes organization_id'
        ELSE '❌ Function does NOT include organization_id'
    END as status
FROM pg_proc
WHERE proname = 'on_quote_approved_create_operational_docs';








