-- ============================================================================
-- REMOVE color from BOM template matching (canonical flow)
-- ============================================================================
-- Matching is based ONLY on:
-- 1. ProductType (product_type_id)
-- 2. User-selected parent roles (QuoteLineComponents kind='selection')
-- ============================================================================

CREATE OR REPLACE FUNCTION "public"."select_best_bom_template_for_quote_line"(
  "p_org_id" uuid,
  "p_product_type_id" uuid,
  "p_quote_line_id" uuid
) RETURNS uuid
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_best_template_id uuid;
  v_best_score int := -1;
  v_candidate RECORD;
  v_match_score int;
  v_user_roles text[];
BEGIN
  -- 1. Obtener roles seleccionados por el usuario (kind='selection')
  SELECT ARRAY_AGG(DISTINCT qlc.component_role) INTO v_user_roles
  FROM public."QuoteLineComponents" qlc
  WHERE qlc.organization_id = p_org_id
    AND qlc.quote_line_id = p_quote_line_id
    AND qlc.kind = 'selection'
    AND qlc.deleted = false;

  -- Si no hay roles seleccionados, usar array vacío
  v_user_roles := COALESCE(v_user_roles, ARRAY[]::text[]);

  -- 2. Buscar templates por product_type_id
  FOR v_candidate IN
    SELECT 
      bt.id,
      bt.updated_at,
      COALESCE((bt.metadata->>'priority')::int, 0) AS priority
    FROM public."BOMTemplates" bt
    WHERE bt.organization_id = p_org_id
      AND bt.product_type_id = p_product_type_id
      AND bt.deleted = false
      AND bt.archived = false
      AND bt.active = true
    ORDER BY 
      priority DESC,
      bt.updated_at DESC
  LOOP
    -- 3. Score por coincidencias de roles
    SELECT COUNT(*) INTO v_match_score
    FROM public."BOMTemplateSlots" slots
    WHERE slots.organization_id = p_org_id
      AND slots.bom_template_id = v_candidate.id
      AND slots.item_role = ANY(v_user_roles);

    IF v_match_score > v_best_score THEN
      v_best_score := v_match_score;
      v_best_template_id := v_candidate.id;
    END IF;
  END LOOP;

  -- 4. Fallback: primer template por ProductType
  IF v_best_template_id IS NULL THEN
    SELECT bt.id INTO v_best_template_id
    FROM public."BOMTemplates" bt
    WHERE bt.organization_id = p_org_id
      AND bt.product_type_id = p_product_type_id
      AND bt.deleted = false
      AND bt.archived = false
      AND bt.active = true
    ORDER BY 
      COALESCE((bt.metadata->>'priority')::int, 0) DESC,
      bt.updated_at DESC
    LIMIT 1;
  END IF;

  RETURN v_best_template_id;
END;
$$;
