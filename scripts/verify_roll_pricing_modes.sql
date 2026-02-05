-- ============================================================================
-- VERIFICACIÓN: Roll Pricing Modes en CatalogItems
-- ============================================================================
-- Fecha: 2026-02-02
-- Propósito: Verificar estado de roll_pricing_mode en items de tipo roll
-- 
-- Ejecutar este script para identificar:
-- 1. Rolls sin roll_pricing_mode (deberían tener default 'per_linear_meter')
-- 2. Rolls con roll_pricing_mode configurado correctamente
-- 3. Rolls con per_square_meter que necesitan roll_width > 0
-- ============================================================================

-- 1. RESUMEN GENERAL
SELECT 
  '📊 RESUMEN DE ROLLS' AS seccion,
  COUNT(*) FILTER (WHERE is_roll = true) AS total_rolls,
  COUNT(*) FILTER (WHERE is_roll = true AND roll_pricing_mode IS NULL) AS rolls_sin_pricing_mode,
  COUNT(*) FILTER (WHERE is_roll = true AND roll_pricing_mode = 'per_linear_meter') AS rolls_per_linear_meter,
  COUNT(*) FILTER (WHERE is_roll = true AND roll_pricing_mode = 'per_square_meter') AS rolls_per_square_meter,
  COUNT(*) FILTER (WHERE is_roll = true AND roll_pricing_mode = 'per_unit') AS rolls_per_unit
FROM "CatalogItems"
WHERE is_active = true;

-- 2. ROLLS SIN ROLL_PRICING_MODE (deberían obtener default vía trigger)
SELECT 
  '⚠️ ROLLS SIN PRICING MODE' AS seccion,
  id,
  sku,
  name,
  roll_type,
  is_roll,
  roll_pricing_mode,
  roll_width,
  cost_exw,
  created_at
FROM "CatalogItems"
WHERE is_active = true
  AND is_roll = true
  AND roll_pricing_mode IS NULL
ORDER BY created_at DESC;

-- 3. ROLLS CON PER_SQUARE_METER (verificar roll_width)
SELECT 
  '📏 ROLLS PER SQUARE METER' AS seccion,
  id,
  sku,
  name,
  roll_type,
  roll_pricing_mode,
  roll_width,
  CASE 
    WHEN roll_width IS NULL OR roll_width <= 0 THEN '❌ FALTA ROLL_WIDTH'
    ELSE '✅ OK'
  END AS validacion,
  cost_exw
FROM "CatalogItems"
WHERE is_active = true
  AND is_roll = true
  AND roll_pricing_mode = 'per_square_meter'
ORDER BY 
  CASE WHEN roll_width IS NULL OR roll_width <= 0 THEN 0 ELSE 1 END,
  name;

-- 4. ROLLS CON PER_LINEAR_METER
SELECT 
  '📐 ROLLS PER LINEAR METER' AS seccion,
  id,
  sku,
  name,
  roll_type,
  roll_pricing_mode,
  roll_width,
  cost_exw
FROM "CatalogItems"
WHERE is_active = true
  AND is_roll = true
  AND roll_pricing_mode = 'per_linear_meter'
ORDER BY name
LIMIT 10;

-- 5. ROLLS CON PER_UNIT
SELECT 
  '🎯 ROLLS PER UNIT' AS seccion,
  id,
  sku,
  name,
  roll_type,
  roll_pricing_mode,
  cost_exw
FROM "CatalogItems"
WHERE is_active = true
  AND is_roll = true
  AND roll_pricing_mode = 'per_unit'
ORDER BY name;

-- 6. VERIFICAR CATALOGITEMCONVERSIONS
SELECT 
  '💰 CATALOG ITEM CONVERSIONS' AS seccion,
  ci.sku,
  ci.name,
  ci.roll_type,
  ci.roll_pricing_mode,
  ci.cost_exw AS cost_exw_input,
  conv.cost_exw_per_m,
  conv.cost_exw_per_m2,
  CASE 
    WHEN ci.roll_pricing_mode = 'per_linear_meter' AND conv.cost_exw_per_m IS NULL THEN '⚠️ Missing per_m'
    WHEN ci.roll_pricing_mode = 'per_square_meter' AND conv.cost_exw_per_m2 IS NULL THEN '⚠️ Missing per_m2'
    ELSE '✅ OK'
  END AS validacion_conversions,
  conv.computed_at
FROM "CatalogItems" ci
LEFT JOIN "CatalogItemConversions" conv ON conv.catalog_item_id = ci.id
WHERE ci.is_active = true
  AND ci.is_roll = true
  AND ci.roll_pricing_mode IS NOT NULL
ORDER BY 
  CASE 
    WHEN ci.roll_pricing_mode = 'per_linear_meter' AND conv.cost_exw_per_m IS NULL THEN 0
    WHEN ci.roll_pricing_mode = 'per_square_meter' AND conv.cost_exw_per_m2 IS NULL THEN 0
    ELSE 1
  END,
  ci.name
LIMIT 20;

-- 7. DISTRIBUCIÓN POR ROLL_TYPE
SELECT 
  '📦 DISTRIBUCIÓN POR ROLL TYPE' AS seccion,
  roll_type,
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE roll_pricing_mode = 'per_linear_meter') AS per_linear_meter,
  COUNT(*) FILTER (WHERE roll_pricing_mode = 'per_square_meter') AS per_square_meter,
  COUNT(*) FILTER (WHERE roll_pricing_mode = 'per_unit') AS per_unit,
  COUNT(*) FILTER (WHERE roll_pricing_mode IS NULL) AS sin_pricing_mode
FROM "CatalogItems"
WHERE is_active = true
  AND is_roll = true
GROUP BY roll_type
ORDER BY total DESC;

-- 8. ITEMS CON ROLL_PRICING_MODE PERO IS_ROLL = FALSE (inconsistencia)
SELECT 
  '❌ INCONSISTENCIAS' AS seccion,
  id,
  sku,
  name,
  is_roll,
  roll_pricing_mode,
  'roll_pricing_mode set but is_roll=false' AS problema
FROM "CatalogItems"
WHERE is_active = true
  AND is_roll = false
  AND roll_pricing_mode IS NOT NULL
ORDER BY name;

-- ============================================================================
-- COMANDOS DE CORRECCIÓN (Si es necesario)
-- ============================================================================

-- Si necesitas establecer roll_pricing_mode manualmente para rolls existentes sin valor:
-- 
-- UPDATE "CatalogItems"
-- SET roll_pricing_mode = 'per_linear_meter'
-- WHERE is_active = true
--   AND is_roll = true
--   AND roll_pricing_mode IS NULL;

-- Si necesitas establecer roll_width para rolls con per_square_meter:
-- 
-- UPDATE "CatalogItems"
-- SET roll_width = 1.0  -- Ajustar al ancho real en metros
-- WHERE is_active = true
--   AND is_roll = true
--   AND roll_pricing_mode = 'per_square_meter'
--   AND (roll_width IS NULL OR roll_width <= 0);

-- Si necesitas recalcular CatalogItemConversions:
-- 
-- SELECT public.trg_catalogitems_write_conversions() 
-- FROM "CatalogItems"
-- WHERE is_active = true
--   AND is_roll = true;

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================
