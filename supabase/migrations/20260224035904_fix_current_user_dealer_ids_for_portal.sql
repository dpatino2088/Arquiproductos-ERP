-- current_user_dealer_ids only looked at OrganizationUsers; portal users (Dealer/Dealer Manager)
-- are in AppUsers (user_type='dealer') or DealerUsers, so they got [] and RLS blocked SalesOrders.
-- Now include AppUsers and DealerUsers so portal users see their dealer's orders.
CREATE OR REPLACE FUNCTION public.current_user_dealer_ids(p_organization_id uuid)
RETURNS uuid[]
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_ids uuid[];
  v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN array[]::uuid[];
  END IF;

  -- 1) AppUsers (portal users: user_type='dealer')
  SELECT coalesce(array_agg(distinct au.dealer_id), array[]::uuid[])
  INTO v_ids
  FROM public."AppUsers" au
  WHERE au.organization_id = p_organization_id
    AND (au.auth_user_id = v_uid OR au.email = lower(trim((auth.jwt()->>'email')::text)))
    AND coalesce(au.deleted, false) = false
    AND au.dealer_id IS NOT NULL
    AND au.user_type = 'dealer'
    AND au.status IN ('active', 'invited');

  IF coalesce(array_length(v_ids, 1), 0) > 0 THEN
    RETURN v_ids;
  END IF;

  -- 2) DealerUsers (legacy portal)
  SELECT coalesce(array_agg(distinct du.dealer_id), array[]::uuid[])
  INTO v_ids
  FROM public."DealerUsers" du
  WHERE du.organization_id = p_organization_id
    AND (du.user_id = v_uid OR du.portal_user_email = lower(trim((auth.jwt()->>'email')::text)))
    AND coalesce(du.deleted, false) = false
    AND du.dealer_id IS NOT NULL
    AND du.status IN ('active', 'invited');

  IF coalesce(array_length(v_ids, 1), 0) > 0 THEN
    RETURN v_ids;
  END IF;

  -- 3) OrganizationUsers (internal users with dealer scope)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'OrganizationUsers' AND column_name = 'dealer_id'
  ) THEN
    SELECT coalesce(array_agg(distinct ou.dealer_id), array[]::uuid[])
    INTO v_ids
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_organization_id
      AND ou.user_id = v_uid
      AND coalesce(ou.deleted, false) = false
      AND ou.dealer_id IS NOT NULL;
    RETURN coalesce(v_ids, array[]::uuid[]);
  END IF;

  RETURN array[]::uuid[];
END;
$$;;
