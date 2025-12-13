-- ============================================================================
-- SCRIPT DE VERIFICACIÓN: Comprobar que las políticas RLS están correctas
-- ============================================================================
-- Ejecuta este script DESPUÉS de aplicar FINAL_FIX_RLS_RECURSION.sql
-- para verificar que todo está configurado correctamente
-- ============================================================================

-- 1. Verificar que existen las funciones helper
SELECT 
    routine_name as "Función",
    routine_type as "Tipo",
    security_type as "Seguridad"
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'can_insert_organization_user',
    'can_view_organization_users', 
    'can_manage_organization_users'
  )
ORDER BY routine_name;

-- Resultado esperado: 3 funciones, todas con security_type = 'DEFINER'

-- 2. Verificar que las funciones tienen los permisos correctos
SELECT 
    routine_name as "Función",
    grantee as "Usuario",
    privilege_type as "Permiso"
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND routine_name IN (
    'can_insert_organization_user',
    'can_view_organization_users',
    'can_manage_organization_users'
  )
ORDER BY routine_name, grantee;

-- Resultado esperado: Cada función debe tener EXECUTE para 'authenticated'

-- 3. Listar todas las políticas actuales en OrganizationUsers
SELECT 
    schemaname as "Esquema",
    tablename as "Tabla", 
    policyname as "Política",
    cmd as "Comando",
    CASE 
        WHEN permissive = 'PERMISSIVE' THEN 'Permisiva'
        ELSE 'Restrictiva'
    END as "Tipo"
FROM pg_policies 
WHERE tablename = 'OrganizationUsers'
ORDER BY cmd, policyname;

-- Resultado esperado: Debe mostrar 6 políticas:
-- - organizationusers_select_own (SELECT)
-- - organizationusers_select_org_admins (SELECT)
-- - organizationusers_insert_owners_admins (INSERT)
-- - organizationusers_update_own (UPDATE)
-- - organizationusers_update_owners (UPDATE)
-- - organizationusers_delete_owners (DELETE)

-- 4. Ver el detalle de las políticas (para verificar que usan las funciones)
SELECT 
    policyname as "Política",
    cmd as "Comando",
    qual as "Condición USING",
    with_check as "Condición WITH CHECK"
FROM pg_policies 
WHERE tablename = 'OrganizationUsers'
ORDER BY cmd, policyname;

-- 5. Verificar que RLS está habilitado
SELECT 
    schemaname as "Esquema",
    tablename as "Tabla",
    rowsecurity as "RLS Habilitado"
FROM pg_tables 
WHERE tablename = 'OrganizationUsers';

-- Resultado esperado: rowsecurity = true

-- ============================================================================
-- TEST DE FUNCIONALIDAD (Opcional - solo si tienes datos de prueba)
-- ============================================================================

-- Test 1: Verificar que las funciones se ejecutan sin error
-- NOTA: Reemplaza los UUIDs con valores reales de tu base de datos
-- SELECT public.can_insert_organization_user(
--     'tu-user-id'::uuid,
--     'tu-org-id'::uuid, 
--     'member'
-- );

-- Test 2: Verificar que puedes consultar OrganizationUsers sin recursión
-- SELECT id, user_email, role, organization_id 
-- FROM "OrganizationUsers" 
-- WHERE organization_id = 'tu-org-id'::uuid
-- LIMIT 5;

-- ============================================================================
-- RESULTADO ESPERADO
-- ============================================================================
-- Si todo está correcto, deberías ver:
-- ✅ 3 funciones con SECURITY DEFINER
-- ✅ Permisos EXECUTE otorgados a 'authenticated'
-- ✅ 6 políticas RLS activas
-- ✅ RLS habilitado en la tabla
-- ✅ Las políticas usan las funciones helper (can_insert_organization_user, etc.)
-- ============================================================================

