-- ============================================================================
-- Migración: Eliminar columnas y tablas no usadas (legacy)
-- Basado en: INFORME_COLUMNAS_EN_USO_Y_LEGACY.md
--
-- IMPORTANTE:
-- 1. Ejecutar en ventana de mantenimiento (los SELECT * sobre QuoteLines
--    deben usar lista de columnas; el RPC de commit ya no escribe collection_id/variant_id).
-- 2. Hacer backup antes. Si algo falla, hacer ROLLBACK.
-- 3. La tabla QuoteLineBOMSelections NO se elimina por defecto: el frontend
--    (bomSelections.ts) aún la usa. Ver bloque opcional al final.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1) QuoteLines: columnas legacy (causaban error UUID con SKU "RCA-04-W")
--    El RPC commit_configured_product_to_quote_line ya no las escribe.
-- ----------------------------------------------------------------------------

-- Índices que referencian las columnas (eliminar antes que las columnas)
DROP INDEX IF EXISTS public.idx_quote_lines_collection_id;
DROP INDEX IF EXISTS public.idx_quote_lines_variant_id;

ALTER TABLE public."QuoteLines"
  DROP COLUMN IF EXISTS collection_id,
  DROP COLUMN IF EXISTS variant_id;

-- ----------------------------------------------------------------------------
-- 2) ConfiguredProducts: columna metadata
--    El RPC no la escribe; el frontend la excluye al armar payloads.
-- ----------------------------------------------------------------------------

ALTER TABLE public."ConfiguredProducts"
  DROP COLUMN IF EXISTS metadata;

-- ----------------------------------------------------------------------------
-- 3) OPCIONAL: Tabla legacy QuoteLineBOMSelections
--    Solo descomentar SI ya eliminaste o refactorizaste todo el código que
--    usa QuoteLineBOMSelections (src/lib/bomSelections.ts y llamadas desde
--    QuoteNew / configurator). Si la dejas comentada, la tabla sigue existiendo.
-- ----------------------------------------------------------------------------

-- DROP TABLE IF EXISTS public."QuoteLineBOMSelections" CASCADE;

-- ----------------------------------------------------------------------------
-- Verificación
-- ----------------------------------------------------------------------------

DO $$
DECLARE
  v_ql_has_collection_id boolean;
  v_ql_has_variant_id boolean;
  v_cp_has_metadata boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'collection_id'
  ) INTO v_ql_has_collection_id;
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'variant_id'
  ) INTO v_ql_has_variant_id;
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'metadata'
  ) INTO v_cp_has_metadata;

  IF NOT v_ql_has_collection_id AND NOT v_ql_has_variant_id AND NOT v_cp_has_metadata THEN
    RAISE NOTICE '✅ Migración 20260204_drop_unused_columns_and_tables: columnas legacy eliminadas correctamente.';
  ELSE
    RAISE WARNING '⚠️ Alguna columna sigue presente: collection_id=%, variant_id=%, metadata=%',
      v_ql_has_collection_id, v_ql_has_variant_id, v_cp_has_metadata;
  END IF;
END $$;

COMMIT;

-- ============================================================================
-- NOTAS POST-MIGRACIÓN
-- ============================================================================
-- 1. En el código frontend, evita SELECT * de QuoteLines; usa lista de columnas
--    para no depender de collection_id/variant_id.
-- 2. Si en el futuro quieres eliminar más columnas de QuoteLines (pricing_basis,
--    cost_exw, drop_m, sqm, material_cost, labor_cost, etc.), ten en cuenta
--    que el cost engine y flujos de "reprice" pueden usarlas; revisa
--    useQuotes, QuoteLineCostsSection, y funciones de pricing antes.
-- 3. Para eliminar la tabla QuoteLineBOMSelections: quita o refactoriza
--    src/lib/bomSelections.ts y cualquier llamada a sus funciones; luego
--    descomenta el DROP TABLE en la sección 3 de este script y vuelve a
--    ejecutar solo esa parte.
-- ============================================================================
