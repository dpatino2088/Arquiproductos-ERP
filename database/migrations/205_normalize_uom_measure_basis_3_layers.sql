-- ====================================================
-- Migration: Normalización UOM y Measure Basis en 3 Capas
-- ====================================================
-- Esta migración implementa normalización a lowercase en DB
-- para garantizar consistencia de datos
-- ====================================================

-- STEP 1: Crear función de normalización
CREATE OR REPLACE FUNCTION normalize_uom_fields()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Normalizar uom a lowercase y trim
  IF NEW.uom IS NOT NULL THEN
    NEW.uom := lower(trim(NEW.uom));
  END IF;

  -- Normalizar measure_basis a lowercase y trim
  IF NEW.measure_basis IS NOT NULL THEN
    NEW.measure_basis := lower(trim(NEW.measure_basis));
  END IF;

  -- Normalizar cost_uom a lowercase y trim (si existe)
  IF NEW.cost_uom IS NOT NULL THEN
    NEW.cost_uom := lower(trim(NEW.cost_uom));
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION normalize_uom_fields IS 
    'Normaliza campos UOM y measure_basis a lowercase antes de insertar/actualizar en CatalogItems. Garantiza consistencia de datos.';

-- STEP 2: Crear trigger
DROP TRIGGER IF EXISTS trg_normalize_uom_fields ON "CatalogItems";

CREATE TRIGGER trg_normalize_uom_fields
BEFORE INSERT OR UPDATE ON "CatalogItems"
FOR EACH ROW
EXECUTE FUNCTION normalize_uom_fields();

COMMENT ON TRIGGER trg_normalize_uom_fields ON "CatalogItems" IS 
    'Trigger que normaliza uom, measure_basis y cost_uom a lowercase antes de guardar. Previene inconsistencias como FT vs ft, MTS vs mts, etc.';

-- STEP 3: Normalizar datos existentes (backfill)
UPDATE "CatalogItems"
SET
  uom = lower(trim(uom)),
  measure_basis = lower(trim(measure_basis)),
  cost_uom = CASE 
    WHEN cost_uom IS NOT NULL THEN lower(trim(cost_uom))
    ELSE cost_uom
  END
WHERE 
  (uom IS NOT NULL AND uom != lower(trim(uom)))
  OR (measure_basis IS NOT NULL AND measure_basis != lower(trim(measure_basis)))
  OR (cost_uom IS NOT NULL AND cost_uom != lower(trim(cost_uom)))
  AND deleted = false;

-- Summary
DO $$
DECLARE
  v_updated_count integer;
BEGIN
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  
  RAISE NOTICE '';
  RAISE NOTICE '✅ Migration 205 completed: Normalización UOM y Measure Basis';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Created/Updated:';
  RAISE NOTICE '   - Function: normalize_uom_fields()';
  RAISE NOTICE '   - Trigger: trg_normalize_uom_fields (BEFORE INSERT OR UPDATE)';
  RAISE NOTICE '   - Backfill: % rows updated', v_updated_count;
  RAISE NOTICE '';
  RAISE NOTICE '🛡️ Protection:';
  RAISE NOTICE '   - Todos los valores de uom, measure_basis, cost_uom se normalizan a lowercase';
  RAISE NOTICE '   - Previene inconsistencias: FT vs ft, MTS vs mts, PCS vs pcs, etc.';
  RAISE NOTICE '';
END $$;





