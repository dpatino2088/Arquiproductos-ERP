import { useQuery } from '@tanstack/react-query';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useAccessContext } from './useAccessContext';
import { useActiveDealer } from './useActiveDealer';
import { buildDirectoryScopeKey } from '../lib/directoryScopeKey';
import { dealerFinancialTimelineKey } from '../lib/queryKeys';
import { supabase } from '../lib/supabase/client';
import { getSupabaseErrorMessageDetailed } from '../lib/supabase-error-utils';

const STALE_TIME_MS = 30_000;
const GC_TIME_MS = 10 * 60_000;

export interface DealerFinancialTimelineEvent {
  organization_id: string;
  dealer_id: string;
  entity_id: string;
  entity_type: string;
  event_type: string;
  event_at: string;
  reference_no: string | null;
  amount: number;
}

export function useDealerFinancialTimeline(dealerId: string | null, limit = 100, enabled = true) {
  const { activeOrganizationId } = useOrganizationContext();
  const { userType } = useAccessContext();
  const { activeDealerId, hasHydrated } = useActiveDealer();

  const orgId = activeOrganizationId ?? null;
  const isScopeReady = userType === 'internal' ? hasHydrated : true;
  const scopeKey = buildDirectoryScopeKey({
    orgId,
    activeDealerId: activeDealerId ?? null,
    userRole: userType,
  });

  const query = useQuery({
    queryKey: dealerFinancialTimelineKey(scopeKey, dealerId ?? ''),
    enabled: enabled && !!orgId && !!dealerId && isScopeReady,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    refetchOnWindowFocus: false,
    queryFn: async (): Promise<DealerFinancialTimelineEvent[]> => {
      const { data, error } = await supabase
        .from('dealer_financial_timeline_v1')
        .select('organization_id, dealer_id, entity_id, entity_type, event_type, event_at, reference_no, amount')
        .eq('organization_id', orgId!)
        .eq('dealer_id', dealerId!)
        .order('event_at', { ascending: false })
        .limit(limit);
      if (error) throw error;
      return ((data ?? []) as Array<Record<string, unknown>>).map((row) => ({
        organization_id: String(row.organization_id ?? ''),
        dealer_id: String(row.dealer_id ?? ''),
        entity_id: String(row.entity_id ?? ''),
        entity_type: String(row.entity_type ?? ''),
        event_type: String(row.event_type ?? ''),
        event_at: String(row.event_at ?? ''),
        reference_no: row.reference_no ? String(row.reference_no) : null,
        amount: Number(row.amount ?? 0),
      }));
    },
  });

  return {
    scopeKey,
    isScopeReady,
    events: query.data ?? [],
    isInitialLoading: query.isLoading && !query.data,
    isFetching: query.isFetching,
    isRefreshing: query.isFetching && !!query.data,
    error: query.error ? getSupabaseErrorMessageDetailed(query.error) : null,
    refetch: query.refetch,
  };
}
