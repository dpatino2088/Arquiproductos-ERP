-- ====================================================
-- Migration 72: Verificar Dependencias ANTES de Borrar
-- ====================================================
-- Este script verifica qué tablas dependen de ItemCategories
-- IMPORTANTE: Ejecuta esto ANTES de borrar manualmente
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  catalog_items_count integer;
  category_margins_count integer;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'VERIFICANDO DEPENDENCIAS DE ItemCategories';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  IMPORTANTE: Si borras ItemCategories manualmente,';
  RAISE NOTICE '    estas tablas pueden verse afectadas:';
  RAISE NOTICE '';

  -- Verificar CatalogItems que usan item_category_id
  SELECT COUNT(*) INTO catalog_items_count
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND item_category_id IS NOT NULL
    AND deleted = false;
  
  RAISE NOTICE '📦 CatalogItems con item_category_id: %', catalog_items_count;
  IF catalog_items_count > 0 THEN
    RAISE WARNING '   ⚠️  Si borras las categorías, estos items quedarán con item_category_id inválido';
    RAISE NOTICE '   💡 SOLUCIÓN: El script 73 actualizará estos items después de recrear las categorías';
  END IF;

  -- Verificar CategoryMargins (si existe)
  BEGIN
    SELECT COUNT(*) INTO category_margins_count
    FROM public."CategoryMargins"
    WHERE organization_id = target_org_id
      AND deleted = false;
    
    RAISE NOTICE '📊 CategoryMargins: %', category_margins_count;
    IF category_margins_count > 0 THEN
      RAISE WARNING '   ⚠️  Si borras las categorías, estos márgenes quedarán huérfanos';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '   ℹ️  Tabla CategoryMargins no existe o no tiene datos';
  END;

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'CONCLUSIÓN:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  
  IF catalog_items_count > 0 THEN
    RAISE NOTICE '✅ PUEDES BORRAR manualmente las categorías, PERO:';
    RAISE NOTICE '   1. Los CatalogItems quedarán temporalmente con item_category_id inválido';
    RAISE NOTICE '   2. Ejecuta el script 73 DESPUÉS para recrear todo y actualizar los IDs';
    RAISE NOTICE '';
    RAISE NOTICE '📋 PASOS RECOMENDADOS:';
    RAISE NOTICE '   1. Ejecuta este script (72) para ver las dependencias';
    RAISE NOTICE '   2. Borra manualmente las categorías en Supabase Table Editor';
    RAISE NOTICE '   3. Ejecuta el script 73 para recrear todo desde cero';
  ELSE
    RAISE NOTICE '✅ NO HAY DEPENDENCIAS - Puedes borrar sin problemas';
    RAISE NOTICE '   Ejecuta el script 73 después para recrear todo';
  END IF;
  
  RAISE NOTICE '';

END $$;

