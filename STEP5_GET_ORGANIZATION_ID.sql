-- STEP 5: Get your organization_id to use in Manufacturing Order creation
-- Run this query to get your organization_id

SELECT 
  ou.organization_id,
  o.organization_name,
  ou.role,
  ou.user_id
FROM "OrganizationUsers" ou
INNER JOIN "Organizations" o ON o.id = ou.organization_id
WHERE ou.user_id = auth.uid()  -- Current logged-in user
  AND ou.deleted = false
  AND o.deleted = false
ORDER BY ou.created_at DESC
LIMIT 5;

-- Use one of the organization_id values from the results above
-- when creating the Manufacturing Order








