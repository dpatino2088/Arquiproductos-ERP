-- Clean up OrganizationUserPermissions for users who already have role_code in AppUsers.
-- Once a user has role_code, their permissions come exclusively from AppUserRolePermissions.
-- Legacy rows in OrganizationUserPermissions were bleeding through (e.g. dashboard.read for procurement).

DELETE FROM public."OrganizationUserPermissions" oup
WHERE EXISTS (
  SELECT 1
  FROM public."AppUsers" au
  JOIN public."OrganizationUsers" ou
    ON ou.user_id = au.auth_user_id
    AND ou.organization_id = au.organization_id
  WHERE ou.id = oup.organization_user_id
    AND au.role_code IS NOT NULL
    AND au.role_code <> ''
    AND au.deleted = false
);
