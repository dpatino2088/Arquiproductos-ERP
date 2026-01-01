-- Backfill temporal de MSRP para items sin precio (permite validar flujo y UI)
-- IMPORTANTE: Esto es un backfill temporal. NO reemplaza MSRPs reales que debes definir.
-- Usa margen mínimo del 35% (margin-on-sale)

-- ============================================
-- A) Verificar cuántos items están sin MSRP
-- ============================================
SELECT
  COUNT(*) AS total_items,
  COUNT(*) FILTER (WHERE msrp IS NULL OR msrp = 0) AS items_sin_msrp,
  COUNT(*) FILTER (WHERE msrp IS NOT NULL AND msrp > 0) AS items_con_msrp
FROM "CatalogItems"
WHERE deleted = false;

-- ============================================
-- B) Backfill usando margen mínimo fijo (35%)
-- ============================================
-- Fórmula: msrp = cost_exw / (1 - 0.35)
-- Esto es un backfill temporal para permitir testing

UPDATE "CatalogItems"
SET 
  msrp = ROUND(cost_exw / (1 - 0.35), 2),
  msrp_manual = false, -- Marca como no manual (para permitir recálculo futuro)
  updated_at = NOW()
WHERE deleted = false
  AND (msrp IS NULL OR msrp = 0)
  AND cost_exw > 0;

-- ============================================
-- C) Verificar resultados
-- ============================================
SELECT
  COUNT(*) AS total_items_actualizados,
  AVG(msrp) AS msrp_promedio,
  MIN(msrp) AS msrp_minimo,
  MAX(msrp) AS msrp_maximo
FROM "CatalogItems"
WHERE deleted = false
  AND msrp > 0;

-- ============================================
-- NOTA IMPORTANTE:
-- Este backfill es temporal para permitir testing.
-- Debes definir los MSRPs reales manualmente o con tus reglas de negocio.
-- ============================================





