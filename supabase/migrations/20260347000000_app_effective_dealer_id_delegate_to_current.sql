-- ============================================================================
-- Fix: app_effective_dealer_id() debe delegar a current_dealer_id()
--
-- Problema: dos fuentes distintas para "acting dealer":
--   - Frontend: set_acting_dealer → AppUserPreferences → current_dealer_id()
--   - RLS: app_effective_dealer_id() → user_dealer_scope (NUNCA se actualiza)
--
-- El frontend nunca llama set_effective_dealer_id, así user_dealer_scope está
-- vacío y app_effective_dealer_id() siempre retorna NULL.
--
-- Solución: hacer app_effective_dealer_id() delegar a current_dealer_id().
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
'Delegates to current_dealer_id() — single source of truth. RLS and frontend use same source.';
