-- ====================================================
-- SCRIPT DE VERIFICACIÓN: Verificar datos existentes
-- Ejecuta esto PRIMERO para ver qué Customers y Contacts tienes
-- ====================================================

-- Ver todas las organizaciones
SELECT 
    id,
    organization_name,
    tax_id,
    status
FROM "Organizations"
WHERE deleted = false
ORDER BY organization_name;

-- Ver todos los Customers de la organización Arquiproductos
SELECT 
    dc.id,
    dc.company_name,
    dc.primary_contact_id,
    COUNT(DISTINCT dcon.id) as total_contacts
FROM "DirectoryCustomers" dc
LEFT JOIN "DirectoryContacts" dcon ON dcon.customer_id = dc.id AND dcon.deleted = false
WHERE dc.organization_id = (
    SELECT id FROM "Organizations" 
    WHERE organization_name ILIKE '%Arquiproductos%' 
    AND deleted = false 
    LIMIT 1
)
AND dc.deleted = false
GROUP BY dc.id, dc.company_name, dc.primary_contact_id
ORDER BY dc.company_name;

-- Ver todos los Contacts con su Customer asignado
SELECT 
    dcon.id as contact_id,
    dcon.customer_name,
    dcon.email,
    dc.id as customer_id,
    dc.company_name as customer_company
FROM "DirectoryContacts" dcon
LEFT JOIN "DirectoryCustomers" dc ON dc.id = dcon.customer_id
WHERE dcon.organization_id = (
    SELECT id FROM "Organizations" 
    WHERE organization_name ILIKE '%Arquiproductos%' 
    AND deleted = false 
    LIMIT 1
)
AND dcon.deleted = false
ORDER BY dc.company_name, dcon.customer_name;

