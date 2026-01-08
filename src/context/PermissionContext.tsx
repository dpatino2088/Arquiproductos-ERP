import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useAuthStore } from '../stores/auth-store';
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

export function PermissionProvider({ children }: { children: React.ReactNode }) {
  const [permissions, setPermissions] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const { user } = useAuthStore();
  const { activeOrganizationId } = useOrganizationContext();

  const loadPermissions = useCallback(async () => {
    if (!user?.id || !activeOrganizationId) {
      setPermissions(new Set());
      setLoading(false);
      return;
    }

    try {
      setLoading(true);

      // Get organization user to check role
      const { data: orgUser, error: orgUserError } = await supabase
        .from('OrganizationUsers')
        .select('id, role')
        .eq('user_id', user.id)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .maybeSingle();

      if (orgUserError || !orgUser) {
        setPermissions(new Set());
        setLoading(false);
        return;
      }

      // Superadmin has all permissions (we'll load them all)
      if (orgUser.role === 'superadmin') {
        const { data: allPermissions } = await supabase
          .from('Permissions')
          .select('code');

        if (allPermissions) {
          setPermissions(new Set(allPermissions.map(p => p.code)));
        } else {
          setPermissions(new Set());
        }
        setLoading(false);
        return;
      }

      // For admin and member, load their specific permissions
      const { data: userPermissions, error: permissionsError } = await supabase
        .from('OrganizationUserPermissions')
        .select('permission_code')
        .eq('organization_user_id', orgUser.id);

      if (permissionsError) {
        if (import.meta.env.DEV) {
          console.error('Error loading permissions:', permissionsError);
        }
        setPermissions(new Set());
        setLoading(false);
        return;
      }

      const permissionSet = new Set(
        (userPermissions || []).map(p => p.permission_code)
      );
      setPermissions(permissionSet);
    } catch (err) {
      if (import.meta.env.DEV) {
        console.error('Error loading permissions:', err);
      }
      setPermissions(new Set());
    } finally {
      setLoading(false);
    }
  }, [user?.id, activeOrganizationId]);

  useEffect(() => {
    loadPermissions();
  }, [loadPermissions]);

  const can = useCallback((permissionCode: string): boolean => {
    return permissions.has(permissionCode);
  }, [permissions]);

  const hasAnyPermission = useCallback((permissionCodes: string[]): boolean => {
    return permissionCodes.some(code => permissions.has(code));
  }, [permissions]);

  const hasAllPermissions = useCallback((permissionCodes: string[]): boolean => {
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

