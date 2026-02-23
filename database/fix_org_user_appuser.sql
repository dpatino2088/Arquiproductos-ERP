-- Crea fila en AppUsers para Organization Users que no la tienen (ej. creados antes del fix create-temp-user)
INSERT INTO public."AppUsers" (
  organization_id, user_type, dealer_id, auth_user_id,
  email, display_name, role_code, status,
  must_change_password, deleted
)
SELECT
  ou.organization_id,
  'org',
  NULL,
  ou.user_id,
  ou.user_email,
  ou.user_name,
  COALESCE(ou.role::text, 'superadmin'),
  'active',
  false,
  false
FROM public."OrganizationUsers" ou
WHERE ou.deleted = false
  AND NOT EXISTS (
    SELECT 1 FROM public."AppUsers" a
    WHERE a.email = ou.user_email
      AND a.organization_id = ou.organization_id
      AND a.user_type = 'org'
      AND a.deleted = false
  );
