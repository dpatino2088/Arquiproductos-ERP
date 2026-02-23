-- ============================================================================
-- Migration 20260351: Fix Acting-As — data sync + RLS cleanup
-- ============================================================================
-- Applied to Supabase on 2026-02-23.
-- 1) Sync missing AppUsers from OrganizationUsers and DealerUsers
-- 2) Drop duplicate/legacy RLS policies on BOMTemplates and ConfiguredProducts
-- 3) Fix ProposalLines, ProposalLineAddOns, DealerTiers: replace is_org_member
--    (non-strict, includes DealerUsers) with is_org_user_member_strict + is_portal_user_in_org
-- ============================================================================

-- --------------------------------------------------------------------------
-- 1) Sync missing AppUsers from OrganizationUsers
-- --------------------------------------------------------------------------
INSERT INTO public."AppUsers" (organization_id, user_type, dealer_id, auth_user_id, email, display_name, role_code, status)
SELECT ou.organization_id, 'org', NULL, ou.user_id, ou.user_email, ou.user_name,
       COALESCE(ou.role::text, 'member'), COALESCE(ou.status::text, 'active')
FROM public."OrganizationUsers" ou
WHERE ou.deleted = false AND ou.user_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public."AppUsers" au
    WHERE au.auth_user_id = ou.user_id AND au.user_type = 'org' AND au.deleted = false
  );

-- Sync missing AppUsers from DealerUsers
INSERT INTO public."AppUsers" (organization_id, user_type, dealer_id, auth_user_id, email, display_name, role_code, status)
SELECT du.organization_id, 'dealer', du.dealer_id, du.user_id, du.portal_user_email, du.portal_user_name,
       COALESCE(du.role::text, 'dealer_member'), COALESCE(du.status::text, 'active')
FROM public."DealerUsers" du
WHERE (du.deleted IS NOT TRUE) AND du.user_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public."AppUsers" au
    WHERE au.auth_user_id = du.user_id AND au.user_type = 'dealer'
      AND COALESCE(au.dealer_id, '00000000-0000-0000-0000-000000000000') = COALESCE(du.dealer_id, '00000000-0000-0000-0000-000000000000')
      AND au.deleted = false
  );

-- --------------------------------------------------------------------------
-- 2) Drop duplicate/legacy RLS policies
-- --------------------------------------------------------------------------
DROP POLICY IF EXISTS "bom_templates_select_own_org" ON public."BOMTemplates";
DROP POLICY IF EXISTS "Users can view ConfiguredProducts for their organization" ON public."ConfiguredProducts";

-- --------------------------------------------------------------------------
-- 3a) Fix ProposalLines — is_org_member -> is_org_user_member_strict
-- --------------------------------------------------------------------------
DROP POLICY IF EXISTS "proposallines_select" ON public."ProposalLines";
CREATE POLICY "proposallines_select" ON public."ProposalLines"
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = "ProposalLines".proposal_id
        AND p.deleted IS NOT TRUE
        AND p.organization_id IS NOT NULL
        AND (public.is_org_user_member_strict(p.organization_id)
             OR public.is_portal_user_in_org(p.organization_id))
    )
  );

DROP POLICY IF EXISTS "proposallines_insert" ON public."ProposalLines";
CREATE POLICY "proposallines_insert" ON public."ProposalLines"
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = "ProposalLines".proposal_id
        AND p.deleted = false
        AND p.organization_id IS NOT NULL
        AND (public.is_org_user_member_strict(p.organization_id)
             OR public.is_portal_user_in_org(p.organization_id))
    )
  );

DROP POLICY IF EXISTS "proposallines_update" ON public."ProposalLines";
CREATE POLICY "proposallines_update" ON public."ProposalLines"
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = "ProposalLines".proposal_id
        AND p.organization_id IS NOT NULL
        AND (public.is_org_user_member_strict(p.organization_id)
             OR public.is_portal_user_in_org(p.organization_id))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = "ProposalLines".proposal_id
        AND p.organization_id IS NOT NULL
        AND (public.is_org_user_member_strict(p.organization_id)
             OR public.is_portal_user_in_org(p.organization_id))
    )
  );

DROP POLICY IF EXISTS "proposallines_delete" ON public."ProposalLines";
CREATE POLICY "proposallines_delete" ON public."ProposalLines"
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = "ProposalLines".proposal_id
        AND p.organization_id IS NOT NULL
        AND (public.is_org_user_member_strict(p.organization_id)
             OR public.is_portal_user_in_org(p.organization_id))
    )
  );

-- --------------------------------------------------------------------------
-- 3b) Fix ProposalLineAddOns — same pattern
-- --------------------------------------------------------------------------
DROP POLICY IF EXISTS "proposal_line_addons_select" ON public."ProposalLineAddOns";
CREATE POLICY "proposal_line_addons_select" ON public."ProposalLineAddOns"
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = "ProposalLineAddOns".proposal_id
        AND p.organization_id IS NOT NULL
        AND (public.is_org_user_member_strict(p.organization_id)
             OR public.is_portal_user_in_org(p.organization_id))
    )
  );

DROP POLICY IF EXISTS "proposal_line_addons_insert" ON public."ProposalLineAddOns";
CREATE POLICY "proposal_line_addons_insert" ON public."ProposalLineAddOns"
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = "ProposalLineAddOns".proposal_id
        AND p.organization_id IS NOT NULL
        AND (public.is_org_user_member_strict(p.organization_id)
             OR public.is_portal_user_in_org(p.organization_id))
    )
  );

DROP POLICY IF EXISTS "proposal_line_addons_update" ON public."ProposalLineAddOns";
CREATE POLICY "proposal_line_addons_update" ON public."ProposalLineAddOns"
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = "ProposalLineAddOns".proposal_id
        AND p.organization_id IS NOT NULL
        AND (public.is_org_user_member_strict(p.organization_id)
             OR public.is_portal_user_in_org(p.organization_id))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = "ProposalLineAddOns".proposal_id
        AND p.organization_id IS NOT NULL
        AND (public.is_org_user_member_strict(p.organization_id)
             OR public.is_portal_user_in_org(p.organization_id))
    )
  );

DROP POLICY IF EXISTS "proposal_line_addons_delete" ON public."ProposalLineAddOns";
CREATE POLICY "proposal_line_addons_delete" ON public."ProposalLineAddOns"
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = "ProposalLineAddOns".proposal_id
        AND p.organization_id IS NOT NULL
        AND (public.is_org_user_member_strict(p.organization_id)
             OR public.is_portal_user_in_org(p.organization_id))
    )
  );

-- --------------------------------------------------------------------------
-- 3c) Fix DealerTiers — is_org_member -> strict
-- --------------------------------------------------------------------------
DROP POLICY IF EXISTS "dealertiers_select_own_org" ON public."DealerTiers";
CREATE POLICY "dealertiers_select_own_org" ON public."DealerTiers"
  FOR SELECT TO authenticated
  USING (
    public.is_org_user_member_strict(organization_id)
    OR public.is_portal_user_in_org(organization_id)
  );
