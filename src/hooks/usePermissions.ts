import { useContext } from 'react';
import { PermissionContext } from '../context/PermissionContext';

/**
 * Hook to check permissions
 * 
 * @example
 * const { can, hasAnyPermission } = usePermissions();
 * 
 * if (can('manufacturing.write')) {
 *   // Show create button
 * }
 * 
 * if (hasAnyPermission(['quotes.read', 'sales_orders.read'])) {
 *   // Show sales module
 * }
 */
export function usePermissions() {
  const context = useContext(PermissionContext);
  
  // If context is not available, return safe defaults
  if (context === undefined) {
    if (import.meta.env.DEV) {
      console.warn('usePermissions called outside PermissionProvider. Returning safe defaults.');
    }
    return {
      permissions: new Set<string>(),
      loading: true,
      can: () => false,
      hasAnyPermission: () => false,
      hasAllPermissions: () => false,
      refreshPermissions: async () => {},
    };
  }
  
  return context;
}

/**
 * Helper hook for specific permission checks
 */
export function useCan(permissionCode: string): boolean {
  const { can } = usePermissions();
  return can(permissionCode);
}

