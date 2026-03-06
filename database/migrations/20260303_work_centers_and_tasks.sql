-- ============================================================================
-- Work Centers, Work Order Tasks, and Task Lines
-- Adds workstation routing to the Manufacturing module
-- ============================================================================
SET search_path = public;

-- --------------------------------------------------------------------------
-- 1. WorkCenters — physical stations (Cut Profile, Cut Roll, Pick, Assembly)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "WorkCenters" (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
  code          text NOT NULL,
  name          text NOT NULL,
  description   text,
  sequence      int NOT NULL DEFAULT 0,
  routing_rule  jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active     boolean NOT NULL DEFAULT true,
  deleted       boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, code)
);

ALTER TABLE "WorkCenters" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wc_select" ON "WorkCenters";
CREATE POLICY "wc_select" ON "WorkCenters"
  FOR SELECT TO authenticated
  USING (deleted = false AND public.is_org_member(organization_id));

DROP POLICY IF EXISTS "wc_insert" ON "WorkCenters";
CREATE POLICY "wc_insert" ON "WorkCenters"
  FOR INSERT TO authenticated
  WITH CHECK (public.is_org_member(organization_id));

DROP POLICY IF EXISTS "wc_update" ON "WorkCenters";
CREATE POLICY "wc_update" ON "WorkCenters"
  FOR UPDATE TO authenticated
  USING (public.is_org_member(organization_id));

DROP POLICY IF EXISTS "wc_delete" ON "WorkCenters";
CREATE POLICY "wc_delete" ON "WorkCenters"
  FOR DELETE TO authenticated
  USING (public.is_org_member(organization_id));

-- --------------------------------------------------------------------------
-- 2. WorkOrderTasks — one task per station per MO
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "WorkOrderTasks" (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id         uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
  manufacturing_order_id  uuid NOT NULL REFERENCES "ManufacturingOrders"(id) ON DELETE CASCADE,
  work_center_id          uuid NOT NULL REFERENCES "WorkCenters"(id) ON DELETE CASCADE,
  sequence                int NOT NULL DEFAULT 0,
  status                  text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','in_progress','completed')),
  assigned_to             text,
  started_at              timestamptz,
  completed_at            timestamptz,
  deleted                 boolean NOT NULL DEFAULT false,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE "WorkOrderTasks" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wot_select" ON "WorkOrderTasks";
CREATE POLICY "wot_select" ON "WorkOrderTasks"
  FOR SELECT TO authenticated
  USING (deleted = false AND public.is_org_member(organization_id));

DROP POLICY IF EXISTS "wot_insert" ON "WorkOrderTasks";
CREATE POLICY "wot_insert" ON "WorkOrderTasks"
  FOR INSERT TO authenticated
  WITH CHECK (public.is_org_member(organization_id));

DROP POLICY IF EXISTS "wot_update" ON "WorkOrderTasks";
CREATE POLICY "wot_update" ON "WorkOrderTasks"
  FOR UPDATE TO authenticated
  USING (public.is_org_member(organization_id));

DROP POLICY IF EXISTS "wot_delete" ON "WorkOrderTasks";
CREATE POLICY "wot_delete" ON "WorkOrderTasks"
  FOR DELETE TO authenticated
  USING (public.is_org_member(organization_id));

CREATE INDEX IF NOT EXISTS idx_wot_mo ON "WorkOrderTasks" (manufacturing_order_id);
CREATE INDEX IF NOT EXISTS idx_wot_wc ON "WorkOrderTasks" (work_center_id);

-- --------------------------------------------------------------------------
-- 3. WorkOrderTaskLines — component lines within each task
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "WorkOrderTaskLines" (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id               uuid NOT NULL REFERENCES "WorkOrderTasks"(id) ON DELETE CASCADE,
  bom_instance_line_id  uuid REFERENCES "BOMInstanceLines"(id),
  catalog_item_id       uuid,
  sku                   text,
  item_name             text,
  component_role        text,
  qty                   numeric NOT NULL DEFAULT 1,
  uom                   text NOT NULL DEFAULT 'ea',
  cut_length_mm         numeric,
  cut_width_mm          numeric,
  completed             boolean NOT NULL DEFAULT false,
  completed_at          timestamptz,
  created_at            timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE "WorkOrderTaskLines" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wotl_select" ON "WorkOrderTaskLines";
CREATE POLICY "wotl_select" ON "WorkOrderTaskLines"
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM "WorkOrderTasks" t
      WHERE t.id = task_id AND t.deleted = false
        AND public.is_org_member(t.organization_id)
    )
  );

DROP POLICY IF EXISTS "wotl_insert" ON "WorkOrderTaskLines";
CREATE POLICY "wotl_insert" ON "WorkOrderTaskLines"
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM "WorkOrderTasks" t
      WHERE t.id = task_id
        AND public.is_org_member(t.organization_id)
    )
  );

DROP POLICY IF EXISTS "wotl_update" ON "WorkOrderTaskLines";
CREATE POLICY "wotl_update" ON "WorkOrderTaskLines"
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM "WorkOrderTasks" t
      WHERE t.id = task_id
        AND public.is_org_member(t.organization_id)
    )
  );

CREATE INDEX IF NOT EXISTS idx_wotl_task ON "WorkOrderTaskLines" (task_id);

-- --------------------------------------------------------------------------
-- 4. Seed default Work Centers for every existing organization
-- --------------------------------------------------------------------------
INSERT INTO "WorkCenters" (organization_id, code, name, description, sequence, routing_rule)
SELECT
  o.id,
  v.code,
  v.name,
  v.description,
  v.seq,
  v.rule::jsonb
FROM "Organizations" o
CROSS JOIN (VALUES
  ('CUT-PROFILE', 'Cut Profile',  'Cut linear profiles (tubes, headbox, side channels, bottom bars)', 10, '{"measure_basis":"linear","is_roll":false}'),
  ('CUT-ROLL',    'Cut Roll',     'Cut roll materials (fabric, film, vinyl)',                          20, '{"is_roll":true}'),
  ('PICK',        'Pick List',    'Pick unit components from inventory',                               30, '{"measure_basis":"unit"}'),
  ('ASSEMBLY',    'Assembly',     'Final assembly and packing',                                        40, '{"is_assembly":true}')
) AS v(code, name, description, seq, rule)
WHERE NOT EXISTS (
  SELECT 1 FROM "WorkCenters" wc
  WHERE wc.organization_id = o.id AND wc.code = v.code
);

-- --------------------------------------------------------------------------
-- 5. generate_work_orders_for_mo(p_mo_id) — routes BOM lines to stations
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_work_orders_for_mo(p_mo_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mo          record;
  v_org_id      uuid;
  v_wc          record;
  v_task_id     uuid;
  v_line        record;
  v_matched     boolean;
  v_rule        jsonb;
  v_task_count  int := 0;
  v_line_count  int := 0;
  v_assembly_id uuid;
BEGIN
  SELECT mo.*, mo.organization_id AS org_id
  INTO v_mo
  FROM "ManufacturingOrders" mo
  WHERE mo.id = p_mo_id AND mo.deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  v_org_id := v_mo.org_id;

  IF EXISTS (SELECT 1 FROM "WorkOrderTasks" WHERE manufacturing_order_id = p_mo_id AND deleted = false) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Work order tasks already exist for this MO');
  END IF;

  FOR v_wc IN
    SELECT * FROM "WorkCenters"
    WHERE organization_id = v_org_id AND is_active = true AND deleted = false
    ORDER BY sequence
  LOOP
    v_rule := v_wc.routing_rule;

    IF (v_rule->>'is_assembly')::boolean IS TRUE THEN
      INSERT INTO "WorkOrderTasks" (organization_id, manufacturing_order_id, work_center_id, sequence, status)
      VALUES (v_org_id, p_mo_id, v_wc.id, v_wc.sequence, 'pending')
      RETURNING id INTO v_assembly_id;
      v_task_count := v_task_count + 1;

      INSERT INTO "WorkOrderTaskLines" (task_id, bom_instance_line_id, catalog_item_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm)
      SELECT
        v_assembly_id,
        bil.id,
        bil.resolved_part_id,
        ci.sku,
        ci.name,
        bil.part_role,
        bil.qty,
        bil.uom,
        bil.cut_length_mm,
        bil.cut_width_mm
      FROM "BOMInstanceLines" bil
      JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
      LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
      WHERE bi.manufacturing_order_id = p_mo_id
        AND bil.deleted = false;

      v_line_count := v_line_count + (SELECT count(*) FROM "WorkOrderTaskLines" WHERE task_id = v_assembly_id);
      CONTINUE;
    END IF;

    v_task_id := NULL;

    FOR v_line IN
      SELECT
        bil.id AS bil_id,
        bil.resolved_part_id,
        ci.sku,
        ci.name AS item_name,
        bil.part_role,
        bil.qty,
        bil.uom,
        bil.cut_length_mm,
        bil.cut_width_mm,
        ci.measure_basis,
        ci.is_roll
      FROM "BOMInstanceLines" bil
      JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
      LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
      WHERE bi.manufacturing_order_id = p_mo_id
        AND bil.deleted = false
    LOOP
      v_matched := true;

      IF v_rule ? 'measure_basis' THEN
        IF COALESCE(v_line.measure_basis, '') <> (v_rule->>'measure_basis') THEN
          v_matched := false;
        END IF;
      END IF;

      IF v_matched AND v_rule ? 'is_roll' THEN
        IF COALESCE(v_line.is_roll, false) <> (v_rule->>'is_roll')::boolean THEN
          v_matched := false;
        END IF;
      END IF;

      IF v_matched THEN
        IF v_task_id IS NULL THEN
          INSERT INTO "WorkOrderTasks" (organization_id, manufacturing_order_id, work_center_id, sequence, status)
          VALUES (v_org_id, p_mo_id, v_wc.id, v_wc.sequence, 'pending')
          RETURNING id INTO v_task_id;
          v_task_count := v_task_count + 1;
        END IF;

        INSERT INTO "WorkOrderTaskLines" (task_id, bom_instance_line_id, catalog_item_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm)
        VALUES (v_task_id, v_line.bil_id, v_line.resolved_part_id, v_line.sku, v_line.item_name, v_line.part_role, v_line.qty, v_line.uom, v_line.cut_length_mm, v_line.cut_width_mm);
        v_line_count := v_line_count + 1;
      END IF;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'tasks_created', v_task_count, 'lines_created', v_line_count);
END;
$$;

DO $$ BEGIN RAISE NOTICE 'Work Centers and Tasks migration complete'; END $$;
