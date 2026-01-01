-- ====================================================
-- Migration 281 (COMPLETE FIX): Corrige TODOS los items
-- ====================================================
-- CORRIGE:
-- 1. Items mal categorizados (ej: CM-10 en Manual Drives → Motorized)
-- 2. Items sin categoría (asigna categoría correcta)
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  
  -- Category IDs
  v_brackets_id uuid;
  v_motorized_id uuid;
  v_manual_drives_id uuid;
  v_controls_id uuid;
  v_accessories_id uuid;
  v_components_id uuid;
  v_fabric_id uuid;
  v_tube_id uuid;
  v_bottom_rail_id uuid;
  v_side_channel_id uuid;
  v_chain_id uuid;
  
  -- Counters
  v_updated_count integer := 0;
  v_total_updated integer := 0;
  v_fixed_misplaced integer := 0;
  v_items_without_category integer := 0;
  rec RECORD;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'CORRECCIÓN COMPLETA DE CATEGORÍAS';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 1: Get category IDs
  -- ====================================================
  RAISE NOTICE 'STEP 1: Loading category IDs...';
  
  -- Brackets
  SELECT id INTO v_brackets_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND (name ILIKE '%bracket%' OR code ILIKE '%BRACKET%')
    AND is_group = false
    AND deleted = false
  ORDER BY name
  LIMIT 1;
  
  -- Motorized (Motors)
  SELECT id INTO v_motorized_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND (name ILIKE '%motor%' OR name ILIKE '%motorized%')
    AND is_group = false
    AND deleted = false
  ORDER BY name
  LIMIT 1;
  
  -- Manual Drives
  SELECT id INTO v_manual_drives_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND (name ILIKE '%manual%drive%' OR code ILIKE '%MANUAL%')
    AND is_group = false
    AND deleted = false
  ORDER BY name
  LIMIT 1;
  
  -- Controls
  SELECT id INTO v_controls_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND (name ILIKE '%control%' AND NOT name ILIKE '%manual%')
    AND is_group = false
    AND deleted = false
  ORDER BY name
  LIMIT 1;
  
  -- Accessories
  SELECT id INTO v_accessories_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND name ILIKE '%accessor%'
    AND is_group = false
    AND deleted = false
  ORDER BY name
  LIMIT 1;
  
  -- Components (fallback)
  SELECT id INTO v_components_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND name ILIKE '%component%'
    AND is_group = false
    AND deleted = false
  ORDER BY name
  LIMIT 1;
  
  -- Fabric
  SELECT id INTO v_fabric_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND name ILIKE '%fabric%'
    AND is_group = false
    AND deleted = false
  ORDER BY name
  LIMIT 1;
  
  -- Tube
  SELECT id INTO v_tube_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND (name ILIKE '%tube%' OR code ILIKE '%TUBE%')
    AND is_group = false
    AND deleted = false
  ORDER BY name
  LIMIT 1;
  
  -- Bottom Rail
  SELECT id INTO v_bottom_rail_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND (name ILIKE '%bottom%rail%' OR name ILIKE '%rail%')
    AND is_group = false
    AND deleted = false
  ORDER BY name
  LIMIT 1;
  
  -- Side Channel
  SELECT id INTO v_side_channel_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND (name ILIKE '%side%channel%' OR name ILIKE '%channel%')
    AND is_group = false
    AND deleted = false
  ORDER BY name
  LIMIT 1;
  
  -- Chain
  SELECT id INTO v_chain_id
  FROM "ItemCategories"
  WHERE organization_id = target_org_id
    AND (name ILIKE '%chain%' OR code ILIKE '%CHAIN%')
    AND is_group = false
    AND deleted = false
  ORDER BY name
  LIMIT 1;
  
  RAISE NOTICE '   ✅ Category IDs loaded';
  RAISE NOTICE '      Brackets: %', COALESCE(v_brackets_id::text, 'NOT FOUND');
  RAISE NOTICE '      Motorized: %', COALESCE(v_motorized_id::text, 'NOT FOUND');
  RAISE NOTICE '      Manual Drives: %', COALESCE(v_manual_drives_id::text, 'NOT FOUND');
  RAISE NOTICE '      Controls: %', COALESCE(v_controls_id::text, 'NOT FOUND');
  RAISE NOTICE '      Accessories: %', COALESCE(v_accessories_id::text, 'NOT FOUND');
  RAISE NOTICE '      Components: %', COALESCE(v_components_id::text, 'NOT FOUND');
  RAISE NOTICE '      Fabric: %', COALESCE(v_fabric_id::text, 'NOT FOUND');
  RAISE NOTICE '      Tube: %', COALESCE(v_tube_id::text, 'NOT FOUND');
  RAISE NOTICE '      Bottom Rail: %', COALESCE(v_bottom_rail_id::text, 'NOT FOUND');
  RAISE NOTICE '      Side Channel: %', COALESCE(v_side_channel_id::text, 'NOT FOUND');
  RAISE NOTICE '      Chain: %', COALESCE(v_chain_id::text, 'NOT FOUND');
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 2: FIX MISPLACED ITEMS (corrige TODOS, incluso los que ya tienen categoría)
  -- ====================================================
  RAISE NOTICE 'STEP 2: Fixing misplaced items (corrige items mal categorizados)...';
  
  -- Fix CM-10: Should be Motorized, NOT Manual Drives (o cualquier otra categoría)
  IF v_motorized_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_motorized_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND sku ILIKE 'CM-10%'
      AND item_category_id != v_motorized_id;  -- Corrige incluso si ya tiene categoría
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_fixed_misplaced := v_fixed_misplaced + v_updated_count;
    IF v_updated_count > 0 THEN
      RAISE NOTICE '   ✅ Fixed CM-10: moved to Motorized (% items)', v_updated_count;
    END IF;
  END IF;
  
  -- Fix ALL CM- motors: Should be Motorized
  IF v_motorized_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_motorized_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND (
        sku ILIKE 'CM-09%' OR
        sku ILIKE 'CM-10%' OR
        sku ILIKE 'CM-11%' OR
        sku ILIKE 'CM-12%' OR
        sku ILIKE 'CM-13%' OR
        sku ILIKE 'CM-14%' OR
        sku ILIKE 'CM-15%' OR
        sku ILIKE 'CM-16%' OR
        sku ILIKE 'CM-17%' OR
        sku ILIKE 'CM-18%' OR
        sku ILIKE 'CM-19%' OR
        sku ILIKE 'CM-20%' OR
        sku ILIKE 'CM-01%' OR
        sku ILIKE 'CM-02%' OR
        sku ILIKE 'CM-03%' OR
        sku ILIKE 'CM-04%' OR
        sku ILIKE 'CM-05%' OR
        sku ILIKE 'CM-06%' OR
        sku ILIKE 'CM-07%' OR
        sku ILIKE 'CM-08%' OR
        sku ILIKE 'CM-45%'
      )
      AND item_category_id != v_motorized_id;  -- Solo corrige si está mal categorizado
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_fixed_misplaced := v_fixed_misplaced + v_updated_count;
    IF v_updated_count > 0 THEN
      RAISE NOTICE '   ✅ Fixed CM-* motors: moved to Motorized (% items)', v_updated_count;
    END IF;
  END IF;
  
  -- Fix RC3001, RC3002, RC3003: Should be Manual Drives (o Controls si no existe Manual Drives)
  IF v_manual_drives_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_manual_drives_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND (sku ILIKE 'RC3001%' OR sku ILIKE 'RC3002%' OR sku ILIKE 'RC3003%')
      AND item_category_id != v_manual_drives_id;  -- Corrige incluso si ya tiene categoría
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_fixed_misplaced := v_fixed_misplaced + v_updated_count;
    IF v_updated_count > 0 THEN
      RAISE NOTICE '   ✅ Fixed RC3001/RC3002/RC3003: moved to Manual Drives (% items)', v_updated_count;
    END IF;
  ELSIF v_controls_id IS NOT NULL THEN
    -- Fallback: if Manual Drives doesn't exist, use Controls
    UPDATE "CatalogItems"
    SET item_category_id = v_controls_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND (sku ILIKE 'RC3001%' OR sku ILIKE 'RC3002%' OR sku ILIKE 'RC3003%')
      AND item_category_id != v_controls_id;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_fixed_misplaced := v_fixed_misplaced + v_updated_count;
    IF v_updated_count > 0 THEN
      RAISE NOTICE '   ✅ Fixed RC3001/RC3002/RC3003: moved to Controls (% items) - Manual Drives not found', v_updated_count;
    END IF;
  END IF;
  
  -- Fix Brackets: Should be in Brackets category
  IF v_brackets_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_brackets_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND (
        sku ILIKE 'RC3006%' OR
        sku ILIKE 'RC3007%' OR
        sku ILIKE 'RC3008%' OR
        sku ILIKE 'RC2004%' OR
        sku ILIKE 'RC2003%' OR
        sku ILIKE 'RC4004%'
      )
      AND item_category_id != v_brackets_id;  -- Corrige incluso si ya tiene categoría
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_fixed_misplaced := v_fixed_misplaced + v_updated_count;
    IF v_updated_count > 0 THEN
      RAISE NOTICE '   ✅ Fixed Brackets: moved to Brackets category (% items)', v_updated_count;
    END IF;
  END IF;
  
  -- Fix Chains: Should be in Chains category
  IF v_chain_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_chain_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND (
        sku ILIKE 'V15%' OR
        sku ILIKE 'RB%' OR
        sku ILIKE 'CSD%'
      )
      AND item_category_id != v_chain_id;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_fixed_misplaced := v_fixed_misplaced + v_updated_count;
    IF v_updated_count > 0 THEN
      RAISE NOTICE '   ✅ Fixed Chains: moved to Chains category (% items)', v_updated_count;
    END IF;
  END IF;
  
  -- Fix Tubes: Should be in Tubes category
  IF v_tube_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_tube_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND (sku ILIKE 'RTU-%' OR sku ILIKE 'RTU%')
      AND item_category_id != v_tube_id;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_fixed_misplaced := v_fixed_misplaced + v_updated_count;
    IF v_updated_count > 0 THEN
      RAISE NOTICE '   ✅ Fixed Tubes: moved to Tubes category (% items)', v_updated_count;
    END IF;
  END IF;
  
  RAISE NOTICE '   ✅ Total misplaced items fixed: %', v_fixed_misplaced;
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 3: Assign categories to items WITHOUT category
  -- ====================================================
  RAISE NOTICE 'STEP 3: Assigning categories to items without category...';
  
  -- Brackets (items sin categoría)
  IF v_brackets_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_brackets_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        sku ILIKE 'RC3006%' OR
        sku ILIKE 'RC3007%' OR
        sku ILIKE 'RC3008%' OR
        sku ILIKE 'RC2004%' OR
        sku ILIKE 'RC2003%' OR
        sku ILIKE 'RC4004%' OR
        (item_name ILIKE '%bracket%' AND description ILIKE '%bracket%')
      );
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '   ✅ Assigned % Brackets', v_updated_count;
  END IF;
  
  -- Motors (items sin categoría)
  IF v_motorized_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_motorized_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        sku ILIKE 'CM-09%' OR
        sku ILIKE 'CM-10%' OR
        sku ILIKE 'CM-11%' OR
        sku ILIKE 'CM-12%' OR
        sku ILIKE 'CM-13%' OR
        sku ILIKE 'CM-14%' OR
        sku ILIKE 'CM-15%' OR
        sku ILIKE 'CM-16%' OR
        sku ILIKE 'CM-17%' OR
        sku ILIKE 'CM-18%' OR
        sku ILIKE 'CM-19%' OR
        sku ILIKE 'CM-20%' OR
        sku ILIKE 'CM-01%' OR
        sku ILIKE 'CM-02%' OR
        sku ILIKE 'CM-03%' OR
        sku ILIKE 'CM-04%' OR
        sku ILIKE 'CM-05%' OR
        sku ILIKE 'CM-06%' OR
        sku ILIKE 'CM-07%' OR
        sku ILIKE 'CM-08%' OR
        sku ILIKE 'CM-45%' OR
        (item_name ILIKE '%motor%' AND NOT item_name ILIKE '%adapter%' AND NOT item_name ILIKE '%crown%' AND NOT item_name ILIKE '%manual%')
      );
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '   ✅ Assigned % Motors', v_updated_count;
  END IF;
  
  -- Manual Drives (items sin categoría)
  IF v_manual_drives_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_manual_drives_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        sku ILIKE 'RC3001%' OR
        sku ILIKE 'RC3002%' OR
        sku ILIKE 'RC3003%' OR
        (item_name ILIKE '%drive%' AND item_name ILIKE '%plug%' AND NOT item_name ILIKE '%motor%') OR
        (item_name ILIKE '%operating%system%' AND NOT item_name ILIKE '%motor%')
      );
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '   ✅ Assigned % Manual Drives', v_updated_count;
  END IF;
  
  -- Accessories (items sin categoría)
  IF v_accessories_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_accessories_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        sku ILIKE 'RC3045%' OR
        sku ILIKE 'RC3162%' OR
        sku ILIKE 'RC3164%' OR
        sku ILIKE 'CM-21%' OR
        sku ILIKE 'CM-22%' OR
        sku ILIKE 'CM-23%' OR
        sku ILIKE 'CM-29%' OR
        sku ILIKE 'CM-30%' OR
        sku ILIKE 'CM-31%' OR
        sku ILIKE 'CM-32%' OR
        sku ILIKE 'CM-34%' OR
        sku ILIKE 'CM-35%' OR
        sku ILIKE 'CM-36%' OR
        sku ILIKE 'CM-38%' OR
        sku ILIKE 'CM-39%' OR
        sku ILIKE 'CM-40%' OR
        sku ILIKE 'CM-41%' OR
        sku ILIKE 'CM-43%' OR
        (item_name ILIKE '%adapter%' AND item_name ILIKE '%motor%') OR
        (item_name ILIKE '%crown%' AND item_name ILIKE '%motor%') OR
        (item_name ILIKE '%accessory%')
      );
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '   ✅ Assigned % Accessories', v_updated_count;
  END IF;
  
  -- Tubes (items sin categoría)
  IF v_tube_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_tube_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        sku ILIKE 'RTU-%' OR
        sku ILIKE 'RTU%' OR
        (item_name ILIKE '%tube%' AND NOT item_name ILIKE '%cassette%')
      );
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '   ✅ Assigned % Tubes', v_updated_count;
  END IF;
  
  -- Chains (items sin categoría)
  IF v_chain_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_chain_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        sku ILIKE 'V15%' OR
        sku ILIKE 'RB%' OR
        sku ILIKE 'CSD%' OR
        item_name ILIKE '%chain%' OR
        description ILIKE '%chain%'
      );
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '   ✅ Assigned % Chains', v_updated_count;
  END IF;
  
  -- Fabric (items sin categoría)
  IF v_fabric_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_fabric_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        sku ILIKE 'DRF-%' OR
        is_fabric = true OR
        item_type = 'fabric'
      );
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '   ✅ Assigned % Fabrics', v_updated_count;
  END IF;
  
  -- Bottom Rail (items sin categoría)
  IF v_bottom_rail_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_bottom_rail_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        item_name ILIKE '%bottom%rail%' OR
        item_name ILIKE '%rail%profile%' OR
        description ILIKE '%bottom%rail%'
      );
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '   ✅ Assigned % Bottom Rails', v_updated_count;
  END IF;
  
  -- Side Channel (items sin categoría)
  IF v_side_channel_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_side_channel_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        item_name ILIKE '%side%channel%' OR
        description ILIKE '%side%channel%'
      );
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '   ✅ Assigned % Side Channels', v_updated_count;
  END IF;
  
  -- Components (fallback para items sin categoría)
  IF v_components_id IS NOT NULL THEN
    UPDATE "CatalogItems"
    SET item_category_id = v_components_id,
        updated_at = NOW()
    WHERE organization_id = target_org_id
      AND deleted = false
      AND item_category_id IS NULL
      AND (
        item_name ILIKE '%end%cap%' OR
        item_name ILIKE '%screw%' OR
        item_name ILIKE '%plug%' OR
        item_name ILIKE '%stop%' OR
        item_name ILIKE '%hardware%'
      );
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    v_total_updated := v_total_updated + v_updated_count;
    RAISE NOTICE '   ✅ Assigned % Components (end caps, screws, etc.)', v_updated_count;
  END IF;
  
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 4: Final summary
  -- ====================================================
  SELECT COUNT(*) INTO v_items_without_category
  FROM "CatalogItems"
  WHERE organization_id = target_org_id
    AND deleted = false
    AND item_category_id IS NULL;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ CORRECCIÓN COMPLETA FINALIZADA';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Summary:';
  RAISE NOTICE '   ✅ Items mal categorizados corregidos: %', v_fixed_misplaced;
  RAISE NOTICE '   ✅ Items sin categoría asignados: %', v_total_updated;
  RAISE NOTICE '   ⚠️  Items aún sin categoría: %', v_items_without_category;
  RAISE NOTICE '';
  
  IF v_items_without_category > 0 THEN
    RAISE NOTICE '💡 Remaining items without category:';
    RAISE NOTICE '   Sample SKUs:';
    
    FOR rec IN (
      SELECT sku, item_name, description
      FROM "CatalogItems"
      WHERE organization_id = target_org_id
        AND deleted = false
        AND item_category_id IS NULL
      LIMIT 10
    ) LOOP
      RAISE NOTICE '      - %: %', rec.sku, COALESCE(rec.item_name, rec.description, 'N/A');
    END LOOP;
  END IF;
  
  RAISE NOTICE '';

END $$;

-- Verification query
SELECT 
  CASE 
    WHEN ci.item_category_id IS NULL THEN '❌ Sin categoría'
    WHEN ic.id IS NULL THEN '⚠️ Categoría inválida'
    ELSE '✅ ' || ic.name || ' (' || COALESCE(ic.code, 'N/A') || ')'
  END as estado,
  COUNT(*) as cantidad_items,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as porcentaje
FROM "CatalogItems" ci
LEFT JOIN "ItemCategories" ic ON ci.item_category_id = ic.id AND ic.deleted = false
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND ci.deleted = false
GROUP BY 
  CASE 
    WHEN ci.item_category_id IS NULL THEN '❌ Sin categoría'
    WHEN ic.id IS NULL THEN '⚠️ Categoría inválida'
    ELSE '✅ ' || ic.name || ' (' || COALESCE(ic.code, 'N/A') || ')'
  END
ORDER BY cantidad_items DESC;
