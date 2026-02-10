-- ============================================================
-- DIRECTORY V2 — RLS + funciones + link portal user
-- Rehacer Directory (Contacts + Customers) para que funcione
-- con usuarios internos (OrganizationUsers) y portal (DealerUsers).
-- Sin tablas nuevas. Una política INSERT por tabla, SELECT/UPDATE simples.
-- ============================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) RPC: link_portal_user(p_org_id uuid) — linkear DealerUsers a auth.uid()
-- Busca por organization_id y portal_user_email = JWT email; setea user_id si null.
-- Así current_dealer_id puede depender siempre de user_id.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.link_portal_user(p_org_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_email text;
  v_uid uuid;
  v_dealer_id uuid;
BEGIN
  v_uid := auth.uid();
  v_email := nullif(trim(auth.jwt() ->> 'email'), '');
  IF v_uid IS NULL OR v_email IS NULL THEN
    RETURN NULL;
  END IF;

  UPDATE public."DealerUsers" du
  SET user_id = v_uid,
      updated_at = now()
  WHERE du.organization_id = p_org_id
    AND (du.deleted IS NULL OR du.deleted = false)
    AND (du.status IS NULL OR du.status IN ('active', 'invited'))
    AND du.user_id IS NULL
    AND v_email IS NOT NULL
    AND lower(trim(du.portal_user_email)) = lower(v_email)
  RETURNING du.dealer_id INTO v_dealer_id;

  RETURN v_dealer_id;
END;
$$;

COMMENT ON FUNCTION public.link_portal_user(uuid) IS 'Links DealerUsers to auth.uid() by org and JWT email. Call once per session for portal. Returns dealer_id of updated row (or NULL).';
GRANT EXECUTE ON FUNCTION public.link_portal_user(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2) is_org_user_member(p_org_id uuid) — TRUE si OU o DU (user_id = auth.uid())
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_org_user_member(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public, auth
AS $$
  SELECT
    EXISTS (
      SELECT 1 FROM public."OrganizationUsers" ou
      WHERE ou.organization_id = p_org_id
        AND ou.user_id = auth.uid()
        AND (ou.deleted IS NULL OR ou.deleted = false)
        AND (ou.status IS NULL OR ou.status IN ('active', 'invited'))
    )
    OR
    EXISTS (
      SELECT 1 FROM public."DealerUsers" du
      WHERE du.organization_id = p_org_id
        AND du.user_id = auth.uid()
        AND (du.deleted IS NULL OR du.deleted = false)
        AND (du.status IS NULL OR du.status IN ('active', 'invited'))
    );
$$;

GRANT EXECUTE ON FUNCTION public.is_org_user_member(uuid) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3) current_dealer_id(p_org_id uuid) — dealer_id del portal user para esa org
-- Prioridad: user_id = auth.uid(); fallback por email SOLO si user_id es null.
-- ORDER BY created_at DESC LIMIT 1 para desempate.
-- ---------------------------------------------------------------------------
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
    AND (du.deleted IS NULL OR du.deleted = false)
    AND (du.status IS NULL OR du.status IN ('active', 'invited'))
    AND (
      du.user_id = auth.uid()
      OR (du.user_id IS NULL AND nullif(trim(auth.jwt() ->> 'email'), '') IS NOT NULL AND lower(trim(du.portal_user_email)) = lower(trim(auth.jwt() ->> 'email')))
    )
  ORDER BY du.created_at DESC
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.current_dealer_id(uuid) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4) DirectoryContacts — RLS simple
-- ---------------------------------------------------------------------------
ALTER TABLE public."DirectoryContacts" ENABLE ROW LEVEL SECURITY;

-- Eliminar TODAS las políticas existentes (INSERT, SELECT, UPDATE, DELETE)
DROP POLICY IF EXISTS dircontacts_insert ON public."DirectoryContacts";
DROP POLICY IF EXISTS directory_contacts_insert ON public."DirectoryContacts";
DROP POLICY IF EXISTS directorycontacts_dealer_insert ON public."DirectoryContacts";
DROP POLICY IF EXISTS directorycontacts_org_insert ON public."DirectoryContacts";
DROP POLICY IF EXISTS directory_contacts_select ON public."DirectoryContacts";
DROP POLICY IF EXISTS directory_contacts_update ON public."DirectoryContacts";
DROP POLICY IF EXISTS directory_contacts_delete ON public."DirectoryContacts";
DROP POLICY IF EXISTS directorycontacts_dealer_select ON public."DirectoryContacts";
DROP POLICY IF EXISTS directorycontacts_dealer_update ON public."DirectoryContacts";
DROP POLICY IF EXISTS directorycontacts_org_select ON public."DirectoryContacts";
DROP POLICY IF EXISTS directorycontacts_org_update ON public."DirectoryContacts";

-- SELECT: org users ven toda la org; portal solo su dealer
CREATE POLICY dircontacts_select ON public."DirectoryContacts"
FOR SELECT TO authenticated
USING (
  deleted = false
  AND organization_id IS NOT NULL
  AND (
    public.is_org_user_member(organization_id)
    OR (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  )
);

-- INSERT: una sola policy
CREATE POLICY dircontacts_insert ON public."DirectoryContacts"
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

-- UPDATE: mismo criterio que SELECT (org o mismo dealer)
CREATE POLICY dircontacts_update ON public."DirectoryContacts"
FOR UPDATE TO authenticated
USING (
  deleted = false
  AND (
    (organization_id IS NOT NULL AND public.is_org_user_member(organization_id))
    OR (organization_id IS NOT NULL AND public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  )
)
WITH CHECK (
  organization_id IS NOT NULL
  AND (
    public.is_org_user_member(organization_id)
    OR (public.current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id)))
  )
);

-- DELETE: no exponer DELETE real; soft delete vía UPDATE deleted=true (ya cubierto por update)
DROP POLICY IF EXISTS directory_contacts_delete ON public."DirectoryContacts";

-- ---------------------------------------------------------------------------
-- 5) DirectoryCustomers — mismo patrón
-- ---------------------------------------------------------------------------
ALTER TABLE public."DirectoryCustomers" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dircustomers_insert ON public."DirectoryCustomers";
DROP POLICY IF EXISTS directory_customers_insert ON public."DirectoryCustomers";
DROP POLICY IF EXISTS directorycustomers_dealer_insert ON public."DirectoryCustomers";
DROP POLICY IF EXISTS directorycustomers_org_insert ON public."DirectoryCustomers";
DROP POLICY IF EXISTS directorycustomers_dealer_select ON public."DirectoryCustomers";
DROP POLICY IF EXISTS directorycustomers_dealer_update ON public."DirectoryCustomers";
DROP POLICY IF EXISTS directorycustomers_org_select ON public."DirectoryCustomers";
DROP POLICY IF EXISTS directorycustomers_org_update ON public."DirectoryCustomers";

CREATE POLICY dircustomers_select ON public."DirectoryCustomers"
FOR SELECT TO authenticated
USING (
  deleted = false
  AND (
    (organization_id IS NOT NULL AND public.is_org_user_member(organization_id))
    OR (organization_id IS NOT NULL AND public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  )
);

CREATE POLICY dircustomers_insert ON public."DirectoryCustomers"
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

CREATE POLICY dircustomers_update ON public."DirectoryCustomers"
FOR UPDATE TO authenticated
USING (
  deleted = false
  AND (
    (organization_id IS NOT NULL AND public.is_org_user_member(organization_id))
    OR (organization_id IS NOT NULL AND public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
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
-- 6) Triggers existentes se mantienen (tg_set_dealer_id_from_portal_user,
--    directorycontacts_fill_org_id, set_created_by). No los recreamos.
--    get_current_portal_user ya usa user_id = auth.uid() OR email; el trigger
--    rellena dealer_id si viene NULL — compatible con WITH CHECK (dealer_id IS NULL permitido).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Verificación (descomentar para ejecutar tras aplicar migración)
-- ---------------------------------------------------------------------------
/*
SELECT polname, polcmd, pg_get_expr(polqual, polrelid) AS using_expr, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy WHERE polrelid = 'public."DirectoryContacts"'::regclass ORDER BY polname;
SELECT polname, polcmd, pg_get_expr(polqual, polrelid) AS using_expr, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy WHERE polrelid = 'public."DirectoryCustomers"'::regclass ORDER BY polname;
SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'is_org_user_member';
SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'current_dealer_id';
SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'link_portal_user';
*/

COMMIT;
