-- ====================================================
-- Example SELECT queries for frontend dropdowns
-- ====================================================

-- Get all active CustomerTypes for an organization (for dropdown)
SELECT 
    id,
    name,
    description
FROM "CustomerTypes"
WHERE organization_id = $1::uuid
    AND deleted = false
    AND archived = false
ORDER BY name ASC;

-- Get all active VendorTypes for an organization (for dropdown)
SELECT 
    id,
    name,
    description
FROM "VendorTypes"
WHERE organization_id = $1::uuid
    AND deleted = false
    AND archived = false
ORDER BY name ASC;

-- Get all active ContactTitles for an organization (for dropdown)
SELECT 
    id,
    title,
    description
FROM "ContactTitles"
WHERE organization_id = $1::uuid
    AND deleted = false
    AND archived = false
ORDER BY title ASC;

-- Get all active ContractorRoles for an organization (for dropdown)
SELECT 
    id,
    role_name,
    description
FROM "ContractorRoles"
WHERE organization_id = $1::uuid
    AND deleted = false
    AND archived = false
ORDER BY role_name ASC;

-- Get all active SiteTypes for an organization (for dropdown)
SELECT 
    id,
    name,
    description
FROM "SiteTypes"
WHERE organization_id = $1::uuid
    AND deleted = false
    AND archived = false
ORDER BY name ASC;

-- ====================================================
-- Example: Get Contact with Title name (JOIN query)
-- ====================================================
SELECT 
    dc.id,
    dc.first_name,
    dc.last_name,
    ct.title as title_name,
    dc.email
FROM "DirectoryContacts" dc
LEFT JOIN "ContactTitles" ct ON dc.title_id = ct.id
WHERE dc.organization_id = $1::uuid
    AND dc.deleted = false;

-- ====================================================
-- Example: Get Customer with CustomerType name (JOIN query)
-- ====================================================
SELECT 
    dc.id,
    dc.company_name,
    ctype.name as customer_type_name,
    dc.email
FROM "DirectoryCustomers" dc
LEFT JOIN "CustomerTypes" ctype ON dc.customer_type_id = ctype.id
WHERE dc.organization_id = $1::uuid
    AND dc.deleted = false;

