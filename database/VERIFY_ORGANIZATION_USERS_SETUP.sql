-- ====================================================
-- SCRIPT DE VERIFICACIÓN: Estado actual de OrganizationUsers
-- Ejecuta esto PRIMERO para ver qué está mal
-- ====================================================

-- 1. Verificar columnas de la tabla
SELECT 
    '1. COLUMNAS DE LA TABLA' as seccion,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'OrganizationUsers'
ORDER BY ordinal_position;

-- 2. Verificar que RLS está habilitado
SELECT 
    '2. ROW LEVEL SECURITY' as seccion,
    tablename,
    rowsecurity as "RLS Habilitado"
FROM pg_tables
WHERE schemaname = 'public' 
  AND tablename = 'OrganizationUsers';

-- 3. Verificar políticas RLS
SELECT 
    '3. POLÍTICAS RLS' as seccion,
    policyname as "Nombre Política",
    cmd as "Comando",
    permissive as "Permisivo",
    roles as "Roles"
FROM pg_policies 
WHERE tablename = 'OrganizationUsers'
ORDER BY policyname;

-- 4. Verificar funciones helper
SELECT 
    '4. FUNCIONES HELPER' as seccion,
    proname as "Nombre Función",
    prosecdef as "Security Definer"
FROM pg_proc 
WHERE proname IN (
    'can_insert_organization_user',
    'can_view_organization_users',
    'can_manage_organization_users',
    'org_is_owner_or_admin'
)
ORDER BY proname;

-- 5. Verificar tu usuario
SELECT 
    '5. TU USUARIO' as seccion,
    ou.name,
    ou.email,
    ou.role,
    ou.is_system,
    o.organization_name,
    ou.deleted
FROM "OrganizationUsers" ou
JOIN "Organizations" o ON o.id = ou.organization_id
WHERE ou.email IN ('dpatino@arquiluz.studio', 'dpatino@grupo927.com')
  AND ou.deleted = false;

-- 6. Verificar Customers disponibles
SELECT 
    '6. CUSTOMERS DISPONIBLES' as seccion,
    COUNT(*) as "Total Customers"
FROM "DirectoryCustomers"
WHERE deleted = false;

-- 7. Verificar Contacts con customer_id
SELECT 
    '7. CONTACTS CON CUSTOMER' as seccion,
    COUNT(*) as "Total Contacts con Customer"
FROM "DirectoryContacts"
WHERE customer_id IS NOT NULL
  AND deleted = false;

-- 8. Verificar índices
SELECT 
    '8. ÍNDICES' as seccion,
    indexname as "Nombre Índice",
    indexdef as "Definición"
FROM pg_indexes
WHERE tablename = 'OrganizationUsers'
ORDER BY indexname;

-- RESUMEN FINAL
SELECT 
    '=== RESUMEN ===' as "DIAGNÓSTICO",
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'OrganizationUsers' AND column_name = 'is_system')
        THEN '✅ Columna is_system existe'
        ELSE '❌ Columna is_system NO existe'
    END as "Columna is_system",
    
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'OrganizationUsers' AND rowsecurity = true)
        THEN '✅ RLS habilitado'
        ELSE '❌ RLS NO habilitado'
    END as "RLS Status",
    
    CASE 
        WHEN (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'OrganizationUsers') >= 6
        THEN '✅ ' || (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'OrganizationUsers')::text || ' políticas RLS'
        ELSE '❌ Solo ' || COALESCE((SELECT COUNT(*) FROM pg_policies WHERE tablename = 'OrganizationUsers')::text, '0') || ' políticas'
    END as "Políticas RLS",
    
    CASE 
        WHEN (SELECT COUNT(*) FROM pg_proc WHERE proname IN ('can_insert_organization_user', 'can_view_organization_users', 'can_manage_organization_users', 'org_is_owner_or_admin')) = 4
        THEN '✅ 4 funciones helper'
        ELSE '❌ Solo ' || COALESCE((SELECT COUNT(*) FROM pg_proc WHERE proname IN ('can_insert_organization_user', 'can_view_organization_users', 'can_manage_organization_users', 'org_is_owner_or_admin'))::text, '0') || ' funciones'
    END as "Funciones Helper";

