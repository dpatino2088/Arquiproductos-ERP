-- ============================================================================
-- Migration: Fix reject_oneoff_keys — remove jsonpath to avoid "syntax error at or near " " of jsonpath input"
-- Date: 2026-02-13
-- Description: reject_oneoff_keys used jsonb_path_query with a path that triggers
--              PostgreSQL jsonpath parse error. OneOff is disabled; we only need
--              to reject top-level oneoff_* keys. Use jsonb_object_keys only.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.reject_oneoff_keys(p_config jsonb)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_has_oneoff boolean := false;
  v_key text;
BEGIN
  IF p_config IS NULL THEN
    RETURN;
  END IF;

  -- Check top-level keys only (no jsonpath — avoids "syntax error at or near " " of jsonpath input")
  FOR v_key IN SELECT jsonb_object_keys(p_config)
  LOOP
    IF v_key LIKE 'oneoff\_%' ESCAPE '\' THEN
      v_has_oneoff := true;
      EXIT;
    END IF;
  END LOOP;

  IF v_has_oneoff THEN
    RAISE EXCEPTION 'OneOff is disabled. Remove oneoff_* fields from config_snapshot.';
  END IF;
END;
$$;

COMMENT ON FUNCTION public.reject_oneoff_keys(p_config jsonb) IS
  'Raises exception if config jsonb contains any top-level oneoff_* keys (OneOff disabled). Uses jsonb_object_keys only to avoid jsonpath parse errors.';
