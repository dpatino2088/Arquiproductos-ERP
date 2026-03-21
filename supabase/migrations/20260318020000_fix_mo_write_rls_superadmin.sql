-- Fix ManufacturingOrders write RLS policy to include superadmin role.
-- The mo_write policy only allowed 'owner' and 'admin', silently blocking
-- all writes (update/insert/delete) for superadmin users.
-- Replace the inline check with the existing is_org_owner_or_admin() helper
-- which already includes superadmin.

DROP POLICY IF EXISTS mo_write ON "ManufacturingOrders";

CREATE POLICY mo_write ON "ManufacturingOrders"
  FOR ALL
  USING (is_org_owner_or_admin(organization_id))
  WITH CHECK (is_org_owner_or_admin(organization_id));
