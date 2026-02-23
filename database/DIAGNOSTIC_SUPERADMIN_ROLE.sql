-- ============================================================================
-- DIAGNÓSTICO: Rol SuperAdmin / org en la UI (fuente: AppUsers)
-- Ejecutar en Supabase SQL Editor para revisar datos.
-- La app usa AppUsers (user_type='org', role_code) como fuente única para rol interno.
-- ============================================================================

-- 1) Usuario por email (auth.users)
SELECT id AS auth_user_id, email, created_at
FROM auth.users
WHERE lower(email) = lower('dpatino@arquiluz.com');

-- 2) Filas en AppUsers para org (rol que ve la UI)
SELECT id, organization_id, user_type, auth_user_id, email, display_name, role_code, status, deleted
FROM public."AppUsers"
WHERE lower(email) = lower('dpatino@arquiluz.com')
   OR auth_user_id = (SELECT id FROM auth.users WHERE lower(email) = lower('dpatino@arquiluz.com') LIMIT 1);

-- 3) Resumen: la UI muestra el role_code de la fila AppUsers con user_type='org'.
--    Si role_code = 'superadmin' → badge "SuperAdmin". Si 'operator' → "Operator", etc.
