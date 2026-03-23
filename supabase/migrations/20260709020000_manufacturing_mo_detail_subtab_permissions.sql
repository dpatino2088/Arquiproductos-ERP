-- Manufacturing MO detail subtabs (cascading RBAC)
-- Module gate: manufacturing.mo.read|write
-- Detail gate: manufacturing.mo.<subtab>.read|write

INSERT INTO public."Permissions" (code, module, description)
VALUES
  ('manufacturing.mo.overview.read', 'manufacturing', 'View Manufacturing Order overview subtab'),
  ('manufacturing.mo.overview.write', 'manufacturing', 'Edit Manufacturing Order overview actions'),
  ('manufacturing.mo.lines.read', 'manufacturing', 'View Manufacturing Order lines subtab'),
  ('manufacturing.mo.materials.read', 'manufacturing', 'View Manufacturing Order materials subtab'),
  ('manufacturing.mo.work_orders.read', 'manufacturing', 'View Manufacturing Order work orders subtab'),
  ('manufacturing.mo.schedule.read', 'manufacturing', 'View Manufacturing Order schedule subtab'),
  ('manufacturing.mo.schedule.write', 'manufacturing', 'Edit Manufacturing Order schedule subtab'),
  ('manufacturing.mo.notes.read', 'manufacturing', 'View Manufacturing Order notes subtab'),
  ('manufacturing.mo.notes.write', 'manufacturing', 'Edit Manufacturing Order notes subtab'),
  ('manufacturing.mo.timeline.read', 'manufacturing', 'View Manufacturing Order timeline subtab'),
  ('manufacturing.mo.attachments.read', 'manufacturing', 'View Manufacturing Order attachments subtab'),
  ('manufacturing.mo.attachments.write', 'manufacturing', 'Edit Manufacturing Order attachments subtab')
ON CONFLICT (code) DO UPDATE
SET module = EXCLUDED.module,
    description = EXCLUDED.description;

-- Grant all MO detail subtabs to roles that already own MO planning/execution.
INSERT INTO public."AppUserRolePermissions" (role_code, permission_code)
SELECT role_code, permission_code
FROM (
  SELECT 'superadmin'::text AS role_code, unnest(ARRAY[
    'manufacturing.mo.overview.read','manufacturing.mo.overview.write',
    'manufacturing.mo.lines.read',
    'manufacturing.mo.materials.read',
    'manufacturing.mo.work_orders.read',
    'manufacturing.mo.schedule.read','manufacturing.mo.schedule.write',
    'manufacturing.mo.notes.read','manufacturing.mo.notes.write',
    'manufacturing.mo.timeline.read',
    'manufacturing.mo.attachments.read','manufacturing.mo.attachments.write'
  ]::text[]) AS permission_code
  UNION ALL
  SELECT 'admin'::text, unnest(ARRAY[
    'manufacturing.mo.overview.read','manufacturing.mo.overview.write',
    'manufacturing.mo.lines.read',
    'manufacturing.mo.materials.read',
    'manufacturing.mo.work_orders.read',
    'manufacturing.mo.schedule.read','manufacturing.mo.schedule.write',
    'manufacturing.mo.notes.read','manufacturing.mo.notes.write',
    'manufacturing.mo.timeline.read',
    'manufacturing.mo.attachments.read','manufacturing.mo.attachments.write'
  ]::text[])
  UNION ALL
  SELECT 'operator_admin'::text, unnest(ARRAY[
    'manufacturing.mo.overview.read','manufacturing.mo.overview.write',
    'manufacturing.mo.lines.read',
    'manufacturing.mo.materials.read',
    'manufacturing.mo.work_orders.read',
    'manufacturing.mo.schedule.read','manufacturing.mo.schedule.write',
    'manufacturing.mo.notes.read','manufacturing.mo.notes.write',
    'manufacturing.mo.timeline.read',
    'manufacturing.mo.attachments.read','manufacturing.mo.attachments.write'
  ]::text[])
) grants
ON CONFLICT (role_code, permission_code) DO NOTHING;
