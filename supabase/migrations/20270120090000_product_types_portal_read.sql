-- Portal dealers need to read ProductTypes (fulfillment_type) so Deliveries can
-- include supply_only lines that are ready/allocated and show Partial vs Ready.

SET search_path = public;

DROP POLICY IF EXISTS rls_producttypes_select ON public."ProductTypes";
CREATE POLICY rls_producttypes_select
  ON public."ProductTypes"
  FOR SELECT
  USING (
    public.is_org_user_member(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );
