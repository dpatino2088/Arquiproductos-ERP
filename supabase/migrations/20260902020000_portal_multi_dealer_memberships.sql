-- Multi-dealer memberships for portal (dealer) users.
--
-- AppUsers already supports N rows per auth user (one per dealer, unique index on
-- auth_user_id + user_type + dealer_id) and the RLS helpers (session_is_dealer_portal,
-- current_user_dealer_ids) are membership-aware. What was missing:
--
--  1. current_dealer_id() picked an arbitrary row (LIMIT 1) for dealer users.
--     Now it honors the user's chosen membership (AppUserPreferences.active_dealer_id)
--     when that dealer is still one of their memberships, else the oldest membership.
--  2. init_session_context() pinned app.dealer_id/app.role_code to an arbitrary row.
--     Now it follows the active membership (role can differ per dealer).
--  3. set_acting_dealer() rejected portal users. Now dealer users can switch among
--     THEIR memberships (never "All dealers", never someone else's dealer).
--  4. get_my_dealer_memberships(): list for the UI switcher.
--
-- Single-membership users are unaffected: no preference -> oldest (only) membership.

-- 1) current_dealer_id(): membership-aware resolution ------------------------
CREATE OR REPLACE FUNCTION public.current_dealer_id()
RETURNS uuid
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
  WITH me AS (
    SELECT au.id, au.user_type, au.dealer_id, au.status, au.created_at
    FROM public."AppUsers" au
    WHERE au.auth_user_id = auth.uid()
      AND au.deleted = false
  )
  SELECT CASE
    WHEN EXISTS (SELECT 1 FROM me WHERE user_type = 'org') THEN (
      -- Org users: acting-as preference (NULL = all dealers), as before.
      SELECT pref.active_dealer_id
      FROM public."AppUserPreferences" pref
      JOIN me ON me.id = pref.user_id
      WHERE me.user_type = 'org'
      LIMIT 1
    )
    ELSE COALESCE(
      -- Dealer users: chosen membership, only if still a valid membership.
      (SELECT pref.active_dealer_id
       FROM public."AppUserPreferences" pref
       JOIN me ON me.id = pref.user_id
       WHERE pref.active_dealer_id IN (
         SELECT dealer_id FROM me
         WHERE user_type = 'dealer' AND status IN ('active', 'invited')
       )
       LIMIT 1),
      -- Default: oldest membership (previous single-row behavior).
      (SELECT dealer_id FROM me WHERE user_type = 'dealer' ORDER BY created_at LIMIT 1)
    )
  END;
$function$;

-- 2) init_session_context(): role/org follow the active membership ------------
CREATE OR REPLACE FUNCTION public.init_session_context()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_row record;
  v_dealer_id uuid;
  v_member record;
BEGIN
  SELECT au.user_type, au.organization_id, au.role_code, au.dealer_id, au.id
    INTO v_row
  FROM public."AppUsers" au
  WHERE au.auth_user_id = auth.uid()
    AND au.deleted = false
  ORDER BY CASE WHEN au.user_type = 'org' THEN 0 ELSE 1 END
  LIMIT 1;

  IF v_row IS NULL THEN
    PERFORM set_config('app.user_type', '', true);
    PERFORM set_config('app.organization_id', '', true);
    PERFORM set_config('app.role_code', '', true);
    PERFORM set_config('app.dealer_id', '', true);
    RETURN;
  END IF;

  PERFORM set_config('app.user_type', COALESCE(v_row.user_type, ''), true);

  IF v_row.user_type = 'org' THEN
    SELECT pref.active_dealer_id INTO v_dealer_id
    FROM public."AppUserPreferences" pref
    WHERE pref.user_id = v_row.id;

    PERFORM set_config('app.organization_id', COALESCE(v_row.organization_id::text, ''), true);
    PERFORM set_config('app.role_code', COALESCE(v_row.role_code, ''), true);
  ELSE
    -- Dealer user: resolve the active membership; role/org come from that row
    -- (a user can be dealer_manager at one dealer and dealer_member at another).
    v_dealer_id := public.current_dealer_id();

    SELECT au.role_code, au.organization_id INTO v_member
    FROM public."AppUsers" au
    WHERE au.auth_user_id = auth.uid()
      AND au.deleted = false
      AND au.user_type = 'dealer'
      AND au.dealer_id = v_dealer_id
    ORDER BY au.created_at
    LIMIT 1;

    PERFORM set_config('app.organization_id',
      COALESCE(v_member.organization_id::text, v_row.organization_id::text, ''), true);
    PERFORM set_config('app.role_code',
      COALESCE(v_member.role_code, v_row.role_code, ''), true);
  END IF;

  PERFORM set_config('app.dealer_id', COALESCE(v_dealer_id::text, ''), true);
END;
$function$;

-- 3) set_acting_dealer(): portal users can switch among their memberships -----
CREATE OR REPLACE FUNCTION public.set_acting_dealer(p_dealer_id uuid)
RETURNS TABLE(active_dealer_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_app_user_id uuid;
  v_org_id uuid;
  v_user_type text;
  v_ok boolean;
  v_member_role text;
  v_anchor_id uuid;
BEGIN
  SELECT id, organization_id, user_type
    INTO v_app_user_id, v_org_id, v_user_type
  FROM public."AppUsers"
  WHERE auth_user_id = auth.uid()
    AND deleted = false
  ORDER BY CASE WHEN user_type = 'org' THEN 0 ELSE 1 END
  LIMIT 1;

  IF v_app_user_id IS NULL THEN
    RAISE EXCEPTION 'AppUser not found for auth user';
  END IF;

  IF v_user_type = 'org' THEN
    -- Org users: unchanged (NULL = all dealers; any dealer of the org).
    IF p_dealer_id IS NOT NULL THEN
      SELECT EXISTS(
        SELECT 1 FROM public."Dealers" d
        WHERE d.id = p_dealer_id
          AND d.organization_id = v_org_id
          AND (d.deleted IS NULL OR d.deleted = false)
      ) INTO v_ok;

      IF NOT v_ok THEN
        RAISE EXCEPTION 'Dealer not in same organization or does not exist';
      END IF;
    END IF;

    INSERT INTO public."AppUserPreferences"(user_id, active_dealer_id)
    VALUES (v_app_user_id, p_dealer_id)
    ON CONFLICT (user_id)
    DO UPDATE SET active_dealer_id = excluded.active_dealer_id;

    PERFORM set_config('app.dealer_id', COALESCE(p_dealer_id::text, ''), true);
    RETURN QUERY SELECT p_dealer_id;
    RETURN;
  END IF;

  -- Dealer (portal) user: must pick one of THEIR memberships; no "All dealers".
  IF p_dealer_id IS NULL THEN
    RAISE EXCEPTION 'Dealer users must select a specific dealer';
  END IF;

  SELECT au.role_code INTO v_member_role
  FROM public."AppUsers" au
  WHERE au.auth_user_id = auth.uid()
    AND au.deleted = false
    AND au.user_type = 'dealer'
    AND au.dealer_id = p_dealer_id
    AND au.status IN ('active', 'invited')
  ORDER BY au.created_at
  LIMIT 1;

  IF v_member_role IS NULL THEN
    RAISE EXCEPTION 'Not a member of this dealer';
  END IF;

  -- Store the preference on the OLDEST membership row (stable anchor) and clear
  -- any stray preference rows on the user''s other membership rows.
  SELECT id INTO v_anchor_id
  FROM public."AppUsers"
  WHERE auth_user_id = auth.uid()
    AND deleted = false
    AND user_type = 'dealer'
  ORDER BY created_at
  LIMIT 1;

  DELETE FROM public."AppUserPreferences"
  WHERE user_id IN (
    SELECT id FROM public."AppUsers"
    WHERE auth_user_id = auth.uid() AND user_type = 'dealer' AND id <> v_anchor_id
  );

  INSERT INTO public."AppUserPreferences"(user_id, active_dealer_id)
  VALUES (v_anchor_id, p_dealer_id)
  ON CONFLICT (user_id)
  DO UPDATE SET active_dealer_id = excluded.active_dealer_id;

  PERFORM set_config('app.dealer_id', p_dealer_id::text, true);
  PERFORM set_config('app.role_code', COALESCE(v_member_role, ''), true);

  RETURN QUERY SELECT p_dealer_id;
END;
$function$;

-- 4) Membership list for the UI switcher --------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_dealer_memberships()
RETURNS TABLE(dealer_id uuid, dealer_name text, role_code text, is_active boolean)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
  SELECT au.dealer_id,
         d.dealer_name,
         au.role_code,
         (au.dealer_id = public.current_dealer_id()) AS is_active
  FROM public."AppUsers" au
  JOIN public."Dealers" d ON d.id = au.dealer_id AND d.deleted IS NOT TRUE
  WHERE au.auth_user_id = auth.uid()
    AND au.user_type = 'dealer'
    AND au.deleted = false
    AND au.status IN ('active', 'invited')
  ORDER BY au.created_at;
$function$;

COMMENT ON FUNCTION public.get_my_dealer_memberships() IS
  'Dealer memberships of the logged-in portal user (one row per dealer), with the currently active one flagged. Used by the header dealer switcher.';
