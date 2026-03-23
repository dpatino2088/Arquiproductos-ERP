-- Allow invoice creation for roles with financial create/write permissions.
-- Includes Sales Coordinator via finance.create.

CREATE OR REPLACE FUNCTION public.can_write_financials_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public."AppUsers" au
    WHERE au.auth_user_id = auth.uid()
      AND au.organization_id = p_org_id
      AND COALESCE(au.deleted, false) = false
      AND (
        au.role_code = 'superadmin'
        OR EXISTS (
          SELECT 1
          FROM public."AppUserRolePermissions" arp
          WHERE arp.role_code = au.role_code
            AND arp.permission_code IN (
              'finance.create',
              'finance.write',
              'financials.create',
              'financials.write'
            )
        )
      )
  );
$$;

GRANT EXECUTE ON FUNCTION public.can_write_financials_org(uuid) TO authenticated;

DROP POLICY IF EXISTS dealer_invoices_write ON public."DealerInvoices";
CREATE POLICY dealer_invoices_write ON public."DealerInvoices"
  FOR ALL
  TO authenticated
  USING (public.can_write_financials_org(organization_id))
  WITH CHECK (public.can_write_financials_org(organization_id));

INSERT INTO public."AppUserRolePermissions" (role_code, permission_code)
SELECT 'sales_coordinator', p.code
FROM public."Permissions" p
WHERE p.code = 'finance.create'
ON CONFLICT DO NOTHING;
