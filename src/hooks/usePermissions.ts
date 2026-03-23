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
    view: ['manufacturing.read', 'manufacturing.wo.read', 'manufacturing.workstation.read',
           'manufacturing.cutopt.read', 'manufacturing.mo.read', 'manufacturing.calendar.read'],
    edit: ['manufacturing.write'],
  },
  financials: {
    view: ['financials.read'],
    edit: ['financials.write'],
  },
  partners: {
    view: ['settings.read', 'partners.read'],
    edit: ['settings.write', 'partners.write'],
  },
  settings: {
    view: ['settings.read'],
    edit: ['settings.write'],
  },
} as const;export type ModuleKey = keyof typeof MODULE_PERMS;

/**
 * Granular CRUD permission codes per module.
 * Used by useGranularAccess to gate create/edit/archive/delete/void actions.
 */
export const GRANULAR_PERMS = {
  directory: {
    create: ['directory.create', 'directory.write'],
    edit:    ['directory.edit', 'directory.write'],
    archive: ['directory.archive'],
    delete:  ['directory.delete'],
  },
  catalog: {
    create: ['catalog.create', 'catalog.write'],
    edit:    ['catalog.edit', 'catalog.write'],
    archive: ['catalog.archive'],
    delete:  ['catalog.delete'],
  },
  quotes: {
    create: ['quotes.create', 'quotes.edit'],
    edit:    ['quotes.edit'],
    archive: ['quotes.archive'],
    delete:  ['quotes.delete'],
  },
  proposals: {
    create: ['proposals.create'],
    archive: ['proposals.archive'],
    delete:  ['proposals.delete'],
  },
  salesorders: {
    create: ['salesorders.create', 'salesorders.edit'],
    edit:    ['salesorders.edit'],
    archive: ['salesorders.archive'],
    delete:  ['salesorders.delete'],
  },
  manufacturing: {
    create: ['manufacturing.create', 'manufacturing.write'],
    edit:    ['manufacturing.edit', 'manufacturing.write'],
    archive: ['manufacturing.archive'],
    delete:  ['manufacturing.delete'],
  },
  inventory: {
    create: ['inventory.create', 'inventory.write'],
    edit:    ['inventory.edit', 'inventory.write'],
    archive: ['inventory.archive'],
    delete:  ['inventory.delete'],
  },
  financials: {
    create: ['financials.create', 'financials.write'],
    edit:    ['financials.edit', 'financials.write'],
    archive: ['financials.archive'],
    delete:  ['financials.delete'],
    void:    ['financials.void'],
  },
} as const;

export type GranularModule = keyof typeof GRANULAR_PERMS;
type GranularAction = 'create' | 'edit' | 'archive' | 'delete' | 'void';

/**
 * Hook for granular CRUD permission checks on a module.
 *
 * @example
 * const { canCreate, canEdit, canArchive, canDelete } = useGranularAccess('directory');
 * {canDelete && <DeleteButton />}
 * {canArchive && <ArchiveButton />}
 */
export function useGranularAccess(module: GranularModule) {
  const { hasAnyPermission } = usePermissions();

  const perms = GRANULAR_PERMS[module];

  const check = (action: GranularAction): boolean => {
    const codes = (perms as Record<string, readonly string[]>)[action];
    if (!codes) return false;
    return hasAnyPermission([...codes]);
  };

  return useMemo(() => ({
    canCreate:  check('create'),
    canEdit:    check('edit'),
    canArchive: check('archive'),
    canDelete:  check('delete'),
    canVoid:    check('void'),
  }), [hasAnyPermission, module]);
}

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

/**
 * Granular manufacturing sub-permissions.
 * Legacy `manufacturing.read` acts as a wildcard — grants all sub-permissions.
 * New granular codes allow fine-grained control per area.
 */
export function useManufacturingAccess() {
  const { can } = usePermissions();

  return useMemo(() => {
    const legacy = can('manufacturing.read');
    return {
      canViewMOs:          legacy || can('manufacturing.mo.read'),
      canEditMOs:          can('manufacturing.write') || can('manufacturing.mo.write'),
      canViewWOs:          legacy || can('manufacturing.wo.read'),
      canEditWOs:          legacy || can('manufacturing.wo.write'),
      canViewWorkstation:  legacy || can('manufacturing.workstation.read'),
      canViewCutOpt:       legacy || can('manufacturing.cutopt.read'),
      canViewCalendar:     legacy || can('manufacturing.calendar.read'),
      canViewCosts:        legacy || can('manufacturing.costs.read'),
    };
  }, [can]);
}
