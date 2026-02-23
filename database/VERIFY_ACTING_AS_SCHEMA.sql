-- ============================================================================
-- VERIFICACIÓN: Acting-As Schema (current_dealer_id, app_effective_dealer_id)
-- Ejecutar en Supabase SQL Editor
-- ============================================================================

-- 1) Overloads de current_dealer_id (deben existir 2: sin args y p_org_id)
SELECT n.nspname as schema, p.proname as name, 
       pg_get_function_identity_arguments(p.oid) as args,
       pg_get_function_result(p.oid) as returns
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace 
WHERE n.nspname = 'public' AND p.proname = 'current_dealer_id'
ORDER BY 3;

-- 2) app_effective_dealer_id debe existir (0 args) y delegar a current_dealer_id
SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid), 
       pg_get_function_result(p.oid)
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace 
WHERE n.nspname = 'public' AND p.proname = 'app_effective_dealer_id';

-- 3) Definición de app_effective_dealer_id (debe contener current_dealer_id)
SELECT pg_get_functiondef(p.oid) 
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace 
WHERE n.nspname = 'public' AND p.proname = 'app_effective_dealer_id';

-- 4) Tablas requeridas
SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='AppUserPreferences') as app_user_preferences_exists,
       EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='AppUsers') as app_users_exists;
