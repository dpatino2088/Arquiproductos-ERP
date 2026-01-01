-- ====================================================
-- FIX CATALOGITEM-PRODUCTTYPE LINKS
-- ====================================================
-- Crea links entre CatalogItems y ProductTypes basándose en family
-- IDEMPOTENTE: Se puede ejecutar múltiples veces
-- ====================================================

DO $$
DECLARE
    v_org_id UUID;
    v_links_created INTEGER := 0;
BEGIN
    -- Obtener organization_id
    SELECT id INTO v_org_id
    FROM "Organizations"
    WHERE deleted = false
    LIMIT 1;
    
    IF v_org_id IS NULL THEN
        RAISE NOTICE '❌ No se encontró ninguna organización';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Organization: %', v_org_id;
    RAISE NOTICE '';
    RAISE NOTICE 'Creando links CatalogItems → ProductTypes...';
    
    -- Crear links basados en family
    INSERT INTO "CatalogItemProductTypes" (
        catalog_item_id,
        product_type_id,
        organization_id,
        is_primary,
        deleted,
        created_at,
        updated_at
    )
    SELECT DISTINCT
        ci.id as catalog_item_id,
        pt.id as product_type_id,
        ci.organization_id,
        true as is_primary,
        false as deleted,
        NOW() as created_at,
        NOW() as updated_at
    FROM "CatalogItems" ci
    INNER JOIN "ProductTypes" pt ON (
        pt.organization_id = ci.organization_id
        AND pt.deleted = false
        AND (
            -- Mapeo family → ProductType.code
            (ci.family = 'Roller Shade' AND pt.code = 'ROLLER')
            OR (ci.family = 'Dual Shade' AND pt.code = 'DUAL')
            OR (ci.family = 'Triple Shade' AND pt.code = 'TRIPLE')
            OR (ci.family = 'Drapery' AND pt.code = 'DRAPERY')
            OR (ci.family = 'Awning' AND pt.code = 'AWNING')
            OR (ci.family = 'Window Film' AND pt.code = 'FILM')
            OR (ci.family = 'Accessories' AND pt.code = 'ACCESSORIES')
            -- Mapeo case-insensitive como fallback
            OR (LOWER(TRIM(ci.family)) = LOWER(TRIM(pt.name)))
        )
    )
    WHERE ci.organization_id = v_org_id
      AND ci.deleted = false
      AND ci.family IS NOT NULL
      AND ci.family != ''
      AND NOT EXISTS (
          SELECT 1 FROM "CatalogItemProductTypes" cipt
          WHERE cipt.catalog_item_id = ci.id
            AND cipt.product_type_id = pt.id
            AND cipt.organization_id = ci.organization_id
      )
    ON CONFLICT (catalog_item_id, product_type_id, organization_id) DO NOTHING;
    
    GET DIAGNOSTICS v_links_created = ROW_COUNT;
    RAISE NOTICE '✅ Links creados: %', v_links_created;
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'MIGRACIÓN COMPLETADA';
    RAISE NOTICE '====================================================';
    
END $$;

-- ====================================================
-- VERIFICACIÓN: Ver resultados por ProductType
-- ====================================================

SELECT 
    pt.code,
    pt.name,
    COUNT(DISTINCT cipt.catalog_item_id) as total_items,
    COUNT(DISTINCT CASE WHEN ci.is_fabric = true THEN cipt.catalog_item_id END) as fabric_items,
    COUNT(DISTINCT CASE WHEN ci.is_fabric = true AND ci.collection_name IS NOT NULL THEN ci.collection_name END) as fabric_collections
FROM "ProductTypes" pt
LEFT JOIN "CatalogItemProductTypes" cipt ON (
    cipt.product_type_id = pt.id 
    AND cipt.organization_id = pt.organization_id
    AND cipt.deleted = false
)
LEFT JOIN "CatalogItems" ci ON (
    ci.id = cipt.catalog_item_id
    AND ci.deleted = false
)
WHERE pt.organization_id = '4de856e8-36ce-480a-952b-a2f5c83d6341'
  AND pt.deleted = false
GROUP BY pt.id, pt.code, pt.name
ORDER BY pt.code;
