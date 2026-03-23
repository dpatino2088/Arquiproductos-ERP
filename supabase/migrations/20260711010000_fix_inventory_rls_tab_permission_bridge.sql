-- Bridge legacy inventory RLS helpers with tab-level permissions.
-- This fixes update/insert checks for Purchase Orders when roles are granted
-- only with tab-scoped codes (e.g. inventory.purchase_orders.write).

CREATE OR REPLACE FUNCTION public.can_read_inventory_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      -- Legacy broad permissions
      'inventory.read',
      'inventory.create',
      'inventory.edit',
      'inventory.delete',
      'inventory.write',
      -- Tab-level permissions
      'inventory.warehouse.read','inventory.warehouse.write',
      'inventory.purchase_orders.read','inventory.purchase_orders.write',
      'inventory.receipts.read','inventory.receipts.write',
      'inventory.transactions.read','inventory.transactions.write',
      'inventory.adjustments.read','inventory.adjustments.write',
      'inventory.material_demand.read','inventory.material_demand.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_create_inventory_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      -- Legacy broad permissions
      'inventory.create',
      'inventory.write',
      -- Tab-level write permissions
      'inventory.warehouse.write',
      'inventory.purchase_orders.write',
      'inventory.receipts.write',
      'inventory.transactions.write',
      'inventory.adjustments.write',
      'inventory.material_demand.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_update_inventory_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      -- Legacy broad permissions
      'inventory.edit',
      'inventory.write',
      -- Tab-level write permissions
      'inventory.warehouse.write',
      'inventory.purchase_orders.write',
      'inventory.receipts.write',
      'inventory.transactions.write',
      'inventory.adjustments.write',
      'inventory.material_demand.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_delete_inventory_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      -- Legacy broad permissions
      'inventory.delete',
      'inventory.write',
      -- Tab-level write permissions
      'inventory.warehouse.write',
      'inventory.purchase_orders.write',
      'inventory.receipts.write',
      'inventory.transactions.write',
      'inventory.adjustments.write',
      'inventory.material_demand.write'
    ]::text[]
  );
$$;

GRANT EXECUTE ON FUNCTION public.can_read_inventory_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_create_inventory_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_update_inventory_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_delete_inventory_org(uuid) TO authenticated;
