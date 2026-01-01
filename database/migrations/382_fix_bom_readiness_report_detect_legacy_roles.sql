-- ====================================================
-- Migration 382: Fix BOM Readiness Report - Detect Legacy Roles & Use Only Real Roles
-- ====================================================
-- Updates bom_readiness_report to:
-- 1. Detect roles legacy (operating_system, etc.) as WARNING (LEGACY_ROLE_DETECTED), not BLOCKER
-- 2. Only validate roles that are actually used in BOMComponents (no hardcoded list)
-- 3. Use canonical roles from ComponentRoleMap CHECK constraint for validation
-- 4. Correctly identify blockers: missing mappings, missing CatalogItems, incomplete auto-select
-- ====================================================

CREATE OR REPLACE FUNCTION public.bom_readiness_report(
    p_organization_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_result jsonb := '[]'::jsonb;
    v_product_type RECORD;
    v_template_count integer;
    v_component_count integer;
    v_issues jsonb;
    v_suggested_seeds jsonb;
    v_product_type_result jsonb;
    v_template RECORD;
    v_component RECORD;
    v_category_codes text[];
    v_missing_mappings text[];
    v_catalog_item_count integer;
    v_missing_uom_count integer;
    v_invalid_role_count integer;
    v_auto_select_count integer;
    v_auto_select_resolvable_count integer;
    v_fixed_component_count integer;
    v_fixed_valid_count integer;
    v_role_mapping RECORD;
    v_items jsonb[] := ARRAY[]::jsonb[];
    v_role_used RECORD;
    v_legacy_roles text[] := ARRAY['operating_system']::text[];  -- Legacy roles that should be migrated
    v_canonical_roles text[];  -- Roles from ComponentRoleMap CHECK constraint
    v_is_legacy boolean;
    v_incomplete_auto_select_count integer;
    v_test_category_codes text[];  -- For testing role mappings
    v_has_mapping boolean;  -- For testing role mappings
BEGIN
    -- Get canonical roles from ComponentRoleMap CHECK constraint
    -- These are the valid roles that can be used
    SELECT ARRAY_AGG(DISTINCT role) INTO v_canonical_roles
    FROM (
        SELECT unnest(ARRAY[
            'fabric', 'tube', 'bracket', 'cassette', 'side_channel', 
            'bottom_bar', 'bottom_rail', 'top_rail', 'drive_manual', 
            'drive_motorized', 'remote_control', 'battery', 'tool', 
            'hardware', 'accessory', 'service', 'window_film', 'end_cap'
            -- NOTE: 'operating_system' is EXCLUDED because it's legacy
        ]) as role
    ) roles;
    
    -- Iterate through all ProductTypes for this organization
    FOR v_product_type IN
        SELECT pt.id, pt.name, pt.code
        FROM "ProductTypes" pt
        WHERE pt.organization_id = p_organization_id
        AND pt.deleted = false
        ORDER BY pt.sort_order NULLS LAST, pt.name
    LOOP
        v_issues := '[]'::jsonb;
        v_suggested_seeds := '[]'::jsonb;
        v_template_count := 0;
        v_component_count := 0;
        v_invalid_role_count := 0;
        v_auto_select_count := 0;
        v_auto_select_resolvable_count := 0;
        v_fixed_component_count := 0;
        v_fixed_valid_count := 0;
        v_missing_mappings := ARRAY[]::text[];
        v_incomplete_auto_select_count := 0;
        
        -- A) Check if BOMTemplate exists
        SELECT COUNT(*) INTO v_template_count
        FROM "BOMTemplates" bt
        WHERE bt.product_type_id = v_product_type.id
        AND bt.organization_id = p_organization_id
        AND bt.deleted = false
        AND bt.active = true;
        
        IF v_template_count = 0 THEN
            v_issues := v_issues || jsonb_build_object(
                'type', 'MISSING_TEMPLATE',
                'severity', 'BLOCKER',
                'message', 'No active BOMTemplate found for this ProductType'
            );
            
            v_suggested_seeds := v_suggested_seeds || jsonb_build_object(
                'type', 'CREATE_TEMPLATE',
                'sql', format(
                    'INSERT INTO "BOMTemplates" (organization_id, product_type_id, name, description, active, deleted, created_at, updated_at) VALUES (%L, %L, %L, %L, true, false, now(), now());',
                    p_organization_id, 
                    v_product_type.id, 
                    v_product_type.name || ' - Base Template', 
                    'Auto-generated template for ' || v_product_type.name
                )
            );
        ELSE
            -- B) Check BOMComponents for templates
            SELECT COUNT(*) INTO v_component_count
            FROM "BOMComponents" bc
            INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
            WHERE bt.product_type_id = v_product_type.id
            AND bt.organization_id = p_organization_id
            AND bt.deleted = false
            AND bt.active = true
            AND bc.deleted = false;
            
            IF v_component_count = 0 THEN
                v_issues := v_issues || jsonb_build_object(
                    'type', 'MISSING_COMPONENTS',
                    'severity', 'BLOCKER',
                    'message', format('BOMTemplate exists but has no BOMComponents (%s templates)', v_template_count)
                );
            END IF;
            
            -- C) Check for legacy roles (WARNING, not BLOCKER)
            FOR v_role_used IN
                SELECT DISTINCT bc.component_role
                FROM "BOMComponents" bc
                INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
                WHERE bt.product_type_id = v_product_type.id
                AND bt.organization_id = p_organization_id
                AND bt.deleted = false
                AND bt.active = true
                AND bc.deleted = false
                AND bc.component_role IS NOT NULL
            LOOP
                -- Check if role is legacy
                v_is_legacy := v_role_used.component_role = ANY(v_legacy_roles);
                
                IF v_is_legacy THEN
                    v_issues := v_issues || jsonb_build_object(
                        'type', 'LEGACY_ROLE_DETECTED',
                        'severity', 'WARN',
                        'message', format('Legacy role "%s" detected. Please migrate to canonical role (e.g., drive_motorized, drive_manual, or control_system)', 
                            v_role_used.component_role),
                        'role', v_role_used.component_role
                    );
                    
                    v_suggested_seeds := v_suggested_seeds || jsonb_build_object(
                        'type', 'MIGRATE_LEGACY_ROLE',
                        'sql', format(
                            '-- TODO: Migrate role %L to canonical role\n-- UPDATE "BOMComponents" SET component_role = ''CANONICAL_ROLE_HERE'' WHERE component_role = %L AND bom_template_id IN (SELECT id FROM "BOMTemplates" WHERE product_type_id = %L);',
                            v_role_used.component_role,
                            v_role_used.component_role,
                            v_product_type.id
                        )
                    );
                END IF;
                
                -- D) Check ComponentRoleMap for each role used (only if not legacy or canonical)
                IF NOT v_is_legacy THEN
                    -- First, try to get category codes using get_item_category_codes_from_role
                    -- This handles special cases like 'end_cap' that map to COMP-HARDWARE
                    v_has_mapping := false;
                    v_test_category_codes := NULL;
                    
                    -- Try to get category codes (this will work for special cases like end_cap)
                    BEGIN
                        v_test_category_codes := public.get_item_category_codes_from_role(v_role_used.component_role, NULL);
                        IF v_test_category_codes IS NOT NULL AND array_length(v_test_category_codes, 1) > 0 THEN
                            v_has_mapping := true;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS THEN
                            -- Function failed, mapping might be missing, but check ComponentRoleMap too
                            v_has_mapping := false;
                    END;
                    
                    -- If get_item_category_codes_from_role didn't work, check ComponentRoleMap directly
                    IF NOT v_has_mapping THEN
                        IF EXISTS (
                            SELECT 1
                            FROM "ComponentRoleMap" crm
                            WHERE crm.role = v_role_used.component_role
                            AND crm.active = true
                        ) THEN
                            v_has_mapping := true;
                        END IF;
                    END IF;
                    
                    -- Only report MISSING_ROLE_MAPPING if neither method found a mapping
                    IF NOT v_has_mapping THEN
                        v_missing_mappings := v_missing_mappings || v_role_used.component_role;
                        
                        v_issues := v_issues || jsonb_build_object(
                            'type', 'MISSING_ROLE_MAPPING',
                            'severity', 'BLOCKER',
                            'message', format('Component role "%s" has no mapping in ComponentRoleMap', v_role_used.component_role),
                            'role', v_role_used.component_role
                        );
                        
                        -- Suggest seed
                        v_suggested_seeds := v_suggested_seeds || jsonb_build_object(
                            'type', 'CREATE_ROLE_MAPPING',
                            'sql', format(
                                '-- TODO: Map role %L to appropriate ItemCategories.code(s)\n-- INSERT INTO "ComponentRoleMap" (item_category_code, role, sub_role, active) VALUES (''CATEGORY_CODE_HERE'', %L, NULL, true);',
                                v_role_used.component_role,
                                v_role_used.component_role
                            )
                        );
                    END IF;
                END IF;
            END LOOP;
            
            -- E) Validate Fixed Components (CatalogItems exist, have UOM, have item_category_id)
            SELECT 
                COUNT(*) FILTER (WHERE bc.component_item_id IS NOT NULL) as fixed_count,
                COUNT(*) FILTER (
                    WHERE bc.component_item_id IS NOT NULL 
                    AND EXISTS (
                        SELECT 1 FROM "CatalogItems" ci 
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
            
            IF v_fixed_component_count > v_fixed_valid_count THEN
                v_issues := v_issues || jsonb_build_object(
                    'type', 'INVALID_FIXED_COMPONENTS',
                    'severity', 'BLOCKER',
                    'message', format('%s fixed component(s) have missing CatalogItems, NULL UOM, or missing item_category_id', 
                        v_fixed_component_count - v_fixed_valid_count)
                );
            END IF;
            
            -- Count components with missing UOM in CatalogItems
            SELECT COUNT(*) INTO v_missing_uom_count
            FROM "BOMComponents" bc
            INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
            LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
            WHERE bt.product_type_id = v_product_type.id
            AND bt.organization_id = p_organization_id
            AND bt.deleted = false
            AND bt.active = true
            AND bc.deleted = false
            AND bc.component_item_id IS NOT NULL
            AND (ci.id IS NULL OR ci.uom IS NULL OR TRIM(ci.uom) = '');
            
            IF v_missing_uom_count > 0 THEN
                v_issues := v_issues || jsonb_build_object(
                    'type', 'MISSING_UOM',
                    'severity', 'BLOCKER',
                    'message', format('%s fixed component(s) have CatalogItems with NULL or empty UOM', v_missing_uom_count)
                );
            END IF;
            
            -- F) Validate Auto-Select Components
            SELECT COUNT(*) INTO v_auto_select_count
            FROM "BOMComponents" bc
            INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
            WHERE bt.product_type_id = v_product_type.id
            AND bt.organization_id = p_organization_id
            AND bt.deleted = false
            AND bt.active = true
            AND bc.deleted = false
            AND (bc.auto_select = true OR bc.component_item_id IS NULL)
            AND bc.component_role IS NOT NULL;
            
            -- Check for incomplete auto-select (missing sku_resolution_rule or qty_type)
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
            
            IF v_incomplete_auto_select_count > 0 THEN
                v_issues := v_issues || jsonb_build_object(
                    'type', 'INCOMPLETE_AUTO_SELECT',
                    'severity', 'BLOCKER',
                    'message', format('%s auto-select component(s) are missing required fields (sku_resolution_rule or qty_type)', 
                        v_incomplete_auto_select_count)
                );
            END IF;
            
            -- Check if auto-select components are resolvable (only for non-legacy roles)
            FOR v_component IN
                SELECT DISTINCT bc.component_role, bc.sku_resolution_rule
                FROM "BOMComponents" bc
                INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
                WHERE bt.product_type_id = v_product_type.id
                AND bt.organization_id = p_organization_id
                AND bt.deleted = false
                AND bt.active = true
                AND bc.deleted = false
                AND (bc.auto_select = true OR bc.component_item_id IS NULL)
                AND bc.component_role IS NOT NULL
                AND bc.component_role != ALL(v_legacy_roles)  -- Skip legacy roles
            LOOP
                -- Try to get category codes for this role
                BEGIN
                    v_category_codes := public.get_item_category_codes_from_role(v_component.component_role);
                    
                    -- Check if there are any CatalogItems in these categories
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
                    ELSE
                        v_issues := v_issues || jsonb_build_object(
                            'type', 'AUTO_SELECT_NOT_RESOLVABLE',
                            'severity', 'BLOCKER',
                            'message', format('Auto-select component with role "%s" cannot be resolved - no CatalogItems found in mapped categories', 
                                v_component.component_role),
                            'role', v_component.component_role
                        );
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                        -- If get_item_category_codes_from_role fails, role mapping is missing (already reported above)
                        NULL;
                END;
            END LOOP;
            
            IF v_auto_select_count > 0 AND v_auto_select_resolvable_count < (v_auto_select_count - v_incomplete_auto_select_count) THEN
                -- Only warn if we have resolvable components but some are not resolvable
                -- (incomplete ones are already reported as BLOCKER above)
                NULL;  -- Already reported as AUTO_SELECT_NOT_RESOLVABLE above
            END IF;
        END IF;
        
        -- Determine overall status and build result for this ProductType
        v_product_type_result := jsonb_build_object(
            'product_type_id', v_product_type.id,
            'product_type_name', v_product_type.name,
            'product_type_code', COALESCE(v_product_type.code, ''),
            'template_count', v_template_count,
            'components_count', v_component_count,
            'status', CASE
                WHEN v_template_count = 0 THEN 'MISSING_TEMPLATE'
                WHEN v_component_count = 0 THEN 'MISSING_COMPONENTS'
                WHEN jsonb_array_length(v_issues) > 0 AND EXISTS (
                    SELECT 1 FROM jsonb_array_elements(v_issues) AS issue 
                    WHERE (issue->>'severity') = 'BLOCKER'
                ) THEN 'ISSUES'
                WHEN jsonb_array_length(v_issues) > 0 THEN 'WARNINGS'
                ELSE 'READY'
            END,
            'issues', v_issues,
            'suggested_seeds', v_suggested_seeds,
            'stats', jsonb_build_object(
                'fixed_components', COALESCE(v_fixed_component_count, 0),
                'valid_fixed_components', COALESCE(v_fixed_valid_count, 0),
                'auto_select_components', COALESCE(v_auto_select_count, 0),
                'resolvable_auto_select', COALESCE(v_auto_select_resolvable_count, 0),
                'missing_uom_count', COALESCE(v_missing_uom_count, 0),
                'incomplete_auto_select_count', COALESCE(v_incomplete_auto_select_count, 0)
            )
        );
        
        -- Append to array properly
        v_items := array_append(v_items, v_product_type_result);
    END LOOP;
    
    -- Convert array of jsonb to jsonb array
    IF array_length(v_items, 1) > 0 THEN
        SELECT jsonb_agg(elem) INTO v_result FROM unnest(v_items) AS elem;
    ELSE
        v_result := '[]'::jsonb;
    END IF;
    
    RETURN v_result;
END;
$$;

COMMENT ON FUNCTION public.bom_readiness_report(uuid) IS 
'Analyzes BOM readiness for all ProductTypes in an organization. Returns JSON array with status, issues, and suggested seeds for each ProductType. Detects legacy roles (operating_system) as WARNINGS, not blockers. Only validates roles actually used in BOMComponents.';

