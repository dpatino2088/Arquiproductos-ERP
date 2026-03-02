import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useAccessContext } from './useAccessContext';
import { useActiveDealer } from './useActiveDealer';
import { buildDirectoryScopeKey } from '../lib/directoryScopeKey';
import { dealerFinancialAccountsListKey } from '../lib/queryKeys';
import { keepPreviousData } from '../lib/query-client';
import { supabase } from '../lib/supabase/client';
import { getSupabaseErrorMessageDetailed } from '../lib/supabase-error-utils';

const STALE_TIME_MS = 60_000;
const GC_TIME_MS = 10 * 60_000;

export type DealerFinancialRisk = 'all' | 'healthy' | 'warning' | 'critical';

export interface DealerFinancialAccountRow {
  dealer_id: string;
  dealer_name: string;
  dealer_no: string | null;
  total_invoiced_lifetime: number;
  total_paid_lifetime: number;
  open_ar: number;
  past_due_amount: number;
  unapplied_amount: number;
  last_payment_date: string | null;
  open_invoices_count: number;
  open_so_count: number;
  aging_current: number;
  aging_1_30: number;
  aging_31_60: number;
  aging_61_90: number;
  aging_90_plus: number;
  risk_band: Exclude<DealerFinancialRisk, 'all'>;
}

export interface UseDealerFinancialAccountsParams {
  q: string;
  risk: DealerFinancialRisk;
  sortKey: string;
  page: number;
  pageSize: number;
  enabled?: boolean;
}

function toNumber(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function resolveRiskBand(params: {
  openAr: number;
  pastDue: number;
  days90Plus: number;
}): Exclude<DealerFinancialRisk, 'all'> {
  const { openAr, pastDue, days90Plus } = params;
  if (days90Plus > 0) return 'critical';
  if (pastDue > 0.005 && openAr > 0.005 && (pastDue / openAr) >= 0.4) return 'critical';
  if (pastDue > 0.005) return 'warning';
  return 'healthy';
}

export function useDealerFinancialAccounts(params: UseDealerFinancialAccountsParams) {
  const { activeOrganizationId } = useOrganizationContext();
  const { userType } = useAccessContext();
  const { activeDealerId, hasHydrated } = useActiveDealer();

  const orgId = activeOrganizationId ?? null;
  const isScopeReady = userType === 'internal' ? hasHydrated : true;
  const enabled = (params.enabled ?? true) && !!orgId && isScopeReady;

  const scopeKey = buildDirectoryScopeKey({
    orgId,
    activeDealerId: activeDealerId ?? null,
    userRole: userType,
  });

  const query = useQuery({
    queryKey: dealerFinancialAccountsListKey(scopeKey, {
      q: params.q.trim().toLowerCase(),
      risk: params.risk,
      sortKey: params.sortKey,
      page: params.page,
      pageSize: params.pageSize,
    }),
    enabled,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    refetchOnWindowFocus: false,
    placeholderData: keepPreviousData,
    queryFn: async (): Promise<DealerFinancialAccountRow[]> => {
      const [{ data: summaryRows, error: summaryErr }, { data: agingRows, error: agingErr }, { data: dealers, error: dealersErr }] = await Promise.all([
        supabase
          .from('dealer_financial_summary_v1')
          .select('dealer_id, total_invoiced_lifetime, total_paid_lifetime, open_ar, past_due_amount, unapplied_amount, last_payment_date, open_invoices_count, open_so_count')
          .eq('organization_id', orgId!),
        supabase
          .from('dealer_ar_aging_v1')
          .select('dealer_id, current, days_1_30, days_31_60, days_61_90, days_90_plus')
          .eq('organization_id', orgId!),
        supabase
          .from('Dealers')
          .select('id, dealer_name, dealer_no')
          .eq('organization_id', orgId!)
          .eq('deleted', false),
      ]);

      if (summaryErr) throw summaryErr;
      if (agingErr) throw agingErr;
      if (dealersErr) throw dealersErr;

      const summaryByDealer = new Map<string, Record<string, unknown>>(
        ((summaryRows ?? []) as Array<Record<string, unknown>>).map((row) => [String(row.dealer_id), row])
      );
      const agingByDealer = new Map<string, Record<string, unknown>>(
        ((agingRows ?? []) as Array<Record<string, unknown>>).map((row) => [String(row.dealer_id), row])
      );

      const rows = ((dealers ?? []) as Array<{ id: string; dealer_name: string; dealer_no: string | null }>)
        .filter((d) => !activeDealerId || d.id === activeDealerId)
        .map((dealer) => {
          const summary = summaryByDealer.get(dealer.id) ?? {};
          const aging = agingByDealer.get(dealer.id) ?? {};
          const openAr = toNumber(summary.open_ar);
          const pastDue = toNumber(summary.past_due_amount);
          const days90Plus = toNumber(aging.days_90_plus);
          return {
            dealer_id: dealer.id,
            dealer_name: dealer.dealer_name,
            dealer_no: dealer.dealer_no ?? null,
            total_invoiced_lifetime: toNumber(summary.total_invoiced_lifetime),
            total_paid_lifetime: toNumber(summary.total_paid_lifetime),
            open_ar: openAr,
            past_due_amount: pastDue,
            unapplied_amount: toNumber(summary.unapplied_amount),
            last_payment_date: typeof summary.last_payment_date === 'string' ? summary.last_payment_date : null,
            open_invoices_count: Math.trunc(toNumber(summary.open_invoices_count)),
            open_so_count: Math.trunc(toNumber(summary.open_so_count)),
            aging_current: toNumber(aging.current),
            aging_1_30: toNumber(aging.days_1_30),
            aging_31_60: toNumber(aging.days_31_60),
            aging_61_90: toNumber(aging.days_61_90),
            aging_90_plus: days90Plus,
            risk_band: resolveRiskBand({ openAr, pastDue, days90Plus }),
          } satisfies DealerFinancialAccountRow;
        });

      return rows;
    },
  });

  const processed = useMemo(() => {
    const source = query.data ?? [];
    const q = params.q.trim().toLowerCase();
    let rows = q
      ? source.filter((row) =>
          row.dealer_name.toLowerCase().includes(q) ||
          (row.dealer_no ?? '').toLowerCase().includes(q)
        )
      : source;

    if (params.risk !== 'all') {
      rows = rows.filter((row) => row.risk_band === params.risk);
    }

    const [sortField, sortDirRaw] = params.sortKey.split(':');
    const sortDir = sortDirRaw === 'desc' ? -1 : 1;
    const sorted = [...rows].sort((a, b) => {
      if (sortField === 'dealer') return a.dealer_name.localeCompare(b.dealer_name) * sortDir;
      if (sortField === 'open_ar') return (a.open_ar - b.open_ar) * sortDir;
      if (sortField === 'past_due') return (a.past_due_amount - b.past_due_amount) * sortDir;
      if (sortField === 'unapplied') return (a.unapplied_amount - b.unapplied_amount) * sortDir;
      if (sortField === 'last_payment') {
        const at = a.last_payment_date ? new Date(a.last_payment_date).getTime() : 0;
        const bt = b.last_payment_date ? new Date(b.last_payment_date).getTime() : 0;
        return (at - bt) * sortDir;
      }
      return a.dealer_name.localeCompare(b.dealer_name);
    });

    const total = sorted.length;
    const start = (Math.max(1, params.page) - 1) * params.pageSize;
    const pageRows = sorted.slice(start, start + params.pageSize);
    return { rows: pageRows, total, allRows: sorted };
  }, [query.data, params.q, params.risk, params.sortKey, params.page, params.pageSize]);

  return {
    scopeKey,
    isScopeReady,
    isInitialLoading: query.isLoading && !query.data,
    isFetching: query.isFetching,
    isRefreshing: query.isFetching && !!query.data,
    rows: processed.rows,
    allRows: processed.allRows,
    total: processed.total,
    error: query.error ? getSupabaseErrorMessageDetailed(query.error) : null,
    refetch: query.refetch,
  };
}
