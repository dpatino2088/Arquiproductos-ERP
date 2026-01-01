-- ====================================================
-- Script para verificar variants por collection
-- ====================================================
-- Este script verifica qué items tienen variant_name
-- y los agrupa por collection para identificar problemas
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  rec RECORD;
  collection_rec RECORD;
  total_items integer;
  items_with_variant integer;
  items_without_variant integer;
  items_with_collection integer;
  items_without_collection integer;
BEGIN
  RAISE NOTICE '🔍 Verificando variants en CatalogItems...';
  RAISE NOTICE '   Target Organization ID: %', target_org_id;
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 1: Estadísticas generales
  -- ====================================================
  SELECT COUNT(*) INTO total_items
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND deleted = false;

  SELECT COUNT(*) INTO items_with_variant
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND deleted = false
    AND variant_name IS NOT NULL
    AND trim(variant_name) <> '';

  SELECT COUNT(*) INTO items_without_variant
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND deleted = false
    AND (variant_name IS NULL OR trim(variant_name) = '');

  SELECT COUNT(*) INTO items_with_collection
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND deleted = false
    AND collection_id IS NOT NULL;

  SELECT COUNT(*) INTO items_without_collection
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND deleted = false
    AND collection_id IS NULL;

  RAISE NOTICE '📊 Estadísticas Generales:';
  RAISE NOTICE '   Total items (no deleted): %', total_items;
  RAISE NOTICE '   Items con variant_name: %', items_with_variant;
  RAISE NOTICE '   Items sin variant_name: %', items_without_variant;
  RAISE NOTICE '   Items con collection_id: %', items_with_collection;
  RAISE NOTICE '   Items sin collection_id: %', items_without_collection;
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 2: Items con variant_name pero sin collection_id
  -- ====================================================
  RAISE NOTICE '⚠️  Items con variant_name pero SIN collection_id:';
  FOR rec IN 
    SELECT 
      ci.sku,
      ci.variant_name,
      ci.is_fabric,
      ci.collection_id
    FROM public."CatalogItems" ci
    WHERE ci.organization_id = target_org_id
      AND ci.deleted = false
      AND ci.variant_name IS NOT NULL
      AND trim(ci.variant_name) <> ''
      AND ci.collection_id IS NULL
    LIMIT 20
  LOOP
    RAISE NOTICE '   - SKU: %, Variant: %, is_fabric: %', 
      rec.sku, rec.variant_name, rec.is_fabric;
  END LOOP;
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 3: Items con collection_id pero sin variant_name
  -- ====================================================
  RAISE NOTICE '⚠️  Items con collection_id pero SIN variant_name:';
  FOR rec IN 
    SELECT 
      ci.sku,
      ci.collection_id,
      cc.collection_name,
      ci.is_fabric
    FROM public."CatalogItems" ci
    LEFT JOIN public."CollectionsCatalog" cc ON cc.id = ci.collection_id
    WHERE ci.organization_id = target_org_id
      AND ci.deleted = false
      AND ci.collection_id IS NOT NULL
      AND (ci.variant_name IS NULL OR trim(ci.variant_name) = '')
    LIMIT 20
  LOOP
    RAISE NOTICE '   - SKU: %, Collection: %, is_fabric: %', 
      rec.sku, rec.collection_name, rec.is_fabric;
  END LOOP;
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 4: Variants por Collection
  -- ====================================================
  RAISE NOTICE '📋 Variants por Collection:';
  FOR collection_rec IN
    SELECT 
      cc.id,
      cc.collection_name,
      COUNT(DISTINCT ci.variant_name) as variant_count,
      COUNT(ci.id) as item_count
    FROM public."CollectionsCatalog" cc
    LEFT JOIN public."CatalogItems" ci ON 
      ci.collection_id = cc.id 
      AND ci.organization_id = target_org_id
      AND ci.deleted = false
      AND ci.variant_name IS NOT NULL
      AND trim(ci.variant_name) <> ''
      AND ci.sku IS NOT NULL
      AND trim(ci.sku) <> ''
    WHERE cc.organization_id = target_org_id
      AND cc.deleted = false
    GROUP BY cc.id, cc.collection_name
    ORDER BY variant_count DESC, cc.collection_name
  LOOP
    RAISE NOTICE '   Collection: % (ID: %)', 
      collection_rec.collection_name, collection_rec.id;
    RAISE NOTICE '      - Variants únicos: %', collection_rec.variant_count;
    RAISE NOTICE '      - Items totales: %', collection_rec.item_count;
    
    -- Mostrar los variants de esta collection
    FOR rec IN
      SELECT DISTINCT
        ci.variant_name,
        COUNT(ci.id) as sku_count
      FROM public."CatalogItems" ci
      WHERE ci.organization_id = target_org_id
        AND ci.collection_id = collection_rec.id
        AND ci.deleted = false
        AND ci.variant_name IS NOT NULL
        AND trim(ci.variant_name) <> ''
        AND ci.sku IS NOT NULL
        AND trim(ci.sku) <> ''
      GROUP BY ci.variant_name
      ORDER BY ci.variant_name
      LIMIT 10
    LOOP
      RAISE NOTICE '         • % (% SKUs)', rec.variant_name, rec.sku_count;
    END LOOP;
    
    RAISE NOTICE '';
  END LOOP;

  -- ====================================================
  -- STEP 5: Items que deberían tener variant pero no lo tienen
  -- ====================================================
  RAISE NOTICE '🔍 Items con collection_id e is_fabric=true pero SIN variant_name:';
  FOR rec IN
    SELECT 
      ci.sku,
      ci.collection_id,
      cc.collection_name,
      ci.is_fabric
    FROM public."CatalogItems" ci
    LEFT JOIN public."CollectionsCatalog" cc ON cc.id = ci.collection_id
    WHERE ci.organization_id = target_org_id
      AND ci.deleted = false
      AND ci.collection_id IS NOT NULL
      AND ci.is_fabric = true
      AND (ci.variant_name IS NULL OR trim(ci.variant_name) = '')
    LIMIT 20
  LOOP
    RAISE NOTICE '   - SKU: %, Collection: %', rec.sku, rec.collection_name;
  END LOOP;
  RAISE NOTICE '';

  RAISE NOTICE '✅ Verificación completada!';

END $$;













