-- ====================================================
-- Migration 306: Create BomInstances and BomInstanceLines for MO-000002
-- ====================================================

-- Step 1: Check current state
SELECT 
    'Current State' as step,
    (SELECT COUNT(*) FROM "ManufacturingOrders" WHERE manufacturing_order_no = 'MO-000002' AND deleted = false) as mo_count,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol
     JOIN "SalesOrders" so ON so.id = sol.sale_order_id
     JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
     WHERE mo.manufacturing_order_no = 'MO-000002' 
     AND sol.deleted = false) as sol_count,
    (SELECT COUNT(*) FROM "BomInstances" bi
     JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
     JOIN "SalesOrders" so ON so.id = sol.sale_order_id
     JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
     WHERE mo.manufacturing_order_no = 'MO-000002' 
     AND bi.deleted = false) as bom_instances_count,
    (SELECT COUNT(*) FROM "BomInstanceLines" bil
     JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
     JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
     JOIN "SalesOrders" so ON so.id = sol.sale_order_id
     JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
     WHERE mo.manufacturing_order_no = 'MO-000002' 
     AND bil.deleted = false) as bom_lines_count;

-- Step 2: Create BomInstances for each SalesOrderLine
DO $$
DECLARE
    v_mo_id uuid;
    v_sale_order_id uuid;
    v_organization_id uuid;
    v_sol_record RECORD;
    v_bom_instance_id uuid;
    v_created_instances integer := 0;
BEGIN
    RAISE NOTICE '🔧 Creating BomInstances for MO-000002...';
    RAISE NOTICE '';
    
    -- Get Manufacturing Order details
    SELECT mo.id, mo.sale_order_id, mo.organization_id
    INTO v_mo_id, v_sale_order_id, v_organization_id
    FROM "ManufacturingOrders" mo
    WHERE mo.manufacturing_order_no = 'MO-000002'
    AND mo.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder MO-000002 not found';
    END IF;
    
    RAISE NOTICE '✅ Manufacturing Order ID: %', v_mo_id;
    RAISE NOTICE '   Sale Order ID: %', v_sale_order_id;
    RAISE NOTICE '   Organization ID: %', v_organization_id;
    RAISE NOTICE '';
    
    -- Create BomInstance for each SalesOrderLine
    FOR v_sol_record IN
        SELECT sol.id as sale_order_line_id, sol.quote_line_id
        FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = v_sale_order_id
        AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        -- Check if BomInstance already exists
        IF EXISTS (
            SELECT 1 FROM "BomInstances"
            WHERE sale_order_line_id = v_sol_record.sale_order_line_id
            AND deleted = false
        ) THEN
            RAISE NOTICE '  ⏭️  BomInstance already exists for SalesOrderLine %', v_sol_record.sale_order_line_id;
            CONTINUE;
        END IF;
        
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
                v_organization_id,
                v_sol_record.sale_order_line_id,
                v_sol_record.quote_line_id,
                NULL,
                false,
                now(),
                now()
            ) RETURNING id INTO v_bom_instance_id;
            
            RAISE NOTICE '  ✅ Created BomInstance % for SalesOrderLine %', v_bom_instance_id, v_sol_record.sale_order_line_id;
            v_created_instances := v_created_instances + 1;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Error creating BomInstance: %', SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Created % BomInstance(s)', v_created_instances;
    
END $$;

-- Step 3: Create BomInstanceLines from QuoteLineComponents
DO $$
DECLARE
    v_mo_id uuid;
    v_sale_order_id uuid;
    v_organization_id uuid;
    v_bom_instance_record RECORD;
    v_qlc_record RECORD;
    rec RECORD;
    v_bil_id uuid;
    v_created_lines integer := 0;
    v_qlc_count integer := 0;
    v_canonical_uom text;
    v_category_code text;
    v_unit_cost_exw numeric(12,4) := 0;
    v_total_cost_exw numeric(12,4) := 0;
BEGIN
    RAISE NOTICE '🔧 Creating BomInstanceLines from QuoteLineComponents...';
    RAISE NOTICE '';
    
    -- Get Manufacturing Order details
    SELECT mo.id, mo.sale_order_id, mo.organization_id
    INTO v_mo_id, v_sale_order_id, v_organization_id
    FROM "ManufacturingOrders" mo
    WHERE mo.manufacturing_order_no = 'MO-000002'
    AND mo.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder MO-000002 not found';
    END IF;
    
    -- Process each BomInstance
    FOR v_bom_instance_record IN
        SELECT bi.id as bom_instance_id, bi.quote_line_id
        FROM "BomInstances" bi
        JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
        WHERE sol.sale_order_id = v_sale_order_id
        AND bi.deleted = false
        AND sol.deleted = false
    LOOP
        RAISE NOTICE '  Processing BomInstance % (QuoteLine: %)', v_bom_instance_record.bom_instance_id, v_bom_instance_record.quote_line_id;
        
        -- Count QuoteLineComponents first
        SELECT COUNT(*) INTO v_qlc_count
        FROM "QuoteLineComponents" qlc
        WHERE qlc.quote_line_id = v_bom_instance_record.quote_line_id
        AND qlc.deleted = false
        AND qlc.source = 'configured_component';
        
        RAISE NOTICE '    Found % QuoteLineComponents with source=configured_component', v_qlc_count;
        
        IF v_qlc_count = 0 THEN
            RAISE WARNING '    ⚠️  No QuoteLineComponents found with source=configured_component for QuoteLine %', v_bom_instance_record.quote_line_id;
            
            -- Show what sources actually exist
            FOR rec IN
                SELECT DISTINCT qlc.source, COUNT(*) as count
                FROM "QuoteLineComponents" qlc
                WHERE qlc.quote_line_id = v_bom_instance_record.quote_line_id
                AND qlc.deleted = false
                GROUP BY qlc.source
            LOOP
                RAISE NOTICE '      Source found: % (count: %)', rec.source, rec.count;
            END LOOP;
            
            CONTINUE; -- Skip this BomInstance if no components found
        END IF;
        
        -- Create BomInstanceLines from QuoteLineComponents
        FOR v_qlc_record IN
            SELECT 
                qlc.*,
                ci.sku,
                ci.item_name
            FROM "QuoteLineComponents" qlc
            LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE qlc.quote_line_id = v_bom_instance_record.quote_line_id
            AND qlc.deleted = false
            AND qlc.source = 'configured_component'
        LOOP
            -- Check if BomInstanceLine already exists
            IF EXISTS (
                SELECT 1 FROM "BomInstanceLines"
                WHERE bom_instance_id = v_bom_instance_record.bom_instance_id
                AND resolved_part_id = v_qlc_record.catalog_item_id
                AND part_role = v_qlc_record.component_role
                AND deleted = false
            ) THEN
                RAISE NOTICE '    ⏭️  BomInstanceLine already exists for role %', v_qlc_record.component_role;
                CONTINUE;
            END IF;
            
            -- Determine canonical UOM (same logic as trigger)
            -- Map UOM to canonical form
            CASE v_qlc_record.uom
                WHEN 'm' THEN v_canonical_uom := 'mts';
                WHEN 'm2' THEN v_canonical_uom := 'm2';
                WHEN 'ea' THEN v_canonical_uom := 'ea';
                WHEN 'pcs' THEN v_canonical_uom := 'ea';
                ELSE v_canonical_uom := COALESCE(v_qlc_record.uom, 'ea');
            END CASE;
            
            -- Get category code from role (must match constraint check_bom_instance_lines_category_code_valid)
            v_category_code := CASE 
                WHEN v_qlc_record.component_role = 'fabric' THEN 'fabric'
                WHEN v_qlc_record.component_role = 'tube' THEN 'tube'
                WHEN v_qlc_record.component_role = 'motor' THEN 'motor'
                WHEN v_qlc_record.component_role = 'bracket' THEN 'bracket'
                WHEN v_qlc_record.component_role LIKE '%cassette%' THEN 'cassette'
                WHEN v_qlc_record.component_role LIKE '%side_channel%' THEN 'side_channel'
                WHEN v_qlc_record.component_role LIKE '%bottom_rail%' OR v_qlc_record.component_role LIKE '%bottom_channel%' THEN 'bottom_channel'
                ELSE 'accessory'  -- Default for motor_adapter, operating_system_drive, bracket_cover, chain, etc.
            END;
            
            -- Calculate costs
            v_unit_cost_exw := COALESCE(v_qlc_record.unit_cost_exw, 0);
            v_total_cost_exw := v_unit_cost_exw * COALESCE(v_qlc_record.qty, 0);
            
            -- Create BomInstanceLine (using same structure as trigger)
            BEGIN
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
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_organization_id,
                    v_bom_instance_record.bom_instance_id,
                    NULL,
                    v_qlc_record.catalog_item_id,
                    v_qlc_record.sku,
                    v_qlc_record.component_role,
                    v_qlc_record.qty,
                    v_canonical_uom,
                    COALESCE(v_qlc_record.item_name, ''),
                    v_unit_cost_exw,
                    v_total_cost_exw,
                    v_category_code,
                    false,
                    now(),
                    now()
                )
                ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom) 
                WHERE deleted = false
                DO NOTHING
                RETURNING id INTO v_bil_id;
                
                IF v_bil_id IS NOT NULL THEN
                    RAISE NOTICE '    ✅ Created BomInstanceLine % (role: %, qty: %, uom: %)', 
                        v_bil_id, v_qlc_record.component_role, v_qlc_record.qty, v_canonical_uom;
                    v_created_lines := v_created_lines + 1;
                ELSE
                    RAISE NOTICE '    ⏭️  Skipped BomInstanceLine (conflict or already exists): role=%, catalog_item_id=%, uom=%', 
                        v_qlc_record.component_role, v_qlc_record.catalog_item_id, v_canonical_uom;
                END IF;
                
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '    ❌ Error creating BomInstanceLine for role % (catalog_item_id: %, SKU: %): %', 
                        v_qlc_record.component_role, 
                        v_qlc_record.catalog_item_id, 
                        COALESCE(v_qlc_record.sku, 'NULL'),
                        SQLERRM;
                    RAISE WARNING '      Details: qty=%, uom=%, canonical_uom=%', 
                        v_qlc_record.qty, v_qlc_record.uom, v_canonical_uom;
            END;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Created % BomInstanceLine(s)', v_created_lines;
    
END $$;

-- Step 4: Final verification
SELECT 
    'Final Verification' as step,
    (SELECT COUNT(*) FROM "BomInstances" bi
     JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
     JOIN "SalesOrders" so ON so.id = sol.sale_order_id
     JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
     WHERE mo.manufacturing_order_no = 'MO-000002' 
     AND bi.deleted = false) as bom_instances_count,
    (SELECT COUNT(*) FROM "BomInstanceLines" bil
     JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
     JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
     JOIN "SalesOrders" so ON so.id = sol.sale_order_id
     JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
     WHERE mo.manufacturing_order_no = 'MO-000002' 
     AND bil.deleted = false) as bom_lines_count;

