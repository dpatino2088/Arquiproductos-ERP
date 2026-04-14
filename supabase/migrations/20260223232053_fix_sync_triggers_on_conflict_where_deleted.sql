-- Fix: ON CONFLICT must include WHERE deleted = false to match partial unique index
-- idx_appusers_auth_user_type_dealer_unique

CREATE OR REPLACE FUNCTION public.sync_org_user_to_appuser()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.deleted = true AND (OLD.deleted = false OR OLD.deleted IS NULL) THEN
    UPDATE public."AppUsers"
    SET deleted = true, updated_at = now()
    WHERE auth_user_id = OLD.user_id
      AND user_type = 'org'
      AND organization_id = OLD.organization_id
      AND deleted = false;
    RETURN NEW;
  END IF;

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
$$;;
