-- =============================================================================
-- Migration: Dealer scope RLS + Terms sin fallback global
-- =============================================================================
-- Objetivo: Evitar que dealers/usuarios se mezclen.
-- 1) RLS: usar app_effective_dealer_id() cuando org user tiene "acting as".
-- 2) Terms: eliminar fallback global en resolve_default_terms_template_id.
--
-- Ver: docs/DEALER_USER_MIXING_DIAGNOSTIC.md
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) resolve_default_terms_template_id: eliminar fallback global
-- -----------------------------------------------------------------------------
-- Si no hay default explícito para el dealer, devolver NULL (no template global).
-- Así Claroscuro nunca verá contenido de Arquiluz.
CREATE OR REPLACE FUNCTION public.resolve_default_terms_template_id(
  p_organization_id uuid,
  p_dealer_id uuid,
  p_doc_type text
)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_template_id uuid;
begin
  if p_doc_type not in ('quote','proposal','sales_order') then
    raise exception 'Invalid doc_type: %', p_doc_type;
  end if;

  -- Solo default explícito por dealer; sin fallback global
  select d.template_id
  into v_template_id
  from public."DealerDocumentTermsDefaults" d
  where d.organization_id = p_organization_id
    and d.dealer_id = p_dealer_id
    and d.doc_type = p_doc_type
  limit 1;

  return v_template_id;
end;
$$;

COMMENT ON FUNCTION public.resolve_default_terms_template_id(uuid, uuid, text)
  IS 'Returns template_id for dealer-specific default only. No global fallback to avoid dealer mixing.';


-- -----------------------------------------------------------------------------
-- 2) RLS: Proposals - incluir app_effective_dealer_id para org users "acting as"
-- -----------------------------------------------------------------------------
-- Lógica: org user con app_effective_dealer_id() NOT NULL solo ve ese dealer.
DROP POLICY IF EXISTS "proposals_select" ON public."Proposals";
CREATE POLICY "proposals_select" ON public."Proposals"
  FOR SELECT TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      -- Portal: su dealer
      (current_dealer_id(organization_id) IS NOT NULL AND dealer_id = current_dealer_id(organization_id))
      OR
      -- Org user: todos O solo el dealer si "acting as"
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
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
      (current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = current_dealer_id(organization_id)))
      OR
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
        )
      )
    )
  );

DROP POLICY IF EXISTS "proposals_update" ON public."Proposals";
CREATE POLICY "proposals_update" ON public."Proposals"
  FOR UPDATE TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      (current_dealer_id(organization_id) IS NOT NULL AND dealer_id = current_dealer_id(organization_id))
      OR
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
        )
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = current_dealer_id(organization_id)))
      OR
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
        )
      )
    )
  );


-- -----------------------------------------------------------------------------
-- 3) RLS: Quotes
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "quotes_select" ON public."Quotes";
CREATE POLICY "quotes_select" ON public."Quotes"
  FOR SELECT TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      (current_dealer_id(organization_id) IS NOT NULL AND dealer_id = current_dealer_id(organization_id))
      OR
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
        )
      )
    )
  );

DROP POLICY IF EXISTS "quotes_insert" ON public."Quotes";
CREATE POLICY "quotes_insert" ON public."Quotes"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = current_dealer_id(organization_id)))
      OR
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
        )
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
      (current_dealer_id(organization_id) IS NOT NULL AND dealer_id = current_dealer_id(organization_id))
      OR
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
        )
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = current_dealer_id(organization_id)))
      OR
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
        )
      )
    )
  );


-- -----------------------------------------------------------------------------
-- 4) RLS: DirectoryContacts
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "dircontacts_select" ON public."DirectoryContacts";
CREATE POLICY "dircontacts_select" ON public."DirectoryContacts"
  FOR SELECT TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (current_dealer_id(organization_id) IS NOT NULL AND dealer_id = current_dealer_id(organization_id))
      OR
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
        )
      )
    )
  );

DROP POLICY IF EXISTS "dircontacts_insert" ON public."DirectoryContacts";
CREATE POLICY "dircontacts_insert" ON public."DirectoryContacts"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = current_dealer_id(organization_id)))
      OR
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
        )
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
      (current_dealer_id(organization_id) IS NOT NULL AND dealer_id = current_dealer_id(organization_id))
      OR
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
        )
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = current_dealer_id(organization_id)))
      OR
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
        )
      )
    )
  );


-- -----------------------------------------------------------------------------
-- 5) RLS: DirectoryCustomers
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "dircustomers_select" ON public."DirectoryCustomers";
CREATE POLICY "dircustomers_select" ON public."DirectoryCustomers"
  FOR SELECT TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (current_dealer_id(organization_id) IS NOT NULL AND dealer_id = current_dealer_id(organization_id))
      OR
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
        )
      )
    )
  );

DROP POLICY IF EXISTS "dircustomers_insert" ON public."DirectoryCustomers";
CREATE POLICY "dircustomers_insert" ON public."DirectoryCustomers"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = current_dealer_id(organization_id)))
      OR
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
        )
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
      (current_dealer_id(organization_id) IS NOT NULL AND dealer_id = current_dealer_id(organization_id))
      OR
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
        )
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = current_dealer_id(organization_id)))
      OR
      (
        is_org_user_member(organization_id)
        AND (
          app_effective_dealer_id() IS NULL
          OR dealer_id = app_effective_dealer_id()
        )
      )
    )
  );
