import { useCallback, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useAccessContext } from './useAccessContext';
import { useActiveDealer } from './useActiveDealer';
import { buildDirectoryScopeKey } from '../lib/directoryScopeKey';
import { vendorBillsListKey, vendorBillDetailKey } from '../lib/queryKeys';
import { keepPreviousData } from '../lib/query-client';
import { supabase, initSessionContext } from '../lib/supabase/client';
import { getSupabaseErrorMessageDetailed } from '../lib/supabase-error-utils';
import { useUIStore } from '../stores/ui-store';

const STALE_TIME_MS = 60_000;
const GC_TIME_MS = 10 * 60_000;

export interface VendorBillLine {
  id: string;
  bill_id: string;
  catalog_item_id: string | null;
  purchase_order_line_id: string | null;
  sort_order: number;
  description: string | null;
  qty: number;
  unit_cost: number;
  tax_pct: number;
  line_subtotal: number;
  line_tax: number;
  line_total: number;
}

export interface VendorBill {
  id: string;
  organization_id: string;
  vendor_id: string;
  purchase_order_id: string | null;
  bill_number: string;
  vendor_bill_ref: string | null;
  status: string;
  bill_date: string;
  due_date: string | null;
  currency_code: string;
  subtotal: number;
  tax_total: number;
  total: number;
  notes: string | null;
  void_reason: string | null;
  voided_by: string | null;
  voided_at: string | null;
  deleted: boolean;
  created_at: string;
  updated_at: string;
  vendor_name?: string;
  lines?: VendorBillLine[];
}

export interface VendorBillsListParams {
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

export function useVendorBillsList(params: VendorBillsListParams) {
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
    queryKey: vendorBillsListKey(scopeKey, {
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

      let billsQuery = supabase
        .from('VendorBills')
        .select('id, organization_id, vendor_id, purchase_order_id, bill_number, vendor_bill_ref, status, bill_date, due_date, currency_code, subtotal, tax_total, total, notes, void_reason, created_at, updated_at')
        .eq('organization_id', orgId!)
        .eq('deleted', false);

      if (params.status && params.status !== 'all') {
        billsQuery = billsQuery.eq('status', params.status);
      }

      const [sortField, sortDirRaw] = params.sortKey.split(':');
      const ascending = sortDirRaw !== 'desc';
      if (sortField !== 'vendor') {
        const dbSortField = sortField === 'bill_date' ? 'bill_date' : sortField === 'due_date' ? 'due_date' : sortField === 'total' ? 'total' : 'bill_date';
        billsQuery = billsQuery.order(dbSortField, { ascending });
      } else {
        billsQuery = billsQuery.order('bill_date', { ascending: false });
      }

      const { data: bills, error } = await billsQuery;
      if (error) throw error;

      const vendorIds = [...new Set(((bills ?? []) as VendorBill[]).map(b => b.vendor_id).filter(Boolean))];
      let vendorMap = new Map<string, string>();
      if (vendorIds.length > 0) {
        const { data: vendors } = await supabase
          .from('DirectoryVendors')
          .select('id, name')
          .in('id', vendorIds);
        vendorMap = new Map(((vendors ?? []) as Array<{ id: string; name: string }>).map(v => [v.id, v.name]));
      }

      let result = ((bills ?? []) as VendorBill[]).map(b => ({
        ...b,
        subtotal: toNumber(b.subtotal),
        tax_total: toNumber(b.tax_total),
        total: toNumber(b.total),
        vendor_name: vendorMap.get(b.vendor_id) ?? '—',
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

  const q = params.q.trim().toLowerCase();
  const rows = (query.data ?? []).filter(b =>
    !q || b.bill_number?.toLowerCase().includes(q) || b.vendor_name?.toLowerCase().includes(q) || b.vendor_bill_ref?.toLowerCase().includes(q)
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

export function useVendorBillDetail(billId: string | null) {
  const { activeOrganizationId } = useOrganizationContext();
  const { userType } = useAccessContext();
  const { activeDealerId, hasHydrated } = useActiveDealer();

  const orgId = activeOrganizationId ?? null;
  const isScopeReady = userType === 'internal' ? hasHydrated : true;
  const enabled = !!orgId && !!billId && isScopeReady;

  const scopeKey = buildDirectoryScopeKey({
    orgId,
    activeDealerId: activeDealerId ?? null,
    userRole: userType,
  });

  const query = useQuery({
    queryKey: vendorBillDetailKey(scopeKey, billId ?? ''),
    enabled,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    queryFn: async () => {
      await initSessionContext();

      const { data: bill, error } = await supabase
        .from('VendorBills')
        .select('*')
        .eq('id', billId!)
        .eq('organization_id', orgId!)
        .single();
      if (error) throw error;

      const { data: lines, error: linesErr } = await supabase
        .from('VendorBillLines')
        .select('*')
        .eq('bill_id', billId!)
        .order('sort_order', { ascending: true });
      if (linesErr) throw linesErr;

      const { data: vendor } = await supabase
        .from('DirectoryVendors')
        .select('id, name, email, work_phone')
        .eq('id', (bill as VendorBill).vendor_id)
        .single();

      return {
        ...(bill as VendorBill),
        subtotal: toNumber((bill as VendorBill).subtotal),
        tax_total: toNumber((bill as VendorBill).tax_total),
        total: toNumber((bill as VendorBill).total),
        vendor_name: (vendor as { name: string } | null)?.name ?? '—',
        lines: ((lines ?? []) as VendorBillLine[]).map(l => ({
          ...l,
          qty: toNumber(l.qty),
          unit_cost: toNumber(l.unit_cost),
          tax_pct: toNumber(l.tax_pct),
          line_subtotal: toNumber(l.line_subtotal),
          line_tax: toNumber(l.line_tax),
          line_total: toNumber(l.line_total),
        })),
      } as VendorBill;
    },
  });

  return {
    bill: query.data ?? null,
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    error: query.error ? getSupabaseErrorMessageDetailed(query.error) : null,
    refetch: query.refetch,
  };
}

export interface CreateVendorBillParams {
  vendor_id: string;
  purchase_order_id?: string | null;
  bill_number: string;
  vendor_bill_ref?: string | null;
  status?: string;
  bill_date: string;
  due_date?: string | null;
  currency_code?: string;
  notes?: string | null;
  lines: Array<{
    catalog_item_id?: string | null;
    purchase_order_line_id?: string | null;
    sort_order: number;
    description: string;
    qty: number;
    unit_cost: number;
    tax_pct: number;
  }>;
}

async function updatePOBillingStatus(poId: string) {
  const { data: po } = await supabase
    .from('PurchaseOrders')
    .select('total')
    .eq('id', poId)
    .single();
  if (!po) return;

  const { data: bills } = await supabase
    .from('VendorBills')
    .select('total')
    .eq('purchase_order_id', poId)
    .eq('deleted', false)
    .neq('status', 'void');

  const billedTotal = ((bills ?? []) as Array<{ total: number }>).reduce((s, b) => s + toNumber(b.total), 0);
  const poTotal = toNumber((po as { total: number }).total);

  let billingStatus = 'unbilled';
  if (billedTotal >= poTotal - 0.005 && poTotal > 0) billingStatus = 'billed';
  else if (billedTotal > 0.005) billingStatus = 'partial';

  await supabase
    .from('PurchaseOrders')
    .update({ billing_status: billingStatus })
    .eq('id', poId);
}

export function useVendorBillMutations() {
  const { activeOrganizationId } = useOrganizationContext();
  const queryClient = useQueryClient();
  const addNotification = useUIStore(s => s.addNotification);
  const [isSaving, setIsSaving] = useState(false);

  const invalidate = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: ['financials', 'vendor-bills'] });
    queryClient.invalidateQueries({ queryKey: ['financials', 'vendor-accounts'] });
  }, [queryClient]);

  const createBill = useCallback(async (params: CreateVendorBillParams) => {
    if (!activeOrganizationId) throw new Error('No organization');
    setIsSaving(true);
    try {
      await initSessionContext();

      const lines = params.lines.map(l => {
        const lineSubtotal = +(l.qty * l.unit_cost).toFixed(2);
        const lineTax = +(lineSubtotal * l.tax_pct / 100).toFixed(2);
        return { ...l, line_subtotal: lineSubtotal, line_tax: lineTax, line_total: +(lineSubtotal + lineTax).toFixed(2) };
      });
      const subtotal = lines.reduce((s, l) => s + l.line_subtotal, 0);
      const taxTotal = lines.reduce((s, l) => s + l.line_tax, 0);
      const total = +(subtotal + taxTotal).toFixed(2);

      const { data: bill, error } = await supabase
        .from('VendorBills')
        .insert({
          organization_id: activeOrganizationId,
          vendor_id: params.vendor_id,
          purchase_order_id: params.purchase_order_id ?? null,
          bill_number: params.bill_number,
          vendor_bill_ref: params.vendor_bill_ref ?? null,
          status: params.status ?? 'draft',
          bill_date: params.bill_date,
          due_date: params.due_date ?? null,
          currency_code: params.currency_code ?? 'USD',
          subtotal,
          tax_total: taxTotal,
          total,
          notes: params.notes ?? null,
        })
        .select('id')
        .single();
      if (error) throw error;

      if (lines.length > 0) {
        const { error: linesErr } = await supabase
          .from('VendorBillLines')
          .insert(lines.map(l => ({
            bill_id: (bill as { id: string }).id,
            catalog_item_id: l.catalog_item_id ?? null,
            purchase_order_line_id: l.purchase_order_line_id ?? null,
            sort_order: l.sort_order,
            description: l.description,
            qty: l.qty,
            unit_cost: l.unit_cost,
            tax_pct: l.tax_pct,
            line_subtotal: l.line_subtotal,
            line_tax: l.line_tax,
            line_total: l.line_total,
          })));
        if (linesErr) throw linesErr;
      }

      if (params.purchase_order_id) {
        await updatePOBillingStatus(params.purchase_order_id);
      }

      invalidate();
      addNotification({ type: 'success', title: 'Bill Created', message: `Bill ${params.bill_number} created.` });
      return (bill as { id: string }).id;
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to create bill';
      addNotification({ type: 'error', title: 'Error', message: msg });
      throw err;
    } finally {
      setIsSaving(false);
    }
  }, [activeOrganizationId, invalidate, addNotification]);

  const voidBill = useCallback(async (billId: string, reason: string, userId: string) => {
    if (!activeOrganizationId) return;
    setIsSaving(true);
    try {
      await initSessionContext();

      const { data: billData } = await supabase
        .from('VendorBills')
        .select('purchase_order_id')
        .eq('id', billId)
        .single();

      const { error } = await supabase
        .from('VendorBills')
        .update({ status: 'void', void_reason: reason, voided_by: userId, voided_at: new Date().toISOString(), updated_at: new Date().toISOString() })
        .eq('id', billId)
        .eq('organization_id', activeOrganizationId);
      if (error) throw error;

      await supabase.from('FinancialAuditLog').insert({
        organization_id: activeOrganizationId,
        entity_type: 'vendor_bill',
        entity_id: billId,
        action: 'void',
        performed_by: userId,
        details: { reason },
      });

      if ((billData as { purchase_order_id: string | null } | null)?.purchase_order_id) {
        await updatePOBillingStatus((billData as { purchase_order_id: string }).purchase_order_id);
      }

      invalidate();
      addNotification({ type: 'success', title: 'Bill Voided', message: 'Vendor bill voided.' });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to void bill';
      addNotification({ type: 'error', title: 'Error', message: msg });
      throw err;
    } finally {
      setIsSaving(false);
    }
  }, [activeOrganizationId, invalidate, addNotification]);

  const deleteDraft = useCallback(async (billId: string) => {
    if (!activeOrganizationId) return;
    setIsSaving(true);
    try {
      await initSessionContext();
      const { error } = await supabase
        .from('VendorBills')
        .update({ deleted: true, updated_at: new Date().toISOString() })
        .eq('id', billId)
        .eq('organization_id', activeOrganizationId)
        .eq('status', 'draft');
      if (error) throw error;
      invalidate();
      addNotification({ type: 'success', title: 'Bill Deleted', message: 'Draft bill deleted.' });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to delete bill';
      addNotification({ type: 'error', title: 'Error', message: msg });
      throw err;
    } finally {
      setIsSaving(false);
    }
  }, [activeOrganizationId, invalidate, addNotification]);

  const issueBill = useCallback(async (billId: string) => {
    if (!activeOrganizationId) return;
    setIsSaving(true);
    try {
      await initSessionContext();
      const { error } = await supabase
        .from('VendorBills')
        .update({ status: 'open', updated_at: new Date().toISOString() })
        .eq('id', billId)
        .eq('organization_id', activeOrganizationId)
        .eq('status', 'draft');
      if (error) throw error;
      invalidate();
      addNotification({ type: 'success', title: 'Bill Issued', message: 'Bill status set to Open.' });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to issue bill';
      addNotification({ type: 'error', title: 'Error', message: msg });
      throw err;
    } finally {
      setIsSaving(false);
    }
  }, [activeOrganizationId, invalidate, addNotification]);

  return { createBill, voidBill, deleteDraft, issueBill, isSaving };
}
