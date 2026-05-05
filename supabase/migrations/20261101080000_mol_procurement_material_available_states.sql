-- ============================================================================
-- MOL line lifecycle expansion: procurement + material_available states
--
-- New flow per Manufacturing Order Line:
--   draft → reviewed → procurement → material_available → materials_ready
--                  └────────→ materials_ready (direct, when allocation covers)
--   plus the legacy `confirmed` is still valid (engineering-only path).
--
-- Triggers/automation:
--   - When a Purchase Order line is allocated to a MO (PurchaseOrderLines
--     allocation_type = 'manufacturing_order') AND the parent PO is OPEN/
--     PARTIAL/CLOSED → all linked MO lines in `reviewed` move to
--     `procurement`.
--   - When a PO transitions to OPEN/PARTIAL → the same promotion runs for
--     PO lines already allocated to MOs.
--   - After PO receipt: lines in `procurement` whose component on-hand covers
--     demand move to `material_available`.
--   - After allocation: lines in `material_available`, `reviewed` or
--     `confirmed` whose allocation covers demand move to `materials_ready`.
-- ============================================================================

SET search_path = public;

-- ----------------------------------------------------------------------------
-- 1) Expand enum + CHECK constraint
-- ----------------------------------------------------------------------------

ALTER TYPE public.manufacturing_order_status
  ADD VALUE IF NOT EXISTS 'material_available'
  AFTER 'procurement';

ALTER TABLE public."ManufacturingOrderLines"
  DROP CONSTRAINT IF EXISTS "ManufacturingOrderLines_status_check";

ALTER TABLE public."ManufacturingOrderLines"
  ADD CONSTRAINT "ManufacturingOrderLines_status_check"
  CHECK (status = ANY (ARRAY[
    'draft'::text,
    'reviewed'::text,
    'confirmed'::text,
    'procurement'::text,
    'material_available'::text,
    'materials_ready'::text,
    'in_production'::text,
    'completed'::text,
    'cancelled'::text
  ]));

-- ----------------------------------------------------------------------------
-- 2) Update advance_mo_line_status with new transitions
-- ----------------------------------------------------------------------------

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
    "draft":              ["reviewed", "cancelled"],
    "reviewed":           ["draft", "procurement", "material_available", "materials_ready", "confirmed", "cancelled"],
    "confirmed":          ["draft", "procurement", "material_available", "materials_ready", "cancelled"],
    "procurement":        ["reviewed", "material_available", "materials_ready", "cancelled"],
    "material_available": ["procurement", "materials_ready", "cancelled"],
    "materials_ready":    ["draft", "in_production", "cancelled"],
    "in_production":      ["completed", "cancelled"],
    "completed":          [],
    "cancelled":          ["draft"]
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

  IF p_new_status = 'in_production' AND v_line.sales_order_line_id IS NOT NULL THEN
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

-- ----------------------------------------------------------------------------
-- 3) Update MO header derivation trigger to consider new statuses
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_mol_status_derive_mo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mo_id        uuid;
  v_all_count    int;
  v_completed    int;
  v_in_prod      int;
  v_mat_ready    int;
  v_mat_avail    int;
  v_procurement  int;
  v_confirmed    int;
  v_reviewed     int;
  v_cancelled    int;
  v_new_status   text;
  v_current      text;
BEGIN
  v_mo_id := COALESCE(NEW.manufacturing_order_id, OLD.manufacturing_order_id);

  SELECT status::text INTO v_current
  FROM "ManufacturingOrders"
  WHERE id = v_mo_id AND deleted = false;

  IF v_current IS NULL THEN
    RETURN NEW;
  END IF;

  IF v_current IN ('quality_check', 'ready_for_pickup', 'delivered') THEN
    RETURN NEW;
  END IF;

  SELECT
    count(*),
    count(*) FILTER (WHERE status = 'completed'),
    count(*) FILTER (WHERE status = 'in_production'),
    count(*) FILTER (WHERE status = 'materials_ready'),
    count(*) FILTER (WHERE status = 'material_available'),
    count(*) FILTER (WHERE status = 'procurement'),
    count(*) FILTER (WHERE status = 'confirmed'),
    count(*) FILTER (WHERE status = 'reviewed'),
    count(*) FILTER (WHERE status = 'cancelled')
  INTO v_all_count, v_completed, v_in_prod, v_mat_ready, v_mat_avail,
       v_procurement, v_confirmed, v_reviewed, v_cancelled
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
  ELSIF v_mat_avail + v_mat_ready + v_in_prod + v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'material_available';
  ELSIF v_procurement + v_mat_avail + v_mat_ready + v_in_prod + v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'procurement';
  ELSIF v_confirmed + v_procurement + v_mat_avail + v_mat_ready + v_in_prod + v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'confirmed';
  ELSIF v_reviewed + v_confirmed + v_procurement + v_mat_avail + v_mat_ready + v_in_prod + v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'confirmed';
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

-- ----------------------------------------------------------------------------
-- 4) Helper: promote MOL from procurement to material_available based on
--    component on-hand inventory (called from PO receipt hook).
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.sync_mol_material_available_from_inventory(
  p_mo_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_changed_lines int := 0;
  v_org_id uuid;
BEGIN
  SELECT organization_id INTO v_org_id
  FROM "ManufacturingOrders"
  WHERE id = p_mo_id AND deleted = false;

  IF v_org_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  WITH covered_lines AS (
    SELECT DISTINCT mol.id
    FROM "ManufacturingOrderLines" mol
    WHERE mol.manufacturing_order_id = p_mo_id
      AND mol.deleted = false
      AND mol.status IN ('reviewed', 'procurement')
      AND mol.sales_order_line_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM "BOMInstances" bi
        JOIN "BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
        WHERE bi.manufacturing_order_id = p_mo_id
          AND bi.sales_order_line_id = mol.sales_order_line_id
          AND bi.deleted = false
          AND bil.deleted = false
          AND bil.resolved_part_id IS NOT NULL
          AND bil.qty > 0
          AND COALESCE((
            SELECT SUM(h.on_hand_qty)
            FROM inventory_on_hand h
            WHERE h.organization_id = v_org_id
              AND h.catalog_item_id = bil.resolved_part_id
          ), 0) < bil.qty - 0.0001
      )
      AND EXISTS (
        SELECT 1
        FROM "BOMInstances" bi
        JOIN "BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
        WHERE bi.manufacturing_order_id = p_mo_id
          AND bi.sales_order_line_id = mol.sales_order_line_id
          AND bi.deleted = false
          AND bil.deleted = false
          AND bil.resolved_part_id IS NOT NULL
          AND bil.qty > 0
      )
  )
  UPDATE "ManufacturingOrderLines" mol
  SET status = 'material_available',
      updated_at = now()
  FROM covered_lines cl
  WHERE mol.id = cl.id;

  GET DIAGNOSTICS v_changed_lines = ROW_COUNT;

  RETURN jsonb_build_object('ok', true, 'line_updates', v_changed_lines);
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_mol_material_available_from_inventory(uuid) TO authenticated;

-- ----------------------------------------------------------------------------
-- 5) Update sync_mo_material_ready_from_allocations to also accept
--    `material_available` lines.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.sync_mo_material_ready_from_allocations(
  p_mo_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_changed_lines int := 0;
  v_open_lines int := 0;
  v_header_changed int := 0;
BEGIN
  WITH ready_lines AS (
    SELECT mol.id
    FROM "ManufacturingOrderLines" mol
    JOIN public.get_mo_line_material_readiness(p_mo_id) lr
      ON lr.sales_order_line_id = mol.sales_order_line_id
    WHERE mol.manufacturing_order_id = p_mo_id
      AND mol.deleted = false
      AND mol.status IN ('reviewed', 'confirmed', 'procurement', 'material_available')
      AND lr.readiness_status = 'ok'
  )
  UPDATE "ManufacturingOrderLines" mol
  SET status = 'materials_ready',
      updated_at = now()
  FROM ready_lines rl
  WHERE mol.id = rl.id;

  GET DIAGNOSTICS v_changed_lines = ROW_COUNT;

  SELECT count(*)
  INTO v_open_lines
  FROM "ManufacturingOrderLines"
  WHERE manufacturing_order_id = p_mo_id
    AND deleted = false
    AND status NOT IN ('materials_ready', 'in_production', 'completed', 'cancelled');

  IF COALESCE(v_open_lines, 0) = 0 THEN
    UPDATE "ManufacturingOrders"
    SET status = 'materials_ready'::manufacturing_order_status,
        updated_at = now()
    WHERE id = p_mo_id
      AND deleted = false
      AND status::text IN ('draft', 'confirmed', 'procurement', 'material_available');
    GET DIAGNOSTICS v_header_changed = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'line_updates', v_changed_lines,
    'mo_updated', v_header_changed > 0
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_mo_material_ready_from_allocations(uuid) TO authenticated;

-- ----------------------------------------------------------------------------
-- 6) PO receipt hook: also bump procurement → material_available before the
--    materials_ready promotion logic. Uses PurchaseOrderLines.allocation_mo_id
--    to find linked MOs (no pivot table in this DB).
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.check_mo_readiness_after_po_receive(p_po_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mo_id uuid;
  v_avail_sync jsonb;
  v_alloc_sync jsonb;
  v_total_avail int := 0;
  v_total_ready int := 0;
  v_total_mo_updates int := 0;
BEGIN
  FOR v_mo_id IN
    SELECT DISTINCT pol.allocation_mo_id
    FROM "PurchaseOrderLines" pol
    JOIN "ManufacturingOrders" mo ON mo.id = pol.allocation_mo_id AND mo.deleted = false
    WHERE pol.purchase_order_id = p_po_id
      AND pol.allocation_type = 'manufacturing_order'
      AND pol.allocation_mo_id IS NOT NULL
      AND mo.status::text IN ('confirmed', 'procurement', 'material_available', 'materials_ready')
  LOOP
    v_avail_sync := public.sync_mol_material_available_from_inventory(v_mo_id);
    v_total_avail := v_total_avail + COALESCE((v_avail_sync->>'line_updates')::int, 0);

    v_alloc_sync := public.sync_mo_material_ready_from_allocations(v_mo_id);
    v_total_ready := v_total_ready + COALESCE((v_alloc_sync->>'line_updates')::int, 0);
    IF COALESCE((v_alloc_sync->>'mo_updated')::boolean, false) THEN
      v_total_mo_updates := v_total_mo_updates + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'material_available_updates', v_total_avail,
    'materials_ready_updates', v_total_ready,
    'advanced_count', v_total_mo_updates
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_mo_readiness_after_po_receive(uuid) TO authenticated;

-- ----------------------------------------------------------------------------
-- 7) Trigger on PurchaseOrderLines: when a PO line is allocated to a MO and
--    parent PO is OPEN/PARTIAL/CLOSED, bump linked MO lines reviewed→procurement.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_pol_set_mol_procurement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_po_status text;
  v_mo_id uuid;
BEGIN
  IF NEW.allocation_type IS DISTINCT FROM 'manufacturing_order' THEN
    RETURN NEW;
  END IF;

  v_mo_id := NEW.allocation_mo_id;
  IF v_mo_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT status::text INTO v_po_status
  FROM "PurchaseOrders"
  WHERE id = NEW.purchase_order_id;

  IF v_po_status IS NULL THEN
    RETURN NEW;
  END IF;

  IF UPPER(v_po_status) NOT IN ('OPEN', 'PARTIAL', 'CLOSED') THEN
    RETURN NEW;
  END IF;

  UPDATE "ManufacturingOrderLines"
  SET status = 'procurement', updated_at = now()
  WHERE manufacturing_order_id = v_mo_id
    AND deleted = false
    AND status = 'reviewed';

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pol_set_mol_procurement ON public."PurchaseOrderLines";
CREATE TRIGGER trg_pol_set_mol_procurement
  AFTER INSERT OR UPDATE OF allocation_type, allocation_mo_id ON public."PurchaseOrderLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_pol_set_mol_procurement();

-- ----------------------------------------------------------------------------
-- 8) Trigger on PurchaseOrders status change: when transitioning to OPEN/
--    PARTIAL, bump linked MO lines reviewed→procurement (covers the case
--    where allocations existed while the PO was still DRAFT).
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_po_open_promote_linked_mol()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status::text = OLD.status::text THEN
    RETURN NEW;
  END IF;

  IF UPPER(NEW.status::text) NOT IN ('OPEN', 'PARTIAL') THEN
    RETURN NEW;
  END IF;

  UPDATE "ManufacturingOrderLines" mol
  SET status = 'procurement', updated_at = now()
  FROM "PurchaseOrderLines" pol
  WHERE pol.purchase_order_id = NEW.id
    AND pol.allocation_type = 'manufacturing_order'
    AND pol.allocation_mo_id IS NOT NULL
    AND mol.manufacturing_order_id = pol.allocation_mo_id
    AND mol.deleted = false
    AND mol.status = 'reviewed';

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_po_open_promote_linked_mol ON public."PurchaseOrders";
CREATE TRIGGER trg_po_open_promote_linked_mol
  AFTER UPDATE OF status ON public."PurchaseOrders"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_po_open_promote_linked_mol();
