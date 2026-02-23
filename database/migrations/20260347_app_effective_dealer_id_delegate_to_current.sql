-- ============================================================================
-- Fix: app_effective_dealer_id() debe delegar a current_dealer_id()
--
-- Problema: dos fuentes distintas para "acting dealer":
--   - Frontend: set_acting_dealer → AppUserPreferences → current_dealer_id()
--   - RLS: app_effective_dealer_id() → user_dealer_scope (NUNCA se actualiza)
--
-- El frontend nunca llama set_effective_dealer_id, así user_dealer_scope está
-- vacío y app_effective_dealer_id() siempre retorna NULL.
-- Las políticas RLS usan app_effective_dealer_id() para org users.
--
-- Consecuencias: RLS permite todas las filas (app_effective_dealer_id = NULL).
-- El filtrado solo ocurre en el frontend. Si hay race/cache incorrecto o datos
-- con dealer_id NULL, los resultados son intermitentes.
--
-- Solución: hacer app_effective_dealer_id() delegar a current_dealer_id().
-- Así RLS y frontend usan la misma fuente (AppUserPreferences).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.app_effective_dealer_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT public.current_dealer_id();
$$;

COMMENT ON FUNCTION public.app_effective_dealer_id() IS
'Delegates to current_dealer_id() — single source of truth for acting-as dealer.
Org users: AppUserPreferences.active_dealer_id. Dealer users: AppUsers.dealer_id.
RLS and frontend now use the same source (AppUserPreferences via current_dealer_id).';
