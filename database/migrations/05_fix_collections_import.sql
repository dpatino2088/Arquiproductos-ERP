-- ====================================================
-- Script para corregir y verificar CollectionsCatalog
-- ====================================================
-- Este script asegura que todas las Collections del CSV se importen correctamente

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  collections_count integer;
  missing_collections_count integer;
  rec RECORD;
BEGIN
  RAISE NOTICE '🔧 Starting CollectionsCatalog fix...';
  RAISE NOTICE '   Target Organization ID: %', target_org_id;

  -- ====================================================
  -- STEP 1: Importar todas las Collections que faltan
  -- ====================================================
  -- Importar Collections desde el staging table que no existen aún
  INSERT INTO public."CollectionsCatalog" (organization_id, manufacturer_id, collection_name)
  SELECT DISTINCT
    target_org_id,
    m.id,
    trim(s.collection)
  FROM public."_stg_catalog_items" s
  LEFT JOIN public."Manufacturers" m
    ON lower(m.name) = lower(trim(s.manufacturer))
  WHERE s.collection IS NOT NULL 
    AND trim(s.collection) <> ''
    AND NOT EXISTS (
      SELECT 1 FROM public."CollectionsCatalog" cc
      WHERE cc.organization_id = target_org_id
        AND lower(cc.collection_name) = lower(trim(s.collection))
    )
  ON CONFLICT DO NOTHING;

  GET DIAGNOSTICS collections_count = ROW_COUNT;
  RAISE NOTICE '✅ Inserted % new collections', collections_count;

  -- ====================================================
  -- STEP 2: Verificar Collections sin manufacturer_id
  -- ====================================================
  -- Actualizar Collections que no tienen manufacturer_id pero deberían tenerlo
  UPDATE public."CollectionsCatalog" cc
  SET manufacturer_id = m.id
  FROM public."_stg_catalog_items" s
  JOIN public."Manufacturers" m
    ON lower(m.name) = lower(trim(s.manufacturer))
  WHERE cc.organization_id = target_org_id
    AND lower(cc.collection_name) = lower(trim(s.collection))
    AND cc.manufacturer_id IS NULL
    AND s.collection IS NOT NULL
    AND trim(s.collection) <> '';

  GET DIAGNOSTICS collections_count = ROW_COUNT;
  RAISE NOTICE '✅ Updated % collections with manufacturer_id', collections_count;

  -- ====================================================
  -- STEP 3: Verificar que todas las Collections del CSV existen
  -- ====================================================
  SELECT COUNT(DISTINCT trim(s.collection))
  INTO missing_collections_count
  FROM public."_stg_catalog_items" s
  WHERE s.collection IS NOT NULL 
    AND trim(s.collection) <> ''
    AND NOT EXISTS (
      SELECT 1 FROM public."CollectionsCatalog" cc
      WHERE cc.organization_id = target_org_id
        AND lower(cc.collection_name) = lower(trim(s.collection))
    );

  IF missing_collections_count > 0 THEN
    RAISE WARNING '⚠️  % collections from CSV are still missing', missing_collections_count;
  ELSE
    RAISE NOTICE '✅ All collections from CSV are present';
  END IF;

  -- ====================================================
  -- STEP 4: Mostrar resumen
  -- ====================================================
  SELECT COUNT(*) INTO collections_count
  FROM public."CollectionsCatalog"
  WHERE organization_id = target_org_id
    AND deleted = false;

  RAISE NOTICE '';
  RAISE NOTICE '📊 Summary:';
  RAISE NOTICE '   Total Collections in database: %', collections_count;

  -- Mostrar algunas Collections de ejemplo
  RAISE NOTICE '';
  RAISE NOTICE '📋 Sample Collections:';
  FOR rec IN
    SELECT collection_name, manufacturer_id
    FROM public."CollectionsCatalog"
    WHERE organization_id = target_org_id
      AND deleted = false
    ORDER BY collection_name
    LIMIT 10
  LOOP
    RAISE NOTICE '  - % (manufacturer_id: %)', rec.collection_name, rec.manufacturer_id;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '✅ CollectionsCatalog fix completed!';

END $$;

