// src/types/roles.ts

export type OrgRole =
  | 'superadmin'
  | 'admin'
  | 'sales_coordinator'
  | 'operator_admin'
  | 'operator_member'
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
