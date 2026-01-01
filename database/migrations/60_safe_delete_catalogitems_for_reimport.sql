-- ====================================================
-- Migration 60: Safe Delete CatalogItems for Re-import
-- ====================================================
-- Este script elimina de forma segura todos los CatalogItems
-- y sus referencias para permitir una re-importación limpia desde CSV
-- 
-- IMPORTANTE: Este script NO elimina datos de:
-- - QuoteLines (solo pone catalog_item_id = NULL)
-- - BOMComponents (solo marca como deleted)
-- - QuoteLineComponents (solo marca como deleted)
-- 
-- Después de ejecutar este script, puedes importar el CSV nuevamente
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  deleted_count integer;
  updated_count integer;
  rec RECORD;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Safe Delete CatalogItems for Re-import';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Target Organization ID: %', target_org_id;
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 1: Verificar que existen CatalogItems
  -- ====================================================
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems'
  ) THEN
    RAISE NOTICE '⚠️  La tabla CatalogItems no existe. Nada que eliminar.';
    RETURN;
  END IF;

  -- Contar items antes de eliminar
  SELECT COUNT(*) INTO deleted_count
  FROM "CatalogItems"
  WHERE organization_id = target_org_id;

  RAISE NOTICE '📊 Items a eliminar: %', deleted_count;
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 2: Eliminar referencias en CatalogItemProductTypes
  -- ====================================================
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItemProductTypes'
  ) THEN
    RAISE NOTICE '🗑️  Eliminando referencias en CatalogItemProductTypes...';
    
    DELETE FROM public."CatalogItemProductTypes" cipt
    WHERE EXISTS (
      SELECT 1 FROM public."CatalogItems" ci
      WHERE ci.id = cipt.catalog_item_id
        AND ci.organization_id = target_org_id
    );

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Eliminados % registros', deleted_count;
  ELSE
    RAISE NOTICE 'ℹ️  CatalogItemProductTypes no existe, saltando...';
  END IF;

  -- ====================================================
  -- STEP 3: Actualizar QuoteLines (catalog_item_id = NULL)
  -- ====================================================
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines' 
    AND column_name = 'catalog_item_id'
  ) THEN
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Actualizando QuoteLines (catalog_item_id = NULL)...';
    
    UPDATE public."QuoteLines" ql
    SET catalog_item_id = NULL,
        updated_at = NOW()
    WHERE EXISTS (
      SELECT 1 FROM public."CatalogItems" ci
      WHERE ci.id = ql.catalog_item_id
        AND ci.organization_id = target_org_id
    );

    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Actualizadas % QuoteLines', updated_count;
  ELSE
    RAISE NOTICE 'ℹ️  QuoteLines.catalog_item_id no existe, saltando...';
  END IF;

  -- ====================================================
  -- STEP 4: Marcar BOMComponents como deleted
  -- ====================================================
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents'
  ) THEN
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Marcando BOMComponents como deleted...';
    
    UPDATE public."BOMComponents" bom
    SET deleted = true,
        updated_at = NOW()
    WHERE EXISTS (
      SELECT 1 FROM public."CatalogItems" ci
      WHERE ci.id = bom.component_item_id
        AND ci.organization_id = target_org_id
    )
    AND deleted = false;

    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Marcados % BOMComponents como deleted', updated_count;
  ELSE
    RAISE NOTICE 'ℹ️  BOMComponents no existe, saltando...';
  END IF;

  -- ====================================================
  -- STEP 5: Marcar QuoteLineComponents como deleted
  -- ====================================================
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLineComponents'
  ) THEN
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Marcando QuoteLineComponents como deleted...';
    
    UPDATE public."QuoteLineComponents" qlc
    SET deleted = true,
        updated_at = NOW()
    WHERE EXISTS (
      SELECT 1 FROM public."CatalogItems" ci
      WHERE ci.id = qlc.catalog_item_id
        AND ci.organization_id = target_org_id
    )
    AND deleted = false;

    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Marcados % QuoteLineComponents como deleted', updated_count;
  ELSE
    RAISE NOTICE 'ℹ️  QuoteLineComponents no existe, saltando...';
  END IF;

  -- ====================================================
  -- STEP 6: Eliminar PricingConfiguration (si existe)
  -- ====================================================
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'PricingConfiguration'
  ) THEN
    RAISE NOTICE '';
    RAISE NOTICE '🗑️  Eliminando PricingConfiguration...';
    
    DELETE FROM public."PricingConfiguration" pc
    WHERE EXISTS (
      SELECT 1 FROM public."CatalogItems" ci
      WHERE ci.id = pc.catalog_item_id
        AND ci.organization_id = target_org_id
    );

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Eliminados % registros', deleted_count;
  ELSE
    RAISE NOTICE 'ℹ️  PricingConfiguration no existe, saltando...';
  END IF;

  -- ====================================================
  -- STEP 7: Eliminar todos los CatalogItems de la organización
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '🗑️  Eliminando todos los CatalogItems...';
  
  DELETE FROM public."CatalogItems"
  WHERE organization_id = target_org_id;

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RAISE NOTICE '   ✅ Eliminados % CatalogItems', deleted_count;

  -- ====================================================
  -- STEP 8: Verificación final
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '📊 Verificación final:';
  
  SELECT COUNT(*) INTO deleted_count
  FROM "CatalogItems"
  WHERE organization_id = target_org_id;

  IF deleted_count = 0 THEN
    RAISE NOTICE '   ✅ Todos los CatalogItems fueron eliminados correctamente';
  ELSE
    RAISE WARNING '   ⚠️  Aún quedan % CatalogItems', deleted_count;
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Proceso completado!';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Próximos pasos:';
  RAISE NOTICE '   1. Importa el CSV a la tabla _stg_catalog_items';
  RAISE NOTICE '   2. Ejecuta el script de migración desde staging';
  RAISE NOTICE '   3. Verifica que los datos se importaron correctamente';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

END $$;













