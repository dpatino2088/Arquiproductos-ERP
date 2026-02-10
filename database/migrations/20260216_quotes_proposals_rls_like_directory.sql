-- ============================================================
-- Quotes y Proposals — RLS alineado con Directory
-- Problema: en el dump, quotes_org_* y proposals_org_* exigen dealer_id IS NULL,
-- por lo que los org users no ven quotes/proposals con dealer_id asignado.
-- Y quotes_dealer_* usa current_user_dealer_ids (OrganizationUsers), no portal (DealerUsers).
--
-- Solución: mismo patrón que Directory (20260211_directory_v2.sql):
-- - SELECT/UPDATE: is_org_user_member(org_id) OR (current_dealer_id(org_id) IS NOT NULL AND dealer_id = current_dealer_id(org_id))
-- - INSERT: is_org_user_member(org_id) OR (current_dealer_id(org_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = current_dealer_id(org_id)))
-- Así org users ven toda la org (y el front filtra por selectedDealerId); portal solo su dealer.
-- ============================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Quotes — reemplazar políticas existentes
-- ---------------------------------------------------------------------------
ALTER TABLE public."Quotes" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS quotes_dealer_insert ON public."Quotes";
DROP POLICY IF EXISTS quotes_dealer_select ON public."Quotes";
DROP POLICY IF EXISTS quotes_dealer_update ON public."Quotes";
DROP POLICY IF EXISTS quotes_org_insert ON public."Quotes";
DROP POLICY IF EXISTS quotes_org_select ON public."Quotes";
DROP POLICY IF EXISTS quotes_org_update ON public."Quotes";

-- SELECT: org members ven toda la org; portal solo su dealer. Excluir filas borradas (soft delete).
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

-- INSERT: org puede insertar con cualquier dealer_id o null; portal solo su dealer (o null, el trigger rellena).
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

-- UPDATE: mismo criterio que SELECT
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
-- 2) Proposals — mismo patrón
-- ---------------------------------------------------------------------------
ALTER TABLE public."Proposals" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS proposals_dealer_insert ON public."Proposals";
DROP POLICY IF EXISTS proposals_dealer_select ON public."Proposals";
DROP POLICY IF EXISTS proposals_dealer_update ON public."Proposals";
DROP POLICY IF EXISTS proposals_org_insert ON public."Proposals";
DROP POLICY IF EXISTS proposals_org_select ON public."Proposals";
DROP POLICY IF EXISTS proposals_org_update ON public."Proposals";

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
