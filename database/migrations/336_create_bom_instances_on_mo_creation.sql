-- ====================================================
-- Migration 336: Create BomInstances and BomInstanceLines when ManufacturingOrder is created
-- ====================================================
-- This migration creates a function and trigger to automatically generate
-- BomInstances and BomInstanceLines when a ManufacturingOrder is created.
-- ====================================================

-- ====================================================
-- STEP 1: Create function to create BomInstances and BomInstanceLines
-- ====================================================

CREATE OR REPLACE FUNCTION public.create_bom_instances_for_manufacturing_order(
    p_manufacturing_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mo RECORD;
    v_so RECORD;
    v_sol RECORD;
    v_ql RECORD;
    v_qlc RECORD;
    v_bom_instance_id uuid;
    v_created_instances integer := 0;
    v_created_lines integer := 0;
    v_lines_for_instance integer := 0;
    v_validated_uom text;
BEGIN
    -- Get Manufacturing Order
    SELECT mo.id, mo.sale_order_id, mo.organization_id, mo.manufacturing_order_no
    INTO v_mo
    FROM "ManufacturingOrders" mo
    WHERE mo.id = p_manufacturing_order_id
    AND mo.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder % not found', p_manufacturing_order_id;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Creating BOM for Manufacturing Order: %', v_mo.manufacturing_order_no;
    
    -- Get Sale Order
    SELECT so.id, so.sale_order_no
    INTO v_so
    FROM "SalesOrders" so
    WHERE so.id = v_mo.sale_order_id
    AND so.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SaleOrder % not found for ManufacturingOrder %', v_mo.sale_order_id, p_manufacturing_order_id;
    END IF;
    
    RAISE NOTICE '   Sale Order: %', v_so.sale_order_no;
    
    -- Process each SalesOrderLine
    FOR v_sol IN
        SELECT sol.id, sol.quote_line_id, sol.line_number, sol.product_type_id
        FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = v_so.id
        AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        -- Check if BomInstance already exists
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sol.id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            -- Get QuoteLine for bom_template_id
            SELECT ql.id, ql.bom_template_id
            INTO v_ql
            FROM "QuoteLines" ql
            WHERE ql.id = v_sol.quote_line_id
            AND ql.deleted = false
            LIMIT 1;
            
            -- Create BomInstance
            BEGIN
                INSERT INTO "BomInstances" (
                    organization_id,
                    sale_order_line_id,
                    quote_line_id,
                    bom_template_id,
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_mo.organization_id,
                    v_sol.id,
                    v_sol.quote_line_id,
                    COALESCE(v_ql.bom_template_id, NULL),
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_bom_instance_id;
                
                RAISE NOTICE '   ✅ Created BomInstance % for SalesOrderLine % (line_number: %)', 
                    v_bom_instance_id, v_sol.id, v_sol.line_number;
                v_created_instances := v_created_instances + 1;
                
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '   ❌ Error creating BomInstance for SalesOrderLine %: %', v_sol.id, SQLERRM;
                    CONTINUE;
            END;
        ELSE
            RAISE NOTICE '   ⏭️  BomInstance % already exists for SalesOrderLine %', v_bom_instance_id, v_sol.id;
        END IF;
        
        -- Create BomInstanceLines from QuoteLineComponents
        v_lines_for_instance := 0; -- Reset counter for this BomInstance
        
        FOR v_qlc IN
                SELECT 
                    qlc.id,
                    qlc.catalog_item_id,
                    qlc.component_role,
                    qlc.qty,
                    qlc.uom,
                    qlc.description,
                    ci.sku,
                    ci.item_name,
                    ci.category_code
                FROM "QuoteLineComponents" qlc
                INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
                WHERE qlc.quote_line_id = v_sol.quote_line_id
                AND qlc.deleted = false
                AND qlc.source = 'configured_component'
                ORDER BY qlc.component_role
            LOOP
                -- Check if BomInstanceLine already exists
                IF EXISTS (
                    SELECT 1
                    FROM "BomInstanceLines" bil
                    WHERE bil.bom_instance_id = v_bom_instance_id
                    AND bil.resolved_part_id = v_qlc.catalog_item_id
                    AND COALESCE(bil.part_role, '') = COALESCE(v_qlc.component_role, '')
                    AND bil.deleted = false
                ) THEN
                    CONTINUE; -- Skip if already exists
                END IF;
                
                -- Normalize UOM (m -> mts)
                v_validated_uom := CASE 
                    WHEN v_qlc.uom = 'm' THEN 'mts'
                    ELSE v_qlc.uom
                END;
                
                -- Create BomInstanceLine
                BEGIN
                    INSERT INTO "BomInstanceLines" (
                        bom_instance_id,
                        resolved_part_id,
                        resolved_sku,
                        part_role,
                        qty,
                        uom,
                        description,
                        category_code,
                        organization_id,
                        deleted,
                        created_at,
                        updated_at
                    ) VALUES (
                        v_bom_instance_id,
                        v_qlc.catalog_item_id,
                        v_qlc.sku,
                        v_qlc.component_role,
                        v_qlc.qty,
                        v_validated_uom,
                        COALESCE(v_qlc.description, v_qlc.item_name),
                        v_qlc.category_code,
                        v_mo.organization_id,
                        false,
                        now(),
                        now()
                    );
                    
                    v_lines_for_instance := v_lines_for_instance + 1;
                    v_created_lines := v_created_lines + 1;
                    
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '   ❌ Error creating BomInstanceLine for component % (role: %): %', 
                            v_qlc.sku, v_qlc.component_role, SQLERRM;
                END;
        END LOOP;
        
        RAISE NOTICE '   📊 Created % BomInstanceLines for BomInstance %', v_lines_for_instance, v_bom_instance_id;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ BOM creation completed:';
    RAISE NOTICE '   - BomInstances created: %', v_created_instances;
    RAISE NOTICE '   - BomInstanceLines created: %', v_created_lines;
    
    RETURN jsonb_build_object(
        'success', true,
        'manufacturing_order_id', p_manufacturing_order_id,
        'bom_instances_created', v_created_instances,
        'bom_instance_lines_created', v_created_lines
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in create_bom_instances_for_manufacturing_order: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

COMMENT ON FUNCTION public.create_bom_instances_for_manufacturing_order IS 
    'Creates BomInstances and BomInstanceLines for a ManufacturingOrder from SalesOrderLines and QuoteLineComponents.';

-- ====================================================
-- STEP 2: Create trigger on ManufacturingOrders
-- ====================================================

CREATE OR REPLACE FUNCTION public.on_manufacturing_order_created_create_bom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only process if ManufacturingOrder is not deleted
    IF NEW.deleted = false THEN
        PERFORM public.create_bom_instances_for_manufacturing_order(NEW.id);
    END IF;
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_manufacturing_order_created_create_bom IS 
    'Trigger function that creates BomInstances and BomInstanceLines when a ManufacturingOrder is created.';

-- Drop trigger if it exists
DROP TRIGGER IF EXISTS trg_manufacturing_order_created_create_bom ON "ManufacturingOrders";

-- Create trigger
CREATE TRIGGER trg_manufacturing_order_created_create_bom
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.deleted = false)
    EXECUTE FUNCTION public.on_manufacturing_order_created_create_bom();

COMMENT ON TRIGGER trg_manufacturing_order_created_create_bom ON "ManufacturingOrders" IS 
    'Automatically creates BomInstances and BomInstanceLines when a ManufacturingOrder is created.';

-- ====================================================
-- STEP 3: Backfill for existing ManufacturingOrders without BOM
-- ====================================================

DO $$
DECLARE
    v_mo RECORD;
    v_result jsonb;
    v_processed integer := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Backfilling BOM for existing ManufacturingOrders...';
    RAISE NOTICE '';
    
    FOR v_mo IN
        SELECT mo.id, mo.manufacturing_order_no
        FROM "ManufacturingOrders" mo
        WHERE mo.deleted = false
        AND NOT EXISTS (
            SELECT 1
            FROM "BomInstances" bi
            INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
            WHERE sol.sale_order_id = mo.sale_order_id
            AND bi.deleted = false
        )
        ORDER BY mo.created_at
    LOOP
        RAISE NOTICE '   Processing: %', v_mo.manufacturing_order_no;
        
        BEGIN
            v_result := public.create_bom_instances_for_manufacturing_order(v_mo.id);
            
            IF (v_result->>'success')::boolean THEN
                v_processed := v_processed + 1;
                RAISE NOTICE '   ✅ Success: %', v_mo.manufacturing_order_no;
            ELSE
                RAISE WARNING '   ❌ Failed: % - %', v_mo.manufacturing_order_no, v_result->>'error';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '   ❌ Error processing %: %', v_mo.manufacturing_order_no, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Backfill completed: % ManufacturingOrder(s) processed', v_processed;
END $$;

