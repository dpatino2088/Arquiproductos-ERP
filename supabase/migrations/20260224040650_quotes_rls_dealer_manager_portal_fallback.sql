-- =============================================================================
-- Migration: Quotes RLS - Dealer Manager portal fallback
-- =============================================================================
-- Problem: Dealer Manager gets "Failed to load quote" - current_dealer_id may
-- return NULL in PostgREST. Proposals has is_dealer_portal_user fallback;
-- Quotes does not.
--
-- Solution: Add is_dealer_portal_user(dealer_id) fallback (same as Proposals).
-- =============================================================================

DROP POLICY IF EXISTS "quotes_select" ON public."Quotes";
CREATE POLICY "quotes_select" ON public."Quotes"
  FOR SELECT TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      (
        public.is_org_user_member_strict(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
      OR
      (
        public.current_dealer_id(organization_id) IS NOT NULL
        AND dealer_id = public.current_dealer_id(organization_id)
      )
      OR
      (
        dealer_id IS NOT NULL
        AND public.is_dealer_portal_user(dealer_id)
      )
    )
  );;
