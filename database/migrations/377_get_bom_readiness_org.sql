-- ====================================================
-- Migration 377: Create get_bom_readiness function for organization-specific BOM readiness
-- ====================================================
-- Creates a function that returns BOM readiness summary and items for a specific organization
-- This function uses bom_readiness_report internally and reformats the response
--
-- Date: 2025-01-01
-- ====================================================

-- Drop the function if it exists (in case we're updating)
DROP FUNCTION IF EXISTS public.get_bom_readiness(uuid);

CREATE OR REPLACE FUNCTION public.get_bom_readiness(
  p_organization_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_report jsonb;       -- lo que devuelve bom_readiness_report
  v_items  jsonb;       -- array de items (siempre)
  v_ready_count    int := 0;
  v_blockers_count int := 0;
  v_warnings_count int := 0;
  v_item jsonb;
BEGIN
  -- 1) Llamar función base
  SELECT public.bom_readiness_report(p_organization_id) INTO v_report;

  -- 2) Normalizar: aceptar array o objeto con items
  IF v_report IS NULL THEN
    v_items := '[]'::jsonb;
  ELSIF jsonb_typeof(v_report) = 'array' THEN
    v_items := v_report;
  ELSIF jsonb_typeof(v_report) = 'object' AND (v_report ? 'items') THEN
    v_items := COALESCE(v_report->'items', '[]'::jsonb);
  ELSE
    -- formato inesperado: no romper UI
    v_items := '[]'::jsonb;
  END IF;

  -- 3) Calcular summary desde items (sin asumir estructura)
  IF jsonb_typeof(v_items) = 'array' THEN
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_items)
    LOOP
      IF upper(COALESCE(v_item->>'status','')) IN ('READY','OK') THEN
        v_ready_count := v_ready_count + 1;
      END IF;

      -- blockers / warnings (si no hay issues, no suma)
      IF (v_item ? 'issues') AND jsonb_typeof(v_item->'issues')='array' THEN
        IF EXISTS (
          SELECT 1
          FROM jsonb_array_elements(v_item->'issues') issue
          WHERE upper(COALESCE(issue->>'severity','')) IN ('BLOCKER','CRITICAL')
        ) THEN
          v_blockers_count := v_blockers_count + 1;
        END IF;

        IF EXISTS (
          SELECT 1
          FROM jsonb_array_elements(v_item->'issues') issue
          WHERE upper(COALESCE(issue->>'severity','')) IN ('WARN','WARNING')
        ) THEN
          v_warnings_count := v_warnings_count + 1;
        END IF;
      END IF;
    END LOOP;
  END IF;

  -- 4) Responder en el formato que tu frontend espera:
  --    { summary: {...}, items: [...] }
  RETURN jsonb_build_object(
    'summary', jsonb_build_object(
      'total_product_types', COALESCE(jsonb_array_length(v_items), 0),
      'ready', v_ready_count,
      'blockers', v_blockers_count,
      'warnings', v_warnings_count
    ),
    'items', v_items
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_bom_readiness(uuid) TO authenticated;

COMMENT ON FUNCTION public.get_bom_readiness(uuid) IS
'Returns BOM readiness summary + items for an organization. Wraps bom_readiness_report and normalizes output.';

-- ====================================================
-- VERIFICATION QUERY
-- ====================================================
-- Para probar la función, primero obtén tu organization_id:
-- 
-- SELECT id, organization_name 
-- FROM "Organizations" 
-- WHERE deleted = false 
-- LIMIT 5;
--
-- Luego ejecuta:
-- SELECT public.get_bom_readiness('TU_UUID_AQUI'::uuid) AS report;

