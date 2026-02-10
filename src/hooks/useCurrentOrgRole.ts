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

        // ✅ CRITICAL FIX: First check if user is a Portal User (DealerUsers)
        // Portal users should NOT have Organization roles - they are external customers
        // IMPORTANT: Use 'role' and 'status' columns (matches actual DB schema)
        const { data: portalUser, error: portalError } = await supabase
          .from('DealerUsers')
          .select('id, role, status')
          .eq('user_id', userId)
          .eq('deleted', false)
          .in('status', ['active', 'invited'])
          .maybeSingle();

        if (portalError && import.meta.env.DEV) {
          console.error('[useCurrentOrgRole] DealerUsers lookup error', {
            message: portalError.message,
            details: portalError.details,
            hint: portalError.hint,
            code: portalError.code,
          });
        }

        // If user is a portal user, they should NOT have organization roles
        if (!cancelled && portalUser) {
          // Use 'role' column (from actual DB schema)
          const portalRole = portalUser.role;
          if (import.meta.env.DEV) {
            console.log('🔒 [useCurrentOrgRole] User is a Portal User, returning null for org role:', {
              portalUserId: portalUser.id,
              portalRole: portalRole,
              userId: userId,
            });
          }
          // Portal users should NOT have organization roles
          setRole(null);
          setLoading(false);
          return;
        }

        // If there was an error other than "not found", log it but continue
        if (portalError && portalError.code !== 'PGRST116' && portalError.code !== '42P01') {
          if (import.meta.env.DEV) {
            console.debug('[useCurrentOrgRole] Error checking portal user (continuing):', portalError.code);
          }
        }

        // 2) SUPERADMIN = fila en PlatformAdmins
        // Nota: Si la tabla no existe, esto fallará silenciosamente
        const { data: platformAdmin, error: paError } = await supabase
          .from('PlatformAdmins')
          .select('user_id')
          .eq('user_id', userId)
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

        // 4) Rol en OrganizationUsers (solo si NO es portal user)
        // #region agent log
        fetch('http://127.0.0.1:7242/ingest/ad52049f-725d-41d8-812c-491bc7b292e1',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'useCurrentOrgRole.ts:108',message:'Checking OrganizationUsers role',data:{userId,effectiveOrgId},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'A,B'})}).catch(()=>{});
        // #endregion
        const { data: orgUser, error: orgError } = await supabase
          .from('OrganizationUsers')
          .select('role')
          .eq('organization_id', effectiveOrgId)
          .eq('user_id', userId)
          .eq('deleted', false)
          .maybeSingle();
        // #region agent log
        fetch('http://127.0.0.1:7242/ingest/ad52049f-725d-41d8-812c-491bc7b292e1',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'useCurrentOrgRole.ts:114',message:'OrganizationUsers query result',data:{foundOrgUser:!!orgUser,role:orgUser?.role,orgErrorCode:orgError?.code},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'A,B'})}).catch(()=>{});
        // #endregion

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
