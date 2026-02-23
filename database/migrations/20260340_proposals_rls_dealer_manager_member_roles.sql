-- =============================================================================
-- Migration: Proposals RLS - Dealer Manager vs Dealer Member
-- =============================================================================
-- Dealer Manager (member_manager): ver y editar todo (Proposals + ProposalLines).
-- Dealer Member (member): ver todo, solo editar sus propios (created_by_user_id = auth.uid()).
--
-- Usa is_dealer_portal_user (member + member_manager) para SELECT.
-- Usa is_dealer_portal_user_with_write O (is_dealer_portal_user AND created_by = self) para UPDATE/INSERT/DELETE.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Proposals SELECT: org users + portal (member + member_manager) para su dealer
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "proposals_select" ON public."Proposals";
CREATE POLICY "proposals_select" ON public."Proposals"
  FOR SELECT TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      -- Org users (incl. acting-as)
      (
        public.is_org_user_member(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
      OR
      -- Portal: member + member_manager ven todos los Proposals de su dealer
      (
        public.current_dealer_id(organization_id) IS NOT NULL
        AND dealer_id = public.current_dealer_id(organization_id)
      )
      OR
      -- Fallback portal vía DealerUsers (por si current_dealer_id falla)
      (
        dealer_id IS NOT NULL
        AND public.is_dealer_portal_user(dealer_id)
      )
    )
  );


-- -----------------------------------------------------------------------------
-- Proposals UPDATE: org users, member_manager todo, member solo los suyos
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "proposals_update" ON public."Proposals";
CREATE POLICY "proposals_update" ON public."Proposals"
  FOR UPDATE TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      -- Org users
      (
        public.is_org_user_member(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
      OR
      -- Portal member_manager: puede editar todo
      (
        dealer_id IS NOT NULL
        AND public.is_dealer_portal_user_with_write(dealer_id)
      )
      OR
      -- Portal member: solo los creados por él
      (
        dealer_id IS NOT NULL
        AND public.is_dealer_portal_user(dealer_id)
        AND created_by_user_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (public.current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id)))
      OR
      (
        public.is_org_user_member(organization_id)
        AND (
          public.app_effective_dealer_id() IS NULL
          OR dealer_id = public.app_effective_dealer_id()
        )
      )
    )
  );


-- -----------------------------------------------------------------------------
-- Proposals INSERT (sin cambios de rol; member_manager y org pueden insertar)
-- -----------------------------------------------------------------------------
-- Mantener lógica actual para INSERT


-- -----------------------------------------------------------------------------
-- ProposalLines: quitar políticas duplicadas (proposal_lines_*)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "proposal_lines_select" ON public."ProposalLines";
DROP POLICY IF EXISTS "proposal_lines_write" ON public."ProposalLines";

-- -----------------------------------------------------------------------------
-- ProposalLines SELECT: quien puede ver el Proposal puede ver las líneas
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "proposallines_select" ON public."ProposalLines";
CREATE POLICY "proposallines_select" ON public."ProposalLines"
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (p.deleted IS NOT TRUE)
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR
          (p.dealer_id IS NOT NULL AND public.is_dealer_portal_user(p.dealer_id))
        )
    )
  );


-- -----------------------------------------------------------------------------
-- ProposalLines INSERT: member_manager o (member y creador del Proposal)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "proposallines_insert" ON public."ProposalLines";
CREATE POLICY "proposallines_insert" ON public."ProposalLines"
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND p.deleted = false
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR
          (
            p.dealer_id IS NOT NULL
            AND (
              public.is_dealer_portal_user_with_write(p.dealer_id)
              OR (public.is_dealer_portal_user(p.dealer_id) AND p.created_by_user_id = auth.uid())
            )
          )
        )
    )
  );


-- -----------------------------------------------------------------------------
-- ProposalLines UPDATE
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "proposallines_update" ON public."ProposalLines";
CREATE POLICY "proposallines_update" ON public."ProposalLines"
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR
          (
            p.dealer_id IS NOT NULL
            AND (
              public.is_dealer_portal_user_with_write(p.dealer_id)
              OR (public.is_dealer_portal_user(p.dealer_id) AND p.created_by_user_id = auth.uid())
            )
          )
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR
          (
            p.dealer_id IS NOT NULL
            AND (
              public.is_dealer_portal_user_with_write(p.dealer_id)
              OR (public.is_dealer_portal_user(p.dealer_id) AND p.created_by_user_id = auth.uid())
            )
          )
        )
    )
  );


-- -----------------------------------------------------------------------------
-- ProposalLines DELETE
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "proposallines_delete" ON public."ProposalLines";
CREATE POLICY "proposallines_delete" ON public."ProposalLines"
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR
          (
            p.dealer_id IS NOT NULL
            AND (
              public.is_dealer_portal_user_with_write(p.dealer_id)
              OR (public.is_dealer_portal_user(p.dealer_id) AND p.created_by_user_id = auth.uid())
            )
          )
        )
    )
  );


-- -----------------------------------------------------------------------------
-- ProposalLineAddOns: misma lógica (member_manager todo, member solo suyos)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "proposal_line_addons_select" ON public."ProposalLineAddOns";
CREATE POLICY "proposal_line_addons_select" ON public."ProposalLineAddOns"
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR (p.dealer_id IS NOT NULL AND public.is_dealer_portal_user(p.dealer_id))
        )
    )
  );

DROP POLICY IF EXISTS "proposal_line_addons_insert" ON public."ProposalLineAddOns";
CREATE POLICY "proposal_line_addons_insert" ON public."ProposalLineAddOns"
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND p.deleted = false
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR
          (
            p.dealer_id IS NOT NULL
            AND (
              public.is_dealer_portal_user_with_write(p.dealer_id)
              OR (public.is_dealer_portal_user(p.dealer_id) AND p.created_by_user_id = auth.uid())
            )
          )
        )
    )
  );

DROP POLICY IF EXISTS "proposal_line_addons_update" ON public."ProposalLineAddOns";
CREATE POLICY "proposal_line_addons_update" ON public."ProposalLineAddOns"
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR
          (
            p.dealer_id IS NOT NULL
            AND (
              public.is_dealer_portal_user_with_write(p.dealer_id)
              OR (public.is_dealer_portal_user(p.dealer_id) AND p.created_by_user_id = auth.uid())
            )
          )
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR
          (
            p.dealer_id IS NOT NULL
            AND (
              public.is_dealer_portal_user_with_write(p.dealer_id)
              OR (public.is_dealer_portal_user(p.dealer_id) AND p.created_by_user_id = auth.uid())
            )
          )
        )
    )
  );

DROP POLICY IF EXISTS "proposal_line_addons_delete" ON public."ProposalLineAddOns";
CREATE POLICY "proposal_line_addons_delete" ON public."ProposalLineAddOns"
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR
          (
            p.dealer_id IS NOT NULL
            AND (
              public.is_dealer_portal_user_with_write(p.dealer_id)
              OR (public.is_dealer_portal_user(p.dealer_id) AND p.created_by_user_id = auth.uid())
            )
          )
        )
    )
  );
