-- ============================================================
-- PASO 4: Acting-as con variable de sesión
-- ============================================================
-- init_session_context() llena app.* en la transacción actual.
-- current_dealer_id() y app_effective_dealer_id() leen solo variables.
-- session_is_* comparan parámetros con app.*.
-- set_acting_dealer además escribe app.dealer_id en la transacción.
-- Importante: con PostgREST cada request es otra transacción; el frontend
-- debe llamar init_session_context() en la misma transacción que los SELECT
-- (o antes del primer fetch por módulo). Ver PASO 7.
-- ============================================================

-- ---------- 4a: init_session_context() ----------
CREATE OR REPLACE FUNCTION public.init_session_context()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_row record;
  v_dealer_id uuid;
BEGIN
  SELECT au.user_type, au.organization_id, au.role_code, au.dealer_id, au.id
    INTO v_row
  FROM public."AppUsers" au
  WHERE au.auth_user_id = auth.uid()
    AND au.deleted = false
  ORDER BY CASE WHEN au.user_type = 'org' THEN 0 ELSE 1 END
  LIMIT 1;

  IF v_row IS NULL THEN
    -- No AppUser: clear session vars so RLS sees "no context"
    PERFORM set_config('app.user_type', '', true);
    PERFORM set_config('app.organization_id', '', true);
    PERFORM set_config('app.role_code', '', true);
    PERFORM set_config('app.dealer_id', '', true);
    RETURN;
  END IF;

  PERFORM set_config('app.user_type', COALESCE(v_row.user_type, ''), true);
  PERFORM set_config('app.organization_id', COALESCE(v_row.organization_id::text, ''), true);
  PERFORM set_config('app.role_code', COALESCE(v_row.role_code, ''), true);

  IF v_row.user_type = 'org' THEN
    SELECT pref.active_dealer_id INTO v_dealer_id
    FROM public."AppUserPreferences" pref
    WHERE pref.user_id = v_row.id;
  ELSE
    v_dealer_id := v_row.dealer_id;
  END IF;

  PERFORM set_config('app.dealer_id', COALESCE(v_dealer_id::text, ''), true);
END;
$$;

COMMENT ON FUNCTION public.init_session_context() IS
  'Sets app.user_type, app.organization_id, app.role_code, app.dealer_id from AppUsers (and AppUserPreferences for org). Must run in same transaction as RLS reads.';

REVOKE ALL ON FUNCTION public.init_session_context() FROM public;
GRANT EXECUTE ON FUNCTION public.init_session_context() TO authenticated;
GRANT EXECUTE ON FUNCTION public.init_session_context() TO service_role;

-- ---------- 4b: current_dealer_id() (0 args) — leer solo variable ----------
CREATE OR REPLACE FUNCTION public.current_dealer_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NULLIF(trim(current_setting('app.dealer_id', true)), '')::uuid;
$$;

COMMENT ON FUNCTION public.current_dealer_id() IS
  'Reads app.dealer_id from session. Call init_session_context() in same transaction first.';

-- ---------- 4c: app_effective_dealer_id() ----------
CREATE OR REPLACE FUNCTION public.app_effective_dealer_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.current_dealer_id();
$$;

COMMENT ON FUNCTION public.app_effective_dealer_id() IS
  'Delegates to current_dealer_id() — session variable for acting-as dealer.';

-- ---------- 4d: Funciones de sesión (solo current_setting) ----------
CREATE OR REPLACE FUNCTION public.session_is_org_user(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT current_setting('app.user_type', true) = 'org'
    AND NULLIF(trim(current_setting('app.organization_id', true)), '')::uuid = p_org_id;
$$;

CREATE OR REPLACE FUNCTION public.session_is_dealer_user(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT current_setting('app.user_type', true) = 'dealer'
    AND NULLIF(trim(current_setting('app.organization_id', true)), '')::uuid = p_org_id;
$$;

CREATE OR REPLACE FUNCTION public.session_is_admin(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.session_is_org_user(p_org_id)
    AND current_setting('app.role_code', true) IN ('owner', 'admin', 'superadmin');
$$;

CREATE OR REPLACE FUNCTION public.session_is_dealer_portal(p_dealer_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT current_setting('app.user_type', true) = 'dealer'
    AND NULLIF(trim(current_setting('app.dealer_id', true)), '')::uuid = p_dealer_id;
$$;

COMMENT ON FUNCTION public.session_is_org_user(uuid) IS 'True if session context is org user for given org.';
COMMENT ON FUNCTION public.session_is_dealer_user(uuid) IS 'True if session context is dealer (portal) user for given org.';
COMMENT ON FUNCTION public.session_is_admin(uuid) IS 'True if session is org admin/owner/superadmin for given org.';
COMMENT ON FUNCTION public.session_is_dealer_portal(uuid) IS 'True if session is dealer portal for given dealer_id.';

REVOKE ALL ON FUNCTION public.session_is_org_user(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.session_is_org_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.session_is_org_user(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.session_is_dealer_user(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.session_is_dealer_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.session_is_dealer_user(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.session_is_admin(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.session_is_admin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.session_is_admin(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.session_is_dealer_portal(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.session_is_dealer_portal(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.session_is_dealer_portal(uuid) TO service_role;

-- ---------- 4e: set_acting_dealer — mantener lógica y actualizar app.dealer_id en transacción ----------
CREATE OR REPLACE FUNCTION public.set_acting_dealer(p_dealer_id uuid)
RETURNS table(active_dealer_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_app_user_id uuid;
  v_org_id uuid;
  v_user_type text;
  v_ok boolean;
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

  IF v_user_type <> 'org' THEN
    RAISE EXCEPTION 'Only org users can use acting-as';
  END IF;

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

  -- So that the rest of the transaction sees the new acting dealer
  PERFORM set_config('app.dealer_id', COALESCE(p_dealer_id::text, ''), true);

  RETURN QUERY SELECT p_dealer_id;
END;
$$;

COMMENT ON FUNCTION public.set_acting_dealer(uuid) IS
  'Sets acting-as dealer for org user and app.dealer_id in session. Call init_session_context() in next request so RLS sees it.';

REVOKE ALL ON FUNCTION public.set_acting_dealer(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.set_acting_dealer(uuid) TO authenticated;

-- Overload current_dealer_id(p_org_id) sigue delegando a current_dealer_id()
CREATE OR REPLACE FUNCTION public.current_dealer_id(p_org_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.current_dealer_id();
$$;

COMMENT ON FUNCTION public.current_dealer_id(uuid) IS
  'Delegates to current_dealer_id(). Session must be initialized with init_session_context().';

-- RPC para el frontend: init + current_dealer_id en una transacción (evita NULL por no haber init en la misma request)
CREATE OR REPLACE FUNCTION public.get_current_dealer_id()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  PERFORM public.init_session_context();
  RETURN public.current_dealer_id();
END;
$$;

COMMENT ON FUNCTION public.get_current_dealer_id() IS
  'Calls init_session_context() then current_dealer_id() in one transaction. Use from frontend for active dealer.';

REVOKE ALL ON FUNCTION public.get_current_dealer_id() FROM public;
GRANT EXECUTE ON FUNCTION public.get_current_dealer_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_dealer_id() TO service_role;
