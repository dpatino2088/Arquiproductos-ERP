// src/types/roles.ts

export type OrgRole =
  | 'superadmin'
  | 'admin'
  | 'operator'
  | 'procurement'
  | 'finance';

// Legacy roles (for migration/compatibility)
export type LegacyOrgRole =
  | 'super_admin'
  | 'owner'
  | 'manager'
  | 'member'
  | 'viewer'
  | 'user';
