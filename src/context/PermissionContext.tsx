import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
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
 * PermissionProvider - Loads and provides RBAC permissions for the active organization
 * 
 * Schema used:
 * - Permissions: code (PK), module, description
 * - OrganizationUserPermissions: organization_user_id, permission_code
 * 
 * Fallback logic:
 * - role='owner' => all permissions
 * - role='admin' => all permissions (can be restricted later)
 * - Other roles => only assigned permissions from OrganizationUserPermissions
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

      // Fallback: owner, admin, and superadmin have all permissions
      // We'll load all permissions if role is owner/admin/superadmin
      if (role === 'owner' || role === 'admin' || role === 'superadmin' || role === 'super_admin') {
        if (import.meta.env.DEV) {
          console.log('🔍 PermissionContext - Role is owner/admin/superadmin, loading all permissions', {
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

        const allPermCodes = new Set((allPermissions || []).map(p => p.code).filter(Boolean));
        setPermissions(allPermCodes);

        if (import.meta.env.DEV) {
          console.log('✅ PermissionContext - All permissions loaded for owner/admin/superadmin:', {
            count: allPermCodes.size,
            permissions: Array.from(allPermCodes),
            role: role,
          });
        }

        setLoading(false);
        return;
      }

      // For other roles, load specific permissions from OrganizationUserPermissions
      // We need organization_user_id from activeMembership
      if (!activeMembership?.id) {
        if (import.meta.env.DEV) {
          console.warn('⚠️ PermissionContext - No activeMembership.id found for role:', role);
        }
        setPermissions(new Set());
        setLoading(false);
        return;
      }

      if (import.meta.env.DEV) {
        console.log('🔍 PermissionContext - Loading specific permissions for organization_user_id:', activeMembership.id);
      }

      // Query: OrganizationUserPermissions -> permission_code where organization_user_id = activeMembership.id
      const { data: userPermissions, error: permissionsError } = await supabase
        .from('OrganizationUserPermissions')
        .select('permission_code')
        .eq('organization_user_id', activeMembership.id);

      if (permissionsError) {
        if (import.meta.env.DEV) {
          console.error('❌ PermissionContext - Error loading user permissions:', {
            code: permissionsError.code,
            message: permissionsError.message,
            details: permissionsError.details,
          });
        }
        setPermissions(new Set());
        setLoading(false);
        return;
      }

      const permissionSet = new Set(
        (userPermissions || []).map(p => p.permission_code).filter(Boolean)
      );

      setPermissions(permissionSet);

      if (import.meta.env.DEV) {
        console.log('✅ PermissionContext - User permissions loaded:', {
          count: permissionSet.size,
          permissions: Array.from(permissionSet),
        });
      }
    } catch (err: any) {
      if (import.meta.env.DEV) {
        console.error('❌ PermissionContext - Exception loading permissions:', {
          error: err,
          message: err?.message,
          stack: err?.stack,
        });
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
