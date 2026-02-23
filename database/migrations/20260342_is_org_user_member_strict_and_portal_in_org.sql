-- =============================================================================
-- Migration: is_org_user_member_strict + is_portal_user_in_org
-- =============================================================================
-- Fix dealer mixing: is_org_user_member() includes DealerUsers, so portal users
-- could pass as org and see data without dealer filter.
-- 1) Create is_org_user_member_strict: only OrganizationUsers (no DealerUsers)
-- 2) Create is_portal_user_in_org: portal user in DealerUsers for that org
-- 3) Migrate dealer-sensitive tables: use is_org_user_member_strict in org branch
-- 4) Migrate org-only tables: use (is_org_user_member_strict OR is_portal_user_in_org)
--
-- Ver: docs/DEALER_USER_MIXING_DIAGNOSTIC.md
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) is_org_user_member_strict: solo OrganizationUsers
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_org_user_member_strict(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND (ou.deleted IS NULL OR ou.deleted = false)
      AND (ou.status IS NULL OR ou.status IN ('active', 'invited'))
  );
$$;

COMMENT ON FUNCTION public.is_org_user_member_strict(uuid)
  IS 'Returns true if current user is an active/invited member via OrganizationUsers ONLY. DealerUsers excluded to avoid portal users passing as org.';

REVOKE ALL ON FUNCTION public.is_org_user_member_strict(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.is_org_user_member_strict(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_org_user_member_strict(uuid) TO service_role;


-- -----------------------------------------------------------------------------
-- 2) is_portal_user_in_org: portal user belongs to org via DealerUsers
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_portal_user_in_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public."DealerUsers" du
    WHERE du.organization_id = p_org_id
      AND du.user_id = auth.uid()
      AND (du.deleted IS NULL OR du.deleted = false)
      AND (du.status IS NULL OR du.status IN ('active', 'invited'))
  );
$$;

COMMENT ON FUNCTION public.is_portal_user_in_org(uuid)
  IS 'Returns true if current user is a portal user (DealerUser) for the given org. Used in org-only tables so portal users can access catalog, BOM, etc.';

REVOKE ALL ON FUNCTION public.is_portal_user_in_org(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.is_portal_user_in_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_portal_user_in_org(uuid) TO service_role;


-- -----------------------------------------------------------------------------
-- 3) Tablas con dealer_id: Proposals, Quotes, DirectoryContacts, DirectoryCustomers
--    Reemplazar is_org_user_member → is_org_user_member_strict en rama org
-- -----------------------------------------------------------------------------

-- Proposals (mantener estructura de 20260340: member_manager + fallback)
DROP POLICY IF EXISTS "proposals_select" ON public."Proposals";
CREATE POLICY "proposals_select" ON public."Proposals"
  FOR SELECT TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
      OR
      (
        public.current_dealer_id(organization_id) IS NOT NULL
        AND dealer_id = public.current_dealer_id(organization_id)
      )
      OR
      (
        dealer_id IS NOT NULL
        AND public.is_dealer_portal_user(dealer_id)
      )
    )
  );

DROP POLICY IF EXISTS "proposals_update" ON public."Proposals";
CREATE POLICY "proposals_update" ON public."Proposals"
  FOR UPDATE TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
      OR
      (
        dealer_id IS NOT NULL
        AND public.is_dealer_portal_user_with_write(dealer_id)
      )
      OR
      (
        dealer_id IS NOT NULL
        AND public.is_dealer_portal_user(dealer_id)
        AND created_by_user_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (public.current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id)))
      OR
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
    )
  );

DROP POLICY IF EXISTS "proposals_insert" ON public."Proposals";
CREATE POLICY "proposals_insert" ON public."Proposals"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (public.current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id)))
      OR
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
    )
  );


-- Quotes
DROP POLICY IF EXISTS "quotes_select" ON public."Quotes";
CREATE POLICY "quotes_select" ON public."Quotes"
  FOR SELECT TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
      OR
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
    )
  );

DROP POLICY IF EXISTS "quotes_insert" ON public."Quotes";
CREATE POLICY "quotes_insert" ON public."Quotes"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (public.current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id)))
      OR
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
    )
  );

DROP POLICY IF EXISTS "quotes_update" ON public."Quotes";
CREATE POLICY "quotes_update" ON public."Quotes"
  FOR UPDATE TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
      OR
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (public.current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id)))
      OR
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
    )
  );


-- DirectoryContacts
DROP POLICY IF EXISTS "dircontacts_select" ON public."DirectoryContacts";
CREATE POLICY "dircontacts_select" ON public."DirectoryContacts"
  FOR SELECT TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
      OR
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
    )
  );

DROP POLICY IF EXISTS "dircontacts_insert" ON public."DirectoryContacts";
CREATE POLICY "dircontacts_insert" ON public."DirectoryContacts"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (public.current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id)))
      OR
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
    )
  );

DROP POLICY IF EXISTS "dircontacts_update" ON public."DirectoryContacts";
CREATE POLICY "dircontacts_update" ON public."DirectoryContacts"
  FOR UPDATE TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
      OR
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (public.current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id)))
      OR
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
    )
  );


-- DirectoryCustomers
DROP POLICY IF EXISTS "dircustomers_select" ON public."DirectoryCustomers";
CREATE POLICY "dircustomers_select" ON public."DirectoryCustomers"
  FOR SELECT TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
      OR
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
    )
  );

DROP POLICY IF EXISTS "dircustomers_insert" ON public."DirectoryCustomers";
CREATE POLICY "dircustomers_insert" ON public."DirectoryCustomers"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (public.current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id)))
      OR
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
    )
  );

DROP POLICY IF EXISTS "dircustomers_update" ON public."DirectoryCustomers";
CREATE POLICY "dircustomers_update" ON public."DirectoryCustomers"
  FOR UPDATE TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
      OR
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (public.current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id)))
      OR
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
    )
  );


-- -----------------------------------------------------------------------------
-- 4) Tablas org-only: (is_org_user_member_strict OR is_portal_user_in_org)
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS "catalogitemcomponents_select_own_org" ON public."CatalogItemComponents";
CREATE POLICY "catalogitemcomponents_select_own_org" ON public."CatalogItemComponents"
  FOR SELECT TO authenticated
  USING (
    public.is_org_user_superadmin(organization_id)
    OR public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "catalogitemcomponents_write_own_org" ON public."CatalogItemComponents";
CREATE POLICY "catalogitemcomponents_write_own_org" ON public."CatalogItemComponents"
  FOR ALL TO authenticated
  USING (
    public.is_org_user_superadmin(organization_id)
    OR public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  )
  WITH CHECK (
    public.is_org_user_superadmin(organization_id)
    OR public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "dealers_select_own_org" ON public."Dealers";
CREATE POLICY "dealers_select_own_org" ON public."Dealers"
  FOR SELECT
  USING (
    (deleted IS NULL OR deleted = false)
    AND (
      public.is_org_user_member_strict(organization_id)
      OR public.is_portal_user_in_org(organization_id)
    )
  );

DROP POLICY IF EXISTS "dealerusers_select_bomtemplates" ON public."BOMTemplates";
CREATE POLICY "dealerusers_select_bomtemplates" ON public."BOMTemplates"
  FOR SELECT
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "dealerusers_select_configured_products" ON public."ConfiguredProducts";
CREATE POLICY "dealerusers_select_configured_products" ON public."ConfiguredProducts"
  FOR SELECT
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

-- ConfiguredProducts insert/update: allow portal users (org-only table)
DROP POLICY IF EXISTS "configuredproducts_org_members_insert" ON public."ConfiguredProducts";
CREATE POLICY "configuredproducts_org_members_insert" ON public."ConfiguredProducts"
  FOR INSERT
  WITH CHECK (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "configuredproducts_org_members_select" ON public."ConfiguredProducts";
CREATE POLICY "configuredproducts_org_members_select" ON public."ConfiguredProducts"
  FOR SELECT
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "configuredproducts_org_members_update" ON public."ConfiguredProducts";
CREATE POLICY "configuredproducts_org_members_update" ON public."ConfiguredProducts"
  FOR UPDATE
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  )
  WITH CHECK (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "org_admins_update" ON public."BOMTemplates";
CREATE POLICY "org_admins_update" ON public."BOMTemplates"
  FOR UPDATE
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  )
  WITH CHECK (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "org_admins_write" ON public."BOMTemplates";
CREATE POLICY "org_admins_write" ON public."BOMTemplates"
  FOR INSERT
  WITH CHECK (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "org_members_select" ON public."BOMTemplates";
CREATE POLICY "org_members_select" ON public."BOMTemplates"
  FOR SELECT
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "inv_balances_insert_org" ON public."InventoryBalances";
CREATE POLICY "inv_balances_insert_org" ON public."InventoryBalances"
  FOR INSERT
  WITH CHECK (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "inv_balances_select_org" ON public."InventoryBalances";
CREATE POLICY "inv_balances_select_org" ON public."InventoryBalances"
  FOR SELECT
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "inv_balances_update_org" ON public."InventoryBalances";
CREATE POLICY "inv_balances_update_org" ON public."InventoryBalances"
  FOR UPDATE
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "inv_profiles_insert_org" ON public."InventoryItemProfiles";
CREATE POLICY "inv_profiles_insert_org" ON public."InventoryItemProfiles"
  FOR INSERT
  WITH CHECK (
    public.is_org_user_member_strict((SELECT w.organization_id FROM public."Warehouses" w WHERE w.id = warehouse_id))
    OR public.is_portal_user_in_org((SELECT w.organization_id FROM public."Warehouses" w WHERE w.id = warehouse_id))
  );

DROP POLICY IF EXISTS "inv_profiles_select_org" ON public."InventoryItemProfiles";
CREATE POLICY "inv_profiles_select_org" ON public."InventoryItemProfiles"
  FOR SELECT
  USING (
    public.is_org_user_member_strict((SELECT w.organization_id FROM public."Warehouses" w WHERE w.id = warehouse_id))
    OR public.is_portal_user_in_org((SELECT w.organization_id FROM public."Warehouses" w WHERE w.id = warehouse_id))
  );

DROP POLICY IF EXISTS "inv_profiles_update_org" ON public."InventoryItemProfiles";
CREATE POLICY "inv_profiles_update_org" ON public."InventoryItemProfiles"
  FOR UPDATE
  USING (
    public.is_org_user_member_strict((SELECT w.organization_id FROM public."Warehouses" w WHERE w.id = warehouse_id))
    OR public.is_portal_user_in_org((SELECT w.organization_id FROM public."Warehouses" w WHERE w.id = warehouse_id))
  );

DROP POLICY IF EXISTS "purchase_orders_insert_org" ON public."PurchaseOrders";
CREATE POLICY "purchase_orders_insert_org" ON public."PurchaseOrders"
  FOR INSERT
  WITH CHECK (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "purchase_orders_select_org" ON public."PurchaseOrders";
CREATE POLICY "purchase_orders_select_org" ON public."PurchaseOrders"
  FOR SELECT
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "purchase_orders_update_org" ON public."PurchaseOrders";
CREATE POLICY "purchase_orders_update_org" ON public."PurchaseOrders"
  FOR UPDATE
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "po_lines_insert_via_po" ON public."PurchaseOrderLines";
CREATE POLICY "po_lines_insert_via_po" ON public."PurchaseOrderLines"
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."PurchaseOrders" po
      WHERE po.id = purchase_order_id
        AND (public.is_org_user_member_strict(po.organization_id) OR public.is_portal_user_in_org(po.organization_id))
    )
  );

DROP POLICY IF EXISTS "po_lines_select_via_po" ON public."PurchaseOrderLines";
CREATE POLICY "po_lines_select_via_po" ON public."PurchaseOrderLines"
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public."PurchaseOrders" po
      WHERE po.id = purchase_order_id
        AND (public.is_org_user_member_strict(po.organization_id) OR public.is_portal_user_in_org(po.organization_id))
    )
  );

DROP POLICY IF EXISTS "po_lines_update_via_po" ON public."PurchaseOrderLines";
CREATE POLICY "po_lines_update_via_po" ON public."PurchaseOrderLines"
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public."PurchaseOrders" po
      WHERE po.id = purchase_order_id
        AND (public.is_org_user_member_strict(po.organization_id) OR public.is_portal_user_in_org(po.organization_id))
    )
  );

DROP POLICY IF EXISTS "qlc_delete" ON public."QuoteLineComponents";
CREATE POLICY "qlc_delete" ON public."QuoteLineComponents"
  FOR DELETE
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "qlc_insert" ON public."QuoteLineComponents";
CREATE POLICY "qlc_insert" ON public."QuoteLineComponents"
  FOR INSERT
  WITH CHECK (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "qlc_select" ON public."QuoteLineComponents";
CREATE POLICY "qlc_select" ON public."QuoteLineComponents"
  FOR SELECT
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "qlc_update" ON public."QuoteLineComponents";
CREATE POLICY "qlc_update" ON public."QuoteLineComponents"
  FOR UPDATE
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  )
  WITH CHECK (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "quotelines_delete" ON public."QuoteLines";
CREATE POLICY "quotelines_delete" ON public."QuoteLines"
  FOR DELETE
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "quotelines_insert" ON public."QuoteLines";
CREATE POLICY "quotelines_insert" ON public."QuoteLines"
  FOR INSERT
  WITH CHECK (
    (public.is_org_user_member_strict(organization_id) OR public.is_portal_user_in_org(organization_id))
    AND EXISTS (
      SELECT 1 FROM public."Quotes" q
      WHERE q.id = quote_id
        AND q.organization_id = "QuoteLines".organization_id
        AND q.deleted = false
    )
  );

DROP POLICY IF EXISTS "quotelines_select" ON public."QuoteLines";
CREATE POLICY "quotelines_select" ON public."QuoteLines"
  FOR SELECT
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "quotelines_update" ON public."QuoteLines";
CREATE POLICY "quotelines_update" ON public."QuoteLines"
  FOR UPDATE
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  )
  WITH CHECK (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "select_catalog_item_roll_specs" ON public."CatalogItemRollSpecs";
CREATE POLICY "select_catalog_item_roll_specs" ON public."CatalogItemRollSpecs"
  FOR SELECT
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "select_catalog_item_supply" ON public."CatalogItemSupply";
CREATE POLICY "select_catalog_item_supply" ON public."CatalogItemSupply"
  FOR SELECT
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "warehouses_insert_org" ON public."Warehouses";
CREATE POLICY "warehouses_insert_org" ON public."Warehouses"
  FOR INSERT
  WITH CHECK (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "warehouses_select_org" ON public."Warehouses";
CREATE POLICY "warehouses_select_org" ON public."Warehouses"
  FOR SELECT
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "warehouses_update_org" ON public."Warehouses";
CREATE POLICY "warehouses_update_org" ON public."Warehouses"
  FOR UPDATE
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );

-- -----------------------------------------------------------------------------
-- Post-migration audit: should return 0 rows
-- Run after applying to confirm no policies still use is_org_user_member
-- -----------------------------------------------------------------------------
-- SELECT n.nspname, c.relname, p.polname
-- FROM pg_policy p
-- JOIN pg_class c ON c.oid = p.polrelid
-- JOIN pg_namespace n ON n.oid = c.relnamespace
-- WHERE n.nspname = 'public'
--   AND (pg_get_expr(p.polqual, p.polrelid) ILIKE '%is_org_user_member(%'
--        OR pg_get_expr(p.polwithcheck, p.polrelid) ILIKE '%is_org_user_member(%');
