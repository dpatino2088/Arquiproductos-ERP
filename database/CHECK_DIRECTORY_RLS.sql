-- ====================================================
-- SCRIPT: Verificar políticas RLS de Directory tables
-- Para diagnóstico de por qué no se ven Customers/Contacts
-- ====================================================

-- 1. Verificar políticas de DirectoryCustomers
SELECT 
    '1. DirectoryCustomers - Políticas RLS' as seccion,
    policyname as "Nombre Política",
    cmd as "Comando",
    qual as "Condición USING",
    with_check as "Condición WITH CHECK"
FROM pg_policies 
WHERE tablename = 'DirectoryCustomers'
ORDER BY policyname;

-- 2. Verificar políticas de DirectoryContacts
SELECT 
    '2. DirectoryContacts - Políticas RLS' as seccion,
    policyname as "Nombre Política",
    cmd as "Comando",
    qual as "Condición USING",
    with_check as "Condición WITH CHECK"
FROM pg_policies 
WHERE tablename = 'DirectoryContacts'
ORDER BY policyname;

-- 3. Verificar que RLS está habilitado
SELECT 
    '3. RLS Status' as seccion,
    tablename,
    rowsecurity as "RLS Habilitado"
FROM pg_tables
WHERE schemaname = 'public' 
  AND tablename IN ('DirectoryCustomers', 'DirectoryContacts', 'OrganizationUsers')
ORDER BY tablename;

-- 4. Probar SELECT directo en DirectoryCustomers
-- Esto dirá si el problema es de RLS o de datos
SELECT 
    '4. Test DirectoryCustomers SELECT' as seccion,
    COUNT(*) as "Total Customers visibles"
FROM "DirectoryCustomers"
WHERE deleted = false;

-- 5. Probar SELECT directo en DirectoryContacts
SELECT 
    '5. Test DirectoryContacts SELECT' as seccion,
    COUNT(*) as "Total Contacts visibles"
FROM "DirectoryContacts"
WHERE deleted = false;

-- 6. Ver Customers con detalles
SELECT 
    '6. Customers disponibles' as seccion,
    id,
    company_name,
    email,
    organization_id,
    deleted
FROM "DirectoryCustomers"
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 10;

-- 7. Ver Contacts con customer_id
SELECT 
    '7. Contacts con Customer asignado' as seccion,
    dc.id as contact_id,
    dc.customer_name,
    dc.email,
    dc.customer_id,
    dcu.company_name as customer_company
FROM "DirectoryContacts" dc
LEFT JOIN "DirectoryCustomers" dcu ON dcu.id = dc.customer_id
WHERE dc.deleted = false
  AND dc.customer_id IS NOT NULL
ORDER BY dc.created_at DESC
LIMIT 10;

