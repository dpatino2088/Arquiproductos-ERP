/**
 * Role-based permission presets for Organization Users
 * 
 * This file defines the default permissions for each role.
 * When a user's role is changed, these presets can be applied
 * to automatically configure their permissions.
 */

export type OrgRole = 'superadmin' | 'admin' | 'operator' | 'procurement' | 'finance';

/**
 * Role permission presets
 * Each role has a set of permission codes that are granted by default
 */
export const ORG_ROLE_PRESETS: Record<OrgRole, string[]> = {
  superadmin: [
    // Superadmin gets ALL permissions - this is handled specially in code
    // but we list common ones for reference
    'dashboard.read',
    'directory.read',
    'directory.write',
    'catalog.read',
    'catalog.write',
    'inventory.read',
    'inventory.write',
    'sales.read',
    'sales.write',
    'quotes.edit',
    'salesorders.edit',
    'manufacturing.read',
    'manufacturing.write',
    'finance.read',
    'finance.write',
    'settings.read',
    'settings.write',
    'org.users.manage',
  ],
  admin: [
    'dashboard.read',
    'directory.read',
    'directory.write',
    'catalog.read',
    'catalog.write',
    'inventory.read',
    'inventory.write',
    'sales.read',
    'sales.write',
    'quotes.edit',
    'salesorders.edit',
    'manufacturing.read',
    'manufacturing.write',
    'finance.read',
    'finance.write',
    'settings.read',
    'settings.write',
    'org.users.manage',
  ],
  operator: [
    'dashboard.read',
    'catalog.read',
    'catalog.write',
    'inventory.read',
    'manufacturing.read',
    'manufacturing.write',
    // NO directory.*, NO sales.*, NO settings.*, NO finance.*, NO org.*
  ],
  procurement: [
    'dashboard.read',
    'directory.read',
    'catalog.read',
    // catalog.write is OPTIONAL - prefer OFF initially
    'inventory.read',
    'inventory.write',
    'sales.read',
    'manufacturing.read', // view only
    'finance.read', // optional if needs costs; default ON
    'settings.read',
    // NO manufacturing.write, NO settings.write, NO org.users.manage, NO finance.write
  ],
  finance: [
    'dashboard.read',
    'sales.read',
    // quotes.edit is OPTIONAL - finance typically read-only on quotes; default OFF
    'finance.read',
    'finance.write',
    'manufacturing.read', // optional view
    'directory.read', // optional
    // NO manufacturing.write, NO org.users.manage, NO settings.write (unless finance should edit cost engine)
  ],
};

/**
 * Get default permissions for a role
 * 
 * @param role - The organization role
 * @param allPermissionCodes - All available permission codes (for superadmin)
 * @returns Set of permission codes for the role
 */
export function getDefaultPermissionsForRole(
  role: OrgRole,
  allPermissionCodes?: string[]
): Set<string> {
  if (role === 'superadmin') {
    // Superadmin always has ALL permissions
    if (allPermissionCodes && allPermissionCodes.length > 0) {
      return new Set(allPermissionCodes);
    }
    // If no codes provided, return all from preset (fallback)
    return new Set(ORG_ROLE_PRESETS.superadmin);
  }
  
  // For other roles, return preset permissions
  return new Set(ORG_ROLE_PRESETS[role] || []);
}

/**
 * Get role label for display
 */
export function getRoleLabel(role: OrgRole): string {
  const labels: Record<OrgRole, string> = {
    superadmin: 'Superadmin (Full access)',
    admin: 'Admin (Manage org users and settings)',
    operator: 'Operator (Manufacturing & sales operations)',
    procurement: 'Procurement (Purchasing & inventory)',
    finance: 'Finance (Financial control)',
  };
  return labels[role] || role;
}

/**
 * Get role description
 */
export function getRoleDescription(role: OrgRole): string {
  const descriptions: Record<OrgRole, string> = {
    superadmin: 'Full system access with all permissions',
    admin: 'Can manage organization users and settings',
    operator: 'Focused on manufacturing and sales operations',
    procurement: 'Focused on purchasing and inventory management',
    finance: 'Focused on financial control and reporting',
  };
  return descriptions[role] || '';
}

/**
 * Check if a role is valid
 */
export function isValidOrgRole(role: string): role is OrgRole {
  return ['superadmin', 'admin', 'operator', 'procurement', 'finance'].includes(role);
}

/**
 * Map legacy roles to new roles
 */
export function mapLegacyRole(legacyRole: string): OrgRole {
  const mapping: Record<string, OrgRole> = {
    'owner': 'superadmin',
    'super_admin': 'superadmin',
    'manager': 'admin',
    'member': 'operator',
    'viewer': 'operator',
    'user': 'operator',
  };
  
  return mapping[legacyRole.toLowerCase()] || 'operator';
}
