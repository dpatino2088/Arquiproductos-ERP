-- ====================================================
-- Migration 277: Fix Operating System Drive and Missing Components
-- ====================================================
-- Corrige el mapeo de operating_system_drive (M-CC-01 es incorrecto)
-- Asegura que motor_adapter y bottom_rail_profile estén correctamente mapeados
-- ====================================================

BEGIN;

DO $$
DECLARE
    v_roller_shade_product_type_id uuid;
    v_organization_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid;
    v_catalog_item_id uuid;
    v_operating_system_drive_id uuid;
    v_motor_adapter_id uuid;
    v_row_count integer;
BEGIN
    -- Find Roller Shade product type
    SELECT id INTO v_roller_shade_product_type_id
    FROM "ProductTypes"
    WHERE code = 'ROLLER' OR name ILIKE '%roller%shade%'
    AND deleted = false
    LIMIT 1;
    
    IF v_roller_shade_product_type_id IS NULL THEN
        RAISE EXCEPTION 'Roller Shade product type not found';
    END IF;
    
    RAISE NOTICE '✅ Found Roller Shade product_type_id: %', v_roller_shade_product_type_id;
    
    -- ====================================================
    -- STEP 1: Desactivar mapeo incorrecto de operating_system_drive (M-CC-01)
    -- ====================================================
    
    UPDATE "BomRoleSkuMapping"
    SET active = false, updated_at = now()
    WHERE component_role = 'operating_system_drive'
        AND product_type_id = v_roller_shade_product_type_id
        AND catalog_item_id IN (
            SELECT id FROM "CatalogItems"
            WHERE sku ILIKE 'M-CC-01%' OR item_name ILIKE '%MEASUREMENT%TOOL%'
        );
    
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count > 0 THEN
        RAISE NOTICE '✅ Desactivado mapeo incorrecto de operating_system_drive (M-CC-01): % filas', v_row_count;
    END IF;
    
    -- ====================================================
    -- STEP 2: Buscar y mapear operating_system_drive correcto
    -- ====================================================
    
    -- Buscar drive belt real (excluyendo M-CC-01 y herramientas)
    SELECT ci.id INTO v_operating_system_drive_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND cipt.deleted = false
        AND (
            ci.item_name ILIKE '%DRIVE%PLUG%' OR
            ci.item_name ILIKE '%DRIVE%BELT%' OR
            (ci.item_name ILIKE '%DRIVE%' AND NOT ci.item_name ILIKE '%TOOL%')
        )
        AND NOT (ci.sku ILIKE 'M-CC-%' OR ci.item_name ILIKE '%MEASUREMENT%' OR ci.item_name ILIKE '%TOOL%')
    ORDER BY 
        CASE WHEN ci.item_name ILIKE '%DRIVE%PLUG%' THEN 0 ELSE 1 END,
        ci.created_at DESC
    LIMIT 1;
    
    IF v_operating_system_drive_id IS NOT NULL THEN
        -- Verificar si ya existe un mapeo activo
        IF NOT EXISTS (
            SELECT 1 FROM "BomRoleSkuMapping"
            WHERE component_role = 'operating_system_drive'
                AND product_type_id = v_roller_shade_product_type_id
                AND catalog_item_id = v_operating_system_drive_id
                AND deleted = false
                AND active = true
        ) THEN
            INSERT INTO "BomRoleSkuMapping" (
                organization_id,
                product_type_id,
                component_role,
                operating_system_variant,
                catalog_item_id,
                priority
            )
            VALUES (
                v_organization_id,
                v_roller_shade_product_type_id,
                'operating_system_drive',
                'standard_m',
                v_operating_system_drive_id,
                10
            )
            ON CONFLICT DO NOTHING;
            
            RAISE NOTICE '✅ Creado mapeo correcto para operating_system_drive (standard_m)';
        ELSE
            RAISE NOTICE 'ℹ️  Mapeo de operating_system_drive ya existe';
        END IF;
    ELSE
        RAISE WARNING '⚠️  No se encontró un operating_system_drive válido (excluyendo M-CC-01)';
    END IF;
    
    -- ====================================================
    -- STEP 3: Verificar y crear mapeo de motor_adapter si falta
    -- ====================================================
    
    -- Verificar si ya existe mapeo de motor_adapter
    SELECT catalog_item_id INTO v_motor_adapter_id
    FROM "BomRoleSkuMapping"
    WHERE component_role = 'motor_adapter'
        AND product_type_id = v_roller_shade_product_type_id
        AND deleted = false
        AND active = true
    LIMIT 1;
    
    IF v_motor_adapter_id IS NULL THEN
        -- Buscar motor_adapter CatalogItem
        SELECT ci.id INTO v_motor_adapter_id
        FROM "CatalogItems" ci
        JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
        WHERE ci.organization_id = v_organization_id
            AND ci.deleted = false
            AND cipt.product_type_id = v_roller_shade_product_type_id
            AND cipt.deleted = false
            AND (
                ci.item_name ILIKE '%BRACKET%ADAPTER%MOTOR%' OR
                ci.sku ILIKE '%RC3162%' OR
                ci.item_name ILIKE '%ADAPTER%MOTOR%' OR
                (ci.item_name ILIKE '%ADAPTER%' AND ci.item_name ILIKE '%MOTOR%')
            )
        ORDER BY 
            CASE WHEN ci.item_name ILIKE '%BRACKET%ADAPTER%MOTOR%' THEN 0 ELSE 1 END,
            ci.created_at DESC
        LIMIT 1;
        
        IF v_motor_adapter_id IS NOT NULL THEN
            INSERT INTO "BomRoleSkuMapping" (
                organization_id,
                product_type_id,
                component_role,
                catalog_item_id,
                priority
            )
            VALUES (
                v_organization_id,
                v_roller_shade_product_type_id,
                'motor_adapter',
                v_motor_adapter_id,
                10
            )
            ON CONFLICT DO NOTHING;
            
            RAISE NOTICE '✅ Creado mapeo para motor_adapter';
        ELSE
            RAISE WARNING '⚠️  No se encontró motor_adapter CatalogItem vinculado a Roller Shade';
        END IF;
    ELSE
        RAISE NOTICE 'ℹ️  Mapeo de motor_adapter ya existe';
    END IF;
    
    -- ====================================================
    -- STEP 4: Verificar bottom_rail_profile (ya existe según diagnóstico)
    -- ====================================================
    
    SELECT COUNT(*) INTO v_row_count
    FROM "BomRoleSkuMapping"
    WHERE component_role = 'bottom_rail_profile'
        AND product_type_id = v_roller_shade_product_type_id
        AND deleted = false
        AND active = true;
    
    IF v_row_count > 0 THEN
        RAISE NOTICE '✅ Mapeo de bottom_rail_profile existe (% mapeos)', v_row_count;
    ELSE
        RAISE WARNING '⚠️  Mapeo de bottom_rail_profile NO existe';
    END IF;
    
    -- ====================================================
    -- STEP 5: Verificar bottom_rail_end_cap
    -- ====================================================
    
    SELECT COUNT(*) INTO v_row_count
    FROM "BomRoleSkuMapping"
    WHERE component_role = 'bottom_rail_end_cap'
        AND product_type_id = v_roller_shade_product_type_id
        AND deleted = false
        AND active = true;
    
    IF v_row_count = 0 THEN
        -- Buscar bottom_rail_end_cap
        SELECT ci.id INTO v_catalog_item_id
        FROM "CatalogItems" ci
        JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
        WHERE ci.organization_id = v_organization_id
            AND ci.deleted = false
            AND cipt.product_type_id = v_roller_shade_product_type_id
            AND cipt.deleted = false
            AND (ci.sku ILIKE '%END%CAP%' OR ci.item_name ILIKE '%END%CAP%' OR ci.sku ILIKE '%CAP%')
            AND (ci.sku ILIKE '%BOTTOM%RAIL%' OR ci.item_name ILIKE '%BOTTOM%RAIL%' OR ci.sku ILIKE '%RAIL%' OR ci.item_name ILIKE '%RAIL%')
        ORDER BY ci.created_at DESC
        LIMIT 1;
        
        IF v_catalog_item_id IS NOT NULL THEN
            INSERT INTO "BomRoleSkuMapping" (
                organization_id,
                product_type_id,
                component_role,
                catalog_item_id,
                priority
            )
            VALUES (
                v_organization_id,
                v_roller_shade_product_type_id,
                'bottom_rail_end_cap',
                v_catalog_item_id,
                10
            )
            ON CONFLICT DO NOTHING;
            
            RAISE NOTICE '✅ Creado mapeo para bottom_rail_end_cap';
        ELSE
            RAISE WARNING '⚠️  No se encontró bottom_rail_end_cap CatalogItem';
        END IF;
    ELSE
        RAISE NOTICE 'ℹ️  Mapeo de bottom_rail_end_cap ya existe';
    END IF;
    
    RAISE NOTICE '✅ Corrección de mapeos completada';
    
END $$;

COMMIT;

-- ====================================================
-- Verificación post-corrección
-- ====================================================

SELECT 
    'Verificación: Mapeos activos por rol' as check_name,
    m.component_role,
    COUNT(*) as mapping_count,
    STRING_AGG(ci.sku, ', ') as skus
FROM "BomRoleSkuMapping" m
JOIN "CatalogItems" ci ON ci.id = m.catalog_item_id
WHERE m.deleted = false
    AND m.active = true
    AND m.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
GROUP BY m.component_role
ORDER BY m.component_role;

