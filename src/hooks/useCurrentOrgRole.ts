import { useEffect, useState, useRef } from 'react';
import { supabase } from '../lib/supabase/client';
import type { OrgRole } from '../types/roles';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useAuthSession } from './useAuthSession';
import { mapLegacyRole, isValidOrgRole } from '../rbac/rolePresets';

type UseCurrentOrgRoleOptions = {
  organizationId?: string | null;
};

type UseCurrentOrgRoleResult = {
  role: OrgRole | null;
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
  canEditQuotes: boolean;
  canViewQuotes: boolean;
  canEditCustomers: boolean;
  canEditContacts: boolean;
  canViewOwnData: boolean;
};

export function useCurrentOrgRole(
  options: UseCurrentOrgRoleOptions = {}
): UseCurrentOrgRoleResult {
  const { activeOrganizationId } = useOrganizationContext();
  const effectiveOrgId = options.organizationId ?? activeOrganizationId ?? null;
  const { session, userId, loading: sessionLoading } = useAuthSession();
  const [role, setRole] = useState<OrgRole | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const lastKeyRef = useRef<string>('');

  useEffect(() => {
    // ✅ FIX: Guard para evitar doble ejecución
    const key = `${userId || ''}:${effectiveOrgId || ''}`;
    if (lastKeyRef.current === key) {
      return;
    }
    lastKeyRef.current = key;

    // ✅ FIX: Si session está cargando, esperar
    if (sessionLoading) {
      return;
    }

    // ✅ FIX: Si no hay userId o session, retornar sin rol
    if (!userId || !session?.user) {
      setRole(null);
      setLoading(false);
      return;
    }

    let cancelled = false;

    async function loadRole() {
      try {
        setLoading(true);
        setError(null);

        // 1) AppUsers (unified): org users — role from role_code (superadmin, admin, operator, etc.)
        const { data: appUserOrgRows, error: appUserError } = await supabase
          .from('AppUsers')
          .select('role_code')
          .eq('auth_user_id', userId)
          .eq('user_type', 'org')
          .eq('deleted', false)
          .in('status', ['active', 'invited'])
          .limit(10);

        if (!cancelled && Array.isArray(appUserOrgRows) && appUserOrgRows.length > 0) {
          // Prefer superadmin if user has it in any org row
          const roleCode = appUserOrgRows.some((r: { role_code?: string }) =>
            String(r?.role_code ?? '').trim().toLowerCase() === 'superadmin'
          )
            ? 'superadmin'
            : String(appUserOrgRows[0]?.role_code ?? '').trim().toLowerCase();
          if (roleCode) {
            if (roleCode === 'superadmin') {
              setRole('superadmin');
              setLoading(false);
              return;
            }
            if (isValidOrgRole(roleCode)) {
              setRole(roleCode as OrgRole);
              setLoading(false);
              return;
            }
            setRole(mapLegacyRole(roleCode));
            setLoading(false);
            return;
          }
        }

        if (appUserError && appUserError.code !== 'PGRST116' && import.meta.env.DEV) {
          console.debug('[useCurrentOrgRole] AppUsers (org) lookup error:', appUserError.code);
        }

        // 2) Portal user check — DealerUsers entries (no AppUsers org row)
        const { data: portalRows, error: portalError } = await supabase
          .from('DealerUsers')
          .select('id, role, status')
          .eq('user_id', userId)
          .eq('deleted', false)
          .in('status', ['active', 'invited'])
          .limit(1);

        const portalUser = Array.isArray(portalRows) && portalRows.length > 0 ? portalRows[0] : null;

        if (portalError && portalError.code !== 'PGRST116' && portalError.code !== '42P01' && import.meta.env.DEV) {
          console.debug('[useCurrentOrgRole] DealerUsers lookup error:', portalError.code);
        }

        if (!cancelled && portalUser) {
          setRole(null);
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
          .eq('user_id', userId)
          .eq('deleted', false)
          .maybeSingle();

        if (orgError && orgError.code !== 'PGRST116') {
          throw orgError;
        }

        if (!cancelled) {
          let dbRole: OrgRole | null = null;
          if (orgUser?.role) {
            const roleStr = orgUser.role.toString();
            if (isValidOrgRole(roleStr)) {
              dbRole = roleStr;
            } else {
              // Map legacy role to new role
              dbRole = mapLegacyRole(roleStr);
            }
          }
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
  }, [userId, effectiveOrgId, sessionLoading]);

  // flags de rol (nuevos roles solamente, legacy ya está mapeado por mapLegacyRole)
  const isSuperAdmin = role === 'superadmin';
  const isOwner = false; // Legacy 'owner' should be mapped to 'superadmin' by mapLegacyRole
  const isAdmin = role === 'admin' || isSuperAdmin; // Superadmin tiene permisos de admin
  const isMember = role === 'operator'; // Legacy 'member' maps to 'operator'
  const isViewer = false; // Legacy 'viewer' should be mapped by mapLegacyRole

  // permisos derivados — según especificación:
  // Superadmin: Puede hacer TODO (incluyendo crear/borrar usuarios)
  // Admin: Puede ver todas las cotizaciones y hacer todo EXCEPTO crear/borrar usuarios (depende de permisos)
  // Operator/Procurement/Finance: Permisos basados en permisos explícitos
  const canManageOrganization = isSuperAdmin; // Solo superadmin puede gestionar organización
  const canManageUsers = isSuperAdmin || isAdmin; // Superadmin y Admin pueden crear/borrar usuarios (si tienen permiso)
  const canCreateQuotes = !!role; // Todos los roles pueden crear quotes (si tienen permiso)
  const canEditQuotes = !!role; // Todos los roles pueden editar quotes (si tienen permiso)
  const canViewQuotes = !!role; // Todos los roles pueden ver quotes (si tienen permiso)
  const canEditCustomers = isSuperAdmin || isAdmin || role === 'operator' || role === 'procurement' || role === 'finance'; // Depende de permisos
  const canEditContacts = isSuperAdmin || isAdmin || role === 'operator' || role === 'procurement' || role === 'finance'; // Depende de permisos
  const canViewOwnData = !!role; // Todos pueden ver sus propios datos

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
    canEditQuotes,
    canViewQuotes,
    canEditCustomers,
    canEditContacts,
    canViewOwnData,
  };
}
