SET search_path = public;

-- 1. WorkCenters
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

-- 2. WorkOrderTasks
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

-- 3. WorkOrderTaskLines
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

CREATE INDEX IF NOT EXISTS idx_wotl_task ON "WorkOrderTaskLines" (task_id);;
