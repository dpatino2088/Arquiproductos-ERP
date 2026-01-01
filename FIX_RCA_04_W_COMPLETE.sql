-- ============================================================================
-- CORREGIR RCA-04-W PARA QUE APAREZCA EN LA UI
-- ============================================================================

DO $$
DECLARE
    v_item_id UUID;
    v_correct_org_id UUID;
    v_current_org_id UUID;
    v_item_exists BOOLEAN;
BEGIN
    RAISE NOTICE '🔍 Buscando RCA-04-W...';
    
    -- 1. Verificar si el item existe
    SELECT id, organization_id INTO v_item_id, v_current_org_id
    FROM "CatalogItems"
    WHERE sku = 'RCA-04-W'
    LIMIT 1;
    
    v_item_exists := (v_item_id IS NOT NULL);
    
    IF NOT v_item_exists THEN
        RAISE NOTICE '❌ Item RCA-04-W NO EXISTE en la base de datos';
        RAISE NOTICE '   Necesitas crear el item primero';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Item encontrado: id=%, organization_id=%', v_item_id, v_current_org_id;
    
    -- 2. Obtener el organization_id correcto (el mismo que RCA-04-A)
    SELECT ci.organization_id INTO v_correct_org_id
    FROM "CatalogItems" ci
    WHERE ci.sku = 'RCA-04-A'
        AND ci.deleted = false
        AND ci.organization_id IS NOT NULL
    LIMIT 1;
    
    IF v_correct_org_id IS NULL THEN
        RAISE NOTICE '⚠️ No se encontró RCA-04-A para obtener organization_id';
        -- Intentar obtener el organization_id más común
        SELECT ci.organization_id INTO v_correct_org_id
        FROM "CatalogItems" ci
        WHERE ci.sku LIKE 'RCA-%'
            AND ci.deleted = false
            AND ci.organization_id IS NOT NULL
        GROUP BY ci.organization_id
        ORDER BY COUNT(*) DESC
        LIMIT 1;
    END IF;
    
    IF v_correct_org_id IS NULL THEN
        RAISE NOTICE '❌ No se pudo determinar organization_id correcto';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Organization_id correcto: %', v_correct_org_id;
    
    -- 3. Corregir el item
    UPDATE "CatalogItems"
    SET 
        organization_id = v_correct_org_id,
        deleted = false,
        archived = false,
        active = true,
        updated_at = NOW()
    WHERE id = v_item_id;
    
    RAISE NOTICE '✅ Item RCA-04-W corregido:';
    RAISE NOTICE '   - organization_id: % → %', v_current_org_id, v_correct_org_id;
    RAISE NOTICE '   - deleted: false';
    RAISE NOTICE '   - archived: false';
    RAISE NOTICE '   - active: true';
    
    RAISE NOTICE '✅ Verificación completada';
END $$;

-- 5. Mostrar resultado final
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

-- 6. Comparar con RCA-04-A (que SÍ aparece)
SELECT 
    'COMPARACIÓN CON RCA-04-A' as paso,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    o.organization_name,
    ci.active,
    ci.deleted,
    ci.archived
FROM "CatalogItems" ci
LEFT JOIN "Organizations" o ON o.id = ci.organization_id
WHERE ci.sku IN ('RCA-04-A', 'RCA-04-W')
ORDER BY ci.sku;

