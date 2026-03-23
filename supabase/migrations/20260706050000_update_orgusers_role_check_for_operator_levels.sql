-- Update OrganizationUsers role check to include new operator levels.

ALTER TABLE "OrganizationUsers"
  DROP CONSTRAINT IF EXISTS organizationusers_role_check;

ALTER TABLE "OrganizationUsers"
  ADD CONSTRAINT organizationusers_role_check
  CHECK (
    role IN (
      'owner',
      'admin',
      'member',
      'viewer',
      'superadmin',
      'operator',
      'operator_admin',
      'operator_member',
      'procurement',
      'finance'
    )
  );
