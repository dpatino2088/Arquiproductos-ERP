-- Fix RLS for CatalogItemComponents (allow org members to manage)
-- Run in Supabase SQL editor

BEGIN;

-- Ensure RLS is enabled
ALTER TABLE public."CatalogItemComponents" ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any (safe)
DROP POLICY IF EXISTS "catalogitemcomponents_select_own_org" ON public."CatalogItemComponents";
DROP POLICY IF EXISTS "catalogitemcomponents_write_own_org" ON public."CatalogItemComponents";

-- Read policy
CREATE POLICY "catalogitemcomponents_select_own_org"
  ON public."CatalogItemComponents"
  FOR SELECT
  USING (
    public.is_org_user_superadmin("organization_id")
    OR public.is_org_user_member("organization_id")
  );

-- Write policy (insert/update/delete)
CREATE POLICY "catalogitemcomponents_write_own_org"
  ON public."CatalogItemComponents"
  FOR ALL
  USING (
    (public.is_org_user_superadmin("organization_id")
     OR public.is_org_user_member("organization_id"))
    AND deleted = false
  )
  WITH CHECK (
    public.is_org_user_superadmin("organization_id")
    OR public.is_org_user_member("organization_id")
  );

COMMIT;
