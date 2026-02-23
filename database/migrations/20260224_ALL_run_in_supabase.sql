-- === database/migrations/20260224_001_create_appusers_if_not_exists.sql ===
-- ============================================================
-- PASO 1: Migración base para AppUsers (si no existe)
-- ============================================================
-- Objetivo: Garantizar DDL declarativo de AppUsers con constraints
-- correctos. Idempotente: CREATE TABLE IF NOT EXISTS, índices IF NOT EXISTS.
-- Referencia: plan Estabilización Dealers Acting-As RLS.
-- ============================================================

-- AppUserPreferences y 20260223 referencian AppUsers(id); Dealers se asume existente.
-- Si la tabla ya existe (creada fuera del repo), esta migración no la sobrescribe.

CREATE TABLE IF NOT EXISTS public."AppUsers" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE CASCADE,
  user_type text NOT NULL CHECK (user_type IN ('org', 'dealer')),
  dealer_id uuid REFERENCES public."Dealers"(id) ON DELETE SET NULL,
  auth_user_id uuid NOT NULL,
  email text,
  display_name text,
  role_code text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  must_change_password boolean DEFAULT false,
  deleted boolean NOT NULL DEFAULT false,
  invited_by_app_user_id uuid REFERENCES public."AppUsers"(id) ON DELETE SET NULL,
  temp_password_set_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_appusers_org_dealer
    CHECK (
      (user_type = 'org' AND dealer_id IS NULL)
      OR (user_type = 'dealer' AND dealer_id IS NOT NULL)
    )
);

COMMENT ON TABLE public."AppUsers" IS 'Unified app user view (org vs dealer). Single source for current_dealer_id() and RLS.';

-- Unicidad: una fila por (auth_user_id, user_type, dealer_id) con dealer_id NULL para org.
-- Usamos índice único sobre expresión para permitir ON CONFLICT en triggers (PASO 3).
CREATE UNIQUE INDEX IF NOT EXISTS idx_appusers_auth_user_type_dealer_unique
  ON public."AppUsers" (
    auth_user_id,
    user_type,
    COALESCE(dealer_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_appusers_auth_user_type
  ON public."AppUsers"(auth_user_id, user_type)
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_appusers_organization_id
  ON public."AppUsers"(organization_id)
  WHERE deleted = false;

-- Trigger updated_at (reutilizar función existente)
-- Primero asegurar que la función existe; luego el trigger (evita $$ anidados)
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $fn$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END $fn$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_appusers_updated_at') THEN
    CREATE TRIGGER trg_appusers_updated_at
      BEFORE UPDATE ON public."AppUsers"
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- Validación: tabla existe y se puede consultar
-- SELECT count(*) FROM public."AppUsers";

-- === database/migrations/20260224_002_integrity_constraints_org_dealer_users.sql ===
-- ============================================================
-- PASO 2: Constraints de integridad en OrganizationUsers y DealerUsers
-- ============================================================
-- Objetivo: Impedir status = 'active' sin user_id (evita RLS silencioso con 0 filas).
-- Idempotente: UPDATE correctivo primero; ADD CONSTRAINT con IF NOT EXISTS no existe en PG,
--   usamos DO block para agregar solo si no existe.
-- ============================================================

-- ---------- OrganizationUsers ----------
-- Fix previo: filas activas sin user_id pasan a 'invited'
UPDATE public."OrganizationUsers"
SET status = 'invited', updated_at = now()
WHERE status = 'active' AND user_id IS NULL AND deleted = false;

ALTER TABLE public."OrganizationUsers"
  DROP CONSTRAINT IF EXISTS chk_orguser_active_has_userid;

ALTER TABLE public."OrganizationUsers"
  ADD CONSTRAINT chk_orguser_active_has_userid
  CHECK (status <> 'active' OR user_id IS NOT NULL);

COMMENT ON CONSTRAINT chk_orguser_active_has_userid ON public."OrganizationUsers" IS
  'Active rows must have user_id set (invited rows may have NULL until they accept).';

-- ---------- DealerUsers ----------
UPDATE public."DealerUsers"
SET status = 'invited', updated_at = now()
WHERE status = 'active' AND user_id IS NULL AND (deleted IS NULL OR deleted = false);

ALTER TABLE public."DealerUsers"
  DROP CONSTRAINT IF EXISTS chk_dealeruser_active_has_userid;

ALTER TABLE public."DealerUsers"
  ADD CONSTRAINT chk_dealeruser_active_has_userid
  CHECK (status <> 'active' OR user_id IS NOT NULL);

COMMENT ON CONSTRAINT chk_dealeruser_active_has_userid ON public."DealerUsers" IS
  'Active portal users must have user_id set.';

-- Validación manual: INSERT con status='active' y user_id NULL debe fallar en ambas tablas.

-- === database/migrations/20260224_003_sync_triggers_appusers.sql ===
-- ============================================================
-- PASO 3: Triggers de sincronización AppUsers
-- ============================================================
-- Objetivo: INSERT/UPDATE en OrganizationUsers o DealerUsers crea/actualiza
-- la fila correspondiente en AppUsers. Elimina dependencia exclusiva de Edge Function.
-- Requiere: PASO 1 (AppUsers + idx_appusers_auth_user_type_dealer_unique).
-- ============================================================

-- ---------- OrganizationUsers -> AppUsers ----------
CREATE OR REPLACE FUNCTION public.sync_org_user_to_appuser()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Soft delete: marcar AppUser como deleted
  IF NEW.deleted = true AND (OLD.deleted = false OR OLD.deleted IS NULL) THEN
    UPDATE public."AppUsers"
    SET deleted = true, updated_at = now()
    WHERE auth_user_id = OLD.user_id
      AND user_type = 'org'
      AND organization_id = OLD.organization_id
      AND deleted = false;
    RETURN NEW;
  END IF;

  -- Solo sincronizar si tiene user_id y no está deleted
  IF NEW.user_id IS NULL OR NEW.deleted = true THEN
    RETURN NEW;
  END IF;

  INSERT INTO public."AppUsers" (
    organization_id, user_type, dealer_id, auth_user_id, email, display_name,
    role_code, status, must_change_password, deleted, created_at, updated_at,
    temp_password_set_at
  )
  VALUES (
    NEW.organization_id,
    'org',
    NULL,
    NEW.user_id,
    NEW.user_email,
    NEW.user_name,
    COALESCE(NEW.role::text, 'member'),
    COALESCE(NEW.status, 'active'),
    COALESCE(NEW.must_change_password, false),
    false,
    COALESCE(NEW.created_at, now()),
    COALESCE(NEW.updated_at, now()),
    NEW.temp_password_set_at
  )
  ON CONFLICT (auth_user_id, user_type, COALESCE(dealer_id, '00000000-0000-0000-0000-000000000000'::uuid))
  DO UPDATE SET
    email = EXCLUDED.email,
    display_name = EXCLUDED.display_name,
    role_code = EXCLUDED.role_code,
    status = EXCLUDED.status,
    must_change_password = EXCLUDED.must_change_password,
    temp_password_set_at = EXCLUDED.temp_password_set_at,
    updated_at = now();

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.sync_org_user_to_appuser() IS
  'Trigger: sync OrganizationUsers -> AppUsers (org row). Upsert by (auth_user_id, user_type, dealer_id).';

DROP TRIGGER IF EXISTS trg_sync_orguser_appuser ON public."OrganizationUsers";
CREATE TRIGGER trg_sync_orguser_appuser
  AFTER INSERT OR UPDATE ON public."OrganizationUsers"
  FOR EACH ROW EXECUTE FUNCTION public.sync_org_user_to_appuser();

-- ---------- DealerUsers -> AppUsers ----------
CREATE OR REPLACE FUNCTION public.sync_dealer_user_to_appuser()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.deleted = true AND (OLD.deleted = false OR OLD.deleted IS NULL) AND OLD.user_id IS NOT NULL THEN
    UPDATE public."AppUsers"
    SET deleted = true, updated_at = now()
    WHERE auth_user_id = OLD.user_id
      AND user_type = 'dealer'
      AND dealer_id = OLD.dealer_id
      AND deleted = false;
    RETURN NEW;
  END IF;

  IF NEW.user_id IS NULL OR (NEW.deleted = true) THEN
    RETURN NEW;
  END IF;

  INSERT INTO public."AppUsers" (
    organization_id, user_type, dealer_id, auth_user_id, email, display_name,
    role_code, status, must_change_password, deleted, created_at, updated_at,
    temp_password_set_at
  )
  VALUES (
    NEW.organization_id,
    'dealer',
    NEW.dealer_id,
    NEW.user_id,
    NEW.portal_user_email,
    NEW.portal_user_name,
    COALESCE(NEW.role::text, 'dealer_member'),
    COALESCE(NEW.status, 'active'),
    COALESCE(NEW.must_change_password, false),
    COALESCE(NEW.deleted, false),
    COALESCE(NEW.created_at, now()),
    COALESCE(NEW.updated_at, now()),
    NEW.temp_password_set_at
  )
  ON CONFLICT (auth_user_id, user_type, COALESCE(dealer_id, '00000000-0000-0000-0000-000000000000'::uuid))
  DO UPDATE SET
    email = EXCLUDED.email,
    display_name = EXCLUDED.display_name,
    role_code = EXCLUDED.role_code,
    status = EXCLUDED.status,
    must_change_password = EXCLUDED.must_change_password,
    deleted = EXCLUDED.deleted,
    temp_password_set_at = EXCLUDED.temp_password_set_at,
    updated_at = now();

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.sync_dealer_user_to_appuser() IS
  'Trigger: sync DealerUsers -> AppUsers (dealer row). Upsert by (auth_user_id, user_type, dealer_id).';

DROP TRIGGER IF EXISTS trg_sync_dealeruser_appuser ON public."DealerUsers";
CREATE TRIGGER trg_sync_dealeruser_appuser
  AFTER INSERT OR UPDATE ON public."DealerUsers"
  FOR EACH ROW EXECUTE FUNCTION public.sync_dealer_user_to_appuser();

-- === database/migrations/20260224_006_fix_orphan_data.sql ===
-- ============================================================
-- PASO 6: Fix de datos huérfanos
-- ============================================================
-- Ejecutar después de PASO 2 y 3, antes de PASO 4 y 5.
-- 6a/6b: Ya cubiertos por PASO 2 (UPDATE active→invited cuando user_id NULL).
-- 6c: AppUsers sin correspondencia en OrganizationUsers ni DealerUsers → deleted = true.
-- 6d: AppUserPreferences con active_dealer_id a dealer inexistente o deleted → NULL.
-- 6e: Solo diagnóstico (SELECT) para Quotes/Proposals/Directory con dealer_id huérfano.
-- ============================================================

-- ---------- 6a/6b (idempotente, por si se ejecuta en otro orden) ----------
UPDATE public."OrganizationUsers"
SET status = 'invited', updated_at = now()
WHERE status = 'active' AND user_id IS NULL AND deleted = false;

UPDATE public."DealerUsers"
SET status = 'invited', updated_at = now()
WHERE status = 'active' AND user_id IS NULL AND (deleted IS NULL OR deleted = false);

-- ---------- 6c: AppUsers huérfanos → deleted = true ----------
UPDATE public."AppUsers" au
SET deleted = true, updated_at = now()
WHERE au.deleted = false
  AND (
    (au.user_type = 'org' AND NOT EXISTS (
      SELECT 1 FROM public."OrganizationUsers" ou
      WHERE ou.organization_id = au.organization_id
        AND ou.user_id = au.auth_user_id
        AND (ou.deleted = false)
    ))
    OR
    (au.user_type = 'dealer' AND au.dealer_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public."DealerUsers" du
      WHERE du.dealer_id = au.dealer_id
        AND du.user_id = au.auth_user_id
        AND (du.deleted IS NULL OR du.deleted = false)
    ))
  );

-- ---------- 6d: AppUserPreferences con active_dealer_id a dealer inexistente o deleted ----------
UPDATE public."AppUserPreferences" pref
SET active_dealer_id = NULL, updated_at = now()
WHERE pref.active_dealer_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public."Dealers" d
    WHERE d.id = pref.active_dealer_id
      AND (d.deleted IS NULL OR d.deleted = false)
  );

-- ---------- 6e: Diagnóstico (solo reporte, sin UPDATE) ----------
-- Descomentar y ejecutar manualmente para revisar filas con dealer_id huérfano:
/*
DO $$
DECLARE
  v_quotes bigint;
  v_proposals bigint;
  v_dc bigint;
  v_dcust bigint;
BEGIN
  SELECT count(*) INTO v_quotes FROM public."Quotes" q
  WHERE q.dealer_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public."Dealers" d WHERE d.id = q.dealer_id AND (d.deleted IS NULL OR d.deleted = false));
  SELECT count(*) INTO v_proposals FROM public."Proposals" p
  WHERE p.dealer_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public."Dealers" d WHERE d.id = p.dealer_id AND (d.deleted IS NULL OR d.deleted = false));
  SELECT count(*) INTO v_dc FROM public."DirectoryContacts" dc
  WHERE dc.dealer_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public."Dealers" d WHERE d.id = dc.dealer_id AND (d.deleted IS NULL OR d.deleted = false));
  SELECT count(*) INTO v_dcust FROM public."DirectoryCustomers" dc
  WHERE dc.dealer_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public."Dealers" d WHERE d.id = dc.dealer_id AND (d.deleted IS NULL OR d.deleted = false));
  RAISE NOTICE 'Quotes con dealer_id huérfano: %', v_quotes;
  RAISE NOTICE 'Proposals con dealer_id huérfano: %', v_proposals;
  RAISE NOTICE 'DirectoryContacts con dealer_id huérfano: %', v_dc;
  RAISE NOTICE 'DirectoryCustomers con dealer_id huérfano: %', v_dcust;
END $$;
*/

-- === database/migrations/20260224_004_acting_as_session_variable.sql ===
-- ============================================================
-- PASO 4: Acting-as con variable de sesión
-- ============================================================
-- init_session_context() llena app.* en la transacción actual.
-- current_dealer_id() y app_effective_dealer_id() leen solo variables.
-- session_is_* comparan parámetros con app.*.
-- set_acting_dealer además escribe app.dealer_id en la transacción.
-- Importante: con PostgREST cada request es otra transacción; el frontend
-- debe llamar init_session_context() en la misma transacción que los SELECT
-- (o antes del primer fetch por módulo). Ver PASO 7.
-- ============================================================

-- ---------- 4a: init_session_context() ----------
CREATE OR REPLACE FUNCTION public.init_session_context()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_row record;
  v_dealer_id uuid;
BEGIN
  SELECT au.user_type, au.organization_id, au.role_code, au.dealer_id, au.id
    INTO v_row
  FROM public."AppUsers" au
  WHERE au.auth_user_id = auth.uid()
    AND au.deleted = false
  ORDER BY CASE WHEN au.user_type = 'org' THEN 0 ELSE 1 END
  LIMIT 1;

  IF v_row IS NULL THEN
    -- No AppUser: clear session vars so RLS sees "no context"
    PERFORM set_config('app.user_type', '', true);
    PERFORM set_config('app.organization_id', '', true);
    PERFORM set_config('app.role_code', '', true);
    PERFORM set_config('app.dealer_id', '', true);
    RETURN;
  END IF;

  PERFORM set_config('app.user_type', COALESCE(v_row.user_type, ''), true);
  PERFORM set_config('app.organization_id', COALESCE(v_row.organization_id::text, ''), true);
  PERFORM set_config('app.role_code', COALESCE(v_row.role_code, ''), true);

  IF v_row.user_type = 'org' THEN
    SELECT pref.active_dealer_id INTO v_dealer_id
    FROM public."AppUserPreferences" pref
    WHERE pref.user_id = v_row.id;
  ELSE
    v_dealer_id := v_row.dealer_id;
  END IF;

  PERFORM set_config('app.dealer_id', COALESCE(v_dealer_id::text, ''), true);
END;
$$;

COMMENT ON FUNCTION public.init_session_context() IS
  'Sets app.user_type, app.organization_id, app.role_code, app.dealer_id from AppUsers (and AppUserPreferences for org). Must run in same transaction as RLS reads.';

REVOKE ALL ON FUNCTION public.init_session_context() FROM public;
GRANT EXECUTE ON FUNCTION public.init_session_context() TO authenticated;
GRANT EXECUTE ON FUNCTION public.init_session_context() TO service_role;

-- ---------- 4b: current_dealer_id() (0 args) — leer solo variable ----------
CREATE OR REPLACE FUNCTION public.current_dealer_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NULLIF(trim(current_setting('app.dealer_id', true)), '')::uuid;
$$;

COMMENT ON FUNCTION public.current_dealer_id() IS
  'Reads app.dealer_id from session. Call init_session_context() in same transaction first.';

-- ---------- 4c: app_effective_dealer_id() ----------
CREATE OR REPLACE FUNCTION public.app_effective_dealer_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.current_dealer_id();
$$;

COMMENT ON FUNCTION public.app_effective_dealer_id() IS
  'Delegates to current_dealer_id() — session variable for acting-as dealer.';

-- ---------- 4d: Funciones de sesión (solo current_setting) ----------
CREATE OR REPLACE FUNCTION public.session_is_org_user(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT current_setting('app.user_type', true) = 'org'
    AND NULLIF(trim(current_setting('app.organization_id', true)), '')::uuid = p_org_id;
$$;

CREATE OR REPLACE FUNCTION public.session_is_dealer_user(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT current_setting('app.user_type', true) = 'dealer'
    AND NULLIF(trim(current_setting('app.organization_id', true)), '')::uuid = p_org_id;
$$;

CREATE OR REPLACE FUNCTION public.session_is_admin(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.session_is_org_user(p_org_id)
    AND current_setting('app.role_code', true) IN ('owner', 'admin', 'superadmin');
$$;

CREATE OR REPLACE FUNCTION public.session_is_dealer_portal(p_dealer_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT current_setting('app.user_type', true) = 'dealer'
    AND NULLIF(trim(current_setting('app.dealer_id', true)), '')::uuid = p_dealer_id;
$$;

COMMENT ON FUNCTION public.session_is_org_user(uuid) IS 'True if session context is org user for given org.';
COMMENT ON FUNCTION public.session_is_dealer_user(uuid) IS 'True if session context is dealer (portal) user for given org.';
COMMENT ON FUNCTION public.session_is_admin(uuid) IS 'True if session is org admin/owner/superadmin for given org.';
COMMENT ON FUNCTION public.session_is_dealer_portal(uuid) IS 'True if session is dealer portal for given dealer_id.';

REVOKE ALL ON FUNCTION public.session_is_org_user(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.session_is_org_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.session_is_org_user(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.session_is_dealer_user(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.session_is_dealer_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.session_is_dealer_user(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.session_is_admin(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.session_is_admin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.session_is_admin(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.session_is_dealer_portal(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.session_is_dealer_portal(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.session_is_dealer_portal(uuid) TO service_role;

-- ---------- 4e: set_acting_dealer — mantener lógica y actualizar app.dealer_id en transacción ----------
CREATE OR REPLACE FUNCTION public.set_acting_dealer(p_dealer_id uuid)
RETURNS table(active_dealer_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_app_user_id uuid;
  v_org_id uuid;
  v_user_type text;
  v_ok boolean;
BEGIN
  SELECT id, organization_id, user_type
    INTO v_app_user_id, v_org_id, v_user_type
  FROM public."AppUsers"
  WHERE auth_user_id = auth.uid()
    AND deleted = false
  ORDER BY CASE WHEN user_type = 'org' THEN 0 ELSE 1 END
  LIMIT 1;

  IF v_app_user_id IS NULL THEN
    RAISE EXCEPTION 'AppUser not found for auth user';
  END IF;

  IF v_user_type <> 'org' THEN
    RAISE EXCEPTION 'Only org users can use acting-as';
  END IF;

  IF p_dealer_id IS NOT NULL THEN
    SELECT EXISTS(
      SELECT 1 FROM public."Dealers" d
      WHERE d.id = p_dealer_id
        AND d.organization_id = v_org_id
        AND (d.deleted IS NULL OR d.deleted = false)
    ) INTO v_ok;

    IF NOT v_ok THEN
      RAISE EXCEPTION 'Dealer not in same organization or does not exist';
    END IF;
  END IF;

  INSERT INTO public."AppUserPreferences"(user_id, active_dealer_id)
  VALUES (v_app_user_id, p_dealer_id)
  ON CONFLICT (user_id)
  DO UPDATE SET active_dealer_id = excluded.active_dealer_id;

  -- So that the rest of the transaction sees the new acting dealer
  PERFORM set_config('app.dealer_id', COALESCE(p_dealer_id::text, ''), true);

  RETURN QUERY SELECT p_dealer_id;
END;
$$;

COMMENT ON FUNCTION public.set_acting_dealer(uuid) IS
  'Sets acting-as dealer for org user and app.dealer_id in session. Call init_session_context() in next request so RLS sees it.';

REVOKE ALL ON FUNCTION public.set_acting_dealer(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.set_acting_dealer(uuid) TO authenticated;

-- Overload current_dealer_id(p_org_id) sigue delegando a current_dealer_id()
CREATE OR REPLACE FUNCTION public.current_dealer_id(p_org_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.current_dealer_id();
$$;

COMMENT ON FUNCTION public.current_dealer_id(uuid) IS
  'Delegates to current_dealer_id(). Session must be initialized with init_session_context().';

-- RPC para el frontend: init + current_dealer_id en una transacción (evita NULL por no haber init en la misma request)
CREATE OR REPLACE FUNCTION public.get_current_dealer_id()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  PERFORM public.init_session_context();
  RETURN public.current_dealer_id();
END;
$$;

COMMENT ON FUNCTION public.get_current_dealer_id() IS
  'Calls init_session_context() then current_dealer_id() in one transaction. Use from frontend for active dealer.';

REVOKE ALL ON FUNCTION public.get_current_dealer_id() FROM public;
GRANT EXECUTE ON FUNCTION public.get_current_dealer_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_dealer_id() TO service_role;

-- === database/migrations/20260224_005_rewrite_rls_quotes_proposals_directory.sql ===
-- ============================================================
-- PASO 5: Reescribir RLS (Quotes, Proposals, DirectoryContacts, DirectoryCustomers)
-- ============================================================
-- Reemplazar políticas que usan is_org_user_member_strict, app_effective_dealer_id(),
-- current_dealer_id(organization_id), is_dealer_portal_user, is_dealer_portal_user_with_write
-- por patrón basado en session_is_org_user, session_is_dealer_user, session_is_dealer_portal
-- y current_dealer_id() (sin args). Requiere init_session_context() en la misma transacción.
-- No se eliminan las funciones legacy; se deprecan en PASO 8.
-- ============================================================

-- ---------- Quotes ----------
DROP POLICY IF EXISTS "quotes_select" ON public."Quotes";
CREATE POLICY "quotes_select" ON public."Quotes"
  FOR SELECT TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );

DROP POLICY IF EXISTS "quotes_insert" ON public."Quotes";
CREATE POLICY "quotes_insert" ON public."Quotes"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
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
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );


-- ---------- Proposals ----------
DROP POLICY IF EXISTS "proposals_select" ON public."Proposals";
CREATE POLICY "proposals_select" ON public."Proposals"
  FOR SELECT TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
      OR
      (dealer_id IS NOT NULL AND public.session_is_dealer_portal(dealer_id))
    )
  );

DROP POLICY IF EXISTS "proposals_update" ON public."Proposals";
CREATE POLICY "proposals_update" ON public."Proposals"
  FOR UPDATE TO authenticated
  USING (
    (deleted IS NOT TRUE)
    AND organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        dealer_id IS NOT NULL
        AND public.session_is_dealer_portal(dealer_id)
        AND (
          current_setting('app.role_code', true) = 'dealer_manager'
          OR created_by_user_id = auth.uid()
        )
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        dealer_id IS NOT NULL
        AND public.session_is_dealer_portal(dealer_id)
        AND (
          current_setting('app.role_code', true) = 'dealer_manager'
          OR created_by_user_id = auth.uid()
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
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );


-- ---------- DirectoryContacts ----------
DROP POLICY IF EXISTS "dircontacts_select" ON public."DirectoryContacts";
CREATE POLICY "dircontacts_select" ON public."DirectoryContacts"
  FOR SELECT TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );

DROP POLICY IF EXISTS "dircontacts_insert" ON public."DirectoryContacts";
CREATE POLICY "dircontacts_insert" ON public."DirectoryContacts"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
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
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );


-- ---------- DirectoryCustomers ----------
DROP POLICY IF EXISTS "dircustomers_select" ON public."DirectoryCustomers";
CREATE POLICY "dircustomers_select" ON public."DirectoryCustomers"
  FOR SELECT TO authenticated
  USING (
    (deleted = false OR deleted IS NULL)
    AND organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );

DROP POLICY IF EXISTS "dircustomers_insert" ON public."DirectoryCustomers";
CREATE POLICY "dircustomers_insert" ON public."DirectoryCustomers"
  FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
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
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      (
        public.session_is_org_user(organization_id)
        AND (public.current_dealer_id() IS NULL OR dealer_id = public.current_dealer_id())
      )
      OR
      (
        public.session_is_dealer_user(organization_id)
        AND dealer_id = public.current_dealer_id()
      )
    )
  );

-- === database/migrations/20260224_008_deprecate_legacy_functions.sql ===
-- ============================================================
-- PASO 8: Deprecar funciones legacy
-- ============================================================
-- Añadir comentario DEPRECATED a funciones sustituidas por session_is_*.
-- No se eliminan; otras tablas/políticas pueden seguir usándolas hasta auditoría.
-- ============================================================

COMMENT ON FUNCTION public.is_org_user_member_strict(uuid) IS
  'DEPRECATED: Use session_is_org_user(uuid) after init_session_context(). Replaced in Quotes, Proposals, Directory RLS by 20260224_005.';

COMMENT ON FUNCTION public.is_portal_user_in_org(uuid) IS
  'DEPRECATED: Prefer session_is_dealer_user(uuid) after init_session_context(). Still used by org-only tables (catalog, BOM, etc.).';

COMMENT ON FUNCTION public.is_org_user_member(uuid) IS
  'DEPRECATED: Includes DealerUsers; use is_org_user_member_strict or session_is_org_user/session_is_dealer_user.';

COMMENT ON FUNCTION public.is_org_user_superadmin(uuid) IS
  'DEPRECATED: Prefer session_is_admin(uuid) for org-scoped admin check after init_session_context().';

-- -----------------------------------------------------------------------------
-- Auditoría: políticas que aún referencian estas funciones (para migración futura)
-- Ejecutar en SQL Editor para listar políticas a actualizar:
-- -----------------------------------------------------------------------------
/*
SELECT n.nspname AS schema_name,
       c.relname AS table_name,
       p.polname AS policy_name,
       CASE WHEN pg_get_expr(p.polqual, p.polrelid) ILIKE '%is_org_user_member_strict%' THEN 'polqual' ELSE NULL END AS in_using,
       CASE WHEN pg_get_expr(p.polwithcheck, p.polrelid) ILIKE '%is_org_user_member_strict%' THEN 'polwithcheck' ELSE NULL END AS in_with_check
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND (
    pg_get_expr(p.polqual, p.polrelid) ILIKE '%is_org_user_member_strict%'
    OR pg_get_expr(p.polwithcheck, p.polrelid) ILIKE '%is_org_user_member_strict%'
    OR pg_get_expr(p.polqual, p.polrelid) ILIKE '%is_portal_user_in_org%'
    OR pg_get_expr(p.polwithcheck, p.polrelid) ILIKE '%is_portal_user_in_org%'
    OR pg_get_expr(p.polqual, p.polrelid) ILIKE '%is_org_user_member%'
    OR pg_get_expr(p.polwithcheck, p.polrelid) ILIKE '%is_org_user_member%'
    OR pg_get_expr(p.polqual, p.polrelid) ILIKE '%is_org_user_superadmin%'
    OR pg_get_expr(p.polwithcheck, p.polrelid) ILIKE '%is_org_user_superadmin%'
  );
*/

