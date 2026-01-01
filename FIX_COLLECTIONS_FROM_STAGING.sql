-- ====================================================
-- Fix: Restaurar collection_name desde staging
-- ====================================================
-- Este script actualiza collection_name en CatalogItems
-- usando los datos del staging para items que lo perdieron
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  updated_count integer;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Restaurando collection_name desde staging';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- Actualizar collection_name desde staging para items que lo tienen en staging
  -- pero no en CatalogItems (o está vacío)
  UPDATE public."CatalogItems" c
  SET 
    collection_name = s.collection_name,
    updated_at = NOW()
  FROM public."_stg_catalog_update" s
  WHERE c.sku = s.sku
    AND c.organization_id = target_org_id
    AND c.deleted = false
    AND s.collection_name IS NOT NULL
    AND trim(s.collection_name) <> ''
    AND (c.collection_name IS NULL OR trim(c.collection_name) = '');

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  
  RAISE NOTICE '✅ Actualizados % registros con collection_name desde staging', updated_count;
  RAISE NOTICE '';

  -- También actualizar variant_name si está vacío
  UPDATE public."CatalogItems" c
  SET 
    variant_name = s.variant_name,
    updated_at = NOW()
  FROM public."_stg_catalog_update" s
  WHERE c.sku = s.sku
    AND c.organization_id = target_org_id
    AND c.deleted = false
    AND s.variant_name IS NOT NULL
    AND trim(s.variant_name) <> ''
    AND (c.variant_name IS NULL OR trim(c.variant_name) = '');

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  
  RAISE NOTICE '✅ Actualizados % registros con variant_name desde staging', updated_count;
  RAISE NOTICE '';
  RAISE NOTICE '✅ Proceso completado!';
  RAISE NOTICE '';

END $$;








