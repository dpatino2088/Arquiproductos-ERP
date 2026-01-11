import React, {
  createContext,
  useContext,
  useEffect,
  useState,
  ReactNode,
  useRef,
  useCallback,
  useMemo,
} from 'react';
import { supabase } from '../lib/supabase/client';
import type { OrgRole } from '../types/roles';
import { useAuthSession } from '../hooks/useAuthSession';

/**
 * Organization Membership - represents a user's membership in an organization
 */
export type OrganizationMembership = {
  id: string;
  organization_id: string;
  user_id: string;
  user_email: string;
  user_name: string | null;
  role: OrgRole;
  status: 'invited' | 'active' | 'disabled';
  deleted: boolean;
  created_at: string;
  updated_at: string;
};

/**
 * Organization Summary - organization info with user's role
 */
export type OrganizationSummary = {
  id: string;
  name: string;
  role: OrgRole | null; // null for portal users (role comes from useAccessContext.portalRole)
  status: 'invited' | 'active' | 'disabled';
  created_at: string;
};

type OrganizationContextValue = {
  memberships: OrganizationMembership[];
  organizations: OrganizationSummary[];

  activeOrganizationId: string | null;
  activeOrganization: OrganizationSummary | null;
  activeMembership: OrganizationMembership | null;
  role: OrgRole | null;

  loading: boolean;
  error: string | null;
  hasOrganizations: boolean;

  setActiveOrganizationId: (id: string | null) => void;
  refresh: () => Promise<void>;
};

const OrganizationContext = createContext<OrganizationContextValue | undefined>(undefined);

const STORAGE_KEY = 'activeOrganizationId';

function normalizeEmail(email: string | null | undefined) {
  return (email || '').toString().trim().toLowerCase();
}

export function OrganizationProvider({ children }: { children: ReactNode }) {
  const { session, userId, loading: authLoading, error: authError } = useAuthSession();

  const [memberships, setMemberships] = useState<OrganizationMembership[]>([]);
  const [organizations, setOrganizations] = useState<OrganizationSummary[]>([]);
  const [activeOrganizationId, setActiveOrganizationIdState] = useState<string | null>(null);

  const [orgLoading, setOrgLoading] = useState(false);
  const [orgError, setOrgError] = useState<string | null>(null);

  // evita race conditions
  const requestSeqRef = useRef(0);

  const sessionEmail = useMemo(() => normalizeEmail(session?.user?.email), [session?.user?.email]);

  const setActiveOrganizationId = useCallback((id: string | null) => {
    setActiveOrganizationIdState(id);
    if (id) localStorage.setItem(STORAGE_KEY, id);
    else localStorage.removeItem(STORAGE_KEY);
  }, []);

  const loadOrganizations = useCallback(
    async (currentUserId: string, currentEmail: string) => {
      const reqId = ++requestSeqRef.current;

      if (import.meta.env.DEV) {
        console.log('[OrganizationContext] load:start', {
          reqId,
          currentUserId,
          currentEmail,
        });
      }

      setOrgLoading(true);
      setOrgError(null);

      try {
        // ==============================
        // STEP 1: INTERNAL OrganizationUsers
        // ==============================
        const { data: membershipsData, error: membershipsError } = await supabase
          .from('OrganizationUsers')
          .select('id, organization_id, user_id, user_email, user_name, role, status, deleted, created_at, updated_at')
          .eq('user_id', currentUserId)
          .eq('deleted', false)
          .in('status', ['active', 'invited']);

        if (reqId !== requestSeqRef.current) return; // stale

        if (membershipsError && import.meta.env.DEV) {
          console.error('[OrganizationContext] OrganizationUsers error:', membershipsError);
        }

        const internalMemberships: OrganizationMembership[] = (membershipsData || []).map((m: any) => ({
          id: m.id,
          organization_id: m.organization_id,
          user_id: m.user_id,
          user_email: (m.user_email || '').toString().trim(),
          user_name: m.user_name || null,
          role: (m.role || 'viewer') as OrgRole,
          status: (m.status || 'active') as 'invited' | 'active' | 'disabled',
          deleted: !!m.deleted,
          created_at: m.created_at || new Date().toISOString(),
          updated_at: m.updated_at || new Date().toISOString(),
        }));

        const internalOrgIds = internalMemberships.map((m) => m.organization_id).filter(Boolean);

        if (import.meta.env.DEV) {
          console.log('[OrganizationContext] internal', {
            count: internalMemberships.length,
            orgIds: internalOrgIds,
          });
        }

        // ==============================
        // STEP 2: If none, PORTAL CompanyPortalUsers
        // ==============================
        let orgIdsToLoad: string[] = [];
        let portalMode = false;

        if (internalOrgIds.length > 0) {
          portalMode = false;
          orgIdsToLoad = internalOrgIds;
          setMemberships(internalMemberships);
        } else {
          portalMode = true;

          // buscamos por user_id OR email (case-insensitive)
          // Nota: usamos `or()` con eq/ilike para soportar ambos caminos.
          const orParts: string[] = [];
          if (currentUserId) orParts.push(`user_id.eq.${currentUserId}`);
          if (currentEmail) orParts.push(`portal_user_email.ilike.${currentEmail}`);

          // ✅ CORRECCIÓN: SOLO usar status, NO portal_user_status
          const { data: portalRows, error: portalErr } = await supabase
            .from('CompanyPortalUsers')
            .select('id, organization_id, portal_user_email, status, deleted, user_id')
            .eq('deleted', false)
            .in('status', ['active', 'invited'])
            .or(orParts.join(','));

          if (reqId !== requestSeqRef.current) return; // stale

          if (portalErr && import.meta.env.DEV) {
            console.error('[OrganizationContext] CompanyPortalUsers error:', portalErr);
          }

          // ✅ Ya filtrado por query, usar directamente
          const activePortal = portalRows || [];

          const portalOrgIds = activePortal.map((pu: any) => pu.organization_id).filter(Boolean);

          if (import.meta.env.DEV) {
            console.log('[OrganizationContext] portal', {
              found: (portalRows || []).length,
              active: activePortal.length,
              orgIds: portalOrgIds,
            });
          }

          orgIdsToLoad = portalOrgIds;
          setMemberships([]); // portal users no tienen OrganizationUsers role
        }

        // ==============================
        // STEP 3: Load Organizations
        // ==============================
        if (!orgIdsToLoad.length) {
          if (import.meta.env.DEV) console.warn('[OrganizationContext] no orgIds -> empty state');
          setOrganizations([]);
          setActiveOrganizationId(null);
          return;
        }

        const { data: orgsData, error: orgsError } = await supabase
          .from('Organizations')
          .select('id, name, created_at')
          .in('id', orgIdsToLoad)
          .eq('deleted', false)
          .order('created_at', { ascending: false });

        if (reqId !== requestSeqRef.current) return; // stale

        if (orgsError) throw new Error(`Failed to load organizations: ${orgsError.message}`);

        // Build summaries
        const orgsMap = new Map<string, OrganizationSummary>();

        if (!portalMode) {
          // internal: role desde membership
          for (const mem of internalMemberships) {
            const org = (orgsData || []).find((o: any) => o.id === mem.organization_id);
            if (!org) continue;
            orgsMap.set(org.id, {
              id: org.id,
              name: org.name || 'Unnamed Organization',
              role: mem.role,
              status: mem.status,
              created_at: org.created_at || mem.created_at,
            });
          }
        } else {
          // portal: no asignar rol aquí (será null), OrganizationSwitcher usará useAccessContext.portalRole
          for (const org of orgsData || []) {
            orgsMap.set(org.id, {
              id: org.id,
              name: org.name || 'Unnamed Organization',
              role: null, // Portal users don't have org roles, useAccessContext will provide portalRole
              status: 'active',
              created_at: org.created_at || new Date().toISOString(),
            });
          }
        }

        const roleOrder: Record<string, number> = {
          superadmin: -1,
          owner: 0,
          admin: 1,
          operator: 2,
          procurement: 3,
          finance: 4,
          member: 5,
          viewer: 6,
        };

        const safeOrgs = Array.from(orgsMap.values()).sort((a, b) => {
          // Handle null roles (portal users) - sort them last
          const aRole = a.role || '';
          const bRole = b.role || '';
          const ao = roleOrder[aRole] ?? 999;
          const bo = roleOrder[bRole] ?? 999;
          if (ao !== bo) return ao - bo;
          return a.name.localeCompare(b.name);
        });

        setOrganizations(safeOrgs);

        // Active org selection
        const stored = localStorage.getItem(STORAGE_KEY);
        const storedValid = !!stored && safeOrgs.some((o) => o.id === stored);

        const nextActive = storedValid ? stored! : safeOrgs[0]?.id ?? null;
        setActiveOrganizationId(nextActive);

        if (import.meta.env.DEV) {
          console.log('[OrganizationContext] load:done', {
            reqId,
            portalMode,
            orgsCount: safeOrgs.length,
            nextActive,
          });
        }
      } catch (err: any) {
        if (import.meta.env.DEV) console.error('[OrganizationContext] load:error', err);
        const msg = err?.message || 'Failed to load organizations';
        setOrgError(msg);
        setMemberships([]);
        setOrganizations([]);
        setActiveOrganizationId(null);
      } finally {
        if (reqId === requestSeqRef.current) {
          setOrgLoading(false);
        }
        if (import.meta.env.DEV) console.log('[OrganizationContext] load:finally', { reqId });
      }
    },
    [setActiveOrganizationId]
  );

  // ✅ Load orgs when auth is ready and user changes
  useEffect(() => {
    // Si hay error de auth, reflejarlo
    if (authError) {
      setOrgError(authError);
      setOrgLoading(false);
      setMemberships([]);
      setOrganizations([]);
      setActiveOrganizationId(null);
      return;
    }

    // Mientras authLoading, no hacemos nada (NO timeout fake aquí)
    if (authLoading) return;

    // Si no hay userId -> limpiar
    if (!userId) {
      setOrgError(null);
      setOrgLoading(false);
      setMemberships([]);
      setOrganizations([]);
      setActiveOrganizationId(null);
      return;
    }

    // Ejecutar carga
    void loadOrganizations(userId, sessionEmail);
  }, [authLoading, authError, userId, sessionEmail, loadOrganizations]);

  const activeOrganization = organizations.find((org) => org.id === activeOrganizationId) || null;
  const activeMembership = memberships.find((m) => m.organization_id === activeOrganizationId) || null;
  const role = activeMembership?.role || null;

  const loading = authLoading || orgLoading;
  const error = authError || orgError;
  const hasOrganizations = organizations.length > 0;

  const refresh = useCallback(async () => {
    if (!userId) return;
    await loadOrganizations(userId, sessionEmail);
  }, [loadOrganizations, userId, sessionEmail]);

  return (
    <OrganizationContext.Provider
      value={{
        memberships,
        organizations,
        activeOrganizationId,
        activeOrganization,
        activeMembership,
        role,
        loading,
        error,
        hasOrganizations,
        setActiveOrganizationId,
        refresh,
      }}
    >
      {children}
    </OrganizationContext.Provider>
  );
}

export function useOrganizationContext(): OrganizationContextValue {
  const context = useContext(OrganizationContext);
  if (context === undefined) {
    throw new Error('useOrganizationContext must be used within an OrganizationProvider');
  }
  return context;
}
