-- =============================================================================
-- Portal multi-dealer: scope ALL portal access to the ACTIVE dealer
-- =============================================================================
-- Problem: with multi-dealer memberships (20260902020000), the RLS helpers
-- is_dealer_portal_user(dealer_id) / session_is_dealer_portal(dealer_id) return
-- true for ANY dealer the user belongs to, regardless of which one is active.
-- SELECT policies (Quotes, Proposals, ServiceClaims, DocumentTermsTemplates)
-- therefore leaked the OTHER dealer's records into the current session, while
-- UPDATE policies only allow dealer_id = current_dealer_id(). Net effect: a user
-- acting as IHO could open an Arquiluz quote but saving it matched 0 rows and
-- PostgREST raised "Cannot coerce the result to a single JSON object" (PGRST116).
--
-- Fix: both helpers now require the dealer to be the ACTIVE one
-- (current_dealer_id()) for users with AppUsers dealer memberships. Data from the
-- other memberships is reachable only after switching dealer in the UI.
-- Legacy DealerUsers-only accounts (no AppUsers rows -> current_dealer_id() IS
-- NULL) keep the old membership-only behavior so they do not lose access.
-- =============================================================================

-- 1) is_dealer_portal_user(p_dealer_id): membership AND active dealer
CREATE OR REPLACE FUNCTION public.is_dealer_portal_user(p_dealer_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_active uuid := public.current_dealer_id();
BEGIN
  -- Users with AppUsers dealer memberships: only the ACTIVE dealer grants access.
  IF v_active IS NOT NULL THEN
    IF p_dealer_id IS DISTINCT FROM v_active THEN
      RETURN false;
    END IF;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public."AppUsers" au
    WHERE au.auth_user_id = auth.uid()
      AND au.user_type = 'dealer'
      AND au.dealer_id = p_dealer_id
      AND COALESCE(au.deleted, false) = false
      AND au.status IN ('active', 'invited')
  )
  OR EXISTS (
    SELECT 1
    FROM public."DealerUsers" dpu
    WHERE dpu.dealer_id = p_dealer_id
      AND (
        dpu.user_id = auth.uid()
        OR lower(dpu.portal_user_email) = lower(auth.jwt() ->> 'email')
      )
      AND COALESCE(dpu.deleted, false) = false
      AND dpu.status IN ('active', 'invited')
  );
END;
$function$;

COMMENT ON FUNCTION public.is_dealer_portal_user(uuid) IS
  'True when the logged-in portal user belongs to the dealer AND that dealer is the currently ACTIVE one (current_dealer_id). Membership in another dealer does not grant access until the user switches. Legacy DealerUsers-only accounts keep membership-only behavior.';

-- 2) session_is_dealer_portal(p_dealer_id): membership AND active dealer
CREATE OR REPLACE FUNCTION public.session_is_dealer_portal(p_dealer_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public."AppUsers" au
    WHERE au.auth_user_id = auth.uid()
      AND au.user_type = 'dealer'
      AND au.dealer_id = p_dealer_id
      AND au.deleted = false
  )
  AND p_dealer_id IS NOT DISTINCT FROM public.current_dealer_id();
$function$;

COMMENT ON FUNCTION public.session_is_dealer_portal(uuid) IS
  'True when the logged-in portal user belongs to the dealer AND that dealer is the currently ACTIVE one (current_dealer_id). Used by Proposals RLS and list-totals visibility guards.';
