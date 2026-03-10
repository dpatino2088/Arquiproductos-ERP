import { useState, useMemo, useCallback, useRef, useEffect } from 'react';
import { useBOMRoles, type RoleType, type CatalogRole } from '../../../hooks/useBOMRoles';
import { useUIStore } from '../../../stores/ui-store';
import {
  Search,
  Shield,
  Trash2,
  Edit,
  ArrowLeft,
  Users,
  Layers,
  Pencil,
  Check,
  X,
  Plus,
} from 'lucide-react';

const ROLE_TYPE_LABELS: Record<RoleType, string> = {
  parent_only: 'Parent',
  child_only: 'Child',
  both: 'Both',
};

const ROLE_TYPE_COLORS: Record<RoleType, string> = {
  parent_only: 'bg-gray-100 text-gray-600',
  child_only: 'bg-gray-100 text-gray-600',
  both: 'bg-gray-100 text-gray-500',
};

type PageMode = 'overview' | 'edit';

export default function BOMRolesTab() {
  const {
    roles,
    dependencies,
    productTypeRules,
    productTypes,
    loading,
    error,
    createRole,
    updateRoleType,
    toggleRoleActive,
    renameRole,
    deleteRole,
    countRoleUsage,
    addDependency,
    removeDependency,
    upsertProductTypeRule,
    removeProductTypeRule,
  } = useBOMRoles();

  const [pageMode, setPageMode] = useState<PageMode>('overview');
  const [search, setSearch] = useState('');
  const [selectedRole, setSelectedRole] = useState<string | null>(null);
  const [filterType, setFilterType] = useState<RoleType | 'all'>('all');
  const [showInactive, setShowInactive] = useState(false);

  // Create role state
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [newRoleCode, setNewRoleCode] = useState('');
  const [newRoleLabel, setNewRoleLabel] = useState('');
  const [newRoleType, setNewRoleType] = useState<RoleType>('both');
  const [isCreating, setIsCreating] = useState(false);

  // Inline rename state
  const [renamingRole, setRenamingRole] = useState<string | null>(null);
  const [renameValue, setRenameValue] = useState('');
  const renameInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (renamingRole && renameInputRef.current) {
      renameInputRef.current.focus();
      renameInputRef.current.select();
    }
  }, [renamingRole]);

  // ── Derived data for overview tables ──

  const parentRolesList = useMemo(
    () => roles.filter((r) => r.active && r.role_type !== 'child_only'),
    [roles],
  );

  const childRolesList = useMemo(
    () => roles.filter((r) => r.active && r.role_type !== 'parent_only'),
    [roles],
  );

  const childrenCountByParent = useMemo(() => {
    const map: Record<string, number> = {};
    for (const d of dependencies) {
      map[d.parent_role_code] = (map[d.parent_role_code] ?? 0) + 1;
    }
    return map;
  }, [dependencies]);

  const parentsCountByChild = useMemo(() => {
    const map: Record<string, number> = {};
    for (const d of dependencies) {
      map[d.role_code] = (map[d.role_code] ?? 0) + 1;
    }
    return map;
  }, [dependencies]);

  const childrenOfRole = useCallback(
    (roleCode: string) =>
      dependencies
        .filter((d) => d.parent_role_code === roleCode)
        .map((d) => roles.find((r) => r.role_code === d.role_code)?.label ?? d.role_code),
    [dependencies, roles],
  );

  const parentsOfRole = useCallback(
    (roleCode: string) =>
      dependencies
        .filter((d) => d.role_code === roleCode)
        .map((d) => roles.find((r) => r.role_code === d.parent_role_code)?.label ?? d.parent_role_code),
    [dependencies, roles],
  );

  // ── Edit-mode derived data ──

  const filteredRoles = useMemo(() => {
    let list = roles;
    if (!showInactive) list = list.filter((r) => r.active);
    if (filterType !== 'all') list = list.filter((r) => r.role_type === filterType);
    if (search) {
      const q = search.toLowerCase();
      list = list.filter(
        (r) => r.label.toLowerCase().includes(q) || r.role_code.toLowerCase().includes(q),
      );
    }
    return list;
  }, [roles, search, filterType, showInactive]);

  const selected: CatalogRole | null = useMemo(
    () => roles.find((r) => r.role_code === selectedRole) ?? null,
    [roles, selectedRole],
  );

  const depsForSelected = useMemo(
    () => (selectedRole ? dependencies.filter((d) => d.role_code === selectedRole) : []),
    [dependencies, selectedRole],
  );

  const childrenOfSelected = useMemo(
    () => (selectedRole ? dependencies.filter((d) => d.parent_role_code === selectedRole) : []),
    [dependencies, selectedRole],
  );

  const rulesForSelected = useMemo(
    () => (selectedRole ? productTypeRules.filter((r) => r.role_code === selectedRole) : []),
    [productTypeRules, selectedRole],
  );

  const parentRolesForEdit = useMemo(
    () => roles.filter((r) => r.role_type !== 'child_only' && r.active),
    [roles],
  );

  const selectRole = useCallback((code: string) => {
    setSelectedRole(code);
  }, []);

  const enterEditForRole = useCallback((code: string) => {
    setSelectedRole(code);
    setPageMode('edit');
  }, []);

  // ── Inline rename / delete ──

  const startRename = useCallback((roleCode: string, currentLabel: string) => {
    setRenamingRole(roleCode);
    setRenameValue(currentLabel);
  }, []);

  const confirmRename = useCallback(async () => {
    if (!renamingRole) return;
    try {
      await renameRole(renamingRole, renameValue);
      useUIStore.getState().addNotification({ type: 'success', title: 'Renamed', message: `Role renamed to "${renameValue.trim()}"` });
    } catch (err) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed to rename' });
    }
    setRenamingRole(null);
  }, [renamingRole, renameValue, renameRole]);

  const cancelRename = useCallback(() => {
    setRenamingRole(null);
  }, []);

  const handleCreateRole = useCallback(async () => {
    if (!newRoleLabel.trim()) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Validation', message: 'Label is required' });
      return;
    }
    const code = newRoleCode.trim() || newRoleLabel.trim().toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '');
    setIsCreating(true);
    try {
      const created = await createRole(code, newRoleLabel.trim(), newRoleType);
      useUIStore.getState().addNotification({ type: 'success', title: 'Created', message: `Role "${created.label}" created` });
      setShowCreateForm(false);
      setNewRoleCode('');
      setNewRoleLabel('');
      setNewRoleType('both');
      setSelectedRole(created.role_code);
    } catch (err) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed to create role' });
    } finally {
      setIsCreating(false);
    }
  }, [newRoleCode, newRoleLabel, newRoleType, createRole]);

  const handleDeleteRole = useCallback(async (roleCode: string, label: string) => {
    try {
      const usage = await countRoleUsage(roleCode);
      const parts: string[] = [];
      if (usage.catalogItems > 0) parts.push(`${usage.catalogItems} catalog item(s)`);
      if (usage.bomComponents > 0) parts.push(`${usage.bomComponents} BOM component(s)`);
      if (usage.categoryMaps > 0) parts.push(`${usage.categoryMaps} category mapping(s)`);

      let msg = `Delete role "${label}" (${roleCode})?`;
      if (parts.length > 0) {
        msg += `\n\nThis role is referenced by:\n• ${parts.join('\n• ')}\n\nThese references will be unlinked (set to null / removed).`;
      }
      msg += '\n\nThis action cannot be undone.';

      if (!window.confirm(msg)) return;

      await deleteRole(roleCode);
      if (selectedRole === roleCode) setSelectedRole(null);
      useUIStore.getState().addNotification({ type: 'success', title: 'Deleted', message: `Role "${label}" deleted` });
    } catch (err) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed to delete role' });
    }
  }, [deleteRole, countRoleUsage, selectedRole]);

  // ── Mutations ──

  const handleRoleTypeChange = useCallback(
    async (roleCode: string, roleType: RoleType) => {
      try {
        await updateRoleType(roleCode, roleType);
      } catch (err) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed to update role type' });
      }
    },
    [updateRoleType],
  );

  const handleToggleActive = useCallback(
    async (roleCode: string, active: boolean) => {
      try {
        await toggleRoleActive(roleCode, active);
      } catch (err) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed to toggle role' });
      }
    },
    [toggleRoleActive],
  );

  const handleToggleDependency = useCallback(
    async (parentRoleCode: string, checked: boolean) => {
      if (!selectedRole) return;
      try {
        if (checked) await addDependency(selectedRole, parentRoleCode);
        else await removeDependency(selectedRole, parentRoleCode);
      } catch (err) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed to update dependency' });
      }
    },
    [selectedRole, addDependency, removeDependency],
  );

  const handleSelectAllParents = useCallback(
    async (selectAll: boolean) => {
      if (!selectedRole) return;
      const eligible = parentRolesForEdit.filter((r) => r.role_code !== selectedRole);
      try {
        for (const pr of eligible) {
          const isLinked = depsForSelected.some((d) => d.parent_role_code === pr.role_code);
          if (selectAll && !isLinked) await addDependency(selectedRole, pr.role_code);
          else if (!selectAll && isLinked) await removeDependency(selectedRole, pr.role_code);
        }
      } catch (err) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed to update dependencies' });
      }
    },
    [selectedRole, parentRolesForEdit, depsForSelected, addDependency, removeDependency],
  );

  const handleRemoveChildDep = useCallback(
    async (childRoleCode: string) => {
      if (!selectedRole) return;
      try {
        await removeDependency(childRoleCode, selectedRole);
      } catch (err) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed to remove child dependency' });
      }
    },
    [selectedRole, removeDependency],
  );

  const handleSelectAllProductTypes = useCallback(
    async (selectAll: boolean) => {
      if (!selectedRole) return;
      try {
        for (const pt of productTypes) {
          const isAssigned = rulesForSelected.some((r) => r.product_type_id === pt.id);
          if (selectAll && !isAssigned) await upsertProductTypeRule(pt.id, selectedRole, false);
          else if (!selectAll && isAssigned) await removeProductTypeRule(pt.id, selectedRole);
        }
      } catch (err) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed to update product types' });
      }
    },
    [selectedRole, productTypes, rulesForSelected, upsertProductTypeRule, removeProductTypeRule],
  );

  const handleToggleProductType = useCallback(
    async (productTypeId: string, checked: boolean) => {
      if (!selectedRole) return;
      try {
        if (checked) await upsertProductTypeRule(productTypeId, selectedRole, false);
        else await removeProductTypeRule(productTypeId, selectedRole);
      } catch (err) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed to update product type rule' });
      }
    },
    [selectedRole, upsertProductTypeRule, removeProductTypeRule],
  );

  const handleToggleRequired = useCallback(
    async (productTypeId: string, isRequired: boolean) => {
      if (!selectedRole) return;
      try {
        await upsertProductTypeRule(productTypeId, selectedRole, isRequired);
      } catch (err) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed to update required flag' });
      }
    },
    [selectedRole, upsertProductTypeRule],
  );

  // ── Loading / Error states ──

  if (loading) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4" />
        <p className="text-sm text-gray-600">Loading roles...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
        <p className="text-sm text-red-600">Error: {error}</p>
      </div>
    );
  }

  // ═══════════════════════════════════════════
  //  OVERVIEW MODE — Two tables: Parents | Children
  // ═══════════════════════════════════════════

  if (pageMode === 'overview') {
    return (
      <div>
        {/* Top bar */}
        <div className="flex items-center justify-between mb-4">
          <p className="text-sm text-gray-500">
            {roles.filter((r) => r.active).length} active roles &middot;{' '}
            {dependencies.length} dependencies
          </p>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setShowCreateForm(true)}
              className="flex items-center gap-1.5 text-sm font-medium px-3 py-1.5 rounded bg-blue-600 text-white hover:bg-blue-700 transition-colors"
            >
              <Plus className="w-3.5 h-3.5" /> New Role
            </button>
            <button
              onClick={() => setPageMode('edit')}
              className="flex items-center gap-1.5 text-sm font-medium px-3 py-1.5 rounded border border-primary text-primary hover:bg-primary/5 transition-colors"
            >
              <Edit className="w-3.5 h-3.5" /> Edit Roles
            </button>
          </div>
        </div>

        {/* Create role inline form */}
        {showCreateForm && (
          <div className="mb-4 bg-white border border-blue-200 rounded-lg p-4">
            <h4 className="text-sm font-semibold text-gray-900 mb-3">Create New Role</h4>
            <div className="flex items-end gap-3 flex-wrap">
              <div className="flex-1 min-w-[160px]">
                <label className="block text-xs font-medium text-gray-600 mb-1">Label *</label>
                <input
                  type="text"
                  value={newRoleLabel}
                  onChange={(e) => setNewRoleLabel(e.target.value)}
                  placeholder="e.g. Sub Bracket"
                  className="w-full px-2.5 py-1.5 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                  onKeyDown={(e) => { if (e.key === 'Enter') handleCreateRole(); }}
                />
              </div>
              <div className="min-w-[160px]">
                <label className="block text-xs font-medium text-gray-600 mb-1">Code (auto-generated if empty)</label>
                <input
                  type="text"
                  value={newRoleCode}
                  onChange={(e) => setNewRoleCode(e.target.value)}
                  placeholder="e.g. sub_bracket"
                  className="w-full px-2.5 py-1.5 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                />
              </div>
              <div className="min-w-[120px]">
                <label className="block text-xs font-medium text-gray-600 mb-1">Type</label>
                <select
                  value={newRoleType}
                  onChange={(e) => setNewRoleType(e.target.value as RoleType)}
                  className="w-full px-2.5 py-1.5 text-sm border border-gray-200 rounded focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                >
                  <option value="parent_only">Parent</option>
                  <option value="child_only">Child</option>
                  <option value="both">Both</option>
                </select>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={handleCreateRole}
                  disabled={isCreating || !newRoleLabel.trim()}
                  className="px-4 py-1.5 text-sm font-medium text-white bg-blue-600 rounded hover:bg-blue-700 disabled:opacity-50"
                >
                  {isCreating ? 'Creating...' : 'Create'}
                </button>
                <button
                  onClick={() => { setShowCreateForm(false); setNewRoleCode(''); setNewRoleLabel(''); setNewRoleType('both'); }}
                  className="px-3 py-1.5 text-sm text-gray-600 border border-gray-200 rounded hover:bg-gray-50"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Two tables side by side — fixed height, both scroll */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 h-[calc(100vh-340px)] min-h-[360px]">
          {/* ── Left: Parent Roles ── */}
          <div className="bg-white border border-gray-200 rounded-lg overflow-hidden flex flex-col">
            <div className="px-4 py-3 border-b border-gray-200 bg-gray-50 flex items-center gap-2 shrink-0">
              <Users className="w-4 h-4 text-gray-500" />
              <h3 className="text-sm font-semibold text-gray-900">
                Parent Roles
                <span className="font-normal text-gray-400 ml-1">({parentRolesList.length})</span>
              </h3>
            </div>
            <div className="flex-1 overflow-y-auto pr-5 pb-5">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-200 bg-gray-50/50">
                    <th className="text-left px-4 py-2 text-xs font-medium text-gray-500 uppercase">Role</th>
                    <th className="text-center px-2 py-2 text-xs font-medium text-gray-500 uppercase">Type</th>
                    <th className="text-center px-2 py-2 text-xs font-medium text-gray-500 uppercase">Children</th>
                    <th className="text-left px-3 py-2 text-xs font-medium text-gray-500 uppercase">Children List</th>
                    <th className="w-20 pl-2 pr-3 py-2"></th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {parentRolesList.map((role) => {
                    const count = childrenCountByParent[role.role_code] ?? 0;
                    const names = childrenOfRole(role.role_code);
                    const isRenaming = renamingRole === role.role_code;
                    return (
                      <tr key={role.role_code} className="hover:bg-gray-50 group">
                        <td className="px-4 py-2.5">
                          {isRenaming ? (
                            <div className="flex items-center gap-1.5">
                              <input
                                ref={renameInputRef}
                                value={renameValue}
                                onChange={(e) => setRenameValue(e.target.value)}
                                onKeyDown={(e) => { if (e.key === 'Enter') confirmRename(); if (e.key === 'Escape') cancelRename(); }}
                                className="text-sm font-medium text-gray-800 border border-primary rounded px-1.5 py-0.5 w-full focus:outline-none focus:ring-1 focus:ring-primary/30"
                              />
                              <button onClick={confirmRename} className="p-0.5 rounded hover:bg-green-100 text-green-600" title="Save"><Check className="w-3.5 h-3.5" /></button>
                              <button onClick={cancelRename} className="p-0.5 rounded hover:bg-gray-200 text-gray-400" title="Cancel"><X className="w-3.5 h-3.5" /></button>
                            </div>
                          ) : (
                            <div className="cursor-pointer" onClick={() => enterEditForRole(role.role_code)}>
                              <p className="font-medium text-gray-800">{role.label}</p>
                              <p className="text-[10px] text-gray-400">{role.role_code}</p>
                            </div>
                          )}
                        </td>
                        <td className="px-2 py-2.5 text-center">
                          <span className={`text-[10px] font-medium px-1.5 py-0.5 rounded ${ROLE_TYPE_COLORS[role.role_type]}`}>
                            {ROLE_TYPE_LABELS[role.role_type]}
                          </span>
                        </td>
                        <td className="px-2 py-2.5 text-center">
                          <span className={`text-xs font-semibold ${count > 0 ? 'text-gray-700' : 'text-gray-300'}`}>{count}</span>
                        </td>
                        <td className="px-3 py-2.5">
                          {names.length > 0 ? (
                            <div className="flex flex-wrap gap-1">
                              {names.map((n) => (
                                <span key={n} className="text-[10px] bg-gray-100 text-gray-600 px-1.5 py-0.5 rounded">{n}</span>
                              ))}
                            </div>
                          ) : (
                            <span className="text-[10px] text-gray-300 italic">—</span>
                          )}
                        </td>
                        <td className="px-2 py-2.5">
                          {!isRenaming && (
                            <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                              <button onClick={(e) => { e.stopPropagation(); startRename(role.role_code, role.label); }} className="p-1 rounded hover:bg-gray-100 text-gray-400 hover:text-gray-600" title="Rename">
                                <Pencil className="w-3.5 h-3.5" />
                              </button>
                              <button onClick={(e) => { e.stopPropagation(); handleDeleteRole(role.role_code, role.label); }} className="p-1 rounded hover:bg-red-100 text-gray-400 hover:text-red-500" title="Delete">
                                <Trash2 className="w-3.5 h-3.5" />
                              </button>
                            </div>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>

          {/* ── Right: Child Roles ── */}
          <div className="bg-white border border-gray-200 rounded-lg overflow-hidden flex flex-col">
            <div className="px-4 py-3 border-b border-gray-200 bg-gray-50 flex items-center gap-2 shrink-0">
              <Layers className="w-4 h-4 text-gray-500" />
              <h3 className="text-sm font-semibold text-gray-900">
                Child Roles
                <span className="font-normal text-gray-400 ml-1">({childRolesList.length})</span>
              </h3>
            </div>
            <div className="flex-1 overflow-y-auto pr-5 pb-5">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-200 bg-gray-50/50">
                    <th className="text-left px-4 py-2 text-xs font-medium text-gray-500 uppercase">Role</th>
                    <th className="text-center px-2 py-2 text-xs font-medium text-gray-500 uppercase">Type</th>
                    <th className="text-center px-2 py-2 text-xs font-medium text-gray-500 uppercase">Parents</th>
                    <th className="text-left px-3 py-2 text-xs font-medium text-gray-500 uppercase">Parent List</th>
                    <th className="w-20 pl-2 pr-3 py-2"></th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {childRolesList.map((role) => {
                    const count = parentsCountByChild[role.role_code] ?? 0;
                    const names = parentsOfRole(role.role_code);
                    const isRenaming = renamingRole === role.role_code;
                    return (
                      <tr key={role.role_code} className="hover:bg-gray-50 group">
                        <td className="px-4 py-2.5">
                          {isRenaming ? (
                            <div className="flex items-center gap-1.5">
                              <input
                                ref={renameInputRef}
                                value={renameValue}
                                onChange={(e) => setRenameValue(e.target.value)}
                                onKeyDown={(e) => { if (e.key === 'Enter') confirmRename(); if (e.key === 'Escape') cancelRename(); }}
                                className="text-sm font-medium text-gray-800 border border-primary rounded px-1.5 py-0.5 w-full focus:outline-none focus:ring-1 focus:ring-primary/30"
                              />
                              <button onClick={confirmRename} className="p-0.5 rounded hover:bg-green-100 text-green-600" title="Save"><Check className="w-3.5 h-3.5" /></button>
                              <button onClick={cancelRename} className="p-0.5 rounded hover:bg-gray-200 text-gray-400" title="Cancel"><X className="w-3.5 h-3.5" /></button>
                            </div>
                          ) : (
                            <div className="cursor-pointer" onClick={() => enterEditForRole(role.role_code)}>
                              <p className="font-medium text-gray-800">{role.label}</p>
                              <p className="text-[10px] text-gray-400">{role.role_code}</p>
                            </div>
                          )}
                        </td>
                        <td className="px-2 py-2.5 text-center">
                          <span className={`text-[10px] font-medium px-1.5 py-0.5 rounded ${ROLE_TYPE_COLORS[role.role_type]}`}>
                            {ROLE_TYPE_LABELS[role.role_type]}
                          </span>
                        </td>
                        <td className="px-2 py-2.5 text-center">
                          <span className={`text-xs font-semibold ${count > 0 ? 'text-gray-700' : 'text-gray-300'}`}>{count}</span>
                        </td>
                        <td className="px-3 py-2.5">
                          {names.length > 0 ? (
                            <div className="flex flex-wrap gap-1">
                              {names.map((n) => (
                                <span key={n} className="text-[10px] bg-gray-100 text-gray-600 px-1.5 py-0.5 rounded">{n}</span>
                              ))}
                            </div>
                          ) : (
                            <span className="text-[10px] text-gray-300 italic">—</span>
                          )}
                        </td>
                        <td className="px-2 py-2.5">
                          {!isRenaming && (
                            <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                              <button onClick={(e) => { e.stopPropagation(); startRename(role.role_code, role.label); }} className="p-1 rounded hover:bg-gray-100 text-gray-400 hover:text-gray-600" title="Rename">
                                <Pencil className="w-3.5 h-3.5" />
                              </button>
                              <button onClick={(e) => { e.stopPropagation(); handleDeleteRole(role.role_code, role.label); }} className="p-1 rounded hover:bg-red-100 text-gray-400 hover:text-red-500" title="Delete">
                                <Trash2 className="w-3.5 h-3.5" />
                              </button>
                            </div>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // ═══════════════════════════════════════════
  //  EDIT MODE — Role list + detail panel
  // ═══════════════════════════════════════════

  return (
    <div>
      {/* Back bar */}
      <div className="flex items-center gap-3 mb-4">
        <button
          onClick={() => setPageMode('overview')}
          className="flex items-center gap-1.5 text-sm text-gray-600 hover:text-gray-900 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" /> Back to overview
        </button>
      </div>

      {/* Search & filters */}
      <div className="mb-4">
        <div className="bg-white border border-gray-200 py-3 px-5 rounded-lg">
          <div className="flex items-center gap-3 flex-wrap">
            <div className="flex-1 relative min-w-[180px]">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search roles..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="w-full pl-9 pr-3 py-1.5 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
              />
            </div>
            <select
              value={filterType}
              onChange={(e) => setFilterType(e.target.value as RoleType | 'all')}
              className="text-sm border border-gray-200 rounded px-2 py-1.5 bg-gray-50"
            >
              <option value="all">All types</option>
              <option value="parent_only">Parent only</option>
              <option value="child_only">Child only</option>
              <option value="both">Both</option>
            </select>
            <label className="flex items-center gap-1.5 text-xs text-gray-500 cursor-pointer select-none">
              <input
                type="checkbox"
                checked={showInactive}
                onChange={(e) => setShowInactive(e.target.checked)}
                className="rounded border-gray-300"
              />
              Show inactive
            </label>
          </div>
        </div>
      </div>

      {/* Two-column: role list + detail — fixed height, both scroll */}
      <div className="grid grid-cols-1 lg:grid-cols-5 gap-4 h-[calc(100vh-380px)] min-h-[360px]">
        {/* Left: Role list (2/5) */}
        <div className="lg:col-span-2 bg-white border border-gray-200 rounded-lg overflow-hidden flex flex-col">
          <div className="px-4 py-2.5 border-b border-gray-200 flex items-center justify-between shrink-0">
            <h3 className="text-sm font-semibold text-gray-900">
              Roles{' '}
              <span className="font-normal text-gray-400">({filteredRoles.length})</span>
            </h3>
            <button
              onClick={() => setShowCreateForm(true)}
              className="flex items-center gap-1 text-xs font-medium px-2 py-1 rounded bg-blue-600 text-white hover:bg-blue-700"
            >
              <Plus className="w-3 h-3" /> New
            </button>
          </div>
          {showCreateForm && (
            <div className="px-4 py-3 border-b border-blue-100 bg-blue-50/50">
              <div className="space-y-2">
                <input
                  type="text"
                  value={newRoleLabel}
                  onChange={(e) => setNewRoleLabel(e.target.value)}
                  placeholder="Label (e.g. Sub Bracket)"
                  className="w-full px-2 py-1.5 text-sm border border-gray-200 rounded"
                  onKeyDown={(e) => { if (e.key === 'Enter') handleCreateRole(); }}
                />
                <input
                  type="text"
                  value={newRoleCode}
                  onChange={(e) => setNewRoleCode(e.target.value)}
                  placeholder="Code (auto if empty)"
                  className="w-full px-2 py-1.5 text-sm border border-gray-200 rounded"
                />
                <select
                  value={newRoleType}
                  onChange={(e) => setNewRoleType(e.target.value as RoleType)}
                  className="w-full px-2 py-1.5 text-sm border border-gray-200 rounded"
                >
                  <option value="parent_only">Parent</option>
                  <option value="child_only">Child</option>
                  <option value="both">Both</option>
                </select>
                <div className="flex gap-2">
                  <button onClick={handleCreateRole} disabled={isCreating || !newRoleLabel.trim()} className="flex-1 px-3 py-1.5 text-sm font-medium text-white bg-blue-600 rounded hover:bg-blue-700 disabled:opacity-50">
                    {isCreating ? 'Creating...' : 'Create'}
                  </button>
                  <button onClick={() => { setShowCreateForm(false); setNewRoleCode(''); setNewRoleLabel(''); setNewRoleType('both'); }} className="px-3 py-1.5 text-sm text-gray-600 border border-gray-200 rounded hover:bg-gray-50">
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          )}
          <div className="flex-1 overflow-y-auto divide-y divide-gray-100 pr-5 pb-5">
            {filteredRoles.length === 0 ? (
              <div className="py-10 text-center text-sm text-gray-500">No roles match</div>
            ) : (
              filteredRoles.map((role) => (
                <button
                  key={role.role_code}
                  onClick={() => selectRole(role.role_code)}
                  className={`w-full text-left pl-4 pr-1 py-2 flex items-center gap-2 transition-colors ${
                    selectedRole === role.role_code
                      ? 'bg-primary/5 border-l-2 border-l-primary'
                      : 'hover:bg-gray-50 border-l-2 border-l-transparent'
                  }`}
                >
                  <div className="flex-1 min-w-0">
                    <p className={`text-sm font-medium truncate ${!role.active ? 'text-gray-400' : 'text-gray-900'}`}>
                      {role.label}
                    </p>
                    <p className="text-[10px] text-gray-400 truncate">{role.role_code}</p>
                  </div>
                  <span className={`text-[10px] font-medium px-1.5 py-0.5 rounded shrink-0 ${ROLE_TYPE_COLORS[role.role_type]}`}>
                    {ROLE_TYPE_LABELS[role.role_type]}
                  </span>
                  {!role.active && (
                    <span className="text-[10px] font-medium px-1.5 py-0.5 rounded bg-red-50 text-red-400 shrink-0">
                      Off
                    </span>
                  )}
                </button>
              ))
            )}
          </div>
        </div>

        {/* Right: Detail panel (3/5) */}
        <div className="lg:col-span-3 flex flex-col">
          {!selected ? (
            <div className="bg-white border border-gray-200 rounded-lg h-full flex items-center justify-center">
              <div className="text-center py-8">
                <Shield className="mx-auto h-8 w-8 text-gray-300 mb-2" />
                <p className="text-sm text-gray-500">Select a role to edit</p>
              </div>
            </div>
          ) : (
            <div className="bg-white border border-gray-200 rounded-lg overflow-hidden h-full flex flex-col">
              {/* Header — compact */}
              <div className="px-4 py-3 border-b border-gray-200 shrink-0">
                <div className="flex items-center justify-between mb-1.5">
                  <div>
                    <h3 className="text-sm font-semibold text-gray-900">{selected.label}</h3>
                    <p className="text-[10px] text-gray-400">{selected.role_code}</p>
                  </div>
                  <button
                    onClick={() => handleToggleActive(selected.role_code, !selected.active)}
                    className={`text-[11px] font-medium px-2 py-0.5 rounded border ${
                      selected.active
                        ? 'border-green-200 bg-green-50 text-green-700 hover:bg-green-100'
                        : 'border-red-200 bg-red-50 text-red-600 hover:bg-red-100'
                    }`}
                  >
                    {selected.active ? 'Active' : 'Inactive'}
                  </button>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-[11px] font-medium text-gray-500">Type:</span>
                  <div className="flex gap-1">
                    {(['parent_only', 'child_only', 'both'] as RoleType[]).map((rt) => (
                      <button
                        key={rt}
                        onClick={() => handleRoleTypeChange(selected.role_code, rt)}
                        className={`text-[10px] font-medium px-2 py-0.5 rounded-md border transition-colors ${
                          selected.role_type === rt
                            ? 'border-primary bg-primary/10 text-primary'
                            : 'border-gray-200 text-gray-500 hover:border-gray-300 hover:bg-gray-50'
                        }`}
                      >
                        {ROLE_TYPE_LABELS[rt]}
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              {/* Edit sections — scrollable */}
              <div className="flex-1 overflow-y-auto divide-y divide-gray-200 pb-5">
                {/* Can be child of */}
                {selected.role_type !== 'parent_only' && (
                  <div className="px-4 py-2.5">
                    <div className="flex items-center justify-between mb-1.5">
                      <h5 className="text-[11px] font-semibold text-gray-500 uppercase tracking-wide">
                        Can be child of ({depsForSelected.length})
                      </h5>
                      <div className="flex items-center gap-2">
                        <button onClick={() => handleSelectAllParents(true)} className="text-[10px] font-medium text-primary hover:underline">All</button>
                        <span className="text-gray-300">|</span>
                        <button onClick={() => handleSelectAllParents(false)} className="text-[10px] font-medium text-gray-500 hover:underline">None</button>
                      </div>
                    </div>
                    <div className="space-y-0 overflow-y-auto border border-gray-100 rounded pb-4">
                      {parentRolesForEdit
                        .filter((r) => r.role_code !== selected.role_code)
                        .map((pr) => {
                          const isLinked = depsForSelected.some((d) => d.parent_role_code === pr.role_code);
                          return (
                            <label key={pr.role_code} className="flex items-center gap-2 px-2.5 py-1 hover:bg-gray-50 cursor-pointer border-b border-gray-50 last:border-0">
                              <input type="checkbox" checked={isLinked} onChange={(e) => handleToggleDependency(pr.role_code, e.target.checked)} className="rounded border-gray-300 text-primary focus:ring-primary/30 h-3.5 w-3.5" />
                              <span className="text-xs text-gray-700 flex-1">{pr.label}</span>
                            </label>
                          );
                        })}
                    </div>
                  </div>
                )}

                {/* Children inside */}
                {selected.role_type !== 'child_only' && (
                  <div className="px-4 py-2.5">
                    <h5 className="text-[11px] font-semibold text-gray-500 uppercase tracking-wide mb-1.5">
                      Children inside ({childrenOfSelected.length})
                    </h5>
                    {childrenOfSelected.length === 0 ? (
                      <p className="text-[11px] text-gray-400 italic py-1">No children linked.</p>
                    ) : (
                      <div className="space-y-0 overflow-y-auto border border-gray-100 rounded pb-4">
                        {childrenOfSelected.map((d) => {
                          const cr = roles.find((r) => r.role_code === d.role_code);
                          return (
                            <div key={d.role_code} className="flex items-center gap-2 px-2.5 py-1 bg-gray-50/50 border-b border-gray-100 last:border-0 group">
                              <span className={`text-[9px] font-medium px-1 py-0.5 rounded ${ROLE_TYPE_COLORS[cr?.role_type ?? 'both']}`}>{ROLE_TYPE_LABELS[cr?.role_type ?? 'both']}</span>
                              <span className="text-xs text-gray-700 flex-1">{cr?.label ?? d.role_code}</span>
                              <button onClick={() => handleRemoveChildDep(d.role_code)} className="p-0.5 rounded hover:bg-red-100 text-gray-400 hover:text-red-500 opacity-0 group-hover:opacity-100 transition-all" title="Remove">
                                <Trash2 className="w-3 h-3" />
                              </button>
                            </div>
                          );
                        })}
                      </div>
                    )}
                  </div>
                )}

                {/* Product Types */}
                <div className="px-4 py-2.5">
                  <div className="flex items-center justify-between mb-1.5">
                    <h5 className="text-[11px] font-semibold text-gray-500 uppercase tracking-wide">
                      Product Types ({rulesForSelected.length})
                    </h5>
                    <div className="flex items-center gap-2">
                      <button onClick={() => handleSelectAllProductTypes(true)} className="text-[10px] font-medium text-primary hover:underline">All</button>
                      <span className="text-gray-300">|</span>
                      <button onClick={() => handleSelectAllProductTypes(false)} className="text-[10px] font-medium text-gray-500 hover:underline">None</button>
                    </div>
                  </div>
                  <div className="space-y-0 overflow-y-auto border border-gray-100 rounded pb-4">
                    {productTypes.map((pt) => {
                      const rule = rulesForSelected.find((r) => r.product_type_id === pt.id);
                      const isAssigned = !!rule;
                      return (
                        <div key={pt.id} className="flex items-center gap-2 px-2.5 py-1 hover:bg-gray-50 border-b border-gray-50 last:border-0">
                          <input type="checkbox" checked={isAssigned} onChange={(e) => handleToggleProductType(pt.id, e.target.checked)} className="rounded border-gray-300 text-primary focus:ring-primary/30 h-3.5 w-3.5" />
                          <span className="text-xs text-gray-700 flex-1">{pt.name}</span>
                          {isAssigned && (
                            <label className="flex items-center gap-1 text-[10px] text-gray-500 cursor-pointer">
                              <input type="checkbox" checked={rule?.is_required ?? false} onChange={(e) => handleToggleRequired(pt.id, e.target.checked)} className="rounded border-gray-300 text-primary focus:ring-primary/30 h-3 w-3" />
                              Req
                            </label>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
