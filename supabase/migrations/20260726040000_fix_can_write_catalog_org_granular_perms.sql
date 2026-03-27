-- Fix: can_write_catalog_org and can_read_catalog_org must recognize the granular
-- catalog.items.* permission codes introduced in 20260725010000_catalog_items_bom_permissions.sql.
-- Without this, a user who only has catalog.items.write (but not the legacy catalog.write)
-- would silently fail on UPDATE due to RLS blocking the query.

CREATE OR REPLACE FUNCTION public.can_read_catalog_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'catalog.read',
      'catalog.create',
      'catalog.edit',
      'catalog.delete',
      'catalog.write',
      -- granular Items sub-permissions
      'catalog.items.read',
      'catalog.items.write',
      'catalog.items.create',
      'catalog.items.edit',
      'catalog.items.archive',
      'catalog.items.delete',
      -- granular BOM sub-permissions
      'catalog.bom.read',
      'catalog.bom.write',
      'catalog.bom.create',
      'catalog.bom.edit',
      'catalog.bom.archive',
      'catalog.bom.delete'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_write_catalog_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'catalog.create',
      'catalog.edit',
      'catalog.delete',
      'catalog.write',
      -- granular Items write sub-permissions
      'catalog.items.write',
      'catalog.items.create',
      'catalog.items.edit',
      'catalog.items.delete',
      -- granular BOM write sub-permissions
      'catalog.bom.write',
      'catalog.bom.create',
      'catalog.bom.edit',
      'catalog.bom.delete'
    ]::text[]
  );
$$;
