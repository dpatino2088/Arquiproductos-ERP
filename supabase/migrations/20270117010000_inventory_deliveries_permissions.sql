-- Deliveries (outbound dispatch) tab under Inventory.
-- Introduces canonical tab permissions and grants them to the roles that
-- already operate the warehouse / dispatch and manufacturing execution flow.

-- 1) Canonical permissions for the new Inventory > Deliveries tab.
INSERT INTO public."Permissions" (code, module, description)
VALUES
  ('inventory.deliveries.read', 'inventory', 'View Inventory deliveries tab'),
  ('inventory.deliveries.write', 'inventory', 'Edit Inventory deliveries tab')
ON CONFLICT (code) DO UPDATE
SET module = EXCLUDED.module,
    description = EXCLUDED.description;

-- 2) Role grants.
--    superadmin/admin  -> full access (mirrors their inventory.% coverage)
--    procurement       -> warehouse/dispatch operator
--    operator_admin    -> can dispatch finished goods
--    operator_member   -> executes physical delivery
INSERT INTO public."AppUserRolePermissions" (role_code, permission_code)
SELECT role_code, permission_code
FROM (
  SELECT 'superadmin'::text AS role_code, unnest(ARRAY['inventory.deliveries.read','inventory.deliveries.write']::text[]) AS permission_code
  UNION ALL
  SELECT 'admin'::text, unnest(ARRAY['inventory.deliveries.read','inventory.deliveries.write']::text[])
  UNION ALL
  SELECT 'procurement'::text, unnest(ARRAY['inventory.deliveries.read','inventory.deliveries.write']::text[])
  UNION ALL
  SELECT 'operator_admin'::text, unnest(ARRAY['inventory.deliveries.read','inventory.deliveries.write']::text[])
  UNION ALL
  SELECT 'operator_member'::text, unnest(ARRAY['inventory.deliveries.read','inventory.deliveries.write']::text[])
) grants
ON CONFLICT (role_code, permission_code) DO NOTHING;

-- 3) Fold deliveries into the aggregate inventory read/write helpers so that
--    organization-level inventory access also recognizes dispatch operators.
CREATE OR REPLACE FUNCTION public.can_read_inventory_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'inventory.warehouse.read','inventory.warehouse.write',
      'inventory.purchase_orders.read','inventory.purchase_orders.write',
      'inventory.receipts.read','inventory.receipts.write',
      'inventory.deliveries.read','inventory.deliveries.write',
      'inventory.transactions.read','inventory.transactions.write',
      'inventory.adjustments.read','inventory.adjustments.write',
      'inventory.material_demand.read','inventory.material_demand.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_write_inventory_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'inventory.warehouse.write',
      'inventory.purchase_orders.write',
      'inventory.receipts.write',
      'inventory.deliveries.write',
      'inventory.transactions.write',
      'inventory.adjustments.write',
      'inventory.material_demand.write'
    ]::text[]
  );
$$;
