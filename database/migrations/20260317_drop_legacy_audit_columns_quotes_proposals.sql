-- ====================================================
-- Migration 20260317: Eliminar columnas legacy en Quotes y Proposals
-- ====================================================
-- Candidatas a eliminar (duplican info resuelta vía AppUsers/DealerUsers):
--   created_by_email, created_by_user_name, created_by_user_type, created_by_dealer_id
--   updated_by_user_id, updated_by_email, updated_by_user_name, updated_by_user_type, updated_by_dealer_id
--
-- IMPORTANTE: set_audit_fields escribe en estas columnas. Primero actualizamos la función
-- para que no falle cuando las columnas no existan (check dinámico).
-- ====================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1) Actualizar set_audit_fields para comprobar existencia de columnas
--    (evita error al eliminar columnas en Quotes/Proposals)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_audit_fields() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_is_dealer boolean;
  v_dealer_id uuid;
  v_portal_email text;
  v_portal_name text;
  v_has_col boolean;
  v_tname text := TG_TABLE_NAME;
BEGIN
  v_is_dealer := public.is_dealer_user_for_org(new.organization_id);
  v_dealer_id := public.current_dealer_id_for_org(new.organization_id);

  IF v_is_dealer THEN
    SELECT du.portal_user_email, du.portal_user_name
      INTO v_portal_email, v_portal_name
    FROM public."DealerUsers" du
    WHERE du.organization_id = new.organization_id
      AND du.user_id = auth.uid()
      AND coalesce(du.deleted, false) = false
      AND (du.status IS NULL OR du.status IN ('active','invited'))
    ORDER BY du.created_at DESC
    LIMIT 1;
  END IF;

  IF tg_op = 'INSERT' THEN
    -- created_by_user_id: solo si existe y está null
    SELECT EXISTS(SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name=v_tname AND column_name='created_by_user_id') INTO v_has_col;
    IF v_has_col AND new.created_by_user_id IS NULL THEN
      new.created_by_user_id := auth.uid();
    END IF;

    SELECT EXISTS(SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name=v_tname AND column_name='created_by_email') INTO v_has_col;
    IF v_has_col AND new.created_by_email IS NULL THEN
      new.created_by_email := coalesce(v_portal_email, public.jwt_email());
    END IF;

    SELECT EXISTS(SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name=v_tname AND column_name='created_by_user_name') INTO v_has_col;
    IF v_has_col AND new.created_by_user_name IS NULL THEN
      new.created_by_user_name := coalesce(v_portal_name, public.jwt_name());
    END IF;

    SELECT EXISTS(SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name=v_tname AND column_name='created_by_user_type') INTO v_has_col;
    IF v_has_col AND new.created_by_user_type IS NULL THEN
      new.created_by_user_type := CASE WHEN v_is_dealer THEN 'portal' ELSE 'internal' END;
    END IF;

    SELECT EXISTS(SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name=v_tname AND column_name='created_by_dealer_id') INTO v_has_col;
    IF v_has_col AND new.created_by_dealer_id IS NULL THEN
      new.created_by_dealer_id := v_dealer_id;
    END IF;
  END IF;

  -- updated_* (siempre en UPDATE, en INSERT también)
  SELECT EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name=v_tname AND column_name='updated_by_user_id') INTO v_has_col;
  IF v_has_col THEN new.updated_by_user_id := auth.uid(); END IF;

  SELECT EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name=v_tname AND column_name='updated_by_email') INTO v_has_col;
  IF v_has_col THEN new.updated_by_email := coalesce(v_portal_email, public.jwt_email()); END IF;

  SELECT EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name=v_tname AND column_name='updated_by_user_name') INTO v_has_col;
  IF v_has_col THEN new.updated_by_user_name := coalesce(v_portal_name, public.jwt_name()); END IF;

  SELECT EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name=v_tname AND column_name='updated_by_user_type') INTO v_has_col;
  IF v_has_col THEN new.updated_by_user_type := CASE WHEN v_is_dealer THEN 'portal' ELSE 'internal' END; END IF;

  SELECT EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name=v_tname AND column_name='updated_by_dealer_id') INTO v_has_col;
  IF v_has_col THEN new.updated_by_dealer_id := v_dealer_id; END IF;

  RETURN new;
END;
$$;

COMMENT ON FUNCTION public.set_audit_fields() IS 'Audit fields. Checks column existence to support tables that dropped legacy columns (Quotes, Proposals).';

-- ----------------------------------------------------------------------------
-- 2) Actualizar set_created_by_fields para no fallar si created_by_email no existe
--    (Quotes usa trg_quotes_set_created_by)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_created_by_fields() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_has_col boolean;
  v_tname text := TG_TABLE_NAME;
BEGIN
  SELECT EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name=v_tname AND column_name='created_by_user_id') INTO v_has_col;
  IF v_has_col AND new.created_by_user_id IS NULL THEN
    new.created_by_user_id := auth.uid();
  END IF;

  SELECT EXISTS(SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name=v_tname AND column_name='created_by_email') INTO v_has_col;
  IF v_has_col AND new.created_by_email IS NULL THEN
    new.created_by_email := public.current_user_email();
  END IF;

  RETURN new;
END;
$$;

-- ----------------------------------------------------------------------------
-- 3) Eliminar columnas legacy en Quotes
-- ----------------------------------------------------------------------------
ALTER TABLE public."Quotes" DROP COLUMN IF EXISTS created_by_email;
ALTER TABLE public."Quotes" DROP COLUMN IF EXISTS created_by_user_name;
ALTER TABLE public."Quotes" DROP COLUMN IF EXISTS created_by_user_type;
ALTER TABLE public."Quotes" DROP COLUMN IF EXISTS created_by_dealer_id;
ALTER TABLE public."Quotes" DROP COLUMN IF EXISTS updated_by_user_id;
ALTER TABLE public."Quotes" DROP COLUMN IF EXISTS updated_by_email;
ALTER TABLE public."Quotes" DROP COLUMN IF EXISTS updated_by_user_name;
ALTER TABLE public."Quotes" DROP COLUMN IF EXISTS updated_by_user_type;
ALTER TABLE public."Quotes" DROP COLUMN IF EXISTS updated_by_dealer_id;

-- ----------------------------------------------------------------------------
-- 4) Eliminar columnas legacy en Proposals
-- ----------------------------------------------------------------------------
ALTER TABLE public."Proposals" DROP COLUMN IF EXISTS created_by_email;
ALTER TABLE public."Proposals" DROP COLUMN IF EXISTS created_by_user_name;
ALTER TABLE public."Proposals" DROP COLUMN IF EXISTS created_by_user_type;
ALTER TABLE public."Proposals" DROP COLUMN IF EXISTS created_by_dealer_id;
ALTER TABLE public."Proposals" DROP COLUMN IF EXISTS updated_by_user_id;
ALTER TABLE public."Proposals" DROP COLUMN IF EXISTS updated_by_email;
ALTER TABLE public."Proposals" DROP COLUMN IF EXISTS updated_by_user_name;
ALTER TABLE public."Proposals" DROP COLUMN IF EXISTS updated_by_user_type;
ALTER TABLE public."Proposals" DROP COLUMN IF EXISTS updated_by_dealer_id;

-- ----------------------------------------------------------------------------
-- 5) created_by_portal_user_id es legacy — migrar y eliminar
--    Migrar: portal_user_id → user_id (auth.users) vía DealerUsers
-- ----------------------------------------------------------------------------
-- 5a) Migrar datos: Proposals con created_by_portal_user_id → created_by_user_id
UPDATE public."Proposals" p
SET created_by_user_id = du.user_id
FROM public."DealerUsers" du
WHERE p.created_by_portal_user_id = du.id
  AND p.created_by_user_id IS NULL
  AND p.created_by_portal_user_id IS NOT NULL;

-- 5b) Migrar datos: Quotes con created_by_portal_user_id → created_by_user_id
UPDATE public."Quotes" q
SET created_by_user_id = du.user_id
FROM public."DealerUsers" du
WHERE q.created_by_portal_user_id = du.id
  AND q.created_by_user_id IS NULL
  AND q.created_by_portal_user_id IS NOT NULL;

-- 5c) Migrar datos: DirectoryContacts
UPDATE public."DirectoryContacts" dc
SET created_by_user_id = du.user_id
FROM public."DealerUsers" du
WHERE dc.created_by_portal_user_id = du.id
  AND dc.created_by_user_id IS NULL
  AND dc.created_by_portal_user_id IS NOT NULL;

-- 5d) Migrar datos: DirectoryCustomers
UPDATE public."DirectoryCustomers" dcu
SET created_by_user_id = du.user_id
FROM public."DealerUsers" du
WHERE dcu.created_by_portal_user_id = du.id
  AND dcu.created_by_user_id IS NULL
  AND dcu.created_by_portal_user_id IS NOT NULL;

-- 5e) Eliminar created_by_portal_user_id
ALTER TABLE public."Proposals" DROP CONSTRAINT IF EXISTS proposals_created_by_exactly_one_chk;
ALTER TABLE public."Proposals" DROP COLUMN IF EXISTS created_by_portal_user_id;

ALTER TABLE public."Quotes" DROP COLUMN IF EXISTS created_by_portal_user_id;

ALTER TABLE public."DirectoryContacts" DROP CONSTRAINT IF EXISTS "DirectoryContacts_created_by_portal_user_id_fkey";
DROP INDEX IF EXISTS public.idx_directory_contacts_created_by_portal_user;
ALTER TABLE public."DirectoryContacts" DROP COLUMN IF EXISTS created_by_portal_user_id;

ALTER TABLE public."DirectoryCustomers" DROP CONSTRAINT IF EXISTS "DirectoryCustomers_created_by_portal_user_id_fkey";
DROP INDEX IF EXISTS public.idx_directory_customers_created_by_portal_user;
ALTER TABLE public."DirectoryCustomers" DROP COLUMN IF EXISTS created_by_portal_user_id;

DROP INDEX IF EXISTS public.idx_quotes_created_by_portal_user;

-- 5f) Actualizar proposals_ensure_created_by (solo created_by_user_id)
CREATE OR REPLACE FUNCTION public.proposals_ensure_created_by() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_quote RECORD;
  v_uid uuid;
BEGIN
  v_uid := auth.uid();

  IF NEW.created_by_user_id IS NULL THEN
    IF v_uid IS NOT NULL THEN
      NEW.created_by_user_id := v_uid;
    ELSIF NEW.quote_id IS NOT NULL THEN
      SELECT q.created_by_user_id INTO v_quote
      FROM public."Quotes" q WHERE q.id = NEW.quote_id;
      IF v_quote.created_by_user_id IS NOT NULL THEN
        NEW.created_by_user_id := v_quote.created_by_user_id;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.proposals_ensure_created_by() IS 'Ensures created_by_user_id is set on insert (defaults to auth.uid() or Quote creator).';

-- 5g) Actualizar proposals_ensure_integrity (solo created_by_user_id)
CREATE OR REPLACE FUNCTION public.proposals_ensure_integrity() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_quote RECORD;
  v_uid uuid;
BEGIN
  v_uid := auth.uid();

  IF NEW.quote_id IS NOT NULL THEN
    SELECT q.created_by_user_id, q.dealer_id INTO v_quote
    FROM public."Quotes" q WHERE q.id = NEW.quote_id;
  END IF;

  IF NEW.dealer_id IS NULL THEN
    IF v_quote.dealer_id IS NOT NULL THEN
      NEW.dealer_id := v_quote.dealer_id;
    ELSE
      RAISE EXCEPTION 'Proposal requires dealer_id. proposal_id=%, quote_id=%',
        COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid), NEW.quote_id;
    END IF;
  END IF;

  IF NEW.created_by_user_id IS NULL THEN
    IF v_uid IS NOT NULL THEN
      NEW.created_by_user_id := v_uid;
    ELSIF v_quote.created_by_user_id IS NOT NULL THEN
      NEW.created_by_user_id := v_quote.created_by_user_id;
    ELSE
      RAISE EXCEPTION 'Proposal must have creator. proposal_id=%, quote_id=%',
        COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid), NEW.quote_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.proposals_ensure_integrity() IS 'Ensures dealer_id and created_by_user_id on Proposal insert.';

COMMIT;

-- Post-apply: verificar que Quotes y Proposals solo tienen created_by_user_id
-- SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name IN ('Quotes','Proposals') AND column_name LIKE 'created_by%' ORDER BY table_name, column_name;
