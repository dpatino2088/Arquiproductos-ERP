/**
 * Helper functions for user roles and organization access
 */

export interface UserMetadata {
  global_role?: 'app_admin' | 'org_user';
  default_organization_id?: string;
  [key: string]: any;
}

export interface AuthUser {
  id: string;
  email?: string;
  user_metadata?: UserMetadata;
}

/**
 * Check if a user is an app admin
 */
export function isAppAdmin(user: AuthUser | null | undefined): boolean {
  if (!user?.user_metadata) return false;
  return user.user_metadata.global_role === 'app_admin';
}

/**
 * Get the default organization ID for a user
 */
export function getDefaultOrganizationId(user: AuthUser | null | undefined): string | null {
  if (!user?.user_metadata) return null;
  return user.user_metadata.default_organization_id || null;
}

/**
 * Check if a user has a specific role in an organization
 * Note: This requires a database query to OrganizationUsers table
 * This is a helper function signature - actual implementation needs DB access
 */
export interface OrganizationRoleCheck {
  userId: string;
  organizationId: string;
  requiredRole: 'owner' | 'admin' | 'member' | 'viewer';
}

/**
 * Role hierarchy for permission checks
 * Higher number = more permissions
 */
export const ROLE_HIERARCHY: Record<string, number> = {
  viewer: 1,
  member: 2,
  admin: 3,
  owner: 4,
  app_admin: 5,
};

/**
 * Check if a role has at least the required permission level
 */
export function hasRolePermission(
  userRole: string,
  requiredRole: 'owner' | 'admin' | 'member' | 'viewer'
): boolean {
  const userLevel = ROLE_HIERARCHY[userRole] || 0;
  const requiredLevel = ROLE_HIERARCHY[requiredRole] || 0;
  return userLevel >= requiredLevel;
}

