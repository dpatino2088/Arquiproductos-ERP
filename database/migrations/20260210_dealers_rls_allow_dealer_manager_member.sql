-- Dealers RLS: allow Dealer Manager and Dealer Member to SELECT (read)
-- So they can see dealer data including logo_url on Proposals.
-- Before: dealers_select_own_org used is_org_member(organization_id) which may
--   only include certain org roles; Super Admin bypasses RLS.
-- After: use is_org_user_member(organization_id) so any org member (including
--   dealer_manager, dealer_member in OrganizationUsers) and portal users
--   (DealerUsers) can read Dealers for their organization.
-- INSERT/UPDATE stay restricted to is_org_owner_or_admin.

BEGIN;

DROP POLICY IF EXISTS dealers_select_own_org ON public."Dealers";

CREATE POLICY dealers_select_own_org
  ON public."Dealers" FOR SELECT
  USING (
    public.is_org_user_member(organization_id)
    AND (deleted IS NULL OR deleted = false)
  );

COMMENT ON POLICY dealers_select_own_org ON public."Dealers" IS
  'Allow org members (incl. dealer_manager, dealer_member) and DealerUsers to read dealers; needed for logo_url on Proposals.';

COMMIT;
