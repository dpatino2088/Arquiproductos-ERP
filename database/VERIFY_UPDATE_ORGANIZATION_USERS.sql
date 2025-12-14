-- ====================================================
-- VERIFICACIÓN: Políticas de Actualización de Usuarios
-- ====================================================
-- Ejecuta este script después de FIX_UPDATE_ORGANIZATION_USERS_RLS.sql
-- para verificar que todo está configurado correctamente
-- ====================================================

-- 1. Verificar que la función can_update_organization_user existe
SELECT 
  '1. Función can_update_organization_user' as verificacion,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Función existe'
    ELSE '❌ Función NO existe'
  END as resultado
FROM pg_proc
WHERE proname = 'can_update_organization_user';

-- 2. Verificar políticas de UPDATE
SELECT 
  '2. Políticas UPDATE' as verificacion,
  policyname,
  cmd as command,
  CASE 
    WHEN policyname = 'organizationusers_update_owners_admins' THEN '✅ Política correcta'
    WHEN policyname = 'organizationusers_update_owners' THEN '⚠️ Política antigua (debería ser reemplazada)'
    ELSE '❓ Política desconocida'
  END as estado
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'OrganizationUsers'
  AND cmd = 'UPDATE'
ORDER BY policyname;

-- 3. Verificar tu rol actual y permisos
SELECT 
  '3. Tu Rol y Permisos' as verificacion,
  ou.role,
  o.organization_name,
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

-- 4. Probar la función manualmente (reemplaza con tu organization_id)
-- Descomenta y ejecuta con tu organization_id real:
/*
SELECT 
  '4. Prueba de Función' as verificacion,
  public.can_update_organization_user(
    auth.uid(),
    'TU_ORGANIZATION_ID'::uuid,
    'member'::text
  ) as puede_actualizar_member,
  public.can_update_organization_user(
    auth.uid(),
    'TU_ORGANIZATION_ID'::uuid,
    'owner'::text
  ) as puede_actualizar_owner;
*/

-- 5. Verificar que no hay políticas duplicadas o conflictivas
SELECT 
  '5. Resumen de Políticas UPDATE' as verificacion,
  COUNT(*) as total_politicas,
  STRING_AGG(policyname, ', ') as nombres_politicas
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'OrganizationUsers'
  AND cmd = 'UPDATE';

-- 6. Verificar permisos de ejecución de la función
SELECT 
  '6. Permisos de Función' as verificacion,
  p.proname as function_name,
  CASE 
    WHEN has_function_privilege('authenticated', 'public.can_update_organization_user(uuid, uuid, text)', 'EXECUTE') THEN '✅ Permisos correctos (authenticated puede ejecutar)'
    ELSE '❌ Permisos faltantes (authenticated NO puede ejecutar)'
  END as estado
FROM pg_proc p
WHERE p.proname = 'can_update_organization_user'
  AND p.pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

