-- ====================================================
-- INTEGRATE: Engineering Rules into BOM Generation
-- ====================================================
-- This script updates generate_bom_for_manufacturing_order to:
-- 1. Keep existing BOM generation logic (non-breaking)
-- 2. Apply dimensional adjustments from EngineeringRules
-- 3. Update MO status to PLANNED when BOM is valid
-- ====================================================

-- First, ensure the helper function exists
-- (This should already exist from CREATE_RESOLVE_DIMENSIONAL_ADJUSTMENTS_FUNCTION.sql)
-- If not, it will be created

-- Now update the main BOM generation function
-- We'll modify the existing function to add adjustment logic AFTER inserting BomInstanceLines

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
    -- New variables for dimensional adjustments
    v_product_type_id uuid;
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
    v_bom_lines_count integer;
BEGIN
    -- ====================================================
    -- STEP 1: Get ManufacturingOrder and SalesOrder
    -- ====================================================
    
    SELECT 
        mo.id,
        mo.sale_order_id,
        mo.organization_id
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
    
    RAISE NOTICE '🔧 Generating BOM for ManufacturingOrder % (SalesOrder: %)', p_manufacturing_order_id, v_sales_order_record.sale_order_no;
    
    -- ====================================================
    -- STEP 2: Process each SalesOrderLine
    -- ====================================================
    
    FOR v_sale_order_line_record IN
        SELECT 
            sol.id as sale_order_line_id,
            sol.quote_line_id,
            sol.organization_id,
            sol.width_m,
            sol.height_m
        FROM "SalesOrderLines" sol
        WHERE sol.sale_order_id = v_sales_order_record.id
        AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        -- Get QuoteLine with product_type_id
        SELECT 
            ql.id,
            ql.organization_id,
            ql.product_type_id,
            ql.width_m,
            ql.height_m
        INTO v_quote_line_record
        FROM "QuoteLines" ql
        WHERE ql.id = v_sale_order_line_record.quote_line_id
        AND ql.deleted = false;
        
        IF NOT FOUND THEN
            RAISE WARNING '⚠️ QuoteLine % not found for SaleOrderLine %', v_sale_order_line_record.quote_line_id, v_sale_order_line_record.sale_order_line_id;
            CONTINUE;
        END IF;
        
        v_product_type_id := v_quote_line_record.product_type_id;
        
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
                ci.item_name,
                ci.measure_basis,
                ci.item_type,
                CASE 
                    WHEN ci.item_type = 'fabric' OR ci.measure_basis = 'fabric_wxh' THEN true
                    ELSE false
                END as is_fabric
            FROM "QuoteLineComponents" qlc
            INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id AND ci.deleted = false
            WHERE qlc.quote_line_id = v_quote_line_record.id
            AND qlc.source = 'configured_component'
            AND qlc.deleted = false
            ORDER BY qlc.id
        LOOP
            BEGIN
                -- Insert BomInstanceLine
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
                    public.derive_category_code_from_role(v_component_record.component_role),
                    v_organization_id,
                    now(),
                    now(),
                    false
                );
                
                -- ====================================================
                -- STEP 6: Apply dimensional adjustments (NEW)
                -- ====================================================
                
                v_target_role := v_component_record.component_role;
                v_measure_basis := v_component_record.measure_basis;
                v_item_type := v_component_record.item_type;
                v_is_fabric := v_component_record.is_fabric;
                
                -- Get base dimensions from QuoteLine/SalesOrderLine
                v_base_width_mm := COALESCE(
                    (v_sale_order_line_record.width_m * 1000)::integer,
                    (v_quote_line_record.width_m * 1000)::integer,
                    0
                );
                v_base_height_mm := COALESCE(
                    (v_sale_order_line_record.height_m * 1000)::integer,
                    (v_quote_line_record.height_m * 1000)::integer,
                    0
                );
                v_base_length_mm := 0;
                
                -- Reset adjustment variables
                v_adjustment_width_mm := 0;
                v_adjustment_height_mm := 0;
                v_adjustment_length_mm := 0;
                v_final_width_mm := 0;
                v_final_height_mm := 0;
                v_final_length_mm := 0;
                v_calc_notes := NULL;
                
                -- Calculate adjustments using EngineeringRules
                IF v_quote_line_record.id IS NOT NULL AND v_product_type_id IS NOT NULL THEN
                    -- For linear parts (tubes, rails, cassettes, side channels)
                    IF v_measure_basis = 'linear_m' OR v_item_type IN ('tube', 'rail', 'cassette', 'side_channel', 'bottom_rail') THEN
                        -- Get LENGTH adjustment
                        v_adjustment_length_mm := public.resolve_dimensional_adjustments(
                            v_organization_id,
                            v_product_type_id,
                            v_quote_line_record.id,
                            v_target_role,
                            'LENGTH'
                        );
                        
                        -- Get WIDTH adjustment (for width-based linear parts)
                        v_adjustment_width_mm := public.resolve_dimensional_adjustments(
                            v_organization_id,
                            v_product_type_id,
                            v_quote_line_record.id,
                            v_target_role,
                            'WIDTH'
                        );
                        
                        v_final_length_mm := v_base_length_mm + v_adjustment_length_mm;
                        v_final_width_mm := v_base_width_mm + v_adjustment_width_mm;
                        
                        IF v_adjustment_length_mm != 0 OR v_adjustment_width_mm != 0 THEN
                            v_calc_notes := format('Base: L=%s mm W=%s mm, Adjustments: LENGTH=%s mm, WIDTH=%s mm', 
                                v_base_length_mm, v_base_width_mm, v_adjustment_length_mm, v_adjustment_width_mm);
                        END IF;
                        
                    -- For fabric (WxH)
                    ELSIF v_is_fabric OR v_measure_basis = 'fabric_wxh' THEN
                        -- Get WIDTH adjustment
                        v_adjustment_width_mm := public.resolve_dimensional_adjustments(
                            v_organization_id,
                            v_product_type_id,
                            v_quote_line_record.id,
                            v_target_role,
                            'WIDTH'
                        );
                        
                        -- Get HEIGHT adjustment
                        v_adjustment_height_mm := public.resolve_dimensional_adjustments(
                            v_organization_id,
                            v_product_type_id,
                            v_quote_line_record.id,
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
                IF v_final_length_mm > 0 OR v_final_width_mm > 0 OR v_final_height_mm > 0 OR v_calc_notes IS NOT NULL THEN
                    UPDATE "BomInstanceLines"
                    SET 
                        cut_length_mm = CASE WHEN v_final_length_mm > 0 THEN v_final_length_mm ELSE NULL END,
                        cut_width_mm = CASE WHEN v_final_width_mm > 0 THEN v_final_width_mm ELSE NULL END,
                        cut_height_mm = CASE WHEN v_final_height_mm > 0 THEN v_final_height_mm ELSE NULL END,
                        calc_notes = v_calc_notes
                    WHERE bom_instance_id = v_bom_instance_id
                    AND resolved_part_id = v_component_record.catalog_item_id
                    AND deleted = false;
                END IF;
                
                v_copied_count := v_copied_count + 1;
                
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '⚠️ Error copying component %: %', v_component_record.id, SQLERRM;
            END;
        END LOOP;
        
        v_total_copied := v_total_copied + v_copied_count;
        RAISE NOTICE '✅ Copied % components for SaleOrderLine %', v_copied_count, v_sale_order_line_record.sale_order_line_id;
    END LOOP;
    
    RAISE NOTICE '✅ Total components copied: %', v_total_copied;
    
    -- ====================================================
    -- STEP 7: Verify BOM and update MO status
    -- ====================================================
    
    SELECT COUNT(*) INTO v_bom_lines_count
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sale_order_id = v_sales_order_record.id
    AND bil.deleted = false
    AND bi.deleted = false
    AND sol.deleted = false;
    
    IF v_bom_lines_count > 0 THEN
        -- Update MO status to PLANNED if currently DRAFT
        UPDATE "ManufacturingOrders"
        SET status = 'planned',
            updated_at = now()
        WHERE id = p_manufacturing_order_id
        AND status = 'draft';
        
        RAISE NOTICE '✅ ManufacturingOrder status updated to PLANNED (BOM has % lines)', v_bom_lines_count;
    ELSE
        RAISE WARNING '⚠️ No BomInstanceLines created. MO status remains DRAFT.';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ BOM generation complete for ManufacturingOrder %', p_manufacturing_order_id;
    RAISE NOTICE '';
    
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






