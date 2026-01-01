-- ====================================================
-- QUERY 3: Replicate bom_readiness_report Logic
-- ====================================================
-- This query replicates EXACTLY the logic used by bom_readiness_report
-- IMPORTANT: Replace 'YOUR_ORGANIZATION_ID_HERE' with your actual organization_id
-- ====================================================

-- First, get your organization_id:
-- SELECT id, name FROM "Organizations" WHERE deleted = false ORDER BY name;

-- Then replace 'YOUR_ORGANIZATION_ID_HERE' below with the actual UUID

DO $$
DECLARE
    p_organization_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid;
    v_product_type RECORD;
    v_component RECORD;
    v_fixed_component_count integer;
    v_fixed_valid_count integer;
    v_auto_select_count integer;
    v_auto_select_resolvable_count integer;
    v_incomplete_auto_select_count integer;
    v_category_codes text[];
    v_catalog_item_count integer;
BEGIN
    RAISE NOTICE 'Checking BOM Readiness for organization: %', p_organization_id;
    RAISE NOTICE '';
    
    FOR v_product_type IN
        SELECT pt.id, pt.name, pt.code
        FROM "ProductTypes" pt
        WHERE pt.organization_id = p_organization_id
        AND pt.deleted = false
        ORDER BY pt.name
    LOOP
        RAISE NOTICE '========================================';
        RAISE NOTICE 'ProductType: % (ID: %)', v_product_type.name, v_product_type.id;
        RAISE NOTICE '========================================';
        
        -- Count fixed components (EXACT logic from bom_readiness_report)
        SELECT 
            COUNT(*) as fixed_count,
            COUNT(*) FILTER (
                WHERE bc.component_item_id IS NOT NULL
                AND EXISTS (
                    SELECT 1 
                    FROM "CatalogItems" ci 
                    WHERE ci.id = bc.component_item_id 
                    AND ci.deleted = false 
                    AND ci.active = true
                    AND ci.uom IS NOT NULL 
                    AND TRIM(ci.uom) <> ''
                    AND ci.item_category_id IS NOT NULL
                )
            ) as valid_fixed_count
        INTO v_fixed_component_count, v_fixed_valid_count
        FROM "BOMComponents" bc
        INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
        WHERE bt.product_type_id = v_product_type.id
        AND bt.organization_id = p_organization_id
        AND bt.deleted = false
        AND bt.active = true
        AND bc.deleted = false;
        
        RAISE NOTICE 'Fixed Components:';
        RAISE NOTICE '  Total: %', v_fixed_component_count;
        RAISE NOTICE '  Valid: %', v_fixed_valid_count;
        RAISE NOTICE '  Invalid: %', v_fixed_component_count - v_fixed_valid_count;
        
        IF v_fixed_component_count > v_fixed_valid_count THEN
            RAISE NOTICE '  ⚠️  ISSUE: % invalid fixed component(s)', v_fixed_component_count - v_fixed_valid_count;
        END IF;
        
        -- Count incomplete auto-select
        SELECT COUNT(*) INTO v_incomplete_auto_select_count
        FROM "BOMComponents" bc
        INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
        WHERE bt.product_type_id = v_product_type.id
        AND bt.organization_id = p_organization_id
        AND bt.deleted = false
        AND bt.active = true
        AND bc.deleted = false
        AND (bc.auto_select = true OR bc.component_item_id IS NULL)
        AND bc.component_role IS NOT NULL
        AND (bc.sku_resolution_rule IS NULL OR bc.qty_type IS NULL);
        
        -- Count auto-select components
        SELECT COUNT(*) INTO v_auto_select_count
        FROM "BOMComponents" bc
        INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
        WHERE bt.product_type_id = v_product_type.id
        AND bt.organization_id = p_organization_id
        AND bt.deleted = false
        AND bt.active = true
        AND bc.deleted = false
        AND (bc.auto_select = true OR bc.component_item_id IS NULL);
        
        RAISE NOTICE '';
        RAISE NOTICE 'Auto-Select Components:';
        RAISE NOTICE '  Total: %', v_auto_select_count;
        RAISE NOTICE '  Incomplete (missing fields): %', v_incomplete_auto_select_count;
        
        -- Count resolvable auto-select (EXACT logic from bom_readiness_report)
        v_auto_select_resolvable_count := 0;
        FOR v_component IN
            SELECT DISTINCT bc.component_role, bc.component_sub_role
            FROM "BOMComponents" bc
            INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
            WHERE bt.product_type_id = v_product_type.id
            AND bt.organization_id = p_organization_id
            AND bt.deleted = false
            AND bt.active = true
            AND bc.deleted = false
            AND (bc.auto_select = true OR bc.component_item_id IS NULL)
            AND bc.component_role IS NOT NULL
            AND bc.sku_resolution_rule IS NOT NULL
            AND bc.qty_type IS NOT NULL
        LOOP
            BEGIN
                v_category_codes := public.get_item_category_codes_from_role(v_component.component_role, v_component.component_sub_role);
                
                SELECT COUNT(*) INTO v_catalog_item_count
                FROM "CatalogItems" ci
                INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                WHERE ic.code = ANY(v_category_codes)
                AND ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND ci.active = true
                AND ci.uom IS NOT NULL
                AND TRIM(ci.uom) <> '';
                
                IF v_catalog_item_count > 0 THEN
                    v_auto_select_resolvable_count := v_auto_select_resolvable_count + 1;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;
        END LOOP;
        
        RAISE NOTICE '  Resolvable: %', v_auto_select_resolvable_count;
        RAISE NOTICE '  Unresolvable: %', v_auto_select_count - v_incomplete_auto_select_count - v_auto_select_resolvable_count;
        
        IF v_auto_select_count > 0 AND v_auto_select_resolvable_count < (v_auto_select_count - v_incomplete_auto_select_count) THEN
            RAISE NOTICE '  ⚠️  ISSUE: % unresolvable auto-select component(s)', 
                v_auto_select_count - v_incomplete_auto_select_count - v_auto_select_resolvable_count;
        END IF;
        
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Analysis complete!';
    RAISE NOTICE '========================================';
END $$;

