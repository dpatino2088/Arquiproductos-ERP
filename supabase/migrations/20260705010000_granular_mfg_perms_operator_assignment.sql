-- ============================================================
-- Granular Manufacturing Permissions + Operator Assignment
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- Part 1: Granular manufacturing sub-permissions
-- ────────────────────────────────────────────────────────────
INSERT INTO "Permissions" (code, module, description) VALUES
  ('manufacturing.mo.read',         'manufacturing', 'View Manufacturing Orders list and detail'),
  ('manufacturing.mo.write',        'manufacturing', 'Create and edit Manufacturing Orders'),
  ('manufacturing.wo.read',         'manufacturing', 'View Work Orders list and detail'),
  ('manufacturing.wo.write',        'manufacturing', 'Start, complete, and manage Work Order tasks'),
  ('manufacturing.workstation.read','manufacturing', 'Access Workstation View'),
  ('manufacturing.cutopt.read',     'manufacturing', 'Access Cut Optimization tool'),
  ('manufacturing.calendar.read',   'manufacturing', 'View Production Calendar'),
  ('manufacturing.costs.read',      'manufacturing', 'View costs and pricing in manufacturing context')
ON CONFLICT (code) DO NOTHING;

-- Assign operator-appropriate sub-permissions to the operator role
INSERT INTO "AppUserRolePermissions" (role_code, permission_code) VALUES
  ('operator', 'manufacturing.wo.read'),
  ('operator', 'manufacturing.wo.write'),
  ('operator', 'manufacturing.workstation.read'),
  ('operator', 'manufacturing.cutopt.read')
ON CONFLICT DO NOTHING;

-- Superadmin and admin get ALL sub-permissions
INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
SELECT r.code, p.code
FROM (VALUES ('superadmin'), ('admin')) AS r(code)
CROSS JOIN (
  SELECT code FROM "Permissions"
  WHERE code IN (
    'manufacturing.mo.read', 'manufacturing.mo.write',
    'manufacturing.wo.read', 'manufacturing.wo.write',
    'manufacturing.workstation.read', 'manufacturing.cutopt.read',
    'manufacturing.calendar.read', 'manufacturing.costs.read'
  )
) AS p
ON CONFLICT DO NOTHING;

-- Procurement gets read-only sub-permissions for MO + calendar
INSERT INTO "AppUserRolePermissions" (role_code, permission_code) VALUES
  ('procurement', 'manufacturing.mo.read'),
  ('procurement', 'manufacturing.wo.read'),
  ('procurement', 'manufacturing.calendar.read')
ON CONFLICT DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- Part 2: Operator Assignment on WorkOrderTasks
-- ────────────────────────────────────────────────────────────

-- Add proper FK columns for operator tracking
ALTER TABLE "WorkOrderTasks"
  ADD COLUMN IF NOT EXISTS assigned_to_user_id uuid REFERENCES "AppUsers"(id),
  ADD COLUMN IF NOT EXISTS completed_by_user_id uuid REFERENCES "AppUsers"(id);

CREATE INDEX IF NOT EXISTS idx_wot_assigned_to_user
  ON "WorkOrderTasks" (assigned_to_user_id)
  WHERE assigned_to_user_id IS NOT NULL;

-- ────────────────────────────────────────────────────────────
-- Part 3: Operator ↔ Work Center bridge table
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS "OperatorWorkCenters" (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES "Organizations"(id),
  user_id       uuid NOT NULL REFERENCES "AppUsers"(id),
  work_center_id uuid NOT NULL REFERENCES "WorkCenters"(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, work_center_id)
);

ALTER TABLE "OperatorWorkCenters" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "org_members_can_read_owc"
  ON "OperatorWorkCenters" FOR SELECT
  USING (organization_id = current_setting('app.current_organization_id', true)::uuid);

CREATE POLICY "org_admins_can_manage_owc"
  ON "OperatorWorkCenters" FOR ALL
  USING (organization_id = current_setting('app.current_organization_id', true)::uuid);

-- ────────────────────────────────────────────────────────────
-- Part 4: Helper view — operators with their work centers
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW "v_operators_by_work_center" AS
SELECT
  owc.work_center_id,
  owc.user_id,
  au.display_name,
  au.email,
  au.role_code,
  owc.organization_id
FROM "OperatorWorkCenters" owc
JOIN "AppUsers" au ON au.id = owc.user_id AND au.deleted = false;
