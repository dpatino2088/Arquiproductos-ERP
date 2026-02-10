-- ============================================================
-- Migration: Rename Company -> Dealer (Companies -> Dealers, CompanyPortalUsers -> DealerUsers)
-- ============================================================
-- Objetivo: Evitar confusión con "Organization". Todo company_id -> dealer_id.
-- Ejecutar en orden; una transacción.
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Organizations: next_company_no -> next_dealer_no, company_no_prefix -> dealer_no_prefix
-- ============================================================
ALTER TABLE public."Organizations"
  RENAME COLUMN next_company_no TO next_dealer_no;

ALTER TABLE public."Organizations"
  RENAME COLUMN company_no_prefix TO dealer_no_prefix;

ALTER TABLE public."Organizations"
  DROP CONSTRAINT IF EXISTS organizations_company_no_prefix_chk;

ALTER TABLE public."Organizations"
  ADD CONSTRAINT organizations_dealer_no_prefix_chk
  CHECK (length(dealer_no_prefix) >= 1 AND length(dealer_no_prefix) <= 10);

-- ============================================================
-- 2) Companies -> Dealers; columnas company_* -> dealer_*
-- ============================================================
ALTER TABLE public."Companies" RENAME TO "Dealers";

ALTER TABLE public."Dealers" RENAME COLUMN company_no TO dealer_no;
ALTER TABLE public."Dealers" RENAME COLUMN company_name TO dealer_name;
ALTER TABLE public."Dealers" RENAME COLUMN company_email TO dealer_email;
ALTER TABLE public."Dealers" RENAME COLUMN company_phone TO dealer_phone;

ALTER TABLE public."Dealers" RENAME CONSTRAINT companies_org_required TO dealers_org_required;

-- Índices únicos (renombrar para claridad)
ALTER INDEX IF EXISTS companies_org_company_no_unique RENAME TO dealers_org_dealer_no_unique;
ALTER INDEX IF EXISTS uq_companies_org_name RENAME TO uq_dealers_org_name;
ALTER INDEX IF EXISTS idx_companies_org RENAME TO idx_dealers_org;
ALTER INDEX IF EXISTS idx_companies_org_company_no RENAME TO idx_dealers_org_dealer_no;
ALTER INDEX IF EXISTS idx_companies_deleted RENAME TO idx_dealers_deleted;

-- ============================================================
-- 3) CompanyPortalUsers -> DealerUsers; company_id -> dealer_id
-- ============================================================
ALTER TABLE public."CompanyPortalUsers" RENAME TO "DealerUsers";

ALTER TABLE public."DealerUsers" RENAME COLUMN company_id TO dealer_id;

-- FK constraint name
ALTER TABLE public."DealerUsers"
  DROP CONSTRAINT IF EXISTS "CompanyPortalUsers_company_id_fkey";

ALTER TABLE public."DealerUsers"
  ADD CONSTRAINT "DealerUsers_dealer_id_fkey"
  FOREIGN KEY (dealer_id) REFERENCES public."Dealers"(id) ON DELETE RESTRICT;

-- Índices
ALTER INDEX IF EXISTS idx_companyportalusers_company RENAME TO idx_dealerusers_dealer;
ALTER INDEX IF EXISTS companyportal_company_email_uniq RENAME TO dealerportal_dealer_email_uniq;
DROP INDEX IF EXISTS public.companyportalusers_company_email_uniq;
DROP INDEX IF EXISTS public.companyportalusers_org_email_unique;

-- ============================================================
-- 4) Otras tablas: company_id -> dealer_id
-- ============================================================
-- Quotes
ALTER TABLE public."Quotes" RENAME COLUMN company_id TO dealer_id;
ALTER TABLE public."Quotes" DROP CONSTRAINT IF EXISTS fk_quotes_company;
ALTER TABLE public."Quotes"
  ADD CONSTRAINT fk_quotes_dealer
  FOREIGN KEY (dealer_id) REFERENCES public."Dealers"(id) ON DELETE SET NULL;

-- QuoteLines
ALTER TABLE public."QuoteLines" RENAME COLUMN company_id TO dealer_id;

-- SalesOrders
ALTER TABLE public."SalesOrders" RENAME COLUMN company_id TO dealer_id;
ALTER TABLE public."SalesOrders" DROP CONSTRAINT IF EXISTS fk_salesorders_company;
ALTER TABLE public."SalesOrders"
  ADD CONSTRAINT fk_salesorders_dealer
  FOREIGN KEY (dealer_id) REFERENCES public."Dealers"(id) ON DELETE SET NULL;

-- ManufacturingOrders
ALTER TABLE public."ManufacturingOrders" RENAME COLUMN company_id TO dealer_id;
ALTER TABLE public."ManufacturingOrders" DROP CONSTRAINT IF EXISTS fk_manufacturingorders_company;
ALTER TABLE public."ManufacturingOrders"
  ADD CONSTRAINT fk_manufacturingorders_dealer
  FOREIGN KEY (dealer_id) REFERENCES public."Dealers"(id) ON DELETE SET NULL;

-- OrderList
ALTER TABLE public."OrderList" RENAME COLUMN company_id TO dealer_id;
ALTER TABLE public."OrderList" DROP CONSTRAINT IF EXISTS fk_orderlist_company;
ALTER TABLE public."OrderList"
  ADD CONSTRAINT fk_orderlist_dealer
  FOREIGN KEY (dealer_id) REFERENCES public."Dealers"(id) ON DELETE SET NULL;

-- DirectoryCustomers
ALTER TABLE public."DirectoryCustomers" RENAME COLUMN company_id TO dealer_id;
ALTER TABLE public."DirectoryCustomers" DROP CONSTRAINT IF EXISTS DirectoryCustomers_company_id_fkey;
ALTER TABLE public."DirectoryCustomers" DROP CONSTRAINT IF EXISTS directorycustomers_company_id_fkey;
ALTER TABLE public."DirectoryCustomers"
  ADD CONSTRAINT DirectoryCustomers_dealer_id_fkey
  FOREIGN KEY (dealer_id) REFERENCES public."Dealers"(id) ON DELETE SET NULL;

-- DirectoryContacts
ALTER TABLE public."DirectoryContacts" RENAME COLUMN company_id TO dealer_id;
ALTER TABLE public."DirectoryContacts" DROP CONSTRAINT IF EXISTS DirectoryContacts_company_id_fkey;
ALTER TABLE public."DirectoryContacts"
  ADD CONSTRAINT DirectoryContacts_dealer_id_fkey
  FOREIGN KEY (dealer_id) REFERENCES public."Dealers"(id) ON DELETE RESTRICT;

-- Quotes.created_by_portal_user_id -> sigue apuntando a DealerUsers (antes CompanyPortalUsers)
ALTER TABLE public."Quotes" DROP CONSTRAINT IF EXISTS "Quotes_created_by_portal_user_id_fkey";
ALTER TABLE public."Quotes"
  ADD CONSTRAINT "Quotes_created_by_portal_user_id_fkey"
  FOREIGN KEY (created_by_portal_user_id) REFERENCES public."DealerUsers"(id) ON DELETE SET NULL;

-- ============================================================
-- 5) Drop triggers que usan funciones company
-- ============================================================
DROP TRIGGER IF EXISTS trg_companies_set_company_no ON public."Dealers";
DROP TRIGGER IF EXISTS trg_quote_lines_set_company_id ON public."QuoteLines";
DROP TRIGGER IF EXISTS trg_quote_lines_validate_company ON public."QuoteLines";
DROP TRIGGER IF EXISTS trg_quotes_set_company ON public."Quotes";
DROP TRIGGER IF EXISTS trg_dircontacts_set_company ON public."DirectoryContacts";
DROP TRIGGER IF EXISTS trg_dircustomers_set_company ON public."DirectoryCustomers";
DROP TRIGGER IF EXISTS trg_directorycustomers_set_company ON public."DirectoryCustomers";
DROP TRIGGER IF EXISTS trg_set_quote_line_company_id ON public."QuoteLines";
DROP TRIGGER IF EXISTS trg_directorycontacts_fill_org_id ON public."DirectoryContacts";

-- ============================================================
-- 6) Funciones nuevas: next_dealer_no, set_dealer_no
-- ============================================================
CREATE OR REPLACE FUNCTION public.next_dealer_no(p_org_id uuid)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_next_no integer;
BEGIN
  UPDATE public."Organizations"
  SET next_dealer_no = next_dealer_no + 1
  WHERE id = p_org_id
  RETURNING next_dealer_no INTO v_next_no;

  IF v_next_no IS NULL THEN
    RAISE EXCEPTION 'Organization % not found', p_org_id;
  END IF;

  RETURN v_next_no::text;
END;
$$;

COMMENT ON FUNCTION public.next_dealer_no(uuid) IS 'Atomically increments Organizations.next_dealer_no. Used by trigger on Dealers insert.';

CREATE OR REPLACE FUNCTION public.set_dealer_no()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.dealer_no IS NULL OR TRIM(NEW.dealer_no) = '' THEN
    NEW.dealer_no := public.next_dealer_no(NEW.organization_id);
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.set_dealer_no() IS 'Trigger: auto-assign dealer_no on Dealers insert.';

-- ============================================================
-- 7) Funciones is_dealer_*
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_dealer_member(p_dealer_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."Dealers" d
    JOIN public."OrganizationUsers" ou ON ou.organization_id = d.organization_id
    WHERE d.id = p_dealer_id
      AND ou.user_id = auth.uid()
      AND ou.deleted = false
      AND ou.status = 'active'
  );
END;
$$;

COMMENT ON FUNCTION public.is_dealer_member(uuid) IS 'Check if current user is member of dealer via organization. SECURITY DEFINER.';

CREATE OR REPLACE FUNCTION public.is_dealer_owner_or_admin(p_dealer_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."Dealers" d
    JOIN public."OrganizationUsers" ou ON ou.organization_id = d.organization_id
    WHERE d.id = p_dealer_id
      AND ou.user_id = auth.uid()
      AND ou.role IN ('superadmin', 'owner', 'admin')
      AND ou.deleted = false
      AND ou.status = 'active'
  );
END;
$$;

COMMENT ON FUNCTION public.is_dealer_owner_or_admin(uuid) IS 'Check if current user is superadmin/owner/admin of dealer. SECURITY DEFINER.';

CREATE OR REPLACE FUNCTION public.is_dealer_portal_user(p_dealer_id uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."DealerUsers" dpu
    WHERE dpu.dealer_id = p_dealer_id
      AND (
        dpu.user_id = auth.uid()
        OR dpu.portal_user_email = (auth.jwt() ->> 'email')
      )
      AND dpu.deleted = false
      AND dpu.status IN ('active', 'invited')
  );
END;
$$;

COMMENT ON FUNCTION public.is_dealer_portal_user(uuid) IS 'True if current user is a DealerUser (portal) for the given dealer.';

CREATE OR REPLACE FUNCTION public.is_dealer_portal_user_with_write(p_dealer_id uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."DealerUsers" dpu
    WHERE dpu.dealer_id = p_dealer_id
      AND (
        dpu.user_id = auth.uid()
        OR lower(dpu.portal_user_email) = lower(auth.jwt() ->> 'email')
      )
      AND dpu.deleted = false
      AND dpu.status IN ('active', 'invited')
      AND dpu.role IN ('member_manager')
  );
END;
$$;

COMMENT ON FUNCTION public.is_dealer_portal_user_with_write(uuid) IS 'True if current user is a DealerUser with write (member_manager) for the given dealer.';

-- ============================================================
-- 8) get_current_portal_user_dealer_id, get_auth_context (dealer_id), get_current_portal_user (dealer_id)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_current_portal_user_dealer_id()
RETURNS uuid
LANGUAGE sql STABLE
AS $$
  SELECT dealer_id
  FROM public."DealerUsers"
  WHERE (user_id = auth.uid() OR portal_user_email = (auth.jwt() ->> 'email'))
    AND deleted = false
    AND status IN ('active', 'invited')
  LIMIT 1;
$$;

COMMENT ON FUNCTION public.get_current_portal_user_dealer_id() IS 'Returns dealer_id for current portal user.';

-- Drop policies que dependen de get_current_portal_user() para poder hacer DROP de la función
DROP POLICY IF EXISTS quotes_portal_select ON public."Quotes";
DROP POLICY IF EXISTS quotes_portal_insert ON public."Quotes";
DROP POLICY IF EXISTS quotes_portal_update ON public."Quotes";

-- Drop first: PostgreSQL no permite cambiar el tipo de retorno con CREATE OR REPLACE
DROP FUNCTION IF EXISTS public.get_current_portal_user();

CREATE OR REPLACE FUNCTION public.get_current_portal_user()
RETURNS TABLE(id uuid, organization_id uuid, dealer_id uuid, portal_user_role text, status text)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN QUERY
  SELECT
    dpu.id,
    dpu.organization_id,
    dpu.dealer_id,
    CASE
      WHEN dpu.role IN ('member_manager', 'manager') THEN 'member_manager'::text
      ELSE 'member'::text
    END AS portal_user_role,
    dpu.status::text AS status
  FROM public."DealerUsers" dpu
  WHERE (
    dpu.user_id = auth.uid()
    OR dpu.portal_user_email = (auth.jwt() ->> 'email')
  )
    AND dpu.deleted = false
    AND dpu.status IN ('active', 'invited')
  LIMIT 1;
END;
$$;

COMMENT ON FUNCTION public.get_current_portal_user() IS 'Get current portal user info. Returns dealer_id.';

-- Drop first: cambia tipo de retorno (company_id → dealer_id)
DROP FUNCTION IF EXISTS public.get_auth_context();

CREATE OR REPLACE FUNCTION public.get_auth_context()
RETURNS TABLE(user_id uuid, is_org_user boolean, is_portal_user boolean, organization_id uuid, dealer_id uuid, needs_password boolean, access_allowed boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_org_user_id uuid;
  v_portal_user_id uuid;
  v_organization_id uuid;
  v_dealer_id uuid;
  v_org_status text;
  v_portal_status text;
  v_org_must_change_password boolean;
  v_portal_must_change_password boolean;
  v_is_org_user boolean := false;
  v_is_portal_user boolean := false;
  v_access_allowed boolean := false;
  v_needs_password boolean := false;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT
      NULL::uuid, false::boolean, false::boolean,
      NULL::uuid, NULL::uuid, false::boolean, false::boolean;
    RETURN;
  END IF;

  SELECT ou.id, ou.organization_id, ou.status, COALESCE(ou.must_change_password, false)
  INTO v_org_user_id, v_organization_id, v_org_status, v_org_must_change_password
  FROM public."OrganizationUsers" ou
  WHERE ou.user_id = v_user_id AND ou.deleted = false AND ou.status IN ('active', 'invited')
  LIMIT 1;

  IF v_org_user_id IS NOT NULL THEN
    v_is_org_user := true;
    v_access_allowed := true;
  END IF;

  IF v_org_user_id IS NULL THEN
    SELECT dpu.id, dpu.dealer_id, dpu.organization_id, dpu.status, COALESCE(dpu.must_change_password, false)
    INTO v_portal_user_id, v_dealer_id, v_organization_id, v_portal_status, v_portal_must_change_password
    FROM public."DealerUsers" dpu
    WHERE dpu.user_id = v_user_id AND dpu.deleted = false AND dpu.status IN ('active', 'invited')
    LIMIT 1;

    IF v_portal_user_id IS NOT NULL THEN
      v_is_portal_user := true;
      v_access_allowed := true;
    END IF;
  ELSE
    SELECT dpu.dealer_id, dpu.status, COALESCE(dpu.must_change_password, false)
    INTO v_dealer_id, v_portal_status, v_portal_must_change_password
    FROM public."DealerUsers" dpu
    WHERE dpu.user_id = v_user_id AND dpu.deleted = false AND dpu.status IN ('active', 'invited')
    LIMIT 1;
  END IF;

  v_needs_password := COALESCE(v_org_must_change_password, false) OR COALESCE(v_portal_must_change_password, false);

  RETURN QUERY SELECT
    v_user_id, v_is_org_user, v_is_portal_user,
    v_organization_id, v_dealer_id, v_needs_password, v_access_allowed;
END;
$$;

COMMENT ON FUNCTION public.get_auth_context() IS 'Auth context for current user. Returns dealer_id (was company_id).';

-- ============================================================
-- 9) Triggers QuoteLines y Quotes (dealer_id)
-- ============================================================
CREATE OR REPLACE FUNCTION public.quote_lines_set_dealer_id()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.dealer_id IS NULL AND NEW.quote_id IS NOT NULL THEN
    SELECT q.dealer_id INTO NEW.dealer_id
    FROM public."Quotes" q
    WHERE q.id = NEW.quote_id AND q.organization_id = NEW.organization_id
    LIMIT 1;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.quote_lines_validate_dealer()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_quote_dealer uuid;
BEGIN
  IF NEW.quote_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT q.dealer_id INTO v_quote_dealer
  FROM public."Quotes" q
  WHERE q.id = NEW.quote_id AND q.organization_id = NEW.organization_id
  LIMIT 1;

  IF v_quote_dealer IS NULL THEN
    RAISE EXCEPTION 'QuoteLines: quote_id % has no dealer_id (or quote not found) for org %', NEW.quote_id, NEW.organization_id;
  END IF;

  IF NEW.dealer_id IS NOT NULL AND NEW.dealer_id <> v_quote_dealer THEN
    RAISE EXCEPTION 'QuoteLines: dealer_id % does not match Quotes.dealer_id % for quote %', NEW.dealer_id, v_quote_dealer, NEW.quote_id;
  END IF;

  IF NEW.dealer_id IS NULL THEN
    NEW.dealer_id := v_quote_dealer;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.tg_set_dealer_id_from_portal_user()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v record;
BEGIN
  IF NEW.dealer_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    SELECT * INTO v FROM public.get_current_portal_user() LIMIT 1;
    IF v.id IS NOT NULL THEN
      NEW.dealer_id := v.dealer_id;
    END IF;
  EXCEPTION WHEN undefined_function THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

-- ============================================================
-- 10) Triggers ManufacturingOrders, OrderList, SalesOrders (dealer_id)
-- ============================================================
CREATE OR REPLACE FUNCTION public.enforce_mo_dealer_matches_salesorder()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_so_dealer uuid;
BEGIN
  IF NEW.sales_order_id IS NULL THEN
    RAISE EXCEPTION 'ManufacturingOrders.sales_order_id is required';
  END IF;

  SELECT so.dealer_id INTO v_so_dealer FROM public."SalesOrders" so WHERE so.id = NEW.sales_order_id;

  IF v_so_dealer IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.dealer_id IS NULL THEN
    NEW.dealer_id := v_so_dealer;
  END IF;

  IF NEW.dealer_id <> v_so_dealer THEN
    RAISE EXCEPTION 'ManufacturingOrders.dealer_id must match SalesOrders.dealer_id';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_orderlist_dealer_matches_salesorder()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_so_dealer uuid;
BEGIN
  IF NEW.sales_order_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT so.dealer_id INTO v_so_dealer FROM public."SalesOrders" so WHERE so.id = NEW.sales_order_id;

  IF v_so_dealer IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.dealer_id IS NULL THEN
    NEW.dealer_id := v_so_dealer;
  END IF;

  IF NEW.dealer_id <> v_so_dealer THEN
    RAISE EXCEPTION 'OrderList.dealer_id must match SalesOrders.dealer_id';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_salesorders_dealer_matches_quote()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_quote_dealer uuid;
BEGIN
  IF NEW.quote_id IS NULL THEN
    RAISE EXCEPTION 'SalesOrders.quote_id is required';
  END IF;

  SELECT q.dealer_id INTO v_quote_dealer FROM public."Quotes" q WHERE q.id = NEW.quote_id;

  IF v_quote_dealer IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.dealer_id IS NULL THEN
    NEW.dealer_id := v_quote_dealer;
  END IF;

  IF NEW.dealer_id <> v_quote_dealer THEN
    RAISE EXCEPTION 'SalesOrders.dealer_id must match Quotes.dealer_id';
  END IF;

  RETURN NEW;
END;
$$;

-- ============================================================
-- 11) directorycontacts_fill_org_id: dealer_id -> Dealers
-- ============================================================
CREATE OR REPLACE FUNCTION public.directorycontacts_fill_org_id()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  IF NEW.organization_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.dealer_id IS NOT NULL THEN
    SELECT d.organization_id INTO NEW.organization_id
    FROM public."Dealers" d
    WHERE d.id = NEW.dealer_id AND d.deleted = false
    LIMIT 1;
  END IF;

  RETURN NEW;
END;
$$;

-- ============================================================
-- 12) Recrear triggers
-- ============================================================
CREATE TRIGGER trg_dealers_set_dealer_no
  BEFORE INSERT ON public."Dealers"
  FOR EACH ROW EXECUTE FUNCTION public.set_dealer_no();

CREATE TRIGGER trg_quote_lines_set_dealer_id
  BEFORE INSERT OR UPDATE OF quote_id, organization_id, dealer_id ON public."QuoteLines"
  FOR EACH ROW EXECUTE FUNCTION public.quote_lines_set_dealer_id();

CREATE TRIGGER trg_quote_lines_validate_dealer
  BEFORE INSERT OR UPDATE OF quote_id, organization_id, dealer_id ON public."QuoteLines"
  FOR EACH ROW EXECUTE FUNCTION public.quote_lines_validate_dealer();

CREATE TRIGGER trg_quotes_set_dealer
  BEFORE INSERT ON public."Quotes"
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_dealer_id_from_portal_user();

CREATE TRIGGER trg_dircontacts_set_dealer
  BEFORE INSERT ON public."DirectoryContacts"
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_dealer_id_from_portal_user();

CREATE TRIGGER trg_directorycustomers_set_dealer
  BEFORE INSERT ON public."DirectoryCustomers"
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_dealer_id_from_portal_user();

CREATE TRIGGER trg_directorycontacts_fill_org_id
  BEFORE INSERT OR UPDATE OF dealer_id, organization_id ON public."DirectoryContacts"
  FOR EACH ROW EXECUTE FUNCTION public.directorycontacts_fill_org_id();

-- ManufacturingOrders / OrderList / SalesOrders: reemplazar triggers existentes
DROP TRIGGER IF EXISTS trg_mo_company_match ON public."ManufacturingOrders";
DROP TRIGGER IF EXISTS trg_mo_company_match_so ON public."ManufacturingOrders";
CREATE TRIGGER enforce_mo_dealer_matches_salesorder
  BEFORE INSERT OR UPDATE ON public."ManufacturingOrders"
  FOR EACH ROW EXECUTE FUNCTION public.enforce_mo_dealer_matches_salesorder();

DROP TRIGGER IF EXISTS trg_orderlist_company_match_so ON public."OrderList";
CREATE TRIGGER enforce_orderlist_dealer_matches_salesorder
  BEFORE INSERT OR UPDATE ON public."OrderList"
  FOR EACH ROW EXECUTE FUNCTION public.enforce_orderlist_dealer_matches_salesorder();

DROP TRIGGER IF EXISTS trg_salesorders_company_match_quote ON public."SalesOrders";
CREATE TRIGGER enforce_salesorders_dealer_matches_quote
  BEFORE INSERT OR UPDATE ON public."SalesOrders"
  FOR EACH ROW EXECUTE FUNCTION public.enforce_salesorders_dealer_matches_quote();

-- ============================================================
-- 13) RLS: drop policies antiguas (nombres companies / companyportalusers)
-- ============================================================
DROP POLICY IF EXISTS companies_select_own_org ON public."Dealers";
DROP POLICY IF EXISTS companies_insert_own_org ON public."Dealers";
DROP POLICY IF EXISTS companies_update_own_org ON public."Dealers";

DROP POLICY IF EXISTS companyportalusers_select_own_org ON public."DealerUsers";
DROP POLICY IF EXISTS companyportalusers_insert_own_org ON public."DealerUsers";
DROP POLICY IF EXISTS companyportalusers_update_own_org ON public."DealerUsers";
DROP POLICY IF EXISTS companyportalusers_select_stable ON public."DealerUsers";
DROP POLICY IF EXISTS companyportalusers_update_self ON public."DealerUsers";
DROP POLICY IF EXISTS companyportalusers_select_customer ON public."DealerUsers";
DROP POLICY IF EXISTS portalusers_select ON public."DealerUsers";
DROP POLICY IF EXISTS portalusers_update ON public."DealerUsers";
DROP POLICY IF EXISTS portal_users_write_owner_admin ON public."DealerUsers";

-- Drop policies que usan company_id o is_company_* (column/función ya no existen tras el rename)
DROP POLICY IF EXISTS dircontacts_select_correct ON public."DirectoryContacts";
DROP POLICY IF EXISTS dircontacts_write_correct ON public."DirectoryContacts";
DROP POLICY IF EXISTS dircustomers_select_correct ON public."DirectoryCustomers";
DROP POLICY IF EXISTS dircustomers_write_correct ON public."DirectoryCustomers";
DROP POLICY IF EXISTS quotes_portal_select ON public."Quotes";
DROP POLICY IF EXISTS quotes_portal_insert ON public."Quotes";
DROP POLICY IF EXISTS quotes_portal_update ON public."Quotes";
DROP POLICY IF EXISTS portal_select_contacts ON public."DirectoryContacts";
DROP POLICY IF EXISTS portal_select_customers ON public."DirectoryCustomers";

-- ============================================================
-- 14) RLS: crear policies Dealers y DealerUsers
-- ============================================================
CREATE POLICY dealers_select_own_org
  ON public."Dealers" FOR SELECT
  USING (public.is_org_member(organization_id) AND deleted = false);

CREATE POLICY dealers_insert_own_org
  ON public."Dealers" FOR INSERT
  WITH CHECK (public.is_org_owner_or_admin(organization_id));

CREATE POLICY dealers_update_own_org
  ON public."Dealers" FOR UPDATE
  USING (public.is_org_owner_or_admin(organization_id))
  WITH CHECK (public.is_org_owner_or_admin(organization_id));

CREATE POLICY dealerusers_select_stable
  ON public."DealerUsers" FOR SELECT
  USING (
    (dealer_id IS NOT NULL AND public.is_dealer_member(dealer_id))
    OR (user_id = auth.uid() AND deleted = false)
  );

CREATE POLICY dealerusers_insert_own_org
  ON public."DealerUsers" FOR INSERT
  WITH CHECK (public.is_dealer_owner_or_admin(dealer_id));

CREATE POLICY dealerusers_update_self
  ON public."DealerUsers" FOR UPDATE
  USING (
    (dealer_id IS NOT NULL AND public.is_dealer_member(dealer_id))
    OR (user_id = auth.uid() AND deleted = false)
  )
  WITH CHECK (
    (dealer_id IS NOT NULL AND public.is_dealer_member(dealer_id))
    OR (user_id = auth.uid() AND deleted = false)
  );

-- ============================================================
-- 15) RLS Quotes (debe usar dealer_id e is_dealer_portal_user)
-- ============================================================
-- Dropear policies de Quotes que referencian company
DROP POLICY IF EXISTS quotes_select_org_or_portal ON public."Quotes";
DROP POLICY IF EXISTS quotes_insert_org_or_portal ON public."Quotes";
DROP POLICY IF EXISTS quotes_update_org_or_portal ON public."Quotes";
DROP POLICY IF EXISTS quotes_portal_select ON public."Quotes";

-- Recrear según lógica existente: org users ven por org; portal users por dealer_id
CREATE POLICY quotes_select_org_or_portal
  ON public."Quotes" FOR SELECT
  USING (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR (dealer_id IS NOT NULL AND public.is_dealer_portal_user(dealer_id))
  );

CREATE POLICY quotes_insert_org_or_portal
  ON public."Quotes" FOR INSERT
  WITH CHECK (
    (organization_id IS NOT NULL AND public.is_org_owner_or_admin(organization_id))
    OR (dealer_id IS NOT NULL AND public.is_dealer_portal_user_with_write(dealer_id))
  );

CREATE POLICY quotes_update_org_or_portal
  ON public."Quotes" FOR UPDATE
  USING (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR (dealer_id IS NOT NULL AND public.is_dealer_portal_user(dealer_id))
  )
  WITH CHECK (
    (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    OR (dealer_id IS NOT NULL AND public.is_dealer_portal_user(dealer_id))
  );

-- ============================================================
-- 16) Directory RLS (dealer_id, is_dealer_member)
-- ============================================================
DROP POLICY IF EXISTS dircustomers_select_own_org_or_company ON public."DirectoryCustomers";
CREATE POLICY dircustomers_select_own_org_or_dealer
  ON public."DirectoryCustomers" FOR SELECT
  USING (
    (
      (dealer_id IS NOT NULL AND public.is_dealer_member(dealer_id))
      OR (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    )
    AND deleted = false
  );

DROP POLICY IF EXISTS dircontacts_select_own_org_or_company ON public."DirectoryContacts";
CREATE POLICY dircontacts_select_own_org_or_dealer
  ON public."DirectoryContacts" FOR SELECT
  USING (
    (
      (dealer_id IS NOT NULL AND public.is_dealer_member(dealer_id))
      OR (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    )
    AND deleted = false
  );

-- ============================================================
-- 17) link_my_invites, link_my_org_invites, handle_auth_user_created: DealerUsers
-- ============================================================
CREATE OR REPLACE FUNCTION public.link_my_invites()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_email text;
  v_org_updated int := 0;
  v_portal_updated int := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_email := lower(coalesce(auth.jwt() ->> 'email', ''));

  IF v_email = '' THEN
    RAISE EXCEPTION 'Missing email in auth context';
  END IF;

  UPDATE public."OrganizationUsers"
  SET user_id = v_uid,
      status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
      updated_at = now()
  WHERE lower(user_email) = v_email AND (user_id IS NULL OR user_id = v_uid);
  GET DIAGNOSTICS v_org_updated = ROW_COUNT;

  UPDATE public."DealerUsers"
  SET user_id = v_uid,
      status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
      updated_at = now()
  WHERE lower(portal_user_email) = v_email AND (user_id IS NULL OR user_id = v_uid);
  GET DIAGNOSTICS v_portal_updated = ROW_COUNT;

  RETURN jsonb_build_object('ok', true, 'org_updated', v_org_updated, 'portal_updated', v_portal_updated);
END;
$$;

CREATE OR REPLACE FUNCTION public.link_my_org_invites()
RETURNS TABLE(linked_count integer, updated_ids uuid[])
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_user_email text;
  v_linked_count integer := 0;
  v_portal_linked_count integer := 0;
  v_updated_ids uuid[];
  v_portal_updated_ids uuid[];
BEGIN
  v_user_id := auth.uid();
  v_user_email := coalesce(auth.jwt() ->> 'email', '');

  IF v_user_id IS NULL OR btrim(v_user_email) = '' THEN
    RETURN QUERY SELECT 0, ARRAY[]::uuid[];
    RETURN;
  END IF;

  WITH updated AS (
    UPDATE public."OrganizationUsers"
    SET user_id = v_user_id,
        status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
        accepted_at = COALESCE(accepted_at, now()),
        updated_at = now()
    WHERE lower(user_email) = lower(v_user_email) AND user_id IS NULL AND deleted = false
    RETURNING id
  )
  SELECT COUNT(*)::integer, ARRAY_AGG(id)::uuid[] INTO v_linked_count, v_updated_ids FROM updated;

  WITH updated_portal AS (
    UPDATE public."DealerUsers"
    SET user_id = v_user_id,
        status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
        accepted_at = COALESCE(accepted_at, now()),
        updated_at = now()
    WHERE lower(portal_user_email) = lower(v_user_email) AND user_id IS NULL AND deleted = false
    RETURNING id
  )
  SELECT COUNT(*)::integer, ARRAY_AGG(id)::uuid[] INTO v_portal_linked_count, v_portal_updated_ids FROM updated_portal;

  RETURN QUERY
  SELECT (v_linked_count + v_portal_linked_count)::integer,
         (COALESCE(v_updated_ids, ARRAY[]::uuid[]) || COALESCE(v_portal_updated_ids, ARRAY[]::uuid[]))::uuid[];
END;
$$;

COMMENT ON FUNCTION public.link_my_org_invites() IS 'Links OrganizationUsers and DealerUsers invites by email.';

-- handle_auth_user_created (trigger en auth.users)
CREATE OR REPLACE FUNCTION public.handle_auth_user_created_for_portal_users()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public."DealerUsers"
  SET user_id = NEW.id,
      status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
      accepted_at = COALESCE(accepted_at, now()),
      updated_at = now()
  WHERE lower(portal_user_email) = lower(NEW.email)
    AND user_id IS NULL
    AND deleted = false;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_auth_user_created_for_portal_users() IS 'Auto-link DealerUsers invites when auth.users is created.';

-- ============================================================
-- 18) delete_dealer_user (reemplaza delete_company_portal_user)
-- ============================================================
CREATE OR REPLACE FUNCTION public.delete_dealer_user(
  p_portal_user_id uuid,
  p_organization_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted_count int;
BEGIN
  UPDATE public."DealerUsers"
  SET deleted = true,
      status = 'disabled',
      updated_at = now()
  WHERE id = p_portal_user_id
    AND organization_id = p_organization_id
    AND deleted = false;

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  IF v_deleted_count = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Portal user not found or already deleted');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

COMMENT ON FUNCTION public.delete_dealer_user(uuid, uuid) IS 'Soft delete a dealer portal user. Replaces delete_company_portal_user.';

GRANT EXECUTE ON FUNCTION public.delete_dealer_user(uuid, uuid) TO authenticated;

-- ============================================================
-- 19) approve_quote_portal: dealer_id
-- ============================================================
CREATE OR REPLACE FUNCTION public.approve_quote_portal(p_quote_id uuid, p_action text)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_portal_user record;
  v_quote record;
  v_new_status public.quote_status;
  v_result json;
BEGIN
  SELECT * INTO v_portal_user FROM public.get_current_portal_user() LIMIT 1;

  IF v_portal_user.id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated as active portal user';
  END IF;

  IF v_portal_user.portal_user_role != 'member_manager' THEN
    RAISE EXCEPTION 'Only member managers can approve/reject quotes';
  END IF;

  SELECT * INTO v_quote
  FROM public."Quotes"
  WHERE id = p_quote_id AND deleted = false;

  IF v_quote.id IS NULL THEN
    RAISE EXCEPTION 'Quote not found';
  END IF;

  IF v_quote.dealer_id != v_portal_user.dealer_id THEN
    RAISE EXCEPTION 'Quote does not belong to your dealer';
  END IF;

  IF p_action NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Invalid action. Must be "approve" or "reject"';
  END IF;

  IF v_quote.status NOT IN ('draft', 'sent', 'pending_approval') THEN
    RAISE EXCEPTION 'Quote status (%) does not allow approval/rejection. Must be draft, sent, or pending_approval', v_quote.status;
  END IF;

  IF p_action = 'approve' THEN
    v_new_status := 'approved';
  ELSE
    v_new_status := 'rejected';
  END IF;

  UPDATE public."Quotes"
  SET status = v_new_status, updated_at = now()
  WHERE id = p_quote_id AND deleted = false;

  SELECT json_build_object('success', true, 'status', v_new_status) INTO v_result;
  RETURN v_result;
END;
$$;

-- approve_quote (legacy): usar DealerUsers y status
CREATE OR REPLACE FUNCTION public.approve_quote(p_quote_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_dealer_id uuid;
  v_role text;
BEGIN
  SELECT dpu.dealer_id, dpu.role INTO v_dealer_id, v_role
  FROM public."DealerUsers" dpu
  WHERE dpu.user_id = auth.uid()
    AND dpu.deleted = false
    AND dpu.status = 'active'
  LIMIT 1;

  IF v_dealer_id IS NULL THEN
    RAISE EXCEPTION 'Not a portal user';
  END IF;

  IF v_role <> 'member_manager' THEN
    RAISE EXCEPTION 'Forbidden: only member_manager can approve quotes';
  END IF;

  UPDATE public."Quotes"
  SET status = 'approved', updated_at = now()
  WHERE id = p_quote_id AND deleted = false AND dealer_id = v_dealer_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quote not found for your dealer';
  END IF;
END;
$$;

-- ============================================================
-- 20) commit_configured_product_to_quote_line: p_dealer_id
-- ============================================================
DROP FUNCTION IF EXISTS public.commit_configured_product_to_quote_line(uuid, uuid, uuid, uuid, text, text, text, text, text);
DROP FUNCTION IF EXISTS public.commit_configured_product_to_quote_line(uuid, uuid, uuid, uuid, text, text);

CREATE OR REPLACE FUNCTION public.commit_configured_product_to_quote_line(
  p_org_id uuid,
  p_quote_id uuid,
  p_configured_product_id uuid,
  p_dealer_id uuid DEFAULT NULL,
  p_position text DEFAULT NULL,
  p_area text DEFAULT NULL,
  p_fabric_drop text DEFAULT NULL,
  p_installation_type text DEFAULT NULL,
  p_installation_location text DEFAULT NULL
)
RETURNS TABLE(quote_line_id uuid, bom_instance_id uuid)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cp RECORD;
  v_quote_line_id uuid;
  v_bom_instance_id uuid;
  v_width_m numeric(12,4);
  v_height_m numeric(12,4);
  v_roll_item RECORD;
  v_operating_type text;
  v_fabric_drop text;
  v_installation_type text;
  v_installation_location text;
  v_roll_msrp_total numeric(12,4);
  v_bom_total numeric(12,4);
  v_total_msrp numeric(12,4);
  v_unit_msrp numeric(12,4);
  v_roll_total_cost numeric(12,4);
  v_bom_total_cost numeric(12,4);
  v_labor_amount numeric(12,4);
  v_accessories_total numeric(12,4);
  v_snapshot jsonb;
  v_snapshot_totals jsonb;
  v_recalc jsonb;
BEGIN
  IF p_org_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_org_id is required'; END IF;
  IF p_quote_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_quote_id is required'; END IF;
  IF p_configured_product_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_configured_product_id is required'; END IF;

  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id AND organization_id = p_org_id AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found or does not belong to org %', p_configured_product_id, p_org_id;
  END IF;
  IF v_cp.bom_template_id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % has no bom_template_id', p_configured_product_id;
  END IF;

  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_snapshot_totals := v_snapshot->'totals';
  v_roll_msrp_total := 0; v_bom_total := 0; v_roll_total_cost := 0; v_bom_total_cost := 0;
  v_labor_amount := 0; v_accessories_total := 0; v_total_msrp := 0;

  IF v_snapshot->>'version' = '1' AND jsonb_array_length(v_snapshot->'items') > 0 THEN
    SELECT COALESCE(SUM((item->>'line_total')::numeric), 0) INTO v_roll_msrp_total
    FROM jsonb_array_elements(v_snapshot->'items') AS item WHERE item->>'kind' = 'roll';
    SELECT COALESCE(SUM(
      (item->>'line_total')::numeric + COALESCE((SELECT SUM((c->>'line_total')::numeric) FROM jsonb_array_elements(COALESCE(item->'children', '[]'::jsonb)) c), 0)
    ), 0) INTO v_bom_total
    FROM jsonb_array_elements(v_snapshot->'items') AS item WHERE item->>'kind' = 'parent';
    v_labor_amount := COALESCE((v_snapshot_totals->>'labor_amount')::numeric, 0);
    v_accessories_total := COALESCE((v_snapshot_totals->>'accessories_total')::numeric, 0);
    v_roll_total_cost := COALESCE((v_snapshot_totals->>'roll_total_cost')::numeric, 0);
    v_bom_total_cost := COALESCE((v_snapshot_totals->>'bom_total_cost')::numeric, 0);
  ELSIF v_snapshot->>'version' = '1' AND v_snapshot_totals IS NOT NULL THEN
    v_roll_msrp_total := COALESCE((v_snapshot_totals->>'roll_msrp_total')::numeric, 0);
    v_bom_total := COALESCE((v_snapshot_totals->>'bom_total')::numeric, 0);
    v_roll_total_cost := COALESCE((v_snapshot_totals->>'roll_total_cost')::numeric, 0);
    v_bom_total_cost := COALESCE((v_snapshot_totals->>'bom_total_cost')::numeric, 0);
    v_labor_amount := COALESCE((v_snapshot_totals->>'labor_amount')::numeric, 0);
    v_accessories_total := COALESCE((v_snapshot_totals->>'accessories_total')::numeric, 0);
    v_total_msrp := COALESCE((v_snapshot_totals->>'total_msrp')::numeric, 0);
  ELSE
    v_roll_msrp_total := COALESCE(v_cp.roll_msrp_total, 0);
    v_bom_total := COALESCE(v_cp.bom_total, 0);
    v_roll_total_cost := COALESCE(v_cp.roll_total_cost, 0);
    v_bom_total_cost := COALESCE(v_cp.bom_total_cost, 0);
    v_labor_amount := COALESCE(v_cp.labor_amount, 0);
    v_accessories_total := COALESCE(v_cp.accessories_total, 0);
    v_total_msrp := COALESCE(v_cp.total_msrp, 0);
  END IF;

  v_total_msrp := v_roll_msrp_total + v_bom_total + v_labor_amount + v_accessories_total;

  IF (v_total_msrp IS NULL OR v_total_msrp = 0) THEN
    BEGIN
      v_recalc := public.calculate_configured_product_totals(p_configured_product_id);
      IF v_recalc IS NOT NULL AND NOT (v_recalc ? 'error') THEN
        v_roll_msrp_total := COALESCE((v_recalc->>'roll_msrp_total')::numeric, 0);
        v_bom_total := COALESCE((v_recalc->>'bom_total')::numeric, 0);
        v_roll_total_cost := COALESCE((v_recalc->>'roll_total_cost')::numeric, 0);
        v_bom_total_cost := COALESCE((v_recalc->>'bom_total_cost')::numeric, 0);
        v_labor_amount := COALESCE((v_recalc->>'labor_amount')::numeric, 0);
        v_accessories_total := COALESCE((v_recalc->>'accessories_total')::numeric, 0);
        v_total_msrp := COALESCE((v_recalc->>'total_msrp')::numeric, 0);
        IF v_total_msrp = 0 THEN v_total_msrp := v_roll_msrp_total + v_bom_total + v_labor_amount + v_accessories_total; END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;

  v_unit_msrp := v_total_msrp / NULLIF(COALESCE(v_cp.quantity, 1), 0);

  v_width_m := COALESCE(v_cp.width_mm / 1000.0, 0);
  v_height_m := COALESCE(v_cp.height_mm / 1000.0, 0);
  v_operating_type := COALESCE(
    v_cp.config_snapshot->>'operating_type',
    v_cp.config_snapshot->>'drive_type',
    v_cp.config_snapshot->>'operation_type'
  );
  IF v_operating_type IS NOT NULL THEN
    v_operating_type := lower(trim(v_operating_type));
    IF v_operating_type IN ('motorized', 'motorised') THEN v_operating_type := 'motor'; END IF;
  END IF;

  v_fabric_drop := COALESCE(p_fabric_drop, v_cp.config_snapshot->>'fabricDrop', v_cp.config_snapshot->>'drop_type');
  v_installation_type := COALESCE(p_installation_type, v_cp.config_snapshot->>'installationType');
  v_installation_location := COALESCE(p_installation_location, v_cp.config_snapshot->>'installationLocation');

  SELECT ci.sku, ci.name, ci.category_id, ci.manufacturer_id, m.name as manufacturer_name,
         ci.collection_name, ci.variant_name, COALESCE(ci.roll_width_m, ci.roll_width) as roll_width_m
  INTO v_roll_item
  FROM public."CatalogItems" ci
  LEFT JOIN public."Manufacturers" m ON m.id = ci.manufacturer_id
  WHERE ci.id = v_cp.roll_catalog_item_id AND ci.is_active = true LIMIT 1;

  INSERT INTO public."QuoteLines" (
    organization_id, dealer_id, quote_id,
    product_type_id, configured_product_id, bom_template_id,
    catalog_item_id, sku, name, category_id, manufacturer_id, manufacturer, collection_name, variant_name, is_roll, roll_type, roll_width_m,
    width_m, height_m, quantity,
    hardware_color, drive_type,
    position, area,
    fabric_drop, installation_type, installation_location,
    roll_msrp_snapshot, bom_msrp_snapshot, roll_cost_snapshot, bom_cost_snapshot, unit_msrp, msrp, total_cost,
    pricing_locked, last_priced_at, pricing_version
  )
  VALUES (
    p_org_id, COALESCE(p_dealer_id, (SELECT dealer_id FROM public."Quotes" WHERE id = p_quote_id LIMIT 1)), p_quote_id,
    v_cp.product_type_id, v_cp.id, v_cp.bom_template_id,
    v_cp.roll_catalog_item_id, COALESCE(v_cp.roll_sku, v_roll_item.sku), v_roll_item.name, v_roll_item.category_id, v_roll_item.manufacturer_id, v_roll_item.manufacturer_name,
    COALESCE(v_cp.roll_collection_name, v_roll_item.collection_name), COALESCE(v_cp.roll_variant_name, v_roll_item.variant_name),
    v_cp.roll_catalog_item_id IS NOT NULL, CASE WHEN v_cp.roll_catalog_item_id IS NOT NULL THEN 'fabric' ELSE NULL END, COALESCE(v_cp.roll_width, v_roll_item.roll_width_m),
    v_width_m, v_height_m, COALESCE(v_cp.quantity, 1),
    v_cp.hardware_color, v_operating_type,
    p_position, p_area,
    v_fabric_drop, v_installation_type, v_installation_location,
    v_roll_msrp_total, v_bom_total, v_roll_total_cost, v_bom_total_cost, v_unit_msrp, v_total_msrp, v_roll_total_cost + v_bom_total_cost + v_labor_amount,
    true, now(), 1
  )
  RETURNING id INTO v_quote_line_id;

  IF v_quote_line_id IS NULL THEN RAISE EXCEPTION 'Failed to insert QuoteLine for ConfiguredProduct %', p_configured_product_id; END IF;
  v_bom_instance_id := NULL;
  RETURN QUERY SELECT v_quote_line_id, v_bom_instance_id;
END;
$$;

COMMENT ON FUNCTION public.commit_configured_product_to_quote_line(uuid, uuid, uuid, uuid, text, text, text, text, text) IS 'Creates QuoteLine from ConfiguredProduct. Uses p_dealer_id.';

-- ============================================================
-- 21) is_portal_user_self: DealerUsers
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_portal_user_self(p_portal_row_id uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid;
  v_jwt_email text;
  v_row_user_id uuid;
  v_row_email text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN false;
  END IF;

  SELECT dpu.user_id, dpu.portal_user_email INTO v_row_user_id, v_row_email
  FROM public."DealerUsers" dpu
  WHERE dpu.id = p_portal_row_id AND dpu.deleted = false
  LIMIT 1;

  IF v_row_user_id IS NULL AND v_row_email IS NULL THEN
    RETURN false;
  END IF;

  IF v_row_user_id IS NOT NULL AND v_row_user_id = v_uid THEN
    RETURN true;
  END IF;

  v_jwt_email := NULLIF(lower(trim(auth.jwt() ->> 'email')), '');
  IF v_jwt_email IS NOT NULL AND v_row_email IS NOT NULL AND lower(trim(v_row_email)) = v_jwt_email THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

-- ============================================================
-- 22) Dropear funciones antiguas
-- ============================================================
DROP FUNCTION IF EXISTS public.next_company_no(uuid);
DROP FUNCTION IF EXISTS public.set_company_no();
DROP FUNCTION IF EXISTS public.is_company_member(uuid);
DROP FUNCTION IF EXISTS public.is_company_owner_or_admin(uuid);
DROP FUNCTION IF EXISTS public.is_company_portal_user(uuid);
DROP FUNCTION IF EXISTS public.is_company_portal_user_with_write(uuid);
DROP FUNCTION IF EXISTS public.get_current_portal_user_company_id();
DROP FUNCTION IF EXISTS public.quote_lines_set_company_id();
DROP FUNCTION IF EXISTS public.quote_lines_validate_company();
DROP FUNCTION IF EXISTS public.tg_set_company_id_from_portal_user();
DROP FUNCTION IF EXISTS public.enforce_mo_company_matches_salesorder();
DROP FUNCTION IF EXISTS public.enforce_orderlist_company_matches_salesorder();
DROP FUNCTION IF EXISTS public.enforce_salesorders_company_matches_quote();
DROP FUNCTION IF EXISTS public.delete_company_portal_user(uuid, uuid);
DROP FUNCTION IF EXISTS public.can_read_company_portal_user(uuid);

COMMIT;
