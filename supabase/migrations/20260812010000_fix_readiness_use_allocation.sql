-- ============================================================================
-- Fix manufacturing readiness to use ALLOCATED qty (not raw on_hand).
-- Fix trigger to not override post-production statuses.
-- Fix trigger to set completed_at when deriving completed.
-- ============================================================================

SET search_path = public;

DROP FUNCTION IF EXISTS public.get_mo_line_material_readiness(uuid);
DROP FUNCTION IF EXISTS public.get_mo_line_materials_detail(uuid, uuid);

-- ─────────────────────────────────────────────────────────────────────────────
-- A) get_mo_line_material_readiness: use allocation instead of on_hand
-- A line is "ok" when every catalog_item it needs has
-- MO-level allocated_qty >= MO-level total required_qty for that SKU.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_mo_line_material_readiness(p_mo_id uuid)
RETURNS TABLE (
  sales_order_line_id uuid,
  readiness_status    text,
  has_shortage        boolean,
  required_qty        numeric,
  allocated_qty       numeric,
  on_hand_qty         numeric,
  missing_qty         numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH mo_alloc AS (
    SELECT catalog_item_id, SUM(allocated_qty) AS total_alloc
    FROM "InventoryAllocations"
    WHERE manufacturing_order_id = p_mo_id
      AND status = 'reserved'
    GROUP BY catalog_item_id
  ),
  mo_demand AS (
    SELECT catalog_item_id, required_qty
    FROM manufacturing_order_material_demand
    WHERE manufacturing_order_id = p_mo_id
  ),
  sku_ok AS (
    SELECT
      md.catalog_item_id,
      md.required_qty,
      COALESCE(ma.total_alloc, 0) AS allocated_qty,
      CASE WHEN COALESCE(ma.total_alloc, 0) >= md.required_qty - 0.0001
           THEN true ELSE false END AS is_covered
    FROM mo_demand md
    LEFT JOIN mo_alloc ma ON ma.catalog_item_id = md.catalog_item_id
  ),
  mo_lines AS (
    SELECT DISTINCT mol.sales_order_line_id
    FROM "ManufacturingOrderLines" mol
    WHERE mol.manufacturing_order_id = p_mo_id
      AND mol.deleted = false
      AND mol.sales_order_line_id IS NOT NULL
  ),
  line_demand AS (
    SELECT
      bi.sales_order_line_id,
      bil.resolved_part_id AS catalog_item_id,
      SUM(COALESCE(bil.qty, 0)::numeric) AS line_required_qty
    FROM "BOMInstances" bi
    JOIN "BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
    WHERE bi.manufacturing_order_id = p_mo_id
      AND bi.deleted = false
      AND bil.deleted = false
      AND bi.sales_order_line_id IS NOT NULL
      AND bil.resolved_part_id IS NOT NULL
    GROUP BY bi.sales_order_line_id, bil.resolved_part_id
  ),
  line_check AS (
    SELECT
      ld.sales_order_line_id,
      SUM(ld.line_required_qty)                            AS required_qty,
      SUM(COALESCE(so.allocated_qty, 0))                   AS allocated_qty,
      SUM(GREATEST(0, ld.line_required_qty - COALESCE(so.allocated_qty, 0))) AS missing_qty,
      BOOL_AND(COALESCE(so.is_covered, false))             AS all_covered
    FROM line_demand ld
    LEFT JOIN sku_ok so ON so.catalog_item_id = ld.catalog_item_id
    GROUP BY ld.sales_order_line_id
  ),
  org AS (
    SELECT organization_id FROM "ManufacturingOrders"
    WHERE id = p_mo_id AND deleted = false LIMIT 1
  )
  SELECT
    ml.sales_order_line_id,
    CASE
      WHEN lc.required_qty IS NULL OR lc.required_qty = 0 THEN 'incomplete'
      WHEN lc.all_covered THEN 'ok'
      ELSE 'incomplete'
    END AS readiness_status,
    CASE
      WHEN lc.required_qty IS NULL OR lc.required_qty = 0 THEN true
      WHEN lc.all_covered THEN false
      ELSE true
    END AS has_shortage,
    COALESCE(lc.required_qty, 0)   AS required_qty,
    COALESCE(lc.allocated_qty, 0)  AS allocated_qty,
    COALESCE((
      SELECT SUM(h.on_hand_qty)::numeric
      FROM inventory_on_hand h, org
      WHERE h.organization_id = org.organization_id
    ), 0) AS on_hand_qty,
    COALESCE(lc.missing_qty, 0) AS missing_qty
  FROM mo_lines ml
  LEFT JOIN line_check lc ON lc.sales_order_line_id = ml.sales_order_line_id
  ORDER BY ml.sales_order_line_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_mo_line_material_readiness(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- B) get_mo_line_materials_detail: add allocated_qty, change readiness to
--    use allocated instead of on_hand
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_mo_line_materials_detail(
  p_mo_id               uuid,
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
  allocated_qty        numeric,
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
  mo_alloc AS (
    SELECT catalog_item_id, SUM(allocated_qty) AS total_alloc
    FROM "InventoryAllocations"
    WHERE manufacturing_order_id = p_mo_id
      AND status = 'reserved'
    GROUP BY catalog_item_id
  ),
  mo_demand AS (
    SELECT catalog_item_id, required_qty
    FROM manufacturing_order_material_demand
    WHERE manufacturing_order_id = p_mo_id
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
    COALESCE(ma.total_alloc, 0) AS allocated_qty,
    GREATEST(0, md.required_qty - COALESCE(ma.total_alloc, 0)) AS missing_qty,
    CASE
      WHEN COALESCE(ma.total_alloc, 0) >= COALESCE(md.required_qty, l.qty) - 0.0001
        THEN 'ok'
      ELSE 'shortage'
    END AS readiness
  FROM bom_lines l
  LEFT JOIN mo_alloc ma ON ma.catalog_item_id = l.catalog_item_id
  LEFT JOIN mo_demand md ON md.catalog_item_id = l.catalog_item_id
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

-- ─────────────────────────────────────────────────────────────────────────────
-- C) advance_mo_line_status: confirmed gate now uses allocation-based readiness
--    (no code change needed — it calls get_mo_line_material_readiness which
--     was updated above)
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- D) Fix trg_mol_status_derive_mo:
--    1. Guard post-production statuses (QC, ready_for_pickup, delivered)
--    2. Set completed_at when deriving 'completed'
--    3. Set production_started_at when deriving 'in_production'
-- ─────────────────────────────────────────────────────────────────────────────

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

  -- Never override post-production statuses set via transition_mo_status
  IF v_current IN ('quality_check', 'ready_for_pickup', 'delivered') THEN
    RETURN NEW;
  END IF;

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

  IF v_cancelled = v_all_count THEN
    v_new_status := 'cancelled';
  ELSIF v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'completed';
  ELSIF v_in_prod > 0 THEN
    v_new_status := 'in_production';
  ELSIF v_confirmed + v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'materials_ready';
  ELSIF v_reviewed + v_confirmed + v_completed + v_cancelled = v_all_count THEN
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

DROP TRIGGER IF EXISTS trg_mol_status_derive_mo ON public."ManufacturingOrderLines";
CREATE TRIGGER trg_mol_status_derive_mo
  AFTER INSERT OR UPDATE OF status ON public."ManufacturingOrderLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_mol_status_derive_mo();
