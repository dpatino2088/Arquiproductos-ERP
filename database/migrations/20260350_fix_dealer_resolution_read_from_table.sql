-- ============================================================================
-- Migration 20260350: Fix dealer resolution — read from TABLE, not session
-- ============================================================================
-- Problem: current_dealer_id() reads from session variable (app.dealer_id)
-- set by init_session_context(). With PostgREST + PgBouncer each HTTP request
-- is a separate transaction, so the variable is EMPTY in data SELECT queries.
-- RLS sees NULL and allows all rows (org) or blocks everything (portal).
--
-- Solution: Redefine current_dealer_id() to read directly from AppUsers +
-- AppUserPreferences on every call. No dependency on init_session_context().
-- ============================================================================

-- --------------------------------------------------------------------------
-- 1) current_dealer_id() (0 args) — read from TABLE
-- --------------------------------------------------------------------------
-- Org users  -> AppUserPreferences.active_dealer_id (acting-as dealer)
-- Dealer users -> AppUsers.dealer_id (fixed)
-- Prefers org row (ORDER BY user_type='org' first) so that an auth user who
-- exists in both org and dealer contexts resolves as org.
-- --------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.current_dealer_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT
    CASE
      WHEN au.user_type = 'dealer' THEN au.dealer_id
      ELSE pref.active_dealer_id
    END
  FROM public."AppUsers" au
  LEFT JOIN public."AppUserPreferences" pref ON pref.user_id = au.id
  WHERE au.auth_user_id = auth.uid()
    AND au.deleted = false
  ORDER BY CASE WHEN au.user_type = 'org' THEN 0 ELSE 1 END
  LIMIT 1;
$$;

COMMENT ON FUNCTION public.current_dealer_id() IS
'Returns effective dealer_id for the current user by reading from AppUsers + AppUserPreferences.
Org users: AppUserPreferences.active_dealer_id (NULL = no dealer filter).
Dealer users: AppUsers.dealer_id (fixed).
Does NOT depend on init_session_context() — safe across PostgREST transactions.';


-- --------------------------------------------------------------------------
-- 2) current_dealer_id(p_org_id uuid) — delegate to 0-arg version
-- --------------------------------------------------------------------------
-- Kept for backward compatibility with RLS policies and legacy code.

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
'Delegates to current_dealer_id() (table-based). Backward compatible overload.';


-- --------------------------------------------------------------------------
-- 3) get_current_dealer_id() — simplified, no init needed
-- --------------------------------------------------------------------------
-- Frontend calls this RPC to get the active dealer. Previously it called
-- init_session_context() first, but that is no longer needed.

CREATE OR REPLACE FUNCTION public.get_current_dealer_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT public.current_dealer_id();
$$;

COMMENT ON FUNCTION public.get_current_dealer_id() IS
'Returns current_dealer_id() directly. No init_session_context() needed.';

REVOKE ALL ON FUNCTION public.get_current_dealer_id() FROM public;
GRANT EXECUTE ON FUNCTION public.get_current_dealer_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_dealer_id() TO service_role;


-- --------------------------------------------------------------------------
-- 4) app_effective_dealer_id() — already delegates, no change needed
-- --------------------------------------------------------------------------
-- Confirming it delegates to current_dealer_id() (now table-based).
-- Recreate to ensure the latest definition is in place.

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
'Delegates to current_dealer_id() (table-based). Used in RLS policies for acting-as dealer scope.';


-- --------------------------------------------------------------------------
-- 5) session_is_org_user / session_is_dealer_user — table-based versions
-- --------------------------------------------------------------------------
-- These were reading from session variables. Redefine to read from AppUsers
-- so they work in any transaction without init_session_context().

CREATE OR REPLACE FUNCTION public.session_is_org_user(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public."AppUsers" au
    WHERE au.auth_user_id = auth.uid()
      AND au.user_type = 'org'
      AND au.organization_id = p_org_id
      AND au.deleted = false
  );
$$;

COMMENT ON FUNCTION public.session_is_org_user(uuid) IS
'True if current user is an org user for the given organization. Table-based (no session dependency).';

CREATE OR REPLACE FUNCTION public.session_is_dealer_user(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public."AppUsers" au
    WHERE au.auth_user_id = auth.uid()
      AND au.user_type = 'dealer'
      AND au.organization_id = p_org_id
      AND au.deleted = false
  );
$$;

COMMENT ON FUNCTION public.session_is_dealer_user(uuid) IS
'True if current user is a dealer user for the given organization. Table-based (no session dependency).';

CREATE OR REPLACE FUNCTION public.session_is_admin(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public."AppUsers" au
    WHERE au.auth_user_id = auth.uid()
      AND au.user_type = 'org'
      AND au.organization_id = p_org_id
      AND au.role_code IN ('owner', 'admin', 'superadmin')
      AND au.deleted = false
  );
$$;

COMMENT ON FUNCTION public.session_is_admin(uuid) IS
'True if current user is org admin/owner/superadmin for given org. Table-based (no session dependency).';

CREATE OR REPLACE FUNCTION public.session_is_dealer_portal(p_dealer_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public."AppUsers" au
    WHERE au.auth_user_id = auth.uid()
      AND au.user_type = 'dealer'
      AND au.dealer_id = p_dealer_id
      AND au.deleted = false
  );
$$;

COMMENT ON FUNCTION public.session_is_dealer_portal(uuid) IS
'True if current user is dealer portal for given dealer_id. Table-based (no session dependency).';


-- --------------------------------------------------------------------------
-- 6) current_user_role_code() — table-based role_code lookup
-- --------------------------------------------------------------------------
-- The Proposals UPDATE policy references current_setting('app.role_code')
-- directly. Replace with a table-based function.

CREATE OR REPLACE FUNCTION public.current_user_role_code()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT au.role_code
  FROM public."AppUsers" au
  WHERE au.auth_user_id = auth.uid()
    AND au.deleted = false
  ORDER BY CASE WHEN au.user_type = 'org' THEN 0 ELSE 1 END
  LIMIT 1;
$$;

COMMENT ON FUNCTION public.current_user_role_code() IS
'Returns role_code from AppUsers for the current auth user. Table-based (no session dependency).';


-- --------------------------------------------------------------------------
-- 7) Fix Proposals UPDATE policy — replace current_setting('app.role_code')
-- --------------------------------------------------------------------------
-- The current policy uses current_setting('app.role_code', true) which is
-- empty without init_session_context(). Replace with current_user_role_code().

DROP POLICY IF EXISTS "proposals_update" ON public."Proposals";
CREATE POLICY "proposals_update" ON public."Proposals"
  FOR UPDATE TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      (
        session_is_org_user(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
      OR
      (
        dealer_id IS NOT NULL
        AND session_is_dealer_portal(dealer_id)
        AND (
          public.current_user_role_code() = 'dealer_manager'
          OR created_by_user_id = auth.uid()
        )
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        session_is_org_user(organization_id)
        AND (current_dealer_id() IS NULL OR dealer_id = current_dealer_id())
      )
      OR
      (
        dealer_id IS NOT NULL
        AND session_is_dealer_portal(dealer_id)
        AND (
          public.current_user_role_code() = 'dealer_manager'
          OR created_by_user_id = auth.uid()
        )
      )
    )
  );


-- --------------------------------------------------------------------------
-- 8) init_session_context() — kept as-is for backward compatibility
-- --------------------------------------------------------------------------
-- Not removed. Still callable. Just no longer critical for RLS.
-- No changes needed.


-- --------------------------------------------------------------------------
-- 7) Verification queries (run manually after applying)
-- --------------------------------------------------------------------------
-- SELECT public.current_dealer_id();
-- Should return the correct dealer without calling init_session_context() first.
--
-- Check that no policies still use the old is_org_user_member (non-strict):
-- SELECT n.nspname, c.relname, p.polname
-- FROM pg_policy p
-- JOIN pg_class c ON c.oid = p.polrelid
-- JOIN pg_namespace n ON n.oid = c.relnamespace
-- WHERE n.nspname = 'public'
--   AND pg_get_expr(p.polqual, p.polrelid) ILIKE '%is_org_user_member(%'
--   AND pg_get_expr(p.polqual, p.polrelid) NOT ILIKE '%is_org_user_member_strict(%';
