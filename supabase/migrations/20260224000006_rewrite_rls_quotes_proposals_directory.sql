-- ============================================================
-- PASO 5: Reescribir RLS (Quotes, Proposals, DirectoryContacts, DirectoryCustomers)
-- ============================================================
-- Reemplazar políticas que usan is_org_user_member_strict, app_effective_dealer_id(),
-- current_dealer_id(organization_id), is_dealer_portal_user, is_dealer_portal_user_with_write
-- por patrón basado en session_is_org_user, session_is_dealer_user, session_is_dealer_portal
-- y current_dealer_id() (sin args). Requiere init_session_context() en la misma transacción.
-- No se eliminan las funciones legacy; se deprecan en PASO 8.
-- ============================================================

-- ---------- Quotes ----------
DROP POLICY IF EXISTS "quotes_select" ON public."Quotes";
CREATE POLICY "quotes_select" ON public."Quotes"
  FOR SELECT TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );

DROP POLICY IF EXISTS "quotes_insert" ON public."Quotes";
CREATE POLICY "quotes_insert" ON public."Quotes"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );

DROP POLICY IF EXISTS "quotes_update" ON public."Quotes";
CREATE POLICY "quotes_update" ON public."Quotes"
  FOR UPDATE TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );


-- ---------- Proposals ----------
DROP POLICY IF EXISTS "proposals_select" ON public."Proposals";
CREATE POLICY "proposals_select" ON public."Proposals"
  FOR SELECT TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
      OR
      (dealer_id IS NOT NULL AND public.session_is_dealer_portal(dealer_id))
    )
  );

DROP POLICY IF EXISTS "proposals_update" ON public."Proposals";
CREATE POLICY "proposals_update" ON public."Proposals"
  FOR UPDATE TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        dealer_id IS NOT NULL
        AND public.session_is_dealer_portal(dealer_id)
        AND (
          current_setting('app.role_code', true) = 'dealer_manager'
          OR created_by_user_id = auth.uid()
        )
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        dealer_id IS NOT NULL
        AND public.session_is_dealer_portal(dealer_id)
        AND (
          current_setting('app.role_code', true) = 'dealer_manager'
          OR created_by_user_id = auth.uid()
        )
      )
    )
  );

DROP POLICY IF EXISTS "proposals_insert" ON public."Proposals";
CREATE POLICY "proposals_insert" ON public."Proposals"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );


-- ---------- DirectoryContacts ----------
DROP POLICY IF EXISTS "dircontacts_select" ON public."DirectoryContacts";
CREATE POLICY "dircontacts_select" ON public."DirectoryContacts"
  FOR SELECT TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );

DROP POLICY IF EXISTS "dircontacts_insert" ON public."DirectoryContacts";
CREATE POLICY "dircontacts_insert" ON public."DirectoryContacts"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );

DROP POLICY IF EXISTS "dircontacts_update" ON public."DirectoryContacts";
CREATE POLICY "dircontacts_update" ON public."DirectoryContacts"
  FOR UPDATE TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );


-- ---------- DirectoryCustomers ----------
DROP POLICY IF EXISTS "dircustomers_select" ON public."DirectoryCustomers";
CREATE POLICY "dircustomers_select" ON public."DirectoryCustomers"
  FOR SELECT TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );

DROP POLICY IF EXISTS "dircustomers_insert" ON public."DirectoryCustomers";
CREATE POLICY "dircustomers_insert" ON public."DirectoryCustomers"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );

DROP POLICY IF EXISTS "dircustomers_update" ON public."DirectoryCustomers";
CREATE POLICY "dircustomers_update" ON public."DirectoryCustomers"
  FOR UPDATE TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );
