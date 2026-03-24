/**
 * Admin → Roles. Tabs ORG | DEALER | ALL, CRUD roles (crear + renombrar), editor de permisos.
 * canManageRoles := roles.manage OR (isSuperAdmin || isAdmin). Si !canManageRoles => no ejecutar queries.
 */

import React, { useState, useMemo, useEffect } from 'react';
import { router } from '../../lib/router';
import { useUIStore } from '../../stores/ui-store';
import { usePermissions } from '../../hooks/usePermissions';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import {
  useRoleList,
  usePermissionsList,
  useRolePermissionCodes,
  useCreateRole,
  useUpdateRoleName,
  useDeleteRole,
  useSyncRolePermissions,
  type AppUserRoleListItem,
} from '../../hooks/useRolesAdmin';
import { RolePermissionsEditor } from '../../components/permissions/RolePermissionsEditor';
import { Shield, Plus, Loader2, Trash2, Users, Pencil } from 'lucide-react';

type TabUserType = 'org' | 'dealer' | 'all';

/** Roles that cannot be deleted — they are the fallback targets for user reassignment */
const PROTECTED_ROLE_CODES = new Set(['superadmin', 'admin', 'member', 'dealer_member']);

type RolesProps = {
  embedded?: boolean;
};

export default function Roles({ embedded = false }: RolesProps) {
  const { addNotification } = useUIStore();
  const { can } = usePermissions();
  const { isSuperAdmin, isAdmin } = useCurrentOrgRole();

  const canManageRoles = can('roles.manage') || isSuperAdmin || isAdmin;

  const [activeTabUserType, setActiveTabUserType] = useState<TabUserType>('org');
  const [selectedRoleCode, setSelectedRoleCode] = useState<string | null>(null);
  const [draftName, setDraftName] = useState('');
  const [selectedPermissionCodes, setSelectedPermissionCodes] = useState<Set<string>>(new Set());
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [createCode, setCreateCode] = useState('');
  const [createName, setCreateName] = useState('');
  const [createUserType, setCreateUserType] = useState<'org' | 'dealer'>('org');

  const { roles, loading: loadingRoles, error: rolesError, refetch: refetchRoles } = useRoleList(
    activeTabUserType,
    canManageRoles
  );
  const { permissions, loading: loadingPerms } = usePermissionsList(canManageRoles);
  const {
    permissionCodes,
    loading: loadingAssigned,
    refetch: refetchAssigned,
  } = useRolePermissionCodes(selectedRoleCode, canManageRoles);

  const [confirmDeleteCode, setConfirmDeleteCode] = useState<string | null>(null);

  const createRole = useCreateRole();
  const updateRoleName = useUpdateRoleName();
  const deleteRoleMutation = useDeleteRole();
  const syncPermissions = useSyncRolePermissions();

  const selectedRole = useMemo(
    () => roles.find((r) => r.code === selectedRoleCode) ?? null,
    [roles, selectedRoleCode]
  );

  /** Protected roles pinned to top, rest sorted alphabetically below */
  const sortedRoles = useMemo(() => {
    const pinned = roles.filter((r) => PROTECTED_ROLE_CODES.has(r.code));
    const rest = roles.filter((r) => !PROTECTED_ROLE_CODES.has(r.code))
      .sort((a, b) => a.name.localeCompare(b.name));
    return [...pinned, ...rest];
  }, [roles]);

  const dirtyPermissions = useMemo(() => {
    if (!selectedRoleCode) return false;
    if (selectedPermissionCodes.size !== permissionCodes.size) return true;
    for (const c of selectedPermissionCodes) if (!permissionCodes.has(c)) return true;
    for (const c of permissionCodes) if (!selectedPermissionCodes.has(c)) return true;
    return false;
  }, [selectedRoleCode, selectedPermissionCodes, permissionCodes]);

  useEffect(() => {
    setSelectedRoleCode(null);
  }, [activeTabUserType]);

  useEffect(() => {
    if (!embedded && !selectedRoleCode && roles.length > 0 && !isCreateOpen) {
      setSelectedRoleCode(roles[0]!.code);
    }
  }, [roles, selectedRoleCode, isCreateOpen, embedded]);

  useEffect(() => {
    if (selectedRole) {
      setDraftName(selectedRole.name);
      setSelectedPermissionCodes(new Set(permissionCodes));
    }
  }, [selectedRole?.code, selectedRole?.name, permissionCodes]);

  const handleSelectRole = (role: AppUserRoleListItem) => {
    setSelectedRoleCode(role.code);
    setIsCreateOpen(false);
  };

  const handleTogglePermission = (code: string) => {
    setSelectedPermissionCodes((prev) => {
      const next = new Set(prev);
      if (next.has(code)) next.delete(code);
      else next.add(code);
      return next;
    });
  };

  const handleSelectAllInModule = (module: string) => {
    // Safety-net merge map mirrors RolePermissionsEditor — catches any legacy module values.
    const MODULE_MERGE: Record<string, string> = {
      purchasing: 'inventory', quotes: 'sales', proposals: 'sales',
      salesorders: 'sales', admin: 'settings', org: 'settings',
      reports: 'settings', portal: 'financials',
    };
    const perms = permissions.filter((p) => {
      const raw = (p.module || 'other').trim().toLowerCase();
      const canonical = MODULE_MERGE[raw] ?? raw;
      return canonical === module;
    });
    const allChecked = perms.every((p) => selectedPermissionCodes.has(p.code));
    setSelectedPermissionCodes((prev) => {
      const next = new Set(prev);
      if (allChecked) perms.forEach((p) => next.delete(p.code));
      else perms.forEach((p) => next.add(p.code));
      return next;
    });
  };

  const handleSavePermissions = async () => {
    if (!selectedRoleCode) return;
    try {
      await syncPermissions.mutateAsync({
        role_code: selectedRoleCode,
        desiredCodes: [...selectedPermissionCodes],
      });
      addNotification({ type: 'success', title: 'Saved', message: 'Permissions updated.' });
      refetchAssigned();
      refetchRoles();
    } catch (e: unknown) {
      addNotification({
        type: 'error',
        title: 'Error',
        message: e instanceof Error ? e.message : 'Failed to save permissions.',
      });
    }
  };

  const handleCreateRole = async (e: React.FormEvent) => {
    e.preventDefault();
    const codeSlug = createCode.trim().toLowerCase().replace(/\s+/g, '_');
    if (!codeSlug || !createName.trim()) {
      addNotification({ type: 'error', title: 'Validation', message: 'Code and name are required.' });
      return;
    }
    if (!/^[a-z0-9_]+$/.test(codeSlug)) {
      addNotification({
        type: 'error',
        title: 'Validation',
        message: 'Code must be lowercase letters, numbers and underscores only (no spaces).',
      });
      return;
    }
    const userType = activeTabUserType === 'all' ? createUserType : activeTabUserType;
    try {
      await createRole.mutateAsync({
        code: codeSlug,
        name: createName.trim(),
        user_type: userType,
      });
      addNotification({ type: 'success', title: 'Created', message: `Role ${codeSlug} created.` });
      setIsCreateOpen(false);
      setCreateCode('');
      setCreateName('');
      setCreateUserType(activeTabUserType === 'all' ? 'org' : activeTabUserType);
      refetchRoles();
    } catch (e: unknown) {
      addNotification({
        type: 'error',
        title: 'Error',
        message: e instanceof Error ? e.message : 'Failed to create role.',
      });
    }
  };

  const handleUpdateName = async () => {
    if (!selectedRole || selectedRole.is_system || draftName.trim() === selectedRole.name) return;
    try {
      await updateRoleName.mutateAsync({ code: selectedRole.code, name: draftName.trim() });
      addNotification({ type: 'success', title: 'Saved', message: 'Role name updated.' });
      refetchRoles();
      setSelectedRoleCode(selectedRole.code);
    } catch (e: unknown) {
      addNotification({
        type: 'error',
        title: 'Error',
        message: e instanceof Error ? e.message : 'Failed to update name.',
      });
    }
  };

  const openCreateModal = () => {
    setIsCreateOpen(true);
    setSelectedRoleCode(null);
    setCreateCode('');
    setCreateName('');
    setCreateUserType(activeTabUserType === 'all' ? 'org' : activeTabUserType);
  };

  const handleDeleteRole = async () => {
    if (!confirmDeleteCode) return;
    try {
      await deleteRoleMutation.mutateAsync({ code: confirmDeleteCode });
      addNotification({ type: 'success', title: 'Deleted', message: `Role "${confirmDeleteCode}" deleted.` });
      if (selectedRoleCode === confirmDeleteCode) setSelectedRoleCode(null);
      setConfirmDeleteCode(null);
      refetchRoles();
    } catch (e: unknown) {
      addNotification({
        type: 'error',
        title: 'Error',
        message: e instanceof Error ? e.message : 'Failed to delete role.',
      });
      setConfirmDeleteCode(null);
    }
  };

  const confirmDeleteRole = roles.find(r => r.code === confirmDeleteCode) ?? null;
  const showEmbeddedRoleList = embedded && !isCreateOpen && !selectedRoleCode;
  const userTypeTabs: Array<{ key: TabUserType; label: string }> = embedded
    ? [
        { key: 'org', label: 'Organization' },
        { key: 'dealer', label: 'Dealer' },
      ]
    : [
        { key: 'org', label: 'Organization' },
        { key: 'dealer', label: 'Dealer' },
        { key: 'all', label: 'All' },
      ];

  if (!canManageRoles) {
    return (
      <div className="p-6 max-w-2xl mx-auto">
        <div className="bg-amber-50 border border-amber-200 rounded-lg p-6 text-center">
          <Shield className="w-12 h-12 mx-auto mb-3 text-amber-600" />
          <h2 className="text-lg font-semibold text-gray-900">Not authorized</h2>
          <p className="text-sm text-gray-600 mt-1">You need the roles.manage permission or Admin/Superadmin role to access this page.</p>
          <button
            type="button"
            onClick={() => router.navigate('/dashboard')}
            className="mt-4 px-4 py-2 text-sm font-medium text-white bg-gray-700 rounded hover:bg-gray-800"
          >
            Back to Dashboard
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className={embedded ? '' : 'p-6 max-w-6xl mx-auto'}>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-gray-900">{embedded ? 'Roles & Permissions' : 'Admin → Roles'}</h1>
          <p className="text-sm text-gray-500">Manage roles and permissions. Source of truth: AppUserRoles.</p>
        </div>
        {!embedded && (
          <button
            type="button"
            onClick={() => router.navigate('/settings/company-settings')}
            className="text-sm text-gray-600 hover:text-gray-900"
          >
            ← Back to Settings
          </button>
        )}
      </div>

      {/* Single unified container — tab bar always visible, content switches below */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">

        {/* Tab bar */}
        <div
          className="border-b flex items-center justify-between"
          style={{ height: '2.625rem', backgroundColor: 'var(--gray-100)', borderColor: 'var(--gray-250)' }}
        >
          <div className="flex items-stretch h-full" role="tablist">
            {userTypeTabs.map((tab) => {
              const isActive = activeTabUserType === tab.key;
              return (
                <button
                  key={tab.key}
                  type="button"
                  role="tab"
                  aria-selected={isActive}
                  onClick={() => { setActiveTabUserType(tab.key); setSelectedRoleCode(null); setIsCreateOpen(false); }}
                  className={`transition-colors flex items-center justify-center border-r ${isActive ? 'bg-white font-semibold' : 'hover:bg-white/50 font-normal'}`}
                  style={{
                    fontSize: '12px',
                    padding: '0 32px',
                    height: '100%',
                    minWidth: '120px',
                    color: 'var(--graphite-black-hex)',
                    borderColor: 'var(--gray-250)',
                    borderBottom: isActive ? '2px solid var(--tab-active-underline)' : 'none',
                  }}
                  aria-label={`${tab.label}${isActive ? ' (current tab)' : ''}`}
                >
                  {tab.label}
                </button>
              );
            })}
          </div>
          <div className="px-3">
            {showEmbeddedRoleList && (
              <button
                type="button"
                onClick={openCreateModal}
                className="flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-blue-600 rounded hover:bg-blue-700"
              >
                <Plus className="w-4 h-4" /> New role
              </button>
            )}
          </div>
        </div>

        {/* Content — list OR detail, never both */}
        {showEmbeddedRoleList ? (
          <div className="p-4">
            {rolesError && <div className="mb-2 text-sm text-red-600">{rolesError}</div>}
            {loadingRoles ? (
              <div className="p-3 flex justify-center">
                <Loader2 className="w-5 h-5 animate-spin text-gray-400" />
              </div>
            ) : roles.length === 0 ? (
              <div className="p-2 text-sm text-gray-500">No roles</div>
            ) : (
              <div className="overflow-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="text-left text-xs text-gray-500 border-b border-gray-200">
                      <th className="py-2 pr-3">Role</th>
                      <th className="py-2 pr-3">Type</th>
                      <th className="py-2 pr-3">Users</th>
                      <th className="py-2 pr-3">Perms</th>
                      <th className="py-2 pr-3">Status</th>
                      <th className="py-2 text-right">Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {sortedRoles.map((r) => (
                      <tr key={r.code} className="border-b border-gray-100">
                        <td className="py-2.5 pr-3">
                          <div className="font-medium text-gray-900">{r.name}</div>
                          <div className="text-xs text-gray-500">{r.code}</div>
                        </td>
                        <td className="py-2.5 pr-3 text-gray-600">{r.user_type}</td>
                        <td className="py-2.5 pr-3 text-gray-600">{r.user_count}</td>
                        <td className="py-2.5 pr-3 text-gray-600">{r.permission_count}</td>
                        <td className="py-2.5 pr-3">
                          {r.is_system ? (
                            <span className="px-1.5 py-0.5 rounded bg-amber-100 text-amber-800 text-xs font-medium">System</span>
                          ) : (
                            <span className="text-xs text-gray-500">Custom</span>
                          )}
                        </td>
                        <td className="py-2.5 text-right">
                          <div className="inline-flex items-center gap-1">
                            <button
                              type="button"
                              onClick={() => handleSelectRole(r)}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                              title="Edit role"
                            >
                              <Pencil className="w-4 h-4" />
                            </button>
                            {!PROTECTED_ROLE_CODES.has(r.code) && (
                              <button
                                type="button"
                                onClick={() => setConfirmDeleteCode(r.code)}
                                className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 hover:text-red-600"
                                title={r.user_count > 0 ? `${r.user_count} user(s) — will be reassigned` : 'Delete role'}
                              >
                                <Trash2 className="w-4 h-4" />
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        ) : isCreateOpen ? (
          <div className="p-6">
            <h2 className="text-lg font-medium text-gray-900 mb-4">New role</h2>
            {activeTabUserType !== 'all' && (
              <p className="text-sm text-gray-500 mb-2">User type: <strong>{activeTabUserType}</strong></p>
            )}
            <form onSubmit={handleCreateRole} className="space-y-4 max-w-md">
              {activeTabUserType === 'all' && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">User type</label>
                  <select
                    value={createUserType}
                    onChange={(e) => setCreateUserType(e.target.value as 'org' | 'dealer')}
                    className="w-full px-2 py-1.5 text-sm border border-gray-200 rounded"
                  >
                    <option value="org">org</option>
                    <option value="dealer">dealer</option>
                  </select>
                </div>
              )}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Code (slug, a-z0-9_)</label>
                <input type="text" value={createCode} onChange={(e) => setCreateCode(e.target.value)} placeholder="e.g. tester_role" className="w-full px-2 py-1.5 text-sm border border-gray-200 rounded" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
                <input type="text" value={createName} onChange={(e) => setCreateName(e.target.value)} placeholder="Display name" className="w-full px-2 py-1.5 text-sm border border-gray-200 rounded" />
              </div>
              <div className="flex gap-2">
                <button type="submit" disabled={createRole.isPending} className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded hover:bg-blue-700 disabled:opacity-50">
                  {createRole.isPending ? <Loader2 className="w-4 h-4 animate-spin inline" /> : null} Create
                </button>
                <button type="button" onClick={() => setIsCreateOpen(false)} className="px-4 py-2 text-sm text-gray-700 border border-gray-200 rounded hover:bg-gray-50">Cancel</button>
              </div>
            </form>
          </div>
        ) : selectedRole ? (
          <div className="p-6">
            <div className="mb-4">
              <button type="button" onClick={() => setSelectedRoleCode(null)} className="text-sm text-gray-600 hover:text-gray-900">
                ← Back to roles list
              </button>
            </div>
            <div className="flex items-start justify-between mb-4">
              <div>
                <h2 className="text-lg font-medium text-gray-900 mb-1">{selectedRole.name}</h2>
                <p className="text-sm text-gray-500">{selectedRole.code}</p>
              </div>
              {!PROTECTED_ROLE_CODES.has(selectedRole.code) && (
                <button
                  type="button"
                  onClick={() => setConfirmDeleteCode(selectedRole.code)}
                  className="flex items-center gap-1 px-3 py-1.5 text-sm font-medium text-red-600 border border-red-200 rounded hover:bg-red-50"
                  title={selectedRole.user_count > 0 ? `${selectedRole.user_count} user(s) assigned — will fallback to member/dealer_member` : 'Delete this role'}
                >
                  <Trash2 className="w-4 h-4" /> Delete
                </button>
              )}
            </div>
            <div className="space-y-4 mb-6">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
                {selectedRole.is_system ? (
                  <p className="text-sm text-gray-500">{selectedRole.name} (system role — read-only)</p>
                ) : (
                  <div className="flex gap-2">
                    <input type="text" value={draftName} onChange={(e) => setDraftName(e.target.value)} className="flex-1 px-2 py-1.5 text-sm border border-gray-200 rounded" />
                    <button type="button" onClick={handleUpdateName} disabled={updateRoleName.isPending || draftName.trim() === selectedRole.name} className="btn-save px-3 py-1.5 text-sm font-medium text-white rounded hover:opacity-90 disabled:opacity-50">Save name</button>
                  </div>
                )}
              </div>
              <div className="flex gap-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">User type</label>
                  <p className="text-sm text-gray-500">{selectedRole.user_type}</p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Users assigned</label>
                  <p className="text-sm text-gray-500">{selectedRole.user_count}</p>
                </div>
              </div>
            </div>
            <div className="flex items-center justify-between mb-3">
              <span className="text-sm font-medium text-gray-700">Permissions ({selectedPermissionCodes.size} assigned)</span>
              {dirtyPermissions && (
                <button type="button" onClick={handleSavePermissions} disabled={syncPermissions.isPending} className="btn-save px-3 py-1.5 text-sm font-medium text-white rounded hover:opacity-90 disabled:opacity-50 flex items-center gap-1">
                  {syncPermissions.isPending ? <Loader2 className="w-4 h-4 animate-spin" /> : null} Save permissions
                </button>
              )}
            </div>
            <RolePermissionsEditor
              permissions={permissions}
              selected={selectedPermissionCodes}
              onToggle={handleTogglePermission}
              onSelectAllInModule={handleSelectAllInModule}
              loading={loadingPerms || loadingAssigned}
            />
          </div>
        ) : null}
      </div>

      {/* Delete confirmation dialog */}
      {confirmDeleteCode && confirmDeleteRole && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Delete Role</h3>
            <p className="text-sm text-gray-600 mb-1">
              Are you sure you want to delete the role <strong>{confirmDeleteRole.name}</strong> (<code className="text-xs">{confirmDeleteRole.code}</code>)?
            </p>
            {confirmDeleteRole.user_count > 0 && (
              <div className="mt-3 rounded border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800">
                This role has <strong>{confirmDeleteRole.user_count} user(s)</strong> assigned. They will be reassigned to fallback role (<strong>member</strong> for org, <strong>dealer_member</strong> for dealer) before deletion.
              </div>
            )}
            {confirmDeleteRole.permission_count > 0 && (
              <p className="mt-2 text-xs text-gray-500">
                {confirmDeleteRole.permission_count} permission(s) will also be removed.
              </p>
            )}
            <div className="flex justify-end gap-2 mt-5">
              <button
                type="button"
                onClick={() => setConfirmDeleteCode(null)}
                className="px-4 py-2 text-sm text-gray-700 border border-gray-200 rounded hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleDeleteRole}
                disabled={deleteRoleMutation.isPending}
                className="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded hover:bg-red-700 disabled:opacity-50 flex items-center gap-1"
              >
                {deleteRoleMutation.isPending && <Loader2 className="w-4 h-4 animate-spin" />}
                Delete Role
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
