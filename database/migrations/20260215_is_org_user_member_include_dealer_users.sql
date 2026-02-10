-- ====================================================
-- is_org_user_member: include Dealer (portal) users
-- ====================================================
-- QuoteLines (and other tables) use is_org_user_member(organization_id) for RLS.
-- The function only checked OrganizationUsers, so Dealer users could not
-- SELECT/INSERT/UPDATE QuoteLines and lines appeared as "0 lines" after save.
-- This migration extends the function to also return true when the current
-- user has a DealerUsers row for the given organization_id (active/invited).
-- ====================================================

SET search_path = public;

CREATE OR REPLACE FUNCTION public.is_org_user_member(p_org_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  -- Internal users: OrganizationUsers
  IF EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND ou.deleted = false
      AND ou.status IN ('active', 'invited')
  ) THEN
    RETURN true;
  END IF;

  -- Portal/Dealer users: DealerUsers
  IF EXISTS (
    SELECT 1
    FROM public."DealerUsers" du
    WHERE du.organization_id = p_org_id
      AND du.user_id = auth.uid()
      AND du.deleted = false
      AND du.status IN ('active', 'invited')
  ) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

COMMENT ON FUNCTION public.is_org_user_member(uuid) IS
  'Returns true if current user is an active/invited member of the organization via OrganizationUsers OR DealerUsers (portal).';
