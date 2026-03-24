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
    view: ['directory.customers.read', 'directory.contacts.read'],
    edit: ['directory.customers.write', 'directory.contacts.write'],
  },
  catalog: {
    view: ['catalog.read', 'catalog.items.read', 'catalog.bom.read'],
    edit: ['catalog.write', 'catalog.items.write', 'catalog.bom.write'],
  },
  inventory: {
    view: [
      'inventory.warehouse.read',
      'inventory.purchase_orders.read',
      'inventory.receipts.read',
      'inventory.transactions.read',
      'inventory.adjustments.read',
      'inventory.material_demand.read',
    ],
    edit: [
      'inventory.warehouse.write',
      'inventory.purchase_orders.write',
      'inventory.receipts.write',
      'inventory.transactions.write',
      'inventory.adjustments.write',
      'inventory.material_demand.write',
    ],
  },
  sales: {
    view: ['sales.quotes.read', 'sales.proposals.read', 'sales.orders.read'],
    edit: ['sales.quotes.write', 'sales.proposals.write', 'sales.orders.write'],
  },
  manufacturing: {
    view: [
      'manufacturing.mo.read',
      'manufacturing.wo.read',
      'manufacturing.calendar.read',
      'manufacturing.finished_goods.read',
      'manufacturing.cutopt.read',
    ],
    edit: [
      'manufacturing.mo.write',
      'manufacturing.wo.write',
      'manufacturing.calendar.write',
      'manufacturing.finished_goods.write',
      'manufacturing.cutopt.write',
    ],
  },
  financials: {
    view: [
      'financials.accounts.read',
      'financials.invoices.read',
      'financials.payments.read',
      'financials.vendor_accounts.read',
      'financials.bills.read',
      'financials.vendor_payments.read',
      'financials.purchase_orders.read',
    ],
    edit: [
      'financials.accounts.write',
      'financials.invoices.write',
      'financials.payments.write',
      'financials.vendor_accounts.write',
      'financials.bills.write',
      'financials.vendor_payments.write',
      'financials.purchase_orders.write',
    ],
  },
  partners: {
    view: ['partners.read'],
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
    create: ['sales.quotes.write'],
    edit:    ['sales.quotes.write'],
    archive: ['sales.quotes.write'],
    delete:  ['sales.quotes.write'],
  },
  proposals: {
    create: ['sales.proposals.write'],
    archive: ['sales.proposals.write'],
    delete:  ['sales.proposals.write'],
  },
  salesorders: {
    create: ['sales.orders.write'],
    edit:    ['sales.orders.write'],
    archive: ['sales.orders.write'],
    delete:  ['sales.orders.write'],
  },
  manufacturing: {
    create: ['manufacturing.mo.write', 'manufacturing.wo.write'],
    edit:    ['manufacturing.mo.write', 'manufacturing.wo.write'],
    archive: ['manufacturing.mo.write'],
    delete:  ['manufacturing.mo.write'],
  },
  inventory: {
    create: ['inventory.transactions.write', 'inventory.purchase_orders.write'],
    edit:    ['inventory.transactions.write', 'inventory.purchase_orders.write'],
    archive: ['inventory.transactions.write'],
    delete:  ['inventory.transactions.write'],
  },
  financials: {
    create: ['financials.invoices.write'],
    edit:    ['financials.invoices.write'],
    archive: ['financials.invoices.write'],
    delete:  ['financials.invoices.write'],
    void:    ['financials.invoices.write'],
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
    return {
      canViewMOs:          can('manufacturing.mo.read'),
      canEditMOs:          can('manufacturing.mo.write'),
      canViewWOs:          can('manufacturing.wo.read'),
      canEditWOs:          can('manufacturing.wo.write'),
      canViewWorkstation:  can('manufacturing.wo.read'),
      canViewCutOpt:       can('manufacturing.cutopt.read') || can('manufacturing.wo.read'),
      canViewCalendar:     can('manufacturing.calendar.read'),
      canViewCosts:        can('manufacturing.mo.read'),
    };
  }, [can]);
}

function moduleFromPath(pathname: string): ModuleKey | null {
  const first = (pathname.split('/')[1] || '').toLowerCase();
  if (first === 'dashboard') return 'dashboard';
  if (first === 'directory') return 'directory';
  if (first === 'sales') return 'sales';
  if (first === 'catalog') return 'catalog';
  if (first === 'inventory') return 'inventory';
  if (first === 'manufacturing') return 'manufacturing';
  if (first === 'financials') return 'financials';
  if (first === 'my-financials') return 'financials';
  if (first === 'partners') return 'partners';
  if (first === 'settings') return 'settings';
  return null;
}

export function getReadPermissionsForPath(pathname: string): string[] {
  const cleanPath = pathname.split('?')[0].split('#')[0];
  const route = '/' + cleanPath.split('/').slice(1, 3).join('/');
  const routeMap: Record<string, string[]> = {
    '/dashboard': ['dashboard.read'],
    '/directory/customers': ['directory.customers.read'],
    '/directory/contacts': ['directory.contacts.read'],
    '/catalog/items': ['catalog.read'],
    '/catalog/bom': ['catalog.write'],
    '/sales/quotes': ['sales.quotes.read'],
    '/sales/proposals': ['sales.proposals.read'],
    '/sales/orders': ['sales.orders.read'],
    '/inventory/warehouse': ['inventory.warehouse.read'],
    '/inventory/purchase-orders': ['inventory.purchase_orders.read'],
    '/inventory/receipts': ['inventory.receipts.read'],
    '/inventory/transactions': ['inventory.transactions.read'],
    '/inventory/adjustments': ['inventory.adjustments.read'],
    '/inventory/material-demand': ['inventory.material_demand.read'],
    '/manufacturing/manufacturing-orders': ['manufacturing.mo.read'],
    '/manufacturing/work-orders': ['manufacturing.wo.read'],
    '/manufacturing/calendar': ['manufacturing.calendar.read'],
    '/manufacturing/finished-goods': ['manufacturing.finished_goods.read'],
    '/manufacturing/cut-optimization': ['manufacturing.cutopt.read', 'manufacturing.wo.read'],
    '/financials/accounts': ['financials.accounts.read'],
    '/financials/invoices': ['financials.invoices.read', 'portal.financials.invoices.read'],
    '/financials/payments': ['financials.payments.read', 'portal.financials.payments.read'],
    '/financials/statement': ['portal.financials.statement.read'],
    '/my-financials/invoices': ['portal.financials.invoices.read'],
    '/my-financials/payments': ['portal.financials.payments.read'],
    '/my-financials/statement': ['portal.financials.statement.read'],
    '/my-financials/accounts': ['portal.financials.statement.read'],
    '/financials/vendor-accounts': ['financials.vendor_accounts.read'],
    '/financials/purchase-orders': ['financials.purchase_orders.read'],
    '/financials/bills': ['financials.bills.read'],
    '/financials/vendor-payments': ['financials.vendor_payments.read'],
  };
  const direct = routeMap[route];
  if (direct) return direct;
  const mod = moduleFromPath(cleanPath);
  if (!mod) return [];
  return [...MODULE_PERMS[mod].view];
}

export function canReadPath(can: (permissionCode: string) => boolean, pathname: string): boolean {
  const required = getReadPermissionsForPath(pathname);
  if (required.length === 0) return true;
  return required.some((perm) => can(perm));
}
