-- ====================================================
-- Migration 75: Limpiar item_category_id inválidos en CatalogItems
-- ====================================================
-- Este script limpia los item_category_id que apuntan a categorías
-- que ya no existen o están deleted (después de recrear las categorías)
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  invalid_category_count integer := 0;
  nulled_count integer := 0;
  valid_category_count integer := 0;
  total_items integer := 0;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'LIMPIEZA DE item_category_id INVÁLIDOS';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 1: Contar items con item_category_id inválido
  -- ====================================================
  RAISE NOTICE 'PASO 1: Verificando item_category_id inválidos...';
  
  SELECT COUNT(*) INTO total_items
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND deleted = false;
  
  SELECT COUNT(*) INTO invalid_category_count
  FROM public."CatalogItems" ci
  WHERE ci.organization_id = target_org_id
    AND ci.deleted = false
    AND ci.item_category_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public."ItemCategories" ic
      WHERE ic.id = ci.item_category_id
        AND ic.deleted = false
    );
  
  SELECT COUNT(*) INTO valid_category_count
  FROM public."CatalogItems" ci
  WHERE ci.organization_id = target_org_id
    AND ci.deleted = false
    AND ci.item_category_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public."ItemCategories" ic
      WHERE ic.id = ci.item_category_id
        AND ic.deleted = false
    );
  
  RAISE NOTICE '   Total CatalogItems: %', total_items;
  RAISE NOTICE '   Con item_category_id válido: %', valid_category_count;
  RAISE NOTICE '   Con item_category_id inválido: %', invalid_category_count;
  RAISE NOTICE '   Sin item_category_id: %', (total_items - valid_category_count - invalid_category_count);
  RAISE NOTICE '';

  -- ====================================================
  -- PASO 2: Limpiar item_category_id inválidos
  -- ====================================================
  IF invalid_category_count > 0 THEN
    RAISE NOTICE 'PASO 2: Limpiando item_category_id inválidos...';
    
    UPDATE public."CatalogItems" ci
    SET item_category_id = NULL,
        updated_at = NOW()
    WHERE ci.organization_id = target_org_id
      AND ci.deleted = false
      AND ci.item_category_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public."ItemCategories" ic
        WHERE ic.id = ci.item_category_id
          AND ic.deleted = false
      );
    
    GET DIAGNOSTICS nulled_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Limpiados % item_category_id inválidos', nulled_count;
    RAISE NOTICE '   💡 Estos items aparecerán como "Uncategorized" en el frontend';
    RAISE NOTICE '   💡 Puedes asignarles categorías manualmente desde el frontend';
  ELSE
    RAISE NOTICE 'PASO 2: No hay item_category_id inválidos que limpiar';
  END IF;

  RAISE NOTICE '';

  -- ====================================================
  -- RESUMEN FINAL
  -- ====================================================
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ PROCESO COMPLETADO';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Resumen:';
  RAISE NOTICE '   - Total items: %', total_items;
  RAISE NOTICE '   - Con categoría válida: %', valid_category_count;
  RAISE NOTICE '   - Limpiados (ahora NULL): %', nulled_count;
  RAISE NOTICE '   - Sin categoría: %', (total_items - valid_category_count - nulled_count);
  RAISE NOTICE '';
  RAISE NOTICE '📋 Próximos pasos:';
  RAISE NOTICE '   1. Los items con item_category_id NULL aparecerán como "Uncategorized"';
  RAISE NOTICE '   2. Puedes asignarles categorías manualmente desde el frontend';
  RAISE NOTICE '   3. O crear un script adicional si tienes un mapeo de SKU a categoría';
  RAISE NOTICE '';

END $$;

-- Query para verificar el estado final
SELECT 
  CASE 
    WHEN ci.item_category_id IS NULL THEN 'Sin categoría'
    WHEN ic.id IS NULL THEN 'Categoría inválida'
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
    WHEN ic.id IS NULL THEN 'Categoría inválida'
    ELSE ic.name || ' (' || ic.code || ')'
  END
ORDER BY cantidad_items DESC;

