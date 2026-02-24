-- =============================================================================
-- Migration: Quotes RLS - Dealer Manager portal fallback
-- =============================================================================
-- Problem: Dealer Manager (portal user) gets "Failed to load quote" because
-- current_dealer_id(organization_id) may return NULL in PostgREST requests
-- (session vars don't persist). Proposals has is_dealer_portal_user(dealer_id)
-- fallback; Quotes does not.
--
-- Solution: Add is_dealer_portal_user(dealer_id) OR session_is_dealer_portal(dealer_id)
-- fallback (same pattern as Proposals in 20260342). Portal users see quotes
-- where quote.dealer_id = their dealer.
--
-- Compatible with 20260342 (uses is_org_user_member_strict, app_effective_dealer_id).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Quotes SELECT: add portal fallback (is_dealer_portal_user or session_is_dealer_portal)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "quotes_select" ON public."Quotes";
CREATE POLICY "quotes_select" ON public."Quotes"
  FOR SELECT TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      -- Org users (is_org_user_member_strict path)
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
      OR
      -- Dealer users (current_dealer_id path)
      (
        public.current_dealer_id(organization_id) IS NOT NULL
        AND dealer_id = public.current_dealer_id(organization_id)
      )
      OR
      -- Portal fallback: Dealer Manager/Member see quotes for their dealer
      -- (same as Proposals in 20260342; works without session init)
      (
        dealer_id IS NOT NULL
        AND public.is_dealer_portal_user(dealer_id)
      )
    )
  );
