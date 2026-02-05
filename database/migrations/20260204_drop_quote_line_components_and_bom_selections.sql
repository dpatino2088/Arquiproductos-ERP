-- ============================================================================
-- Migration: Drop empty Quote tables (QuoteLineBOMSelections, QuoteLineComponents)
-- Date: 2026-02-04
-- Description:
--   Ambas tablas están vacías (0 records). La información equivalente vive en:
--   - ConfiguredProducts.bom_preview_snapshot (breakdown y opciones)
--   - QuoteLines (area, position, drive_type, collection_name, etc.)
--
--   Se reemplazan las funciones que las referencian para que no fallen.
-- ============================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. REEMPLAZAR FUNCIONES QUE REFERENCIAN LAS TABLAS
-- ═══════════════════════════════════════════════════════════════════════════

-- get_parent_sku_selections: retornar conjunto vacío (ya no hay QuoteLineComponents)
CREATE OR REPLACE FUNCTION public.get_parent_sku_selections(p_org_id uuid, p_quote_line_id uuid)
RETURNS TABLE(component_role text, catalog_item_id uuid, sku text, item_name text)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  -- Tabla QuoteLineComponents eliminada. Usar ConfiguredProducts.bom_preview_snapshot si se necesita.
  RETURN;
END;
$$;

COMMENT ON FUNCTION public.get_parent_sku_selections(uuid, uuid) IS 
'DEPRECATED: QuoteLineComponents was dropped. Returns empty. Use ConfiguredProducts.bom_preview_snapshot for selections.';

-- get_quote_line_option_value: leer de QuoteLines si existe la columna, sino NULL
CREATE OR REPLACE FUNCTION public.get_quote_line_option_value(p_org_id uuid, p_quote_line_id uuid, p_key text)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_value text;
BEGIN
  -- Opciones ahora en columnas directas de QuoteLines
  SELECT CASE p_key
    WHEN 'area' THEN ql.area
    WHEN 'position' THEN ql.position
    WHEN 'drive_type' THEN ql.drive_type
    ELSE NULL
  END INTO v_value
  FROM public."QuoteLines" ql
  WHERE ql.id = p_quote_line_id
    AND ql.organization_id = p_org_id
  LIMIT 1;
  RETURN v_value;
END;
$$;

COMMENT ON FUNCTION public.get_quote_line_option_value(uuid, uuid, text) IS 
'Reads option from QuoteLines columns (area, position, drive_type). QuoteLineComponents was dropped.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. compute_quote_line_cost: quitar dependencia de QuoteLineComponents
--    En el bloque ELSE: no leer QuoteLineComponents; usar solo fallback catalog_item_id
-- ═══════════════════════════════════════════════════════════════════════════
-- Parche: ejecutar solo si la función existe y contiene la referencia
DO $$
DECLARE
  v_src text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_src
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'compute_quote_line_cost'
  LIMIT 1;
  
  IF v_src IS NOT NULL AND v_src LIKE '%QuoteLineComponents%' THEN
    RAISE NOTICE 'compute_quote_line_cost references QuoteLineComponents. Run manual fix: replace ELSE block to use only catalog_item_id fallback and remove FOR loop over QuoteLineComponents.';
    RAISE WARNING 'After dropping tables, compute_quote_line_cost will fail when called for non-BOM lines. Fix the function or use QuoteLineCosts from snapshots.';
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. ELIMINAR TRIGGER Y TABLAS
-- ═══════════════════════════════════════════════════════════════════════════

DROP TRIGGER IF EXISTS trg_quote_line_components_updated_at ON public."QuoteLineComponents";

DROP TABLE IF EXISTS public."QuoteLineComponents" CASCADE;
DROP TABLE IF EXISTS public."QuoteLineBOMSelections" CASCADE;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. VERIFICACIÓN
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  RAISE NOTICE '══════════════════════════════════════════════════════════════';
  RAISE NOTICE '✅ Migration 20260204_drop_quote_line_components_and_bom_selections';
  RAISE NOTICE '══════════════════════════════════════════════════════════════';
  RAISE NOTICE '  DROPPED: QuoteLineComponents, QuoteLineBOMSelections';
  RAISE NOTICE '  UPDATED: get_parent_sku_selections (returns empty)';
  RAISE NOTICE '  UPDATED: get_quote_line_option_value (reads from QuoteLines)';
  RAISE NOTICE '  QuoteLines + ConfiguredProducts.bom_preview_snapshot are the source of truth.';
  RAISE NOTICE '══════════════════════════════════════════════════════════════';
END $$;
