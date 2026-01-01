-- ============================================================================
-- ASEGURAR QUE RCA-04-W SEA IDÉNTICO A RCA-04-A (EXCEPTO SKU)
-- ============================================================================

DO $$
DECLARE
    v_rca04a RECORD;
    v_rca04w_id UUID;
BEGIN
    RAISE NOTICE '🔍 Obteniendo datos de RCA-04-A...';
    
    -- Obtener todos los datos de RCA-04-A
    SELECT * INTO v_rca04a
    FROM "CatalogItems"
    WHERE sku = 'RCA-04-A'
    LIMIT 1;
    
    IF v_rca04a.id IS NULL THEN
        RAISE NOTICE '❌ RCA-04-A no encontrado';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ RCA-04-A encontrado: id=%', v_rca04a.id;
    
    -- Obtener ID de RCA-04-W
    SELECT id INTO v_rca04w_id
    FROM "CatalogItems"
    WHERE sku = 'RCA-04-W'
    LIMIT 1;
    
    IF v_rca04w_id IS NULL THEN
        RAISE NOTICE '❌ RCA-04-W no encontrado';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ RCA-04-W encontrado: id=%', v_rca04w_id;
    
    -- Actualizar RCA-04-W para que tenga los mismos valores que RCA-04-A
    -- (excepto sku, id, created_at, updated_at)
    UPDATE "CatalogItems"
    SET 
        organization_id = v_rca04a.organization_id,
        item_name = COALESCE(NULLIF(item_name, ''), v_rca04a.item_name),
        description = v_rca04a.description,
        manufacturer_id = v_rca04a.manufacturer_id,
        item_category_id = v_rca04a.item_category_id,
        item_type = v_rca04a.item_type,
        measure_basis = v_rca04a.measure_basis,
        uom = v_rca04a.uom,
        is_fabric = v_rca04a.is_fabric,
        roll_width_m = v_rca04a.roll_width_m,
        fabric_pricing_mode = v_rca04a.fabric_pricing_mode,
        cost_exw = v_rca04a.cost_exw,
        default_margin_pct = v_rca04a.default_margin_pct,
        msrp = v_rca04a.msrp,
        active = v_rca04a.active,
        discontinued = v_rca04a.discontinued,
        collection_id = v_rca04a.collection_id,
        collection_name = v_rca04a.collection_name,
        variant_id = v_rca04a.variant_id,
        variant_name = v_rca04a.variant_name,
        deleted = false, -- Asegurar que no esté eliminado
        archived = false, -- Asegurar que no esté archivado
        metadata = v_rca04a.metadata,
        updated_at = NOW()
    WHERE id = v_rca04w_id;
    
    RAISE NOTICE '✅ RCA-04-W actualizado para que sea idéntico a RCA-04-A';
    RAISE NOTICE '   - organization_id: %', v_rca04a.organization_id;
    RAISE NOTICE '   - active: %', v_rca04a.active;
    RAISE NOTICE '   - deleted: false';
    RAISE NOTICE '   - archived: false';
END $$;

-- Verificar resultado
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
    ci.updated_at
FROM "CatalogItems" ci
WHERE ci.sku IN ('RCA-04-A', 'RCA-04-W')
ORDER BY ci.sku;








