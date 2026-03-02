-- ============================================================
-- BOM Roles Tab: schema additions
-- ============================================================

-- 1. Add role_type classification column to CatalogItemRoles
ALTER TABLE public."CatalogItemRoles"
  ADD COLUMN IF NOT EXISTS role_type TEXT NOT NULL DEFAULT 'both';

ALTER TABLE public."CatalogItemRoles"
  ADD CONSTRAINT catalogitemroles_role_type_check
  CHECK (role_type IN ('parent_only', 'child_only', 'both'));

-- 2. Seed role_type based on known child-only roles from codebase VALID_CHILD_ROLES
UPDATE public."CatalogItemRoles"
SET role_type = 'child_only'
WHERE role_code IN (
  'adapter', 'end_cap', 'fastener', 'idler', 'chain_stop', 'chain_tensioner',
  'filler', 'chain', 'belt', 'belt_connector', 'hem_weight', 'brush',
  'accessory', 'carrier', 'consumable', 'hook', 'mounting_clip', 'bearing',
  'connector', 'end_plug', 'guide', 'rail_connector', 'spring', 'stopper'
);

-- 3. Mark structural roles as parent_only
UPDATE public."CatalogItemRoles"
SET role_type = 'parent_only'
WHERE role_code IN (
  'tube', 'track', 'headbox', 'cassette', 'top_rail', 'side_channel',
  'bottom_bar', 'bottom_channel'
);

-- Everything else stays 'both' (drive, motor, fabric, wand, tape, etc.)

-- 4. Junction table: "role X can be child of role Y" (global, same as CatalogItemRoles)
CREATE TABLE IF NOT EXISTS public."RoleDependencies" (
  role_code        TEXT NOT NULL REFERENCES public."CatalogItemRoles"(role_code) ON DELETE CASCADE,
  parent_role_code TEXT NOT NULL REFERENCES public."CatalogItemRoles"(role_code) ON DELETE CASCADE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (role_code, parent_role_code)
);

-- 5. Seed default dependencies
INSERT INTO public."RoleDependencies" (role_code, parent_role_code) VALUES
  ('adapter',          'tube'),
  ('end_cap',          'tube'),
  ('bearing',          'tube'),
  ('end_plug',         'tube'),
  ('adapter',          'drive'),
  ('chain',            'drive'),
  ('chain_stop',       'drive'),
  ('chain_tensioner',  'drive'),
  ('mounting_clip',    'bracket'),
  ('fastener',         'bracket'),
  ('filler',           'side_channel'),
  ('brush',            'side_channel'),
  ('guide',            'side_channel')
ON CONFLICT DO NOTHING;

SELECT 1;
