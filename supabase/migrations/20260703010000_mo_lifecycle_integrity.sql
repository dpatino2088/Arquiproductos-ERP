-- ============================================================================
-- MO Lifecycle Integrity
-- 1. Add new enum values: confirmed, procurement, materials_ready
-- 2. Rewrite transition_mo_status with sequencing validation
-- 3. Auto-advance MO to materials_ready when PO received covers all demand
-- 4. Repair stale MOs where tasks are complete but status is behind
-- ============================================================================

SET search_path = public;

-- --------------------------------------------------------------------------
-- 1. Add new enum values
-- --------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'confirmed' AND enumtypid = 'manufacturing_order_status'::regtype) THEN
    ALTER TYPE manufacturing_order_status ADD VALUE 'confirmed' AFTER 'draft';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'procurement' AND enumtypid = 'manufacturing_order_status'::regtype) THEN
    ALTER TYPE manufacturing_order_status ADD VALUE 'procurement' AFTER 'confirmed';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'materials_ready' AND enumtypid = 'manufacturing_order_status'::regtype) THEN
    ALTER TYPE manufacturing_order_status ADD VALUE 'materials_ready' AFTER 'procurement';
  END IF;
END $$;

-- --------------------------------------------------------------------------
-- 2. Rewrite transition_mo_status with sequencing validation
-- --------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.transition_mo_status(uuid, text, uuid, text);

CREATE OR REPLACE FUNCTION public.transition_mo_status(
  p_mo_id      uuid,
  p_new_status text,
  p_user_id    uuid,
  p_user_name  text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mo          record;
  v_from        text;
  v_to          text;
  v_allowed     text[];
  v_readiness   jsonb;
  v_has_shortage boolean;
BEGIN
  SELECT * INTO v_mo FROM "ManufacturingOrders" WHERE id = p_mo_id AND deleted = false;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  v_from := COALESCE(v_mo.status::text, 'draft');
  v_to   := lower(trim(p_new_status));

  -- Valid transition map
  v_allowed := CASE v_from
    WHEN 'draft'            THEN ARRAY['confirmed', 'planned', 'procurement', 'materials_ready', 'in_production', 'cancelled']
    WHEN 'confirmed'        THEN ARRAY['procurement', 'materials_ready', 'planned', 'in_production', 'cancelled', 'draft']
    WHEN 'procurement'      THEN ARRAY['materials_ready', 'in_production', 'cancelled', 'confirmed']
    WHEN 'materials_ready'  THEN ARRAY['in_production', 'cancelled']
    WHEN 'planned'          THEN ARRAY['in_production', 'cancelled', 'draft']
    WHEN 'in_production'    THEN ARRAY['quality_check', 'cancelled']
    WHEN 'quality_check'    THEN ARRAY['ready_for_pickup']
    WHEN 'ready_for_pickup' THEN ARRAY['delivered']
    WHEN 'delivered'        THEN ARRAY['completed']
    WHEN 'completed'        THEN ARRAY[]::text[]
    WHEN 'cancelled'        THEN ARRAY['draft']
    ELSE ARRAY[]::text[]
  END;

  IF NOT (v_to = ANY(v_allowed)) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', format('Invalid transition: %s → %s. Allowed: %s', v_from, v_to, array_to_string(v_allowed, ', ')),
      'from', v_from,
      'to', v_to
    );
  END IF;

  -- Material readiness guard for in_production
  IF v_to = 'in_production' THEN
    v_readiness := public.get_mo_material_readiness(p_mo_id);
    v_has_shortage := COALESCE((v_readiness->>'has_shortage')::boolean, false);
    IF v_has_shortage THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'Materials incomplete. All materials must be on hand or on order before starting production.',
        'from', v_from,
        'to', v_to,
        'material_readiness', v_readiness
      );
    END IF;
  END IF;

  UPDATE "ManufacturingOrders"
  SET status = v_to::manufacturing_order_status,
      updated_at = now(),
      production_started_at = CASE
        WHEN v_to = 'in_production' AND production_started_at IS NULL THEN now()
        ELSE production_started_at
      END,
      completed_at = CASE
        WHEN v_to IN ('delivered', 'completed') AND completed_at IS NULL THEN now()
        ELSE completed_at
      END,
      delivered_at = CASE
        WHEN v_to = 'delivered' AND delivered_at IS NULL THEN now()
        ELSE delivered_at
      END
  WHERE id = p_mo_id AND deleted = false;

  RETURN jsonb_build_object('ok', true, 'from', v_from, 'to', v_to);
END;
$$;

GRANT EXECUTE ON FUNCTION public.transition_mo_status(uuid, text, uuid, text) TO authenticated;

-- --------------------------------------------------------------------------
-- 3. Function: check and auto-advance MOs linked to a PO after receiving
--    Called after receive_purchase_order to update MO status
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_mo_readiness_after_po_receive(p_po_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mo_id     uuid;
  v_mo_status text;
  v_readiness jsonb;
  v_advanced  text[] := ARRAY[]::text[];
BEGIN
  FOR v_mo_id, v_mo_status IN
    SELECT DISTINCT pomo.manufacturing_order_id, mo.status::text
    FROM "PurchaseOrderManufacturingOrders" pomo
    JOIN "ManufacturingOrders" mo ON mo.id = pomo.manufacturing_order_id AND mo.deleted = false
    WHERE pomo.purchase_order_id = p_po_id
      AND pomo.deleted = false
      AND mo.status::text IN ('confirmed', 'procurement')
  LOOP
    v_readiness := public.get_mo_material_readiness(v_mo_id);
    IF COALESCE((v_readiness->>'has_shortage')::boolean, true) = false THEN
      UPDATE "ManufacturingOrders"
      SET status = 'materials_ready'::manufacturing_order_status, updated_at = now()
      WHERE id = v_mo_id AND deleted = false;
      v_advanced := array_append(v_advanced, v_mo_id::text);
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'advanced_count', array_length(v_advanced, 1), 'mo_ids', to_jsonb(v_advanced));
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_mo_readiness_after_po_receive(uuid) TO authenticated;

-- --------------------------------------------------------------------------
-- 4. Repair stale MOs: tasks all completed but status stuck in draft/planned
-- --------------------------------------------------------------------------
UPDATE "ManufacturingOrders" mo
SET status = 'quality_check'::manufacturing_order_status, updated_at = now()
WHERE mo.deleted = false
  AND mo.status::text IN ('draft', 'planned', 'confirmed', 'procurement', 'materials_ready', 'in_production')
  AND EXISTS (
    SELECT 1 FROM "WorkOrderTasks" wot
    WHERE wot.manufacturing_order_id = mo.id AND wot.deleted = false
  )
  AND NOT EXISTS (
    SELECT 1 FROM "WorkOrderTasks" wot
    WHERE wot.manufacturing_order_id = mo.id AND wot.deleted = false AND wot.status != 'completed'
  );

DO $$ BEGIN RAISE NOTICE 'MO lifecycle integrity: new statuses added, transition validation, PO receive hook, stale MOs repaired'; END $$;
