-- =========================================
-- Script de verificación: Roll Dimensions
-- =========================================
-- Verifica que las columnas, constraints y triggers
-- para roll_width y roll_length estén correctos
-- =========================================

-- PASO 1: Verificar columnas
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'CatalogItems'
  AND column_name IN (
    'roll_width', 'roll_width_value', 'roll_width_uom', 'roll_width_m',
    'roll_length_value', 'roll_length_uom', 'roll_length_m'
  )
ORDER BY column_name;

-- PASO 2: Verificar constraints
SELECT 
  conname AS constraint_name,
  pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public."CatalogItems"'::regclass
  AND conname IN (
    'catalogitems_roll_width_uom_chk',
    'catalogitems_roll_length_uom_chk'
  );

-- PASO 3: Verificar trigger de normalización
SELECT 
  tgname AS trigger_name,
  pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE tgrelid = 'public."CatalogItems"'::regclass
  AND tgname = 'trg_catalogitems_sync_roll_dimensions';

-- PASO 4: Verificar trigger de conversions actualizado
SELECT 
  tgname AS trigger_name,
  pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE tgrelid = 'public."CatalogItems"'::regclass
  AND tgname = 'catalogitems_write_conversions';

-- PASO 5: Test de normalización (crear item de prueba)
DO $$
DECLARE
  v_org_id uuid;
  v_test_id uuid;
BEGIN
  -- Obtener una org existente
  SELECT id INTO v_org_id FROM "Organizations" LIMIT 1;
  
  IF v_org_id IS NULL THEN
    RAISE NOTICE '⚠️ No organization found, skipping test insert';
    RETURN;
  END IF;
  
  -- Insertar item de prueba
  INSERT INTO "CatalogItems" (
    organization_id, sku, name, unit_of_measure, measure_basis,
    is_roll, roll_type, collection_name, variant_name,
    roll_width_value, roll_width_uom,
    roll_length_value, roll_length_uom
  ) VALUES (
    v_org_id, 'TEST-ROLL-DIM-001', 'Test Roll Dimensions', 'm', 'linear',
    true, 'fabric', 'Test Collection', 'White',
    60, 'in',  -- 60 pulgadas
    30, 'yd'   -- 30 yardas
  )
  RETURNING id INTO v_test_id;
  
  -- Verificar que roll_width_m y roll_length_m se calcularon
  RAISE NOTICE '✅ Test item created: %', v_test_id;
  
  -- Mostrar valores calculados
  PERFORM * FROM (
    SELECT 
      sku,
      roll_width_value,
      roll_width_uom,
      roll_width_m,
      CASE 
        WHEN roll_width_value = 60 AND roll_width_uom = 'in' 
        THEN roll_width_m = round(60 * 0.0254, 4)
        ELSE false
      END AS width_correct,
      roll_length_value,
      roll_length_uom,
      roll_length_m,
      CASE 
        WHEN roll_length_value = 30 AND roll_length_uom = 'yd' 
        THEN roll_length_m = round(30 * 0.9144, 4)
        ELSE false
      END AS length_correct
    FROM "CatalogItems"
    WHERE id = v_test_id
  ) t;
  
  -- Limpiar
  DELETE FROM "CatalogItems" WHERE id = v_test_id;
  RAISE NOTICE '🧹 Test item deleted';
  
END $$;

-- PASO 6: Verificar que conversions usa roll_width_m
SELECT 
  ci.sku,
  ci.roll_width_value,
  ci.roll_width_uom,
  ci.roll_width_m,
  ci.roll_width AS legacy_width,
  conv.roll_width_input,
  conv.cost_exw_per_m2
FROM "CatalogItems" ci
LEFT JOIN "CatalogItemConversions" conv ON conv.catalog_item_id = ci.id
WHERE ci.is_roll = true
  AND ci.cost_exw IS NOT NULL
LIMIT 5;

-- Esperado:
-- - roll_width_input debería ser igual a roll_width_m (o roll_width si roll_width_m es NULL)
-- - cost_exw_per_m2 calculado con roll_width_m (o fallback a roll_width)
