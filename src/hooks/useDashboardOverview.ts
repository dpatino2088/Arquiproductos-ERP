import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useAccessContext } from './useAccessContext';
import { useDealerScope } from './useDealerScope';
import { buildDirectoryScopeKey } from '../lib/directoryScopeKey';
import { commercialDashboardOverviewKey } from '../lib/queryKeys';
import { keepPreviousData } from '../lib/query-client';
import { getSupabaseErrorMessageDetailed } from '../lib/supabase-error-utils';

type CountDelta = {
  current: number;
  previous: number;
  delta: number;
};

type AmountDelta = {
  current: number;
  previous: number;
  deltaPct: number | null;
};

export interface DashboardActivityItem {
  id: string;
  entity: 'quote' | 'proposal' | 'order';
  number: string;
  status: string;
  amount: number;
  created_at: string;
}

export interface DashboardOverviewData {
  salesTotal: AmountDelta;
  activeOrders: CountDelta;
  proposalsSent: CountDelta;
  proposalsAccepted: CountDelta;
  pipeline: {
    quotesDraft: number;
    quotesApproved: number;
    proposalsSent: number;
    proposalsAccepted: number;
    activeOrders: number;
  };
  orderStatusMix: Array<{ status: string; count: number; pct: number }>;
  recentOrders: Array<{ id: string; number: string; status: string; amount: number; created_at: string; dealerName?: string | null }>;
  recentActivity: DashboardActivityItem[];
  scopeMode: 'organization' | 'dealer';
}

type QuoteRow = {
  id: string;
  dealer_id: string | null;
  quote_no: string | null;
  status: string | null;
  total_amount: number | null;
  created_at: string;
};

type ProposalRow = {
  id: string;
  proposal_no: string | null;
  status: string | null;
  total_amount: number | null;
  created_at: string;
};

type OrderRow = {
  id: string;
  sales_order_no: string | null;
  status: string | null;
  total_amount: number | null;
  created_at: string;
};

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;
const TERMINAL_ORDER_STATUSES = new Set(['delivered', 'closed', 'cancelled', 'canceled', 'completed']);

function asNumber(value: unknown): number {
  const n = Number(value ?? 0);
  return Number.isFinite(n) ? n : 0;
}

function inWindow(iso: string | null | undefined, startMs: number, endMs: number): boolean {
  if (!iso) return false;
  const t = new Date(iso).getTime();
  return Number.isFinite(t) && t >= startMs && t < endMs;
}

function normalizeStatus(value: string | null | undefined): string {
  return (value ?? 'unknown').toString().trim().toLowerCase();
}

function isCancelledOrder(status: string | null | undefined): boolean {
  const value = normalizeStatus(status);
  return value === 'cancelled' || value === 'canceled';
}

export function useDashboardOverview() {
  const { activeOrganizationId } = useOrganizationContext();
  const { userType, portalDealerId } = useAccessContext();
  const { effectiveDealerId, hasHydrated } = useDealerScope();

  const scopedDealerId = userType === 'portal' ? (portalDealerId ?? null) : (effectiveDealerId ?? null);
  const scopeKey = buildDirectoryScopeKey({
    orgId: activeOrganizationId ?? null,
    activeDealerId: scopedDealerId,
    userRole: userType,
  });
  const isScopeReady = userType === 'internal' ? hasHydrated : true;

  const query = useQuery({
    queryKey: commercialDashboardOverviewKey(scopeKey),
    enabled: !!activeOrganizationId && isScopeReady,
    placeholderData: keepPreviousData,
    refetchOnWindowFocus: false,
    queryFn: async (): Promise<DashboardOverviewData> => {
      const orgId = activeOrganizationId!;
      const scopeMode: 'organization' | 'dealer' = scopedDealerId ? 'dealer' : 'organization';

      let quoteIdsForScope: string[] = [];
      if (scopedDealerId) {
        const { data: scopedQuotes, error: scopedQuotesErr } = await supabase
          .from('Quotes')
          .select('id')
          .eq('organization_id', orgId)
          .eq('dealer_id', scopedDealerId)
          .or('deleted.is.false,deleted.is.null');
        if (scopedQuotesErr) throw scopedQuotesErr;
        quoteIdsForScope = (scopedQuotes ?? []).map((q: { id: string }) => q.id);
        if (quoteIdsForScope.length === 0) {
          return {
            salesTotal: { current: 0, previous: 0, deltaPct: 0 },
            activeOrders: { current: 0, previous: 0, delta: 0 },
            proposalsSent: { current: 0, previous: 0, delta: 0 },
            proposalsAccepted: { current: 0, previous: 0, delta: 0 },
            pipeline: { quotesDraft: 0, quotesApproved: 0, proposalsSent: 0, proposalsAccepted: 0, activeOrders: 0 },
            orderStatusMix: [],
            recentOrders: [],
            recentActivity: [],
            scopeMode,
          };
        }
      }

      let quotesQuery = supabase
        .from('Quotes')
        .select('id, dealer_id, quote_no, status, total_amount, created_at')
        .eq('organization_id', orgId)
        .or('deleted.is.false,deleted.is.null');
      if (scopedDealerId) quotesQuery = quotesQuery.eq('dealer_id', scopedDealerId);

      let proposalsQuery = supabase
        .from('Proposals')
        .select('id, proposal_no, status, total_amount, created_at')
        .eq('organization_id', orgId)
        .or('deleted.is.false,deleted.is.null');
      if (scopedDealerId) proposalsQuery = proposalsQuery.eq('dealer_id', scopedDealerId);

      let ordersQuery = supabase
        .from('SalesOrders')
        .select('id, sales_order_no, status, total_amount, created_at, quote_id')
        .eq('organization_id', orgId)
        .eq('deleted', false);
      if (scopedDealerId) ordersQuery = ordersQuery.in('quote_id', quoteIdsForScope);

      const [{ data: quotesData, error: quotesErr }, { data: proposalsData, error: proposalsErr }, { data: ordersData, error: ordersErr }] = await Promise.all([
        quotesQuery,
        proposalsQuery,
        ordersQuery,
      ]);
      if (quotesErr) throw quotesErr;
      if (proposalsErr) throw proposalsErr;
      if (ordersErr) throw ordersErr;

      const quotes = (quotesData ?? []) as QuoteRow[];
      const proposals = (proposalsData ?? []) as ProposalRow[];
      const orders = (ordersData ?? []) as Array<OrderRow & { quote_id: string | null }>;
      const quoteDealerByQuoteId = new Map<string, string | null>(quotes.map((q) => [q.id, q.dealer_id ?? null]));
      const dealerNameById = new Map<string, string>();

      if (!scopedDealerId) {
        const dealerIds = [...new Set(quotes.map((q) => q.dealer_id).filter((id): id is string => !!id))];
        if (dealerIds.length > 0) {
          const { data: dealersData, error: dealersErr } = await supabase
            .from('Dealers')
            .select('id, dealer_name')
            .eq('organization_id', orgId)
            .in('id', dealerIds)
            .eq('deleted', false);
          if (dealersErr) throw dealersErr;
          (dealersData ?? []).forEach((d: { id: string; dealer_name: string | null }) => {
            dealerNameById.set(d.id, d.dealer_name ?? 'Unknown dealer');
          });
        }
      }

      const nowMs = Date.now();
      const currentStartMs = nowMs - THIRTY_DAYS_MS;
      const previousStartMs = nowMs - (2 * THIRTY_DAYS_MS);

      const salesCurrent = orders
        .filter((row) => !isCancelledOrder(row.status))
        .filter((row) => inWindow(row.created_at, currentStartMs, nowMs))
        .reduce((sum, row) => sum + asNumber(row.total_amount), 0);
      const salesPrevious = orders
        .filter((row) => !isCancelledOrder(row.status))
        .filter((row) => inWindow(row.created_at, previousStartMs, currentStartMs))
        .reduce((sum, row) => sum + asNumber(row.total_amount), 0);
      const salesDeltaPct = salesPrevious > 0
        ? ((salesCurrent - salesPrevious) / salesPrevious) * 100
        : (salesCurrent > 0 ? 100 : 0);

      const activeOrdersNow = orders.filter((row) => !TERMINAL_ORDER_STATUSES.has(normalizeStatus(row.status))).length;
      const activeOrdersPrev = orders
        .filter((row) => !TERMINAL_ORDER_STATUSES.has(normalizeStatus(row.status)))
        .filter((row) => inWindow(row.created_at, previousStartMs, currentStartMs))
        .length;

      const proposalsSentCurrent = proposals
        .filter((row) => normalizeStatus(row.status) === 'sent')
        .filter((row) => inWindow(row.created_at, currentStartMs, nowMs))
        .length;
      const proposalsSentPrevious = proposals
        .filter((row) => normalizeStatus(row.status) === 'sent')
        .filter((row) => inWindow(row.created_at, previousStartMs, currentStartMs))
        .length;

      const proposalsAcceptedCurrent = proposals
        .filter((row) => normalizeStatus(row.status) === 'accepted')
        .filter((row) => inWindow(row.created_at, currentStartMs, nowMs))
        .length;
      const proposalsAcceptedPrevious = proposals
        .filter((row) => normalizeStatus(row.status) === 'accepted')
        .filter((row) => inWindow(row.created_at, previousStartMs, currentStartMs))
        .length;

      const statusBuckets = new Map<string, number>();
      orders.forEach((row) => {
        const key = normalizeStatus(row.status);
        statusBuckets.set(key, (statusBuckets.get(key) ?? 0) + 1);
      });
      const totalOrders = Math.max(orders.length, 1);
      const orderStatusMix = [...statusBuckets.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .map(([status, count]) => ({
          status: status.replace(/_/g, ' '),
          count,
          pct: Math.round((count / totalOrders) * 100),
        }));

      const recentActivity: DashboardActivityItem[] = [
        ...orders.map((row) => ({
          id: `order-${row.id}`,
          entity: 'order' as const,
          number: row.sales_order_no ?? `SO-${row.id.slice(0, 8)}`,
          status: normalizeStatus(row.status),
          amount: asNumber(row.total_amount),
          created_at: row.created_at,
        })),
        ...proposals.map((row) => ({
          id: `proposal-${row.id}`,
          entity: 'proposal' as const,
          number: row.proposal_no ?? `PR-${row.id.slice(0, 8)}`,
          status: normalizeStatus(row.status),
          amount: asNumber(row.total_amount),
          created_at: row.created_at,
        })),
        ...quotes.map((row) => ({
          id: `quote-${row.id}`,
          entity: 'quote' as const,
          number: row.quote_no ?? `QT-${row.id.slice(0, 8)}`,
          status: normalizeStatus(row.status),
          amount: asNumber(row.total_amount),
          created_at: row.created_at,
        })),
      ]
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
        .slice(0, 8);

      const recentOrders = orders
        .map((row) => ({
          id: row.id,
          number: row.sales_order_no ?? `SO-${row.id.slice(0, 8)}`,
          status: normalizeStatus(row.status),
          amount: asNumber(row.total_amount),
          created_at: row.created_at,
          dealerName: (() => {
            if (scopedDealerId) return null;
            const quoteDealerId = row.quote_id ? (quoteDealerByQuoteId.get(row.quote_id) ?? null) : null;
            return quoteDealerId ? (dealerNameById.get(quoteDealerId) ?? null) : null;
          })(),
        }))
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
        .slice(0, 10);

      return {
        salesTotal: {
          current: salesCurrent,
          previous: salesPrevious,
          deltaPct: Number.isFinite(salesDeltaPct) ? salesDeltaPct : null,
        },
        activeOrders: {
          current: activeOrdersNow,
          previous: activeOrdersPrev,
          delta: activeOrdersNow - activeOrdersPrev,
        },
        proposalsSent: {
          current: proposalsSentCurrent,
          previous: proposalsSentPrevious,
          delta: proposalsSentCurrent - proposalsSentPrevious,
        },
        proposalsAccepted: {
          current: proposalsAcceptedCurrent,
          previous: proposalsAcceptedPrevious,
          delta: proposalsAcceptedCurrent - proposalsAcceptedPrevious,
        },
        pipeline: {
          quotesDraft: quotes.filter((row) => normalizeStatus(row.status) === 'draft').length,
          quotesApproved: quotes.filter((row) => normalizeStatus(row.status) === 'approved').length,
          proposalsSent: proposals.filter((row) => normalizeStatus(row.status) === 'sent').length,
          proposalsAccepted: proposals.filter((row) => normalizeStatus(row.status) === 'accepted').length,
          activeOrders: activeOrdersNow,
        },
        orderStatusMix,
        recentOrders,
        recentActivity,
        scopeMode,
      };
    },
  });

  const data = useMemo<DashboardOverviewData>(() => {
    return query.data ?? {
      salesTotal: { current: 0, previous: 0, deltaPct: 0 },
      activeOrders: { current: 0, previous: 0, delta: 0 },
      proposalsSent: { current: 0, previous: 0, delta: 0 },
      proposalsAccepted: { current: 0, previous: 0, delta: 0 },
      pipeline: { quotesDraft: 0, quotesApproved: 0, proposalsSent: 0, proposalsAccepted: 0, activeOrders: 0 },
      orderStatusMix: [],
      recentOrders: [],
      recentActivity: [],
      scopeMode: scopedDealerId ? 'dealer' : 'organization',
    };
  }, [query.data, scopedDealerId]);

  return {
    data,
    isScopeReady,
    isInitialLoading: query.isLoading && !query.data,
    isRefreshing: query.isFetching && !!query.data,
    error: query.error ? getSupabaseErrorMessageDetailed(query.error) : null,
    refetch: query.refetch,
  };
}
