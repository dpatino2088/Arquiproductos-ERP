-- ====================================================
-- Verificar RLS y Permisos para CatalogItems
-- ====================================================
-- Este script verifica si hay problemas con RLS
-- que puedan estar bloqueando las consultas
-- ====================================================

-- 1. Verificar si RLS está habilitado
SELECT 
  'RLS Status' as seccion,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename = 'CatalogItems';

-- 2. Verificar políticas RLS existentes
SELECT 
  'RLS Policies' as seccion,
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'CatalogItems';

-- 3. Verificar permisos de la tabla
SELECT 
  'Table Permissions' as seccion,
  grantee,
  privilege_type,
  is_grantable
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND table_name = 'CatalogItems'
ORDER BY grantee, privilege_type;

-- 4. Probar consulta simple (como la hace el frontend)
SELECT 
  'Test Query - Collections' as seccion,
  COUNT(*) as total_items,
  COUNT(DISTINCT collection_name) as unique_collections,
  COUNT(*) FILTER (WHERE collection_name IS NOT NULL) as items_with_collection
FROM public."CatalogItems"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND deleted = false
  AND collection_name IS NOT NULL;

-- 5. Probar consulta con filtro de family (como la hace el frontend)
SELECT 
  'Test Query - By Family' as seccion,
  family,
  COUNT(*) as total_items,
  COUNT(DISTINCT collection_name) as unique_collections
FROM public."CatalogItems"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND deleted = false
  AND collection_name IS NOT NULL
  AND family IS NOT NULL
GROUP BY family
ORDER BY family
LIMIT 10;








