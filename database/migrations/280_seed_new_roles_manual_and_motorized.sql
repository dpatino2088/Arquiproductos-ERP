-- ====================================================
-- Migration 280: Seed New Roles for Manual and Motorized
-- ====================================================
-- Seeds mappings for:
-- - Manual: chain, chain_stop, operating_system_drive (RC3001/RC3002/RC3003)
-- - Motorized: motor_crown (RC3164), motor_accessory (RC3045)
-- - Both: bracket_cover (RC3007 + RC3008)
-- ====================================================

BEGIN;

DO $$
DECLARE
    v_roller_shade_product_type_id uuid;
    v_organization_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid;
    v_catalog_item_id uuid;
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
    -- STEP 1: Seed operating_system_drive for manual (RC3001, RC3002, RC3003)
    -- ====================================================
    
    -- RC3001 (1:1 gear ratio)
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND cipt.deleted = false
        AND ci.sku ILIKE 'RC3001%'
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
            'operating_system_drive',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE E'✅ Seeded operating_system_drive RC3001 mapping';
    END IF;
    
    -- RC3002 (1:1.5 gear ratio)
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND cipt.deleted = false
        AND ci.sku ILIKE 'RC3002%'
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
            'operating_system_drive',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE E'✅ Seeded operating_system_drive RC3002 mapping';
    END IF;
    
    -- RC3003 (1:3 gear ratio)
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND cipt.deleted = false
        AND ci.sku ILIKE 'RC3003%'
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
            'operating_system_drive',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE E'✅ Seeded operating_system_drive RC3003 mapping';
    END IF;
    
    -- ====================================================
    -- STEP 2: Seed chain for manual (V15DP, RB.., V15M, RB..M)
    -- ====================================================
    
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND cipt.deleted = false
        AND (ci.sku ILIKE 'V15%' OR ci.sku ILIKE 'RB%' OR ci.item_name ILIKE '%CHAIN%')
    ORDER BY 
        CASE WHEN ci.sku ILIKE 'V15%' THEN 0 ELSE 1 END,
        ci.created_at DESC
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
            'chain',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE E'✅ Seeded chain mapping';
    END IF;
    
    -- ====================================================
    -- STEP 3: Seed chain_stop (topes de cadena, 2 per curtain)
    -- ====================================================
    
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND cipt.deleted = false
        AND (ci.sku ILIKE '%CHAIN%STOP%' OR ci.item_name ILIKE '%CHAIN%STOP%' OR ci.item_name ILIKE '%TOPE%CADENA%')
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
            'chain_stop',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE E'✅ Seeded chain_stop mapping';
    END IF;
    
    -- ====================================================
    -- STEP 4: Seed motor_crown (RC3164 - always with motor)
    -- ====================================================
    
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND cipt.deleted = false
        AND ci.sku ILIKE 'RC3164%'
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
            'motor_crown',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE E'✅ Seeded motor_crown (RC3164) mapping';
    END IF;
    
    -- ====================================================
    -- STEP 5: Seed motor_accessory (RC3045 - fixed accessory of motor)
    -- ====================================================
    
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND cipt.deleted = false
        AND ci.sku ILIKE 'RC3045%'
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
            'motor_accessory',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE E'✅ Seeded motor_accessory (RC3045) mapping';
    END IF;
    
    -- ====================================================
    -- STEP 6: Seed bracket_cover (RC3007 + RC3008 - decorative covers for RC3006)
    -- ====================================================
    
    -- RC3007
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND cipt.deleted = false
        AND ci.sku ILIKE 'RC3007%'
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
            'bracket_cover',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE E'✅ Seeded bracket_cover RC3007 mapping';
    END IF;
    
    -- RC3008 (if different from RC3007)
    SELECT ci.id INTO v_catalog_item_id
    FROM "CatalogItems" ci
    JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
    WHERE ci.organization_id = v_organization_id
        AND ci.deleted = false
        AND cipt.product_type_id = v_roller_shade_product_type_id
        AND cipt.deleted = false
        AND ci.sku ILIKE 'RC3008%'
        AND NOT EXISTS (
            SELECT 1 FROM "BomRoleSkuMapping"
            WHERE component_role = 'bracket_cover'
                AND catalog_item_id = ci.id
                AND deleted = false
        )
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
            'bracket_cover',
            v_catalog_item_id,
            10
        )
        ON CONFLICT DO NOTHING;
        RAISE NOTICE E'✅ Seeded bracket_cover RC3008 mapping';
    END IF;
    
    RAISE NOTICE E'✅ Completed seeding new roles for manual and motorized';
    
END $$;

COMMIT;


