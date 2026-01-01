-- ====================================================
-- Migration 393: Fix Fixed Components Count Bug
-- ====================================================
-- BUG: bom_readiness_report was counting ALL components (including auto-select)
-- as "fixed components", then only validating those with component_item_id IS NOT NULL.
-- This caused auto-select components to appear as "invalid fixed components".
-- 
-- FIX: Only count components with component_item_id IS NOT NULL as fixed components.
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
    v_is_resolvable boolean;  -- For checking if a component is resolvable
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
            
            v_product_type_result := jsonb_build_object(
                'product_type_id', v_product_type.id,
                'product_type_name', v_product_type.name,
                'product_type_code', v_product_type.code,
                'template_count', 0,
                'components_count', 0,
                'status', 'BLOCKED',
                'issues', v_issues,
                'suggested_seeds', v_suggested_seeds
            );
            
            v_items := v_items || v_product_type_result;
            CONTINUE;  -- Skip to next product type
        END IF;
        
        -- B) Count total components
        SELECT COUNT(*) INTO v_component_count
        FROM "BOMComponents" bc
        INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
        WHERE bt.product_type_id = v_product_type.id
        AND bt.organization_id = p_organization_id
        AND bt.deleted = false
        AND bt.active = true
        AND bc.deleted = false;
        
        -- C) Validate component roles (only check roles that are actually used)
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
            
            -- Check if role is canonical
            IF NOT (v_role_used.component_role = ANY(v_canonical_roles)) AND NOT v_is_legacy THEN
                v_invalid_role_count := v_invalid_role_count + 1;
            ELSIF v_is_legacy THEN
                -- Legacy role detected - add as warning, not blocker
                v_issues := v_issues || jsonb_build_object(
                    'type', 'LEGACY_ROLE_DETECTED',
                    'severity', 'WARN',
                    'message', format('Legacy role "%s" detected. Consider migrating to canonical role.', v_role_used.component_role)
                );
            END IF;
        END LOOP;
        
        IF v_invalid_role_count > 0 THEN
            v_issues := v_issues || jsonb_build_object(
                'type', 'INVALID_ROLES',
                'severity', 'BLOCKER',
                'message', format('%s component(s) have invalid (non-canonical) roles', v_invalid_role_count)
            );
        END IF;
        
        -- D) Check auto-select components resolvability (count by individual component, not by role)
        SELECT 
            COUNT(*) FILTER (WHERE bc.component_item_id IS NULL OR bc.auto_select = true) as auto_select_count,
            COUNT(*) FILTER (
                WHERE (bc.component_item_id IS NULL OR bc.auto_select = true)
                AND bc.component_role IS NOT NULL
                AND bc.sku_resolution_rule IS NOT NULL
                AND bc.qty_type IS NOT NULL
            ) as complete_auto_select_count
        INTO v_auto_select_count, v_incomplete_auto_select_count
        FROM "BOMComponents" bc
        INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
        WHERE bt.product_type_id = v_product_type.id
        AND bt.organization_id = p_organization_id
        AND bt.deleted = false
        AND bt.active = true
        AND bc.deleted = false;
        
        IF v_incomplete_auto_select_count < v_auto_select_count THEN
            v_issues := v_issues || jsonb_build_object(
                'type', 'INCOMPLETE_AUTO_SELECT',
                'severity', 'BLOCKER',
                'message', format('%s auto-select component(s) missing required fields (sku_resolution_rule, qty_type)', 
                    v_auto_select_count - v_incomplete_auto_select_count)
            );
        END IF;
        
        -- Check resolvability for each auto-select component individually
        FOR v_component IN
            SELECT 
                bc.id,
                bc.component_role,
                bc.component_sub_role,
                bc.sku_resolution_rule,
                bc.hardware_color,
                bc.block_condition
            FROM "BOMComponents" bc
            INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
            WHERE bt.product_type_id = v_product_type.id
            AND bt.organization_id = p_organization_id
            AND bt.deleted = false
            AND bt.active = true
            AND bc.deleted = false
            AND (bc.component_item_id IS NULL OR bc.auto_select = true)
            AND bc.component_role IS NOT NULL
        LOOP
            -- Check if role has mapping
            v_test_category_codes := public.get_item_category_codes_from_role(
                v_component.component_role,
                v_component.component_sub_role
            );
            
            IF v_test_category_codes IS NULL OR array_length(v_test_category_codes, 1) IS NULL THEN
                -- Missing role mapping - already handled above, skip
                v_is_resolvable := false;
            ELSE
                -- Check if there are CatalogItems for this role
                SELECT COUNT(*) INTO v_catalog_item_count
                FROM "CatalogItems" ci
                INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                WHERE ic.code = ANY(v_test_category_codes)
                AND ci.organization_id = p_organization_id
                AND ci.deleted = false
                AND ci.active = true;
                
                v_is_resolvable := (v_catalog_item_count > 0);
            END IF;
            
            IF v_is_resolvable THEN
                v_auto_select_resolvable_count := v_auto_select_resolvable_count + 1;
            END IF;
        END LOOP;
        
        IF v_auto_select_count > 0 AND v_auto_select_resolvable_count < v_auto_select_count THEN
            v_issues := v_issues || jsonb_build_object(
                'type', 'UNRESOLVABLE_AUTO_SELECT',
                'severity', 'BLOCKER',
                'message', format('%s auto-select component(s) cannot be resolved (no matching CatalogItems found)', 
                    v_auto_select_count - v_auto_select_resolvable_count)
            );
        END IF;
        
        -- E) Validate Fixed Components (CatalogItems exist, have UOM, have item_category_id)
        -- BUG FIX: Only count components with component_item_id IS NOT NULL as fixed components
        SELECT 
            COUNT(*) FILTER (WHERE bc.component_item_id IS NOT NULL) as fixed_count,
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
        
        IF v_fixed_component_count > v_fixed_valid_count THEN
            v_issues := v_issues || jsonb_build_object(
                'type', 'INVALID_FIXED_COMPONENTS',
                'severity', 'BLOCKER',
                'message', format('%s fixed component(s) have missing CatalogItems, NULL UOM, or missing item_category_id', 
                    v_fixed_component_count - v_fixed_valid_count)
            );
        END IF;
        
        -- F) Check for missing role mappings (only for roles actually used)
        FOR v_role_used IN
            SELECT DISTINCT bc.component_role, bc.component_sub_role
            FROM "BOMComponents" bc
            INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
            WHERE bt.product_type_id = v_product_type.id
            AND bt.organization_id = p_organization_id
            AND bt.deleted = false
            AND bt.active = true
            AND bc.deleted = false
            AND bc.component_role IS NOT NULL
        LOOP
            -- Special case: end_cap is mapped via get_item_category_codes_from_role
            IF v_role_used.component_role = 'end_cap' THEN
                v_test_category_codes := public.get_item_category_codes_from_role(
                    v_role_used.component_role,
                    v_role_used.component_sub_role
                );
                IF v_test_category_codes IS NULL OR array_length(v_test_category_codes, 1) IS NULL THEN
                    IF NOT (v_role_used.component_role = ANY(v_missing_mappings)) THEN
                        v_missing_mappings := v_missing_mappings || v_role_used.component_role;
                    END IF;
                END IF;
            ELSE
                -- Check ComponentRoleMap
                -- BUG FIX: If mapping has sub_role = NULL, it accepts any component sub_role (generic mapping)
                -- If mapping has specific sub_role, it only matches components with that exact sub_role
                SELECT EXISTS (
                    SELECT 1 
                    FROM "ComponentRoleMap" crm
                    WHERE crm.role = v_role_used.component_role
                    AND (
                        crm.sub_role = v_role_used.component_sub_role  -- Exact match
                        OR crm.sub_role IS NULL  -- Generic mapping (accepts any sub_role)
                    )
                    AND crm.active = true
                ) INTO v_has_mapping;
                
                IF NOT v_has_mapping THEN
                    IF NOT (v_role_used.component_role = ANY(v_missing_mappings)) THEN
                        v_missing_mappings := v_missing_mappings || v_role_used.component_role;
                    END IF;
                END IF;
            END IF;
        END LOOP;
        
        IF array_length(v_missing_mappings, 1) > 0 THEN
            v_issues := v_issues || jsonb_build_object(
                'type', 'MISSING_ROLE_MAPPING',
                'severity', 'BLOCKER',
                'message', format('Missing ComponentRoleMap entries for roles: %s', array_to_string(v_missing_mappings, ', '))
            );
            
            -- Generate suggested seeds
            FOR v_role_used IN
                SELECT unnest(v_missing_mappings) as role_name
            LOOP
                -- Try to infer item_category_code from role name
                v_suggested_seeds := v_suggested_seeds || jsonb_build_object(
                    'type', 'CREATE_ROLE_MAPPING',
                    'sql', format(
                        '-- TODO: Map role "%s" to appropriate ItemCategories.code. Example: INSERT INTO "ComponentRoleMap" (item_category_code, role, sub_role, active) VALUES (%L, %L, NULL, true);',
                        v_role_used.role_name,
                        'COMP-' || upper(replace(v_role_used.role_name, '_', '-')),
                        v_role_used.role_name
                    )
                );
            END LOOP;
        END IF;
        
        -- Determine status
        IF jsonb_array_length(v_issues) = 0 THEN
            v_product_type_result := jsonb_build_object(
                'product_type_id', v_product_type.id,
                'product_type_name', v_product_type.name,
                'product_type_code', v_product_type.code,
                'template_count', v_template_count,
                'components_count', v_component_count,
                'status', 'READY',
                'issues', v_issues,
                'suggested_seeds', v_suggested_seeds
            );
        ELSE
            -- Check if there are blockers
            IF EXISTS (
                SELECT 1 
                FROM jsonb_array_elements(v_issues) issue
                WHERE upper(issue->>'severity') IN ('BLOCKER', 'CRITICAL')
            ) THEN
                v_product_type_result := jsonb_build_object(
                    'product_type_id', v_product_type.id,
                    'product_type_name', v_product_type.name,
                    'product_type_code', v_product_type.code,
                    'template_count', v_template_count,
                    'components_count', v_component_count,
                    'status', 'BLOCKED',
                    'issues', v_issues,
                    'suggested_seeds', v_suggested_seeds
                );
            ELSE
                v_product_type_result := jsonb_build_object(
                    'product_type_id', v_product_type.id,
                    'product_type_name', v_product_type.name,
                    'product_type_code', v_product_type.code,
                    'template_count', v_template_count,
                    'components_count', v_component_count,
                    'status', 'WARNING',
                    'issues', v_issues,
                    'suggested_seeds', v_suggested_seeds
                );
            END IF;
        END IF;
        
        v_items := v_items || v_product_type_result;
    END LOOP;
    
    -- Return as JSON array
    RETURN COALESCE(
        (SELECT jsonb_agg(elem) FROM unnest(v_items) AS elem),
        '[]'::jsonb
    );
END;
$$;

COMMENT ON FUNCTION public.bom_readiness_report(uuid) IS 'Reports BOM readiness status for all ProductTypes in an organization. Fixed in migration 393 to only count components with component_item_id IS NOT NULL as fixed components.';

