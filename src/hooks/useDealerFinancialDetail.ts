import { useQuery } from '@tanstack/react-query';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useAccessContext } from './useAccessContext';
import { useActiveDealer } from './useActiveDealer';
import { buildDirectoryScopeKey } from '../lib/directoryScopeKey';
import { dealerFinancialDetailKey } from '../lib/queryKeys';
import { supabase } from '../lib/supabase/client';
import { getSupabaseErrorMessageDetailed } from '../lib/supabase-error-utils';

const STALE_TIME_MS = 60_000;
const GC_TIME_MS = 10 * 60_000;

export interface DealerFinancialDetail {
  dealer_id: string;
  dealer_name: string;
  dealer_no: string | null;
  dealer_email: string | null;
  dealer_phone: string | null;
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
}

function toNumber(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function useDealerFinancialDetail(dealerId: string | null, enabled = true) {
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
    queryKey: dealerFinancialDetailKey(scopeKey, dealerId ?? ''),
    enabled: enabled && !!orgId && !!dealerId && isScopeReady,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    refetchOnWindowFocus: false,
    queryFn: async (): Promise<DealerFinancialDetail | null> => {
      const [{ data: dealer, error: dealerErr }, { data: summary, error: summaryErr }, { data: aging, error: agingErr }] = await Promise.all([
        supabase
          .from('Dealers')
          .select('id, dealer_name, dealer_no, dealer_email, dealer_phone')
          .eq('organization_id', orgId!)
          .eq('id', dealerId!)
          .eq('deleted', false)
          .maybeSingle(),
        supabase
          .from('dealer_financial_summary_v1')
          .select('dealer_id, total_invoiced_lifetime, total_paid_lifetime, open_ar, past_due_amount, unapplied_amount, last_payment_date, open_invoices_count, open_so_count')
          .eq('organization_id', orgId!)
          .eq('dealer_id', dealerId!)
          .maybeSingle(),
        supabase
          .from('dealer_ar_aging_v1')
          .select('dealer_id, current, days_1_30, days_31_60, days_61_90, days_90_plus')
          .eq('organization_id', orgId!)
          .eq('dealer_id', dealerId!)
          .maybeSingle(),
      ]);

      if (dealerErr) throw dealerErr;
      if (summaryErr) throw summaryErr;
      if (agingErr) throw agingErr;
      if (!dealer) return null;

      return {
        dealer_id: dealer.id,
        dealer_name: dealer.dealer_name,
        dealer_no: dealer.dealer_no ?? null,
        dealer_email: dealer.dealer_email ?? null,
        dealer_phone: dealer.dealer_phone ?? null,
        total_invoiced_lifetime: toNumber(summary?.total_invoiced_lifetime),
        total_paid_lifetime: toNumber(summary?.total_paid_lifetime),
        open_ar: toNumber(summary?.open_ar),
        past_due_amount: toNumber(summary?.past_due_amount),
        unapplied_amount: toNumber(summary?.unapplied_amount),
        last_payment_date: typeof summary?.last_payment_date === 'string' ? summary.last_payment_date : null,
        open_invoices_count: Math.trunc(toNumber(summary?.open_invoices_count)),
        open_so_count: Math.trunc(toNumber(summary?.open_so_count)),
        aging_current: toNumber(aging?.current),
        aging_1_30: toNumber(aging?.days_1_30),
        aging_31_60: toNumber(aging?.days_31_60),
        aging_61_90: toNumber(aging?.days_61_90),
        aging_90_plus: toNumber(aging?.days_90_plus),
      };
    },
  });

  return {
    scopeKey,
    isScopeReady,
    detail: query.data ?? null,
    isInitialLoading: query.isLoading && !query.data,
    isFetching: query.isFetching,
    isRefreshing: query.isFetching && !!query.data,
    error: query.error ? getSupabaseErrorMessageDetailed(query.error) : null,
    refetch: query.refetch,
  };
}
