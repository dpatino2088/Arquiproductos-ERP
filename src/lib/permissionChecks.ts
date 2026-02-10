/**
 * Permission checks from role-based permission sets.
 * Used for UI gating / feature flags (not RLS).
 */

/**
 * Check if a role's permission set includes the given permission code.
 */
export function roleHasPermission(rolePermissionSet: Set<string>, code: string): boolean {
  return rolePermissionSet.has(code);
}

/**
 * Build a Set of permission codes from AppUserRolePermissions rows.
 */
export function buildPermissionSetFromRolePermissions(
  rows: Array<{ permission_code: string }>
): Set<string> {
  const set = new Set<string>();
  for (const row of rows) {
    if (row?.permission_code) set.add(row.permission_code);
  }
  return set;
}
