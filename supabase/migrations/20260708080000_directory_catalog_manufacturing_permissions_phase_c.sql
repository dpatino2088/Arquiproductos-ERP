-- Phase C (core remaining modules): Directory, Catalog, Manufacturing
-- Preserve existing tenant/dealer scoping while requiring permission codes.

CREATE OR REPLACE FUNCTION public.can_read_directory_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'directory.read',
      'directory.create',
      'directory.edit',
      'directory.delete',
      'directory.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_create_directory_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'directory.create',
      'directory.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_update_directory_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'directory.edit',
      'directory.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_read_catalog_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'catalog.read',
      'catalog.create',
      'catalog.edit',
      'catalog.delete',
      'catalog.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_write_catalog_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'catalog.create',
      'catalog.edit',
      'catalog.delete',
      'catalog.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_read_manufacturing_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'manufacturing.read',
      'manufacturing.mo.read',
      'manufacturing.wo.read',
      'manufacturing.workstation.read',
      'manufacturing.cutopt.read',
      'manufacturing.calendar.read',
      'manufacturing.write',
      'manufacturing.edit',
      'manufacturing.create',
      'manufacturing.delete'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_write_manufacturing_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'manufacturing.write',
      'manufacturing.edit',
      'manufacturing.create',
      'manufacturing.delete',
      'manufacturing.mo.write',
      'manufacturing.wo.write'
    ]::text[]
  );
$$;

GRANT EXECUTE ON FUNCTION public.can_read_directory_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_create_directory_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_update_directory_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_catalog_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_catalog_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_manufacturing_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_manufacturing_org(uuid) TO authenticated;

-- DirectoryContacts
DROP POLICY IF EXISTS dircontacts_select ON public."DirectoryContacts";
CREATE POLICY dircontacts_select ON public."DirectoryContacts"
  FOR SELECT
  TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (
        session_is_org_user(organization_id)
        AND public.can_read_directory_org(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

DROP POLICY IF EXISTS dircontacts_insert ON public."DirectoryContacts";
CREATE POLICY dircontacts_insert ON public."DirectoryContacts"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        session_is_org_user(organization_id)
        AND public.can_create_directory_org(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

DROP POLICY IF EXISTS dircontacts_update ON public."DirectoryContacts";
CREATE POLICY dircontacts_update ON public."DirectoryContacts"
  FOR UPDATE
  TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (
        session_is_org_user(organization_id)
        AND public.can_update_directory_org(organization_id)
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
        AND public.can_update_directory_org(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

-- DirectoryCustomers
DROP POLICY IF EXISTS dircustomers_select ON public."DirectoryCustomers";
CREATE POLICY dircustomers_select ON public."DirectoryCustomers"
  FOR SELECT
  TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (
        session_is_org_user(organization_id)
        AND public.can_read_directory_org(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

DROP POLICY IF EXISTS dircustomers_insert ON public."DirectoryCustomers";
CREATE POLICY dircustomers_insert ON public."DirectoryCustomers"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        session_is_org_user(organization_id)
        AND public.can_create_directory_org(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

DROP POLICY IF EXISTS dircustomers_update ON public."DirectoryCustomers";
CREATE POLICY dircustomers_update ON public."DirectoryCustomers"
  FOR UPDATE
  TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (
        session_is_org_user(organization_id)
        AND public.can_update_directory_org(organization_id)
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
        AND public.can_update_directory_org(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
    )
  );

-- Catalog core
DROP POLICY IF EXISTS catalogitems_select_own_org ON public."CatalogItems";
CREATE POLICY catalogitems_select_own_org ON public."CatalogItems"
  FOR SELECT
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_read_catalog_org(organization_id));

DROP POLICY IF EXISTS catalogitems_write_own_org ON public."CatalogItems";
CREATE POLICY catalogitems_write_own_org ON public."CatalogItems"
  FOR ALL
  TO authenticated
  USING (public.can_write_catalog_org(organization_id))
  WITH CHECK (public.can_write_catalog_org(organization_id));

DROP POLICY IF EXISTS catalogcategories_select_own_org ON public."CatalogCategories";
CREATE POLICY catalogcategories_select_own_org ON public."CatalogCategories"
  FOR SELECT
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_read_catalog_org(organization_id));

DROP POLICY IF EXISTS catalogcategories_write_own_org ON public."CatalogCategories";
CREATE POLICY catalogcategories_write_own_org ON public."CatalogCategories"
  FOR ALL
  TO authenticated
  USING (public.can_write_catalog_org(organization_id))
  WITH CHECK (public.can_write_catalog_org(organization_id));

DROP POLICY IF EXISTS dealerusers_select_bomtemplates ON public."BOMTemplates";
DROP POLICY IF EXISTS org_members_select ON public."BOMTemplates";
CREATE POLICY bomtemplates_select_own_org ON public."BOMTemplates"
  FOR SELECT
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_read_catalog_org(organization_id));

DROP POLICY IF EXISTS org_admins_write ON public."BOMTemplates";
DROP POLICY IF EXISTS org_admins_update ON public."BOMTemplates";
CREATE POLICY bomtemplates_insert_own_org ON public."BOMTemplates"
  FOR INSERT
  TO authenticated
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_write_catalog_org(organization_id));

CREATE POLICY bomtemplates_update_own_org ON public."BOMTemplates"
  FOR UPDATE
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_write_catalog_org(organization_id))
  WITH CHECK (is_portal_user_in_org(organization_id) OR public.can_write_catalog_org(organization_id));

DROP POLICY IF EXISTS bomcomponents_select_own_org ON public."BOMComponents";
CREATE POLICY bomcomponents_select_own_org ON public."BOMComponents"
  FOR SELECT
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_read_catalog_org(organization_id));

DROP POLICY IF EXISTS bomcomponents_write_own_org ON public."BOMComponents";
CREATE POLICY bomcomponents_write_own_org ON public."BOMComponents"
  FOR ALL
  TO authenticated
  USING (public.can_write_catalog_org(organization_id))
  WITH CHECK (public.can_write_catalog_org(organization_id));

DROP POLICY IF EXISTS bomtemplateslots_select_own_org ON public."BOMTemplateSlots";
CREATE POLICY bomtemplateslots_select_own_org ON public."BOMTemplateSlots"
  FOR SELECT
  TO authenticated
  USING (is_portal_user_in_org(organization_id) OR public.can_read_catalog_org(organization_id));

DROP POLICY IF EXISTS bomtemplateslots_write_own_org ON public."BOMTemplateSlots";
CREATE POLICY bomtemplateslots_write_own_org ON public."BOMTemplateSlots"
  FOR ALL
  TO authenticated
  USING (public.can_write_catalog_org(organization_id))
  WITH CHECK (public.can_write_catalog_org(organization_id));

-- Manufacturing core
DROP POLICY IF EXISTS mo_select ON public."ManufacturingOrders";
CREATE POLICY mo_select ON public."ManufacturingOrders"
  FOR SELECT
  TO authenticated
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
    AND public.can_read_manufacturing_org(organization_id)
  );

DROP POLICY IF EXISTS mo_write ON public."ManufacturingOrders";
CREATE POLICY mo_write ON public."ManufacturingOrders"
  FOR ALL
  TO authenticated
  USING (public.can_write_manufacturing_org(organization_id))
  WITH CHECK (public.can_write_manufacturing_org(organization_id));

DROP POLICY IF EXISTS wot_select ON public."WorkOrderTasks";
CREATE POLICY wot_select ON public."WorkOrderTasks"
  FOR SELECT
  TO authenticated
  USING ((deleted = false) AND public.can_read_manufacturing_org(organization_id));

DROP POLICY IF EXISTS wot_insert ON public."WorkOrderTasks";
CREATE POLICY wot_insert ON public."WorkOrderTasks"
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_write_manufacturing_org(organization_id));

DROP POLICY IF EXISTS wot_update ON public."WorkOrderTasks";
CREATE POLICY wot_update ON public."WorkOrderTasks"
  FOR UPDATE
  TO authenticated
  USING (public.can_write_manufacturing_org(organization_id))
  WITH CHECK (public.can_write_manufacturing_org(organization_id));

DROP POLICY IF EXISTS wot_delete ON public."WorkOrderTasks";
CREATE POLICY wot_delete ON public."WorkOrderTasks"
  FOR DELETE
  TO authenticated
  USING (public.can_write_manufacturing_org(organization_id));

DROP POLICY IF EXISTS wotl_select ON public."WorkOrderTaskLines";
CREATE POLICY wotl_select ON public."WorkOrderTaskLines"
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."WorkOrderTasks" t
      WHERE t.id = public."WorkOrderTaskLines".task_id
        AND t.deleted = false
        AND public.can_read_manufacturing_org(t.organization_id)
    )
  );

DROP POLICY IF EXISTS wotl_insert ON public."WorkOrderTaskLines";
CREATE POLICY wotl_insert ON public."WorkOrderTaskLines"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."WorkOrderTasks" t
      WHERE t.id = public."WorkOrderTaskLines".task_id
        AND public.can_write_manufacturing_org(t.organization_id)
    )
  );

DROP POLICY IF EXISTS wotl_update ON public."WorkOrderTaskLines";
CREATE POLICY wotl_update ON public."WorkOrderTaskLines"
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."WorkOrderTasks" t
      WHERE t.id = public."WorkOrderTaskLines".task_id
        AND public.can_write_manufacturing_org(t.organization_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."WorkOrderTasks" t
      WHERE t.id = public."WorkOrderTaskLines".task_id
        AND public.can_write_manufacturing_org(t.organization_id)
    )
  );

DROP POLICY IF EXISTS wc_select ON public."WorkCenters";
CREATE POLICY wc_select ON public."WorkCenters"
  FOR SELECT
  TO authenticated
  USING ((deleted = false) AND public.can_read_manufacturing_org(organization_id));

DROP POLICY IF EXISTS wc_insert ON public."WorkCenters";
CREATE POLICY wc_insert ON public."WorkCenters"
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_write_manufacturing_org(organization_id));

DROP POLICY IF EXISTS wc_update ON public."WorkCenters";
CREATE POLICY wc_update ON public."WorkCenters"
  FOR UPDATE
  TO authenticated
  USING (public.can_write_manufacturing_org(organization_id))
  WITH CHECK (public.can_write_manufacturing_org(organization_id));

DROP POLICY IF EXISTS wc_delete ON public."WorkCenters";
CREATE POLICY wc_delete ON public."WorkCenters"
  FOR DELETE
  TO authenticated
  USING (public.can_write_manufacturing_org(organization_id));

DROP POLICY IF EXISTS mo_attachments_select ON public.manufacturing_order_attachments;
CREATE POLICY mo_attachments_select ON public.manufacturing_order_attachments
  FOR SELECT
  TO authenticated
  USING (public.can_read_manufacturing_org(organization_id));

DROP POLICY IF EXISTS mo_attachments_insert ON public.manufacturing_order_attachments;
CREATE POLICY mo_attachments_insert ON public.manufacturing_order_attachments
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_write_manufacturing_org(organization_id));

DROP POLICY IF EXISTS mo_attachments_delete ON public.manufacturing_order_attachments;
CREATE POLICY mo_attachments_delete ON public.manufacturing_order_attachments
  FOR DELETE
  TO authenticated
  USING (public.can_write_manufacturing_org(organization_id));
