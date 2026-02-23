-- ====================================================
-- Migration 20260323: Fix "record 'new' has no field 'created_by_email'"
-- ====================================================
-- Hotfix: actualiza set_audit_fields y set_created_by_fields para no fallar
-- en tablas sin created_by_email (Quotes, Proposals tras 20260317).
-- Usa bloques EXCEPTION para capturar 42703 (columna inexistente).
-- ====================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1) set_audit_fields: usa EXCEPTION para evitar acceder a columnas inexistentes
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
    BEGIN
      IF new.created_by_user_id IS NULL THEN new.created_by_user_id := auth.uid(); END IF;
    EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

    BEGIN
      IF new.created_by_email IS NULL THEN new.created_by_email := coalesce(v_portal_email, public.jwt_email()); END IF;
    EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

    BEGIN
      IF new.created_by_user_name IS NULL THEN new.created_by_user_name := coalesce(v_portal_name, public.jwt_name()); END IF;
    EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

    BEGIN
      IF new.created_by_user_type IS NULL THEN new.created_by_user_type := CASE WHEN v_is_dealer THEN 'portal' ELSE 'internal' END; END IF;
    EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

    BEGIN
      IF new.created_by_dealer_id IS NULL THEN new.created_by_dealer_id := v_dealer_id; END IF;
    EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;
  END IF;

  BEGIN
    new.updated_by_user_id := auth.uid();
  EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

  BEGIN
    new.updated_by_email := coalesce(v_portal_email, public.jwt_email());
  EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

  BEGIN
    new.updated_by_user_name := coalesce(v_portal_name, public.jwt_name());
  EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

  BEGIN
    new.updated_by_user_type := CASE WHEN v_is_dealer THEN 'portal' ELSE 'internal' END;
  EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

  BEGIN
    new.updated_by_dealer_id := v_dealer_id;
  EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

  RETURN new;
END;
$$;

COMMENT ON FUNCTION public.set_audit_fields() IS 'Audit fields. Checks column existence to support tables that dropped legacy columns (Quotes, Proposals).';

-- ----------------------------------------------------------------------------
-- 2) set_created_by_fields: usa EXCEPTION para evitar acceder a columnas inexistentes
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_created_by_fields() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO public, auth
AS $$
BEGIN
  BEGIN
    IF new.created_by_user_id IS NULL THEN new.created_by_user_id := auth.uid(); END IF;
  EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

  BEGIN
    IF new.created_by_email IS NULL THEN new.created_by_email := public.current_user_email(); END IF;
  EXCEPTION WHEN SQLSTATE '42703' THEN NULL; END;

  RETURN new;
END;
$$;

COMMENT ON FUNCTION public.set_created_by_fields() IS 'Sets created_by_user_id and created_by_email. Checks column existence for Quotes/Proposals that dropped legacy columns.';

COMMIT;
