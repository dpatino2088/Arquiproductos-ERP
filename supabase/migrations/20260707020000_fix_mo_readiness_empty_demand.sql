-- ============================================================================
-- Fix material readiness for empty-demand MOs
-- If an MO has no material demand lines, it must not be marked as complete.
-- ============================================================================

SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_mo_material_readiness(p_mo_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_org_id         uuid;
  v_demand         record;
  v_on_hand        numeric;
  v_on_order       numeric;
  v_need           numeric;
  v_has_shortage   boolean := false;
  v_demand_lines   integer := 0;
BEGIN
  SELECT mo.organization_id
    INTO v_org_id
  FROM public."ManufacturingOrders" mo
  WHERE mo.id = p_mo_id
    AND mo.deleted = false;

  IF v_org_id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'MO not found',
      'status', 'incomplete',
      'has_shortage', true
    );
  END IF;

  SELECT COUNT(*)
    INTO v_demand_lines
  FROM public.manufacturing_order_material_demand d
  WHERE d.manufacturing_order_id = p_mo_id;

  -- No BOM/material demand means readiness cannot be "complete".
  IF v_demand_lines = 0 THEN
    RETURN jsonb_build_object(
      'ok', true,
      'status', 'incomplete',
      'has_shortage', true,
      'reason', 'no_material_demand'
    );
  END IF;

  FOR v_demand IN
    SELECT d.catalog_item_id, d.required_qty
    FROM public.manufacturing_order_material_demand d
    WHERE d.manufacturing_order_id = p_mo_id
  LOOP
    v_on_hand := COALESCE((
      SELECT SUM(h.on_hand_qty)
      FROM public.inventory_on_hand h
      WHERE h.organization_id = v_org_id
        AND h.catalog_item_id = v_demand.catalog_item_id
    ), 0);

    v_on_order := COALESCE((
      SELECT SUM(o.on_order_qty)
      FROM public.inventory_on_order o
      WHERE o.organization_id = v_org_id
        AND o.catalog_item_id = v_demand.catalog_item_id
    ), 0);

    v_need := GREATEST(0, (v_demand.required_qty::numeric - v_on_hand - v_on_order));
    IF v_need > 0 THEN
      v_has_shortage := true;
      EXIT;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'status', CASE WHEN v_has_shortage THEN 'incomplete' ELSE 'complete' END,
    'has_shortage', v_has_shortage
  );
END;
$$;

COMMENT ON FUNCTION public.get_mo_material_readiness(uuid) IS
  'Returns MO material readiness. status=complete only when all demand lines are covered and demand exists. MOs with zero demand lines return incomplete.';

