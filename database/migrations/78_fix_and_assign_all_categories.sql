-- ====================================================
-- Migration 78: Limpiar y asignar TODAS las categorías
-- ====================================================
-- Este script:
-- 1. Limpia item_category_id inválidos (que apuntan a categorías deleted)
-- 2. Asigna Fabric a items con is_fabric = true
-- 3. Asigna Hardware a TODOS los items restantes sin categoría
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  updated_count integer := 0;
  
  -- Category IDs
  fabric_id uuid;
  hardware_id uuid;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'LIMPIEZA Y ASIGNACIÓN COMPLETA';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 1: Obtener IDs de categorías
  -- ====================================================
  RAISE NOTICE 'PASO 1: Obteniendo IDs de categorías...';
  
  SELECT id INTO fabric_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id 
      AND code = 'FABRIC' 
      AND deleted = false
    LIMIT 1;
  
  SELECT id INTO hardware_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id 
      AND code = 'COMP-HARDWARE' 
      AND deleted = false
    LIMIT 1;
  
  IF fabric_id IS NULL THEN
    RAISE EXCEPTION 'ERROR: Fabric no encontrado';
  END IF;
  
  IF hardware_id IS NULL THEN
    RAISE EXCEPTION 'ERROR: Hardware no encontrado';
  END IF;
  
  RAISE NOTICE '   ✅ Fabric ID: %', fabric_id;
  RAISE NOTICE '   ✅ Hardware ID: %', hardware_id;
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 2: Limpiar item_category_id inválidos
  -- ====================================================
  RAISE NOTICE 'PASO 2: Limpiando item_category_id inválidos...';
  
  UPDATE public."CatalogItems" ci
  SET item_category_id = NULL, updated_at = NOW()
  WHERE ci.organization_id = target_org_id
    AND ci.deleted = false
    AND ci.item_category_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public."ItemCategories" ic
      WHERE ic.id = ci.item_category_id
        AND ic.deleted = false
    );
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  IF updated_count > 0 THEN
    RAISE NOTICE '   ✅ Limpiados % item_category_id inválidos', updated_count;
  ELSE
    RAISE NOTICE '   ✅ No hay item_category_id inválidos';
  END IF;
  
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 3: Asignar Fabric a todos los items con is_fabric = true
  -- ====================================================
  RAISE NOTICE 'PASO 3: Asignando Fabric a items con is_fabric = true...';
  
  UPDATE public."CatalogItems"
  SET item_category_id = fabric_id, updated_at = NOW()
  WHERE organization_id = target_org_id
    AND deleted = false
    AND item_category_id IS NULL
    AND is_fabric = true;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Fabric: % items asignados', updated_count;

  RAISE NOTICE '';

  -- ====================================================
  -- PASO 4: Asignar Hardware a TODOS los items restantes sin categoría
  -- ====================================================
  RAISE NOTICE 'PASO 4: Asignando Hardware a TODOS los items restantes sin categoría...';
  
  UPDATE public."CatalogItems"
  SET item_category_id = hardware_id, updated_at = NOW()
  WHERE organization_id = target_org_id
    AND deleted = false
    AND item_category_id IS NULL;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Hardware: % items asignados', updated_count;

  RAISE NOTICE '';

  -- ====================================================
  -- RESUMEN FINAL
  -- ====================================================
  DECLARE
    remaining_uncategorized integer;
    fabric_count integer;
    hardware_count integer;
    total_items integer;
  BEGIN
    SELECT COUNT(*) INTO total_items
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND deleted = false;
    
    SELECT COUNT(*) INTO remaining_uncategorized
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL;
    
    SELECT COUNT(*) INTO fabric_count
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id = fabric_id;
    
    SELECT COUNT(*) INTO hardware_count
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id = hardware_id;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ PROCESO COMPLETADO';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Resumen final:';
    RAISE NOTICE '   - Total items: %', total_items;
    RAISE NOTICE '   - Fabric: % items', fabric_count;
    RAISE NOTICE '   - Hardware: % items', hardware_count;
    RAISE NOTICE '   - Sin categoría: % items', remaining_uncategorized;
    RAISE NOTICE '';
    
    IF remaining_uncategorized > 0 THEN
      RAISE WARNING '   ⚠️  Aún quedan % items sin categoría', remaining_uncategorized;
      RAISE WARNING '   💡 Esto no debería pasar. Verifica los items manualmente.';
    ELSE
      RAISE NOTICE '   ✅ Todos los items tienen categoría asignada';
    END IF;
    RAISE NOTICE '';
  END;

END $$;

-- Query para ver el estado final
SELECT 
  CASE 
    WHEN ci.item_category_id IS NULL THEN 'Sin categoría'
    ELSE ic.name || ' (' || ic.code || ')'
  END as categoria,
  COUNT(*) as cantidad_items
FROM public."CatalogItems" ci
LEFT JOIN public."ItemCategories" ic ON ci.item_category_id = ic.id AND ic.deleted = false
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND ci.deleted = false
GROUP BY 
  CASE 
    WHEN ci.item_category_id IS NULL THEN 'Sin categoría'
    ELSE ic.name || ' (' || ic.code || ')'
  END
ORDER BY cantidad_items DESC;

