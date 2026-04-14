CREATE OR REPLACE FUNCTION public.compute_template_cut_breakdown(
  p_bom_template_id uuid,
  p_org_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_cuttable RECORD;
  v_deductor RECORD;
  v_child_ded RECORD;
  v_result jsonb := '[]'::jsonb;
  v_deductions jsonb;
  v_role text;
  v_axis text;
  v_base_label text;
  v_tolerance numeric;
  v_total_deduction numeric;
  v_net_delta numeric;
  v_has_conditional boolean;
  v_parent_uuid uuid;
  v_children_sum numeric;
  v_combined_delta numeric;
BEGIN
  IF p_bom_template_id IS NULL OR p_org_id IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  FOR v_cuttable IN
    SELECT bc.id, bc.component_role, bc.depends_on_role,
           COALESCE(bc.cut_delta_mm, 0) AS tolerance,
           COALESCE(bc.cut_axis, '') AS cut_axis,
           ci.sku AS cuttable_sku,
           COALESCE(bc.qty_type, 'fixed') AS qty_type,
           COALESCE(bc.qty_value, 1) AS qty_value
    FROM public."BOMComponents" bc
    LEFT JOIN public."CatalogItems" ci
      ON ci.id = bc.component_item_id AND ci.organization_id = p_org_id
    WHERE bc.bom_template_id = p_bom_template_id
      AND bc.organization_id = p_org_id
      AND bc.deleted = false AND bc.archived = false
      AND bc.parent_component_id IS NULL
      AND COALESCE(ci.measure_basis, '') IN ('linear', 'area')
    ORDER BY bc.sort_order
  LOOP
    v_role := v_cuttable.component_role;
    v_tolerance := v_cuttable.tolerance;

    IF v_cuttable.cut_axis = 'height'
       OR v_role IN ('side_channel', 'chain', 'belt', 'brush') THEN
      v_axis := 'height';
    ELSE
      v_axis := 'width';
    END IF;

    IF v_cuttable.depends_on_role IS NOT NULL AND v_cuttable.depends_on_role != '' THEN
      v_base_label := INITCAP(REPLACE(v_cuttable.depends_on_role, '_', ' '));
    ELSIF v_axis = 'height' THEN
      v_base_label := 'Height';
    ELSE
      v_base_label := 'Width';
    END IF;

    v_deductions := '[]'::jsonb;
    v_total_deduction := 0;
    v_has_conditional := false;

    -- External deductions: ONLY parent-level components.
    -- Children with matching affects_role are aggregated into their parent's combined delta.
    FOR v_deductor IN
      SELECT bc2.id, bc2.component_role, ci2.sku,
             CASE WHEN v_axis = 'height'
                  THEN COALESCE(ci2.delta_y_mm, 0)
                  ELSE COALESCE(ci2.delta_x_mm, 0)
             END AS self_delta,
             COALESCE(bc2.qty_value, 1) AS qty,
             (bc2.condition_key IS NOT NULL AND bc2.condition_key != '')
               OR COALESCE(bc2.is_required, true) = false
               OR lower(COALESCE(bc2.component_role, '')) LIKE 'intermediate%' AS is_conditional,
             CASE
               WHEN bc2.condition_key IS NOT NULL AND bc2.condition_key != ''
                 THEN COALESCE(bc2.condition_key, '')
               WHEN COALESCE(bc2.is_required, true) = false
                 THEN 'optional'
               WHEN lower(COALESCE(bc2.component_role, '')) LIKE 'intermediate%'
                 THEN 'multi_panel'
               ELSE ''
             END AS cond_key,
             CASE
               WHEN bc2.condition_key IS NOT NULL AND bc2.condition_key != ''
                 THEN COALESCE(bc2.condition_value, '')
               WHEN COALESCE(bc2.is_required, true) = false
                 THEN 'true'
               WHEN lower(COALESCE(bc2.component_role, '')) LIKE 'intermediate%'
                 THEN 'true'
               ELSE ''
             END AS cond_value
      FROM public."BOMComponents" bc2
      LEFT JOIN public."CatalogItems" ci2
        ON ci2.id = bc2.component_item_id AND ci2.organization_id = p_org_id
      WHERE bc2.bom_template_id = p_bom_template_id
        AND bc2.organization_id = p_org_id
        AND bc2.deleted = false AND bc2.archived = false
        AND bc2.parent_component_id IS NULL
        AND v_role = ANY(string_to_array(bc2.affects_role, ','))
        AND COALESCE(bc2.delta_mode, 'subtract') = 'subtract'
      ORDER BY bc2.sort_order
    LOOP
      -- Sum children that ALSO have affects_role for this cuttable
      SELECT COALESCE(SUM(
        (CASE WHEN v_axis = 'height'
              THEN COALESCE(ci_ch.delta_y_mm, 0)
              ELSE COALESCE(ci_ch.delta_x_mm, 0)
         END) * COALESCE(bc_ch.qty_value, 1)
      ), 0)
      INTO v_children_sum
      FROM public."BOMComponents" bc_ch
      LEFT JOIN public."CatalogItems" ci_ch
        ON ci_ch.id = bc_ch.component_item_id AND ci_ch.organization_id = p_org_id
      WHERE bc_ch.parent_component_id = v_deductor.id
        AND bc_ch.organization_id = p_org_id
        AND bc_ch.deleted = false AND bc_ch.archived = false
        AND COALESCE(bc_ch.delta_mode, 'subtract') = 'subtract'
        AND v_role = ANY(string_to_array(bc_ch.affects_role, ','));

      v_combined_delta := v_deductor.self_delta + v_children_sum;

      IF v_combined_delta != 0 THEN
        v_deductions := v_deductions || jsonb_build_object(
          'role', v_deductor.component_role,
          'sku', COALESCE(v_deductor.sku, '?'),
          'delta', v_combined_delta,
          'qty', v_deductor.qty,
          'total', v_combined_delta * v_deductor.qty,
          'conditional', v_deductor.is_conditional,
          'condition_key', v_deductor.cond_key,
          'condition_value', v_deductor.cond_value,
          'source', 'affects_role'
        );
        v_total_deduction := v_total_deduction + (v_combined_delta * v_deductor.qty);
        IF v_deductor.is_conditional THEN v_has_conditional := true; END IF;
      END IF;
    END LOOP;

    -- Own children deductions (children of the cuttable itself)
    v_parent_uuid := v_cuttable.id;
    IF v_parent_uuid IS NOT NULL THEN
      FOR v_child_ded IN
        SELECT bc3.component_role, ci3.sku,
               CASE WHEN v_axis = 'height'
                    THEN COALESCE(ci3.delta_y_mm, 0)
                    ELSE COALESCE(ci3.delta_x_mm, 0)
               END AS delta,
               COALESCE(bc3.qty_value, 1) AS qty,
               (bc3.condition_key IS NOT NULL AND bc3.condition_key != '')
                 OR COALESCE(bc3.is_required, true) = false
                 OR lower(COALESCE(bc3.component_role, '')) LIKE 'intermediate%' AS is_conditional,
               CASE
                 WHEN bc3.condition_key IS NOT NULL AND bc3.condition_key != ''
                   THEN COALESCE(bc3.condition_key, '')
                 WHEN COALESCE(bc3.is_required, true) = false
                   THEN 'optional'
                 WHEN lower(COALESCE(bc3.component_role, '')) LIKE 'intermediate%'
                   THEN 'multi_panel'
                 ELSE ''
               END AS cond_key,
               CASE
                 WHEN bc3.condition_key IS NOT NULL AND bc3.condition_key != ''
                   THEN COALESCE(bc3.condition_value, '')
                 WHEN COALESCE(bc3.is_required, true) = false
                   THEN 'true'
                 WHEN lower(COALESCE(bc3.component_role, '')) LIKE 'intermediate%'
                   THEN 'true'
                 ELSE ''
               END AS cond_value
        FROM public."BOMComponents" bc3
        LEFT JOIN public."CatalogItems" ci3
          ON ci3.id = bc3.component_item_id AND ci3.organization_id = p_org_id
        WHERE bc3.parent_component_id = v_parent_uuid
          AND bc3.organization_id = p_org_id
          AND bc3.deleted = false AND bc3.archived = false
          AND COALESCE(bc3.delta_mode, 'subtract') = 'subtract'
        ORDER BY bc3.sort_order
      LOOP
        IF v_child_ded.delta != 0 THEN
          v_deductions := v_deductions || jsonb_build_object(
            'role', v_child_ded.component_role,
            'sku', COALESCE(v_child_ded.sku, '?'),
            'delta', v_child_ded.delta,
            'qty', v_child_ded.qty,
            'total', v_child_ded.delta * v_child_ded.qty,
            'conditional', v_child_ded.is_conditional,
            'condition_key', v_child_ded.cond_key,
            'condition_value', v_child_ded.cond_value,
            'source', 'own_child'
          );
          v_total_deduction := v_total_deduction + (v_child_ded.delta * v_child_ded.qty);
          IF v_child_ded.is_conditional THEN v_has_conditional := true; END IF;
        END IF;
      END LOOP;
    END IF;

    v_net_delta := v_tolerance - v_total_deduction;

    v_result := v_result || jsonb_build_object(
      'role', v_role,
      'label', INITCAP(REPLACE(v_role, '_', ' ')),
      'sku', COALESCE(v_cuttable.cuttable_sku, '?'),
      'axis', v_axis,
      'base', v_base_label,
      'tolerance', v_tolerance,
      'deductions', v_deductions,
      'net_delta', v_net_delta,
      'has_conditional', v_has_conditional,
      'qty_type', v_cuttable.qty_type,
      'qty_value', v_cuttable.qty_value
    );
  END LOOP;

  RETURN v_result;
END;
$$;;
