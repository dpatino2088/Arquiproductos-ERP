import { useQuery } from '@tanstack/react-query';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useActiveDealer } from './useActiveDealer';
import { useAccessContext } from './useAccessContext';
import { buildDirectoryScopeKey } from '../lib/directoryScopeKey';
import { directoryContactsListKey } from '../lib/queryKeys';
import { fetchDirectoryContacts } from '../lib/directoryListFetchers';
import { supabase } from '../lib/supabase/client';
import { keepPreviousData } from '../lib/query-client';

const STALE_TIME_MS = 60_000;
const GC_TIME_MS = 10 * 60_000;

export interface UseDirectoryContactsListParams {
  organizationId?: string | null;
  enabled?: boolean;
}

/**
 * React Query list hook for Directory Contacts.
 * - Stable scopeKey (org:dealer:role) to avoid unnecessary refetches.
 * - placeholderData keeps previous data while refetching (no flash).
 * - Use in Contacts tab; prefetch from Directory for the other tab.
 */
export function useDirectoryContactsList(params?: UseDirectoryContactsListParams) {
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

  if (import.meta.env.DEV) {
    console.log('[useDirectoryContactsList] RENDER', { orgId, activeDealerId, scopeKey, enabled, hasHydrated, userType });
  }

  const query = useQuery({
    queryKey: directoryContactsListKey(scopeKey),
    queryFn: () =>
      fetchDirectoryContacts(supabase, {
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

  const contacts = query.data ?? [];
  const isFirstLoad = query.isLoading && !query.data;
  const isRefreshing = query.isFetching && !!query.data;
  const isScopeReady = userType === 'internal' ? hasHydrated : true;

  return {
    contacts,
    scopeKey,
    isScopeReady,
    isPending: query.isLoading,
    isInitialLoading: isFirstLoad,
    isFetching: query.isFetching,
    isRefreshing,
    hasData: contacts.length > 0,
    error: query.error ? String(query.error) : null,
    refetch: query.refetch,
    isPlaceholderData: query.isPlaceholderData,
    data: query.data,
  };
}
