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
  const byModule = React.useMemo(() => {
    const map = new Map<string, PermissionRow[]>();
    for (const p of permissions) {
      const key = p.module || 'Other';
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
          const allChecked = perms.every((p) => selected.has(p.code));
          return (
            <div key={module} className="border border-gray-200 rounded p-3">
              <button
                type="button"
                onClick={() => onSelectAllInModule(module)}
                className="flex items-center gap-2 text-sm font-medium text-gray-900 mb-2"
              >
                {allChecked ? (
                  <CheckSquare className="w-4 h-4 text-blue-600" />
                ) : (
                  <Square className="w-4 h-4 text-gray-400" />
                )}
                {module} — Select all
              </button>
              <ul className="space-y-1 pl-6">
                {perms.map((p) => (
                  <li key={p.code}>
                    <label className="flex items-center gap-2 text-sm cursor-pointer">
                      <input
                        type="checkbox"
                        checked={selected.has(p.code)}
                        onChange={() => onToggle(p.code)}
                        className="rounded border-gray-300"
                      />
                      <span className="font-mono text-gray-800">{p.code}</span>
                      {p.description != null && p.description !== '' && (
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
}
