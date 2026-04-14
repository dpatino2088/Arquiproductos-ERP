-- ============================================================================
-- MO/MOL alignment for materials readiness
-- - Add materials_ready to ManufacturingOrderLines status model
-- - Align line transition flow and MO derivation trigger
-- - Sync MO + MOL after PO receipts when readiness is fully covered
-- ============================================================================

SET search_path = public;

-- 1) Expand MOL status model
ALTER TABLE public."ManufacturingOrderLines"
  DROP CONSTRAINT IF EXISTS "ManufacturingOrderLines_status_check";

ALTER TABLE public."ManufacturingOrderLines"
  ADD CONSTRAINT "ManufacturingOrderLines_status_check"
  CHECK (status = ANY (ARRAY[
    'draft'::text,
    'reviewed'::text,
    'confirmed'::text,
    'materials_ready'::text,
    'in_production'::text,
    'completed'::text,
    'cancelled'::text
  ]));

-- Backfill: if MO is already materials_ready, confirmed lines should reflect it.
UPDATE public."ManufacturingOrderLines" mol
SET status = 'materials_ready',
    updated_at = now()
FROM public."ManufacturingOrders" mo
WHERE mo.id = mol.manufacturing_order_id
  AND mo.deleted = false
  AND mol.deleted = false
  AND mo.status::text = 'materials_ready'
  AND mol.status = 'confirmed';

-- 2) Line transition flow (with intermediate materials_ready state)
CREATE OR REPLACE FUNCTION public.advance_mo_line_status(
  p_line_id uuid,
  p_new_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_line RECORD;
  v_readiness RECORD;
  v_wo_result jsonb;
  v_valid_transitions jsonb := '{
    "draft":           ["reviewed", "cancelled"],
    "reviewed":        ["confirmed", "cancelled"],
    "confirmed":       ["materials_ready", "cancelled"],
    "materials_ready": ["in_production", "cancelled"],
    "in_production":   ["completed", "cancelled"],
    "completed":       []
  }'::jsonb;
  v_allowed jsonb;
BEGIN
  SELECT mol.*, mo.id AS mo_id
  INTO v_line
  FROM "ManufacturingOrderLines" mol
  JOIN "ManufacturingOrders" mo ON mo.id = mol.manufacturing_order_id
  WHERE mol.id = p_line_id
    AND mol.deleted = false
    AND mo.deleted = false;

  IF v_line IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Line not found');
  END IF;

  v_allowed := v_valid_transitions -> v_line.status;
  IF v_allowed IS NULL OR NOT v_allowed ? p_new_status THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', format('Cannot transition from %s to %s', v_line.status, p_new_status)
    );
  END IF;

  -- Gate: line can only become materials_ready when allocation-based readiness is ok.
  IF p_new_status = 'materials_ready' THEN
    SELECT r.readiness_status INTO v_readiness
    FROM public.get_mo_line_material_readiness(v_line.mo_id) r
    WHERE r.sales_order_line_id = v_line.sales_order_line_id
    LIMIT 1;

    IF v_readiness IS NULL OR v_readiness.readiness_status != 'ok' THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'Cannot mark material ready: materials are not fully allocated for this line'
      );
    END IF;
  END IF;

  UPDATE "ManufacturingOrderLines"
  SET status = p_new_status, updated_at = now()
  WHERE id = p_line_id;

  -- Keep WO generation on confirmed (commercial/engineering confirmation stage).
  IF p_new_status = 'confirmed' AND v_line.sales_order_line_id IS NOT NULL THEN
    v_wo_result := public.generate_work_orders_for_line(
      v_line.mo_id,
      v_line.sales_order_line_id,
      false
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'status', p_new_status,
    'wo_generated', COALESCE(v_wo_result->>'ok' = 'true', false)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.advance_mo_line_status(uuid, text) TO authenticated;

-- 3) Derive MO header status from line statuses with materials_ready stage
CREATE OR REPLACE FUNCTION public.trg_mol_status_derive_mo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mo_id       uuid;
  v_all_count   int;
  v_completed   int;
  v_in_prod     int;
  v_mat_ready   int;
  v_confirmed   int;
  v_reviewed    int;
  v_cancelled   int;
  v_new_status  text;
  v_current     text;
BEGIN
  v_mo_id := COALESCE(NEW.manufacturing_order_id, OLD.manufacturing_order_id);

  SELECT status::text INTO v_current
  FROM "ManufacturingOrders"
  WHERE id = v_mo_id AND deleted = false;

  IF v_current IS NULL THEN
    RETURN NEW;
  END IF;

  -- Never override post-production statuses set via transition_mo_status.
  IF v_current IN ('quality_check', 'ready_for_pickup', 'delivered') THEN
    RETURN NEW;
  END IF;

  SELECT
    count(*),
    count(*) FILTER (WHERE status = 'completed'),
    count(*) FILTER (WHERE status = 'in_production'),
    count(*) FILTER (WHERE status = 'materials_ready'),
    count(*) FILTER (WHERE status = 'confirmed'),
    count(*) FILTER (WHERE status = 'reviewed'),
    count(*) FILTER (WHERE status = 'cancelled')
  INTO v_all_count, v_completed, v_in_prod, v_mat_ready, v_confirmed, v_reviewed, v_cancelled
  FROM "ManufacturingOrderLines"
  WHERE manufacturing_order_id = v_mo_id
    AND deleted = false;

  IF v_all_count = 0 THEN
    RETURN NEW;
  END IF;

  IF v_cancelled = v_all_count THEN
    v_new_status := 'cancelled';
  ELSIF v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'completed';
  ELSIF v_in_prod > 0 THEN
    v_new_status := 'in_production';
  ELSIF v_mat_ready + v_in_prod + v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'materials_ready';
  ELSIF v_confirmed + v_mat_ready + v_in_prod + v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'confirmed';
  ELSIF v_reviewed + v_confirmed + v_mat_ready + v_in_prod + v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'procurement';
  ELSE
    v_new_status := 'draft';
  END IF;

  IF v_new_status IS DISTINCT FROM v_current THEN
    UPDATE "ManufacturingOrders"
    SET status = v_new_status::manufacturing_order_status,
        updated_at = now(),
        production_started_at = CASE
          WHEN v_new_status = 'in_production' AND production_started_at IS NULL THEN now()
          ELSE production_started_at
        END,
        completed_at = CASE
          WHEN v_new_status = 'completed' AND completed_at IS NULL THEN now()
          ELSE completed_at
        END
    WHERE id = v_mo_id AND deleted = false;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mol_status_derive_mo ON public."ManufacturingOrderLines";
CREATE TRIGGER trg_mol_status_derive_mo
  AFTER INSERT OR UPDATE OF status ON public."ManufacturingOrderLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_mol_status_derive_mo();

-- 4) After PO receipt: sync line readiness and header readiness
CREATE OR REPLACE FUNCTION public.check_mo_readiness_after_po_receive(p_po_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mo_id             uuid;
  v_mo_status         text;
  v_open_lines        int;
  v_changed_lines     int := 0;
  v_total_changed     int := 0;
  v_advanced          text[] := ARRAY[]::text[];
BEGIN
  FOR v_mo_id, v_mo_status IN
    SELECT DISTINCT pomo.manufacturing_order_id, mo.status::text
    FROM "PurchaseOrderManufacturingOrders" pomo
    JOIN "ManufacturingOrders" mo ON mo.id = pomo.manufacturing_order_id AND mo.deleted = false
    WHERE pomo.purchase_order_id = p_po_id
      AND pomo.deleted = false
      AND mo.status::text IN ('confirmed', 'procurement', 'materials_ready')
  LOOP
    -- Promote covered lines to materials_ready.
    WITH ready_lines AS (
      SELECT mol.id
      FROM "ManufacturingOrderLines" mol
      JOIN public.get_mo_line_material_readiness(v_mo_id) lr
        ON lr.sales_order_line_id = mol.sales_order_line_id
      WHERE mol.manufacturing_order_id = v_mo_id
        AND mol.deleted = false
        AND mol.status = 'confirmed'
        AND lr.readiness_status = 'ok'
    )
    UPDATE "ManufacturingOrderLines" mol
    SET status = 'materials_ready',
        updated_at = now()
    FROM ready_lines rl
    WHERE mol.id = rl.id;

    GET DIAGNOSTICS v_changed_lines = ROW_COUNT;
    v_total_changed := v_total_changed + COALESCE(v_changed_lines, 0);

    -- If every non-cancelled line is ready or beyond, set MO header to materials_ready.
    SELECT count(*)
    INTO v_open_lines
    FROM "ManufacturingOrderLines"
    WHERE manufacturing_order_id = v_mo_id
      AND deleted = false
      AND status NOT IN ('materials_ready', 'in_production', 'completed', 'cancelled');

    IF COALESCE(v_open_lines, 0) = 0 THEN
      UPDATE "ManufacturingOrders"
      SET status = 'materials_ready'::manufacturing_order_status,
          updated_at = now()
      WHERE id = v_mo_id
        AND deleted = false
        AND status::text IN ('confirmed', 'procurement');
      v_advanced := array_append(v_advanced, v_mo_id::text);
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'advanced_count', COALESCE(array_length(v_advanced, 1), 0),
    'mo_ids', to_jsonb(v_advanced),
    'line_updates', v_total_changed
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_mo_readiness_after_po_receive(uuid) TO authenticated;
