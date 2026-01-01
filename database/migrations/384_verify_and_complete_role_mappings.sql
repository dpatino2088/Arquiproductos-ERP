-- ====================================================
-- Migration 384: Verify and Complete Role Mappings
-- ====================================================
-- Verifies that all roles used in BOMComponents have mappings in ComponentRoleMap
-- Creates missing mappings if they don't exist (based on standard ItemCategory codes)
-- ====================================================
-- NOTE: end_cap is handled by get_item_category_codes_from_role special case (maps to COMP-HARDWARE)
-- ====================================================

DO $$
DECLARE
    v_role_count integer;
    v_mapping_count integer;
    v_created_count integer := 0;
    v_role_record RECORD;
BEGIN
    -- Check which roles are used but don't have mappings
    RAISE NOTICE 'Checking for roles without mappings...';
    
    FOR v_role_record IN
        SELECT DISTINCT bc.component_role
        FROM "BOMComponents" bc
        INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
        WHERE bc.component_role IS NOT NULL
            AND bc.deleted = false
            AND bt.deleted = false
            AND bt.active = true
            AND bc.component_role NOT IN ('operating_system')  -- Skip legacy roles
            AND NOT EXISTS (
                SELECT 1 
                FROM "ComponentRoleMap" crm 
                WHERE crm.role = bc.component_role 
                AND crm.active = true
            )
    LOOP
        RAISE NOTICE 'Role "%" has no mapping. Checking if ItemCategory exists...', v_role_record.component_role;
        
        -- Try to find/create mapping based on standard ItemCategory codes
        CASE v_role_record.component_role
            WHEN 'bottom_bar' THEN
                -- COMP-BOTTOM-BAR should already exist from migration 363
                IF EXISTS (SELECT 1 FROM "ItemCategories" WHERE code = 'COMP-BOTTOM-BAR' AND deleted = false) THEN
                    INSERT INTO "ComponentRoleMap" (item_category_code, role, sub_role, description, active)
                    VALUES ('COMP-BOTTOM-BAR', 'bottom_bar', NULL, 'Bottom bar components', true)
                    ON CONFLICT (item_category_code) DO UPDATE SET
                        role = EXCLUDED.role,
                        sub_role = EXCLUDED.sub_role,
                        description = EXCLUDED.description,
                        active = EXCLUDED.active,
                        updated_at = now();
                    v_created_count := v_created_count + 1;
                    RAISE NOTICE '  ✅ Created/updated mapping: bottom_bar -> COMP-BOTTOM-BAR';
                ELSE
                    RAISE WARNING '  ⚠️  ItemCategory COMP-BOTTOM-BAR does not exist. Mapping not created.';
                END IF;
                
            WHEN 'bottom_rail' THEN
                -- COMP-BOTTOM-RAIL should already exist from migration 363
                IF EXISTS (SELECT 1 FROM "ItemCategories" WHERE code = 'COMP-BOTTOM-RAIL' AND deleted = false) THEN
                    INSERT INTO "ComponentRoleMap" (item_category_code, role, sub_role, description, active)
                    VALUES ('COMP-BOTTOM-RAIL', 'bottom_rail', NULL, 'Bottom rail components', true)
                    ON CONFLICT (item_category_code) DO UPDATE SET
                        role = EXCLUDED.role,
                        sub_role = EXCLUDED.sub_role,
                        description = EXCLUDED.description,
                        active = EXCLUDED.active,
                        updated_at = now();
                    v_created_count := v_created_count + 1;
                    RAISE NOTICE '  ✅ Created/updated mapping: bottom_rail -> COMP-BOTTOM-RAIL';
                ELSE
                    RAISE WARNING '  ⚠️  ItemCategory COMP-BOTTOM-RAIL does not exist. Mapping not created.';
                END IF;
                
            WHEN 'drive_motorized' THEN
                -- DRIVE-MOTORIZED should already exist from migration 363
                IF EXISTS (SELECT 1 FROM "ItemCategories" WHERE code = 'DRIVE-MOTORIZED' AND deleted = false) THEN
                    INSERT INTO "ComponentRoleMap" (item_category_code, role, sub_role, description, active)
                    VALUES ('DRIVE-MOTORIZED', 'drive_motorized', NULL, 'Motorized drive components', true)
                    ON CONFLICT (item_category_code) DO UPDATE SET
                        role = EXCLUDED.role,
                        sub_role = EXCLUDED.sub_role,
                        description = EXCLUDED.description,
                        active = EXCLUDED.active,
                        updated_at = now();
                    v_created_count := v_created_count + 1;
                    RAISE NOTICE '  ✅ Created/updated mapping: drive_motorized -> DRIVE-MOTORIZED';
                ELSE
                    RAISE WARNING '  ⚠️  ItemCategory DRIVE-MOTORIZED does not exist. Mapping not created.';
                END IF;
                
            WHEN 'end_cap' THEN
                -- end_cap is handled by get_item_category_codes_from_role special case (maps to COMP-HARDWARE)
                -- No mapping entry needed in ComponentRoleMap (it's handled in code)
                RAISE NOTICE '  ℹ️  end_cap uses special case mapping to COMP-HARDWARE (handled by get_item_category_codes_from_role)';
                
            ELSE
                RAISE WARNING '  ⚠️  Unknown role "%" - no automatic mapping available. Please create mapping manually.', v_role_record.component_role;
        END CASE;
    END LOOP;
    
    IF v_created_count = 0 THEN
        RAISE NOTICE '✅ All roles have mappings (or use special cases). No mappings created.';
    ELSE
        RAISE NOTICE '✅ Created/updated % mapping(s)', v_created_count;
    END IF;
    
    -- Final verification: report roles that still don't have mappings
    SELECT COUNT(DISTINCT bc.component_role) INTO v_role_count
    FROM "BOMComponents" bc
    INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
    WHERE bc.component_role IS NOT NULL
        AND bc.deleted = false
        AND bt.deleted = false
        AND bt.active = true
        AND bc.component_role NOT IN ('operating_system', 'end_cap')  -- Skip legacy and special case
        AND NOT EXISTS (
            SELECT 1 
            FROM "ComponentRoleMap" crm 
            WHERE crm.role = bc.component_role 
            AND crm.active = true
        );
    
    IF v_role_count > 0 THEN
        RAISE WARNING '⚠️  % role(s) still missing mappings. Run diagnostic query to identify them.', v_role_count;
    ELSE
        RAISE NOTICE '✅ All roles (except legacy and special cases) have mappings.';
    END IF;
END $$;

-- ====================================================
-- Verification Query (run separately to verify)
-- ====================================================
-- This query shows which roles are used but don't have mappings
-- 
-- SELECT DISTINCT 
--     bc.component_role,
--     COUNT(*) as component_count,
--     CASE 
--         WHEN bc.component_role = 'end_cap' THEN 'Special case: maps to COMP-HARDWARE via get_item_category_codes_from_role'
--         WHEN bc.component_role = 'operating_system' THEN 'Legacy role: should be migrated'
--         WHEN EXISTS (SELECT 1 FROM "ComponentRoleMap" crm WHERE crm.role = bc.component_role AND crm.active = true) 
--             THEN 'Has mapping'
--         ELSE 'Missing mapping'
--     END as mapping_status
-- FROM "BOMComponents" bc
-- INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
-- WHERE bc.component_role IS NOT NULL
--     AND bc.deleted = false
--     AND bt.deleted = false
--     AND bt.active = true
-- GROUP BY bc.component_role
-- ORDER BY bc.component_role;

