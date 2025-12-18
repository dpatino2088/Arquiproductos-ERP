-- ====================================================
-- Migration 89: Verificar que BOMTemplates existe
-- ====================================================

-- Verificar si la tabla existe
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = 'BOMTemplates'
    ) THEN '✅ Tabla BOMTemplates EXISTE'
    ELSE '❌ Tabla BOMTemplates NO EXISTE'
  END as estado_tabla;

-- Mostrar estructura de la tabla si existe
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'BOMTemplates'
ORDER BY ordinal_position;

-- Verificar políticas RLS
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'BOMTemplates';

-- Verificar índices
SELECT 
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'BOMTemplates'
  AND schemaname = 'public';

-- Intentar hacer un SELECT simple para verificar acceso
SELECT COUNT(*) as total_templates
FROM public."BOMTemplates";

