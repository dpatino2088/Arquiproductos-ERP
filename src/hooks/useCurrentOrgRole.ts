import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import type { OrgRole } from '../types/roles';
import { useOrganizationContext } from '../context/OrganizationContext';

type UseCurrentOrgRoleOptions = {
  organizationId?: string | null;
};

type UseCurrentOrgRoleResult = {
  role: OrgRole;
  loading: boolean;
  error: string | null;

  // flags
  isSuperAdmin: boolean;
  isOwner: boolean;
  isAdmin: boolean;
  isMember: boolean;
  isViewer: boolean;

  // permisos derivados
  canManageOrganization: boolean;
  canManageUsers: boolean;
  canCreateQuotes: boolean;
  canViewQuotes: boolean;
  canEditCustomers: boolean;
};

export function useCurrentOrgRole(
  options: UseCurrentOrgRoleOptions = {}
): UseCurrentOrgRoleResult {
  const { activeOrganizationId } = useOrganizationContext();
  const effectiveOrgId = options.organizationId ?? activeOrganizationId ?? null;
  const [role, setRole] = useState<OrgRole>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function loadRole() {
      try {
        setLoading(true);
        setError(null);

        // 1) Usuario actual
        const {
          data: { user },
          error: userError,
        } = await supabase.auth.getUser();

        if (userError) throw userError;

        if (!user) {
          if (!cancelled) {
            setRole(null);
            setLoading(false);
          }
          return;
        }

        // 2) SUPERADMIN = fila en PlatformAdmins
        // Nota: Si la tabla no existe, esto fallará silenciosamente
        const { data: platformAdmin, error: paError } = await supabase
          .from('PlatformAdmins')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

        // Si la tabla no existe (PGRST116 o 42P01), continuamos sin superadmin
        if (paError && paError.code !== 'PGRST116' && paError.code !== '42P01') {
          // Solo lanzamos error si no es "no encontrado" o "tabla no existe"
          if (import.meta.env.DEV) {
            console.debug('PlatformAdmins table may not exist:', paError.code);
          }
        }

        if (!cancelled && platformAdmin) {
          setRole('superadmin');
          setLoading(false);
          return;
        }

        // 3) Sin organizationId → no hay rol de organización
        if (!effectiveOrgId) {
          if (!cancelled) {
            setRole(null);
            setLoading(false);
          }
          return;
        }

        // 4) Rol en OrganizationUsers
        const { data: orgUser, error: orgError } = await supabase
          .from('OrganizationUsers')
          .select('role')
          .eq('organization_id', effectiveOrgId)
          .eq('user_id', user.id)
          .eq('deleted', false)
          .maybeSingle();

        if (orgError && orgError.code !== 'PGRST116') {
          throw orgError;
        }

        if (!cancelled) {
          const dbRole = (orgUser?.role as OrgRole) ?? null;
          setRole(dbRole);
          setLoading(false);
        }
      } catch (err: any) {
        if (!cancelled) {
          console.error('Error loading org role', err);
          setError(err.message ?? 'Error loading role');
          setRole(null);
          setLoading(false);
        }
      }
    }

    loadRole();

    return () => {
      cancelled = true;
    };
  }, [effectiveOrgId]);

  // flags de rol (incluyendo superadmin como nivel más alto)
  const isSuperAdmin = role === 'superadmin';
  const isOwner = role === 'owner' || isSuperAdmin;
  const isAdmin = role === 'admin' || isOwner || isSuperAdmin;
  const isMember = role === 'member';
  const isViewer = role === 'viewer';

  // permisos derivados — aquí definimos la política funcional
  const canManageOrganization = isOwner || isSuperAdmin;
  const canManageUsers = isOwner || isAdmin || isSuperAdmin; // admin también puede gestionar usuarios
  const canCreateQuotes = isOwner || isAdmin || isMember || isSuperAdmin;
  const canViewQuotes = !!role || isSuperAdmin;
  const canEditCustomers = isOwner || isAdmin || isMember || isSuperAdmin;

  return {
    role,
    loading,
    error,
    isSuperAdmin,
    isOwner,
    isAdmin,
    isMember,
    isViewer,
    canManageOrganization,
    canManageUsers,
    canCreateQuotes,
    canViewQuotes,
    canEditCustomers,
  };
}
