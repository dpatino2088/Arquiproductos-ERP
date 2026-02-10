/**
 * AppUserRoles + batch/cache helpers.
 * Tables: public."AppUserRoles", public."AppUserRolePermissions".
 * NO legacy renames; use exact table names.
 */

import { useState, useEffect } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';
import { supabase } from './supabase/client';

export type AppUserType = 'org' | 'dealer';

export interface AppUserRole {
  code: string;
  name: string;
  user_type: AppUserType;
}

// Simple in-memory cache (no invalidation for now; avoids refetch on every render)
const rolesByTypeCache = new Map<AppUserType, AppUserRole[]>();
const rolePermissionsCache = new Map<string, Set<string>>();

/**
 * Fetch roles for a user type from AppUserRoles.
 * Cached per user_type.
 */
export async function fetchRolesByType(
  supabase: SupabaseClient,
  userType: AppUserType
): Promise<AppUserRole[]> {
  const cached = rolesByTypeCache.get(userType);
  if (cached) return cached;

  const { data, error } = await supabase
    .from('AppUserRoles')
    .select('code, name, user_type')
    .eq('user_type', userType)
    .order('name');

  if (error) throw error;
  const list = (data || []).map((r: { code: string; name: string; user_type: string }) => ({
    code: r.code,
    name: r.name,
    user_type: r.user_type as AppUserType,
  }));
  rolesByTypeCache.set(userType, list);
  return list;
}

/**
 * Fetch permission codes for a role from AppUserRolePermissions.
 * Cached per role_code.
 */
export async function fetchRolePermissions(
  supabase: SupabaseClient,
  roleCode: string
): Promise<Set<string>> {
  const cached = rolePermissionsCache.get(roleCode);
  if (cached) return cached;

  const { data, error } = await supabase
    .from('AppUserRolePermissions')
    .select('permission_code')
    .eq('role_code', roleCode);

  if (error) throw error;
  const set = new Set<string>(
    (data || []).map((r: { permission_code: string }) => r.permission_code).filter(Boolean)
  );
  rolePermissionsCache.set(roleCode, set);
  return set;
}

/** Invalidate cached permissions for a role (e.g. after admin edit). */
export function invalidateRolePermissionsCache(roleCode: string): void {
  rolePermissionsCache.delete(roleCode);
}

/**
 * React hook: load roles for a user type (uses cached fetchRolesByType).
 * For use in AppUser/DealerUser create/edit screens.
 */
export function useRolesForUserType(userType: AppUserType | null) {
  const [roles, setRoles] = useState<AppUserRole[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!userType) {
      setRoles([]);
      setLoading(false);
      setError(null);
      return;
    }
    let cancelled = false;
    setLoading(true);
    setError(null);
    fetchRolesByType(supabase, userType)
      .then((list) => {
        if (!cancelled) setRoles(list);
      })
      .catch((err) => {
        if (!cancelled) {
          setError(err?.message ?? 'Failed to load roles');
          setRoles([]);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => { cancelled = true; };
  }, [userType]);

  return { roles, loading, error };
}
