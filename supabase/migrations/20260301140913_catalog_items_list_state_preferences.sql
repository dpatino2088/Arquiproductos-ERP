-- Persist Catalog Items list UI state per app user.
-- Stores filters/search/sort/pagination in AppUserPreferences as JSONB.

ALTER TABLE public."AppUserPreferences"
ADD COLUMN IF NOT EXISTS catalog_items_list_state jsonb;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'app_user_preferences_catalog_items_list_state_is_object_chk'
  ) THEN
    ALTER TABLE public."AppUserPreferences"
      ADD CONSTRAINT app_user_preferences_catalog_items_list_state_is_object_chk
      CHECK (
        catalog_items_list_state IS NULL
        OR jsonb_typeof(catalog_items_list_state) = 'object'
      );
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.get_catalog_items_list_state()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_app_user_id uuid;
  v_state jsonb;
BEGIN
  SELECT au.id
    INTO v_app_user_id
  FROM public."AppUsers" au
  WHERE au.auth_user_id = auth.uid()
    AND au.deleted = false
  ORDER BY CASE WHEN au.user_type = 'org' THEN 0 ELSE 1 END
  LIMIT 1;

  IF v_app_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT pref.catalog_items_list_state
    INTO v_state
  FROM public."AppUserPreferences" pref
  WHERE pref.user_id = v_app_user_id;

  RETURN v_state;
END;
$$;

COMMENT ON FUNCTION public.get_catalog_items_list_state() IS
  'Returns catalog items list UI state (JSONB) for current auth user from AppUserPreferences.';

REVOKE ALL ON FUNCTION public.get_catalog_items_list_state() FROM public;
GRANT EXECUTE ON FUNCTION public.get_catalog_items_list_state() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_catalog_items_list_state() TO service_role;

CREATE OR REPLACE FUNCTION public.set_catalog_items_list_state(p_state jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_app_user_id uuid;
BEGIN
  IF p_state IS NOT NULL AND jsonb_typeof(p_state) <> 'object' THEN
    RAISE EXCEPTION 'p_state must be a JSON object or NULL';
  END IF;

  SELECT au.id
    INTO v_app_user_id
  FROM public."AppUsers" au
  WHERE au.auth_user_id = auth.uid()
    AND au.deleted = false
  ORDER BY CASE WHEN au.user_type = 'org' THEN 0 ELSE 1 END
  LIMIT 1;

  IF v_app_user_id IS NULL THEN
    RAISE EXCEPTION 'AppUser not found for auth user';
  END IF;

  INSERT INTO public."AppUserPreferences" (user_id, catalog_items_list_state)
  VALUES (v_app_user_id, p_state)
  ON CONFLICT (user_id)
  DO UPDATE
  SET catalog_items_list_state = EXCLUDED.catalog_items_list_state;
END;
$$;

COMMENT ON FUNCTION public.set_catalog_items_list_state(jsonb) IS
  'Persists catalog items list UI state (JSONB) for current auth user in AppUserPreferences.';

REVOKE ALL ON FUNCTION public.set_catalog_items_list_state(jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.set_catalog_items_list_state(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_catalog_items_list_state(jsonb) TO service_role;;
