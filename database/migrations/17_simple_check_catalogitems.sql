-- ====================================================
-- Script simple: Verificar si CatalogItems existe
-- ====================================================
-- Este script muestra los resultados en una tabla
-- ====================================================

-- Verificar si la tabla existe
SELECT 
  'Tabla CatalogItems' as verificacion,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = 'CatalogItems'
    ) THEN '✅ EXISTE'
    ELSE '❌ NO EXISTE'
  END as estado;

-- Si existe, mostrar sus columnas
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'CatalogItems'
ORDER BY ordinal_position;

-- Buscar tablas similares
SELECT 
  table_name,
  'Tabla similar' as tipo
FROM information_schema.tables
WHERE table_schema = 'public'
  AND (
    lower(table_name) LIKE '%catalog%' 
    OR lower(table_name) LIKE '%item%'
  )
ORDER BY table_name;













