-- ============================================================================
-- Migration: QuoteLines – add sort_order for reordering + RPC for batch update
-- Date: 2026-02-06
-- Description: Add sort_order column to QuoteLines for drag-and-drop reorder.
--   Backfill existing rows by created_at. Create RPC update_quote_line_sort_orders.
-- ============================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. ADD sort_order TO QuoteLines
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'QuoteLines' AND column_name = 'sort_order'
  ) THEN
    ALTER TABLE public."QuoteLines" ADD COLUMN sort_order integer;
    RAISE NOTICE 'Added QuoteLines.sort_order';
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. BACKFILL: set sort_order by created_at per quote_id
-- ═══════════════════════════════════════════════════════════════════════════
WITH ordered AS (
  SELECT id, row_number() OVER (PARTITION BY quote_id ORDER BY created_at ASC NULLS LAST) - 1 AS rn
  FROM public."QuoteLines"
  WHERE sort_order IS NULL
)
UPDATE public."QuoteLines" q
SET sort_order = ordered.rn
FROM ordered
WHERE q.id = ordered.id;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. RPC: batch update sort_order for quote lines
-- ═══════════════════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS public.update_quote_line_sort_orders(uuid, jsonb);

CREATE OR REPLACE FUNCTION public.update_quote_line_sort_orders(
  p_quote_id uuid,
  p_updates jsonb -- Array of {id: uuid, sort_order: integer}
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_update jsonb;
  v_updated_count integer := 0;
  v_result jsonb;
BEGIN
  IF p_quote_id IS NULL THEN
    RAISE EXCEPTION 'quote_id is required';
  END IF;

  IF p_updates IS NULL OR jsonb_array_length(p_updates) = 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'updated_count', 0,
      'message', 'No updates provided'
    );
  END IF;

  FOR v_update IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    UPDATE public."QuoteLines"
    SET
      sort_order = (v_update->>'sort_order')::integer,
      updated_at = now()
    WHERE
      id = (v_update->>'id')::uuid
      AND quote_id = p_quote_id;

    IF FOUND THEN
      v_updated_count := v_updated_count + 1;
    END IF;
  END LOOP;

  v_result := jsonb_build_object(
    'success', true,
    'updated_count', v_updated_count,
    'total_provided', jsonb_array_length(p_updates),
    'message', format('Updated %s of %s quote lines', v_updated_count, jsonb_array_length(p_updates))
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_quote_line_sort_orders(uuid, jsonb) TO authenticated;

COMMENT ON FUNCTION public.update_quote_line_sort_orders(uuid, jsonb) IS
'Batch update sort_order for quote lines. Input: quote_id and JSONB array of {id: uuid, sort_order: integer}.';

COMMIT;
