-- Harden procurement scope + close AppUsers/DealerUsers privilege gaps.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Align procurement permissions to purchasing + inventory + MO overview only
-- ---------------------------------------------------------------------------
WITH desired(permission_code) AS (
  VALUES
    ('catalog.read'),
    ('inventory.warehouse.read'),
    ('inventory.warehouse.write'),
    ('inventory.purchase_orders.read'),
    ('inventory.purchase_orders.write'),
    ('inventory.receipts.read'),
    ('inventory.receipts.write'),
    ('inventory.transactions.read'),
    ('inventory.transactions.write'),
    ('inventory.adjustments.read'),
    ('inventory.adjustments.write'),
    ('inventory.material_demand.read'),
    ('inventory.material_demand.write'),
    ('sales.orders.read'),
    ('manufacturing.mo.read'),
    ('manufacturing.mo.overview.read')
)
DELETE FROM public."AppUserRolePermissions" rp
WHERE rp.role_code = 'procurement'
  AND NOT EXISTS (
    SELECT 1
    FROM desired d
    WHERE d.permission_code = rp.permission_code
  );

INSERT INTO public."AppUserRolePermissions"(role_code, permission_code)
SELECT 'procurement', p.code
FROM public."Permissions" p
WHERE p.code IN (
  'catalog.read',
  'inventory.warehouse.read',
  'inventory.warehouse.write',
  'inventory.purchase_orders.read',
  'inventory.purchase_orders.write',
  'inventory.receipts.read',
  'inventory.receipts.write',
  'inventory.transactions.read',
  'inventory.transactions.write',
  'inventory.adjustments.read',
  'inventory.adjustments.write',
  'inventory.material_demand.read',
  'inventory.material_demand.write',
  'sales.orders.read',
  'manufacturing.mo.read',
  'manufacturing.mo.overview.read'
)
ON CONFLICT (role_code, permission_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2) AppUsers: enable RLS and add scoped write policies
-- ---------------------------------------------------------------------------
ALTER TABLE public."AppUsers" ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_portal_dealer_manager(p_dealer_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."AppUsers" au
    WHERE au.auth_user_id = auth.uid()
      AND au.user_type = 'dealer'
      AND au.dealer_id = p_dealer_id
      AND COALESCE(au.deleted, false) = false
      AND au.status IN ('active', 'invited')
      AND LOWER(COALESCE(au.role_code, '')) IN ('dealer_manager', 'manager', 'member_manager')
  )
  OR EXISTS (
    SELECT 1
    FROM public."DealerUsers" du
    WHERE du.user_id = auth.uid()
      AND du.dealer_id = p_dealer_id
      AND COALESCE(du.deleted, false) = false
      AND LOWER(COALESCE(du.status::text, '')) IN ('active', 'invited')
      AND LOWER(COALESCE(du.role::text, '')) IN ('dealer_manager', 'manager', 'member_manager')
  );
END;
$$;

DROP POLICY IF EXISTS appusers_select_scope ON public."AppUsers";
CREATE POLICY appusers_select_scope
ON public."AppUsers"
FOR SELECT
USING (
  auth.uid() = auth_user_id
  OR (organization_id IS NOT NULL AND public.is_org_user_member_strict(organization_id))
  OR (dealer_id IS NOT NULL AND public.is_dealer_member(dealer_id))
);

DROP POLICY IF EXISTS appusers_insert_scope ON public."AppUsers";
CREATE POLICY appusers_insert_scope
ON public."AppUsers"
FOR INSERT
WITH CHECK (
  (organization_id IS NOT NULL AND public.is_org_owner_or_admin(organization_id))
  OR (user_type = 'dealer' AND dealer_id IS NOT NULL AND public.is_portal_dealer_manager(dealer_id))
);

DROP POLICY IF EXISTS appusers_update_scope ON public."AppUsers";
CREATE POLICY appusers_update_scope
ON public."AppUsers"
FOR UPDATE
USING (
  auth.uid() = auth_user_id
  OR (organization_id IS NOT NULL AND public.is_org_owner_or_admin(organization_id))
  OR (user_type = 'dealer' AND dealer_id IS NOT NULL AND public.is_portal_dealer_manager(dealer_id))
)
WITH CHECK (
  auth.uid() = auth_user_id
  OR (organization_id IS NOT NULL AND public.is_org_owner_or_admin(organization_id))
  OR (user_type = 'dealer' AND dealer_id IS NOT NULL AND public.is_portal_dealer_manager(dealer_id))
);

DROP POLICY IF EXISTS appusers_delete_scope ON public."AppUsers";
CREATE POLICY appusers_delete_scope
ON public."AppUsers"
FOR DELETE
USING (
  organization_id IS NOT NULL
  AND public.is_org_owner_or_admin(organization_id)
);

-- ---------------------------------------------------------------------------
-- 3) DealerUsers: tighten UPDATE policy (remove broad org-member write)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS dealerusers_update_self ON public."DealerUsers";
CREATE POLICY dealerusers_update_self
ON public."DealerUsers"
FOR UPDATE
USING (
  ((user_id = auth.uid()) AND (deleted = false))
  OR public.is_dealer_owner_or_admin(dealer_id)
  OR public.is_portal_dealer_manager(dealer_id)
)
WITH CHECK (
  ((user_id = auth.uid()) AND (deleted = false))
  OR public.is_dealer_owner_or_admin(dealer_id)
  OR public.is_portal_dealer_manager(dealer_id)
);

COMMIT;
