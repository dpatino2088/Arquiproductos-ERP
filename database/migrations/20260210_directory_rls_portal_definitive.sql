-- ============================================================
-- OBJETIVO: Arreglar definitivamente "new row violates row-level
-- security policy for table DirectoryContacts" para usuarios
-- portal (DealerUsers). Sin tablas nuevas, solo políticas y funciones.
-- ============================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) FUNCIONES
-- ---------------------------------------------------------------------------

-- is_org_user_member(p_org_id uuid): TRUE si auth.uid() es OrganizationUser
-- (deleted=false) O DealerUser (organization_id=p_org_id, user_id=auth.uid(), deleted=false, status IN ('active','invited')).
-- SECURITY DEFINER, search_path=public (auth.uid() es schema-qualified).
CREATE OR REPLACE FUNCTION public.is_org_user_member(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT
    EXISTS (
      SELECT 1
      FROM public."OrganizationUsers" ou
      WHERE ou.organization_id = p_org_id
        AND ou.user_id = auth.uid()
        AND (ou.deleted IS NULL OR ou.deleted = false)
        AND (ou.status IS NULL OR ou.status IN ('active', 'invited'))
    )
    OR
    EXISTS (
      SELECT 1
      FROM public."DealerUsers" du
      WHERE du.organization_id = p_org_id
        AND du.user_id = auth.uid()
        AND (du.deleted IS NULL OR du.deleted = false)
        AND (du.status IS NULL OR du.status IN ('active', 'invited'))
    );
$$;

GRANT EXECUTE ON FUNCTION public.is_org_user_member(uuid) TO anon, authenticated;

-- current_dealer_id(p_org_id uuid): DealerUsers.dealer_id para auth.uid()
-- con mismo filtro status/deleted. SECURITY DEFINER.
CREATE OR REPLACE FUNCTION public.current_dealer_id(p_org_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT du.dealer_id
  FROM public."DealerUsers" du
  WHERE du.organization_id = p_org_id
    AND du.user_id = auth.uid()
    AND (du.deleted IS NULL OR du.deleted = false)
    AND (du.status IS NULL OR du.status IN ('active', 'invited'))
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.current_dealer_id(uuid) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2) DirectoryContacts: eliminar TODAS las políticas INSERT, crear solo una
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS dircontacts_insert ON public."DirectoryContacts";
DROP POLICY IF EXISTS directory_contacts_insert ON public."DirectoryContacts";
DROP POLICY IF EXISTS directorycontacts_dealer_insert ON public."DirectoryContacts";
DROP POLICY IF EXISTS directorycontacts_org_insert ON public."DirectoryContacts";

CREATE POLICY dircontacts_insert
ON public."DirectoryContacts"
FOR INSERT
TO authenticated
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

-- ---------------------------------------------------------------------------
-- 3) DirectoryCustomers: mismo patrón (eliminar todas INSERT, una sola)
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS dircustomers_insert ON public."DirectoryCustomers";
DROP POLICY IF EXISTS directory_customers_insert ON public."DirectoryCustomers";
DROP POLICY IF EXISTS directorycustomers_dealer_insert ON public."DirectoryCustomers";
DROP POLICY IF EXISTS directorycustomers_org_insert ON public."DirectoryCustomers";

CREATE POLICY dircustomers_insert
ON public."DirectoryCustomers"
FOR INSERT
TO authenticated
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

COMMIT;
