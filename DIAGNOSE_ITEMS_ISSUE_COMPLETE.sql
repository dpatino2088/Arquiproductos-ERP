-- ============================================================================
-- DIAGNÓSTICO COMPLETO DEL PROBLEMA DE ITEMS NO VISIBLES
-- ============================================================================

-- 1. Verificar datos exactos de RCA-04-A y RCA-04-W
SELECT 
    '1. DATOS EXACTOS' as paso,
    ci.id,
    ci.sku,
    ci.item_name,
    LENGTH(ci.item_name) as item_name_length,
    ci.organization_id,
    ci.active,
    ci.deleted,
    ci.archived,
    ci.item_type,
    ci.measure_basis,
    ci.uom,
    ci.metadata,
    ci.created_at,
    ci.updated_at
FROM "CatalogItems" ci
WHERE ci.sku IN ('RCA-04-A', 'RCA-04-W')
ORDER BY ci.sku;

-- 2. Verificar si hay diferencias en campos NULL o vacíos
SELECT 
    '2. ANÁLISIS NULL/EMPTY' as paso,
    ci.sku,
    CASE WHEN ci.item_name IS NULL THEN 'NULL'
         WHEN ci.item_name = '' THEN 'EMPTY'
         ELSE 'HAS VALUE' END as item_name_status,
    CASE WHEN ci.metadata IS NULL THEN 'NULL'
         WHEN ci.metadata::text = '{}' THEN 'EMPTY OBJECT'
         ELSE 'HAS DATA' END as metadata_status,
    ci.active,
    ci.deleted,
    ci.archived
FROM "CatalogItems" ci
WHERE ci.sku IN ('RCA-04-A', 'RCA-04-W')
ORDER BY ci.sku;

-- 3. Verificar organization_id coincide
SELECT 
    '3. ORGANIZATION_ID MATCH' as paso,
    ci.sku,
    ci.organization_id,
    o.organization_name,
    CASE WHEN ci.organization_id = (SELECT organization_id FROM "CatalogItems" WHERE sku = 'RCA-04-A' LIMIT 1)
         THEN 'MATCHES'
         ELSE 'DIFFERENT' END as org_match
FROM "CatalogItems" ci
LEFT JOIN "Organizations" o ON o.id = ci.organization_id
WHERE ci.sku IN ('RCA-04-A', 'RCA-04-W')
ORDER BY ci.sku;

-- 4. Simular EXACTAMENTE la query del hook
DO $$
DECLARE
    v_org_id UUID;
    v_count_total INT;
    v_count_rca04a INT;
    v_count_rca04w INT;
BEGIN
    -- Obtener el organization_id de RCA-04-A
    SELECT organization_id INTO v_org_id
    FROM "CatalogItems"
    WHERE sku = 'RCA-04-A'
    LIMIT 1;
    
    RAISE NOTICE '═══════════════════════════════════════════';
    RAISE NOTICE '4. SIMULACIÓN QUERY HOOK';
    RAISE NOTICE '═══════════════════════════════════════════';
    RAISE NOTICE 'Organization ID: %', v_org_id;
    
    -- Contar total de items con los filtros del hook
    SELECT COUNT(*) INTO v_count_total
    FROM "CatalogItems"
    WHERE organization_id = v_org_id
      AND deleted = false;
    
    RAISE NOTICE 'Total items (org_id + deleted=false): %', v_count_total;
    
    -- Verificar RCA-04-A
    SELECT COUNT(*) INTO v_count_rca04a
    FROM "CatalogItems"
    WHERE organization_id = v_org_id
      AND deleted = false
      AND sku = 'RCA-04-A';
    
    RAISE NOTICE 'RCA-04-A found: %', CASE WHEN v_count_rca04a > 0 THEN 'YES ✓' ELSE 'NO ✗' END;
    
    -- Verificar RCA-04-W
    SELECT COUNT(*) INTO v_count_rca04w
    FROM "CatalogItems"
    WHERE organization_id = v_org_id
      AND deleted = false
      AND sku = 'RCA-04-W';
    
    RAISE NOTICE 'RCA-04-W found: %', CASE WHEN v_count_rca04w > 0 THEN 'YES ✓' ELSE 'NO ✗' END;
    
    IF v_count_rca04w = 0 THEN
        RAISE NOTICE '═══════════════════════════════════════════';
        RAISE NOTICE '⚠️ RCA-04-W NO CUMPLE CON LOS FILTROS DEL HOOK';
        RAISE NOTICE '═══════════════════════════════════════════';
        
        -- Verificar qué está mal
        PERFORM 1 FROM "CatalogItems"
        WHERE sku = 'RCA-04-W' AND organization_id != v_org_id;
        
        IF FOUND THEN
            RAISE NOTICE '❌ PROBLEMA: organization_id diferente';
        END IF;
        
        PERFORM 1 FROM "CatalogItems"
        WHERE sku = 'RCA-04-W' AND deleted = true;
        
        IF FOUND THEN
            RAISE NOTICE '❌ PROBLEMA: deleted = true';
        END IF;
    END IF;
    
    RAISE NOTICE '═══════════════════════════════════════════';
END $$;

-- 5. Comparar TODOS los campos entre RCA-04-A y RCA-04-W
SELECT 
    '5. COMPARACIÓN COMPLETA' as paso,
    'RCA-04-A' as item,
    *
FROM "CatalogItems"
WHERE sku = 'RCA-04-A'
UNION ALL
SELECT 
    '5. COMPARACIÓN COMPLETA' as paso,
    'RCA-04-W' as item,
    *
FROM "CatalogItems"
WHERE sku = 'RCA-04-W'
ORDER BY item;

-- 6. Verificar si el item_name tiene caracteres extraños
SELECT 
    '6. CARACTERES ESPECIALES' as paso,
    ci.sku,
    ci.item_name,
    LENGTH(ci.item_name) as length,
    ascii(substring(ci.item_name from 1 for 1)) as first_char_ascii,
    encode(ci.item_name::bytea, 'hex') as hex_representation
FROM "CatalogItems" ci
WHERE ci.sku IN ('RCA-04-A', 'RCA-04-W')
ORDER BY ci.sku;








