-- ============================================================
-- Dealer Manager y Dealer Member pueden borrar (soft delete)
-- Quotes, Proposals y Directory (Contact/Customer).
--
-- Si aún existen políticas antiguas que usan current_user_dealer_ids
-- (solo devuelve dealers para OrganizationUsers, no para DealerUsers),
-- los usuarios portal no pueden UPDATE. Esta migración asegura políticas
-- unificadas con is_org_user_member OR current_dealer_id para que
-- cualquier usuario del dealer (member o member_manager) pueda
-- SELECT/INSERT/UPDATE (incl. set deleted = true).
--
-- Directory (DirectoryContacts, DirectoryCustomers) ya permite UPDATE
-- a portal en 20260211_directory_v2 (current_dealer_id). No se cambia.
-- ============================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Quotes — políticas unificadas (org + portal por current_dealer_id)
-- ---------------------------------------------------------------------------
ALTER TABLE public."Quotes" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS quotes_dealer_insert ON public."Quotes";
DROP POLICY IF EXISTS quotes_dealer_select ON public."Quotes";
DROP POLICY IF EXISTS quotes_dealer_update ON public."Quotes";
DROP POLICY IF EXISTS quotes_org_insert ON public."Quotes";
DROP POLICY IF EXISTS quotes_org_select ON public."Quotes";
DROP POLICY IF EXISTS quotes_org_update ON public."Quotes";
DROP POLICY IF EXISTS quotes_select ON public."Quotes";
DROP POLICY IF EXISTS quotes_insert ON public."Quotes";
DROP POLICY IF EXISTS quotes_update ON public."Quotes";

CREATE POLICY quotes_select ON public."Quotes"
FOR SELECT TO authenticated
USING (
  (deleted = false OR deleted IS NULL)
  AND organization_id IS NOT NULL
  AND (
    public.is_org_user_member(organization_id)
    OR (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  )
);

CREATE POLICY quotes_insert ON public."Quotes"
FOR INSERT TO authenticated
WITH CHECK (
  organization_id IS NOT NULL
  AND (
    public.is_org_user_member(organization_id)
    OR (
      public.current_dealer_id(organization_id) IS NOT NULL
      AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id))
    )
  )
);

CREATE POLICY quotes_update ON public."Quotes"
FOR UPDATE TO authenticated
USING (
  (deleted = false OR deleted IS NULL)
  AND organization_id IS NOT NULL
  AND (
    public.is_org_user_member(organization_id)
    OR (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  )
)
WITH CHECK (
  organization_id IS NOT NULL
  AND (
    public.is_org_user_member(organization_id)
    OR (public.current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id)))
  )
);

-- ---------------------------------------------------------------------------
-- 2) Proposals — mismo patrón (Dealer Member y Dealer Manager pueden borrar)
-- ---------------------------------------------------------------------------
ALTER TABLE public."Proposals" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS proposals_dealer_insert ON public."Proposals";
DROP POLICY IF EXISTS proposals_dealer_select ON public."Proposals";
DROP POLICY IF EXISTS proposals_dealer_update ON public."Proposals";
DROP POLICY IF EXISTS proposals_org_insert ON public."Proposals";
DROP POLICY IF EXISTS proposals_org_select ON public."Proposals";
DROP POLICY IF EXISTS proposals_org_update ON public."Proposals";
DROP POLICY IF EXISTS proposals_select ON public."Proposals";
DROP POLICY IF EXISTS proposals_insert ON public."Proposals";
DROP POLICY IF EXISTS proposals_update ON public."Proposals";

CREATE POLICY proposals_select ON public."Proposals"
FOR SELECT TO authenticated
USING (
  (deleted = false OR deleted IS NULL)
  AND organization_id IS NOT NULL
  AND (
    public.is_org_user_member(organization_id)
    OR (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  )
);

CREATE POLICY proposals_insert ON public."Proposals"
FOR INSERT TO authenticated
WITH CHECK (
  organization_id IS NOT NULL
  AND (
    public.is_org_user_member(organization_id)
    OR (
      public.current_dealer_id(organization_id) IS NOT NULL
      AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id))
    )
  )
);

CREATE POLICY proposals_update ON public."Proposals"
FOR UPDATE TO authenticated
USING (
  (deleted = false OR deleted IS NULL)
  AND organization_id IS NOT NULL
  AND (
    public.is_org_user_member(organization_id)
    OR (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  )
)
WITH CHECK (
  organization_id IS NOT NULL
  AND (
    public.is_org_user_member(organization_id)
    OR (public.current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id)))
  )
);

COMMIT;
