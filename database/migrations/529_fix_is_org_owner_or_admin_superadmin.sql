BEGIN;

-- ============================================================
-- Migration: Fix is_org_owner_or_admin to include superadmin role
-- ============================================================
-- OBJECTIVE:
-- Update the is_org_owner_or_admin function to include 'superadmin'
-- in addition to 'owner' and 'admin' roles, so superadmins can manage
-- Companies and other organization-level resources.
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_org_owner_or_admin(p_org_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND ou.role IN ('superadmin', 'owner', 'admin') -- Added 'superadmin'
      AND ou.deleted = false
      AND ou.status = 'active'
  );
END;
$$;

COMMENT ON FUNCTION public.is_org_owner_or_admin IS 'Check if current user is superadmin/owner/admin in organization. SECURITY DEFINER to avoid RLS recursion. Updated to include superadmin role.';

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- Summary:
-- 1. Updated is_org_owner_or_admin to include 'superadmin' role
-- 2. Superadmins can now create/update Companies and other org resources
-- ============================================================
