
-- Phase 1: Enable RLS on CatalogItems, CatalogCategories, CatalogItemsMSRP, BOMComponents, BOMTemplateSlots
-- Uses existing helper functions: is_org_user_member_strict, is_portal_user_in_org, is_org_user_superadmin

-- =============================================
-- 1. CatalogItems
-- =============================================
ALTER TABLE "CatalogItems" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "catalogitems_select_own_org" ON "CatalogItems";
CREATE POLICY "catalogitems_select_own_org" ON "CatalogItems"
  FOR SELECT
  USING (
    is_org_user_member_strict(organization_id)
    OR is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "catalogitems_write_own_org" ON "CatalogItems";
CREATE POLICY "catalogitems_write_own_org" ON "CatalogItems"
  FOR ALL
  USING (
    is_org_user_superadmin(organization_id)
  )
  WITH CHECK (
    is_org_user_superadmin(organization_id)
  );

-- =============================================
-- 2. CatalogCategories
-- =============================================
ALTER TABLE "CatalogCategories" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "catalogcategories_select_own_org" ON "CatalogCategories";
CREATE POLICY "catalogcategories_select_own_org" ON "CatalogCategories"
  FOR SELECT
  USING (
    is_org_user_member_strict(organization_id)
    OR is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "catalogcategories_write_own_org" ON "CatalogCategories";
CREATE POLICY "catalogcategories_write_own_org" ON "CatalogCategories"
  FOR ALL
  USING (
    is_org_user_superadmin(organization_id)
  )
  WITH CHECK (
    is_org_user_superadmin(organization_id)
  );

-- =============================================
-- 3. CatalogItemsMSRP
-- =============================================
ALTER TABLE "CatalogItemsMSRP" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "catalogitemsmsrp_select_own_org" ON "CatalogItemsMSRP";
CREATE POLICY "catalogitemsmsrp_select_own_org" ON "CatalogItemsMSRP"
  FOR SELECT
  USING (
    is_org_user_member_strict(organization_id)
    OR is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "catalogitemsmsrp_write_own_org" ON "CatalogItemsMSRP";
CREATE POLICY "catalogitemsmsrp_write_own_org" ON "CatalogItemsMSRP"
  FOR ALL
  USING (
    is_org_user_superadmin(organization_id)
  )
  WITH CHECK (
    is_org_user_superadmin(organization_id)
  );

-- =============================================
-- 4. BOMComponents
-- =============================================
ALTER TABLE "BOMComponents" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bomcomponents_select_own_org" ON "BOMComponents";
CREATE POLICY "bomcomponents_select_own_org" ON "BOMComponents"
  FOR SELECT
  USING (
    is_org_user_member_strict(organization_id)
    OR is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "bomcomponents_write_own_org" ON "BOMComponents";
CREATE POLICY "bomcomponents_write_own_org" ON "BOMComponents"
  FOR ALL
  USING (
    is_org_user_superadmin(organization_id)
  )
  WITH CHECK (
    is_org_user_superadmin(organization_id)
  );

-- =============================================
-- 5. BOMTemplateSlots
-- =============================================
ALTER TABLE "BOMTemplateSlots" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bomtemplateslots_select_own_org" ON "BOMTemplateSlots";
CREATE POLICY "bomtemplateslots_select_own_org" ON "BOMTemplateSlots"
  FOR SELECT
  USING (
    is_org_user_member_strict(organization_id)
    OR is_portal_user_in_org(organization_id)
  );

DROP POLICY IF EXISTS "bomtemplateslots_write_own_org" ON "BOMTemplateSlots";
CREATE POLICY "bomtemplateslots_write_own_org" ON "BOMTemplateSlots"
  FOR ALL
  USING (
    is_org_user_superadmin(organization_id)
  )
  WITH CHECK (
    is_org_user_superadmin(organization_id)
  );
;
