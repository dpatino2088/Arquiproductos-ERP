-- Introspección de tablas Cost Engine
-- Ejecutar en Supabase SQL Editor para ver columnas reales

-- 1) CostSettings
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'CostSettings'
ORDER BY ordinal_position;

-- 2) ImportTaxRules
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'ImportTaxRules'
ORDER BY ordinal_position;

-- 3) CategoryMargins
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'CategoryMargins'
ORDER BY ordinal_position;

-- 4) CatalogCategories (para validar que existe)
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'CatalogCategories'
ORDER BY ordinal_position;

-- Verificar constraints y unique indexes
SELECT 
  tc.constraint_name,
  tc.table_name,
  kcu.column_name,
  tc.constraint_type
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.table_name IN ('CostSettings', 'ImportTaxRules', 'CategoryMargins')
ORDER BY tc.table_name, tc.constraint_type;
