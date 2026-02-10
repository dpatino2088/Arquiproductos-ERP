-- ====================================================
-- ConfiguredProducts RLS: allow Dealer (portal) users to SELECT
-- ====================================================
-- Portal users (DealerUsers) are not in OrganizationUsers, so they could not
-- read ConfiguredProducts. That caused "Configuration Not Found" when editing
-- a quote with a line that has a configured_product_id. This migration
-- extends SELECT policies so Dealer users can read ConfiguredProducts
-- (and ConfiguredProductOptions) for their organization.
-- ====================================================

SET search_path = public;

-- ConfiguredProducts: drop and recreate SELECT policy
DROP POLICY IF EXISTS "Users can view ConfiguredProducts for their organization" ON public."ConfiguredProducts";

CREATE POLICY "Users can view ConfiguredProducts for their organization"
  ON public."ConfiguredProducts"
  FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() AND deleted = false
    )
    OR
    organization_id IN (
      SELECT organization_id FROM public."DealerUsers"
      WHERE user_id = auth.uid() AND deleted = false
    )
  );

-- ConfiguredProductOptions: only if table exists (it may not exist in all environments)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'ConfiguredProductOptions'
  ) THEN
    DROP POLICY IF EXISTS "Users can view ConfiguredProductOptions for their organization" ON public."ConfiguredProductOptions";
    CREATE POLICY "Users can view ConfiguredProductOptions for their organization"
      ON public."ConfiguredProductOptions"
      FOR SELECT
      USING (
        configured_product_id IN (
          SELECT cp.id FROM public."ConfiguredProducts" cp
          INNER JOIN public."OrganizationUsers" ou ON cp.organization_id = ou.organization_id
          WHERE ou.user_id = auth.uid() AND ou.deleted = false
        )
        OR
        configured_product_id IN (
          SELECT cp.id FROM public."ConfiguredProducts" cp
          INNER JOIN public."DealerUsers" du ON cp.organization_id = du.organization_id
          WHERE du.user_id = auth.uid() AND du.deleted = false
        )
      );
  END IF;
END $$;
