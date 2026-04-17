/**
 * Hook to list AppUsers for a dealer (user_type='dealer', dealer_id=dealerId).
 * Use this in Dealer Profile / Dealer Detail instead of useDealerUsers (DealerUsers legacy).
 * Source of truth: AppUsers.role_code (dealer_manager | dealer_member).
 */

import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';

export type DealerAppUserStatus = 'invited' | 'active' | 'disabled';

export interface DealerAppUser {
  id: string;
  organization_id: string;
  dealer_id: string;
  auth_user_id: string | null;
  email: string;
  display_name: string | null;
  /** AppUserRoles.code: dealer_manager | dealer_member */
  role_code: string;
  status: DealerAppUserStatus;
  deleted: boolean;
  created_at: string;
  updated_at: string;
  /** Data source to help UI explain legacy rows. */
  source?: 'app' | 'legacy';
}

export type UseAppUsersByDealerOptions = {
  /** When true, do not fetch until dealerId is set. */
  onlyWhenDealerId?: boolean;
};

/**
 * Fetches AppUsers for a given dealer (user_type='dealer', dealer_id=dealerId).
 * Excludes soft-deleted (deleted=true).
 */
export function useAppUsersByDealer(
  dealerId: string | null | undefined,
  options?: UseAppUsersByDealerOptions
) {
  const { onlyWhenDealerId = true } = options ?? {};
  const [users, setUsers] = useState<DealerAppUser[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchUsers = useCallback(async () => {
    if (!dealerId || dealerId === '') {
      if (onlyWhenDealerId) {
        setUsers([]);
        setIsLoading(false);
        setError(null);
        return;
      }
    }

    try {
      setIsLoading(true);
      setError(null);

      const { data, error: queryError } = await supabase
        .from('AppUsers')
        .select('id, organization_id, dealer_id, auth_user_id, email, display_name, role_code, status, deleted, created_at, updated_at')
        .eq('user_type', 'dealer')
        .eq('dealer_id', dealerId!)
        .eq('deleted', false)
        .order('created_at', { ascending: false });

      if (queryError) throw queryError;
      const appRows: DealerAppUser[] = (data ?? []).map((row: any) => ({
        id: row.id,
        organization_id: row.organization_id,
        dealer_id: row.dealer_id,
        auth_user_id: row.auth_user_id ?? null,
        email: (row.email ?? '').toString().trim(),
        display_name: row.display_name ?? null,
        role_code: (row.role_code ?? 'dealer_member').toString().trim(),
        status: (row.status ?? 'invited').toString().trim() as DealerAppUserStatus,
        deleted: row.deleted ?? false,
        created_at: row.created_at ?? '',
        updated_at: row.updated_at ?? '',
        source: 'app',
      }));

      // Legacy fallback: show DealerUsers rows not yet synced into AppUsers.
      const { data: legacyRows, error: legacyError } = await supabase
        .from('DealerUsers')
        .select('id, organization_id, dealer_id, user_id, portal_user_email, portal_user_name, role, status, deleted, created_at, updated_at')
        .eq('dealer_id', dealerId!)
        .eq('deleted', false)
        .order('created_at', { ascending: false });
      if (legacyError) throw legacyError;

      const authIdsInApp = new Set(appRows.map((u) => u.auth_user_id).filter(Boolean));
      const emailsInApp = new Set(appRows.map((u) => u.email.toLowerCase()).filter(Boolean));
      const normalizeLegacyRole = (role: string | null | undefined): string => {
        const s = (role ?? '').toString().trim().toLowerCase();
        return s === 'dealer_manager' ? 'dealer_manager' : 'dealer_member';
      };
      const normalizeLegacyStatus = (status: string | null | undefined): DealerAppUserStatus => {
        const s = (status ?? '').toString().trim().toLowerCase();
        if (s === 'disabled') return 'disabled';
        if (s === 'active' || s === 'authorized') return 'active';
        return 'invited';
      };

      const legacyOnlyRows: DealerAppUser[] = (legacyRows ?? [])
        .filter((row: any) => {
          const authId = row.user_id ?? null;
          const email = (row.portal_user_email ?? '').toString().trim().toLowerCase();
          if (authId && authIdsInApp.has(authId)) return false;
          if (email && emailsInApp.has(email)) return false;
          return true;
        })
        .map((row: any) => ({
          id: `legacy:${row.id}`,
          organization_id: row.organization_id,
          dealer_id: row.dealer_id,
          auth_user_id: row.user_id ?? null,
          email: (row.portal_user_email ?? '').toString().trim(),
          display_name: row.portal_user_name ?? null,
          role_code: normalizeLegacyRole(row.role),
          status: normalizeLegacyStatus(row.status),
          deleted: row.deleted ?? false,
          created_at: row.created_at ?? '',
          updated_at: row.updated_at ?? '',
          source: 'legacy',
        }));

      const merged = [...appRows, ...legacyOnlyRows].sort((a, b) => {
        const ta = a.created_at ? new Date(a.created_at).getTime() : 0;
        const tb = b.created_at ? new Date(b.created_at).getTime() : 0;
        return tb - ta;
      });
      setUsers(merged);
    } catch (err: any) {
      const msg = err?.message ?? 'Error loading dealer users';
      console.error('[useAppUsersByDealer]', msg, err);
      setError(msg);
      setUsers([]);
    } finally {
      setIsLoading(false);
    }
  }, [dealerId, onlyWhenDealerId]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  const refetch = useCallback(() => fetchUsers(), [fetchUsers]);

  return {
    users,
    isLoading,
    error,
    refetch,
    fetchUsers,
  };
}

/** Map AppUser.role_code to portal display role (for UI labels). */
export function roleCodeToPortalLabel(roleCode: string): string {
  const s = (roleCode ?? '').toString().trim().toLowerCase();
  return s === 'dealer_manager' ? 'Manager' : 'Member';
}

/** Map CompanyPortalRole (dealer_member | dealer_manager) to AppUsers/DealerUsers.role_code. */
export function portalRoleToRoleCode(role: 'dealer_member' | 'dealer_manager'): string {
  return role;
}

/** Map AppUsers/DealerUsers.role_code to CompanyPortalRole. */
export function roleCodeToPortalRole(roleCode: string): 'dealer_member' | 'dealer_manager' {
  const s = (roleCode ?? '').toString().trim().toLowerCase();
  return s === 'dealer_manager' ? 'dealer_manager' : 'dealer_member';
}

/** DealerAppUser with dealer_name (for list views across all dealers in org). */
export type DealerAppUserWithDealer = DealerAppUser & { dealer_name: string | null };

/**
 * Fetches all dealer-type AppUsers for an organization (all dealers).
 * Use in Settings > Dealer Users list (not per-dealer profile).
 */
export function useDealerAppUsersForOrg(organizationId: string | null | undefined) {
  const [users, setUsers] = useState<DealerAppUserWithDealer[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchUsers = useCallback(async () => {
    if (!organizationId || organizationId === '') {
      setUsers([]);
      setIsLoading(false);
      setError(null);
      return;
    }

    try {
      setIsLoading(true);
      setError(null);

      const { data: appUsers, error: auError } = await supabase
        .from('AppUsers')
        .select('id, organization_id, dealer_id, auth_user_id, email, display_name, role_code, status, deleted, created_at, updated_at')
        .eq('organization_id', organizationId)
        .eq('user_type', 'dealer')
        .eq('deleted', false)
        .order('created_at', { ascending: false });

      if (auError) throw auError;

      const list = appUsers ?? [];
      const dealerIds = [...new Set(list.map((r: any) => r.dealer_id).filter(Boolean))] as string[];

      let dealerNameMap = new Map<string, string>();
      if (dealerIds.length > 0) {
        const { data: dealers } = await supabase
          .from('Dealers')
          .select('id, dealer_name')
          .in('id', dealerIds)
          .eq('deleted', false);
        dealerNameMap = new Map((dealers ?? []).map((d: any) => [d.id, d.dealer_name ?? '']));
      }

      setUsers(list.map((row: any) => ({
        id: row.id,
        organization_id: row.organization_id,
        dealer_id: row.dealer_id,
        auth_user_id: row.auth_user_id ?? null,
        email: (row.email ?? '').toString().trim(),
        display_name: row.display_name ?? null,
        role_code: (row.role_code ?? 'dealer_member').toString().trim(),
        status: (row.status ?? 'invited').toString().trim() as DealerAppUserStatus,
        deleted: row.deleted ?? false,
        created_at: row.created_at ?? '',
        updated_at: row.updated_at ?? '',
        dealer_name: row.dealer_id ? (dealerNameMap.get(row.dealer_id) ?? null) : null,
      })));
    } catch (err: any) {
      const msg = err?.message ?? 'Error loading dealer users';
      console.error('[useDealerAppUsersForOrg]', msg, err);
      setError(msg);
      setUsers([]);
    } finally {
      setIsLoading(false);
    }
  }, [organizationId]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  const refetch = useCallback(() => fetchUsers(), [fetchUsers]);

  return {
    users,
    isLoading,
    error,
    refetch,
    fetchUsers,
  };
}
