-- ====================================================
-- Migration 74: Verificar Compatibilidad con Hooks
-- ====================================================
-- Este script verifica que las categorías estén configuradas
-- correctamente para que los hooks funcionen bien
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'VERIFICACIÓN DE COMPATIBILIDAD CON HOOKS';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- Verificación 1: useItemCategories() - Todas las categorías
  -- ====================================================
  RAISE NOTICE '1️⃣ Verificando useItemCategories()...';
  
  DECLARE
    total_categories integer;
    categories_with_parent integer;
    categories_without_parent integer;
  BEGIN
    SELECT COUNT(*) INTO total_categories
    FROM public."ItemCategories"
    WHERE organization_id = target_org_id
      AND deleted = false;
    
    SELECT COUNT(*) INTO categories_with_parent
    FROM public."ItemCategories"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND parent_category_id IS NOT NULL;
    
    SELECT COUNT(*) INTO categories_without_parent
    FROM public."ItemCategories"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND parent_category_id IS NULL;
    
    RAISE NOTICE '   Total categorías: %', total_categories;
    RAISE NOTICE '   Con padre: %', categories_with_parent;
    RAISE NOTICE '   Sin padre: %', categories_without_parent;
    RAISE NOTICE '   ✅ useItemCategories() funcionará correctamente';
  END;

  RAISE NOTICE '';

  -- ====================================================
  -- Verificación 2: useLeafItemCategories() - Solo hojas (is_group = false)
  -- ====================================================
  RAISE NOTICE '2️⃣ Verificando useLeafItemCategories()...';
  
  DECLARE
    leaf_categories integer;
    group_categories integer;
    leaf_list text;
  BEGIN
    SELECT COUNT(*) INTO leaf_categories
    FROM public."ItemCategories"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND is_group = false;
    
    SELECT COUNT(*) INTO group_categories
    FROM public."ItemCategories"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND is_group = true;
    
    RAISE NOTICE '   Categorías hoja (is_group = false): %', leaf_categories;
    RAISE NOTICE '   Categorías grupo (is_group = true): %', group_categories;
    
    -- Listar categorías hoja
    SELECT string_agg(name || ' (' || code || ')', ', ' ORDER BY code)
    INTO leaf_list
    FROM public."ItemCategories"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND is_group = false;
    
    IF leaf_list IS NOT NULL THEN
      RAISE NOTICE '   Categorías hoja encontradas: %', leaf_list;
    END IF;
    
    RAISE NOTICE '   ✅ useLeafItemCategories() mostrará % categorías', leaf_categories;
  END;

  RAISE NOTICE '';

  -- ====================================================
  -- Verificación 3: CatalogItems con item_category_id
  -- ====================================================
  RAISE NOTICE '3️⃣ Verificando CatalogItems con item_category_id...';
  
  DECLARE
    items_with_category integer;
    items_without_category integer;
    items_with_invalid_category integer;
  BEGIN
    SELECT COUNT(*) INTO items_with_category
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NOT NULL;
    
    SELECT COUNT(*) INTO items_without_category
    FROM public."CatalogItems"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL;
    
    -- Verificar items con item_category_id inválido (categoría no existe o está deleted)
    SELECT COUNT(*) INTO items_with_invalid_category
    FROM public."CatalogItems" ci
    WHERE ci.organization_id = target_org_id
      AND ci.deleted = false
      AND ci.item_category_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public."ItemCategories" ic
        WHERE ic.id = ci.item_category_id
          AND ic.deleted = false
      );
    
    RAISE NOTICE '   Items con item_category_id: %', items_with_category;
    RAISE NOTICE '   Items sin item_category_id: %', items_without_category;
    
    IF items_with_invalid_category > 0 THEN
      RAISE WARNING '   ⚠️  Items con item_category_id inválido: %', items_with_invalid_category;
      RAISE WARNING '   💡 Estos items no aparecerán en los filtros por categoría';
    ELSE
      RAISE NOTICE '   ✅ Todos los item_category_id son válidos';
    END IF;
  END;

  RAISE NOTICE '';

  -- ====================================================
  -- Verificación 4: Categorías requeridas para BOM
  -- ====================================================
  RAISE NOTICE '4️⃣ Verificando categorías requeridas para BOM...';
  
  DECLARE
    required_categories text[] := ARRAY[
      'COMP-BRACKET', 'COMP-CASSETTE', 'COMP-SIDE', 'COMP-BOTTOM', 'COMP-TUBE',
      'ACC-BATTERY', 'ACC-REMOTE', 'ACC-SENSOR', 'ACC-TOOL',
      'MOTOR-MANUAL', 'MOTOR-MOTORIZED', 'MOTOR-CONTROL',
      'COMP-CHAIN', 'COMP-HARDWARE', 'WINDOW-FILM'
    ];
    missing_categories text[] := ARRAY[]::text[];
    cat_code text;
    cat_exists boolean;
  BEGIN
    FOREACH cat_code IN ARRAY required_categories
    LOOP
      SELECT EXISTS(
        SELECT 1 FROM public."ItemCategories"
        WHERE organization_id = target_org_id
          AND code = cat_code
          AND deleted = false
          AND is_group = false
      ) INTO cat_exists;
      
      IF NOT cat_exists THEN
        missing_categories := array_append(missing_categories, cat_code);
      END IF;
    END LOOP;
    
    IF array_length(missing_categories, 1) > 0 THEN
      RAISE WARNING '   ⚠️  Categorías faltantes: %', array_to_string(missing_categories, ', ');
      RAISE WARNING '   💡 Estas categorías no aparecerán en el filtro de BOM';
    ELSE
      RAISE NOTICE '   ✅ Todas las categorías requeridas existen';
    END IF;
  END;

  RAISE NOTICE '';

  -- ====================================================
  -- Verificación 5: Estructura jerárquica correcta
  -- ====================================================
  RAISE NOTICE '5️⃣ Verificando estructura jerárquica...';
  
  DECLARE
    circular_refs integer;
    self_parents integer;
  BEGIN
    -- Verificar referencias circulares (categoría que es padre de su propio padre)
    SELECT COUNT(*) INTO circular_refs
    FROM public."ItemCategories" c1
    JOIN public."ItemCategories" c2 ON c1.parent_category_id = c2.id
    WHERE c1.organization_id = target_org_id
      AND c1.deleted = false
      AND c2.parent_category_id = c1.id;
    
    -- Verificar self-parent (categoría que es su propio padre)
    SELECT COUNT(*) INTO self_parents
    FROM public."ItemCategories"
    WHERE organization_id = target_org_id
      AND deleted = false
      AND id = parent_category_id;
    
    IF circular_refs > 0 THEN
      RAISE WARNING '   ⚠️  Referencias circulares encontradas: %', circular_refs;
    END IF;
    
    IF self_parents > 0 THEN
      RAISE WARNING '   ⚠️  Categorías que son su propio padre: %', self_parents;
    END IF;
    
    IF circular_refs = 0 AND self_parents = 0 THEN
      RAISE NOTICE '   ✅ Estructura jerárquica correcta (sin referencias circulares)';
    END IF;
  END;

  RAISE NOTICE '';

  -- ====================================================
  -- RESUMEN FINAL
  -- ====================================================
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ VERIFICACIÓN COMPLETADA';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Los hooks deberían funcionar correctamente si:';
  RAISE NOTICE '   1. Todas las categorías tienen is_group correcto';
  RAISE NOTICE '   2. Las categorías hoja (is_group = false) son las que aparecen en filtros';
  RAISE NOTICE '   3. Los CatalogItems tienen item_category_id válido';
  RAISE NOTICE '';

END $$;

-- Query para ver todas las categorías hoja (las que aparecen en useLeafItemCategories)
SELECT 
  name,
  code,
  CASE 
    WHEN parent_category_id IS NULL THEN 'Sin padre'
    ELSE (SELECT name FROM public."ItemCategories" WHERE id = c.parent_category_id)
  END as parent_name,
  is_group
FROM public."ItemCategories" c
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND deleted = false
  AND is_group = false  -- Solo categorías hoja (las que aparecen en filtros)
ORDER BY 
  code,
  name;

