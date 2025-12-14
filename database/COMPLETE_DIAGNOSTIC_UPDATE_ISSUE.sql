-- ====================================================
-- DIAGNÓSTICO COMPLETO: Problema de Actualización de Usuarios
-- ====================================================
-- Ejecuta este script para identificar todos los problemas
-- ====================================================

-- 1. Verificar que la función can_update_organization_user existe y funciona
SELECT 
  '1. Función can_update_organization_user' as paso,
  proname as function_name,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Existe'
    ELSE '❌ NO existe - Ejecuta FIX_UPDATE_ORGANIZATION_USERS_RLS.sql'
  END as estado
FROM pg_proc
WHERE proname = 'can_update_organization_user'
GROUP BY proname;

-- 2. Verificar políticas de UPDATE actuales
SELECT 
  '2. Políticas UPDATE' as paso,
  policyname,
  cmd as command,
  CASE 
    WHEN policyname = 'organizationusers_update_owners_admins' THEN '✅ Política correcta'
    WHEN policyname = 'organizationusers_update_owners' THEN '⚠️ Política antigua - Necesita actualización'
    WHEN policyname = 'organizationusers_update_own' THEN '✅ Política para auto-actualización'
    ELSE '❓ Política desconocida'
  END as estado
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'OrganizationUsers'
  AND cmd = 'UPDATE'
ORDER BY policyname;

-- 3. Verificar tu rol actual y permisos
SELECT 
  '3. Tu Rol y Permisos' as paso,
  ou.role,
  o.organization_name,
  ou.organization_id,
  CASE 
    WHEN ou.role = 'owner' THEN '✅ Puedes actualizar cualquier usuario'
    WHEN ou.role = 'admin' THEN '✅ Puedes actualizar usuarios (excepto cambiar a owner)'
    WHEN ou.role = 'member' THEN '❌ No puedes actualizar usuarios'
    WHEN ou.role = 'viewer' THEN '❌ No puedes actualizar usuarios'
    ELSE '❓ Rol desconocido'
  END as permisos
FROM "OrganizationUsers" ou
JOIN "Organizations" o ON o.id = ou.organization_id
WHERE ou.user_id = auth.uid()
  AND ou.deleted = false;

-- 4. Probar la función con tu usuario actual (reemplaza con tu organization_id real)
-- Descomenta y ejecuta:
/*
SELECT 
  '4. Prueba de Función' as paso,
  public.can_update_organization_user(
    auth.uid(),
    (SELECT organization_id FROM "OrganizationUsers" WHERE user_id = auth.uid() AND deleted = false LIMIT 1),
    'member'::text
  ) as puede_actualizar_member,
  public.can_update_organization_user(
    auth.uid(),
    (SELECT organization_id FROM "OrganizationUsers" WHERE user_id = auth.uid() AND deleted = false LIMIT 1),
    'owner'::text
  ) as puede_actualizar_owner;
*/

-- 5. Verificar que RLS está habilitado
SELECT 
  '5. RLS Status' as paso,
  tablename,
  rowsecurity as rls_enabled,
  CASE 
    WHEN rowsecurity THEN '✅ RLS habilitado'
    ELSE '❌ RLS deshabilitado - PROBLEMA CRÍTICO'
  END as estado
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename = 'OrganizationUsers';

-- 6. Verificar permisos de ejecución de la función
SELECT 
  '6. Permisos de Función' as paso,
  p.proname as function_name,
  CASE 
    WHEN has_function_privilege('authenticated', 'public.can_update_organization_user(uuid, uuid, text)', 'EXECUTE') THEN '✅ Permisos correctos'
    ELSE '❌ Permisos faltantes - Ejecuta: GRANT EXECUTE ON FUNCTION public.can_update_organization_user(uuid, uuid, text) TO authenticated;'
  END as estado
FROM pg_proc p
WHERE p.proname = 'can_update_organization_user'
  AND p.pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- 7. Verificar usuarios de ejemplo para probar actualización
SELECT 
  '7. Usuarios para Probar' as paso,
  ou.id,
  ou.user_name,
  ou.email,
  ou.role,
  ou.organization_id,
  o.organization_name,
  CASE 
    WHEN ou.deleted THEN '⚠️ Usuario eliminado'
    ELSE '✅ Usuario activo'
  END as estado
FROM "OrganizationUsers" ou
JOIN "Organizations" o ON o.id = ou.organization_id
WHERE ou.organization_id IN (
  SELECT organization_id 
  FROM "OrganizationUsers" 
  WHERE user_id = auth.uid() 
    AND deleted = false
    AND role IN ('owner', 'admin')
)
AND ou.deleted = false
ORDER BY ou.created_at DESC
LIMIT 5;

