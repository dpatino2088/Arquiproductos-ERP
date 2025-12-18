-- ====================================================
-- Migration 76: Asignar categorías automáticamente a CatalogItems
-- ====================================================
-- Este script asigna categorías de forma simplificada:
-- 1. Fabric → todos los items con is_fabric = true
-- 2. Components → todos los items que queden sin categoría
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
  RAISE NOTICE 'ASIGNACIÓN AUTOMÁTICA DE CATEGORÍAS';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 1: Obtener IDs de categorías
  -- ====================================================
  RAISE NOTICE 'PASO 1: Obteniendo IDs de categorías...';
  
  -- Fabric (categoría hoja)
  SELECT id INTO fabric_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id 
      AND code = 'FABRIC' 
      AND deleted = false 
      AND is_group = false
    LIMIT 1;
  
  -- Hardware (categoría hoja de Components)
  SELECT id INTO hardware_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id 
      AND code = 'COMP-HARDWARE' 
      AND deleted = false 
      AND is_group = false
    LIMIT 1;
  
  IF fabric_id IS NULL THEN
    RAISE WARNING '   ⚠️  Fabric no encontrado';
  ELSE
    RAISE NOTICE '   ✅ Fabric ID: %', fabric_id;
  END IF;
  
  IF hardware_id IS NULL THEN
    RAISE WARNING '   ⚠️  Hardware no encontrado';
  ELSE
    RAISE NOTICE '   ✅ Hardware ID: %', hardware_id;
  END IF;
  
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 2: Asignar Fabric a todos los items con is_fabric = true
  -- ====================================================
  RAISE NOTICE 'PASO 2: Asignando Fabric a items con is_fabric = true...';
  
  IF fabric_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = fabric_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND is_fabric = true;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Fabric: % items asignados', updated_count;
  ELSE
    RAISE WARNING '   ⚠️  No se pudo asignar Fabric (categoría no encontrada)';
  END IF;

  RAISE NOTICE '';

  -- ====================================================
  -- PASO 3: Asignar Hardware a todos los items restantes sin categoría
  -- ====================================================
  RAISE NOTICE 'PASO 3: Asignando Hardware a items restantes sin categoría...';
  
  IF hardware_id IS NOT NULL THEN
    UPDATE public."CatalogItems"
    SET item_category_id = hardware_id, updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Hardware: % items asignados', updated_count;
  ELSE
    RAISE WARNING '   ⚠️  No se pudo asignar Hardware (categoría no encontrada)';
  END IF;

  RAISE NOTICE '';

  -- ====================================================
  -- RESUMEN FINAL
  -- ====================================================
  DECLARE
    remaining_uncategorized integer;
    fabric_count integer;
    hardware_count integer;
  BEGIN
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
    RAISE NOTICE '✅ ASIGNACIÓN AUTOMÁTICA COMPLETADA';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Resumen:';
    RAISE NOTICE '   - Fabric: % items', fabric_count;
    RAISE NOTICE '   - Hardware: % items', hardware_count;
    RAISE NOTICE '   - Sin categoría: % items', remaining_uncategorized;
    RAISE NOTICE '';
    
    IF remaining_uncategorized > 0 THEN
      RAISE WARNING '   ⚠️  Aún quedan % items sin categoría', remaining_uncategorized;
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

