-- ====================================================
-- Migration 77: Diagnosticar por qué no se asignaron categorías
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  fabric_id uuid;
  hardware_id uuid;
  items_with_fabric_flag integer;
  items_without_category integer;
  total_items integer;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'DIAGNÓSTICO DE ASIGNACIÓN DE CATEGORÍAS';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- Verificar categorías
  SELECT id INTO fabric_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id 
      AND code = 'FABRIC' 
      AND deleted = false 
      AND is_group = false
    LIMIT 1;
  
  SELECT id INTO hardware_id FROM public."ItemCategories"
    WHERE organization_id = target_org_id 
      AND code = 'COMP-HARDWARE' 
      AND deleted = false 
      AND is_group = false
    LIMIT 1;
  
  RAISE NOTICE 'Categorías encontradas:';
  IF fabric_id IS NULL THEN
    RAISE WARNING '   ⚠️  Fabric NO encontrado';
  ELSE
    RAISE NOTICE '   ✅ Fabric ID: %', fabric_id;
  END IF;
  
  IF hardware_id IS NULL THEN
    RAISE WARNING '   ⚠️  Hardware NO encontrado';
  ELSE
    RAISE NOTICE '   ✅ Hardware ID: %', hardware_id;
  END IF;
  
  RAISE NOTICE '';

  -- Contar items
  SELECT COUNT(*) INTO total_items
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND deleted = false;
  
  SELECT COUNT(*) INTO items_with_fabric_flag
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND deleted = false
    AND is_fabric = true;
  
  SELECT COUNT(*) INTO items_without_category
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND deleted = false
    AND item_category_id IS NULL;
  
  RAISE NOTICE 'Estado de CatalogItems:';
  RAISE NOTICE '   Total items: %', total_items;
  RAISE NOTICE '   Items con is_fabric = true: %', items_with_fabric_flag;
  RAISE NOTICE '   Items sin categoría: %', items_without_category;
  RAISE NOTICE '';

  -- Verificar si hay items con is_fabric = true pero sin categoría
  DECLARE
    fabric_items_without_category integer;
  BEGIN
    SELECT COUNT(*) INTO fabric_items_without_category
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND is_fabric = true
      AND item_category_id IS NULL;
    
    IF fabric_items_without_category > 0 THEN
      RAISE WARNING '   ⚠️  Items con is_fabric = true pero sin categoría: %', fabric_items_without_category;
    END IF;
  END;

  RAISE NOTICE '';

END $$;

-- Verificar algunos items de ejemplo
SELECT 
  sku,
  name,
  item_name,
  is_fabric,
  item_category_id,
  CASE 
    WHEN item_category_id IS NULL THEN 'Sin categoría'
    ELSE (SELECT name FROM public."ItemCategories" WHERE id = ci.item_category_id AND deleted = false)
  END as categoria_actual
FROM public."CatalogItems" ci
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND deleted = false
  AND item_category_id IS NULL
LIMIT 10;

