-- Create RPC function to batch update BOM template sort_order
-- This is much more efficient than individual updates

BEGIN;

-- Drop function if exists (for idempotency)
DROP FUNCTION IF EXISTS public.update_bom_template_sort_orders(uuid, jsonb);

-- Create function to batch update sort_order for multiple templates
CREATE OR REPLACE FUNCTION public.update_bom_template_sort_orders(
  p_organization_id uuid,
  p_updates jsonb -- Array of {id: uuid, sort_order: integer}
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_update jsonb;
  v_updated_count integer := 0;
  v_result jsonb;
BEGIN
  -- Validate organization_id
  IF p_organization_id IS NULL THEN
    RAISE EXCEPTION 'organization_id is required';
  END IF;

  -- Validate updates array
  IF p_updates IS NULL OR jsonb_array_length(p_updates) = 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'updated_count', 0,
      'message', 'No updates provided'
    );
  END IF;

  -- Update each template's sort_order
  FOR v_update IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    UPDATE public."BOMTemplates"
    SET 
      sort_order = (v_update->>'sort_order')::integer,
      updated_at = now()
    WHERE 
      id = (v_update->>'id')::uuid
      AND organization_id = p_organization_id
      AND deleted = false;
    
    IF FOUND THEN
      v_updated_count := v_updated_count + 1;
    END IF;
  END LOOP;

  -- Return result
  v_result := jsonb_build_object(
    'success', true,
    'updated_count', v_updated_count,
    'total_provided', jsonb_array_length(p_updates),
    'message', format('Updated %s of %s templates', v_updated_count, jsonb_array_length(p_updates))
  );

  RETURN v_result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.update_bom_template_sort_orders(uuid, jsonb) TO authenticated;

COMMENT ON FUNCTION public.update_bom_template_sort_orders(uuid, jsonb) IS 
'Batch update sort_order for multiple BOM templates. 
Input: organization_id and JSONB array of {id: uuid, sort_order: integer}.
Returns: JSONB with success status and updated count.';

COMMIT;
