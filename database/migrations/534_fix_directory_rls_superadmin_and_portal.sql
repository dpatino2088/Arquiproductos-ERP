-- ============================================================
-- Migration: Fix Directory RLS for SuperAdmin and Portal Users
-- ============================================================
-- OBJETIVO:
-- 1) SuperAdmin debe ver TODOS los Contacts y Customers de su organization (sin filtros de created_by)
-- 2) CompanyPortalUsers deben ver solo Contacts y Customers de su company_id
-- 3) OrganizationUsers normales ven por organization_id
-- 4) Alinear lógica entre DirectoryContacts y DirectoryCustomers
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Helper function: Check if user is SuperAdmin in organization
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_org_user_superadmin(p_org_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND ou.role IN ('superadmin', 'owner')
      AND ou.deleted = false
      AND ou.status IN ('active', 'invited')
  );
END;
$$;

COMMENT ON FUNCTION public.is_org_user_superadmin(uuid) IS 
  'Returns true if current user is superadmin/owner in the organization. Bypass all permission checks.';

-- ============================================================
-- 2) Helper function: Check if user is CompanyPortalUser for a company
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_company_portal_user(p_company_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."CompanyPortalUsers" cpu
    WHERE cpu.company_id = p_company_id
      AND (
        cpu.user_id = auth.uid()
        OR cpu.portal_user_email = (auth.jwt() ->> 'email')
      )
      AND cpu.deleted = false
      AND cpu.status IN ('active', 'invited')
  );
END;
$$;

COMMENT ON FUNCTION public.is_company_portal_user(uuid) IS 
  'Returns true if current user is a CompanyPortalUser (portal user) for the given company.';

-- ============================================================
-- 3) Helper function: Check if user is normal OrganizationUser member
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_org_user_member(p_org_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND ou.deleted = false
      AND ou.status IN ('active', 'invited')
  );
END;
$$;

COMMENT ON FUNCTION public.is_org_user_member(uuid) IS 
  'Returns true if current user is an active/invited OrganizationUser member (non-superadmin).';

-- ============================================================
-- 4) Grant execute permissions
-- ============================================================
GRANT EXECUTE ON FUNCTION public.is_org_user_superadmin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_org_user_superadmin(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.is_company_portal_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_company_portal_user(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.is_org_user_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_org_user_member(uuid) TO anon;

-- ============================================================
-- 5) FIX DirectoryCustomers RLS
-- ============================================================
-- Drop old policies
DROP POLICY IF EXISTS dircustomers_select_own_org_or_company ON public."DirectoryCustomers";
DROP POLICY IF EXISTS dir_customers_select ON public."DirectoryCustomers";
DROP POLICY IF EXISTS dir_customers_write ON public."DirectoryCustomers";

-- New SELECT policy with correct hierarchy:
-- 1) SuperAdmin: see ALL in organization (no created_by filter)
-- 2) Portal User: see only their company_id
-- 3) Org User: see by organization_id
CREATE POLICY dircustomers_select_correct
  ON public."DirectoryCustomers"
  FOR SELECT
  USING (
    deleted = false
    AND (
      -- SuperAdmin: see ALL in organization (bypass)
      (
        organization_id IS NOT NULL 
        AND public.is_org_user_superadmin(organization_id)
      )
      OR
      -- Portal User: see only their company
      (
        company_id IS NOT NULL 
        AND public.is_company_portal_user(company_id)
      )
      OR
      -- Normal Org User: see by organization_id
      (
        organization_id IS NOT NULL 
        AND public.is_org_user_member(organization_id)
      )
    )
  );

-- Write policy (similar logic)
CREATE POLICY dircustomers_write_correct
  ON public."DirectoryCustomers"
  FOR ALL
  USING (
    (
      -- SuperAdmin: can write ALL in organization
      (
        organization_id IS NOT NULL 
        AND public.is_org_user_superadmin(organization_id)
      )
      OR
      -- Portal User: can write only their company (if allowed)
      (
        company_id IS NOT NULL 
        AND public.is_company_portal_user(company_id)
      )
      OR
      -- Normal Org User: can write by organization_id
      (
        organization_id IS NOT NULL 
        AND public.is_org_user_member(organization_id)
      )
    )
    AND deleted = false
  )
  WITH CHECK (
    (
      -- Same logic for WITH CHECK
      (
        organization_id IS NOT NULL 
        AND public.is_org_user_superadmin(organization_id)
      )
      OR
      (
        company_id IS NOT NULL 
        AND public.is_company_portal_user(company_id)
      )
      OR
      (
        organization_id IS NOT NULL 
        AND public.is_org_user_member(organization_id)
      )
    )
  );

-- ============================================================
-- 6) FIX DirectoryContacts RLS (ALIGNED with DirectoryCustomers)
-- ============================================================
-- Drop old policies
DROP POLICY IF EXISTS dircontacts_select_own_org_or_company ON public."DirectoryContacts";
DROP POLICY IF EXISTS dir_contacts_select ON public."DirectoryContacts";
DROP POLICY IF EXISTS dir_contacts_write ON public."DirectoryContacts";

-- New SELECT policy with SAME logic as DirectoryCustomers
CREATE POLICY dircontacts_select_correct
  ON public."DirectoryContacts"
  FOR SELECT
  USING (
    deleted = false
    AND (
      -- SuperAdmin: see ALL in organization (bypass)
      (
        organization_id IS NOT NULL 
        AND public.is_org_user_superadmin(organization_id)
      )
      OR
      -- Portal User: see only their company
      (
        company_id IS NOT NULL 
        AND public.is_company_portal_user(company_id)
      )
      OR
      -- Normal Org User: see by organization_id
      (
        organization_id IS NOT NULL 
        AND public.is_org_user_member(organization_id)
      )
    )
  );

-- Write policy (similar logic)
CREATE POLICY dircontacts_write_correct
  ON public."DirectoryContacts"
  FOR ALL
  USING (
    (
      -- SuperAdmin: can write ALL in organization
      (
        organization_id IS NOT NULL 
        AND public.is_org_user_superadmin(organization_id)
      )
      OR
      -- Portal User: can write only their company (if allowed)
      (
        company_id IS NOT NULL 
        AND public.is_company_portal_user(company_id)
      )
      OR
      -- Normal Org User: can write by organization_id
      (
        organization_id IS NOT NULL 
        AND public.is_org_user_member(organization_id)
      )
    )
    AND deleted = false
  )
  WITH CHECK (
    (
      -- Same logic for WITH CHECK
      (
        organization_id IS NOT NULL 
        AND public.is_org_user_superadmin(organization_id)
      )
      OR
      (
        company_id IS NOT NULL 
        AND public.is_company_portal_user(company_id)
      )
      OR
      (
        organization_id IS NOT NULL 
        AND public.is_org_user_member(organization_id)
      )
    )
  );

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- EXPLICACIÓN:
-- 
-- 1) SuperAdmin (role='superadmin' o 'owner'):
--    - Ve TODOS los Contacts y Customers de su organization
--    - NO depende de created_by_user_id
--    - NO depende de permisos finos (bypass completo)
--
-- 2) OrganizationUsers normales:
--    - Ven Contacts y Customers por organization_id
--    - Dependen de permisos RBAC (directory.read, etc)
--
-- 3) CompanyPortalUsers:
--    - Ven SOLO Contacts y Customers de SU company_id
--    - NO ven registros de otras companies
--
-- Las políticas están ALINEADAS entre DirectoryContacts y DirectoryCustomers,
-- usando la MISMA jerarquía de condiciones.
-- ============================================================
