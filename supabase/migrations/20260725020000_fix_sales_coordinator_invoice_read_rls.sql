-- Fix: Sales Coordinator can have financials.invoices.read but still fail RLS on DealerInvoices
-- because can_read_financials_org() did not include that granular read permission.

CREATE OR REPLACE FUNCTION public.can_read_financials_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'financials.read',
      'financials.create',
      'financials.edit',
      'financials.delete',
      'financials.void',
      'financials.write',
      'financials.invoices.read',
      'financials.invoices.create'
    ]::text[]
  );
$$;

GRANT EXECUTE ON FUNCTION public.can_read_financials_org(uuid) TO authenticated;

-- Guardrail: ensure sales_coordinator has the granular invoice read permission in DB.
INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
SELECT 'sales_coordinator', p.code
FROM "Permissions" p
WHERE p.code = 'financials.invoices.read'
ON CONFLICT DO NOTHING;
