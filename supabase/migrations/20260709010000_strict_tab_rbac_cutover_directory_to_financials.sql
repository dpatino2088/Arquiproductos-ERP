-- Strict Tab-Level RBAC cutover (Directory -> Financials).
-- This migration introduces canonical tab read/write permissions,
-- reseeds key role grants, and aligns RLS helper functions to tab scopes.

-- 1) Canonical tab permissions
INSERT INTO public."Permissions" (code, module, description)
VALUES
  ('directory.customers.read', 'directory', 'View Directory customers tab'),
  ('directory.customers.write', 'directory', 'Edit Directory customers tab'),
  ('directory.contacts.read', 'directory', 'View Directory contacts tab'),
  ('directory.contacts.write', 'directory', 'Edit Directory contacts tab'),

  ('sales.quotes.read', 'sales', 'View Sales quotes tab'),
  ('sales.quotes.write', 'sales', 'Edit Sales quotes tab'),
  ('sales.proposals.read', 'sales', 'View Sales proposals tab'),
  ('sales.proposals.write', 'sales', 'Edit Sales proposals tab'),
  ('sales.orders.read', 'sales', 'View Sales orders tab'),
  ('sales.orders.write', 'sales', 'Edit Sales orders tab'),

  ('inventory.warehouse.read', 'inventory', 'View Inventory warehouse tab'),
  ('inventory.warehouse.write', 'inventory', 'Edit Inventory warehouse tab'),
  ('inventory.purchase_orders.read', 'inventory', 'View Inventory purchase orders tab'),
  ('inventory.purchase_orders.write', 'inventory', 'Edit Inventory purchase orders tab'),
  ('inventory.receipts.read', 'inventory', 'View Inventory receipts tab'),
  ('inventory.receipts.write', 'inventory', 'Edit Inventory receipts tab'),
  ('inventory.transactions.read', 'inventory', 'View Inventory transactions tab'),
  ('inventory.transactions.write', 'inventory', 'Edit Inventory transactions tab'),
  ('inventory.adjustments.read', 'inventory', 'View Inventory adjustments tab'),
  ('inventory.adjustments.write', 'inventory', 'Edit Inventory adjustments tab'),
  ('inventory.material_demand.read', 'inventory', 'View Inventory material demand tab'),
  ('inventory.material_demand.write', 'inventory', 'Edit Inventory material demand tab'),

  ('manufacturing.mo.read', 'manufacturing', 'View Manufacturing orders tab'),
  ('manufacturing.mo.write', 'manufacturing', 'Edit Manufacturing orders tab'),
  ('manufacturing.wo.read', 'manufacturing', 'View Work orders tab'),
  ('manufacturing.wo.write', 'manufacturing', 'Edit Work orders tab'),
  ('manufacturing.calendar.read', 'manufacturing', 'View Manufacturing calendar tab'),
  ('manufacturing.calendar.write', 'manufacturing', 'Edit Manufacturing calendar tab'),
  ('manufacturing.finished_goods.read', 'manufacturing', 'View Finished goods tab'),
  ('manufacturing.finished_goods.write', 'manufacturing', 'Edit Finished goods tab'),
  ('manufacturing.cutopt.read', 'manufacturing', 'View Cut optimization tab'),
  ('manufacturing.cutopt.write', 'manufacturing', 'Edit Cut optimization tab'),

  ('financials.accounts.read', 'financials', 'View Financials AR accounts tab'),
  ('financials.accounts.write', 'financials', 'Edit Financials AR accounts tab'),
  ('financials.invoices.read', 'financials', 'View Financials invoices tab'),
  ('financials.invoices.write', 'financials', 'Edit Financials invoices tab'),
  ('financials.payments.read', 'financials', 'View Financials AR payments tab'),
  ('financials.payments.write', 'financials', 'Edit Financials AR payments tab'),
  ('financials.vendor_accounts.read', 'financials', 'View Financials AP vendor accounts tab'),
  ('financials.vendor_accounts.write', 'financials', 'Edit Financials AP vendor accounts tab'),
  ('financials.purchase_orders.read', 'financials', 'View Financials AP purchase orders tab'),
  ('financials.purchase_orders.write', 'financials', 'Edit Financials AP purchase orders tab'),
  ('financials.bills.read', 'financials', 'View Financials AP bills tab'),
  ('financials.bills.write', 'financials', 'Edit Financials AP bills tab'),
  ('financials.vendor_payments.read', 'financials', 'View Financials AP vendor payments tab'),
  ('financials.vendor_payments.write', 'financials', 'Edit Financials AP vendor payments tab')
ON CONFLICT (code) DO UPDATE
SET module = EXCLUDED.module,
    description = EXCLUDED.description;

-- 2) Strict role grants for targeted internal roles
WITH strict_tab_perms AS (
  SELECT unnest(ARRAY[
    'directory.customers.read','directory.customers.write','directory.contacts.read','directory.contacts.write',
    'sales.quotes.read','sales.quotes.write','sales.proposals.read','sales.proposals.write','sales.orders.read','sales.orders.write',
    'inventory.warehouse.read','inventory.warehouse.write','inventory.purchase_orders.read','inventory.purchase_orders.write',
    'inventory.receipts.read','inventory.receipts.write','inventory.transactions.read','inventory.transactions.write',
    'inventory.adjustments.read','inventory.adjustments.write','inventory.material_demand.read','inventory.material_demand.write',
    'manufacturing.mo.read','manufacturing.mo.write','manufacturing.wo.read','manufacturing.wo.write',
    'manufacturing.calendar.read','manufacturing.calendar.write','manufacturing.finished_goods.read','manufacturing.finished_goods.write',
    'manufacturing.cutopt.read','manufacturing.cutopt.write',
    'financials.accounts.read','financials.accounts.write','financials.invoices.read','financials.invoices.write',
    'financials.payments.read','financials.payments.write','financials.vendor_accounts.read','financials.vendor_accounts.write',
    'financials.purchase_orders.read','financials.purchase_orders.write','financials.bills.read','financials.bills.write',
    'financials.vendor_payments.read','financials.vendor_payments.write'
  ]) AS permission_code
)
DELETE FROM public."AppUserRolePermissions" rp
USING strict_tab_perms stp
WHERE rp.role_code IN ('sales_coordinator', 'finance', 'admin', 'superadmin', 'procurement', 'operator_admin', 'operator_member')
  AND rp.permission_code = stp.permission_code;

INSERT INTO public."AppUserRolePermissions" (role_code, permission_code)
SELECT role_code, permission_code
FROM (
  -- Superadmin/admin: full tab access for scoped modules.
  SELECT 'superadmin'::text AS role_code, p.code AS permission_code
  FROM public."Permissions" p
  WHERE p.code LIKE 'directory.%'
     OR p.code LIKE 'sales.%'
     OR p.code LIKE 'inventory.%'
     OR p.code LIKE 'manufacturing.%'
     OR p.code LIKE 'financials.%'
  UNION ALL
  SELECT 'admin'::text, p.code
  FROM public."Permissions" p
  WHERE p.code LIKE 'directory.%'
     OR p.code LIKE 'sales.%'
     OR p.code LIKE 'inventory.%'
     OR p.code LIKE 'manufacturing.%'
     OR p.code LIKE 'financials.%'

  UNION ALL
  -- Sales Coordinator: directory + sales + invoices only.
  SELECT 'sales_coordinator'::text, unnest(ARRAY[
    'directory.customers.read','directory.customers.write',
    'directory.contacts.read','directory.contacts.write',
    'sales.quotes.read','sales.quotes.write',
    'sales.proposals.read','sales.proposals.write',
    'sales.orders.read','sales.orders.write',
    'financials.invoices.read','financials.invoices.write'
  ]::text[])

  UNION ALL
  -- Finance: full Financials tabs.
  SELECT 'finance'::text, unnest(ARRAY[
    'financials.accounts.read','financials.accounts.write',
    'financials.invoices.read','financials.invoices.write',
    'financials.payments.read','financials.payments.write',
    'financials.vendor_accounts.read','financials.vendor_accounts.write',
    'financials.purchase_orders.read','financials.purchase_orders.write',
    'financials.bills.read','financials.bills.write',
    'financials.vendor_payments.read','financials.vendor_payments.write'
  ]::text[])

  UNION ALL
  -- Procurement: inventory tabs.
  SELECT 'procurement'::text, unnest(ARRAY[
    'inventory.warehouse.read','inventory.warehouse.write',
    'inventory.purchase_orders.read','inventory.purchase_orders.write',
    'inventory.receipts.read','inventory.receipts.write',
    'inventory.transactions.read','inventory.transactions.write',
    'inventory.adjustments.read','inventory.adjustments.write',
    'inventory.material_demand.read','inventory.material_demand.write'
  ]::text[])

  UNION ALL
  -- Operator Admin: manufacturing execution tabs.
  SELECT 'operator_admin'::text, unnest(ARRAY[
    'manufacturing.mo.read','manufacturing.mo.write',
    'manufacturing.wo.read','manufacturing.wo.write',
    'manufacturing.calendar.read',
    'manufacturing.finished_goods.read',
    'manufacturing.cutopt.read'
  ]::text[])

  UNION ALL
  -- Operator Member: work-order focused tabs.
  SELECT 'operator_member'::text, unnest(ARRAY[
    'manufacturing.wo.read','manufacturing.wo.write',
    'manufacturing.finished_goods.read',
    'manufacturing.cutopt.read'
  ]::text[])
) grants
ON CONFLICT (role_code, permission_code) DO NOTHING;

-- Remove legacy broad role grants from sales coordinator to enforce strict tab access.
DELETE FROM public."AppUserRolePermissions"
WHERE role_code = 'sales_coordinator'
  AND permission_code IN (
    'inventory.read','inventory.write',
    'manufacturing.read','manufacturing.write',
    'financials.read','financials.write','financials.create','financials.edit','financials.delete','financials.void',
    'directory.read','directory.write',
    'sales.read','sales.write',
    'financials.invoices.create'
  );

-- 3) Tab-scoped helper functions
CREATE OR REPLACE FUNCTION public.can_read_directory_customers_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['directory.customers.read','directory.customers.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_write_directory_customers_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['directory.customers.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_read_directory_contacts_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['directory.contacts.read','directory.contacts.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_write_directory_contacts_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['directory.contacts.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_read_directory_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY['directory.customers.read','directory.customers.write','directory.contacts.read','directory.contacts.write']::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_create_directory_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['directory.customers.write','directory.contacts.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_update_directory_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['directory.customers.write','directory.contacts.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_read_sales_quotes_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['sales.quotes.read','sales.quotes.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_write_sales_quotes_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['sales.quotes.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_read_sales_proposals_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['sales.proposals.read','sales.proposals.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_write_sales_proposals_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['sales.proposals.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_read_sales_orders_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['sales.orders.read','sales.orders.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_write_sales_orders_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['sales.orders.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_read_sales_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'sales.quotes.read','sales.quotes.write',
      'sales.proposals.read','sales.proposals.write',
      'sales.orders.read','sales.orders.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_create_sales_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY['sales.quotes.write','sales.proposals.write','sales.orders.write']::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_update_sales_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY['sales.quotes.write','sales.proposals.write','sales.orders.write']::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_delete_sales_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY['sales.quotes.write','sales.proposals.write','sales.orders.write']::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_read_inventory_warehouse_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['inventory.warehouse.read','inventory.warehouse.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_write_inventory_warehouse_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['inventory.warehouse.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_read_inventory_purchase_orders_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY['inventory.purchase_orders.read','inventory.purchase_orders.write']::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_write_inventory_purchase_orders_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['inventory.purchase_orders.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_read_inventory_movements_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'inventory.transactions.read','inventory.transactions.write',
      'inventory.adjustments.read','inventory.adjustments.write',
      'inventory.receipts.read','inventory.receipts.write',
      'inventory.material_demand.read','inventory.material_demand.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_write_inventory_movements_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'inventory.transactions.write',
      'inventory.adjustments.write',
      'inventory.receipts.write',
      'inventory.material_demand.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_read_inventory_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
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
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
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
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.can_create_inventory_org(p_org_id);
$$;

CREATE OR REPLACE FUNCTION public.can_delete_inventory_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.can_create_inventory_org(p_org_id);
$$;

CREATE OR REPLACE FUNCTION public.can_read_financials_accounts_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['financials.accounts.read','financials.accounts.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_write_financials_accounts_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['financials.accounts.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_read_financials_invoices_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['financials.invoices.read','financials.invoices.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_write_financials_invoices_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['financials.invoices.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_read_financials_payments_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['financials.payments.read','financials.payments.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_write_financials_payments_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['financials.payments.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_read_financials_ap_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'financials.vendor_accounts.read','financials.vendor_accounts.write',
      'financials.purchase_orders.read','financials.purchase_orders.write',
      'financials.bills.read','financials.bills.write',
      'financials.vendor_payments.read','financials.vendor_payments.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_write_financials_ap_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'financials.vendor_accounts.write',
      'financials.purchase_orders.write',
      'financials.bills.write',
      'financials.vendor_payments.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_read_financials_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    public.can_read_financials_accounts_org(p_org_id)
    OR public.can_read_financials_invoices_org(p_org_id)
    OR public.can_read_financials_payments_org(p_org_id)
    OR public.can_read_financials_ap_org(p_org_id);
$$;

CREATE OR REPLACE FUNCTION public.can_create_financials_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    public.can_write_financials_invoices_org(p_org_id)
    OR public.can_write_financials_payments_org(p_org_id)
    OR public.can_write_financials_ap_org(p_org_id);
$$;

CREATE OR REPLACE FUNCTION public.can_update_financials_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.can_create_financials_org(p_org_id);
$$;

CREATE OR REPLACE FUNCTION public.can_delete_financials_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.can_create_financials_org(p_org_id);
$$;

CREATE OR REPLACE FUNCTION public.can_read_manufacturing_mo_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['manufacturing.mo.read','manufacturing.mo.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_write_manufacturing_mo_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['manufacturing.mo.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_read_manufacturing_wo_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['manufacturing.wo.read','manufacturing.wo.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_write_manufacturing_wo_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['manufacturing.wo.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_read_manufacturing_calendar_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['manufacturing.calendar.read','manufacturing.calendar.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_write_manufacturing_calendar_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.user_has_org_permission(p_org_id, ARRAY['manufacturing.calendar.write']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_read_manufacturing_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    public.can_read_manufacturing_mo_org(p_org_id)
    OR public.can_read_manufacturing_wo_org(p_org_id)
    OR public.can_read_manufacturing_calendar_org(p_org_id)
    OR public.user_has_org_permission(p_org_id, ARRAY['manufacturing.finished_goods.read','manufacturing.cutopt.read']::text[]);
$$;

CREATE OR REPLACE FUNCTION public.can_write_manufacturing_org(p_org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    public.can_write_manufacturing_mo_org(p_org_id)
    OR public.can_write_manufacturing_wo_org(p_org_id)
    OR public.can_write_manufacturing_calendar_org(p_org_id)
    OR public.user_has_org_permission(p_org_id, ARRAY['manufacturing.finished_goods.write','manufacturing.cutopt.write']::text[]);
$$;

GRANT EXECUTE ON FUNCTION public.can_read_directory_customers_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_directory_customers_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_directory_contacts_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_directory_contacts_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_sales_quotes_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_sales_quotes_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_sales_proposals_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_sales_proposals_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_sales_orders_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_sales_orders_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_inventory_warehouse_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_inventory_warehouse_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_inventory_purchase_orders_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_inventory_purchase_orders_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_inventory_movements_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_inventory_movements_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_financials_accounts_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_financials_accounts_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_financials_invoices_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_financials_invoices_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_financials_payments_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_financials_payments_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_financials_ap_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_financials_ap_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_manufacturing_mo_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_manufacturing_mo_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_manufacturing_wo_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_manufacturing_wo_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_manufacturing_calendar_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_manufacturing_calendar_org(uuid) TO authenticated;

-- 4) Core policy remap (critical tables)
DROP POLICY IF EXISTS dircontacts_select ON public."DirectoryContacts";
CREATE POLICY dircontacts_select ON public."DirectoryContacts"
  FOR SELECT TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_read_directory_contacts_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

DROP POLICY IF EXISTS dircontacts_insert ON public."DirectoryContacts";
CREATE POLICY dircontacts_insert ON public."DirectoryContacts"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_write_directory_contacts_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

DROP POLICY IF EXISTS dircontacts_update ON public."DirectoryContacts";
CREATE POLICY dircontacts_update ON public."DirectoryContacts"
  FOR UPDATE TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_write_directory_contacts_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_write_directory_contacts_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

DROP POLICY IF EXISTS dircustomers_select ON public."DirectoryCustomers";
CREATE POLICY dircustomers_select ON public."DirectoryCustomers"
  FOR SELECT TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_read_directory_customers_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

DROP POLICY IF EXISTS dircustomers_insert ON public."DirectoryCustomers";
CREATE POLICY dircustomers_insert ON public."DirectoryCustomers"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_write_directory_customers_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

DROP POLICY IF EXISTS dircustomers_update ON public."DirectoryCustomers";
CREATE POLICY dircustomers_update ON public."DirectoryCustomers"
  FOR UPDATE TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_write_directory_customers_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_write_directory_customers_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

DROP POLICY IF EXISTS salesorders_org_select ON public."SalesOrders";
CREATE POLICY salesorders_org_select ON public."SalesOrders"
  FOR SELECT TO authenticated
  USING (
    organization_id IS NOT NULL
    AND is_internal_org_user(organization_id)
    AND public.can_read_sales_orders_org(organization_id)
  );

DROP POLICY IF EXISTS salesorders_org_insert ON public."SalesOrders";
CREATE POLICY salesorders_org_insert ON public."SalesOrders"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND is_internal_org_user(organization_id)
    AND public.can_write_sales_orders_org(organization_id)
  );

DROP POLICY IF EXISTS salesorders_org_update ON public."SalesOrders";
CREATE POLICY salesorders_org_update ON public."SalesOrders"
  FOR UPDATE TO authenticated
  USING (
    organization_id IS NOT NULL
    AND is_internal_org_user(organization_id)
    AND public.can_write_sales_orders_org(organization_id)
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND is_internal_org_user(organization_id)
    AND public.can_write_sales_orders_org(organization_id)
  );

DROP POLICY IF EXISTS quotes_select ON public."Quotes";
CREATE POLICY quotes_select ON public."Quotes"
  FOR SELECT TO authenticated
  USING (
    deleted IS NOT TRUE
    AND organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_read_sales_quotes_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
      OR (dealer_id IS NOT NULL AND is_dealer_portal_user(dealer_id))
    )
  );

DROP POLICY IF EXISTS quotes_insert ON public."Quotes";
CREATE POLICY quotes_insert ON public."Quotes"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_write_sales_quotes_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

DROP POLICY IF EXISTS quotes_update ON public."Quotes";
CREATE POLICY quotes_update ON public."Quotes"
  FOR UPDATE TO authenticated
  USING (
    deleted IS NOT TRUE
    AND organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_write_sales_quotes_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_write_sales_quotes_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

DROP POLICY IF EXISTS proposals_select ON public."Proposals";
CREATE POLICY proposals_select ON public."Proposals"
  FOR SELECT TO authenticated
  USING (
    deleted IS NOT TRUE
    AND organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_read_sales_proposals_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
      OR (dealer_id IS NOT NULL AND session_is_dealer_portal(dealer_id))
    )
  );

DROP POLICY IF EXISTS proposals_insert ON public."Proposals";
CREATE POLICY proposals_insert ON public."Proposals"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_write_sales_proposals_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

DROP POLICY IF EXISTS proposals_update ON public."Proposals";
CREATE POLICY proposals_update ON public."Proposals"
  FOR UPDATE TO authenticated
  USING (
    deleted IS NOT TRUE
    AND organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_write_sales_proposals_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (
        dealer_id IS NOT NULL
        AND session_is_dealer_portal(dealer_id)
        AND (current_user_role_code() = 'dealer_manager' OR created_by_user_id = auth.uid())
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (session_is_org_user(organization_id)
       AND public.can_write_sales_proposals_org(organization_id)
       AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id()))
      OR (
        dealer_id IS NOT NULL
        AND session_is_dealer_portal(dealer_id)
        AND (current_user_role_code() = 'dealer_manager' OR created_by_user_id = auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS purchase_orders_select_org ON public."PurchaseOrders";
CREATE POLICY purchase_orders_select_org ON public."PurchaseOrders"
  FOR SELECT TO authenticated
  USING (
    is_portal_user_in_org(organization_id)
    OR public.can_read_inventory_purchase_orders_org(organization_id)
    OR public.can_read_financials_ap_org(organization_id)
  );

DROP POLICY IF EXISTS purchase_orders_insert_org ON public."PurchaseOrders";
CREATE POLICY purchase_orders_insert_org ON public."PurchaseOrders"
  FOR INSERT TO authenticated
  WITH CHECK (
    is_portal_user_in_org(organization_id)
    OR public.can_write_inventory_purchase_orders_org(organization_id)
    OR public.can_write_financials_ap_org(organization_id)
  );

DROP POLICY IF EXISTS purchase_orders_update_org ON public."PurchaseOrders";
CREATE POLICY purchase_orders_update_org ON public."PurchaseOrders"
  FOR UPDATE TO authenticated
  USING (
    is_portal_user_in_org(organization_id)
    OR public.can_write_inventory_purchase_orders_org(organization_id)
    OR public.can_write_financials_ap_org(organization_id)
  )
  WITH CHECK (
    is_portal_user_in_org(organization_id)
    OR public.can_write_inventory_purchase_orders_org(organization_id)
    OR public.can_write_financials_ap_org(organization_id)
  );

DROP POLICY IF EXISTS po_lines_select_via_po ON public."PurchaseOrderLines";
CREATE POLICY po_lines_select_via_po ON public."PurchaseOrderLines"
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."PurchaseOrders" po
      WHERE po.id = public."PurchaseOrderLines".purchase_order_id
        AND (
          is_portal_user_in_org(po.organization_id)
          OR public.can_read_inventory_purchase_orders_org(po.organization_id)
          OR public.can_read_financials_ap_org(po.organization_id)
        )
    )
  );

DROP POLICY IF EXISTS po_lines_insert_via_po ON public."PurchaseOrderLines";
CREATE POLICY po_lines_insert_via_po ON public."PurchaseOrderLines"
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."PurchaseOrders" po
      WHERE po.id = public."PurchaseOrderLines".purchase_order_id
        AND (
          is_portal_user_in_org(po.organization_id)
          OR public.can_write_inventory_purchase_orders_org(po.organization_id)
          OR public.can_write_financials_ap_org(po.organization_id)
        )
    )
  );

DROP POLICY IF EXISTS po_lines_update_via_po ON public."PurchaseOrderLines";
CREATE POLICY po_lines_update_via_po ON public."PurchaseOrderLines"
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."PurchaseOrders" po
      WHERE po.id = public."PurchaseOrderLines".purchase_order_id
        AND (
          is_portal_user_in_org(po.organization_id)
          OR public.can_write_inventory_purchase_orders_org(po.organization_id)
          OR public.can_write_financials_ap_org(po.organization_id)
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."PurchaseOrders" po
      WHERE po.id = public."PurchaseOrderLines".purchase_order_id
        AND (
          is_portal_user_in_org(po.organization_id)
          OR public.can_write_inventory_purchase_orders_org(po.organization_id)
          OR public.can_write_financials_ap_org(po.organization_id)
        )
    )
  );

DROP POLICY IF EXISTS inv_movements_select ON public."InventoryMovements";
CREATE POLICY inv_movements_select ON public."InventoryMovements"
  FOR SELECT TO authenticated
  USING (public.can_read_inventory_movements_org(organization_id));

DROP POLICY IF EXISTS inv_movements_insert ON public."InventoryMovements";
CREATE POLICY inv_movements_insert ON public."InventoryMovements"
  FOR INSERT TO authenticated
  WITH CHECK (public.can_write_inventory_movements_org(organization_id));

DROP POLICY IF EXISTS inv_movements_update ON public."InventoryMovements";
CREATE POLICY inv_movements_update ON public."InventoryMovements"
  FOR UPDATE TO authenticated
  USING (public.can_write_inventory_movements_org(organization_id))
  WITH CHECK (public.can_write_inventory_movements_org(organization_id));

DROP POLICY IF EXISTS inv_movements_delete ON public."InventoryMovements";
CREATE POLICY inv_movements_delete ON public."InventoryMovements"
  FOR DELETE TO authenticated
  USING (public.can_write_inventory_movements_org(organization_id));

DROP POLICY IF EXISTS inv_balances_select_org ON public."InventoryBalances";
CREATE POLICY inv_balances_select_org ON public."InventoryBalances"
  FOR SELECT TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_read_inventory_warehouse_org(organization_id));

DROP POLICY IF EXISTS inv_balances_insert_org ON public."InventoryBalances";
CREATE POLICY inv_balances_insert_org ON public."InventoryBalances"
  FOR INSERT TO authenticated
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_write_inventory_warehouse_org(organization_id));

DROP POLICY IF EXISTS inv_balances_update_org ON public."InventoryBalances";
CREATE POLICY inv_balances_update_org ON public."InventoryBalances"
  FOR UPDATE TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_write_inventory_warehouse_org(organization_id))
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_write_inventory_warehouse_org(organization_id));

DROP POLICY IF EXISTS warehouses_select_org ON public."Warehouses";
CREATE POLICY warehouses_select_org ON public."Warehouses"
  FOR SELECT TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_read_inventory_warehouse_org(organization_id));

DROP POLICY IF EXISTS warehouses_insert_org ON public."Warehouses";
CREATE POLICY warehouses_insert_org ON public."Warehouses"
  FOR INSERT TO authenticated
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_write_inventory_warehouse_org(organization_id));

DROP POLICY IF EXISTS warehouses_update_org ON public."Warehouses";
CREATE POLICY warehouses_update_org ON public."Warehouses"
  FOR UPDATE TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_write_inventory_warehouse_org(organization_id))
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_write_inventory_warehouse_org(organization_id));

DROP POLICY IF EXISTS dealer_invoices_select ON public."DealerInvoices";
CREATE POLICY dealer_invoices_select ON public."DealerInvoices"
  FOR SELECT TO authenticated
  USING (public.is_portal_user_in_org(organization_id) OR public.can_read_financials_invoices_org(organization_id));

DROP POLICY IF EXISTS dealer_invoices_insert ON public."DealerInvoices";
CREATE POLICY dealer_invoices_insert ON public."DealerInvoices"
  FOR INSERT TO authenticated
  WITH CHECK (public.can_write_financials_invoices_org(organization_id));

DROP POLICY IF EXISTS dealer_invoices_update ON public."DealerInvoices";
CREATE POLICY dealer_invoices_update ON public."DealerInvoices"
  FOR UPDATE TO authenticated
  USING (public.can_write_financials_invoices_org(organization_id))
  WITH CHECK (public.can_write_financials_invoices_org(organization_id));

DROP POLICY IF EXISTS dealer_invoices_delete ON public."DealerInvoices";
CREATE POLICY dealer_invoices_delete ON public."DealerInvoices"
  FOR DELETE TO authenticated
  USING (public.can_write_financials_invoices_org(organization_id));

DROP POLICY IF EXISTS dealer_invoice_lines_select ON public."DealerInvoiceLines";
CREATE POLICY dealer_invoice_lines_select ON public."DealerInvoiceLines"
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."DealerInvoices" di
      WHERE di.id = public."DealerInvoiceLines".invoice_id
        AND (public.is_portal_user_in_org(di.organization_id) OR public.can_read_financials_invoices_org(di.organization_id))
    )
  );

DROP POLICY IF EXISTS dealer_invoice_lines_insert ON public."DealerInvoiceLines";
CREATE POLICY dealer_invoice_lines_insert ON public."DealerInvoiceLines"
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."DealerInvoices" di
      WHERE di.id = public."DealerInvoiceLines".invoice_id
        AND public.can_write_financials_invoices_org(di.organization_id)
    )
  );

DROP POLICY IF EXISTS dealer_invoice_lines_update ON public."DealerInvoiceLines";
CREATE POLICY dealer_invoice_lines_update ON public."DealerInvoiceLines"
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."DealerInvoices" di
      WHERE di.id = public."DealerInvoiceLines".invoice_id
        AND public.can_write_financials_invoices_org(di.organization_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."DealerInvoices" di
      WHERE di.id = public."DealerInvoiceLines".invoice_id
        AND public.can_write_financials_invoices_org(di.organization_id)
    )
  );

DROP POLICY IF EXISTS dealer_invoice_lines_delete ON public."DealerInvoiceLines";
CREATE POLICY dealer_invoice_lines_delete ON public."DealerInvoiceLines"
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."DealerInvoices" di
      WHERE di.id = public."DealerInvoiceLines".invoice_id
        AND public.can_write_financials_invoices_org(di.organization_id)
    )
  );

DROP POLICY IF EXISTS payments_select_own_org ON public."Payments";
CREATE POLICY payments_select_own_org ON public."Payments"
  FOR SELECT TO authenticated
  USING (public.is_portal_user_in_org(organization_id) OR public.can_read_financials_payments_org(organization_id));

DROP POLICY IF EXISTS payments_insert_own_org ON public."Payments";
CREATE POLICY payments_insert_own_org ON public."Payments"
  FOR INSERT TO authenticated
  WITH CHECK (public.can_write_financials_payments_org(organization_id));

DROP POLICY IF EXISTS payments_update_own_org ON public."Payments";
CREATE POLICY payments_update_own_org ON public."Payments"
  FOR UPDATE TO authenticated
  USING (public.can_write_financials_payments_org(organization_id))
  WITH CHECK (public.can_write_financials_payments_org(organization_id));

DROP POLICY IF EXISTS payments_delete_own_org ON public."Payments";
CREATE POLICY payments_delete_own_org ON public."Payments"
  FOR DELETE TO authenticated
  USING (public.can_write_financials_payments_org(organization_id));

DROP POLICY IF EXISTS payment_apps_select ON public."PaymentApplications";
CREATE POLICY payment_apps_select ON public."PaymentApplications"
  FOR SELECT TO authenticated
  USING (public.is_portal_user_in_org(organization_id) OR public.can_read_financials_payments_org(organization_id));

DROP POLICY IF EXISTS payment_apps_insert ON public."PaymentApplications";
CREATE POLICY payment_apps_insert ON public."PaymentApplications"
  FOR INSERT TO authenticated
  WITH CHECK (public.can_write_financials_payments_org(organization_id));

DROP POLICY IF EXISTS payment_apps_update ON public."PaymentApplications";
CREATE POLICY payment_apps_update ON public."PaymentApplications"
  FOR UPDATE TO authenticated
  USING (public.can_write_financials_payments_org(organization_id))
  WITH CHECK (public.can_write_financials_payments_org(organization_id));

DROP POLICY IF EXISTS payment_apps_delete ON public."PaymentApplications";
CREATE POLICY payment_apps_delete ON public."PaymentApplications"
  FOR DELETE TO authenticated
  USING (public.can_write_financials_payments_org(organization_id));

DROP POLICY IF EXISTS vendor_bills_select_org ON public."VendorBills";
CREATE POLICY vendor_bills_select_org ON public."VendorBills"
  FOR SELECT TO authenticated
  USING (public.can_read_financials_ap_org(organization_id));

DROP POLICY IF EXISTS vendor_bills_insert_org ON public."VendorBills";
CREATE POLICY vendor_bills_insert_org ON public."VendorBills"
  FOR INSERT TO authenticated
  WITH CHECK (public.can_write_financials_ap_org(organization_id));

DROP POLICY IF EXISTS vendor_bills_update_org ON public."VendorBills";
CREATE POLICY vendor_bills_update_org ON public."VendorBills"
  FOR UPDATE TO authenticated
  USING (public.can_write_financials_ap_org(organization_id))
  WITH CHECK (public.can_write_financials_ap_org(organization_id));

DROP POLICY IF EXISTS vendor_bills_delete_org ON public."VendorBills";
CREATE POLICY vendor_bills_delete_org ON public."VendorBills"
  FOR DELETE TO authenticated
  USING (public.can_write_financials_ap_org(organization_id));

DROP POLICY IF EXISTS vendor_payments_select_org ON public."VendorPayments";
CREATE POLICY vendor_payments_select_org ON public."VendorPayments"
  FOR SELECT TO authenticated
  USING (public.can_read_financials_ap_org(organization_id));

DROP POLICY IF EXISTS vendor_payments_insert_org ON public."VendorPayments";
CREATE POLICY vendor_payments_insert_org ON public."VendorPayments"
  FOR INSERT TO authenticated
  WITH CHECK (public.can_write_financials_ap_org(organization_id));

DROP POLICY IF EXISTS vendor_payments_update_org ON public."VendorPayments";
CREATE POLICY vendor_payments_update_org ON public."VendorPayments"
  FOR UPDATE TO authenticated
  USING (public.can_write_financials_ap_org(organization_id))
  WITH CHECK (public.can_write_financials_ap_org(organization_id));

DROP POLICY IF EXISTS vendor_payments_delete_org ON public."VendorPayments";
CREATE POLICY vendor_payments_delete_org ON public."VendorPayments"
  FOR DELETE TO authenticated
  USING (public.can_write_financials_ap_org(organization_id));

DROP POLICY IF EXISTS mo_select ON public."ManufacturingOrders";
CREATE POLICY mo_select ON public."ManufacturingOrders"
  FOR SELECT TO authenticated
  USING (
    deleted = false
    AND EXISTS (
      SELECT 1
      FROM public."OrganizationUsers" ou
      WHERE ou.user_id = auth.uid()
        AND ou.organization_id = public."ManufacturingOrders".organization_id
        AND ou.deleted = false
        AND ou.status = 'active'
    )
    AND public.can_read_manufacturing_mo_org(organization_id)
  );

DROP POLICY IF EXISTS mo_write ON public."ManufacturingOrders";
CREATE POLICY mo_write ON public."ManufacturingOrders"
  FOR ALL TO authenticated
  USING (public.can_write_manufacturing_mo_org(organization_id))
  WITH CHECK (public.can_write_manufacturing_mo_org(organization_id));

DROP POLICY IF EXISTS wot_select ON public."WorkOrderTasks";
CREATE POLICY wot_select ON public."WorkOrderTasks"
  FOR SELECT TO authenticated
  USING ((deleted = false) AND public.can_read_manufacturing_wo_org(organization_id));

DROP POLICY IF EXISTS wot_insert ON public."WorkOrderTasks";
CREATE POLICY wot_insert ON public."WorkOrderTasks"
  FOR INSERT TO authenticated
  WITH CHECK (public.can_write_manufacturing_wo_org(organization_id));

DROP POLICY IF EXISTS wot_update ON public."WorkOrderTasks";
CREATE POLICY wot_update ON public."WorkOrderTasks"
  FOR UPDATE TO authenticated
  USING (public.can_write_manufacturing_wo_org(organization_id))
  WITH CHECK (public.can_write_manufacturing_wo_org(organization_id));

DROP POLICY IF EXISTS wot_delete ON public."WorkOrderTasks";
CREATE POLICY wot_delete ON public."WorkOrderTasks"
  FOR DELETE TO authenticated
  USING (public.can_write_manufacturing_wo_org(organization_id));

DROP POLICY IF EXISTS wc_select ON public."WorkCenters";
CREATE POLICY wc_select ON public."WorkCenters"
  FOR SELECT TO authenticated
  USING ((deleted = false) AND public.can_read_manufacturing_calendar_org(organization_id));

DROP POLICY IF EXISTS wc_insert ON public."WorkCenters";
CREATE POLICY wc_insert ON public."WorkCenters"
  FOR INSERT TO authenticated
  WITH CHECK (public.can_write_manufacturing_calendar_org(organization_id));

DROP POLICY IF EXISTS wc_update ON public."WorkCenters";
CREATE POLICY wc_update ON public."WorkCenters"
  FOR UPDATE TO authenticated
  USING (public.can_write_manufacturing_calendar_org(organization_id))
  WITH CHECK (public.can_write_manufacturing_calendar_org(organization_id));

DROP POLICY IF EXISTS wc_delete ON public."WorkCenters";
CREATE POLICY wc_delete ON public."WorkCenters"
  FOR DELETE TO authenticated
  USING (public.can_write_manufacturing_calendar_org(organization_id));
