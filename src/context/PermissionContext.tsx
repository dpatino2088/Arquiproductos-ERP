import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { fetchRolePermissions } from '../lib/roles';
import { useAuthSession } from '../hooks/useAuthSession';
import { useOrganizationContext } from './OrganizationContext';

interface PermissionContextType {
  permissions: Set<string>;
  loading: boolean;
  can: (permissionCode: string) => boolean;
  hasAnyPermission: (permissionCodes: string[]) => boolean;
  hasAllPermissions: (permissionCodes: string[]) => boolean;
  refreshPermissions: () => Promise<void>;
}

const PermissionContext = createContext<PermissionContextType | undefined>(undefined);

// Export the context for direct access if needed
export { PermissionContext };

/**
 * PermissionProvider - RBAC permissions for the active context.
 *
 * Source of truth: AppUserRolePermissions (via role_code on AppUsers).
 *
 * Priority:
 * 1. role_code from AppUsers -> AppUserRolePermissions (all users must have this).
 * 2. Fallback for admin/superadmin without AppUsers row -> load all Permissions.
 * 3. No role_code and not admin/superadmin -> empty set (deny all).
 *
 * OrganizationUserPermissions (legacy individual overrides) is intentionally
 * NOT used — it caused permission bleed-through across role changes.
 */
export function PermissionProvider({ children }: { children: React.ReactNode }) {
  const [permissions, setPermissions] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const { userId } = useAuthSession();
  const { activeOrganizationId, activeMembership, role } = useOrganizationContext();
  // activeMembership is kept for the dev-log below; not used for permission resolution.

  const loadPermissions = useCallback(async () => {
    if (!userId || !activeOrganizationId) {
      if (import.meta.env.DEV) {
        console.log('🔍 PermissionContext - No userId or activeOrganizationId, clearing permissions');
      }
      setPermissions(new Set());
      setLoading(false);
      return;
    }

    try {
      setLoading(true);

      if (import.meta.env.DEV) {
        console.log('🔍 PermissionContext - Loading permissions for:', {
          userId,
          activeOrganizationId,
          role: activeMembership?.role,
        });
      }

      // 1) Try AppUsers.role_code -> AppUserRolePermissions (unified roles)
      const { data: appUserRow } = await supabase
        .from('AppUsers')
        .select('role_code')
        .eq('auth_user_id', userId)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .limit(1)
        .maybeSingle();

      if (appUserRow?.role_code) {
        // role_code is the source of truth — permissions come exclusively from AppUserRolePermissions.
        // OrganizationUserPermissions (legacy) is intentionally NOT merged here to prevent
        // stale individual overrides from bleeding through role-based access control.
        const permissionSet = await fetchRolePermissions(supabase, appUserRow.role_code);
        setPermissions(permissionSet);
        if (import.meta.env.DEV) {
          console.log('✅ PermissionContext - Permissions from AppUserRolePermissions (role_code):', {
            role_code: appUserRow.role_code,
            count: permissionSet.size,
          });
        }
        setLoading(false);
        return;
      }

      // 2) Fallback: admin/superadmin without an AppUsers row (edge case during setup).
      // In normal operation all admins have an AppUsers row with role_code='superadmin'/'admin'
      // and are handled by path 1 above. This path ensures they never get locked out.
      if (role === 'admin' || role === 'superadmin') {
        if (import.meta.env.DEV) {
          console.log('🔍 PermissionContext - Fallback: admin/superadmin without AppUsers row, loading all permissions');
        }
        const { data: allPermissions, error: allPermsError } = await supabase
          .from('Permissions')
          .select('code');
        if (!allPermsError) {
          setPermissions(new Set<string>(
            (allPermissions || []).map((p: { code: string }) => p.code).filter(Boolean)
          ));
        } else {
          setPermissions(new Set());
        }
        setLoading(false);
        return;
      }

      // 3) No role_code, not admin/superadmin → deny all.
      // Every user should have a role_code assigned; if not, it's a data issue.
      if (import.meta.env.DEV) {
        console.warn('⚠️ PermissionContext - User has no role_code and is not admin/superadmin. Denying all permissions.', {
          userId, activeOrganizationId,
        });
      }
      setPermissions(new Set());
      setLoading(false);
    } catch (err: any) {
      if (import.meta.env.DEV) {
        console.error('❌ PermissionContext - Exception loading permissions:', err?.message);
      }
      setPermissions(new Set());
    } finally {
      setLoading(false);
    }
  }, [userId, activeOrganizationId, role]);

  useEffect(() => {
    loadPermissions();
  }, [loadPermissions]);

  const can = useCallback((permissionCode: string): boolean => {
    return permissions.has(permissionCode);
  }, [permissions]);

  const hasAnyPermission = useCallback((permissionCodes: string[]): boolean => {
    if (!permissionCodes || permissionCodes.length === 0) return false;
    return permissionCodes.some(code => permissions.has(code));
  }, [permissions]);

  const hasAllPermissions = useCallback((permissionCodes: string[]): boolean => {
    if (!permissionCodes || permissionCodes.length === 0) return true;
    return permissionCodes.every(code => permissions.has(code));
  }, [permissions]);

  const refreshPermissions = useCallback(async () => {
    await loadPermissions();
  }, [loadPermissions]);

  return (
    <PermissionContext.Provider
      value={{
        permissions,
        loading,
        can,
        hasAnyPermission,
        hasAllPermissions,
        refreshPermissions,
      }}
    >
      {children}
    </PermissionContext.Provider>
  );
}

export function usePermission() {
  const context = useContext(PermissionContext);
  if (context === undefined) {
    throw new Error('usePermission must be used within a PermissionProvider');
  }
  return context;
}
