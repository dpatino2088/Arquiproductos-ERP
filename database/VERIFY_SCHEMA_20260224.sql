-- ============================================================================
-- Verificación del esquema tras migraciones 20260224 (Estabilización Dealers/Acting-As/RLS)
-- Ejecutar en Supabase SQL Editor DESPUÉS de aplicar 20260224_* o 20260224_ALL_run_in_supabase.sql
-- ============================================================================

-- 1) Tabla AppUsers existe y columnas esperadas
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'AppUsers'
ORDER BY ordinal_position;

-- 2) Índice único para triggers (ON CONFLICT)
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'AppUsers'
  AND indexname = 'idx_appusers_auth_user_type_dealer_unique';

-- 3) Función set_updated_at y trigger en AppUsers
SELECT tgname, tgrelid::regclass
FROM pg_trigger
WHERE tgname IN ('trg_appusers_updated_at', 'trg_sync_orguser_appuser', 'trg_sync_dealeruser_appuser');

-- 4) Funciones de sesión (PASO 4)
SELECT proname, pg_get_function_identity_arguments(oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND proname IN (
    'init_session_context', 'get_current_dealer_id', 'current_dealer_id', 'app_effective_dealer_id',
    'session_is_org_user', 'session_is_dealer_user', 'session_is_admin', 'session_is_dealer_portal',
    'set_acting_dealer'
  )
ORDER BY proname, args;

-- 5) RLS en Quotes: políticas deben usar session_is_org_user o session_is_dealer_user
SELECT polname, polcmd, pg_get_expr(polqual, polrelid) AS using_expr
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname = 'Quotes'
  AND (pg_get_expr(polqual, polrelid) ILIKE '%session_is_%' OR pg_get_expr(polwithcheck, polrelid) ILIKE '%session_is_%');

-- 6) Constraints de integridad (PASO 2)
SELECT conname, conrelid::regclass
FROM pg_constraint
WHERE conname IN ('chk_orguser_active_has_userid', 'chk_dealeruser_active_has_userid');

-- Resumen: si todo está bien verás filas en 1–6. Si falta algo, la query correspondiente devolverá 0 filas.
