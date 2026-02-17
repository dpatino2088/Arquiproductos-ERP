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
  useSyncRolePermissions,
  type AppUserRoleListItem,
} from '../../hooks/useRolesAdmin';
import { RolePermissionsEditor } from '../../components/permissions/RolePermissionsEditor';
import { Shield, Plus, Loader2, ChevronRight } from 'lucide-react';

type TabUserType = 'org' | 'dealer' | 'all';

export default function Roles() {
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

  const createRole = useCreateRole();
  const updateRoleName = useUpdateRoleName();
  const syncPermissions = useSyncRolePermissions();

  const selectedRole = useMemo(
    () => roles.find((r) => r.code === selectedRoleCode) ?? null,
    [roles, selectedRoleCode]
  );

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
    const perms = permissions.filter((p) => (p.module || 'Other') === module);
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
    <div className="p-6 max-w-6xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-gray-900">Admin → Roles</h1>
          <p className="text-sm text-gray-500">Manage roles and permissions. Source of truth: AppUserRoles.</p>
        </div>
        <button
          type="button"
          onClick={() => router.navigate('/settings/company-settings')}
          className="text-sm text-gray-600 hover:text-gray-900"
        >
          ← Back to Settings
        </button>
      </div>

      <div className="flex gap-6">
        {/* Left: tabs ORG | DEALER | ALL + list */}
        <div className="w-96 flex-shrink-0 bg-white border border-gray-200 rounded-lg overflow-hidden">
          <div className="p-3 border-b border-gray-200 space-y-3">
            <div className="flex rounded-lg border border-gray-200 p-0.5 bg-gray-100" role="tablist">
              <button
                type="button"
                role="tab"
                aria-selected={activeTabUserType === 'org'}
                onClick={() => setActiveTabUserType('org')}
                className={`flex-1 py-1.5 text-sm font-medium rounded-md ${activeTabUserType === 'org' ? 'bg-white text-gray-900 shadow' : 'text-gray-600 hover:text-gray-900'}`}
              >
                ORG
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={activeTabUserType === 'dealer'}
                onClick={() => setActiveTabUserType('dealer')}
                className={`flex-1 py-1.5 text-sm font-medium rounded-md ${activeTabUserType === 'dealer' ? 'bg-white text-gray-900 shadow' : 'text-gray-600 hover:text-gray-900'}`}
              >
                DEALER
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={activeTabUserType === 'all'}
                onClick={() => setActiveTabUserType('all')}
                className={`flex-1 py-1.5 text-sm font-medium rounded-md ${activeTabUserType === 'all' ? 'bg-white text-gray-900 shadow' : 'text-gray-600 hover:text-gray-900'}`}
              >
                ALL
              </button>
            </div>
            <button
              type="button"
              onClick={openCreateModal}
              className="w-full flex items-center justify-center gap-2 py-2 text-sm font-medium text-white bg-blue-600 rounded hover:bg-blue-700"
            >
              <Plus className="w-4 h-4" /> New role
            </button>
          </div>
          <div className="max-h-[60vh] overflow-y-auto">
            {rolesError && <div className="p-3 text-sm text-red-600">{rolesError}</div>}
            {loadingRoles ? (
              <div className="p-4 flex justify-center">
                <Loader2 className="w-5 h-5 animate-spin text-gray-400" />
              </div>
            ) : roles.length === 0 ? (
              <div className="p-4 text-sm text-gray-500 text-center">No roles</div>
            ) : (
              <ul className="divide-y divide-gray-100">
                {roles.map((r) => (
                  <li key={r.code}>
                    <button
                      type="button"
                      onClick={() => handleSelectRole(r)}
                      className={`w-full text-left px-4 py-3 flex items-center gap-2 text-sm ${
                        selectedRoleCode === r.code ? 'bg-blue-50 text-blue-900' : 'hover:bg-gray-50'
                      }`}
                    >
                      <div className="flex-1 min-w-0">
                        <div className="font-medium text-gray-900 truncate">{r.name}</div>
                        <div className="text-xs text-gray-500 truncate">{r.code}</div>
                      </div>
                      <span className="flex-shrink-0 text-xs px-1.5 py-0.5 rounded bg-gray-100 text-gray-600">
                        {r.user_type}
                      </span>
                      <span className="text-xs text-gray-400 flex-shrink-0">{r.permission_count}</span>
                      {r.is_system && (
                        <span className="flex-shrink-0 text-[10px] font-medium px-1.5 py-0.5 rounded bg-amber-100 text-amber-800">
                          System
                        </span>
                      )}
                      <ChevronRight className="w-4 h-4 flex-shrink-0" />
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>

        {/* Right: placeholder or editor */}
        <div className="flex-1 bg-white border border-gray-200 rounded-lg overflow-hidden">
          {isCreateOpen ? (
            <div className="p-6">
              <h2 className="text-lg font-medium text-gray-900 mb-4">New role</h2>
              {activeTabUserType === 'all' && (
                <p className="text-sm text-gray-500 mb-2">Choose user type (tab is ALL).</p>
              )}
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
                  <input
                    type="text"
                    value={createCode}
                    onChange={(e) => setCreateCode(e.target.value)}
                    placeholder="e.g. tester_role"
                    className="w-full px-2 py-1.5 text-sm border border-gray-200 rounded"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
                  <input
                    type="text"
                    value={createName}
                    onChange={(e) => setCreateName(e.target.value)}
                    placeholder="Display name"
                    className="w-full px-2 py-1.5 text-sm border border-gray-200 rounded"
                  />
                </div>
                <div className="flex gap-2">
                  <button
                    type="submit"
                    disabled={createRole.isPending}
                    className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded hover:bg-blue-700 disabled:opacity-50"
                  >
                    {createRole.isPending ? <Loader2 className="w-4 h-4 animate-spin inline" /> : null} Create
                  </button>
                  <button
                    type="button"
                    onClick={() => setIsCreateOpen(false)}
                    className="px-4 py-2 text-sm text-gray-700 border border-gray-200 rounded hover:bg-gray-50"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          ) : selectedRole ? (
            <div className="p-6">
              <h2 className="text-lg font-medium text-gray-900 mb-1">{selectedRole.name}</h2>
              <p className="text-sm text-gray-500 mb-4">{selectedRole.code}</p>

              <div className="space-y-4 mb-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
                  {selectedRole.is_system ? (
                    <p className="text-sm text-gray-500">{selectedRole.name} (system role — read-only)</p>
                  ) : (
                    <div className="flex gap-2">
                      <input
                        type="text"
                        value={draftName}
                        onChange={(e) => setDraftName(e.target.value)}
                        className="flex-1 px-2 py-1.5 text-sm border border-gray-200 rounded"
                      />
                      <button
                        type="button"
                        onClick={handleUpdateName}
                        disabled={
                          updateRoleName.isPending || draftName.trim() === selectedRole.name
                        }
                        className="btn-save px-3 py-1.5 text-sm font-medium text-white rounded hover:opacity-90 disabled:opacity-50"
                      >
                        Save name
                      </button>
                    </div>
                  )}
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">User type</label>
                  <p className="text-sm text-gray-500">{selectedRole.user_type}</p>
                </div>
              </div>

              <div className="flex items-center justify-between mb-3">
                <span className="text-sm font-medium text-gray-700">Permissions</span>
                {dirtyPermissions && (
                  <button
                    type="button"
                    onClick={handleSavePermissions}
                    disabled={syncPermissions.isPending}
                    className="btn-save px-3 py-1.5 text-sm font-medium text-white rounded hover:opacity-90 disabled:opacity-50 flex items-center gap-1"
                  >
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
          ) : (
            <div className="p-12 text-center text-gray-500">
              <Shield className="w-12 h-12 mx-auto mb-3 text-gray-300" />
              <p>Select a role</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
