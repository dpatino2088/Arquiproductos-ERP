import { useCallback, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useAccessContext } from './useAccessContext';
import { useActiveDealer } from './useActiveDealer';
import { buildDirectoryScopeKey } from '../lib/directoryScopeKey';
import { vendorPaymentsListKey, vendorPaymentDetailKey } from '../lib/queryKeys';
import { keepPreviousData } from '../lib/query-client';
import { supabase, initSessionContext } from '../lib/supabase/client';
import { getSupabaseErrorMessageDetailed } from '../lib/supabase-error-utils';
import { getAppUsersDisplayNames } from '../lib/appUsersDisplayNames';
import { useUIStore } from '../stores/ui-store';

const STALE_TIME_MS = 60_000;
const GC_TIME_MS = 10 * 60_000;

export interface VendorPayment {
  id: string;
  organization_id: string;
  vendor_id: string;
  amount: number;
  payment_method: string | null;
  reference_number: string | null;
  bank_name: string | null;
  payment_date: string;
  description: string | null;
  notes: string | null;
  recorded_by: string | null;
  recorded_by_name: string | null;
  status: string;
  void_reason: string | null;
  voided_by: string | null;
  voided_at: string | null;
  created_at: string;
  vendor_name?: string;
}

export interface VendorPaymentApplication {
  id: string;
  vendor_payment_id: string;
  bill_id: string;
  applied_amount: number;
  created_at: string;
  bill_number?: string;
  bill_total?: number;
}

export interface VendorPaymentsListParams {
  q: string;
  status: string;
  sortKey: string;
  page: number;
  pageSize: number;
  enabled?: boolean;
}

function toNumber(v: unknown): number {
  const n = Number(v ?? 0);
  return Number.isFinite(n) ? n : 0;
}

export function useVendorPaymentsList(params: VendorPaymentsListParams) {
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
    queryKey: vendorPaymentsListKey(scopeKey, {
      q: params.q.trim().toLowerCase(),
      status: params.status,
      sortKey: params.sortKey,
      page: params.page,
      pageSize: params.pageSize,
    }),
    enabled,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    refetchOnWindowFocus: false,
    placeholderData: keepPreviousData,
    queryFn: async () => {
      await initSessionContext();

      let q = supabase
        .from('VendorPayments')
        .select('id, organization_id, vendor_id, amount, payment_method, reference_number, bank_name, payment_date, description, notes, recorded_by_name, status, void_reason, created_at')
        .eq('organization_id', orgId!)
        .eq('deleted', false);

      if (params.status && params.status !== 'all') {
        q = q.eq('status', params.status);
      }

      const [sortField, sortDirRaw] = params.sortKey.split(':');
      const ascending = sortDirRaw !== 'desc';
      if (sortField !== 'vendor') {
        const dbField = sortField === 'amount' ? 'amount' : sortField === 'method' ? 'payment_method' : 'payment_date';
        q = q.order(dbField, { ascending });
      } else {
        q = q.order('payment_date', { ascending: false });
      }

      const { data, error } = await q;
      if (error) throw error;

      const vendorIds = [...new Set(((data ?? []) as VendorPayment[]).map(p => p.vendor_id).filter(Boolean))];
      let vendorMap = new Map<string, string>();
      if (vendorIds.length > 0) {
        const { data: vendors } = await supabase
          .from('DirectoryVendors')
          .select('id, name')
          .in('id', vendorIds);
        vendorMap = new Map(((vendors ?? []) as Array<{ id: string; name: string }>).map(v => [v.id, v.name]));
      }

      let result = ((data ?? []) as VendorPayment[]).map(p => ({
        ...p,
        amount: toNumber(p.amount),
        vendor_name: vendorMap.get(p.vendor_id) ?? '—',
      }));

      if (sortField === 'vendor') {
        result.sort((a, b) => {
          const cmp = (a.vendor_name ?? '').localeCompare(b.vendor_name ?? '');
          return ascending ? cmp : -cmp;
        });
      }

      return result;
    },
  });

  const search = params.q.trim().toLowerCase();
  const rows = (query.data ?? []).filter(p =>
    !search || p.vendor_name?.toLowerCase().includes(search) || p.reference_number?.toLowerCase().includes(search)
  );
  const total = rows.length;
  const start = (Math.max(1, params.page) - 1) * params.pageSize;
  const pageRows = rows.slice(start, start + params.pageSize);

  return {
    scopeKey,
    isScopeReady,
    isInitialLoading: query.isLoading && !query.data,
    isFetching: query.isFetching,
    rows: pageRows,
    total,
    error: query.error ? getSupabaseErrorMessageDetailed(query.error) : null,
    refetch: query.refetch,
  };
}

export function useVendorPaymentDetail(paymentId: string | null) {
  const { activeOrganizationId } = useOrganizationContext();
  const { userType } = useAccessContext();
  const { activeDealerId, hasHydrated } = useActiveDealer();

  const orgId = activeOrganizationId ?? null;
  const isScopeReady = userType === 'internal' ? hasHydrated : true;
  const enabled = !!orgId && !!paymentId && isScopeReady;

  const scopeKey = buildDirectoryScopeKey({
    orgId,
    activeDealerId: activeDealerId ?? null,
    userRole: userType,
  });

  const query = useQuery({
    queryKey: vendorPaymentDetailKey(scopeKey, paymentId ?? ''),
    enabled,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    queryFn: async () => {
      await initSessionContext();

      const { data: payment, error } = await supabase
        .from('VendorPayments')
        .select('*')
        .eq('id', paymentId!)
        .eq('organization_id', orgId!)
        .single();
      if (error) throw error;

      const { data: vendor } = await supabase
        .from('DirectoryVendors')
        .select('id, name')
        .eq('id', (payment as VendorPayment).vendor_id)
        .single();

      const { data: apps } = await supabase
        .from('VendorPaymentApplications')
        .select('id, vendor_payment_id, bill_id, applied_amount, created_at')
        .eq('vendor_payment_id', paymentId!);

      const billIds = [...new Set(((apps ?? []) as VendorPaymentApplication[]).map(a => a.bill_id).filter(Boolean))];
      let billMap = new Map<string, { bill_number: string; total: number }>();
      if (billIds.length > 0) {
        const { data: bills } = await supabase
          .from('VendorBills')
          .select('id, bill_number, total')
          .in('id', billIds);
        billMap = new Map(((bills ?? []) as Array<{ id: string; bill_number: string; total: number }>).map(b => [b.id, { bill_number: b.bill_number, total: toNumber(b.total) }]));
      }

      const vp = payment as VendorPayment;
      if (vp.recorded_by) {
        const nameMap = await getAppUsersDisplayNames([vp.recorded_by]);
        const resolved = nameMap.get(vp.recorded_by);
        if (resolved && resolved !== 'Legacy / Imported') vp.recorded_by_name = resolved;
      }

      return {
        payment: {
          ...vp,
          amount: toNumber(vp.amount),
          vendor_name: (vendor as { name: string } | null)?.name ?? '—',
        } as VendorPayment,
        applications: ((apps ?? []) as VendorPaymentApplication[]).map(a => ({
          ...a,
          applied_amount: toNumber(a.applied_amount),
          bill_number: billMap.get(a.bill_id)?.bill_number ?? '—',
          bill_total: billMap.get(a.bill_id)?.total ?? 0,
        })),
      };
    },
  });

  return {
    payment: query.data?.payment ?? null,
    applications: query.data?.applications ?? [],
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    error: query.error ? getSupabaseErrorMessageDetailed(query.error) : null,
    refetch: query.refetch,
  };
}

export interface RecordVendorPaymentParams {
  vendor_id: string;
  amount: number;
  payment_method: string;
  reference_number?: string;
  bank_name?: string;
  payment_date: string;
  description?: string | null;
  notes?: string | null;
  userId: string | null;
  userName?: string | null;
}

export function useVendorPaymentMutations() {
  const { activeOrganizationId } = useOrganizationContext();
  const queryClient = useQueryClient();
  const addNotification = useUIStore(s => s.addNotification);
  const [isSaving, setIsSaving] = useState(false);

  const invalidate = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: ['financials', 'vendor-payments'] });
    queryClient.invalidateQueries({ queryKey: ['financials', 'vendor-bills'] });
    queryClient.invalidateQueries({ queryKey: ['financials', 'vendor-accounts'] });
  }, [queryClient]);

  const recordPayment = useCallback(async (params: RecordVendorPaymentParams) => {
    if (!activeOrganizationId) throw new Error('No organization');
    setIsSaving(true);
    try {
      await initSessionContext();
      const { data, error } = await supabase
        .from('VendorPayments')
        .insert({
          organization_id: activeOrganizationId,
          vendor_id: params.vendor_id,
          amount: params.amount,
          payment_method: params.payment_method,
          reference_number: params.reference_number?.trim() || null,
          bank_name: params.bank_name?.trim() || null,
          payment_date: params.payment_date,
          description: params.description?.trim() || null,
          notes: params.notes?.trim() || null,
          recorded_by: params.userId,
          recorded_by_name: params.userName ?? null,
        })
        .select('id')
        .single();
      if (error) throw error;
      invalidate();
      addNotification({ type: 'success', title: 'Payment Recorded', message: 'Vendor payment recorded.' });
      return (data as { id: string }).id;
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to record payment';
      addNotification({ type: 'error', title: 'Error', message: msg });
      throw err;
    } finally {
      setIsSaving(false);
    }
  }, [activeOrganizationId, invalidate, addNotification]);

  const applyToBill = useCallback(async (paymentId: string, billId: string, amount: number) => {
    if (!activeOrganizationId) return;
    setIsSaving(true);
    try {
      await initSessionContext();
      const { error } = await supabase
        .from('VendorPaymentApplications')
        .insert({ vendor_payment_id: paymentId, bill_id: billId, applied_amount: amount });
      if (error) throw error;

      const { data: apps } = await supabase
        .from('VendorPaymentApplications')
        .select('applied_amount')
        .eq('bill_id', billId);
      const totalApplied = ((apps ?? []) as Array<{ applied_amount: number }>).reduce((s, a) => s + toNumber(a.applied_amount), 0);

      const { data: bill } = await supabase
        .from('VendorBills')
        .select('total')
        .eq('id', billId)
        .single();
      const billTotal = toNumber((bill as { total: number } | null)?.total);

      let newStatus = 'open';
      if (totalApplied >= billTotal - 0.005) newStatus = 'paid';
      else if (totalApplied > 0.005) newStatus = 'partial';

      await supabase
        .from('VendorBills')
        .update({ status: newStatus, updated_at: new Date().toISOString() })
        .eq('id', billId);

      invalidate();
      addNotification({ type: 'success', title: 'Payment Applied', message: 'Payment applied to bill.' });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to apply payment';
      addNotification({ type: 'error', title: 'Error', message: msg });
      throw err;
    } finally {
      setIsSaving(false);
    }
  }, [activeOrganizationId, invalidate, addNotification]);

  const unapplyFromBill = useCallback(async (applicationId: string, billId: string, userId: string) => {
    if (!activeOrganizationId) return;
    setIsSaving(true);
    try {
      await initSessionContext();
      const { error } = await supabase
        .from('VendorPaymentApplications')
        .delete()
        .eq('id', applicationId);
      if (error) throw error;

      await supabase.from('FinancialAuditLog').insert({
        organization_id: activeOrganizationId,
        entity_type: 'vendor_payment_application',
        entity_id: applicationId,
        action: 'unapply',
        performed_by: userId,
        details: { bill_id: billId },
      });

      const { data: remainingApps } = await supabase
        .from('VendorPaymentApplications')
        .select('applied_amount')
        .eq('bill_id', billId);
      const totalApplied = ((remainingApps ?? []) as Array<{ applied_amount: number }>).reduce((s, a) => s + toNumber(a.applied_amount), 0);

      const { data: bill } = await supabase
        .from('VendorBills')
        .select('total')
        .eq('id', billId)
        .single();
      const billTotal = toNumber((bill as { total: number } | null)?.total);

      let newStatus = 'open';
      if (totalApplied >= billTotal - 0.005) newStatus = 'paid';
      else if (totalApplied > 0.005) newStatus = 'partial';

      await supabase
        .from('VendorBills')
        .update({ status: newStatus, updated_at: new Date().toISOString() })
        .eq('id', billId);

      invalidate();
      addNotification({ type: 'success', title: 'Payment Unapplied', message: 'Payment removed from bill.' });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to unapply payment';
      addNotification({ type: 'error', title: 'Error', message: msg });
      throw err;
    } finally {
      setIsSaving(false);
    }
  }, [activeOrganizationId, invalidate, addNotification]);

  const voidPayment = useCallback(async (paymentId: string, reason: string, userId: string) => {
    if (!activeOrganizationId) return;
    setIsSaving(true);
    try {
      await initSessionContext();
      const { error } = await supabase
        .from('VendorPayments')
        .update({ status: 'void', void_reason: reason, voided_by: userId, voided_at: new Date().toISOString(), updated_at: new Date().toISOString() })
        .eq('id', paymentId)
        .eq('organization_id', activeOrganizationId);
      if (error) throw error;

      await supabase.from('FinancialAuditLog').insert({
        organization_id: activeOrganizationId,
        entity_type: 'vendor_payment',
        entity_id: paymentId,
        action: 'void',
        performed_by: userId,
        details: { reason },
      });

      invalidate();
      addNotification({ type: 'success', title: 'Payment Voided', message: 'Vendor payment voided.' });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to void payment';
      addNotification({ type: 'error', title: 'Error', message: msg });
      throw err;
    } finally {
      setIsSaving(false);
    }
  }, [activeOrganizationId, invalidate, addNotification]);

  return { recordPayment, applyToBill, unapplyFromBill, voidPayment, isSaving };
}
