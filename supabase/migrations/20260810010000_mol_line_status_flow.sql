-- MOL line-level status flow
-- Statuses: draft → reviewed → confirmed → in_production → completed | cancelled
-- The MO header status is derived from its lines.

SET search_path = public;

-- 1. Drop old CHECK, migrate data, then add new CHECK
ALTER TABLE public."ManufacturingOrderLines"
  DROP CONSTRAINT IF EXISTS "ManufacturingOrderLines_status_check";

UPDATE public."ManufacturingOrderLines"
SET status = 'draft'
WHERE status = 'planned';

ALTER TABLE public."ManufacturingOrderLines"
  ADD CONSTRAINT "ManufacturingOrderLines_status_check"
  CHECK (status = ANY (ARRAY[
    'draft'::text, 'reviewed'::text, 'confirmed'::text,
    'in_production'::text, 'completed'::text, 'cancelled'::text
  ]));

ALTER TABLE public."ManufacturingOrderLines"
  ALTER COLUMN status SET DEFAULT 'draft';

-- 2. RPC to advance a line's status with validation
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
  v_mo   RECORD;
  v_readiness RECORD;
  v_valid_transitions jsonb := '{
    "draft":         ["reviewed", "cancelled"],
    "reviewed":      ["confirmed", "cancelled"],
    "confirmed":     ["in_production", "cancelled"],
    "in_production": ["completed", "cancelled"],
    "completed":     []
  }'::jsonb;
  v_allowed jsonb;
BEGIN
  SELECT mol.*, mo.id AS mo_id, mo.organization_id, mo.status AS mo_status
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

  -- Gate: confirmed requires material readiness = ok
  IF p_new_status = 'confirmed' THEN
    SELECT r.readiness_status INTO v_readiness
    FROM get_mo_line_material_readiness(v_line.mo_id) r
    WHERE r.sales_order_line_id = v_line.sales_order_line_id
    LIMIT 1;

    IF v_readiness IS NULL OR v_readiness.readiness_status != 'ok' THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'Cannot confirm: materials are not ready for this line'
      );
    END IF;
  END IF;

  UPDATE "ManufacturingOrderLines"
  SET status = p_new_status, updated_at = now()
  WHERE id = p_line_id;

  RETURN jsonb_build_object('ok', true, 'status', p_new_status);
END;
$$;

GRANT EXECUTE ON FUNCTION public.advance_mo_line_status(uuid, text) TO authenticated;

-- 3. Trigger: derive MO header status from its lines
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

  IF v_current IS NULL THEN RETURN NEW; END IF;

  SELECT
    count(*),
    count(*) FILTER (WHERE status = 'completed'),
    count(*) FILTER (WHERE status = 'in_production'),
    count(*) FILTER (WHERE status = 'confirmed'),
    count(*) FILTER (WHERE status = 'reviewed'),
    count(*) FILTER (WHERE status = 'cancelled')
  INTO v_all_count, v_completed, v_in_prod, v_confirmed, v_reviewed, v_cancelled
  FROM "ManufacturingOrderLines"
  WHERE manufacturing_order_id = v_mo_id
    AND deleted = false;

  IF v_all_count = 0 THEN RETURN NEW; END IF;

  -- All cancelled
  IF v_cancelled = v_all_count THEN
    v_new_status := 'cancelled';
  -- All completed (excluding cancelled)
  ELSIF v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'completed';
  -- Any in production
  ELSIF v_in_prod > 0 THEN
    v_new_status := 'in_production';
  -- All confirmed or better (but none in_production yet)
  ELSIF v_confirmed + v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'materials_ready';
  -- All reviewed or better
  ELSIF v_reviewed + v_confirmed + v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'confirmed';
  ELSE
    v_new_status := 'draft';
  END IF;

  IF v_new_status IS DISTINCT FROM v_current THEN
    UPDATE "ManufacturingOrders"
    SET status = v_new_status::manufacturing_order_status, updated_at = now()
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

-- 4. Per-line materials detail RPC (BOM breakdown for a single line)
CREATE OR REPLACE FUNCTION public.get_mo_line_materials_detail(
  p_mo_id uuid,
  p_sales_order_line_id uuid
)
RETURNS TABLE (
  bom_instance_line_id uuid,
  catalog_item_id      uuid,
  sku                  text,
  item_name            text,
  part_role            text,
  qty                  numeric,
  uom                  text,
  unit_cost            numeric,
  total_cost           numeric,
  on_hand_qty          numeric,
  on_order_qty         numeric,
  missing_qty          numeric,
  readiness            text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH mo AS (
    SELECT organization_id
    FROM "ManufacturingOrders"
    WHERE id = p_mo_id AND deleted = false
    LIMIT 1
  ),
  bom_lines AS (
    SELECT
      bil.id AS bom_instance_line_id,
      bil.resolved_part_id AS catalog_item_id,
      ci.sku,
      ci.name AS item_name,
      bil.part_role,
      COALESCE(bil.qty, 0)::numeric AS qty,
      bil.uom,
      COALESCE(bil.unit_cost_exw, 0)::numeric AS unit_cost,
      COALESCE(bil.total_cost_exw, 0)::numeric AS total_cost
    FROM "BOMInstances" bi
    JOIN "BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
    LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
    WHERE bi.manufacturing_order_id = p_mo_id
      AND bi.sales_order_line_id = p_sales_order_line_id
      AND bi.deleted = false
      AND bil.deleted = false
      AND bil.resolved_part_id IS NOT NULL
  )
  SELECT
    l.bom_instance_line_id,
    l.catalog_item_id,
    l.sku,
    l.item_name,
    l.part_role,
    l.qty,
    l.uom,
    l.unit_cost,
    l.total_cost,
    COALESCE((
      SELECT SUM(h.on_hand_qty)::numeric
      FROM inventory_on_hand h, mo
      WHERE h.organization_id = mo.organization_id
        AND h.catalog_item_id = l.catalog_item_id
    ), 0) AS on_hand_qty,
    COALESCE((
      SELECT SUM(o.on_order_qty)::numeric
      FROM inventory_on_order o, mo
      WHERE o.organization_id = mo.organization_id
        AND o.catalog_item_id = l.catalog_item_id
    ), 0) AS on_order_qty,
    GREATEST(0, l.qty - COALESCE((
      SELECT SUM(h.on_hand_qty)::numeric
      FROM inventory_on_hand h, mo
      WHERE h.organization_id = mo.organization_id
        AND h.catalog_item_id = l.catalog_item_id
    ), 0)) AS missing_qty,
    CASE
      WHEN l.qty <= COALESCE((
        SELECT SUM(h.on_hand_qty)::numeric
        FROM inventory_on_hand h, mo
        WHERE h.organization_id = mo.organization_id
          AND h.catalog_item_id = l.catalog_item_id
      ), 0) THEN 'ok'
      ELSE 'shortage'
    END AS readiness
  FROM bom_lines l
  ORDER BY
    CASE l.part_role
      WHEN 'fabric' THEN 1
      WHEN 'tube' THEN 2
      WHEN 'motor' THEN 3
      WHEN 'drive' THEN 4
      WHEN 'bracket' THEN 5
      WHEN 'intermediate_bracket' THEN 6
      WHEN 'intermediate_connector' THEN 7
      WHEN 'headbox' THEN 8
      WHEN 'bottom_bar' THEN 9
      WHEN 'bottom_bar_profile' THEN 10
      WHEN 'end_cap' THEN 11
      WHEN 'end_plug' THEN 12
      WHEN 'chain' THEN 13
      WHEN 'track' THEN 14
      WHEN 'carrier' THEN 15
      WHEN 'glider' THEN 16
      WHEN 'hook' THEN 17
      WHEN 'accessory' THEN 18
      ELSE 19
    END,
    l.sku;
$$;

GRANT EXECUTE ON FUNCTION public.get_mo_line_materials_detail(uuid, uuid) TO authenticated;
