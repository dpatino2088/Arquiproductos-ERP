/**
 * Admin → Roles: archivo único de hooks. React Query.
 * Fuente de verdad: AppUserRoles, Permissions, AppUserRolePermissions.
 * Sin migraciones. Sin triggers.
 */

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';
import { invalidateRolePermissionsCache } from '../lib/roles';

export type PermissionRow = {
  code: string;
  module: string;
  description: string | null;
};

export type AppUserRoleRow = {
  code: string;
  name: string;
  description: string | null;
  user_type: 'org' | 'dealer';
  sort_order: number | null;
  is_system: boolean | null;
};

export type AppUserRoleListItem = {
  code: string;
  name: string;
  description: string | null;
  user_type: 'org' | 'dealer';
  sort_order: number;
  is_system: boolean;
  permission_count: number;
  user_count: number;
};

const ROLES_QUERY_KEY = ['roles-admin'];
const PERMISSIONS_QUERY_KEY = ['permissions-list'];
const ROLE_PERMISSIONS_QUERY_KEY = (roleCode: string) => ['role-permissions', roleCode];

/** A) useRoleList(user_type, enabled?): query AppUserRoles; filter si user_type !== 'all'; order user_type asc, sort_order asc, name asc; normalizar; batch count. */
export function useRoleList(
  user_type: 'org' | 'dealer' | 'all',
  enabled: boolean = true
) {
  const { data, isLoading, error, refetch } = useQuery({
    queryKey: [...ROLES_QUERY_KEY, user_type],
    enabled,
    queryFn: async (): Promise<AppUserRoleListItem[]> => {
      let q = supabase
        .from('AppUserRoles')
        .select('code, name, description, user_type, sort_order, is_system')
        .order('user_type', { ascending: true })
        .order('sort_order', { ascending: true })
        .order('name', { ascending: true });
      if (user_type !== 'all') {
        q = q.eq('user_type', user_type);
      }
      const { data: rows, error: e } = await q;
      if (e) throw e;
      const list = (rows ?? []) as AppUserRoleRow[];
      if (list.length === 0) return [];
      const roleCodes = list.map((r) => r.code);
      const { data: rpRows, error: rpErr } = await supabase
        .from('AppUserRolePermissions')
        .select('role_code')
        .in('role_code', roleCodes);
      if (rpErr) throw rpErr;
      const countByRole: Record<string, number> = {};
      for (const code of roleCodes) countByRole[code] = 0;
      for (const row of rpRows ?? []) {
        const c = (row as { role_code: string }).role_code;
        if (c in countByRole) countByRole[c] += 1;
      }

      const { data: userRows, error: userErr } = await supabase
        .from('AppUsers')
        .select('role_code')
        .in('role_code', roleCodes)
        .eq('deleted', false);
      if (userErr) throw userErr;
      const userCountByRole: Record<string, number> = {};
      for (const code of roleCodes) userCountByRole[code] = 0;
      for (const row of userRows ?? []) {
        const c = (row as { role_code: string }).role_code;
        if (c in userCountByRole) userCountByRole[c] += 1;
      }

      return list.map((r) => ({
        code: r.code,
        name: r.name,
        description: r.description ?? null,
        user_type: r.user_type,
        sort_order: r.sort_order ?? 9999,
        is_system: !!r.is_system,
        permission_count: countByRole[r.code] ?? 0,
        user_count: userCountByRole[r.code] ?? 0,
      }));
    },
  });
  return {
    roles: data ?? [],
    loading: isLoading,
    error: error ? (error as Error).message : null,
    refetch,
  };
}

/** B) usePermissionsList(enabled?) */
export function usePermissionsList(enabled: boolean = true) {
  const { data, isLoading, error, refetch } = useQuery({
    queryKey: PERMISSIONS_QUERY_KEY,
    enabled,
    queryFn: async (): Promise<PermissionRow[]> => {
      const { data: rows, error: e } = await supabase
        .from('Permissions')
        .select('code, module, description')
        .order('module', { ascending: true })
        .order('code', { ascending: true });
      if (e) throw e;
      return (rows ?? []) as PermissionRow[];
    },
  });
  return {
    permissions: data ?? [],
    loading: isLoading,
    error: error ? (error as Error).message : null,
    refetch,
  };
}

/** C) useRolePermissionCodes(roleCode, enabled?): Set(permission_code). Si roleCode null => Set vacío. */
export function useRolePermissionCodes(roleCode: string | null, enabled: boolean = true) {
  const effectiveEnabled = !!roleCode && enabled;
  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ROLE_PERMISSIONS_QUERY_KEY(roleCode ?? ''),
    enabled: effectiveEnabled,
    queryFn: async (): Promise<Set<string>> => {
      if (!roleCode) return new Set();
      const { data: rows, error: e } = await supabase
        .from('AppUserRolePermissions')
        .select('permission_code')
        .eq('role_code', roleCode);
      if (e) throw e;
      return new Set((rows ?? []).map((r: { permission_code: string }) => r.permission_code));
    },
  });
  return {
    permissionCodes: data ?? new Set<string>(),
    loading: isLoading,
    error: error ? (error as Error).message : null,
    refetch,
  };
}

/** D) useCreateRole(): validar code /^[a-z0-9_]+$/, name, user_type; insert; duplicate 23505 => "Role code already exists" */
export function useCreateRole() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationKey: ['create-role'],
    mutationFn: async (payload: {
      code: string;
      name: string;
      user_type: 'org' | 'dealer';
      description?: string | null;
    }) => {
      const codeSlug = payload.code.trim().toLowerCase().replace(/\s+/g, '_');
      if (!/^[a-z0-9_]+$/.test(codeSlug)) {
        throw new Error('Code must be lowercase letters, numbers and underscores only (no spaces).');
      }
      if (!payload.name.trim()) throw new Error('Name is required.');
      if (!payload.user_type) throw new Error('User type is required.');
      const { error: e } = await supabase.from('AppUserRoles').insert({
        code: codeSlug,
        name: payload.name.trim(),
        user_type: payload.user_type,
        description: payload.description ?? null,
        sort_order: 0,
        is_system: false,
      });
      if (e) {
        if (e.code === '23505') throw new Error('Role code already exists.');
        throw e;
      }
      return { code: codeSlug, name: payload.name.trim(), user_type: payload.user_type };
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ROLES_QUERY_KEY });
    },
  });
}

/** E) useUpdateRoleName(): update solo { name } eq code. NO updated_at. */
export function useUpdateRoleName() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationKey: ['update-role-name'],
    mutationFn: async (payload: { code: string; name: string }) => {
      const { error: e } = await supabase
        .from('AppUserRoles')
        .update({ name: payload.name.trim() })
        .eq('code', payload.code);
      if (e) throw e;
      return payload;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ROLES_QUERY_KEY });
    },
  });
}

/** F) useDeleteRole(): only non-system roles with 0 users. Removes permissions first, then the role. */
export function useDeleteRole() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationKey: ['delete-role'],
    mutationFn: async (payload: { code: string; fallbackRoleCode?: string }) => {
      const { code, fallbackRoleCode } = payload;

      const { data: role, error: roleErr } = await supabase
        .from('AppUserRoles')
        .select('code, is_system, user_type')
        .eq('code', code)
        .single();
      if (roleErr) throw roleErr;

      const userType = (role as AppUserRoleRow).user_type;

      const { data: allRoles, error: allRolesErr } = await supabase
        .from('AppUserRoles')
        .select('code, user_type, is_system')
        .eq('user_type', userType);
      if (allRolesErr) throw allRolesErr;

      const { count, error: countErr } = await supabase
        .from('AppUsers')
        .select('id', { count: 'exact', head: true })
        .eq('role_code', code)
        .eq('user_type', userType)
        .eq('deleted', false);
      if (countErr) throw countErr;

      const assignedUsers = count ?? 0;
      if (assignedUsers > 0) {
        const roleCodesForType = new Set(
          (allRoles ?? [])
            .map((r: { code: string }) => r.code)
        );

        const fallbackCandidates =
          userType === 'dealer'
            ? ['dealer_member', 'dealer']
            : ['member', 'operator_member'];

        const resolvedFallback =
          (fallbackRoleCode && fallbackRoleCode !== code ? fallbackRoleCode : null) ??
          fallbackCandidates.find((candidate) => candidate !== code && roleCodesForType.has(candidate)) ??
          null;

        if (!resolvedFallback) {
          throw new Error(
            `Cannot delete role "${code}" — ${assignedUsers} user(s) are assigned and no fallback role exists for ${userType}.`
          );
        }

        const { error: reassignErr } = await supabase
          .from('AppUsers')
          .update({ role_code: resolvedFallback })
          .eq('role_code', code)
          .eq('user_type', userType)
          .eq('deleted', false);
        if (reassignErr) throw reassignErr;
      }

      const { error: delPermsErr } = await supabase
        .from('AppUserRolePermissions')
        .delete()
        .eq('role_code', code);
      if (delPermsErr) throw delPermsErr;

      const { error: delRoleErr } = await supabase
        .from('AppUserRoles')
        .delete()
        .eq('code', code);
      if (delRoleErr) throw delRoleErr;

      invalidateRolePermissionsCache(code);
      return { code };
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ROLES_QUERY_KEY });
    },
  });
}

/** G) useSyncRolePermissions(): diff current vs desired; delete toRemove, insert toAdd (NO upsert); invalidate rolePermissionCodes + roleList. */
export function useSyncRolePermissions() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationKey: ['sync-role-permissions'],
    mutationFn: async (params: { role_code: string; desiredCodes: string[] }) => {
      const { role_code, desiredCodes } = params;
      const cached = queryClient.getQueryData<Set<string>>(ROLE_PERMISSIONS_QUERY_KEY(role_code));
      let currentSet: Set<string>;
      if (cached instanceof Set) {
        currentSet = cached;
      } else {
        const { data } = await supabase
          .from('AppUserRolePermissions')
          .select('permission_code')
          .eq('role_code', role_code);
        currentSet = new Set(
          (data ?? []).map((r: { permission_code: string }) => r.permission_code)
        );
      }
      const desiredSet = new Set(desiredCodes);
      const toAdd = desiredCodes.filter((c) => !currentSet.has(c));
      const toRemove: string[] = [...currentSet].filter((c) => !desiredSet.has(c));

      if (toRemove.length > 0) {
        const { error: delErr } = await supabase
          .from('AppUserRolePermissions')
          .delete()
          .eq('role_code', role_code)
          .in('permission_code', toRemove);
        if (delErr) throw delErr;
      }
      if (toAdd.length > 0) {
        const rows = toAdd.map((permission_code) => ({ role_code, permission_code }));
        const { error: insErr } = await supabase.from('AppUserRolePermissions').insert(rows);
        if (insErr) throw insErr;
      }
      invalidateRolePermissionsCache(role_code);
      return { role_code };
    },
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: ROLE_PERMISSIONS_QUERY_KEY(variables.role_code) });
      queryClient.invalidateQueries({ queryKey: ROLES_QUERY_KEY });
    },
  });
}
