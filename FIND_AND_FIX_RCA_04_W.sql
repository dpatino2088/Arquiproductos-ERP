-- ============================================================================
-- ENCONTRAR Y CORREGIR RCA-04-W PARA QUE APAREZCA EN LA UI
-- ============================================================================

-- 1. Verificar estado actual de RCA-04-W
SELECT 
    'ESTADO ACTUAL' as paso,
    ci.id,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    o.organization_name,
    ci.active,
    ci.deleted,
    ci.archived,
    ci.updated_at,
    CASE 
        WHEN ci.deleted = true THEN '❌ ELIMINADO'
        WHEN ci.archived = true THEN '⚠️ ARCHIVADO'
        WHEN ci.active = false THEN '⚠️ INACTIVO'
        WHEN ci.organization_id IS NULL THEN '⚠️ SIN organization_id'
        ELSE '✅ DEBERÍA APARECER'
    END as status
FROM "CatalogItems" ci
LEFT JOIN "Organizations" o ON o.id = ci.organization_id
WHERE ci.sku = 'RCA-04-W';

-- 2. Verificar organization_id más común para items RCA
SELECT 
    'ORGANIZATION_ID MÁS COMÚN' as paso,
    ci.organization_id,
    o.organization_name,
    COUNT(*) as item_count
FROM "CatalogItems" ci
LEFT JOIN "Organizations" o ON o.id = ci.organization_id
WHERE ci.sku LIKE 'RCA-%'
    AND ci.deleted = false
GROUP BY ci.organization_id, o.organization_name
ORDER BY item_count DESC
LIMIT 1;

-- 3. Corregir RCA-04-W para que tenga el mismo organization_id que otros items RCA
DO $$
DECLARE
    v_correct_org_id UUID;
    v_current_org_id UUID;
    v_item_id UUID;
BEGIN
    -- Obtener el organization_id más común para items RCA
    SELECT ci.organization_id INTO v_correct_org_id
    FROM "CatalogItems" ci
    WHERE ci.sku LIKE 'RCA-%'
        AND ci.deleted = false
        AND ci.organization_id IS NOT NULL
    GROUP BY ci.organization_id
    ORDER BY COUNT(*) DESC
    LIMIT 1;
    
    IF v_correct_org_id IS NULL THEN
        RAISE NOTICE '⚠️ No se encontró organization_id común para items RCA';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Organization_id correcto encontrado: %', v_correct_org_id;
    
    -- Obtener el organization_id actual de RCA-04-W
    SELECT ci.id, ci.organization_id INTO v_item_id, v_current_org_id
    FROM "CatalogItems" ci
    WHERE ci.sku = 'RCA-04-W'
    LIMIT 1;
    
    IF v_item_id IS NULL THEN
        RAISE NOTICE '❌ Item RCA-04-W no encontrado';
        RETURN;
    END IF;
    
    RAISE NOTICE '📋 Item encontrado: id=%, organization_id actual=%', v_item_id, v_current_org_id;
    
    -- Si el organization_id es diferente, corregirlo
    IF v_current_org_id IS DISTINCT FROM v_correct_org_id THEN
        RAISE NOTICE '🔧 Corrigiendo organization_id de % a %', v_current_org_id, v_correct_org_id;
        
        UPDATE "CatalogItems"
        SET 
            organization_id = v_correct_org_id,
            deleted = false,
            archived = false,
            active = true,
            updated_at = NOW()
        WHERE id = v_item_id;
        
        RAISE NOTICE '✅ Item corregido';
    ELSE
        RAISE NOTICE '✅ Organization_id ya es correcto';
    END IF;
    
    -- Asegurar que no esté eliminado o archivado
    UPDATE "CatalogItems"
    SET 
        deleted = false,
        archived = false,
        active = true,
        updated_at = NOW()
    WHERE id = v_item_id
        AND (deleted = true OR archived = true OR active = false);
    
    RAISE NOTICE '✅ Estado del item verificado y corregido si era necesario';
END $$;

-- 4. Verificar resultado final
SELECT 
    'RESULTADO FINAL' as paso,
    ci.id,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    o.organization_name,
    ci.active,
    ci.deleted,
    ci.archived,
    ci.updated_at,
    CASE 
        WHEN ci.deleted = true THEN '❌ ELIMINADO'
        WHEN ci.archived = true THEN '⚠️ ARCHIVADO'
        WHEN ci.active = false THEN '⚠️ INACTIVO'
        WHEN ci.organization_id IS NULL THEN '⚠️ SIN organization_id'
        ELSE '✅ DEBERÍA APARECER EN UI'
    END as status
FROM "CatalogItems" ci
LEFT JOIN "Organizations" o ON o.id = ci.organization_id
WHERE ci.sku = 'RCA-04-W';








