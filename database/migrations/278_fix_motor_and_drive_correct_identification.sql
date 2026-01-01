-- ====================================================
-- Migration 278: Fix Motor and Drive Correct Identification
-- ====================================================
-- Corrige los mapeos:
-- - RC3045 es adaptador, NO operating_system_drive
-- - RC3164 es crown del motor, NO el motor
-- - Busca el motor real (CM-01, etc.)
-- - Busca el operating_system_drive real (drive belt/plug)
-- ====================================================

BEGIN;

DO $$
DECLARE
    v_roller_shade_product_type_id uuid;
    v_organization_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid;
    v_motor_id uuid;
    v_drive_id uuid;
    v_row_count integer;
    v_crown_id uuid;
    v_crown_sku text;
    v_crown_name text;
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
    
    RAISE NOTICE E'✅ Found Roller Shade product_type_id: %', v_roller_shade_product_type_id;
    
    -- ====================================================
    -- STEP 1: Desactivar mapeo incorrecto de operating_system_drive (RC3045 es adaptador)
    -- ====================================================
    
    UPDATE "BomRoleSkuMapping"
    SET active = false, updated_at = now()
    WHERE component_role = 'operating_system_drive'
        AND product_type_id = v_roller_shade_product_type_id
        AND catalog_item_id IN (
            SELECT id FROM "CatalogItems"
            WHERE sku ILIKE 'RC3045%'
        );
    
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count > 0 THEN
        RAISE NOTICE E'✅ Desactivado mapeo incorrecto de operating_system_drive (RC3045 es adaptador): % filas', v_row_count;
    END IF;
    
    -- ====================================================
    -- STEP 2: Desactivar mapeo incorrecto de motor (RC3164 es crown, no motor)
    -- ====================================================
    
    UPDATE "BomRoleSkuMapping"
    SET active = false, updated_at = now()
    WHERE component_role = 'motor'
        AND product_type_id = v_roller_shade_product_type_id
        AND catalog_item_id IN (
            SELECT id FROM "CatalogItems"
            WHERE sku ILIKE 'RC3164%'
        );
    
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count > 0 THEN
        RAISE NOTICE E'✅ Desactivado mapeo incorrecto de motor (RC3164 es crown): % filas', v_row_count;
    END IF;
    
    -- ====================================================
    -- STEP 3: Buscar motor real (CM-09 para standard_m, CM-10 para standard_l)
    -- ====================================================
    
    -- Buscar motor para standard_m (CM-09 es típico para standard_m)
    SELECT ci.id INTO v_motor_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND cipt.deleted = false
        AND ci.sku ILIKE 'CM-09%'  -- CM-09 para standard_m
        AND NOT (ci.sku ILIKE 'RC%' OR ci.item_name ILIKE '%CROWN%' OR ci.item_name ILIKE '%ADAPTER%')
    ORDER BY ci.created_at DESC
    LIMIT 1;
    
    -- Si no encuentra CM-09, buscar cualquier CM- para standard_m
    IF v_motor_id IS NULL THEN
        SELECT ci.id INTO v_motor_id
        FROM "CatalogItems" ci
        JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
        WHERE ci.organization_id = v_organization_id
            AND ci.deleted = false
            AND cipt.product_type_id = v_roller_shade_product_type_id
            AND cipt.deleted = false
            AND ci.sku ILIKE 'CM-%'
            AND NOT (ci.sku ILIKE 'RC%' OR ci.item_name ILIKE '%CROWN%' OR ci.item_name ILIKE '%ADAPTER%')
        ORDER BY 
            CASE WHEN ci.sku ILIKE 'CM-09%' THEN 0
                 WHEN ci.sku ILIKE 'CM-10%' THEN 1
                 ELSE 2 END,
            ci.created_at DESC
        LIMIT 1;
    END IF;
    
    IF v_motor_id IS NOT NULL THEN
        -- Verificar si ya existe un mapeo activo para este motor
        IF NOT EXISTS (
            SELECT 1 FROM "BomRoleSkuMapping"
            WHERE component_role = 'motor'
                AND product_type_id = v_roller_shade_product_type_id
                AND catalog_item_id = v_motor_id
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
                'motor',
                'standard_m',
                v_motor_id,
                10
            )
            ON CONFLICT DO NOTHING;
            
            -- Obtener SKU para el mensaje
            SELECT sku INTO v_crown_sku FROM "CatalogItems" WHERE id = v_motor_id;
            IF v_crown_sku IS NOT NULL THEN
                RAISE NOTICE E'✅ Creado mapeo correcto para motor (standard_m): %', v_crown_sku;
            ELSE
                RAISE NOTICE E'✅ Creado mapeo correcto para motor (standard_m)';
            END IF;
        ELSE
            RAISE NOTICE E'ℹ️  Mapeo de motor ya existe para este SKU';
        END IF;
    ELSE
        RAISE WARNING E'⚠️  No se encontró un motor real (CM-%%, MOTOR%%) vinculado a Roller Shade';
    END IF;
    
    -- ====================================================
    -- STEP 4: Buscar operating_system_drive real (drive belt/plug, NO adaptadores)
    -- ====================================================
    
    SELECT ci.id INTO v_drive_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND cipt.deleted = false
        AND (
            ci.item_name ILIKE '%DRIVE%PLUG%' OR
            ci.item_name ILIKE '%DRIVE%BELT%' OR
            (ci.item_name ILIKE '%DRIVE%' AND NOT ci.item_name ILIKE '%ADAPTER%' AND NOT ci.item_name ILIKE '%TOOL%')
        )
        AND NOT (ci.sku ILIKE 'M-CC-%' OR ci.sku ILIKE 'RC%' OR ci.item_name ILIKE '%MEASUREMENT%' OR ci.item_name ILIKE '%TOOL%' OR ci.item_name ILIKE '%ADAPTER%')
    ORDER BY 
        CASE WHEN ci.item_name ILIKE '%DRIVE%PLUG%' THEN 0 
             WHEN ci.item_name ILIKE '%DRIVE%BELT%' THEN 1 
             ELSE 2 END,
        ci.created_at DESC
    LIMIT 1;
    
    IF v_drive_id IS NOT NULL THEN
        -- Verificar si ya existe un mapeo activo
        IF NOT EXISTS (
            SELECT 1 FROM "BomRoleSkuMapping"
            WHERE component_role = 'operating_system_drive'
                AND product_type_id = v_roller_shade_product_type_id
                AND catalog_item_id = v_drive_id
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
                v_drive_id,
                10
            )
            ON CONFLICT DO NOTHING;
            
            RAISE NOTICE E'✅ Creado mapeo correcto para operating_system_drive (standard_m)';
        ELSE
            RAISE NOTICE E'ℹ️  Mapeo de operating_system_drive ya existe para este SKU';
        END IF;
    ELSE
        RAISE WARNING E'⚠️  No se encontró un operating_system_drive válido (drive plug/belt, excluyendo adaptadores)';
    END IF;
    
    -- ====================================================
    -- STEP 5: Verificar si RC3164 debería ser motor_crown (nuevo rol si es necesario)
    -- ====================================================
    
    -- Por ahora solo verificamos, no creamos un nuevo rol sin confirmación
    SELECT ci.id, ci.sku, ci.item_name INTO v_crown_id, v_crown_sku, v_crown_name
    FROM "CatalogItems" ci
    WHERE ci.sku ILIKE 'RC3164%'
    LIMIT 1;
    
    IF v_crown_id IS NOT NULL THEN
        RAISE NOTICE E'ℹ️  RC3164 encontrado: % - % (es crown del motor, no el motor mismo)', v_crown_sku, v_crown_name;
        RAISE NOTICE E'   Si necesitas mapear el crown como componente separado, considera crear un rol "motor_crown"';
    END IF;
    
    RAISE NOTICE E'✅ Corrección de motor y drive completada';
    
END $$;

COMMIT;

-- ====================================================
-- Verificación post-corrección
-- ====================================================

-- Verificar mapeos de motor
SELECT 
    'Verificación: Motor mapeos' as check_name,
    m.component_role,
    ci.sku,
    ci.item_name,
    m.operating_system_variant,
    m.priority
FROM "BomRoleSkuMapping" m
JOIN "CatalogItems" ci ON ci.id = m.catalog_item_id
WHERE m.deleted = false
    AND m.active = true
    AND m.component_role = 'motor'
    AND m.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
ORDER BY m.priority, m.operating_system_variant;

-- Verificar mapeos de operating_system_drive
SELECT 
    'Verificación: Operating System Drive mapeos' as check_name,
    m.component_role,
    ci.sku,
    ci.item_name,
    m.operating_system_variant,
    m.priority
FROM "BomRoleSkuMapping" m
JOIN "CatalogItems" ci ON ci.id = m.catalog_item_id
WHERE m.deleted = false
    AND m.active = true
    AND m.component_role = 'operating_system_drive'
    AND m.product_type_id = '318a8c9a-da17-43c4-925e-4f6dec6c7596'::uuid
ORDER BY m.priority, m.operating_system_variant;

-- Verificar todos los mapeos activos
SELECT 
    'Verificación: Todos los mapeos activos' as check_name,
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

