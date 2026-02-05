-- ============================================================================
-- Migración: ConfiguredProducts – eliminar TODAS las columnas no usadas
-- Fecha: 2026-02-04
-- Basado en: DUMP 2026-02_04_V1_full.sql + búsqueda en src/ y migrations
--
-- AUDITORÍA:
-- La tabla ConfiguredProducts en el dump tiene 43 columnas. Todas están en uso:
--   - id, organization_id, quote_id, bom_template_id, product_type_id, width_mm,
--     height_mm, quantity, hardware_color, bom_total, labor_pct, accessories_total,
--     total_msrp, config_snapshot, created_at, updated_at, deleted
--   - roll_catalog_item_id, roll_sku, roll_collection_name, roll_variant_name,
--     roll_width, roll_msrp_total, roll_plus_bom_total
--   - bottom_bar_item_id, bottom_bar_sku, headbox_item_id, headbox_sku,
--     side_channel_item_id, side_channel_sku, bottom_channel_item_id, bottom_channel_sku
--   - motor_item_id, motor_sku, drive_item_id, drive_sku, tube_item_id, tube_sku
--   - operating_type, roll_total_cost, bom_total_cost, labor_amount, bom_preview_snapshot
--
-- Columnas que SÍ se eliminan (legacy; pueden existir en DBs que corrieron
-- migraciones antiguas pero no las posteriores que las quitaron del schema):
--   - metadata (no se escribe en create_configured_product_and_bom_preview;
--     ya eliminada en 20260204_drop_unused_columns_and_tables; repetir por idempotencia)
--   - quote_line_id (el flujo actual no la usa; createQuoteLineFromConfiguredProduct
--     la actualizaba pero la columna ya no está en el dump)
--   - bom_instance_id (no se escribe en create_configured_product_and_bom_preview;
--     comentado en 20260204_drop_bom_instances_tables; puede existir en algunos DBs)
-- ============================================================================

BEGIN;

-- Eliminar columnas legacy que no están en el dump actual y no se usan.
-- DROP COLUMN IF EXISTS es idempotente: si la columna no existe, no hace nada.

ALTER TABLE public."ConfiguredProducts"
  DROP COLUMN IF EXISTS metadata,
  DROP COLUMN IF EXISTS quote_line_id,
  DROP COLUMN IF EXISTS bom_instance_id;

-- ----------------------------------------------------------------------------
-- Verificación
-- ----------------------------------------------------------------------------

DO $$
DECLARE
  v_has_metadata boolean;
  v_has_quote_line_id boolean;
  v_has_bom_instance_id boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'metadata'
  ) INTO v_has_metadata;
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'quote_line_id'
  ) INTO v_has_quote_line_id;
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'bom_instance_id'
  ) INTO v_has_bom_instance_id;

  IF NOT v_has_metadata AND NOT v_has_quote_line_id AND NOT v_has_bom_instance_id THEN
    RAISE NOTICE '✅ ConfiguredProducts: columnas no usadas (metadata, quote_line_id, bom_instance_id) eliminadas o ya ausentes.';
  ELSE
    RAISE WARNING '⚠️ Alguna columna sigue presente: metadata=%, quote_line_id=%, bom_instance_id=%',
      v_has_metadata, v_has_quote_line_id, v_has_bom_instance_id;
  END IF;
END $$;

COMMIT;

-- ============================================================================
-- NOTAS
-- ============================================================================
-- Las 43 columnas restantes de ConfiguredProducts están todas en uso por:
--   - create_configured_product_and_bom_preview (INSERT + UPDATE bom_preview_snapshot)
--   - calculate_configured_product_totals (UPDATE totales)
--   - build_bom_preview_snapshot (SELECT)
--   - commit_configured_product_to_quote_line (SELECT)
--   - Frontend: useQuotes (select id, roll_plus_bom_total, total_msrp, bom_preview_snapshot),
--     QuoteNew (select roll_catalog_item_id, roll_sku, ...), etc.
-- No se debe eliminar ninguna otra columna sin actualizar código y RPCs.
