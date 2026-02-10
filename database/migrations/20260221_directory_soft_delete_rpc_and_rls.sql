-- ============================================================
-- Directory: RPC soft-delete + RLS para que Dealer puedan borrar
-- ============================================================
-- 1) RPCs SECURITY DEFINER para soft-delete (Contact y Customer).
--    Comprueban is_org_user_member O current_dealer_id igual al dealer_id del registro.
-- 2) Ajustar políticas UPDATE de DirectoryContacts y DirectoryCustomers para usar
--    is_org_user_member (incluye DealerUsers) en lugar de is_org_owner_or_admin,
--    así cualquier usuario del org o del dealer puede actualizar (soft delete).
-- ============================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) RPC: soft_delete_directory_contact
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.soft_delete_directory_contact(p_contact_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public."DirectoryContacts" c
  SET deleted = true, updated_at = now()
  WHERE c.id = p_contact_id
    AND (c.deleted IS NULL OR c.deleted = false)
    AND c.organization_id IS NOT NULL
    AND (
      public.is_org_user_member(c.organization_id)
      OR (public.current_dealer_id(c.organization_id) IS NOT NULL AND c.dealer_id = public.current_dealer_id(c.organization_id))
    );
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION public.soft_delete_directory_contact(uuid) IS 'Soft-delete a directory contact. Only if current user has access (org member or same dealer).';

GRANT EXECUTE ON FUNCTION public.soft_delete_directory_contact(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2) RPC: soft_delete_directory_customer
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.soft_delete_directory_customer(p_customer_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public."DirectoryCustomers" c
  SET deleted = true, updated_at = now()
  WHERE c.id = p_customer_id
    AND (c.deleted IS NULL OR c.deleted = false)
    AND c.organization_id IS NOT NULL
    AND (
      public.is_org_user_member(c.organization_id)
      OR (public.current_dealer_id(c.organization_id) IS NOT NULL AND c.dealer_id = public.current_dealer_id(c.organization_id))
    );
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION public.soft_delete_directory_customer(uuid) IS 'Soft-delete a directory customer. Only if current user has access (org member or same dealer).';

GRANT EXECUTE ON FUNCTION public.soft_delete_directory_customer(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3) RLS: DirectoryContacts UPDATE — permitir a org members Y portal (dealer)
--    Si existen políticas que usan is_org_owner_or_admin, reemplazar por is_org_user_member.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS dircontacts_update ON public."DirectoryContacts";

CREATE POLICY dircontacts_update ON public."DirectoryContacts"
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
-- 4) RLS: DirectoryCustomers UPDATE — mismo criterio
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS dircustomers_update ON public."DirectoryCustomers";

CREATE POLICY dircustomers_update ON public."DirectoryCustomers"
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

-- Opcional: si SELECT usa is_org_member y por eso portal no ve filas, reemplazar por is_org_user_member
DROP POLICY IF EXISTS dircontacts_select ON public."DirectoryContacts";
CREATE POLICY dircontacts_select ON public."DirectoryContacts"
FOR SELECT TO authenticated
USING (
  (deleted = false OR deleted IS NULL)
  AND organization_id IS NOT NULL
  AND (
    public.is_org_user_member(organization_id)
    OR (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  )
);

DROP POLICY IF EXISTS dircustomers_select ON public."DirectoryCustomers";
CREATE POLICY dircustomers_select ON public."DirectoryCustomers"
FOR SELECT TO authenticated
USING (
  (deleted = false OR deleted IS NULL)
  AND organization_id IS NOT NULL
  AND (
    public.is_org_user_member(organization_id)
    OR (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  )
);

COMMIT;
