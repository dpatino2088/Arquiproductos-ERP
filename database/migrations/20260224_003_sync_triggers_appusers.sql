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
  WHERE deleted = false
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
  WHERE deleted = false
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
</think>
Corrigiendo el trigger: ON CONFLICT no admite WHERE en la cláusula.
<｜tool▁calls▁begin｜><｜tool▁call▁begin｜>
StrReplace