-- =============================================================================
-- RPC: get_app_users_display_names
-- =============================================================================
-- Devuelve { auth_user_id, display_name } para una lista de auth_user_ids.
--
-- Por qué SECURITY DEFINER:
-- La política RLS de public."AppUsers" sólo deja a un dealer ver usuarios de su
-- propio dealer_id. Eso impide a un Dealer Manager resolver el nombre del
-- creador de Quotes/Proposals que pertenecen a *otros* dealers de la misma
-- organización (caso típico cuando se ven proposals creadas por staff interno).
--
-- Esta RPC expone únicamente { auth_user_id, display_name } (sin email, role,
-- ni datos sensibles) y está limitada a usuarios autenticados.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_app_users_display_names(
  p_auth_user_ids uuid[]
)
RETURNS TABLE (
  auth_user_id uuid,
  display_name text
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT au.auth_user_id, au.display_name
  FROM public."AppUsers" au
  WHERE au.deleted = false
    AND au.auth_user_id = ANY(p_auth_user_ids)
    AND au.display_name IS NOT NULL
    AND length(trim(au.display_name)) > 0;
$$;

REVOKE ALL ON FUNCTION public.get_app_users_display_names(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_app_users_display_names(uuid[]) TO authenticated;

COMMENT ON FUNCTION public.get_app_users_display_names(uuid[]) IS
  'Devuelve display_name por auth_user_id evitando RLS de AppUsers; usado por columnas "Created by" en Quotes y Proposals.';
