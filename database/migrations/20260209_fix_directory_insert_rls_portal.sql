-- OBJETIVO: Arreglar "new row violates row-level security policy" cuando un
-- usuario portal (DealerUsers) crea DirectoryContacts o DirectoryCustomers.
-- - is_org_user_member: re-crear con param (p_org_id uuid); incluye OU + DU.
-- - INSERT policies: permitir portal cuando dealer_id IS NULL OR dealer_id = current_dealer_id(org).

BEGIN;

-- A) Actualizar is_org_user_member SIN DROP: muchas policies (QuoteLines, BOMTemplates, etc.)
--    dependen de ella. CREATE OR REPLACE mantiene la firma (uuid) y actualiza solo el cuerpo.
CREATE OR REPLACE FUNCTION public.is_org_user_member(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public, auth
AS $$
  select
    exists (
      select 1
      from public."OrganizationUsers" ou
      where ou.organization_id = p_org_id
        and ou.user_id = auth.uid()
        and coalesce(ou.deleted,false) = false
        and (ou.status is null or ou.status in ('active','invited'))
    )
    or
    exists (
      select 1
      from public."DealerUsers" du
      where du.organization_id = p_org_id
        and du.user_id = auth.uid()
        and coalesce(du.deleted,false) = false
        and (du.status is null or du.status in ('active','invited'))
    );
$$;

GRANT EXECUTE ON FUNCTION public.is_org_user_member(uuid) TO anon, authenticated;

-- A2) current_dealer_id(p_org_id uuid): SIN DROP (policies dependen de ella). CREATE OR REPLACE solo cuerpo.
--     Devuelve DealerUsers.dealer_id para org=p_org_id, user=auth.uid(), status active/invited, deleted=false.
CREATE OR REPLACE FUNCTION public.current_dealer_id(p_org_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public, auth
AS $$
  SELECT du.dealer_id
  FROM public."DealerUsers" du
  WHERE du.organization_id = p_org_id
    AND du.user_id = auth.uid()
    AND coalesce(du.deleted, false) = false
    AND (du.status IS NULL OR du.status IN ('active', 'invited'))
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.current_dealer_id(uuid) TO anon, authenticated;

-- B) Una sola política INSERT en DirectoryContacts (evitar conflicto con directory_contacts_insert, etc.)
--    El dump tiene varias: dircontacts_insert, directory_contacts_insert (usa app_user_id JWT),
--    directorycontacts_dealer_insert, directorycontacts_org_insert. Los usuarios portal no tienen
--    app_user_id en JWT; dejar solo una política que permita org (is_org_user_member) y portal (current_dealer_id).

ALTER TABLE public."DirectoryContacts" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."DirectoryCustomers" ENABLE ROW LEVEL SECURITY;

-- Quitar TODAS las políticas INSERT existentes en DirectoryContacts
DROP POLICY IF EXISTS dircontacts_insert ON public."DirectoryContacts";
DROP POLICY IF EXISTS directory_contacts_insert ON public."DirectoryContacts";
DROP POLICY IF EXISTS directorycontacts_dealer_insert ON public."DirectoryContacts";
DROP POLICY IF EXISTS directorycontacts_org_insert ON public."DirectoryContacts";

-- Una sola política INSERT: org (OrganizationUsers + DealerUsers) o portal (current_dealer_id)
CREATE POLICY dircontacts_insert
ON public."DirectoryContacts"
FOR INSERT
TO authenticated
WITH CHECK (
  (
    organization_id IS NOT NULL
    AND public.is_org_user_member(organization_id)
  )
  OR
  (
    public.current_dealer_id(organization_id) IS NOT NULL
    AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id))
  )
);

-- DirectoryCustomers: igual, una sola INSERT
DROP POLICY IF EXISTS dircustomers_insert ON public."DirectoryCustomers";
-- Por si en tu base existen políticas con otros nombres (dump puede variar):
DROP POLICY IF EXISTS directory_customers_insert ON public."DirectoryCustomers";
DROP POLICY IF EXISTS directorycustomers_dealer_insert ON public."DirectoryCustomers";
DROP POLICY IF EXISTS directorycustomers_org_insert ON public."DirectoryCustomers";

CREATE POLICY dircustomers_insert
ON public."DirectoryCustomers"
FOR INSERT
TO authenticated
WITH CHECK (
  (
    organization_id IS NOT NULL
    AND public.is_org_user_member(organization_id)
  )
  OR
  (
    public.current_dealer_id(organization_id) IS NOT NULL
    AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id))
  )
);

COMMIT;
