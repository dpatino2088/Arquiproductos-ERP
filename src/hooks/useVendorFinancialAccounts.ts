import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useAccessContext } from './useAccessContext';
import { useActiveDealer } from './useActiveDealer';
import { buildDirectoryScopeKey } from '../lib/directoryScopeKey';
import { vendorFinancialAccountsListKey, vendorFinancialDetailKey, vendorFinancialTimelineKey } from '../lib/queryKeys';
import { keepPreviousData } from '../lib/query-client';
import { supabase, initSessionContext } from '../lib/supabase/client';
import { getSupabaseErrorMessageDetailed } from '../lib/supabase-error-utils';

const STALE_TIME_MS = 60_000;
const GC_TIME_MS = 10 * 60_000;

export type VendorFinancialRisk = 'all' | 'healthy' | 'warning' | 'critical';

export interface VendorFinancialAccountRow {
  vendor_id: string;
  vendor_name: string;
  total_billed_lifetime: number;
  total_paid_lifetime: number;
  open_ap: number;
  past_due_amount: number;
  unapplied_amount: number;
  last_payment_date: string | null;
  open_bills_count: number;
  open_po_count: number;
  aging_current: number;
  aging_1_30: number;
  aging_31_60: number;
  aging_61_90: number;
  aging_90_plus: number;
  risk_band: Exclude<VendorFinancialRisk, 'all'>;
}

export interface UseVendorFinancialAccountsParams {
  q: string;
  risk: VendorFinancialRisk;
  sortKey: string;
  page: number;
  pageSize: number;
  enabled?: boolean;
}

function toNumber(v: unknown): number {
  const n = Number(v ?? 0);
  return Number.isFinite(n) ? n : 0;
}

function resolveRiskBand(params: {
  openAp: number;
  pastDue: number;
  days90Plus: number;
}): Exclude<VendorFinancialRisk, 'all'> {
  const { openAp, pastDue, days90Plus } = params;
  if (days90Plus > 0) return 'critical';
  if (pastDue > 0.005 && openAp > 0.005 && (pastDue / openAp) >= 0.4) return 'critical';
  if (pastDue > 0.005) return 'warning';
  return 'healthy';
}

export function useVendorFinancialAccounts(params: UseVendorFinancialAccountsParams) {
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
    queryKey: vendorFinancialAccountsListKey(scopeKey, {
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
    queryFn: async (): Promise<VendorFinancialAccountRow[]> => {
      await initSessionContext();

      const [
        { data: summaryRows, error: summaryErr },
        { data: agingRows, error: agingErr },
        { data: vendors, error: vendorsErr },
      ] = await Promise.all([
        supabase
          .from('vendor_financial_summary_v1')
          .select('vendor_id, total_billed_lifetime, total_paid_lifetime, open_ap, past_due_amount, unapplied_amount, last_payment_date, open_bills_count, open_po_count')
          .eq('organization_id', orgId!),
        supabase
          .from('vendor_ap_aging_v1')
          .select('vendor_id, current, days_1_30, days_31_60, days_61_90, days_90_plus')
          .eq('organization_id', orgId!),
        supabase
          .from('DirectoryVendors')
          .select('id, name')
          .eq('organization_id', orgId!)
          .eq('deleted', false),
      ]);

      if (summaryErr) throw summaryErr;
      if (agingErr) throw agingErr;
      if (vendorsErr) throw vendorsErr;

      const summaryByVendor = new Map<string, Record<string, unknown>>(
        ((summaryRows ?? []) as Array<Record<string, unknown>>).map(r => [String(r.vendor_id), r])
      );
      const agingByVendor = new Map<string, Record<string, unknown>>(
        ((agingRows ?? []) as Array<Record<string, unknown>>).map(r => [String(r.vendor_id), r])
      );

      return ((vendors ?? []) as Array<{ id: string; name: string }>).map(vendor => {
        const summary = summaryByVendor.get(vendor.id) ?? {};
        const aging = agingByVendor.get(vendor.id) ?? {};
        const openAp = toNumber(summary.open_ap);
        const pastDue = toNumber(summary.past_due_amount);
        const days90Plus = toNumber(aging.days_90_plus);
        return {
          vendor_id: vendor.id,
          vendor_name: vendor.name,
          total_billed_lifetime: toNumber(summary.total_billed_lifetime),
          total_paid_lifetime: toNumber(summary.total_paid_lifetime),
          open_ap: openAp,
          past_due_amount: pastDue,
          unapplied_amount: toNumber(summary.unapplied_amount),
          last_payment_date: typeof summary.last_payment_date === 'string' ? summary.last_payment_date : null,
          open_bills_count: Math.trunc(toNumber(summary.open_bills_count)),
          open_po_count: Math.trunc(toNumber(summary.open_po_count)),
          aging_current: toNumber(aging.current),
          aging_1_30: toNumber(aging.days_1_30),
          aging_31_60: toNumber(aging.days_31_60),
          aging_61_90: toNumber(aging.days_61_90),
          aging_90_plus: days90Plus,
          risk_band: resolveRiskBand({ openAp, pastDue, days90Plus }),
        } satisfies VendorFinancialAccountRow;
      });
    },
  });

  const processed = useMemo(() => {
    const source = query.data ?? [];
    const q = params.q.trim().toLowerCase();
    let rows = q
      ? source.filter(r => r.vendor_name.toLowerCase().includes(q))
      : source;

    if (params.risk !== 'all') {
      rows = rows.filter(r => r.risk_band === params.risk);
    }

    const [sortField, sortDirRaw] = params.sortKey.split(':');
    const sortDir = sortDirRaw === 'desc' ? -1 : 1;
    const sorted = [...rows].sort((a, b) => {
      if (sortField === 'vendor') return a.vendor_name.localeCompare(b.vendor_name) * sortDir;
      if (sortField === 'open_ap') return (a.open_ap - b.open_ap) * sortDir;
      if (sortField === 'past_due') return (a.past_due_amount - b.past_due_amount) * sortDir;
      if (sortField === 'unapplied') return (a.unapplied_amount - b.unapplied_amount) * sortDir;
      if (sortField === 'last_payment') {
        const at = a.last_payment_date ? new Date(a.last_payment_date).getTime() : 0;
        const bt = b.last_payment_date ? new Date(b.last_payment_date).getTime() : 0;
        return (at - bt) * sortDir;
      }
      return a.vendor_name.localeCompare(b.vendor_name);
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

export interface VendorFinancialDetail {
  vendor_id: string;
  vendor_name: string;
  vendor_email: string | null;
  vendor_phone: string | null;
  total_billed_lifetime: number;
  total_paid_lifetime: number;
  open_ap: number;
  past_due_amount: number;
  unapplied_amount: number;
  last_payment_date: string | null;
  open_bills_count: number;
  open_po_count: number;
  aging: {
    current: number;
    days_1_30: number;
    days_31_60: number;
    days_61_90: number;
    days_90_plus: number;
  };
}

export function useVendorFinancialDetail(vendorId: string | null) {
  const { activeOrganizationId } = useOrganizationContext();
  const { userType } = useAccessContext();
  const { activeDealerId, hasHydrated } = useActiveDealer();

  const orgId = activeOrganizationId ?? null;
  const isScopeReady = userType === 'internal' ? hasHydrated : true;
  const enabled = !!orgId && !!vendorId && isScopeReady;

  const scopeKey = buildDirectoryScopeKey({
    orgId,
    activeDealerId: activeDealerId ?? null,
    userRole: userType,
  });

  const query = useQuery({
    queryKey: vendorFinancialDetailKey(scopeKey, vendorId ?? ''),
    enabled,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    queryFn: async (): Promise<VendorFinancialDetail> => {
      await initSessionContext();

      const [
        { data: summaryRows, error: summaryErr },
        { data: agingRows, error: agingErr },
        { data: vendor, error: vendorErr },
      ] = await Promise.all([
        supabase
          .from('vendor_financial_summary_v1')
          .select('*')
          .eq('organization_id', orgId!)
          .eq('vendor_id', vendorId!)
          .maybeSingle(),
        supabase
          .from('vendor_ap_aging_v1')
          .select('*')
          .eq('organization_id', orgId!)
          .eq('vendor_id', vendorId!)
          .maybeSingle(),
        supabase
          .from('DirectoryVendors')
          .select('id, name, email, work_phone')
          .eq('id', vendorId!)
          .single(),
      ]);

      if (summaryErr) throw summaryErr;
      if (agingErr) throw agingErr;
      if (vendorErr) throw vendorErr;

      const s = (summaryRows as Record<string, unknown> | null) ?? {};
      const a = (agingRows as Record<string, unknown> | null) ?? {};
      const v = vendor as { id: string; name: string; email: string | null; work_phone: string | null };

      return {
        vendor_id: v.id,
        vendor_name: v.name,
        vendor_email: v.email,
        vendor_phone: v.work_phone,
        total_billed_lifetime: toNumber(s.total_billed_lifetime),
        total_paid_lifetime: toNumber(s.total_paid_lifetime),
        open_ap: toNumber(s.open_ap),
        past_due_amount: toNumber(s.past_due_amount),
        unapplied_amount: toNumber(s.unapplied_amount),
        last_payment_date: typeof s.last_payment_date === 'string' ? s.last_payment_date : null,
        open_bills_count: Math.trunc(toNumber(s.open_bills_count)),
        open_po_count: Math.trunc(toNumber(s.open_po_count)),
        aging: {
          current: toNumber(a.current),
          days_1_30: toNumber(a.days_1_30),
          days_31_60: toNumber(a.days_31_60),
          days_61_90: toNumber(a.days_61_90),
          days_90_plus: toNumber(a.days_90_plus),
        },
      };
    },
  });

  return {
    detail: query.data ?? null,
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    error: query.error ? getSupabaseErrorMessageDetailed(query.error) : null,
    refetch: query.refetch,
  };
}

export interface VendorFinancialTimelineEntry {
  entity_id: string;
  entity_type: string;
  event_type: string;
  event_at: string;
  reference_no: string | null;
  amount: number;
}

export function useVendorFinancialTimeline(vendorId: string | null) {
  const { activeOrganizationId } = useOrganizationContext();
  const { userType } = useAccessContext();
  const { activeDealerId, hasHydrated } = useActiveDealer();

  const orgId = activeOrganizationId ?? null;
  const isScopeReady = userType === 'internal' ? hasHydrated : true;
  const enabled = !!orgId && !!vendorId && isScopeReady;

  const scopeKey = buildDirectoryScopeKey({
    orgId,
    activeDealerId: activeDealerId ?? null,
    userRole: userType,
  });

  const query = useQuery({
    queryKey: vendorFinancialTimelineKey(scopeKey, vendorId ?? ''),
    enabled,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    queryFn: async (): Promise<VendorFinancialTimelineEntry[]> => {
      await initSessionContext();

      const { data, error } = await supabase
        .from('vendor_financial_timeline_v1')
        .select('entity_id, entity_type, event_type, event_at, reference_no, amount')
        .eq('organization_id', orgId!)
        .eq('vendor_id', vendorId!)
        .order('event_at', { ascending: false })
        .limit(200);

      if (error) throw error;

      return ((data ?? []) as VendorFinancialTimelineEntry[]).map(e => ({
        ...e,
        amount: toNumber(e.amount),
      }));
    },
  });

  return {
    entries: query.data ?? [],
    isLoading: query.isLoading,
    error: query.error ? getSupabaseErrorMessageDetailed(query.error) : null,
    refetch: query.refetch,
  };
}
