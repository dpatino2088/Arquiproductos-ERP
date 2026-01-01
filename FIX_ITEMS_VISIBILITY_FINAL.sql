-- ============================================================================
-- FIX FINAL: Asegurar que RCA-04-W sea idéntico a RCA-04-A en todos los campos críticos
-- ============================================================================

DO $$
DECLARE
    v_rca04a RECORD;
    v_rca04w_id UUID;
    v_org_id UUID;
BEGIN
    RAISE NOTICE '═══════════════════════════════════════════';
    RAISE NOTICE 'FIX FINAL: Sincronizar RCA-04-W con RCA-04-A';
    RAISE NOTICE '═══════════════════════════════════════════';
    
    -- 1. Obtener datos de RCA-04-A
    SELECT * INTO v_rca04a
    FROM "CatalogItems"
    WHERE sku = 'RCA-04-A'
    LIMIT 1;
    
    IF v_rca04a.id IS NULL THEN
        RAISE NOTICE '❌ RCA-04-A no encontrado';
        RETURN;
    END IF;
    
    v_org_id := v_rca04a.organization_id;
    RAISE NOTICE '✅ RCA-04-A encontrado: id=%, org_id=%', v_rca04a.id, v_org_id;
    
    -- 2. Obtener ID de RCA-04-W
    SELECT id INTO v_rca04w_id
    FROM "CatalogItems"
    WHERE sku = 'RCA-04-W'
    LIMIT 1;
    
    IF v_rca04w_id IS NULL THEN
        RAISE NOTICE '❌ RCA-04-W no encontrado';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ RCA-04-W encontrado: id=%', v_rca04w_id;
    
    -- 3. Sincronizar RCA-04-W con RCA-04-A (todos los campos críticos)
    UPDATE "CatalogItems"
    SET 
        organization_id = v_org_id,
        active = v_rca04a.active,
        deleted = false,  -- Asegurar que NO esté eliminado
        archived = false, -- Asegurar que NO esté archivado
        discontinued = v_rca04a.discontinued,
        item_type = v_rca04a.item_type,
        measure_basis = v_rca04a.measure_basis,
        uom = v_rca04a.uom,
        is_fabric = v_rca04a.is_fabric,
        updated_at = NOW()
    WHERE id = v_rca04w_id;
    
    RAISE NOTICE '✅ RCA-04-W actualizado con valores de RCA-04-A';
    RAISE NOTICE '   - organization_id: %', v_org_id;
    RAISE NOTICE '   - active: %', v_rca04a.active;
    RAISE NOTICE '   - deleted: false';
    RAISE NOTICE '   - archived: false';
    RAISE NOTICE '═══════════════════════════════════════════';
END $$;

-- 4. Verificar resultado final
SELECT 
    'RESULTADO FINAL' as paso,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    ci.active,
    ci.deleted,
    ci.archived,
    ci.item_type,
    ci.measure_basis,
    ci.uom,
    CASE 
        WHEN ci.deleted = true THEN '❌ ELIMINADO'
        WHEN ci.archived = true THEN '⚠️ ARCHIVADO'
        WHEN ci.active = false THEN '⚠️ INACTIVO'
        WHEN ci.organization_id IS NULL THEN '⚠️ SIN organization_id'
        ELSE '✅ DEBERÍA APARECER EN UI'
    END as status
FROM "CatalogItems" ci
WHERE ci.sku IN ('RCA-04-A', 'RCA-04-W')
ORDER BY ci.sku;








