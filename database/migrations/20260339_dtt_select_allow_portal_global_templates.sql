-- =============================================================================
-- Migration: Allow DealerUsers to SELECT global templates (dealer_id NULL)
-- =============================================================================
-- QuoteTermsDisplay fallback fetches global templates (dealer_id IS NULL) when
-- no dealer-specific default exists. Previous dtt_select only allowed portal
-- users to see dealer-specific templates. Add branch for global templates.
-- =============================================================================

DROP POLICY IF EXISTS "dtt_select" ON public."DocumentTermsTemplates";
CREATE POLICY "dtt_select" ON public."DocumentTermsTemplates"
  FOR SELECT TO authenticated
  USING (
    (
      organization_id IN (
        SELECT ou.organization_id
        FROM public."OrganizationUsers" ou
        WHERE ou.user_id = auth.uid() AND (ou.deleted IS NULL OR ou.deleted = false)
      )
      AND (
        dealer_id IS NULL
        OR dealer_id IN (
          SELECT au.dealer_id
          FROM public."AppUsers" au
          WHERE au.auth_user_id = auth.uid() AND au.dealer_id IS NOT NULL
          LIMIT 1
        )
        OR EXISTS (
          SELECT 1 FROM public."OrganizationUsers" ou2
          WHERE ou2.user_id = auth.uid() AND (ou2.deleted IS NULL OR ou2.deleted = false)
        )
      )
    )
    OR
    -- DealerUsers - their dealer's templates
    (
      dealer_id IS NOT NULL
      AND public.is_dealer_portal_user(dealer_id)
    )
    OR
    -- DealerUsers - global templates for their org (Quote fallback)
    (
      dealer_id IS NULL
      AND organization_id IN (
        SELECT du.organization_id
        FROM public."DealerUsers" du
        WHERE du.user_id = auth.uid()
          AND (du.deleted IS NULL OR du.deleted = false)
          AND (du.status IS NULL OR du.status IN ('active', 'invited'))
      )
    )
  );
