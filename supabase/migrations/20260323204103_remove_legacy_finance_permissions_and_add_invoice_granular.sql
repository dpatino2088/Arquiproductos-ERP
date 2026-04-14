-- Remove legacy finance.* permissions and move to financials-only model.
-- Add granular invoice create permission for role-level assignment.

INSERT INTO public."Permissions" (code, module, description)
VALUES ('financials.invoices.create', 'financials', 'Create invoices')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public."AppUserRolePermissions" (role_code, permission_code)
SELECT r.role_code, p.code
FROM (
  VALUES
    ('superadmin', 'financials.invoices.create'),
    ('admin', 'financials.invoices.create'),
    ('finance', 'financials.invoices.create'),
    ('sales_coordinator', 'financials.invoices.create')
) AS r(role_code, permission_code)
JOIN public."Permissions" p ON p.code = r.permission_code
ON CONFLICT DO NOTHING;

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
              'financials.invoices.create',
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

DELETE FROM public."AppUserRolePermissions"
WHERE permission_code LIKE 'finance.%';

DELETE FROM public."OrganizationUserPermissions"
WHERE permission_code LIKE 'finance.%';

DELETE FROM public."Permissions"
WHERE code LIKE 'finance.%';;
