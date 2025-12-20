-- ====================================================
-- Migration 126: Diagnose ProductTypes and CatalogItemProductTypes relations
-- ====================================================
-- This script helps diagnose why only "Roller Shade" is showing up
-- ====================================================

DO $$
DECLARE
    v_org_id UUID;
    v_product_type_count INTEGER;
    v_relation_count INTEGER;
    v_catalog_item_count INTEGER;
    v_product_type_rec RECORD;
    v_relation_rec RECORD;
BEGIN
    RAISE NOTICE '🔍 DIAGNOSTIC: ProductTypes and Relations';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    
    -- Get the first organization
    SELECT id INTO v_org_id
    FROM "Organizations"
    WHERE deleted = false
    LIMIT 1;
    
    IF v_org_id IS NULL THEN
        RAISE NOTICE '❌ No organization found.';
        RETURN;
    END IF;
    
    RAISE NOTICE '📋 Organization ID: %', v_org_id;
    RAISE NOTICE '';
    
    -- Count ProductTypes
    SELECT COUNT(*) INTO v_product_type_count
    FROM "ProductTypes"
    WHERE organization_id = v_org_id
      AND deleted = false;
    
    RAISE NOTICE '📊 ProductTypes Summary:';
    RAISE NOTICE '   Total ProductTypes: %', v_product_type_count;
    RAISE NOTICE '';
    
    -- List all ProductTypes
    RAISE NOTICE '📋 All ProductTypes:';
    FOR v_product_type_rec IN
        SELECT id, name, code, archived, deleted, created_at
        FROM "ProductTypes"
        WHERE organization_id = v_org_id
          AND deleted = false
        ORDER BY name
    LOOP
        RAISE NOTICE '   - ID: %', v_product_type_rec.id;
        RAISE NOTICE '     Name: "%"', v_product_type_rec.name;
        RAISE NOTICE '     Code: "%"', COALESCE(v_product_type_rec.code, 'NULL');
        RAISE NOTICE '     Archived: %', v_product_type_rec.archived;
        RAISE NOTICE '';
    END LOOP;
    
    -- Count CatalogItemProductTypes relations
    SELECT COUNT(*) INTO v_relation_count
    FROM "CatalogItemProductTypes"
    WHERE organization_id = v_org_id
      AND deleted = false;
    
    RAISE NOTICE '📊 CatalogItemProductTypes Relations Summary:';
    RAISE NOTICE '   Total Relations: %', v_relation_count;
    RAISE NOTICE '';
    
    -- Count CatalogItems with fabric
    SELECT COUNT(*) INTO v_catalog_item_count
    FROM "CatalogItems"
    WHERE organization_id = v_org_id
      AND deleted = false
      AND is_fabric = true
      AND collection_name IS NOT NULL
      AND variant_name IS NOT NULL;
    
    RAISE NOTICE '📊 CatalogItems with Fabric:';
    RAISE NOTICE '   Total Fabric Items: %', v_catalog_item_count;
    RAISE NOTICE '';
    
    -- List relations grouped by ProductType
    RAISE NOTICE '📋 Relations by ProductType:';
    FOR v_product_type_rec IN
        SELECT pt.id, pt.name, COUNT(cpt.id) as relation_count
        FROM "ProductTypes" pt
        LEFT JOIN "CatalogItemProductTypes" cpt 
            ON pt.id = cpt.product_type_id 
            AND cpt.organization_id = pt.organization_id
            AND cpt.deleted = false
        WHERE pt.organization_id = v_org_id
          AND pt.deleted = false
        GROUP BY pt.id, pt.name
        ORDER BY pt.name
    LOOP
        RAISE NOTICE '   - ProductType: "%" (ID: %)', v_product_type_rec.name, v_product_type_rec.id;
        RAISE NOTICE '     Relations: %', v_product_type_rec.relation_count;
        RAISE NOTICE '';
    END LOOP;
    
    -- Show sample relations
    RAISE NOTICE '📋 Sample Relations (first 10):';
    FOR v_relation_rec IN
        SELECT 
            cpt.id,
            cpt.catalog_item_id,
            cpt.product_type_id,
            pt.name as product_type_name,
            ci.sku,
            ci.collection_name,
            ci.variant_name,
            ci.family,
            cpt.is_primary
        FROM "CatalogItemProductTypes" cpt
        INNER JOIN "ProductTypes" pt ON cpt.product_type_id = pt.id
        INNER JOIN "CatalogItems" ci ON cpt.catalog_item_id = ci.id
        WHERE cpt.organization_id = v_org_id
          AND cpt.deleted = false
        ORDER BY pt.name, ci.sku
        LIMIT 10
    LOOP
        RAISE NOTICE '   - SKU: "%" → ProductType: "%" (Primary: %)', 
            v_relation_rec.sku, 
            v_relation_rec.product_type_name,
            v_relation_rec.is_primary;
        RAISE NOTICE '     Collection: "%", Variant: "%", Family: "%"', 
            COALESCE(v_relation_rec.collection_name, 'NULL'),
            COALESCE(v_relation_rec.variant_name, 'NULL'),
            COALESCE(v_relation_rec.family, 'NULL');
        RAISE NOTICE '';
    END LOOP;
    
    -- Check for CatalogItems with family but no relation
    RAISE NOTICE '📋 CatalogItems with family but NO relation in CatalogItemProductTypes:';
    FOR v_relation_rec IN
        SELECT 
            ci.id,
            ci.sku,
            ci.family,
            ci.collection_name,
            ci.variant_name,
            ci.is_fabric
        FROM "CatalogItems" ci
        LEFT JOIN "CatalogItemProductTypes" cpt 
            ON ci.id = cpt.catalog_item_id 
            AND ci.organization_id = cpt.organization_id
            AND cpt.deleted = false
        WHERE ci.organization_id = v_org_id
          AND ci.deleted = false
          AND ci.family IS NOT NULL
          AND ci.family != ''
          AND cpt.id IS NULL
        ORDER BY ci.family, ci.sku
        LIMIT 10
    LOOP
        RAISE NOTICE '   - SKU: "%", Family: "%" (Fabric: %)', 
            v_relation_rec.sku, 
            v_relation_rec.family,
            v_relation_rec.is_fabric;
        RAISE NOTICE '     Collection: "%", Variant: "%"', 
            COALESCE(v_relation_rec.collection_name, 'NULL'),
            COALESCE(v_relation_rec.variant_name, 'NULL');
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '✅ Diagnostic complete';
    RAISE NOTICE '====================================================';
END $$;


