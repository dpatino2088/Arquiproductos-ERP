-- Merge drapery template pairs (48mm + 60mm) into a single template per combo.
-- The glider component is conditioned on system_size (condition_key/condition_value).
-- After this migration: 30 drapery templates → 15 unified templates.
-- Adding future sizes (54mm, 80mm) only requires new BOMComponents, not new templates.

DO $$
DECLARE
  v_now TIMESTAMPTZ := now();

  -- Each pair: (keep_id, delete_id, new_code)
  -- keep = 48mm template to keep and rename
  -- delete = 60mm template to retire
  v_pairs uuid[][] := ARRAY[
    -- ── Ripple Fold ──────────────────────────────────────────────────
    ARRAY['f13a71a7-ea6f-481f-a7ed-972d398500e0'::uuid, '689b8ec6-f94c-49dc-a374-b7d6a1d896f1'::uuid], -- CENTER_MOTOR_LEFT
    ARRAY['c1510daa-3502-4940-8910-7991dc61bc47'::uuid, '0540c88b-a0b9-46fa-a241-e9a9757f0e24'::uuid], -- CENTER_MOTOR_RIGHT
    ARRAY['eb3e4f21-7c5f-46df-8481-cf81876b6a03'::uuid, '3abc2e9c-b6fd-4c11-aa35-c92fbb6b7dfa'::uuid], -- FIXED
    ARRAY['06bbc63b-b8cc-45a9-bcd2-76fb29539bf2'::uuid, 'c3dbd0df-4274-438e-9cf4-e475c34ff8f9'::uuid], -- MOTOR_LEFT
    ARRAY['106da959-857a-41d9-a4b5-8b4fc61ae21c'::uuid, '93ff811b-3729-45ac-b757-afb5ae8a703b'::uuid], -- MANUAL_CENTER
    ARRAY['bc8b4647-4044-4283-a28c-23a27ee7a64f'::uuid, '499a2f51-6d9e-4de8-89a6-7de94f61e1c8'::uuid], -- MANUAL_LEFT
    ARRAY['a4fe66a7-10fb-4832-afac-686028f6afae'::uuid, '4773b62a-0ae7-475d-a694-f7463d0b426f'::uuid], -- MANUAL_RIGHT
    ARRAY['a7703703-1661-4f0c-81b4-2c4eed835edb'::uuid, '55cac293-567d-40bb-b540-9bd783dbdac4'::uuid], -- MOTOR_RIGHT
    -- ── Wave Drapery ─────────────────────────────────────────────────
    ARRAY['cea451cc-5add-459f-9b5a-895f9c02915b'::uuid, '4f81d027-d831-484d-bc05-17a3b28e0697'::uuid], -- CENTER_MOTOR_LEFT
    ARRAY['3fd2cf38-1e18-41bd-a0c1-9c31773ec1f0'::uuid, 'c189b33b-d7ed-4935-998f-e0054e67b836'::uuid], -- CENTER_MOTOR_RIGHT
    ARRAY['0a7f98a4-82b9-42f6-9d90-79b218e840c0'::uuid, '50364395-5ee1-4187-9b6b-39ffdd760952'::uuid], -- MOTOR_LEFT
    ARRAY['51cc1fcd-bcbc-4788-8236-4c701882e181'::uuid, '8fbac901-695d-4af7-bcf4-4da887828c14'::uuid], -- MANUAL_CENTER
    ARRAY['c803a9aa-c751-4a60-b9f1-436b7e90f672'::uuid, '72175c27-b855-49a5-8a93-5f63fb1673cc'::uuid], -- MANUAL_LEFT
    ARRAY['c6a1486e-5012-4b7d-97f9-152831052eb2'::uuid, '0f6c00f3-d78c-4225-a8cf-ea61dbe11357'::uuid], -- MANUAL_RIGHT
    ARRAY['cdde979a-a78b-4513-ab8e-f3c62ad9ba06'::uuid, 'cf34b1c0-6e16-4612-94a4-76e4552b68a3'::uuid]  -- MOTOR_RIGHT
  ];

  v_new_codes text[] := ARRAY[
    -- Ripple Fold
    'DRAPERY_RIPPLE_FOLD_MOTOR_CENTER_LEFT_WHITE',
    'DRAPERY_RIPPLE_FOLD_MOTOR_CENTER_RIGHT_WHITE',
    'DRAPERY_RIPPLE_FOLD_FIXED_WHITE',
    'DRAPERY_RIPPLE_FOLD_MOTOR_LEFT_WHITE',
    'DRAPERY_RIPPLE_FOLD_MANUAL_CENTER_WHITE',
    'DRAPERY_RIPPLE_FOLD_MANUAL_LEFT_WHITE',
    'DRAPERY_RIPPLE_FOLD_MANUAL_RIGHT_WHITE',
    'DRAPERY_RIPPLE_FOLD_MOTOR_RIGHT_WHITE',
    -- Wave
    'DRAPERY_WAVE_MOTOR_CENTER_LEFT_WHITE',
    'DRAPERY_WAVE_MOTOR_CENTER_RIGHT_WHITE',
    'DRAPERY_WAVE_MOTOR_LEFT_WHITE',
    'DRAPERY_WAVE_MANUAL_CENTER_WHITE',
    'DRAPERY_WAVE_MANUAL_LEFT_WHITE',
    'DRAPERY_WAVE_MANUAL_RIGHT_WHITE',
    'DRAPERY_WAVE_MOTOR_RIGHT_WHITE'
  ];

  v_pair uuid[];
  v_keep_id uuid;
  v_delete_id uuid;
  v_new_code text;
  v_glider_60mm RECORD;
  v_glider_keep_id uuid;
  i int;
BEGIN
  FOR i IN 1..array_length(v_pairs, 1) LOOP
    v_pair := v_pairs[i];
    v_keep_id   := v_pair[1];
    v_delete_id := v_pair[2];
    v_new_code  := v_new_codes[i];

    -- 1. Mark the existing glider on the KEEP template as 48mm conditioned
    SELECT id INTO v_glider_keep_id
    FROM "BOMComponents"
    WHERE bom_template_id = v_keep_id
      AND component_role = 'glider'
      AND deleted = false
      AND parent_component_id IS NULL
    LIMIT 1;

    IF v_glider_keep_id IS NOT NULL THEN
      UPDATE "BOMComponents"
      SET condition_key = 'system_size',
          condition_value = '48mm',
          updated_at = v_now
      WHERE id = v_glider_keep_id;
    END IF;

    -- 2. Get the 60mm glider from the DELETE template and insert it into the KEEP template
    SELECT *
    INTO v_glider_60mm
    FROM "BOMComponents"
    WHERE bom_template_id = v_delete_id
      AND component_role = 'glider'
      AND deleted = false
      AND parent_component_id IS NULL
    LIMIT 1;

    IF v_glider_60mm IS NOT NULL THEN
      INSERT INTO "BOMComponents" (
        organization_id, bom_template_id,
        component_item_id, component_role,
        qty_type, qty_value, qty_delta_mm, qty_spacing_mm, qty_min,
        uom, waste_pct, sort_order,
        is_required, per_panel, auto_select,
        condition_key, condition_value,
        deleted, archived, created_at, updated_at
      ) VALUES (
        v_glider_60mm.organization_id, v_keep_id,
        v_glider_60mm.component_item_id, 'glider',
        v_glider_60mm.qty_type, v_glider_60mm.qty_value, v_glider_60mm.qty_delta_mm,
        v_glider_60mm.qty_spacing_mm, v_glider_60mm.qty_min,
        v_glider_60mm.uom, v_glider_60mm.waste_pct,
        COALESCE(v_glider_keep_id::text, 'x')::text,  -- place after 48mm glider
        true, false, false,
        'system_size', '60mm',
        false, false, v_now, v_now
      );
    END IF;

    -- 3. Rename KEEP template + clear system_size (now universal)
    UPDATE "BOMTemplates"
    SET code       = v_new_code,
        name       = v_new_code,
        system_size = NULL,
        updated_at = v_now
    WHERE id = v_keep_id;

    -- 4. Soft-delete the DELETE template's components and then the template itself
    UPDATE "BOMComponents"
    SET deleted = true, updated_at = v_now
    WHERE bom_template_id = v_delete_id;

    UPDATE "BOMTemplates"
    SET deleted = true, archived = true, updated_at = v_now
    WHERE id = v_delete_id;

    RAISE NOTICE 'Merged pair % → %', i, v_new_code;
  END LOOP;
END $$;
;
