import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase/client';
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
  canEditContacts: boolean;
  canEditVendors: boolean;
  canViewOwnData: boolean;
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

  // flags de rol (solo 3 roles: superadmin, admin, member)
  const isSuperAdmin = role === 'superadmin';
  const isAdmin = role === 'admin' || isSuperAdmin;
  const isMember = role === 'member';
  // Mantener isOwner e isViewer para compatibilidad con código existente, pero siempre false
  const isOwner = false; // Ya no existe el rol 'owner'
  const isViewer = false; // Ya no existe el rol 'viewer'

  // permisos derivados — según especificación:
  // Superadmin: Puede hacer TODO (incluyendo crear/borrar usuarios)
  // Admin: Puede ver todas las cotizaciones y hacer todo EXCEPTO crear/borrar usuarios
  // Member: Solo puede ver/editar/borrar sus propias cotizaciones
  const canManageOrganization = isSuperAdmin; // Solo superadmin puede gestionar organización
  const canManageUsers = isSuperAdmin; // Solo superadmin puede crear/borrar usuarios
  const canCreateQuotes = isSuperAdmin || isAdmin || isMember; // Todos pueden crear quotes
  const canViewQuotes = !!role || isSuperAdmin; // Todos pueden ver quotes (pero Member solo las suyas)
  const canEditCustomers = isSuperAdmin || isAdmin; // Superadmin y Admin pueden editar customers
  const canEditContacts = isSuperAdmin || isAdmin; // Superadmin y Admin pueden editar contacts
  const canEditVendors = isSuperAdmin || isAdmin; // Superadmin y Admin pueden editar vendors
  const canViewOwnData = !!role || isSuperAdmin; // Todos pueden ver sus propios datos

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
    canEditContacts,
    canEditVendors,
    canViewOwnData,
  };
}
