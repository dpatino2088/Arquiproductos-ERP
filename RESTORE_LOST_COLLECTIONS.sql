-- ====================================================
-- Restaurar collection_name perdidos durante migración
-- ====================================================
-- Este script restaura collection_name para items que lo perdieron
-- pero SOLO para items que deberían tenerlo (fabric items)
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  updated_count integer;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Restaurando collection_name perdidos';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- Restaurar collection_name desde staging SOLO para items que:
  -- 1. Son fabric items (is_fabric = true)
  -- 2. Tienen collection_name en staging
  -- 3. Perdieron su collection_name (está NULL o vacío en CatalogItems)
  UPDATE public."CatalogItems" c
  SET 
    collection_name = s.collection_name,
    variant_name = COALESCE(
      NULLIF(trim(s.variant_name), ''),
      c.variant_name
    ),
    updated_at = NOW()
  FROM public."_stg_catalog_update" s
  WHERE c.sku = s.sku
    AND c.organization_id = target_org_id
    AND c.deleted = false
    AND c.is_fabric = true  -- SOLO fabric items
    AND s.collection_name IS NOT NULL
    AND trim(s.collection_name) <> ''
    AND (c.collection_name IS NULL OR trim(c.collection_name) = '');

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  
  RAISE NOTICE '✅ Restaurados % fabric items con collection_name desde staging', updated_count;
  RAISE NOTICE '';

  -- También restaurar variant_name si está vacío pero el staging lo tiene
  UPDATE public."CatalogItems" c
  SET 
    variant_name = s.variant_name,
    updated_at = NOW()
  FROM public."_stg_catalog_update" s
  WHERE c.sku = s.sku
    AND c.organization_id = target_org_id
    AND c.deleted = false
    AND c.is_fabric = true  -- SOLO fabric items
    AND s.variant_name IS NOT NULL
    AND trim(s.variant_name) <> ''
    AND (c.variant_name IS NULL OR trim(c.variant_name) = '');

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  
  RAISE NOTICE '✅ Restaurados % fabric items con variant_name desde staging', updated_count;
  RAISE NOTICE '';
  RAISE NOTICE '✅ Proceso completado!';
  RAISE NOTICE '';

END $$;








