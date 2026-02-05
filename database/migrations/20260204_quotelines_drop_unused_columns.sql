-- ============================================================================
-- Migración: QuoteLines – eliminar columnas no usadas
-- Fecha: 2026-02-04
-- Basado en: DUMP 2026-02_04_V1_full.sql + búsqueda en src/ y RPC commit
--
-- Criterio: Los precios/costes se toman de CatalogItemsMSRP y no se recalcula
-- nada en QuoteLines. Se eliminan todas las columnas de pricing/cost legacy
-- que ya no se usan.
--
-- YA ELIMINADAS en 20260204_drop_unused_columns_and_tables:
--   collection_id, variant_id (no repetir aquí).
-- ============================================================================

BEGIN;

-- Eliminar columnas de pricing/cost no usadas (fuente de verdad = CatalogItemsMSRP, sin recálculo aquí).
-- DROP COLUMN IF EXISTS es idempotente.

ALTER TABLE public."QuoteLines"
  DROP COLUMN IF EXISTS pricing_basis,
  DROP COLUMN IF EXISTS unit_of_measure,
  DROP COLUMN IF EXISTS fabric_pricing_mode,
  DROP COLUMN IF EXISTS drop_m,
  DROP COLUMN IF EXISTS sqm,
  DROP COLUMN IF EXISTS cost_exw,
  DROP COLUMN IF EXISTS labor_pct,
  DROP COLUMN IF EXISTS shipping_pct,
  DROP COLUMN IF EXISTS import_tax_pct,
  DROP COLUMN IF EXISTS default_margin_pct,
  DROP COLUMN IF EXISTS minimum_margin_pct,
  DROP COLUMN IF EXISTS discount_pct,
  DROP COLUMN IF EXISTS material_cost,
  DROP COLUMN IF EXISTS labor_cost,
  DROP COLUMN IF EXISTS shipping_cost,
  DROP COLUMN IF EXISTS import_tax_cost,
  DROP COLUMN IF EXISTS applied_margin_pct,
  DROP COLUMN IF EXISTS net_price;

-- ----------------------------------------------------------------------------
-- Verificación (muestra si alguna sigue presente)
-- ----------------------------------------------------------------------------

DO $$
DECLARE
  v_count int;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'QuoteLines'
    AND column_name IN (
      'pricing_basis', 'unit_of_measure', 'fabric_pricing_mode', 'drop_m',
      'sqm', 'cost_exw', 'labor_pct', 'shipping_pct', 'import_tax_pct',
      'default_margin_pct', 'minimum_margin_pct', 'discount_pct',
      'material_cost', 'labor_cost', 'shipping_cost', 'import_tax_cost',
      'applied_margin_pct', 'net_price'
    );
  IF v_count = 0 THEN
    RAISE NOTICE '✅ QuoteLines: todas las columnas legacy de pricing/cost eliminadas o ya ausentes.';
  ELSE
    RAISE WARNING '⚠️ QuoteLines: % columnas legacy siguen presentes (revisar DROP).', v_count;
  END IF;
END $$;

COMMIT;

-- ============================================================================
-- NOTAS
-- ============================================================================
-- Tras esta migración, el frontend no debe enviar estas columnas en insert/update
-- de QuoteLines (p. ej. quitar sqm, cost_exw, net_price, discount_pct,
-- applied_margin_pct, default_margin_pct de allowedQuoteLineFields si aún están).
-- Precio/coste viene de CatalogItemsMSRP y de los snapshots (roll_*_snapshot,
-- bom_*_snapshot, msrp, total_cost).
