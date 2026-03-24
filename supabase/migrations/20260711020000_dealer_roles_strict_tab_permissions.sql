-- Align dealer portal roles with strict tab-level RBAC used by frontend guards.
-- This prevents portal users from losing access when UI checks strict tab codes
-- (directory.* / sales.*) while dealer roles still only have legacy codes.
--
-- Strategy:
-- 1) Ensure required strict permissions exist.
-- 2) Grant strict tab permissions to dealer_member and dealer_manager.
-- 3) Keep legacy permissions for compatibility with older flows.

INSERT INTO public."Permissions" (code, module, description)
VALUES
  ('directory.customers.read',  'directory', 'View Directory customers tab'),
  ('directory.customers.write', 'directory', 'Edit Directory customers tab'),
  ('directory.contacts.read',   'directory', 'View Directory contacts tab'),
  ('directory.contacts.write',  'directory', 'Edit Directory contacts tab'),
  ('sales.quotes.read',         'sales',     'View Sales quotes tab'),
  ('sales.quotes.write',        'sales',     'Edit Sales quotes tab'),
  ('sales.proposals.read',      'sales',     'View Sales proposals tab'),
  ('sales.proposals.write',     'sales',     'Edit Sales proposals tab'),
  ('sales.orders.read',         'sales',     'View Sales orders tab'),
  ('sales.orders.write',        'sales',     'Edit Sales orders tab')
ON CONFLICT (code) DO UPDATE
SET module = EXCLUDED.module,
    description = EXCLUDED.description;

INSERT INTO public."AppUserRolePermissions" (role_code, permission_code)
SELECT grants.role_code, grants.permission_code
FROM (
  -- Dealer Member: can work in Directory + Quotes/Proposals and view Orders.
  SELECT 'dealer_member'::text AS role_code, unnest(ARRAY[
    'dashboard.read',
    'directory.customers.read',
    'directory.customers.write',
    'directory.contacts.read',
    'directory.contacts.write',
    'sales.quotes.read',
    'sales.quotes.write',
    'sales.proposals.read',
    'sales.proposals.write',
    'sales.orders.read'
  ]::text[]) AS permission_code

  UNION ALL

  -- Dealer Manager: full Directory + Sales tabs.
  SELECT 'dealer_manager'::text, unnest(ARRAY[
    'dashboard.read',
    'directory.customers.read',
    'directory.customers.write',
    'directory.contacts.read',
    'directory.contacts.write',
    'sales.quotes.read',
    'sales.quotes.write',
    'sales.proposals.read',
    'sales.proposals.write',
    'sales.orders.read',
    'sales.orders.write'
  ]::text[])
) AS grants
ON CONFLICT (role_code, permission_code) DO NOTHING;
