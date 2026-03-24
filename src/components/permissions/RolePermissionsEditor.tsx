/**
 * RolePermissionsEditor — groups permissions by module following sidebar order.
 * Module cards appear in the same order as the sidebar navigation.
 */

import React from 'react';
import { Loader2, CheckSquare, Square } from 'lucide-react';
import type { PermissionRow } from '../../hooks/useRolesAdmin';

type Props = {
  permissions: PermissionRow[];
  selected: Set<string>;
  onToggle: (code: string) => void;
  onSelectAllInModule: (module: string) => void;
  loading?: boolean;
};

// Sidebar module order — cards will appear in this sequence.
const MODULE_ORDER = [
  'dashboard',
  'directory',
  'sales',
  'catalog',
  'inventory',
  'manufacturing',
  'financials',
  'partners',
  'settings',
];

// Merge stray legacy modules into their canonical group.
// Any codes that were previously under separate modules (purchasing, quotes, etc.)
// have been fixed at DB level, but this acts as a frontend safety net.
const MODULE_MERGE: Record<string, string> = {
  purchasing:  'inventory',
  quotes:      'sales',
  proposals:   'sales',
  salesorders: 'sales',
  admin:       'settings',
  org:         'settings',
  reports:     'settings',
  portal:      'financials',
};

const MODULE_DISPLAY_LABEL: Record<string, string> = {
  dashboard:    'Dashboard',
  directory:    'Directory',
  sales:        'Sales',
  catalog:      'Catalog',
  inventory:    'Inventory',
  manufacturing:'Manufacturing',
  financials:   'Financials',
  partners:     'Partners',
  settings:     'Settings & Admin',
};

// Sub-group labels inside a module card — override auto-generated label when needed.
const RESOURCE_LABEL_OVERRIDE: Record<string, string> = {
  // inventory
  'inventory':                      'Module Access',
  'inventory.purchase_orders':      'Purchase Orders',
  'inventory.receipts':             'Receipts',
  'inventory.transactions':         'Transactions',
  'inventory.warehouse':            'Warehouses',
  'inventory.adjustments':          'Adjustments',
  'inventory.material_demand':      'Material Demand',
  // legacy purchasing codes now under inventory
  'purchasing':                     'Purchasing (Legacy)',
  // sales
  'sales':                          'Module Access',
  'sales.orders':                   'Sales Orders',
  'sales.quotes':                   'Quotes',
  'sales.proposals':                'Proposals',
  'salesorders':                    'Sales Orders (Legacy)',
  'quotes':                         'Quotes (Legacy)',
  'proposals':                      'Proposals (Legacy)',
  // directory
  'directory':                      'Module Access',
  'directory.contacts':             'Contacts',
  'directory.customers':            'Customers',
  // manufacturing
  'manufacturing':                  'Module Access',
  'manufacturing.mo':               'Manufacturing Orders',
  'manufacturing.wo':               'Work Orders',
  'manufacturing.calendar':         'Production Calendar',
  'manufacturing.costs':            'Costs',
  'manufacturing.cutopt':           'Cut Optimization',
  'manufacturing.finished_goods':   'Finished Goods',
  'manufacturing.workstation':      'Workstation',
  'manufacturing.mo.attachments':   'MO Attachments',
  'manufacturing.mo.lines':         'MO Lines',
  'manufacturing.mo.materials':     'MO Materials',
  'manufacturing.mo.notes':         'MO Notes',
  'manufacturing.mo.overview':      'MO Overview',
  'manufacturing.mo.schedule':      'MO Schedule',
  'manufacturing.mo.timeline':      'MO Timeline',
  'manufacturing.mo.work_orders':   'MO Work Orders',
  // financials
  'financials':                     'Module Access',
  'financials.invoices':            'Invoices',
  'financials.accounts':            'Dealer Accounts',
  'financials.payments':            'Payments',
  'financials.bills':               'Bills',
  'financials.purchase_orders':     'AP Purchase Orders',
  'financials.vendor_accounts':     'Vendor Accounts',
  'financials.vendor_payments':     'Vendor Payments',
  'portal.financials':              'My Financials (Portal)',
  'portal.financials.invoices':     'Portal – Invoices',
  'portal.financials.payments':     'Portal – Payments',
  'portal.financials.statement':    'Portal – Statement',
  'portal.financials.invoice_pdf':  'Portal – Invoice PDF',
  // catalog
  'catalog':                        'Module Access',
  'catalog.items':                  'Items',
  'catalog.bom':                    'BOM',
  // settings
  'settings':                       'Settings Access',
  'org.users':                      'Organization Users',
  'roles':                          'Roles & Permissions',
  'reports':                        'Reports',
  // partners
  'partners':                       'Module Access',
  // dashboard
  'dashboard':                      'Module Access',
};

const ACTION_TOKENS = new Set([
  'read', 'write', 'create', 'edit', 'archive',
  'delete', 'void', 'approve', 'manage', 'copy',
]);

const ACTION_ORDER: Record<string, number> = {
  read: 0, write: 1, create: 2, edit: 3, approve: 4,
  manage: 5, copy: 6, archive: 7, delete: 8, void: 9,
};

function getResourceLabel(parentKey: string): string {
  if (RESOURCE_LABEL_OVERRIDE[parentKey]) return RESOURCE_LABEL_OVERRIDE[parentKey];
  return parentKey
    .split('.')
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1).replace(/_/g, ' '))
    .join(' › ');
}

export function RolePermissionsEditor({
  permissions,
  selected,
  onToggle,
  onSelectAllInModule,
  loading = false,
}: Props) {
  // Group by canonical module, applying merge map as safety net.
  const byModule = React.useMemo(() => {
    const map = new Map<string, PermissionRow[]>();
    for (const p of permissions) {
      const raw = (p.module || 'other').trim().toLowerCase();
      const canonical = MODULE_MERGE[raw] ?? raw;
      if (!map.has(canonical)) map.set(canonical, []);
      map.get(canonical)!.push(p);
    }
    return map;
  }, [permissions]);

  // Sort module keys following MODULE_ORDER; unknown modules go at the end.
  const orderedModules = React.useMemo(() => {
    const known = MODULE_ORDER.filter((m) => byModule.has(m));
    const unknown = Array.from(byModule.keys())
      .filter((m) => !MODULE_ORDER.includes(m))
      .sort();
    return [...known, ...unknown];
  }, [byModule]);

  if (loading) {
    return (
      <div className="py-8 flex justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-gray-400" />
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="mb-3">
        <span className="text-sm font-medium text-gray-700">
          Permissions ({selected.size} assigned)
        </span>
      </div>
      {selected.size === 0 && (
        <p className="text-sm text-amber-700 mb-3">No permissions assigned.</p>
      )}

      <div className="space-y-4 max-h-[50vh] overflow-y-auto pr-1">
        {orderedModules.map((module) => {
          const perms = byModule.get(module)!;
          const allChecked = perms.every((p) => selected.has(p.code));

          // Group by resource prefix (strip last token if it's an action).
          const groups = new Map<string, PermissionRow[]>();
          for (const p of perms) {
            const parts = p.code.split('.');
            const last = parts[parts.length - 1] ?? '';
            const parentKey =
              parts.length > 1 && ACTION_TOKENS.has(last)
                ? parts.slice(0, -1).join('.')
                : p.code;
            if (!groups.has(parentKey)) groups.set(parentKey, []);
            groups.get(parentKey)!.push(p);
          }

          // Module-access group (e.g. `inventory.read`, `inventory.write`) goes first,
          // then sub-resources alphabetically.
          const moduleAccessKey = module; // e.g. 'inventory'
          const orderedGroups = Array.from(groups.entries()).sort(([aKey], [bKey]) => {
            if (aKey === moduleAccessKey) return -1;
            if (bKey === moduleAccessKey) return 1;
            return getResourceLabel(aKey).localeCompare(getResourceLabel(bKey));
          });

          return (
            <div key={module} className="border border-gray-200 rounded-lg overflow-hidden">
              {/* Module header */}
              <div className="flex items-center justify-between px-4 py-2.5 bg-gray-50 border-b border-gray-200">
                <span className="text-sm font-semibold text-gray-900">
                  {MODULE_DISPLAY_LABEL[module] ?? module.charAt(0).toUpperCase() + module.slice(1)}
                </span>
                <button
                  type="button"
                  onClick={() => onSelectAllInModule(module)}
                  className="flex items-center gap-1.5 text-xs text-gray-500 hover:text-gray-900 transition-colors"
                >
                  {allChecked ? (
                    <CheckSquare className="w-3.5 h-3.5 text-blue-600" />
                  ) : (
                    <Square className="w-3.5 h-3.5 text-gray-400" />
                  )}
                  {allChecked ? 'Clear all' : 'Select all'}
                </button>
              </div>

              {/* Resource sub-groups */}
              <div className="p-3 space-y-2.5">
                {orderedGroups.map(([parentKey, groupPerms]) => {
                  const sorted = [...groupPerms].sort((a, b) => {
                    const aParts = a.code.split('.');
                    const bParts = b.code.split('.');
                    const aAction = aParts[aParts.length - 1] ?? '';
                    const bAction = bParts[bParts.length - 1] ?? '';
                    const oa = ACTION_ORDER[aAction] ?? 99;
                    const ob = ACTION_ORDER[bAction] ?? 99;
                    return oa !== ob ? oa - ob : a.code.localeCompare(b.code);
                  });

                  // Pin .read as the first checkbox (parent/view permission).
                  const readCode = `${parentKey}.read`;
                  const readPerm = sorted.find((p) => p.code === readCode) ?? null;
                  const orderedPerms = readPerm
                    ? [readPerm, ...sorted.filter((p) => p.code !== readCode)]
                    : sorted;

                  const resourceLbl = getResourceLabel(parentKey);
                  const isModuleAccess = parentKey === moduleAccessKey;

                  return (
                    <div
                      key={parentKey}
                      className={`rounded-md border px-3 py-2 ${
                        isModuleAccess
                          ? 'border-blue-100 bg-blue-50/40'
                          : 'border-gray-100'
                      }`}
                    >
                      <div className="text-[10px] font-semibold uppercase tracking-wider text-gray-400 mb-1.5">
                        {isModuleAccess ? '● Enable / View Module' : resourceLbl}
                      </div>
                      <ul className="space-y-1.5">
                        {orderedPerms.map((p, index) => (
                          <li key={p.code}>
                            <label className="flex items-start gap-2 text-sm cursor-pointer group">
                              <input
                                type="checkbox"
                                checked={selected.has(p.code)}
                                onChange={() => onToggle(p.code)}
                                className="mt-0.5 rounded border-gray-300 shrink-0"
                              />
                              <span className="font-mono text-gray-700 group-hover:text-gray-900 leading-snug">
                                {p.code}
                              </span>
                              {index === 0 && readPerm?.code === p.code && (
                                <span className="text-blue-600 text-xs font-medium shrink-0">← View</span>
                              )}
                              {p.description != null && p.description !== '' && !(index === 0 && readPerm?.code === p.code) && (
                                <span className="text-gray-400 text-xs leading-snug">— {p.description}</span>
                              )}
                            </label>
                          </li>
                        ))}
                      </ul>
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
