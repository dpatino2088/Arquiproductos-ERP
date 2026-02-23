import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useActiveDealer } from './useActiveDealer';
import { useAccessContext } from './useAccessContext';
import { buildCatalogScopeKey } from '../lib/catalogScopeKey';
import { catalogItemsListKey } from '../lib/queryKeys';
import { fetchCatalogItemsList } from '../lib/catalogListFetchers';
import { supabase } from '../lib/supabase/client';
import { keepPreviousData } from '../lib/query-client';
import type { CatalogItem } from '../types/catalog';

const STALE_TIME_MS = 60_000;
const GC_TIME_MS = 10 * 60 * 1000;

export interface CatalogListFiltersStable {
  q?: string;
  categoryId?: string;
  status?: string;
  sortKey?: string;
  page?: number;
  pageSize?: number;
}

export interface UseCatalogItemsListParams {
  organizationId?: string | null;
  enabled?: boolean;
  /** Primitives only; memoize in caller to avoid refetches */
  filters?: CatalogListFiltersStable;
}

/**
 * React Query list hook for Catalog Items (light list: minimal columns + MSRP in one batch).
 * - Stable scopeKey and filtersStable (primitives only) to avoid phantom refetches.
 * - placeholderData keeps previous data while refetching (no flash).
 * - enabled: isScopeReady && (q.length === 0 || q.length >= 2) for search.
 */
export function useCatalogItemsList(params?: UseCatalogItemsListParams) {
  const { activeOrganizationId: contextOrgId } = useOrganizationContext();
  const { activeDealerId, hasHydrated } = useActiveDealer();
  const { userType } = useAccessContext();

  const orgId = params?.organizationId ?? contextOrgId ?? null;
  const filters = params?.filters ?? {};
  const isScopeReady = userType === 'internal' ? hasHydrated : true;

  const scopeKey = useMemo(
    () =>
      buildCatalogScopeKey({
        orgId,
        activeDealerId: activeDealerId ?? null,
        userRole: userType,
      }),
    [orgId, activeDealerId, userType]
  );

  const filtersStable = useMemo(
    () => ({
      q: (filters.q ?? '').trim(),
      categoryId: filters.categoryId ?? '',
      status: filters.status ?? 'all',
      sortKey: filters.sortKey ?? 'sku',
      page: filters.page ?? 1,
      pageSize: filters.pageSize ?? 500,
    }),
    [filters.q, filters.categoryId, filters.status, filters.sortKey, filters.page, filters.pageSize]
  );

  const queryKey = useMemo(
    () => catalogItemsListKey(scopeKey, filtersStable),
    [scopeKey, filtersStable.q, filtersStable.categoryId, filtersStable.status, filtersStable.sortKey, filtersStable.page, filtersStable.pageSize]
  );

  const searchQ = filtersStable.q;
  // When auth/store exposes isHydratingUser, add: && !isHydratingUser to avoid refetch during hydration
  const enabled =
    (params?.enabled ?? true) &&
    !!orgId &&
    isScopeReady &&
    (searchQ.length === 0 || searchQ.length >= 2);

  const query = useQuery({
    queryKey,
    queryFn: () =>
      fetchCatalogItemsList(supabase, {
        orgId: orgId!,
        filters: filtersStable,
      }),
    enabled,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    refetchOnWindowFocus: false,
    retry: 1,
    placeholderData: keepPreviousData,
  });

  const items: CatalogItem[] = query.data ?? [];
  const isFirstLoad = query.isLoading && !query.data;
  const isRefreshing = query.isFetching && !!query.data;

  return {
    items,
    scopeKey,
    filtersStable,
    isScopeReady,
    isPending: query.isLoading,
    isInitialLoading: isFirstLoad,
    isFetching: query.isFetching,
    isRefreshing,
    hasData: items.length > 0,
    error: query.error ? String(query.error) : null,
    refetch: query.refetch,
    isPlaceholderData: query.isPlaceholderData,
    data: query.data,
  };
}
