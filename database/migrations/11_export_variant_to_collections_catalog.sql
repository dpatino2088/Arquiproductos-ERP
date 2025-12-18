-- ====================================================
-- Script para exportar variant de staging a CatalogItems.variant_name
-- ====================================================
-- Este script toma los valores de variant del staging table
-- y los actualiza en CatalogItems.variant_name usando el SKU como referencia
-- Solo actualiza items que son fabrics (is_fabric = true)
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  updated_count integer;
  rec RECORD;
BEGIN
  RAISE NOTICE '🔧 Exportando variant de staging a CatalogItems.variant_name...';
  RAISE NOTICE '   Target Organization ID: %', target_org_id;

  -- ====================================================
  -- STEP 1: Verificar que el staging table existe
  -- ====================================================
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = '_stg_catalog_items'
  ) THEN
    RAISE EXCEPTION 'Staging table _stg_catalog_items does not exist. Please import CSV first.';
  END IF;

  -- ====================================================
  -- STEP 2: Actualizar CatalogItems.variant_name usando SKU como referencia
  -- ====================================================
  -- Solo actualizar items que son fabrics (is_fabric = true)
  -- Hacer match por SKU entre staging y CatalogItems
  -- Nota: Supabase puede convertir columnas a minúsculas, usar COALESCE para ambos casos
  UPDATE public."CatalogItems" ci
  SET
    variant_name = CASE 
      WHEN (s.variant IS NOT NULL OR s."Variant" IS NOT NULL)
        AND trim(COALESCE(s.variant, s."Variant", '')) <> ''
      THEN trim(COALESCE(s.variant, s."Variant", ''))
      ELSE ci.variant_name  -- Mantener valor existente si no hay variant en staging
    END,
    updated_at = now()
  FROM public."_stg_catalog_items" s
  WHERE ci.organization_id = target_org_id
    AND ci.is_fabric = true  -- Solo fabrics
    AND ci.deleted = false
    AND lower(trim(ci.sku)) = lower(trim(s.sku))  -- Match por SKU
    AND s.sku IS NOT NULL
    AND trim(s.sku) <> ''
    AND (
      (s.variant IS NOT NULL OR s."Variant" IS NOT NULL)
      AND trim(COALESCE(s.variant, s."Variant", '')) <> ''
    )
    AND (
      ci.variant_name IS NULL 
      OR ci.variant_name = '' 
      OR ci.variant_name <> trim(COALESCE(s.variant, s."Variant", ''))
    );

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '✅ Actualizados % CatalogItems con variant_name', updated_count;

  -- ====================================================
  -- STEP 3: Verificación
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '📊 Verificación:';
  
  -- Contar fabrics con variant_name
  SELECT COUNT(*) INTO updated_count
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND is_fabric = true
    AND deleted = false
    AND variant_name IS NOT NULL
    AND trim(variant_name) <> '';
  
  RAISE NOTICE '   Fabrics con variant_name: %', updated_count;

  -- Contar fabrics sin variant_name
  SELECT COUNT(*) INTO updated_count
  FROM public."CatalogItems"
  WHERE organization_id = target_org_id
    AND is_fabric = true
    AND deleted = false
    AND (variant_name IS NULL OR trim(variant_name) = '');
  
  RAISE NOTICE '   Fabrics sin variant_name: %', updated_count;

  -- ====================================================
  -- STEP 4: Mostrar ejemplos
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '📋 Ejemplos de CatalogItems (fabrics) con variant_name:';
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
      AND ci.is_fabric = true
      AND ci.deleted = false
      AND ci.variant_name IS NOT NULL
      AND trim(ci.variant_name) <> ''
    ORDER BY cc.collection_name, ci.variant_name, ci.sku
    LIMIT 10
  LOOP
    RAISE NOTICE '   - SKU: %, Collection: %, Variant: %, Display: %', 
      rec.sku, rec.collection_name, rec.variant_name, rec.display_name;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '✅ Exportación completada!';

END $$;

