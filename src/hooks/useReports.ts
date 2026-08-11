import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useActiveDealer } from './useActiveDealer';
import { useAccessContext } from './useAccessContext';
import { buildCatalogScopeKey } from '../lib/catalogScopeKey';
import { reportsTabKey } from '../lib/queryKeys';
import { supabase } from '../lib/supabase/client';
import { keepPreviousData } from '../lib/query-client';

const STALE_TIME_MS = 60_000;
const GC_TIME_MS = 10 * 60 * 1000;

export type ReportTab = 'sales' | 'dealers' | 'products' | 'components' | 'purchasing';

const RPC_BY_TAB: Record<ReportTab, string> = {
  sales: 'report_sales_summary',
  dealers: 'report_dealer_ranking',
  products: 'report_product_mix',
  components: 'report_component_consumption',
  purchasing: 'report_purchasing',
};

// ---------------------------------------------------------------------------
// Payload shapes (mirror the jsonb built by the report_* RPCs)
// ---------------------------------------------------------------------------

export interface SalesSummaryReport {
  total_sales: number;
  orders_count: number;
  avg_ticket: number;
  monthly: { month: string; total: number; orders: number }[];
  status_mix: { status: string; count: number }[];
  funnel: {
    quotes_created: number;
    quotes_amount: number;
    proposals_created: number;
    proposals_accepted: number;
    orders_created: number;
    quote_to_order_pct: number;
    avg_cycle_days: number;
  };
}

export interface DealerRankRow {
  dealer_id: string;
  dealer_name: string;
  dealer_no: string | null;
  orders_count: number;
  sales_total: number;
  quotes_count: number;
  conversion_pct: number | null;
  revenue: number;
  cost: number;
  margin_pct: number | null;
}

export type DealerRankingReport = DealerRankRow[];

export interface ProductMixReport {
  by_product_type: {
    product_type: string;
    units: number;
    revenue: number;
    avg_width_m: number | null;
    avg_height_m: number | null;
  }[];
  top_collections: { collection: string; variant: string | null; units: number; revenue: number }[];
}

export interface ComponentConsumptionReport {
  top_components: {
    part_role: string | null;
    sku: string | null;
    name: string | null;
    uom: string | null;
    qty: number;
    cost: number;
    orders_count: number;
  }[];
  by_role: { part_role: string; qty: number; cost: number }[];
  accessories: { sku: string | null; name: string | null; qty: number; orders_count: number }[];
}

export interface PurchasingReport {
  total_spend: number;
  po_count: number;
  monthly: { month: string; total: number; pos: number }[];
  status_mix: { status: string; count: number }[];
  by_vendor: { vendor: string; total: number; pos: number }[];
  top_items: { sku: string; name: string | null; qty: number; unit: string | null; spend: number }[];
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

export interface ReportDateRange {
  /** Inclusive start, 'YYYY-MM-DD' */
  from: string;
  /** Inclusive end, 'YYYY-MM-DD' */
  to: string;
}

/** Previous window of the same length ending the day before `range.from`. */
export function previousRange(range: ReportDateRange): ReportDateRange {
  const from = new Date(`${range.from}T00:00:00`);
  const to = new Date(`${range.to}T00:00:00`);
  const days = Math.max(0, Math.round((to.getTime() - from.getTime()) / 86_400_000));
  const prevTo = new Date(from.getTime() - 86_400_000);
  const prevFrom = new Date(prevTo.getTime() - days * 86_400_000);
  const iso = (d: Date) => d.toISOString().slice(0, 10);
  return { from: iso(prevFrom), to: iso(prevTo) };
}

/**
 * Fetch one aggregated report tab (server-side GROUP BY, one RPC round-trip).
 * With `withPrevious`, the equal-length previous window is fetched in parallel
 * so the tab can render deltas.
 */
export function useReport<T>(
  tab: ReportTab,
  range: ReportDateRange,
  opts?: { withPrevious?: boolean; enabled?: boolean }
) {
  const { activeOrganizationId } = useOrganizationContext();
  const { activeDealerId, hasHydrated } = useActiveDealer();
  const { userType } = useAccessContext();

  const orgId = activeOrganizationId ?? null;
  const isScopeReady = userType === 'internal' ? hasHydrated : true;
  const enabled = (opts?.enabled ?? true) && !!orgId && isScopeReady;
  const withPrevious = opts?.withPrevious ?? false;

  const scopeKey = useMemo(
    () =>
      buildCatalogScopeKey({
        orgId,
        activeDealerId: activeDealerId ?? null,
        userRole: userType,
      }),
    [orgId, activeDealerId, userType]
  );

  const prev = useMemo(() => previousRange(range), [range.from, range.to]);

  const fetchReport = async (win: ReportDateRange): Promise<T> => {
    const { data, error } = await supabase.rpc(RPC_BY_TAB[tab], {
      p_org_id: orgId,
      p_from: win.from,
      p_to: win.to,
    });
    if (error) throw error;
    return data as T;
  };

  const current = useQuery({
    queryKey: reportsTabKey(scopeKey, tab, range.from, range.to),
    queryFn: () => fetchReport(range),
    enabled,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    refetchOnWindowFocus: false,
    retry: 1,
    placeholderData: keepPreviousData,
  });

  const previous = useQuery({
    queryKey: reportsTabKey(scopeKey, tab, prev.from, prev.to),
    queryFn: () => fetchReport(prev),
    enabled: enabled && withPrevious,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    refetchOnWindowFocus: false,
    retry: 1,
    placeholderData: keepPreviousData,
  });

  return {
    data: current.data as T | undefined,
    previousData: withPrevious ? (previous.data as T | undefined) : undefined,
    isInitialLoading: current.isLoading && !current.data,
    isRefreshing: current.isFetching && !!current.data,
    error: current.error ? String(current.error) : null,
    refetch: current.refetch,
  };
}

/** Percentage delta between current and previous values (null when not computable). */
export function deltaPct(current: number | undefined, previous: number | undefined): number | null {
  if (current == null || previous == null || previous === 0) return null;
  return ((current - previous) / Math.abs(previous)) * 100;
}
