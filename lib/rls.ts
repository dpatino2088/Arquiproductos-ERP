export const ROLES = [
  'ADMIN',
  'MANAGER',
  'INTERNAL_USER',
  'DISTRIBUTOR_USER',
  'VIEW_ONLY'
] as const;

export type Role = (typeof ROLES)[number];

export const roleLabels: Record<Role, string> = {
  ADMIN: 'Admin',
  MANAGER: 'Manager',
  INTERNAL_USER: 'Internal User',
  DISTRIBUTOR_USER: 'Distributor User',
  VIEW_ONLY: 'View Only'
};

export const roleDescription: Record<Role, string> = {
  ADMIN: 'Full access to all companies data and configuration.',
  MANAGER: 'Manage operational records and approve changes.',
  INTERNAL_USER: 'Operate daily workflows within assigned company.',
  DISTRIBUTOR_USER: 'External distributor access with restricted scope.',
  VIEW_ONLY: 'Read-only visibility for audits or temporary users.'
};

