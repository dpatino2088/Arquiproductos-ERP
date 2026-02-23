-- =============================================================================
-- Migration: DocumentTermsTemplates - Allow Dealer Manager (member_manager) to INSERT/UPDATE
-- =============================================================================
-- Dealer Member: can VIEW terms (SELECT)
-- Dealer Manager: can VIEW and EDIT terms (SELECT, INSERT, UPDATE)
--
-- Current dtt_insert/dtt_update use AppUsers.dealer_id; portal users (DealerUsers)
-- may not have AppUsers, so they fail RLS. Add branch for is_dealer_portal_user_with_write.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- dtt_insert: add DealerUsers member_manager
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "dtt_insert" ON public."DocumentTermsTemplates";
CREATE POLICY "dtt_insert" ON public."DocumentTermsTemplates"
  FOR INSERT TO authenticated
  WITH CHECK (
    -- Org users
    (
      organization_id IN (
        SELECT ou.organization_id
        FROM public."OrganizationUsers" ou
        WHERE ou.user_id = auth.uid()
          AND (ou.deleted IS NULL OR ou.deleted = false)
      )
      AND EXISTS (
        SELECT 1 FROM public."OrganizationUsers" ou
        WHERE ou.user_id = auth.uid() AND (ou.deleted IS NULL OR ou.deleted = false)
      )
    )
    OR
    -- AppUsers dealer (user_type='dealer')
    (
      dealer_id IS NOT NULL
      AND dealer_id = (
        SELECT au.dealer_id
        FROM public."AppUsers" au
        WHERE au.auth_user_id = auth.uid()
        LIMIT 1
      )
    )
    OR
    -- DealerUsers member_manager (Dealer Manager) - portal users
    (
      dealer_id IS NOT NULL
      AND public.is_dealer_portal_user_with_write(dealer_id)
      AND organization_id = (
        SELECT d.organization_id
        FROM public."Dealers" d
        WHERE d.id = dealer_id AND (d.deleted IS NULL OR d.deleted = false)
        LIMIT 1
      )
    )
  );


-- -----------------------------------------------------------------------------
-- dtt_select: add DealerUsers (member + member_manager) - can view
-- -----------------------------------------------------------------------------
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
    -- DealerUsers (member or member_manager) - can view their dealer's templates
    (
      dealer_id IS NOT NULL
      AND public.is_dealer_portal_user(dealer_id)
    )
    OR
    -- DealerUsers - can view GLOBAL templates (dealer_id NULL) for their org (Quote fallback)
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


-- -----------------------------------------------------------------------------
-- dtt_update: add DealerUsers member_manager
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "dtt_update" ON public."DocumentTermsTemplates";
CREATE POLICY "dtt_update" ON public."DocumentTermsTemplates"
  FOR UPDATE TO authenticated
  USING (
    -- Org users
    (
      organization_id IN (
        SELECT ou.organization_id
        FROM public."OrganizationUsers" ou
        WHERE ou.user_id = auth.uid() AND (ou.deleted IS NULL OR ou.deleted = false)
      )
      AND (
        EXISTS (
          SELECT 1 FROM public."OrganizationUsers" ou
          WHERE ou.user_id = auth.uid() AND (ou.deleted IS NULL OR ou.deleted = false)
        )
        OR dealer_id = (
          SELECT au.dealer_id
          FROM public."AppUsers" au
          WHERE au.auth_user_id = auth.uid()
          LIMIT 1
        )
      )
    )
    OR
    -- AppUsers dealer
    (
      dealer_id = (
        SELECT au.dealer_id
        FROM public."AppUsers" au
        WHERE au.auth_user_id = auth.uid()
        LIMIT 1
      )
    )
    OR
    -- DealerUsers member_manager (Dealer Manager)
    (
      dealer_id IS NOT NULL
      AND public.is_dealer_portal_user_with_write(dealer_id)
    )
  )
  WITH CHECK (true);


-- -----------------------------------------------------------------------------
-- set_dealer_default_terms_template: allow Dealer Manager (member_manager)
-- -----------------------------------------------------------------------------
-- Current RPC gets v_org_id only from OrganizationUsers; portal users fail.
-- Add fallback: get org from DealerUsers when user is member_manager for p_dealer_id.
CREATE OR REPLACE FUNCTION public.set_dealer_default_terms_template(
  p_dealer_id uuid,
  p_doc_type text,
  p_template_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_org_id uuid;
  v_dealer_org uuid;
  v_template_org uuid;
  v_template_dealer uuid;
begin
  if p_doc_type not in ('quote','proposal','sales_order') then
    raise exception 'Invalid doc_type: %', p_doc_type;
  end if;

  -- Caller org: OrganizationUsers (internal) OR DealerUsers member_manager (portal)
  select ou.organization_id into v_org_id
  from public."OrganizationUsers" ou
  where ou.user_id = auth.uid()
    and (ou.deleted is null or ou.deleted = false)
  limit 1;

  if v_org_id is null then
    -- Portal: Dealer Manager for this dealer
    if not public.is_dealer_portal_user_with_write(p_dealer_id) then
      raise exception 'Permission denied: only org users or dealer managers for their dealer';
    end if;
    select d.organization_id into v_org_id
    from public."Dealers" d
    where d.id = p_dealer_id and (d.deleted is null or d.deleted = false)
    limit 1;
  end if;

  if v_org_id is null then
    raise exception 'User is not a member of any organization';
  end if;

  -- Validate dealer in org
  select d.organization_id into v_dealer_org
  from public."Dealers" d
  where d.id = p_dealer_id and (d.deleted is null or d.deleted = false);

  if v_dealer_org is null or v_dealer_org <> v_org_id then
    raise exception 'Dealer % not found in your organization', p_dealer_id;
  end if;

  -- Validate template belongs to org and is either global or same dealer
  select t.organization_id, t.dealer_id
    into v_template_org, v_template_dealer
  from public."DocumentTermsTemplates" t
  where t.id = p_template_id;

  if v_template_org is null or v_template_org <> v_org_id then
    raise exception 'Template not in your organization';
  end if;

  if v_template_dealer is not null and v_template_dealer <> p_dealer_id then
    raise exception 'Template is not global nor for this dealer';
  end if;

  insert into public."DealerDocumentTermsDefaults" (
    organization_id, dealer_id, doc_type, template_id, updated_by_auth_user_id, updated_at
  ) values (
    v_org_id, p_dealer_id, p_doc_type, p_template_id, auth.uid(), now()
  )
  on conflict (dealer_id, doc_type) do update
    set template_id = excluded.template_id,
        organization_id = excluded.organization_id,
        updated_by_auth_user_id = excluded.updated_by_auth_user_id,
        updated_at = now();
end;
$$;
