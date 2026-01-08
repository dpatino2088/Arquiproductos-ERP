-- ========================================================
-- DIAGNÓSTICO: Tablas existentes relacionadas con BOM/Assemblies
-- ========================================================
-- Objetivo: Detectar si ya existe una tabla para assemblies
-- antes de crear CatalogItemBOMLines

SELECT 
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
AND (
    table_name ILIKE '%bom%' 
    OR table_name ILIKE '%child%'
    OR table_name ILIKE '%assembly%'
    OR table_name ILIKE '%parent%'
)
ORDER BY table_name;

-- Verificar estructura de tablas candidatas
SELECT 
    t.table_name,
    c.column_name,
    c.data_type,
    c.is_nullable,
    c.column_default
FROM information_schema.tables t
INNER JOIN information_schema.columns c ON c.table_name = t.table_name
WHERE t.table_schema = 'public'
AND (
    t.table_name ILIKE '%bom%' 
    OR t.table_name ILIKE '%child%'
    OR t.table_name ILIKE '%assembly%'
)
AND c.table_schema = 'public'
ORDER BY t.table_name, c.ordinal_position;

-- Verificar si CatalogItemBOMLines ya existe
SELECT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name = 'CatalogItemBOMLines'
) AS catalog_item_bom_lines_exists;

-- Verificar si CatalogItemChildrenBOM existe
SELECT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name = 'CatalogItemChildrenBOM'
) AS catalog_item_children_bom_exists;


