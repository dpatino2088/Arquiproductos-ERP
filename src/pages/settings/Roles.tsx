/**
 * Admin UI: list AppUserRoles and edit permissions per role (AppUserRolePermissions).
 * Batch save: diff then upsert/delete in bulk.
 */

import React, { useState, useEffect, useCallback } from 'react';
import { supabase } from '../../lib/supabase/client';
import { fetchRolePermissions, invalidateRolePermissionsCache, type AppUserRole } from '../../lib/roles';
import { Shield, ChevronRight, Loader2 } from 'lucide-react';

interface PermissionRow {
  code: string;
  module: string;
  description: string | null;
}

export default function Roles() {
  const [roles, setRoles] = useState<AppUserRole[]>([]);
  const [loadingRoles, setLoadingRoles] = useState(true);
  const [selectedRoleCode, setSelectedRoleCode] = useState<string | null>(null);
  const [permissions, setPermissions] = useState<PermissionRow[]>([]);
  const [assignedSet, setAssignedSet] = useState<Set<string>>(new Set());
  const [loadingPerms, setLoadingPerms] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadRoles = useCallback(async () => {
    setLoadingRoles(true);
    setError(null);
    try {
      const { data, error: e } = await supabase
        .from('AppUserRoles')
        .select('code, name, user_type')
        .order('user_type')
        .order('name');
      if (e) throw e;
      setRoles((data || []) as AppUserRole[]);
    } catch (err: any) {
      setError(err?.message ?? 'Failed to load roles');
      setRoles([]);
    } finally {
      setLoadingRoles(false);
    }
  }, []);

  useEffect(() => {
    loadRoles();
  }, [loadRoles]);

  const loadPermissionsAndAssigned = useCallback(async (roleCode: string) => {
    setLoadingPerms(true);
    setError(null);
    try {
      const [permsRes, assignedRes] = await Promise.all([
        supabase
          .from('Permissions')
          .select('code, module, description')
          .order('module')
          .order('code'),
        supabase
          .from('AppUserRolePermissions')
          .select('permission_code')
          .eq('role_code', roleCode),
      ]);
      if (permsRes.error) throw permsRes.error;
      if (assignedRes.error) throw assignedRes.error;
      setPermissions((permsRes.data || []) as PermissionRow[]);
      setAssignedSet(
        new Set((assignedRes.data || []).map((r: { permission_code: string }) => r.permission_code))
      );
    } catch (err: any) {
      setError(err?.message ?? 'Failed to load permissions');
      setPermissions([]);
      setAssignedSet(new Set());
    } finally {
      setLoadingPerms(false);
    }
  }, []);

  useEffect(() => {
    if (selectedRoleCode) {
      loadPermissionsAndAssigned(selectedRoleCode);
    } else {
      setPermissions([]);
      setAssignedSet(new Set());
    }
  }, [selectedRoleCode, loadPermissionsAndAssigned]);

  const togglePermission = (code: string) => {
    setAssignedSet((prev) => {
      const next = new Set(prev);
      if (next.has(code)) next.delete(code);
      else next.add(code);
      return next;
    });
  };

  const savePermissions = async () => {
    if (!selectedRoleCode) return;
    setSaving(true);
    setError(null);
    try {
      const previous = await fetchRolePermissions(supabase, selectedRoleCode);
      const toAdd = [...assignedSet].filter((c) => !previous.has(c));
      const toRemove = [...previous].filter((c) => !assignedSet.has(c));

      if (toRemove.length > 0) {
        const { error: delErr } = await supabase
          .from('AppUserRolePermissions')
          .delete()
          .eq('role_code', selectedRoleCode)
          .in('permission_code', toRemove);
        if (delErr) throw delErr;
      }

      if (toAdd.length > 0) {
        const rows = toAdd.map((permission_code) => ({
          role_code: selectedRoleCode,
          permission_code,
        }));
        const { error: insErr } = await supabase.from('AppUserRolePermissions').upsert(rows, {
          onConflict: 'role_code,permission_code',
        });
        if (insErr) throw insErr;
      }

      invalidateRolePermissionsCache(selectedRoleCode);
      loadPermissionsAndAssigned(selectedRoleCode);
    } catch (err: any) {
      setError(err?.message ?? 'Failed to save');
    } finally {
      setSaving(false);
    }
  };

  const selectedRole = roles.find((r) => r.code === selectedRoleCode);

  return (
    <div className="p-6 max-w-4xl">
      <h1 className="text-xl font-semibold text-gray-900 mb-2">Roles & Permissions</h1>
      <p className="text-sm text-gray-500 mb-6">
        Manage roles and their permissions. Permissions are used for UI gating and feature access.
      </p>

      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-800">
          {error}
        </div>
      )}

      <div className="flex gap-6">
        <div className="w-64 flex-shrink-0 bg-white border border-gray-200 rounded-lg overflow-hidden">
          <div className="px-4 py-3 bg-gray-50 border-b border-gray-200 font-medium text-gray-700 text-sm">
            Roles
          </div>
          {loadingRoles ? (
            <div className="p-4 flex items-center justify-center text-gray-500">
              <Loader2 className="w-5 h-5 animate-spin" />
            </div>
          ) : (
            <ul className="divide-y divide-gray-100">
              {roles.map((r) => (
                <li key={r.code}>
                  <button
                    type="button"
                    onClick={() => setSelectedRoleCode(r.code)}
                    className={`w-full text-left px-4 py-3 flex items-center justify-between text-sm transition-colors ${
                      selectedRoleCode === r.code
                        ? 'bg-primary/10 text-primary font-medium'
                        : 'text-gray-700 hover:bg-gray-50'
                    }`}
                  >
                    <span>{r.name}</span>
                    <span className="text-xs text-gray-500">({r.user_type})</span>
                    <ChevronRight className="w-4 h-4 text-gray-400" />
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="flex-1 bg-white border border-gray-200 rounded-lg overflow-hidden">
          {!selectedRoleCode ? (
            <div className="p-8 text-center text-gray-500">
              <Shield className="w-12 h-12 mx-auto mb-3 text-gray-300" />
              <p>Select a role to edit its permissions.</p>
            </div>
          ) : (
            <>
              <div className="px-4 py-3 bg-gray-50 border-b border-gray-200 flex items-center justify-between">
                <h2 className="font-medium text-gray-900">
                  {selectedRole?.name ?? selectedRoleCode} ({selectedRole?.user_type ?? '—'})
                </h2>
                <button
                  type="button"
                  onClick={savePermissions}
                  disabled={saving}
                  className="px-3 py-1.5 text-sm font-medium text-white rounded-md bg-primary hover:bg-primary/90 disabled:opacity-50 flex items-center gap-2"
                >
                  {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
                  Save
                </button>
              </div>
              <div className="p-4 max-h-[60vh] overflow-y-auto">
                {loadingPerms ? (
                  <div className="flex items-center justify-center py-8 text-gray-500">
                    <Loader2 className="w-6 h-6 animate-spin" />
                  </div>
                ) : (
                  <div className="space-y-2">
                    {permissions.length === 0 ? (
                      <p className="text-sm text-gray-500">No permissions defined in Permissions table.</p>
                    ) : (
                      permissions.map((p) => (
                        <label
                          key={p.code}
                          className="flex items-center gap-3 py-2 px-3 rounded hover:bg-gray-50 cursor-pointer"
                        >
                          <input
                            type="checkbox"
                            checked={assignedSet.has(p.code)}
                            onChange={() => togglePermission(p.code)}
                            className="rounded border-gray-300"
                          />
                          <span className="text-sm font-mono text-gray-800">{p.code}</span>
                          <span className="text-xs text-gray-500">{p.module}</span>
                          {p.description && (
                            <span className="text-xs text-gray-400 truncate">{p.description}</span>
                          )}
                        </label>
                      ))
                    )}
                  </div>
                )}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
