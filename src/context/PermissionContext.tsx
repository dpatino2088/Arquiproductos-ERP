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
 * Priority:
 * 1. role_code from AppUsers -> load from AppUserRolePermissions (role-based).
 * 2. role admin/superadmin -> all permissions from Permissions.
 * 3. Legacy (temporal): OrganizationUserPermissions by activeMembership.id.
 *    En fase final todos los usuarios tendrán role_code y esta rama se elimina.
 * Fuente de verdad: AppUserRolePermissions; el frontend solo consume el set resuelto.
 */
export function PermissionProvider({ children }: { children: React.ReactNode }) {
  const [permissions, setPermissions] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const { userId } = useAuthSession();
  const { activeOrganizationId, activeMembership, role } = useOrganizationContext();

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
        const permissionSet = await fetchRolePermissions(supabase, appUserRow.role_code);

        // Merge user-level overrides from OrganizationUserPermissions so
        // Permissions module changes are reflected even with role_code users.
        const { data: orgUser } = await supabase
          .from('OrganizationUsers')
          .select('id')
          .eq('organization_id', activeOrganizationId)
          .eq('user_id', userId)
          .eq('deleted', false)
          .limit(1)
          .maybeSingle();

        if (orgUser?.id) {
          const { data: extraPerms, error: extraPermsError } = await supabase
            .from('OrganizationUserPermissions')
            .select('permission_code')
            .eq('organization_user_id', orgUser.id);

          if (!extraPermsError) {
            for (const row of extraPerms || []) {
              if (row?.permission_code) permissionSet.add(row.permission_code);
            }
          } else if (import.meta.env.DEV) {
            console.warn('⚠️ PermissionContext - Could not merge user override permissions:', extraPermsError.message);
          }
        }

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

      // 2) Admin/superadmin: all permissions
      if (role === 'admin' || role === 'superadmin') {
        if (import.meta.env.DEV) {
          console.log('🔍 PermissionContext - Role is admin/superadmin, loading all permissions', {
            role,
            activeMembershipId: activeMembership?.id,
            activeOrganizationId,
          });
        }

        const { data: allPermissions, error: allPermsError } = await supabase
          .from('Permissions')
          .select('code');

        if (allPermsError) {
          if (import.meta.env.DEV) {
            console.error('❌ PermissionContext - Error loading all permissions:', allPermsError);
          }
          setPermissions(new Set());
          setLoading(false);
          return;
        }

        const allPermCodes = new Set<string>(
          (allPermissions || []).map((p: { code: string }) => p.code).filter((c: string | undefined): c is string => Boolean(c))
        );
        setPermissions(allPermCodes);

        if (import.meta.env.DEV) {
          console.log('✅ PermissionContext - All permissions loaded for admin/superadmin:', {
            count: allPermCodes.size,
            role,
          });
        }
        setLoading(false);
        return;
      }

      // 3) Legacy (temporal): OrganizationUserPermissions. Fase final = solo role_code.
      if (!activeMembership?.id) {
        if (import.meta.env.DEV) {
          console.warn('⚠️ PermissionContext - No activeMembership.id and no AppUser role_code');
        }
        setPermissions(new Set());
        setLoading(false);
        return;
      }

      if (import.meta.env.DEV) {
        console.log('🔍 PermissionContext - Loading legacy permissions for organization_user_id:', activeMembership.id);
      }

      const { data: userPermissions, error: permissionsError } = await supabase
        .from('OrganizationUserPermissions')
        .select('permission_code')
        .eq('organization_user_id', activeMembership.id);

      if (permissionsError) {
        if (import.meta.env.DEV) {
          console.error('❌ PermissionContext - Error loading user permissions:', permissionsError.message);
        }
        setPermissions(new Set());
        setLoading(false);
        return;
      }

      const permissionSet = new Set<string>(
        (userPermissions || []).map((p: { permission_code: string }) => p.permission_code).filter((c: string | undefined): c is string => Boolean(c))
      );
      setPermissions(permissionSet);

      if (import.meta.env.DEV) {
        console.log('✅ PermissionContext - User permissions loaded (legacy):', { count: permissionSet.size });
      }
    } catch (err: any) {
      if (import.meta.env.DEV) {
        console.error('❌ PermissionContext - Exception loading permissions:', err?.message);
      }
      setPermissions(new Set());
    } finally {
      setLoading(false);
    }
  }, [userId, activeOrganizationId, activeMembership?.id, role]);

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
