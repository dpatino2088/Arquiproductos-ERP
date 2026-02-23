import { useQuery } from '@tanstack/react-query';
import { catalogItemDetailKey } from '../lib/queryKeys';
import { fetchCatalogItemDetail } from '../lib/catalogListFetchers';
import { supabase } from '../lib/supabase/client';
import type { CatalogItem } from '../types/catalog';

const STALE_TIME_MS = 60_000;

export interface UseCatalogItemDetailParams {
  /** Seed from list cache for instant open; then query refines with full detail. */
  initialData?: CatalogItem | undefined;
}

/**
 * Detail query for one catalog item. Uses DETAIL_QUERY_VERSION.
 * - enabled: isScopeReady && !!itemId (never undefined in key: use '' if null).
 * - Pass initialData from list cache when opening from list for zero-flash open.
 */
export function useCatalogItemDetail(
  scopeKey: string,
  itemId: string | null,
  params?: UseCatalogItemDetailParams & { orgId: string | null }
) {
  const isScopeReady = !!scopeKey && !!params?.orgId;
  const enabled = isScopeReady && !!itemId;

  return useQuery({
    queryKey: catalogItemDetailKey(scopeKey, itemId ?? ''),
    queryFn: () =>
      fetchCatalogItemDetail(supabase, {
        orgId: params!.orgId!,
        itemId: itemId!,
      }),
    enabled,
    initialData: params?.initialData,
    staleTime: STALE_TIME_MS,
    refetchOnWindowFocus: false,
  });
}
