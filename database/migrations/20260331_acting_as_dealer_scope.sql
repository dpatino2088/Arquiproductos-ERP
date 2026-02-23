-- =============================================================================
-- Migration: Acting As Dealer — Enterprise Scope (v2 — hardened)
-- =============================================================================
-- Supabase uses PgBouncer in transaction mode, so set_config() per-transaction
-- does NOT persist across separate PostgREST HTTP requests.
-- Instead we use a persistent table (user_dealer_scope) that RLS can read on
-- every request.  This is connection-pool safe and deterministic.
-- =============================================================================

-- 1) Table: user_dealer_scope ------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_dealer_scope (
  user_id             uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  organization_id     uuid NOT NULL,
  effective_dealer_id uuid,
  updated_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_dealer_scope ENABLE ROW LEVEL SECURITY;

-- Indices for fast lookups
CREATE INDEX IF NOT EXISTS idx_uds_org
  ON public.user_dealer_scope (organization_id);
CREATE INDEX IF NOT EXISTS idx_uds_org_dealer
  ON public.user_dealer_scope (organization_id, effective_dealer_id);

-- RLS: users can only read/update their own row
DROP POLICY IF EXISTS "uds_owner" ON public.user_dealer_scope;
CREATE POLICY "uds_owner" ON public.user_dealer_scope
  FOR ALL
  USING  (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Tighten grants: all writes go through RPCs (SECURITY DEFINER).
-- Direct SELECT allowed so RLS helpers can read the scope.
REVOKE ALL ON public.user_dealer_scope FROM authenticated;
GRANT SELECT ON public.user_dealer_scope TO authenticated;

-- 2) Helper: app_effective_dealer_id() ---------------------------------------
--    Returns the org-user's chosen dealer scope (NULL = org-wide / no filter).
--    Portal/dealer users should continue using current_dealer_id(org_id).
CREATE OR REPLACE FUNCTION public.app_effective_dealer_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT effective_dealer_id
  FROM public.user_dealer_scope
  WHERE user_id = auth.uid()
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.app_effective_dealer_id() TO authenticated;

-- 3) RPC: set_effective_dealer_id(p_dealer_id uuid) --------------------------
--    Org users call this to switch "acting as dealer".
--    Validates the dealer belongs to the caller's organization.
CREATE OR REPLACE FUNCTION public.set_effective_dealer_id(p_dealer_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id uuid;
  v_dealer_org uuid;
BEGIN
  -- Resolve caller's organization
  SELECT organization_id INTO v_org_id
  FROM public."OrganizationUsers"
  WHERE user_id = auth.uid()
    AND (deleted IS NULL OR deleted = false)
  LIMIT 1;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'User is not a member of any organization';
  END IF;

  -- Validate dealer belongs to same org
  IF p_dealer_id IS NOT NULL THEN
    SELECT organization_id INTO v_dealer_org
    FROM public."Dealers"
    WHERE id = p_dealer_id AND (deleted IS NULL OR deleted = false);

    IF v_dealer_org IS NULL OR v_dealer_org != v_org_id THEN
      RAISE EXCEPTION 'Dealer % not found in organization %', p_dealer_id, v_org_id;
    END IF;
  END IF;

  -- Upsert scope
  INSERT INTO public.user_dealer_scope (user_id, organization_id, effective_dealer_id, updated_at)
  VALUES (auth.uid(), v_org_id, p_dealer_id, now())
  ON CONFLICT (user_id) DO UPDATE
    SET effective_dealer_id = EXCLUDED.effective_dealer_id,
        organization_id    = EXCLUDED.organization_id,
        updated_at         = now();

  RETURN p_dealer_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_effective_dealer_id(uuid) TO authenticated;

-- 4) RPC: clear_effective_dealer_id() ----------------------------------------
--    Clears scope → org-wide view.
--    Uses UPSERT so it works even if no row exists yet.
CREATE OR REPLACE FUNCTION public.clear_effective_dealer_id()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id uuid;
BEGIN
  SELECT organization_id INTO v_org_id
  FROM public."OrganizationUsers"
  WHERE user_id = auth.uid()
    AND (deleted IS NULL OR deleted = false)
  LIMIT 1;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'User is not a member of any organization';
  END IF;

  INSERT INTO public.user_dealer_scope (user_id, organization_id, effective_dealer_id, updated_at)
  VALUES (auth.uid(), v_org_id, NULL, now())
  ON CONFLICT (user_id) DO UPDATE
    SET effective_dealer_id = NULL,
        organization_id    = EXCLUDED.organization_id,
        updated_at         = now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.clear_effective_dealer_id() TO authenticated;

-- =============================================================================
-- 5) Example RLS policies (reference — apply per table as needed)
-- =============================================================================
-- These show the pattern for dealer-scoped tables.
-- Org users with no scope see all org data; with scope see only that dealer.
-- Portal users continue using current_dealer_id().
--
-- IMPORTANT: Review existing policies before applying.  Use DROP POLICY IF
-- EXISTS + CREATE POLICY to avoid conflicts.
-- =============================================================================

-- -- Example: Quotes
-- DROP POLICY IF EXISTS "quotes_acting_as_select" ON public."Quotes";
-- CREATE POLICY "quotes_acting_as_select" ON public."Quotes"
--   FOR SELECT USING (
--     (deleted IS NOT TRUE) AND (
--       (
--         is_org_user_member(organization_id) AND (
--           app_effective_dealer_id() IS NULL
--           OR dealer_id = app_effective_dealer_id()
--         )
--       )
--       OR
--       (dealer_id = current_dealer_id(organization_id))
--     )
--   );

-- -- Example: DirectoryCustomers
-- DROP POLICY IF EXISTS "dircustomers_acting_as_select" ON public."DirectoryCustomers";
-- CREATE POLICY "dircustomers_acting_as_select" ON public."DirectoryCustomers"
--   FOR SELECT USING (
--     (deleted IS NOT TRUE) AND (
--       (
--         is_org_user_member(organization_id) AND (
--           app_effective_dealer_id() IS NULL
--           OR dealer_id = app_effective_dealer_id()
--         )
--       )
--       OR
--       (dealer_id = current_dealer_id(organization_id))
--     )
--   );

-- -- Same pattern applies to: Proposals, DirectoryContacts, QuoteLines, SalesOrders
