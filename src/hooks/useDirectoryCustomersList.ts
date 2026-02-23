import { useQuery } from '@tanstack/react-query';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useActiveDealer } from './useActiveDealer';
import { useAccessContext } from './useAccessContext';
import { buildDirectoryScopeKey } from '../lib/directoryScopeKey';
import { directoryCustomersListKey } from '../lib/queryKeys';
import { fetchDirectoryCustomers } from '../lib/directoryListFetchers';
import { supabase } from '../lib/supabase/client';
import { keepPreviousData } from '../lib/query-client';

const STALE_TIME_MS = 60_000;
const GC_TIME_MS = 10 * 60_000;

export interface UseDirectoryCustomersListParams {
  organizationId?: string | null;
  enabled?: boolean;
}

/**
 * React Query list hook for Directory Customers.
 * - Stable scopeKey (org:dealer:role) to avoid unnecessary refetches.
 * - placeholderData keeps previous data while refetching (no flash).
 * - Use in Customers tab; prefetch from Directory for the other tab.
 */
export function useDirectoryCustomersList(params?: UseDirectoryCustomersListParams) {
  const { activeOrganizationId: contextOrgId } = useOrganizationContext();
  const { activeDealerId, hasHydrated } = useActiveDealer();
  const { userType } = useAccessContext();

  const orgId = params?.organizationId ?? contextOrgId ?? null;
  const enabled = (params?.enabled ?? true) && !!orgId && (userType !== 'internal' || hasHydrated);

  const scopeKey = buildDirectoryScopeKey({
    orgId,
    activeDealerId: activeDealerId ?? null,
    userRole: userType,
  });

  const query = useQuery({
    queryKey: directoryCustomersListKey(scopeKey),
    queryFn: () =>
      fetchDirectoryCustomers(supabase, {
        orgId: orgId!,
        userType,
        activeDealerId: activeDealerId ?? null,
      }),
    enabled,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    refetchOnWindowFocus: false,
    retry: 1,
    placeholderData: keepPreviousData,
  });

  const customers = query.data ?? [];
  const isFirstLoad = query.isLoading && !query.data;
  const isRefreshing = query.isFetching && !!query.data;
  const isScopeReady = userType === 'internal' ? hasHydrated : true;

  return {
    customers,
    scopeKey,
    isScopeReady,
    isPending: query.isLoading,
    isInitialLoading: isFirstLoad,
    isFetching: query.isFetching,
    isRefreshing,
    hasData: customers.length > 0,
    error: query.error ? String(query.error) : null,
    refetch: query.refetch,
    isPlaceholderData: query.isPlaceholderData,
    data: query.data,
  };
}
