-- =====================================================
-- RLS Dealer Scope + Audit (created_by_name, updated_by_*)
-- =====================================================
-- PART A: Portal (DealerUsers) SOLO ve/edita SU dealer_id.
--        Internal (OrganizationUsers) sin cambios; "Acting as Dealer" es solo UI.
-- PART C: Audit columns + set_audit_fields() con nombre (DealerUsers.portal_user_name / OrganizationUsers.user_name).
-- =====================================================
-- NO DROP is_org_user_member. No romper policies internal; solo corregir portal.
-- =====================================================

SET search_path = public;

-- ---------------------------------------------------------------------------
-- A.1) Función: dealer_id del portal user para la org (null si no es portal)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_dealer_id(p_org_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT du.dealer_id
  FROM public."DealerUsers" du
  WHERE du.organization_id = p_org_id
    AND du.user_id = auth.uid()
    AND (du.deleted IS NULL OR du.deleted = false)
    AND (du.status IS NULL OR du.status IN ('active', 'invited'))
  LIMIT 1;
$$;

COMMENT ON FUNCTION public.current_dealer_id(uuid) IS 'Dealer ID for current portal user in the given org. NULL if not a DealerUser or not in that org. Used by RLS for Directory/Quotes.';

-- ---------------------------------------------------------------------------
-- A.2) DirectoryContacts — RLS por dealer para portal
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "dircontacts_select_own_org_or_dealer" ON public."DirectoryContacts";
DROP POLICY IF EXISTS "dir_contacts_write_owner_admin" ON public."DirectoryContacts";

-- SELECT: internal (org member) ve todo; portal solo su dealer_id
CREATE POLICY "dircontacts_select"
  ON public."DirectoryContacts"
  FOR SELECT
  TO authenticated
  USING (
    (deleted = false)
    AND (
      (organization_id IS NOT NULL AND public.is_org_member(organization_id))
      OR
      (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
    )
  );

-- INSERT: internal org member o portal con dealer_id = current_dealer_id
CREATE POLICY "dircontacts_insert"
  ON public."DirectoryContacts"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR
    (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  );

-- UPDATE/DELETE: internal owner/admin o portal solo su dealer
CREATE POLICY "dircontacts_update"
  ON public."DirectoryContacts"
  FOR UPDATE
  TO authenticated
  USING (
    (organization_id IS NOT NULL AND public.is_org_owner_or_admin(organization_id))
    OR
    (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  )
  WITH CHECK (
    (organization_id IS NOT NULL AND public.is_org_owner_or_admin(organization_id))
    OR
    (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  );

CREATE POLICY "dircontacts_delete"
  ON public."DirectoryContacts"
  FOR DELETE
  TO authenticated
  USING (
    (organization_id IS NOT NULL AND public.is_org_owner_or_admin(organization_id))
    OR
    (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  );

-- ---------------------------------------------------------------------------
-- A.3) DirectoryCustomers — mismo patrón
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "dircustomers_select_own_org_or_dealer" ON public."DirectoryCustomers";
DROP POLICY IF EXISTS "dir_customers_write_owner_admin" ON public."DirectoryCustomers";

CREATE POLICY "dircustomers_select"
  ON public."DirectoryCustomers"
  FOR SELECT
  TO authenticated
  USING (
    (deleted = false)
    AND (
      (organization_id IS NOT NULL AND public.is_org_member(organization_id))
      OR
      (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
    )
  );

CREATE POLICY "dircustomers_insert"
  ON public."DirectoryCustomers"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR
    (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  );

CREATE POLICY "dircustomers_update"
  ON public."DirectoryCustomers"
  FOR UPDATE
  TO authenticated
  USING (
    (organization_id IS NOT NULL AND public.is_org_owner_or_admin(organization_id))
    OR
    (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  )
  WITH CHECK (
    (organization_id IS NOT NULL AND public.is_org_owner_or_admin(organization_id))
    OR
    (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  );

CREATE POLICY "dircustomers_delete"
  ON public."DirectoryCustomers"
  FOR DELETE
  TO authenticated
  USING (
    (organization_id IS NOT NULL AND public.is_org_owner_or_admin(organization_id))
    OR
    (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  );

-- ---------------------------------------------------------------------------
-- A.4) Quotes — RLS: internal org member; portal solo dealer_id = current_dealer_id
--      Eliminamos políticas que permitían portal "ver todo" y fijamos scope estricto.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can read own organization quotes" ON public."Quotes";
DROP POLICY IF EXISTS "Users can insert own organization quotes" ON public."Quotes";
DROP POLICY IF EXISTS "Users can update own organization quotes" ON public."Quotes";
DROP POLICY IF EXISTS "quotes_access" ON public."Quotes";
DROP POLICY IF EXISTS "quotes_select" ON public."Quotes";
DROP POLICY IF EXISTS "quotes_select_org_or_portal" ON public."Quotes";
DROP POLICY IF EXISTS "quotes_insert_org_or_portal" ON public."Quotes";
DROP POLICY IF EXISTS "quotes_update_org_or_portal" ON public."Quotes";
DROP POLICY IF EXISTS "quotes_write" ON public."Quotes";

CREATE POLICY "quotes_select"
  ON public."Quotes"
  FOR SELECT
  TO authenticated
  USING (
    (deleted = false)
    AND (
      (organization_id IS NOT NULL AND public.is_org_member(organization_id))
      OR
      (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
    )
  );

CREATE POLICY "quotes_insert"
  ON public."Quotes"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR
    (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  );

CREATE POLICY "quotes_update"
  ON public."Quotes"
  FOR UPDATE
  TO authenticated
  USING (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR
    (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  )
  WITH CHECK (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR
    (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  );

CREATE POLICY "quotes_delete"
  ON public."Quotes"
  FOR DELETE
  TO authenticated
  USING (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR
    (public.current_dealer_id(organization_id) IS NOT NULL AND dealer_id = public.current_dealer_id(organization_id))
  );

-- ---------------------------------------------------------------------------
-- A.5) QuoteLines — vía quote: internal org member; portal solo si quote.dealer_id = current_dealer_id
--      Reemplazamos is_org_user_member por is_org_member + portal por current_dealer_id
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "quotelines_select" ON public."QuoteLines";
DROP POLICY IF EXISTS "quotelines_insert" ON public."QuoteLines";
DROP POLICY IF EXISTS "quotelines_update" ON public."QuoteLines";
DROP POLICY IF EXISTS "quotelines_delete" ON public."QuoteLines";

CREATE POLICY "quotelines_select"
  ON public."QuoteLines"
  FOR SELECT
  TO authenticated
  USING (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR
    (EXISTS (
      SELECT 1 FROM public."Quotes" q
      WHERE q.id = QuoteLines.quote_id
        AND q.organization_id = QuoteLines.organization_id
        AND public.current_dealer_id(q.organization_id) IS NOT NULL
        AND q.dealer_id = public.current_dealer_id(q.organization_id)
    ))
  );

CREATE POLICY "quotelines_insert"
  ON public."QuoteLines"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR
    (EXISTS (
      SELECT 1 FROM public."Quotes" q
      WHERE q.id = QuoteLines.quote_id
        AND q.organization_id = QuoteLines.organization_id
        AND public.current_dealer_id(q.organization_id) IS NOT NULL
        AND q.dealer_id = public.current_dealer_id(q.organization_id)
    ))
  );

CREATE POLICY "quotelines_update"
  ON public."QuoteLines"
  FOR UPDATE
  TO authenticated
  USING (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR
    (EXISTS (
      SELECT 1 FROM public."Quotes" q
      WHERE q.id = QuoteLines.quote_id
        AND q.organization_id = QuoteLines.organization_id
        AND public.current_dealer_id(q.organization_id) IS NOT NULL
        AND q.dealer_id = public.current_dealer_id(q.organization_id)
    ))
  )
  WITH CHECK (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR
    (EXISTS (
      SELECT 1 FROM public."Quotes" q
      WHERE q.id = QuoteLines.quote_id
        AND q.organization_id = QuoteLines.organization_id
        AND public.current_dealer_id(q.organization_id) IS NOT NULL
        AND q.dealer_id = public.current_dealer_id(q.organization_id)
    ))
  );

CREATE POLICY "quotelines_delete"
  ON public."QuoteLines"
  FOR DELETE
  TO authenticated
  USING (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR
    (EXISTS (
      SELECT 1 FROM public."Quotes" q
      WHERE q.id = QuoteLines.quote_id
        AND q.organization_id = QuoteLines.organization_id
        AND public.current_dealer_id(q.organization_id) IS NOT NULL
        AND q.dealer_id = public.current_dealer_id(q.organization_id)
    ))
  );

-- =====================================================
-- PART C — Audit: created_by_name, updated_by_* (solo si faltan)
-- =====================================================

-- C.1) Columnas audit (idempotente)
DO $$
BEGIN
  -- DirectoryContacts
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='DirectoryContacts' AND column_name='created_by_name') THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN created_by_name text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='DirectoryContacts' AND column_name='updated_by_user_id') THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN updated_by_user_id uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='DirectoryContacts' AND column_name='updated_by_name') THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN updated_by_name text;
  END IF;

  -- DirectoryCustomers
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='DirectoryCustomers' AND column_name='created_by_name') THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN created_by_name text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='DirectoryCustomers' AND column_name='updated_by_user_id') THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN updated_by_user_id uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='DirectoryCustomers' AND column_name='updated_by_name') THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN updated_by_name text;
  END IF;

  -- Quotes (created_by_user_id/created_by_email ya existen; añadir created_by_name y updated_by_*)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Quotes' AND column_name='created_by_name') THEN
    ALTER TABLE public."Quotes" ADD COLUMN created_by_name text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Quotes' AND column_name='updated_by_user_id') THEN
    ALTER TABLE public."Quotes" ADD COLUMN updated_by_user_id uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Quotes' AND column_name='updated_by_name') THEN
    ALTER TABLE public."Quotes" ADD COLUMN updated_by_name text;
  END IF;

  -- Proposals
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Proposals' AND column_name='created_by_name') THEN
    ALTER TABLE public."Proposals" ADD COLUMN created_by_name text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Proposals' AND column_name='updated_by_user_id') THEN
    ALTER TABLE public."Proposals" ADD COLUMN updated_by_user_id uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='Proposals' AND column_name='updated_by_name') THEN
    ALTER TABLE public."Proposals" ADD COLUMN updated_by_name text;
  END IF;

  -- SalesOrders
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='created_by_user_id') THEN
    ALTER TABLE public."SalesOrders" ADD COLUMN created_by_user_id uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='created_by_name') THEN
    ALTER TABLE public."SalesOrders" ADD COLUMN created_by_name text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='updated_by_user_id') THEN
    ALTER TABLE public."SalesOrders" ADD COLUMN updated_by_user_id uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='SalesOrders' AND column_name='updated_by_name') THEN
    ALTER TABLE public."SalesOrders" ADD COLUMN updated_by_name text;
  END IF;
END $$;

-- C.2) Función trigger: setear created_by_name y updated_by_* (solo si null).
--      created_by_user_id / created_by_email los sigue poniendo set_created_by_fields donde exista.
CREATE OR REPLACE FUNCTION public.set_audit_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_name text;
BEGIN
  -- Display name: DealerUsers.portal_user_name o OrganizationUsers.user_name; fallback email
  SELECT COALESCE(du.portal_user_name, ou.user_name, nullif(trim(current_setting('request.jwt.claims', true)::jsonb ->> 'email'), ''))
  INTO v_name
  FROM (SELECT 1) _d
  LEFT JOIN public."DealerUsers" du ON du.user_id = v_uid AND (du.deleted IS NULL OR du.deleted = false) AND du.status IN ('active', 'invited')
  LEFT JOIN public."OrganizationUsers" ou ON ou.user_id = v_uid AND (ou.deleted IS NULL OR ou.deleted = false)
  LIMIT 1;

  IF TG_OP = 'INSERT' THEN
    IF NEW.created_by_name IS NULL AND v_name IS NOT NULL THEN
      NEW.created_by_name := v_name;
    END IF;
    -- created_by_user_id lo setea set_created_by_fields donde aplique; no pisar (Proposals usa created_by_portal_user_id en portal).
  END IF;

  IF v_uid IS NOT NULL THEN
    NEW.updated_by_user_id := v_uid;
  END IF;
  IF v_name IS NOT NULL THEN
    NEW.updated_by_name := v_name;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.set_audit_fields() IS 'Trigger: set created_by_user_id/name and updated_by_user_id/name. Name from DealerUsers.portal_user_name or OrganizationUsers.user_name; fallback email. Only sets if null.';

-- C.3) Triggers BEFORE INSERT OR UPDATE (solo tablas que tienen las columnas)
-- DirectoryContacts
DROP TRIGGER IF EXISTS trg_directorycontacts_set_audit ON public."DirectoryContacts";
CREATE TRIGGER trg_directorycontacts_set_audit
  BEFORE INSERT OR UPDATE ON public."DirectoryContacts"
  FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();

-- DirectoryCustomers
DROP TRIGGER IF EXISTS trg_directorycustomers_set_audit ON public."DirectoryCustomers";
CREATE TRIGGER trg_directorycustomers_set_audit
  BEFORE INSERT OR UPDATE ON public."DirectoryCustomers"
  FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();

-- Quotes (mantener set_created_by_fields para created_by_email si ya existe; set_audit_fields cubre created_by_name y updated_by_*)
DROP TRIGGER IF EXISTS trg_quotes_set_audit ON public."Quotes";
CREATE TRIGGER trg_quotes_set_audit
  BEFORE INSERT OR UPDATE ON public."Quotes"
  FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();

-- Proposals
DROP TRIGGER IF EXISTS trg_proposals_set_audit ON public."Proposals";
CREATE TRIGGER trg_proposals_set_audit
  BEFORE INSERT OR UPDATE ON public."Proposals"
  FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();

-- SalesOrders
DROP TRIGGER IF EXISTS trg_salesorders_set_audit ON public."SalesOrders";
CREATE TRIGGER trg_salesorders_set_audit
  BEFORE INSERT OR UPDATE ON public."SalesOrders"
  FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();

-- Grants
GRANT EXECUTE ON FUNCTION public.current_dealer_id(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.current_dealer_id(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_dealer_id(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.set_audit_fields() TO anon;
GRANT EXECUTE ON FUNCTION public.set_audit_fields() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_audit_fields() TO service_role;
