-- ====================================================
-- STEP 4: Update BOM generation to apply dimensional adjustments
-- ====================================================
-- This script:
-- 1. Adds dimension columns to BomInstanceLines if missing
-- 2. Updates generate_bom_for_manufacturing_order to apply adjustments
-- ====================================================

-- ====================================================
-- STEP 4.1: Add dimension columns to BomInstanceLines if missing
-- ====================================================

DO $$
BEGIN
    -- cut_length_mm
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'cut_length_mm'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN cut_length_mm integer;
        RAISE NOTICE '✅ Added cut_length_mm column to BomInstanceLines';
    END IF;
    
    -- cut_width_mm
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'cut_width_mm'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN cut_width_mm integer;
        RAISE NOTICE '✅ Added cut_width_mm column to BomInstanceLines';
    END IF;
    
    -- cut_height_mm
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'cut_height_mm'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN cut_height_mm integer;
        RAISE NOTICE '✅ Added cut_height_mm column to BomInstanceLines';
    END IF;
    
    -- calc_notes
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'calc_notes'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN calc_notes text;
        RAISE NOTICE '✅ Added calc_notes column to BomInstanceLines';
    END IF;
END;
$$;

-- ====================================================
-- STEP 4.2: Update generate_bom_for_manufacturing_order function
-- ====================================================

CREATE OR REPLACE FUNCTION public.generate_bom_for_manufacturing_order(p_manufacturing_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mo_record RECORD;
    v_sale_order_id uuid;
    v_organization_id uuid;
    v_sale_order_line RECORD;
    v_bom_instance_id uuid;
    v_quote_line_id uuid;
    v_product_type_id uuid;
    v_component RECORD;
    v_base_width_mm integer;
    v_base_height_mm integer;
    v_base_length_mm integer;
    v_adjustment_width_mm integer;
    v_adjustment_height_mm integer;
    v_adjustment_length_mm integer;
    v_final_width_mm integer;
    v_final_height_mm integer;
    v_final_length_mm integer;
    v_target_role text;
    v_measure_basis text;
    v_item_type text;
    v_is_fabric boolean;
    v_calc_notes text;
BEGIN
    -- Get ManufacturingOrder details
    SELECT 
        mo.id,
        mo.sale_order_id,
        mo.organization_id,
        mo.status
    INTO v_mo_record
    FROM "ManufacturingOrders" mo
    WHERE mo.id = p_manufacturing_order_id
    AND mo.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder % not found', p_manufacturing_order_id;
    END IF;
    
    v_sale_order_id := v_mo_record.sale_order_id;
    v_organization_id := v_mo_record.organization_id;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '🔧 Generating BOM for ManufacturingOrder %', p_manufacturing_order_id;
    RAISE NOTICE '   Sale Order ID: %', v_sale_order_id;
    RAISE NOTICE '   Organization ID: %', v_organization_id;
    RAISE NOTICE '====================================================';
    
    -- Process each SalesOrderLine
    FOR v_sale_order_line IN
        SELECT 
            sol.id as sale_order_line_id,
            sol.quote_line_id,
            sol.width_m,
            sol.height_m,
            ql.product_type_id,
            ql.width_m as ql_width_m,
            ql.height_m as ql_height_m
        FROM "SalesOrderLines" sol
        LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
        WHERE sol.sale_order_id = v_sale_order_id
        AND sol.deleted = false
    LOOP
        v_quote_line_id := v_sale_order_line.quote_line_id;
        v_product_type_id := v_sale_order_line.product_type_id;
        
        -- Get or create BomInstance for this SalesOrderLine
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sale_order_line.sale_order_line_id
        AND deleted = false
        LIMIT 1;
        
        IF v_bom_instance_id IS NULL THEN
            -- Create BomInstance
            INSERT INTO "BomInstances" (
                organization_id,
                sale_order_line_id,
                quote_line_id,
                deleted
            ) VALUES (
                v_organization_id,
                v_sale_order_line.sale_order_line_id,
                v_quote_line_id,
                false
            ) RETURNING id INTO v_bom_instance_id;
            
            RAISE NOTICE '✅ Created BomInstance % for SaleOrderLine %', v_bom_instance_id, v_sale_order_line.sale_order_line_id;
        ELSE
            RAISE NOTICE '⏭️  Using existing BomInstance % for SaleOrderLine %', v_bom_instance_id, v_sale_order_line.sale_order_line_id;
        END IF;
        
        -- Delete existing BomInstanceLines for this BomInstance (idempotency)
        DELETE FROM "BomInstanceLines"
        WHERE bom_instance_id = v_bom_instance_id;
        
        RAISE NOTICE '🗑️  Cleared existing BomInstanceLines for BomInstance %', v_bom_instance_id;
        
        -- Copy QuoteLineComponents to BomInstanceLines
        FOR v_component IN
            SELECT 
                qlc.id,
                qlc.catalog_item_id,
                qlc.qty,
                qlc.uom,
                qlc.unit_cost_exw,
                qlc.total_cost_exw,
                qlc.part_role,
                ci.measure_basis,
                ci.item_type,
                CASE 
                    WHEN ci.item_type = 'fabric' OR ci.measure_basis = 'fabric_wxh' THEN true
                    ELSE false
                END as is_fabric
            FROM "QuoteLineComponents" qlc
            INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE qlc.quote_line_id = v_quote_line_id
            AND qlc.deleted = false
        LOOP
            -- Insert BomInstanceLine
            INSERT INTO "BomInstanceLines" (
                organization_id,
                bom_instance_id,
                resolved_part_id,
                resolved_sku,
                part_role,
                qty,
                uom,
                unit_cost_exw,
                total_cost_exw,
                deleted
            ) VALUES (
                v_organization_id,
                v_bom_instance_id,
                v_component.catalog_item_id,
                (SELECT sku FROM "CatalogItems" WHERE id = v_component.catalog_item_id),
                v_component.part_role,
                v_component.qty,
                v_component.uom,
                v_component.unit_cost_exw,
                v_component.total_cost_exw,
                false
            );
            
            -- Apply dimensional adjustments for linear parts and fabric
            v_target_role := v_component.part_role;
            v_measure_basis := v_component.measure_basis;
            v_item_type := v_component.item_type;
            v_is_fabric := v_component.is_fabric;
            
            -- Get base dimensions from QuoteLine (use SalesOrderLine as fallback)
            v_base_width_mm := COALESCE(
                (v_sale_order_line.width_m * 1000)::integer,
                (v_sale_order_line.ql_width_m * 1000)::integer,
                0
            );
            v_base_height_mm := COALESCE(
                (v_sale_order_line.height_m * 1000)::integer,
                (v_sale_order_line.ql_height_m * 1000)::integer,
                0
            );
            v_base_length_mm := 0; -- Will be calculated if needed
            
            -- Calculate adjustments using EngineeringRules
            IF v_quote_line_id IS NOT NULL AND v_product_type_id IS NOT NULL THEN
                -- For linear parts (tubes, rails, cassettes, side channels)
                IF v_measure_basis = 'linear_m' OR v_item_type IN ('tube', 'rail', 'cassette', 'side_channel', 'bottom_rail') THEN
                    -- Get LENGTH adjustment
                    v_adjustment_length_mm := public.resolve_dimensional_adjustments(
                        v_organization_id,
                        v_product_type_id,
                        v_quote_line_id,
                        v_target_role,
                        'LENGTH'
                    );
                    
                    -- Get WIDTH adjustment (for width-based linear parts)
                    v_adjustment_width_mm := public.resolve_dimensional_adjustments(
                        v_organization_id,
                        v_product_type_id,
                        v_quote_line_id,
                        v_target_role,
                        'WIDTH'
                    );
                    
                    v_final_length_mm := v_base_length_mm + v_adjustment_length_mm;
                    v_final_width_mm := v_base_width_mm + v_adjustment_width_mm;
                    
                    IF v_adjustment_length_mm != 0 OR v_adjustment_width_mm != 0 THEN
                        v_calc_notes := format('Base: %s mm, Adjustments: LENGTH=%s mm, WIDTH=%s mm', 
                            v_base_length_mm, v_adjustment_length_mm, v_adjustment_width_mm);
                    END IF;
                    
                -- For fabric (WxH)
                ELSIF v_is_fabric OR v_measure_basis = 'fabric_wxh' THEN
                    -- Get WIDTH adjustment
                    v_adjustment_width_mm := public.resolve_dimensional_adjustments(
                        v_organization_id,
                        v_product_type_id,
                        v_quote_line_id,
                        v_target_role,
                        'WIDTH'
                    );
                    
                    -- Get HEIGHT adjustment
                    v_adjustment_height_mm := public.resolve_dimensional_adjustments(
                        v_organization_id,
                        v_product_type_id,
                        v_quote_line_id,
                        v_target_role,
                        'HEIGHT'
                    );
                    
                    v_final_width_mm := v_base_width_mm + v_adjustment_width_mm;
                    v_final_height_mm := v_base_height_mm + v_adjustment_height_mm;
                    
                    IF v_adjustment_width_mm != 0 OR v_adjustment_height_mm != 0 THEN
                        v_calc_notes := format('Base: W=%s mm H=%s mm, Adjustments: WIDTH=%s mm, HEIGHT=%s mm', 
                            v_base_width_mm, v_base_height_mm, v_adjustment_width_mm, v_adjustment_height_mm);
                    END IF;
                END IF;
            END IF;
            
            -- Update BomInstanceLine with calculated dimensions
            UPDATE "BomInstanceLines"
            SET 
                cut_length_mm = CASE 
                    WHEN v_final_length_mm > 0 THEN v_final_length_mm 
                    ELSE NULL 
                END,
                cut_width_mm = CASE 
                    WHEN v_final_width_mm > 0 THEN v_final_width_mm 
                    ELSE NULL 
                END,
                cut_height_mm = CASE 
                    WHEN v_final_height_mm > 0 THEN v_final_height_mm 
                    ELSE NULL 
                END,
                calc_notes = v_calc_notes
            WHERE bom_instance_id = v_bom_instance_id
            AND resolved_part_id = v_component.catalog_item_id
            AND deleted = false;
            
            -- Reset variables for next iteration
            v_final_length_mm := 0;
            v_final_width_mm := 0;
            v_final_height_mm := 0;
            v_calc_notes := NULL;
        END LOOP;
        
        RAISE NOTICE '✅ Processed BomInstance % with adjustments', v_bom_instance_id;
    END LOOP;
    
    -- Verify BOM was created successfully
    DECLARE
        v_bom_instances_count integer;
        v_bom_lines_count integer;
    BEGIN
        SELECT COUNT(DISTINCT bi.id) INTO v_bom_instances_count
        FROM "BomInstances" bi
        INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
        WHERE sol.sale_order_id = v_sale_order_id
        AND bi.deleted = false
        AND sol.deleted = false;
        
        SELECT COUNT(*) INTO v_bom_lines_count
        FROM "BomInstanceLines" bil
        INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
        INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
        WHERE sol.sale_order_id = v_sale_order_id
        AND bil.deleted = false
        AND bi.deleted = false
        AND sol.deleted = false;
        
        RAISE NOTICE '';
        RAISE NOTICE '✅ BOM Generation Complete';
        RAISE NOTICE '   BomInstances: %', v_bom_instances_count;
        RAISE NOTICE '   BomInstanceLines: %', v_bom_lines_count;
        RAISE NOTICE '';
        
        -- Update MO status to PLANNED if BOM is valid
        IF v_bom_lines_count > 0 THEN
            UPDATE "ManufacturingOrders"
            SET status = 'planned',
                updated_at = now()
            WHERE id = p_manufacturing_order_id
            AND status = 'draft';
            
            RAISE NOTICE '✅ ManufacturingOrder status updated to PLANNED';
        ELSE
            RAISE WARNING '⚠️ No BomInstanceLines created. MO status remains DRAFT.';
        END IF;
    END;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in generate_bom_for_manufacturing_order: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
        RAISE;
END;
$$;

COMMENT ON FUNCTION public.generate_bom_for_manufacturing_order IS 
'Generates BOM for a ManufacturingOrder by copying QuoteLineComponents to BomInstanceLines.
Applies dimensional adjustments from EngineeringRules for linear parts and fabric.
Updates MO status to PLANNED if BOM is valid (has lines).';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.generate_bom_for_manufacturing_order(uuid) TO authenticated;






