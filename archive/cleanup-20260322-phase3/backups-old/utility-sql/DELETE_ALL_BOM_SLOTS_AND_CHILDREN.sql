-- ELIMINAR TODOS LOS SLOTS Y HIJOS DE TODOS LOS TEMPLATES
-- Org: 3acbb54c-c71f-4cb2-9fe3-d3ac513babe2
BEGIN;

-- 1) Eliminar HIJOS (CatalogItemComponents)
DELETE FROM public."CatalogItemComponents"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid;

-- 2) Eliminar SLOTS (BOMTemplateSlots)
DELETE FROM public."BOMTemplateSlots"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid;

COMMIT;

-- Verificación
SELECT 'CatalogItemComponents' AS table_name, COUNT(*) AS remaining
FROM public."CatalogItemComponents"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
UNION ALL
SELECT 'BOMTemplateSlots' AS table_name, COUNT(*) AS remaining
FROM public."BOMTemplateSlots"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid;
