/**
 * Editor de permisos por rol: agrupa por module, checkbox por permiso, Select all in module.
 * Si selected.size === 0 => "No permissions assigned."
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

export function RolePermissionsEditor({
  permissions,
  selected,
  onToggle,
  onSelectAllInModule,
  loading = false,
}: Props) {
  const ACTION_TOKENS = new Set([
    'read',
    'write',
    'create',
    'edit',
    'archive',
    'delete',
    'void',
    'approve',
    'manage',
  ]);

  const ACTION_ORDER: Record<string, number> = {
    read: 0,
    write: 1,
    create: 2,
    edit: 3,
    archive: 4,
    delete: 5,
    void: 6,
    approve: 7,
    manage: 8,
  };

  const moduleLabel = (value: string) =>
    value
      .split('.')
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(' ');

  const resourceLabel = (module: string, parentKey: string) => {
    const base = parentKey.startsWith(`${module}.`) ? parentKey.slice(module.length + 1) : parentKey;
    if (!base || base.toLowerCase() === module.toLowerCase()) return 'Module Access';
    return base
      .split('.')
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(' ');
  };

  const byModule = React.useMemo(() => {
    const map = new Map<string, PermissionRow[]>();
    for (const p of permissions) {
      const key = (p.module || 'other').trim().toLowerCase();
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(p);
    }
    return map;
  }, [permissions]);

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
      <div className="space-y-4 max-h-[50vh] overflow-y-auto">
        {Array.from(byModule.entries()).map(([module, perms]) => {
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

          const orderedGroups = Array.from(groups.entries()).sort((a, b) => {
            const aLabel = resourceLabel(module, a[0]).toLowerCase();
            const bLabel = resourceLabel(module, b[0]).toLowerCase();
            return aLabel.localeCompare(bLabel);
          });
          const allChecked = perms.every((p) => selected.has(p.code));

          return (
            <div key={module} className="border border-gray-200 rounded p-3">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-medium text-gray-900">{moduleLabel(module)}</span>
                <button
                  type="button"
                  onClick={() => onSelectAllInModule(module)}
                  className="flex items-center gap-1 text-xs text-gray-600 hover:text-gray-900"
                >
                  {allChecked ? (
                    <CheckSquare className="w-3.5 h-3.5 text-blue-600" />
                  ) : (
                    <Square className="w-3.5 h-3.5 text-gray-400" />
                  )}
                  {allChecked ? 'Clear all' : 'Select all'}
                </button>
              </div>
              <div className="space-y-3 pl-2">
                {orderedGroups.map(([parentKey, groupPerms]) => {
                  const sortedGroup = [...groupPerms].sort((a, b) => {
                    const aParts = a.code.split('.');
                    const bParts = b.code.split('.');
                    const aAction = aParts[aParts.length - 1] ?? '';
                    const bAction = bParts[bParts.length - 1] ?? '';
                    const oa = ACTION_ORDER[aAction] ?? 99;
                    const ob = ACTION_ORDER[bAction] ?? 99;
                    if (oa !== ob) return oa - ob;
                    return a.code.localeCompare(b.code);
                  });
                  const readCode = `${parentKey}.read`;
                  const readPerm = sortedGroup.find((p) => p.code === readCode) ?? null;
                  const orderedPerms = readPerm
                    ? [readPerm, ...sortedGroup.filter((p) => p.code !== readCode)]
                    : sortedGroup;

                  return (
                    <div key={parentKey} className="border border-gray-100 rounded-md p-2.5">
                      <div className="text-xs font-semibold uppercase tracking-wide text-gray-500 mb-2">
                        {resourceLabel(module, parentKey)}
                      </div>
                      <ul className="space-y-1.5 pl-2">
                        {orderedPerms.map((p, index) => (
                          <li key={p.code}>
                            <label className="flex items-center gap-2 text-sm cursor-pointer">
                              <input
                                type="checkbox"
                                checked={selected.has(p.code)}
                                onChange={() => onToggle(p.code)}
                                className="rounded border-gray-300"
                              />
                              <span className="font-mono text-gray-800">{p.code}</span>
                              {index === 0 && readPerm?.code === p.code && (
                                <span className="text-blue-700 text-xs font-medium">— Parent (View)</span>
                              )}
                              {!(index === 0 && readPerm?.code === p.code) && p.description != null && p.description !== '' && (
                                <span className="text-gray-500">— {p.description}</span>
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
