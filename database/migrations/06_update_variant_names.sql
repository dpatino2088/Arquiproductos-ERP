-- ====================================================
-- Script para actualizar variant_name en CatalogItems
-- ====================================================
-- Este script actualiza los variant_name desde el staging table
-- para los items que son fabrics y tienen collection

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  updated_count integer;
  rec RECORD;
BEGIN
  RAISE NOTICE '🔧 Starting variant_name update...';
  RAISE NOTICE '   Target Organization ID: %', target_org_id;

  -- ====================================================
  -- STEP 1: Verificar que el staging table existe y tiene datos
  -- ====================================================
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = '_stg_catalog_items'
  ) THEN
    RAISE EXCEPTION 'Staging table _stg_catalog_items does not exist. Please import CSV first.';
  END IF;

  -- ====================================================
  -- STEP 2: Actualizar variant_name desde staging table
  -- ====================================================
  -- Solo actualizar items que son fabrics y tienen variant en el CSV
  -- Note: Supabase convierte los nombres de columnas a minúsculas al importar CSV
  -- Por lo tanto, usamos "variant" (minúscula) en lugar de "Variant"
  UPDATE public."CatalogItems" ci
  SET
    variant_name = CASE 
      WHEN COALESCE(s.is_fabric, FALSE) = TRUE
        AND (s.variant IS NOT NULL OR s."Variant" IS NOT NULL)
        AND (trim(COALESCE(s.variant, s."Variant", '')) <> '')
      THEN trim(COALESCE(s.variant, s."Variant", ''))
      ELSE ci.variant_name  -- Keep existing value if condition not met
    END,
    updated_at = now()
  FROM public."_stg_catalog_items" s
  WHERE ci.organization_id = target_org_id
    AND lower(trim(ci.sku)) = lower(trim(s.sku))
    AND s.sku IS NOT NULL 
    AND trim(s.sku) <> ''
    AND COALESCE(s.is_fabric, FALSE) = TRUE
    AND (s.variant IS NOT NULL OR s."Variant" IS NOT NULL)
    AND (trim(COALESCE(s.variant, s."Variant", '')) <> '')
    AND (ci.variant_name IS NULL OR ci.variant_name = '' OR ci.variant_name <> trim(COALESCE(s.variant, s."Variant", '')));

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '✅ Updated % CatalogItems with variant_name', updated_count;

  -- ====================================================
  -- STEP 3: Verificar resultados
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '📊 Verification:';
  
  -- Count fabrics with variant_name
  SELECT COUNT(*) INTO updated_count
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND is_fabric = TRUE
    AND variant_name IS NOT NULL
    AND trim(variant_name) <> '';
  
  RAISE NOTICE '   Fabrics with variant_name: %', updated_count;

  -- Count fabrics without variant_name
  SELECT COUNT(*) INTO updated_count
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND is_fabric = TRUE
    AND (variant_name IS NULL OR trim(variant_name) = '');
  
  RAISE NOTICE '   Fabrics without variant_name: %', updated_count;

  -- ====================================================
  -- STEP 4: Mostrar ejemplos
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '📋 Sample fabrics with variant_name:';
  FOR rec IN 
    SELECT 
      ci.sku,
      ci.item_name,
      ci.variant_name,
      cc.collection_name,
      CASE 
        WHEN ci.is_fabric AND cc.collection_name IS NOT NULL AND ci.variant_name IS NOT NULL
        THEN cc.collection_name || ' ' || ci.variant_name
        ELSE ci.item_name
      END as display_name
    FROM public."CatalogItems" ci
    LEFT JOIN public."CollectionsCatalog" cc ON cc.id = ci.collection_id
    WHERE ci.organization_id = target_org_id
      AND ci.is_fabric = TRUE
      AND ci.variant_name IS NOT NULL
      AND trim(ci.variant_name) <> ''
    LIMIT 10
  LOOP
    RAISE NOTICE '  - SKU: %, Variant: %, Collection: %, Display: %', 
      rec.sku, rec.variant_name, rec.collection_name, rec.display_name;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '✅ variant_name update completed!';

END $$;

