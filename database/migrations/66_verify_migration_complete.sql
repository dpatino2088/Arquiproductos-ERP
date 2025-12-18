-- ====================================================
-- Migration 66: Verify Migration Complete
-- ====================================================
-- Este script verifica que la migración desde staging a CatalogItems
-- se completó correctamente y muestra un resumen de los datos
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  total_items integer;
  items_with_collection integer;
  items_with_variant integer;
  items_with_family integer;
  items_with_cost_exw integer;
  items_with_roll_width integer;
  items_with_category integer;
  items_with_manufacturer integer;
  items_active integer;
  items_discontinued integer;
  fabrics_count integer;
  non_fabrics_count integer;
  items_missing_sku integer;
  items_missing_name integer;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Verificando migración completada';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- Verificación 1: Total de items migrados
  -- ====================================================
  RAISE NOTICE '📊 Estadísticas generales:';
  
  SELECT COUNT(*) INTO total_items
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND deleted = false;
  
  RAISE NOTICE '   Total de items en CatalogItems: %', total_items;
  
  IF total_items = 0 THEN
    RAISE WARNING '   ⚠️  No se encontraron items. La migración puede no haberse ejecutado.';
  ELSE
    RAISE NOTICE '   ✅ Items encontrados en CatalogItems';
  END IF;

  -- ====================================================
  -- Verificación 2: Items con datos completos
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '📋 Verificando completitud de datos:';
  
  -- Items con collection_name
  SELECT COUNT(*) INTO items_with_collection
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND collection_name IS NOT NULL
    AND trim(collection_name) <> ''
    AND deleted = false;
  RAISE NOTICE '   Items con collection_name: % (%.1f%%)', 
    items_with_collection, 
    CASE WHEN total_items > 0 THEN (items_with_collection::numeric / total_items * 100) ELSE 0 END;
  
  -- Items con variant_name
  SELECT COUNT(*) INTO items_with_variant
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND variant_name IS NOT NULL
    AND trim(variant_name) <> ''
    AND deleted = false;
  RAISE NOTICE '   Items con variant_name: % (%.1f%%)', 
    items_with_variant,
    CASE WHEN total_items > 0 THEN (items_with_variant::numeric / total_items * 100) ELSE 0 END;
  
  -- Items con family
  SELECT COUNT(*) INTO items_with_family
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND family IS NOT NULL
    AND trim(family) <> ''
    AND deleted = false;
  RAISE NOTICE '   Items con family: % (%.1f%%)', 
    items_with_family,
    CASE WHEN total_items > 0 THEN (items_with_family::numeric / total_items * 100) ELSE 0 END;
  
  -- Items con cost_exw
  SELECT COUNT(*) INTO items_with_cost_exw
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND cost_exw > 0
    AND deleted = false;
  RAISE NOTICE '   Items con cost_exw > 0: % (%.1f%%)', 
    items_with_cost_exw,
    CASE WHEN total_items > 0 THEN (items_with_cost_exw::numeric / total_items * 100) ELSE 0 END;
  
  -- Items con roll_width_m (solo fabrics)
  SELECT COUNT(*) INTO items_with_roll_width
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND roll_width_m IS NOT NULL
    AND deleted = false;
  RAISE NOTICE '   Items con roll_width_m: % (%.1f%%)', 
    items_with_roll_width,
    CASE WHEN total_items > 0 THEN (items_with_roll_width::numeric / total_items * 100) ELSE 0 END;
  
  -- Items con category
  SELECT COUNT(*) INTO items_with_category
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND item_category_id IS NOT NULL
    AND deleted = false;
  RAISE NOTICE '   Items con item_category_id: % (%.1f%%)', 
    items_with_category,
    CASE WHEN total_items > 0 THEN (items_with_category::numeric / total_items * 100) ELSE 0 END;
  
  -- Items con manufacturer
  SELECT COUNT(*) INTO items_with_manufacturer
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND manufacturer_id IS NOT NULL
    AND deleted = false;
  RAISE NOTICE '   Items con manufacturer_id: % (%.1f%%)', 
    items_with_manufacturer,
    CASE WHEN total_items > 0 THEN (items_with_manufacturer::numeric / total_items * 100) ELSE 0 END;

  -- ====================================================
  -- Verificación 3: Estado de items
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '📈 Estado de items:';
  
  SELECT COUNT(*) INTO items_active
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND active = true
    AND deleted = false;
  RAISE NOTICE '   Items activos: %', items_active;
  
  SELECT COUNT(*) INTO items_discontinued
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND discontinued = true
    AND deleted = false;
  RAISE NOTICE '   Items descontinuados: %', items_discontinued;

  -- ====================================================
  -- Verificación 4: Tipos de items
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🏷️  Tipos de items:';
  
  SELECT COUNT(*) INTO fabrics_count
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND is_fabric = true
    AND deleted = false;
  RAISE NOTICE '   Fabrics: %', fabrics_count;
  
  SELECT COUNT(*) INTO non_fabrics_count
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND (is_fabric = false OR is_fabric IS NULL)
    AND deleted = false;
  RAISE NOTICE '   No-fabrics: %', non_fabrics_count;

  -- ====================================================
  -- Verificación 5: Datos críticos faltantes
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  Verificando datos críticos faltantes:';
  
  SELECT COUNT(*) INTO items_missing_sku
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND (sku IS NULL OR trim(sku) = '')
    AND deleted = false;
  
  IF items_missing_sku > 0 THEN
    RAISE WARNING '   ⚠️  Items sin SKU: %', items_missing_sku;
  ELSE
    RAISE NOTICE '   ✅ Todos los items tienen SKU';
  END IF;
  
  SELECT COUNT(*) INTO items_missing_name
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND (item_name IS NULL OR trim(item_name) = '')
    AND deleted = false;
  
  IF items_missing_name > 0 THEN
    RAISE WARNING '   ⚠️  Items sin item_name: %', items_missing_name;
  ELSE
    RAISE NOTICE '   ✅ Todos los items tienen item_name';
  END IF;

  -- ====================================================
  -- Verificación 6: Duplicados por SKU
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🔍 Verificando duplicados por SKU:';
  
  DECLARE
    duplicate_count integer;
  BEGIN
    SELECT COUNT(*) INTO duplicate_count
    FROM (
      SELECT sku, COUNT(*) as cnt
      FROM public."CatalogItems"
      WHERE organization_id = target_org_id
        AND deleted = false
        AND sku IS NOT NULL
        AND trim(sku) <> ''
      GROUP BY sku
      HAVING COUNT(*) > 1
    ) duplicates;
    
    IF duplicate_count > 0 THEN
      RAISE WARNING '   ⚠️  Se encontraron % SKUs duplicados', duplicate_count;
      RAISE NOTICE '   📝 Ejecuta esta query para ver los duplicados:';
      RAISE NOTICE '      SELECT sku, COUNT(*) FROM "CatalogItems" WHERE organization_id = ''%'' AND deleted = false GROUP BY sku HAVING COUNT(*) > 1;', target_org_id;
    ELSE
      RAISE NOTICE '   ✅ No se encontraron SKUs duplicados';
    END IF;
  END;

  -- ====================================================
  -- Resumen final
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Verificación completada';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Resumen:';
  RAISE NOTICE '   Total items: %', total_items;
  RAISE NOTICE '   Items activos: %', items_active;
  RAISE NOTICE '   Fabrics: %', fabrics_count;
  RAISE NOTICE '   No-fabrics: %', non_fabrics_count;
  RAISE NOTICE '';
  
  IF total_items > 0 AND items_missing_sku = 0 AND items_missing_name = 0 THEN
    RAISE NOTICE '✅ La migración parece estar completa y correcta';
  ELSE
    RAISE WARNING '⚠️  Revisa las advertencias anteriores';
  END IF;
  
  RAISE NOTICE '';

END $$;

