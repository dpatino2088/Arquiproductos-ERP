-- ============================================================================
-- Fix: current_dealer_id(p_org_id) debe delegar a current_dealer_id()
--
-- Problema: existían dos overloads:
--   - current_dealer_id() (0 args): usa AppUserPreferences para org users
--   - current_dealer_id(p_org_id): usa DealerUsers (legacy), NO AppUserPreferences
--
-- Las políticas RLS y código legacy llaman current_dealer_id(organization_id).
-- Eso usaba la versión con args, que no consultaba AppUserPreferences.
-- SuperAdmin/org users sin fila en DealerUsers → retornaba NULL → 0 filas.
--
-- Solución: hacer que current_dealer_id(p_org_id) delegue a current_dealer_id().
-- Así ambas firmas usan la misma fuente de verdad (AppUserPreferences + AppUsers).
--
-- Para probar desde SQL Editor con auth simulado:
--   select set_config('request.jwt.claim.role', 'authenticated', true);
--   select set_config('request.jwt.claim.sub', '<auth.users.id>', true);
--   select public.current_dealer_id();
-- ============================================================================

CREATE OR REPLACE FUNCTION public.current_dealer_id(p_org_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT public.current_dealer_id();
$$;

COMMENT ON FUNCTION public.current_dealer_id(uuid) IS
'Delegates to current_dealer_id() — single source of truth for acting-as dealer.
Used by RLS policies and legacy code. Org users: AppUserPreferences.active_dealer_id.
Dealer users: AppUsers.dealer_id.';
