import { useContext, useMemo } from 'react';
import { PermissionContext } from '../context/PermissionContext';

/**
 * Hook to check permissions
 * 
 * @example
 * const { can, hasAnyPermission, hasAllPermissions } = usePermissions();
 * 
 * if (can('directory.read')) {
 *   // Show directory menu
 * }
 * 
 * if (hasAnyPermission(['quotes.read', 'sales_orders.read'])) {
 *   // Show sales module
 * }
 * 
 * if (hasAllPermissions(['directory.read', 'directory.write'])) {
 *   // Show full directory features
 * }
 */
export function usePermissions() {
  const context = useContext(PermissionContext);
  
  // If context is not available, return safe defaults
  if (context === undefined) {
    if (import.meta.env.DEV) {
      console.warn('⚠️ usePermissions called outside PermissionProvider. Returning safe defaults.');
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
 * Helper hook for specific permission check
 * 
 * @example
 * const canEditDirectory = useCan('directory.write');
 * 
 * {canEditDirectory && <EditButton />}
 */
export function useCan(permissionCode: string): boolean {
  const { can } = usePermissions();
  return can(permissionCode);
}

/**
 * Module permissions matrix
 * Defines which permissions are required to view/edit each module
 */
export const MODULE_PERMS = {
  dashboard: {
    view: ['dashboard.read'],
    edit: ['dashboard.write'],
  },
  directory: {
    view: ['directory.read'],
    edit: ['directory.write'],
  },
  catalog: {
    view: ['catalog.read'],
    edit: ['catalog.write'],
  },
  inventory: {
    view: ['inventory.read'],
    edit: ['inventory.write'],
  },
  sales: {
    view: ['sales.read'],
    edit: ['sales.write'],
  },
  manufacturing: {
    view: ['manufacturing.read'],
    edit: ['manufacturing.write'],
  },
  financials: {
    view: ['finance.read', 'financials.read'], // Support both for backward compatibility
    edit: ['finance.write', 'financials.write'],
  },
  settings: {
    view: ['settings.read'],
    edit: ['settings.write'],
  },
} as const;export type ModuleKey = keyof typeof MODULE_PERMS;

/**
 * Hook to check if user can access a module
 * 
 * @example
 * const { canView, canEdit } = useModuleAccess('directory');
 * 
 * {canView && <DirectoryMenu />}
 * {canEdit && <CreateButton />}
 */
export function useModuleAccess(module: ModuleKey) {
  const { can, hasAnyPermission } = usePermissions();
  
  const modulePerms = MODULE_PERMS[module];
  if (!modulePerms) {
    if (import.meta.env.DEV) {
      console.warn(`⚠️ useModuleAccess: Unknown module "${module}"`);
    }
    return { canView: false, canEdit: false };
  }

  const canView = useMemo(() => {
    return hasAnyPermission([...modulePerms.view]);
  }, [hasAnyPermission, modulePerms.view]);

  const canEdit = useMemo(() => {
    return canView && hasAnyPermission([...modulePerms.edit]);
  }, [canView, hasAnyPermission, modulePerms.edit]);

  return { canView, canEdit };
}
