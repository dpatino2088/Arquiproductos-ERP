-- Sales + Inventory Phase B:
-- Keep org/dealer scoping but require Permissions module codes for internal org users.

CREATE OR REPLACE FUNCTION public.can_read_sales_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'sales.read',
      'sales.write',
      'quotes.read',
      'quotes.create',
      'quotes.edit',
      'proposals.read',
      'proposals.create',
      'salesorders.read',
      'salesorders.create',
      'salesorders.edit'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_create_sales_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'sales.write',
      'quotes.create',
      'quotes.edit',
      'proposals.create',
      'salesorders.create',
      'salesorders.edit'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_update_sales_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'sales.write',
      'quotes.edit',
      'salesorders.edit'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_delete_sales_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'sales.write',
      'quotes.delete',
      'proposals.delete',
      'salesorders.delete'
    ]::text[]
  );
$$;

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
      'inventory.read',
      'inventory.create',
      'inventory.edit',
      'inventory.delete',
      'inventory.write'
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
      'inventory.create',
      'inventory.write'
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
      'inventory.edit',
      'inventory.write'
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
      'inventory.delete',
      'inventory.write'
    ]::text[]
  );
$$;

GRANT EXECUTE ON FUNCTION public.can_read_sales_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_create_sales_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_update_sales_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_delete_sales_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_inventory_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_create_inventory_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_update_inventory_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_delete_inventory_org(uuid) TO authenticated;

-- SalesOrders (internal org users must also have sales permissions)
DROP POLICY IF EXISTS salesorders_org_select ON public."SalesOrders";
CREATE POLICY salesorders_org_select ON public."SalesOrders"
  FOR SELECT
  TO authenticated
  USING (
    organization_id IS NOT NULL
    AND is_internal_org_user(organization_id)
    AND public.can_read_sales_org(organization_id)
  );

DROP POLICY IF EXISTS salesorders_org_insert ON public."SalesOrders";
CREATE POLICY salesorders_org_insert ON public."SalesOrders"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND is_internal_org_user(organization_id)
    AND public.can_create_sales_org(organization_id)
  );

DROP POLICY IF EXISTS salesorders_org_update ON public."SalesOrders";
CREATE POLICY salesorders_org_update ON public."SalesOrders"
  FOR UPDATE
  TO authenticated
  USING (
    organization_id IS NOT NULL
    AND is_internal_org_user(organization_id)
    AND public.can_update_sales_org(organization_id)
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND is_internal_org_user(organization_id)
    AND public.can_update_sales_org(organization_id)
  );

-- Quotes (require sales permission in internal org branch; keep dealer/portal behavior)
DROP POLICY IF EXISTS quotes_select ON public."Quotes";
CREATE POLICY quotes_select ON public."Quotes"
  FOR SELECT
  TO authenticated
  USING (
    deleted IS NOT TRUE
    AND organization_id IS NOT NULL
    AND (
      (
        session_is_org_user(organization_id)
        AND public.can_read_sales_org(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
      OR (dealer_id IS NOT NULL AND is_dealer_portal_user(dealer_id))
    )
  );

DROP POLICY IF EXISTS quotes_insert ON public."Quotes";
CREATE POLICY quotes_insert ON public."Quotes"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        session_is_org_user(organization_id)
        AND public.can_create_sales_org(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

DROP POLICY IF EXISTS quotes_update ON public."Quotes";
CREATE POLICY quotes_update ON public."Quotes"
  FOR UPDATE
  TO authenticated
  USING (
    deleted IS NOT TRUE
    AND organization_id IS NOT NULL
    AND (
      (
        session_is_org_user(organization_id)
        AND public.can_update_sales_org(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        session_is_org_user(organization_id)
        AND public.can_update_sales_org(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

-- Proposals (same pattern as Quotes)
DROP POLICY IF EXISTS proposals_select ON public."Proposals";
CREATE POLICY proposals_select ON public."Proposals"
  FOR SELECT
  TO authenticated
  USING (
    deleted IS NOT TRUE
    AND organization_id IS NOT NULL
    AND (
      (
        session_is_org_user(organization_id)
        AND public.can_read_sales_org(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
      OR (dealer_id IS NOT NULL AND session_is_dealer_portal(dealer_id))
    )
  );

DROP POLICY IF EXISTS proposals_insert ON public."Proposals";
CREATE POLICY proposals_insert ON public."Proposals"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        session_is_org_user(organization_id)
        AND public.can_create_sales_org(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

DROP POLICY IF EXISTS proposals_update ON public."Proposals";
CREATE POLICY proposals_update ON public."Proposals"
  FOR UPDATE
  TO authenticated
  USING (
    deleted IS NOT TRUE
    AND organization_id IS NOT NULL
    AND (
      (
        session_is_org_user(organization_id)
        AND public.can_update_sales_org(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
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
      (
        session_is_org_user(organization_id)
        AND public.can_update_sales_org(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
      OR (
        dealer_id IS NOT NULL
        AND session_is_dealer_portal(dealer_id)
        AND (current_user_role_code() = 'dealer_manager' OR created_by_user_id = auth.uid())
      )
    )
  );

-- Sales detail tables: org writes require sales permission; keep portal path.
DROP POLICY IF EXISTS qlc_select ON public."QuoteLineComponents";
CREATE POLICY qlc_select ON public."QuoteLineComponents"
  FOR SELECT
  TO authenticated
  USING (
    is_portal_user_in_org(organization_id)
    OR public.can_read_sales_org(organization_id)
  );

DROP POLICY IF EXISTS qlc_insert ON public."QuoteLineComponents";
CREATE POLICY qlc_insert ON public."QuoteLineComponents"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    is_portal_user_in_org(organization_id)
    OR public.can_create_sales_org(organization_id)
  );

DROP POLICY IF EXISTS qlc_update ON public."QuoteLineComponents";
CREATE POLICY qlc_update ON public."QuoteLineComponents"
  FOR UPDATE
  TO authenticated
  USING (
    is_portal_user_in_org(organization_id)
    OR public.can_update_sales_org(organization_id)
  )
  WITH CHECK (
    is_portal_user_in_org(organization_id)
    OR public.can_update_sales_org(organization_id)
  );

DROP POLICY IF EXISTS qlc_delete ON public."QuoteLineComponents";
CREATE POLICY qlc_delete ON public."QuoteLineComponents"
  FOR DELETE
  TO authenticated
  USING (
    is_portal_user_in_org(organization_id)
    OR public.can_delete_sales_org(organization_id)
  );

DROP POLICY IF EXISTS quotelines_select ON public."QuoteLines";
CREATE POLICY quotelines_select ON public."QuoteLines"
  FOR SELECT
  TO authenticated
  USING (
    is_portal_user_in_org(organization_id)
    OR public.can_read_sales_org(organization_id)
  );

DROP POLICY IF EXISTS quotelines_insert ON public."QuoteLines";
CREATE POLICY quotelines_insert ON public."QuoteLines"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (
      is_portal_user_in_org(organization_id)
      OR public.can_create_sales_org(organization_id)
    )
    AND EXISTS (
      SELECT 1
      FROM public."Quotes" q
      WHERE q.id = public."QuoteLines".quote_id
        AND q.organization_id = public."QuoteLines".organization_id
        AND q.deleted = false
    )
  );

DROP POLICY IF EXISTS quotelines_update ON public."QuoteLines";
CREATE POLICY quotelines_update ON public."QuoteLines"
  FOR UPDATE
  TO authenticated
  USING (
    is_portal_user_in_org(organization_id)
    OR public.can_update_sales_org(organization_id)
  )
  WITH CHECK (
    is_portal_user_in_org(organization_id)
    OR public.can_update_sales_org(organization_id)
  );

DROP POLICY IF EXISTS quotelines_delete ON public."QuoteLines";
CREATE POLICY quotelines_delete ON public."QuoteLines"
  FOR DELETE
  TO authenticated
  USING (
    is_portal_user_in_org(organization_id)
    OR public.can_delete_sales_org(organization_id)
  );

DROP POLICY IF EXISTS proposallines_select ON public."ProposalLines";
CREATE POLICY proposallines_select ON public."ProposalLines"
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."Proposals" p
      WHERE p.id = public."ProposalLines".proposal_id
        AND p.deleted IS NOT TRUE
        AND (is_portal_user_in_org(p.organization_id) OR public.can_read_sales_org(p.organization_id))
    )
  );

DROP POLICY IF EXISTS proposallines_insert ON public."ProposalLines";
CREATE POLICY proposallines_insert ON public."ProposalLines"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."Proposals" p
      WHERE p.id = public."ProposalLines".proposal_id
        AND p.deleted = false
        AND (is_portal_user_in_org(p.organization_id) OR public.can_create_sales_org(p.organization_id))
    )
  );

DROP POLICY IF EXISTS proposallines_update ON public."ProposalLines";
CREATE POLICY proposallines_update ON public."ProposalLines"
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."Proposals" p
      WHERE p.id = public."ProposalLines".proposal_id
        AND (is_portal_user_in_org(p.organization_id) OR public.can_update_sales_org(p.organization_id))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."Proposals" p
      WHERE p.id = public."ProposalLines".proposal_id
        AND (is_portal_user_in_org(p.organization_id) OR public.can_update_sales_org(p.organization_id))
    )
  );

DROP POLICY IF EXISTS proposallines_delete ON public."ProposalLines";
CREATE POLICY proposallines_delete ON public."ProposalLines"
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."Proposals" p
      WHERE p.id = public."ProposalLines".proposal_id
        AND (is_portal_user_in_org(p.organization_id) OR public.can_delete_sales_org(p.organization_id))
    )
  );

DROP POLICY IF EXISTS proposal_line_addons_select ON public."ProposalLineAddOns";
CREATE POLICY proposal_line_addons_select ON public."ProposalLineAddOns"
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."Proposals" p
      WHERE p.id = public."ProposalLineAddOns".proposal_id
        AND (is_portal_user_in_org(p.organization_id) OR public.can_read_sales_org(p.organization_id))
    )
  );

DROP POLICY IF EXISTS proposal_line_addons_insert ON public."ProposalLineAddOns";
CREATE POLICY proposal_line_addons_insert ON public."ProposalLineAddOns"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."Proposals" p
      WHERE p.id = public."ProposalLineAddOns".proposal_id
        AND (is_portal_user_in_org(p.organization_id) OR public.can_create_sales_org(p.organization_id))
    )
  );

DROP POLICY IF EXISTS proposal_line_addons_update ON public."ProposalLineAddOns";
CREATE POLICY proposal_line_addons_update ON public."ProposalLineAddOns"
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."Proposals" p
      WHERE p.id = public."ProposalLineAddOns".proposal_id
        AND (is_portal_user_in_org(p.organization_id) OR public.can_update_sales_org(p.organization_id))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."Proposals" p
      WHERE p.id = public."ProposalLineAddOns".proposal_id
        AND (is_portal_user_in_org(p.organization_id) OR public.can_update_sales_org(p.organization_id))
    )
  );

DROP POLICY IF EXISTS proposal_line_addons_delete ON public."ProposalLineAddOns";
CREATE POLICY proposal_line_addons_delete ON public."ProposalLineAddOns"
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."Proposals" p
      WHERE p.id = public."ProposalLineAddOns".proposal_id
        AND (is_portal_user_in_org(p.organization_id) OR public.can_delete_sales_org(p.organization_id))
    )
  );

-- Inventory module
DROP POLICY IF EXISTS purchase_orders_select_org ON public."PurchaseOrders";
CREATE POLICY purchase_orders_select_org ON public."PurchaseOrders"
  FOR SELECT
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_read_inventory_org(organization_id));

DROP POLICY IF EXISTS purchase_orders_insert_org ON public."PurchaseOrders";
CREATE POLICY purchase_orders_insert_org ON public."PurchaseOrders"
  FOR INSERT
  TO authenticated
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_create_inventory_org(organization_id));

DROP POLICY IF EXISTS purchase_orders_update_org ON public."PurchaseOrders";
CREATE POLICY purchase_orders_update_org ON public."PurchaseOrders"
  FOR UPDATE
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_update_inventory_org(organization_id))
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_update_inventory_org(organization_id));

DROP POLICY IF EXISTS po_lines_select_via_po ON public."PurchaseOrderLines";
CREATE POLICY po_lines_select_via_po ON public."PurchaseOrderLines"
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."PurchaseOrders" po
      WHERE po.id = public."PurchaseOrderLines".purchase_order_id
        AND (is_portal_user_in_org(po.organization_id) OR public.can_read_inventory_org(po.organization_id))
    )
  );

DROP POLICY IF EXISTS po_lines_insert_via_po ON public."PurchaseOrderLines";
CREATE POLICY po_lines_insert_via_po ON public."PurchaseOrderLines"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."PurchaseOrders" po
      WHERE po.id = public."PurchaseOrderLines".purchase_order_id
        AND (is_portal_user_in_org(po.organization_id) OR public.can_create_inventory_org(po.organization_id))
    )
  );

DROP POLICY IF EXISTS po_lines_update_via_po ON public."PurchaseOrderLines";
CREATE POLICY po_lines_update_via_po ON public."PurchaseOrderLines"
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."PurchaseOrders" po
      WHERE po.id = public."PurchaseOrderLines".purchase_order_id
        AND (is_portal_user_in_org(po.organization_id) OR public.can_update_inventory_org(po.organization_id))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."PurchaseOrders" po
      WHERE po.id = public."PurchaseOrderLines".purchase_order_id
        AND (is_portal_user_in_org(po.organization_id) OR public.can_update_inventory_org(po.organization_id))
    )
  );

DROP POLICY IF EXISTS inv_movements_select ON public."InventoryMovements";
CREATE POLICY inv_movements_select ON public."InventoryMovements"
  FOR SELECT
  TO authenticated
  USING (public.can_read_inventory_org(organization_id));

DROP POLICY IF EXISTS inv_movements_insert ON public."InventoryMovements";
CREATE POLICY inv_movements_insert ON public."InventoryMovements"
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_create_inventory_org(organization_id));

DROP POLICY IF EXISTS inv_movements_update ON public."InventoryMovements";
CREATE POLICY inv_movements_update ON public."InventoryMovements"
  FOR UPDATE
  TO authenticated
  USING (public.can_update_inventory_org(organization_id))
  WITH CHECK (public.can_update_inventory_org(organization_id));

DROP POLICY IF EXISTS inv_movements_delete ON public."InventoryMovements";
CREATE POLICY inv_movements_delete ON public."InventoryMovements"
  FOR DELETE
  TO authenticated
  USING (public.can_delete_inventory_org(organization_id));

DROP POLICY IF EXISTS inv_movement_lines_select ON public."InventoryMovementLines";
CREATE POLICY inv_movement_lines_select ON public."InventoryMovementLines"
  FOR SELECT
  TO authenticated
  USING (
    inventory_movement_id IN (
      SELECT im.id
      FROM public."InventoryMovements" im
      WHERE public.can_read_inventory_org(im.organization_id)
    )
  );

DROP POLICY IF EXISTS inv_movement_lines_insert ON public."InventoryMovementLines";
CREATE POLICY inv_movement_lines_insert ON public."InventoryMovementLines"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    inventory_movement_id IN (
      SELECT im.id
      FROM public."InventoryMovements" im
      WHERE public.can_create_inventory_org(im.organization_id)
    )
  );

DROP POLICY IF EXISTS inv_movement_lines_update ON public."InventoryMovementLines";
CREATE POLICY inv_movement_lines_update ON public."InventoryMovementLines"
  FOR UPDATE
  TO authenticated
  USING (
    inventory_movement_id IN (
      SELECT im.id
      FROM public."InventoryMovements" im
      WHERE public.can_update_inventory_org(im.organization_id)
    )
  )
  WITH CHECK (
    inventory_movement_id IN (
      SELECT im.id
      FROM public."InventoryMovements" im
      WHERE public.can_update_inventory_org(im.organization_id)
    )
  );

DROP POLICY IF EXISTS inv_movement_lines_delete ON public."InventoryMovementLines";
CREATE POLICY inv_movement_lines_delete ON public."InventoryMovementLines"
  FOR DELETE
  TO authenticated
  USING (
    inventory_movement_id IN (
      SELECT im.id
      FROM public."InventoryMovements" im
      WHERE public.can_delete_inventory_org(im.organization_id)
    )
  );

DROP POLICY IF EXISTS inv_alloc_select_org ON public."InventoryAllocations";
CREATE POLICY inv_alloc_select_org ON public."InventoryAllocations"
  FOR SELECT
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_read_inventory_org(organization_id));

DROP POLICY IF EXISTS inv_alloc_insert_org ON public."InventoryAllocations";
CREATE POLICY inv_alloc_insert_org ON public."InventoryAllocations"
  FOR INSERT
  TO authenticated
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_create_inventory_org(organization_id));

DROP POLICY IF EXISTS inv_alloc_update_org ON public."InventoryAllocations";
CREATE POLICY inv_alloc_update_org ON public."InventoryAllocations"
  FOR UPDATE
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_update_inventory_org(organization_id))
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_update_inventory_org(organization_id));

DROP POLICY IF EXISTS inv_alloc_delete_org ON public."InventoryAllocations";
CREATE POLICY inv_alloc_delete_org ON public."InventoryAllocations"
  FOR DELETE
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_delete_inventory_org(organization_id));

DROP POLICY IF EXISTS inv_balances_select_org ON public."InventoryBalances";
CREATE POLICY inv_balances_select_org ON public."InventoryBalances"
  FOR SELECT
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_read_inventory_org(organization_id));

DROP POLICY IF EXISTS inv_balances_insert_org ON public."InventoryBalances";
CREATE POLICY inv_balances_insert_org ON public."InventoryBalances"
  FOR INSERT
  TO authenticated
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_create_inventory_org(organization_id));

DROP POLICY IF EXISTS inv_balances_update_org ON public."InventoryBalances";
CREATE POLICY inv_balances_update_org ON public."InventoryBalances"
  FOR UPDATE
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_update_inventory_org(organization_id))
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_update_inventory_org(organization_id));

DROP POLICY IF EXISTS warehouses_select_org ON public."Warehouses";
CREATE POLICY warehouses_select_org ON public."Warehouses"
  FOR SELECT
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_read_inventory_org(organization_id));

DROP POLICY IF EXISTS warehouses_insert_org ON public."Warehouses";
CREATE POLICY warehouses_insert_org ON public."Warehouses"
  FOR INSERT
  TO authenticated
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_create_inventory_org(organization_id));

DROP POLICY IF EXISTS warehouses_update_org ON public."Warehouses";
CREATE POLICY warehouses_update_org ON public."Warehouses"
  FOR UPDATE
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_update_inventory_org(organization_id))
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_update_inventory_org(organization_id));;
