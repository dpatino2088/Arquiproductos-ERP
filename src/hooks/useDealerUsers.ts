import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

/**
 * Dealer portal user shape (antes CompanyPortalUser)
 */
export interface DealerUser {
  id: string;
  dealer_id: string;
  dealer_name?: string | null;
  user_id?: string | null;
  portal_user_email: string;
  portal_user_name?: string | null;
  portal_user_role?: 'dealer_manager' | 'dealer_member' | null;
  portal_user_status: 'draft' | 'invited' | 'active' | 'disabled';
  organization_id?: string | null;
  invited_at?: string | null;
  accepted_at?: string | null;
  deleted: boolean;
  created_at?: string;
  updated_at?: string;
  role?: string | null;
  status?: string | null;
  contact_email?: string | null;
  contact_phone?: string | null;
  user_email?: string | null;
  user_name?: string | null;
  contact_id?: string | null;
  contact_name?: string | null;
  legacy?: { email?: string; status?: string };
}

export type UseDealerUsersOptions = {
  /** When true, do not fetch until dealerId is set. Use on dealer profile edit so dealers never see other dealers' users. */
  onlyWhenDealerId?: boolean;
};

/**
 * Hook para gestionar DealerUsers (antes CompanyPortalUsers)
 * Filtra por organization vía Dealers y opcionalmente por dealer_id.
 */
export function useDealerUsers(dealerId?: string | null, options?: UseDealerUsersOptions) {
  const { onlyWhenDealerId = false } = options || {};
  const [users, setUsers] = useState<DealerUser[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  const normalizeStatus = useCallback((status: any): 'active' | 'disabled' => {
    const s = (status || '').toString().toLowerCase().trim();
    if (s === 'active' || s === 'disabled') return s;
    return 'active';
  }, []);

  const safeSelectPortalUsers = useCallback(async (orgId: string, filterDealerId?: string | null) => {
    const explicitAndGeneric = 'id, dealer_id, user_id, portal_user_email, portal_user_name, role, status, organization_id, invited_at, accepted_at, deleted, created_at, updated_at';

    try {
      const { data, error: queryError } = await supabase
        .from('DealerUsers')
        .select(`
          ${explicitAndGeneric},
          Dealers!DealerUsers_dealer_id_fkey (
            id,
            organization_id,
            dealer_name
          )
        `)
        .eq('Dealers.organization_id', orgId)
        .eq('deleted', false)
        .order('created_at', { ascending: false });

      if (queryError) {
        if (queryError.code === '42703' || queryError.message?.includes('does not exist') || queryError.message?.includes('column') || queryError.message?.includes('join')) {
          const { data: orgDealers } = await supabase
            .from('Dealers')
            .select('id, dealer_name')
            .eq('organization_id', orgId)
            .eq('deleted', false);

          let dealerIds = (orgDealers || []).map((d: { id: string }) => d.id);
          const dealerNameMap = new Map((orgDealers || []).map((d: { id: string; dealer_name?: string }) => [d.id, d.dealer_name]));

          if (filterDealerId) {
            if (!dealerIds.includes(filterDealerId)) return [];
            dealerIds = [filterDealerId];
          }

          if (dealerIds.length === 0) return [];

          const explicitOnly = 'id, dealer_id, user_id, portal_user_email, portal_user_name, role, status, organization_id, invited_at, accepted_at, deleted, created_at, updated_at';
          const { data: retryData, error: retryError } = await supabase
            .from('DealerUsers')
            .select(explicitOnly)
            .in('dealer_id', dealerIds)
            .eq('deleted', false)
            .order('created_at', { ascending: false });

          if (retryError) throw retryError;

          return (retryData || []).map((row: any) => ({
            ...row,
            Dealers: {
              organization_id: orgId,
              dealer_name: dealerNameMap.get(row.dealer_id) || null,
            },
          }));
        }
        throw queryError;
      }

      let filteredData = data || [];
      if (filterDealerId) {
        filteredData = filteredData.filter((row: any) => row.dealer_id === filterDealerId);
      }
      return filteredData;
    } catch (err) {
      throw err;
    }
  }, []);

  const mapToPortalUser = useCallback((row: any): DealerUser => {
    const portal_user_email = (row.portal_user_email ?? row.email ?? '').toString().trim();
    const portal_user_status = normalizeStatus(row.portal_user_status ?? row.status ?? 'draft');

    return {
      id: row.id,
      dealer_id: row.dealer_id,
      dealer_name: row.Dealers?.dealer_name || null,
      user_id: row.user_id || null,
      portal_user_email,
      portal_user_name: row.portal_user_name || null,
      portal_user_role: (() => {
        const rawRole = String(row.role ?? row.portal_user_role ?? '').toLowerCase().trim();
        return rawRole === 'dealer_manager' ? ('dealer_manager' as const) : ('dealer_member' as const);
      })(),
      portal_user_status,
      organization_id: row.organization_id || (row.Dealers?.organization_id || null),
      invited_at: row.invited_at || null,
      accepted_at: row.accepted_at || null,
      deleted: row.deleted || false,
      created_at: row.created_at || undefined,
      updated_at: row.updated_at || undefined,
      legacy: (row.email || row.status) ? { email: row.email || undefined, status: row.status || undefined } : undefined,
    };
  }, [normalizeStatus]);

  const fetchUsers = useCallback(async () => {
    if (!activeOrganizationId) {
      setUsers([]);
      setIsLoading(false);
      setError(null);
      return;
    }

    if (onlyWhenDealerId && (dealerId == null || dealerId === '')) {
      setUsers([]);
      setIsLoading(true);
      setError(null);
      return;
    }

    try {
      setIsLoading(true);
      setError(null);
      const data = await safeSelectPortalUsers(activeOrganizationId, dealerId);
      const mapped = data.map(mapToPortalUser);
      setUsers(mapped);
    } catch (err: any) {
      const errorMessage = err?.message || 'Error loading portal users';
      console.error('[useDealerUsers] Error:', errorMessage, err);
      setError(errorMessage);
      setUsers([]);
    } finally {
      setIsLoading(false);
    }
  }, [activeOrganizationId, dealerId, onlyWhenDealerId, safeSelectPortalUsers, mapToPortalUser]);

  const refetch = useCallback(() => fetchUsers(), [fetchUsers]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  return {
    users,
    isLoading,
    error,
    fetchUsers,
    refetch,
  };
}
