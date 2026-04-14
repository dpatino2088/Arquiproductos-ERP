-- Fix: build_bom_preview_snapshot must skip components when user explicitly
-- selects 'NONE' in the configurator, regardless of is_required flag.
-- Previously, 'NONE' was passed through try_parse_uuid() which returned NULL,
-- and then only is_required=false would cause a skip. This meant is_required=true
-- components (side_channel, bottom_channel, headbox) would still appear even
-- when the user chose "Not Included".
--
-- Also sets is_required=false for side_channel/bottom_channel in Roller templates.

-- Step 1: Set is_required=false for side_channel and bottom_channel in Roller templates
UPDATE public."BOMComponents"
SET is_required = false
WHERE id IN (
  SELECT bc.id
  FROM public."BOMComponents" bc
  JOIN public."BOMTemplates" bt ON bt.id = bc.bom_template_id
  JOIN public."ProductTypes" pt ON pt.id = bt.product_type_id
  WHERE bc.deleted = false AND bc.archived = false
    AND bt.is_active = true
    AND bc.parent_component_id IS NULL
    AND lower(bc.component_role) IN ('side_channel', 'bottom_channel')
    AND pt.code = 'roller'
    AND bc.is_required = true
);

-- Step 2: Patch build_bom_preview_snapshot to add explicit NONE check
DO $$
DECLARE
  v_funcdef text;
  v_old_block text;
  v_new_block text;
BEGIN
  SELECT pg_get_functiondef(oid) INTO v_funcdef
  FROM pg_proc
  WHERE proname = 'build_bom_preview_snapshot'
    AND pronamespace = 'public'::regnamespace
  LIMIT 1;

  v_old_block := 'IF v_selected_id IS NOT NULL THEN v_comp.component_item_id := v_selected_id; v_selected := true; END IF;' || chr(10) ||
    '        IF NOT v_selected AND COALESCE(v_comp.is_required,true) = false AND v_role_lower IN (''side_channel'',''bottom_channel'',''headbox'',''bottom_bar'',''motor'',''drive'',''tube'',''track'') THEN CONTINUE; END IF;';

  v_new_block := 'IF v_selected_id IS NOT NULL THEN v_comp.component_item_id := v_selected_id; v_selected := true; END IF;' || chr(10) ||
    '        -- Skip if user explicitly chose Not Included (NONE)' || chr(10) ||
    '        DECLARE v_raw_val text; BEGIN' || chr(10) ||
    '          CASE v_role_lower WHEN ''bottom_bar'' THEN v_raw_val := v_config_inner->>''bottom_bar_item_id''; WHEN ''headbox'' THEN v_raw_val := v_config_inner->>''headbox_item_id''; WHEN ''side_channel'' THEN v_raw_val := v_config_inner->>''side_channel_item_id''; WHEN ''bottom_channel'' THEN v_raw_val := v_config_inner->>''bottom_channel_item_id''; ELSE v_raw_val := NULL; END CASE;' || chr(10) ||
    '          IF v_raw_val IS NOT NULL AND upper(trim(v_raw_val)) = ''NONE'' THEN CONTINUE; END IF;' || chr(10) ||
    '        END;' || chr(10) ||
    '        IF NOT v_selected AND COALESCE(v_comp.is_required,true) = false AND v_role_lower IN (''side_channel'',''bottom_channel'',''headbox'',''bottom_bar'',''motor'',''drive'',''tube'',''track'') THEN CONTINUE; END IF;';

  IF position(v_old_block IN v_funcdef) > 0 THEN
    v_funcdef := replace(v_funcdef, v_old_block, v_new_block);
    EXECUTE v_funcdef;
  END IF;
END;
$$;
