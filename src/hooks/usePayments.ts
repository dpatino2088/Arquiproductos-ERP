import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useUIStore } from '../stores/ui-store';
import { getAppUsersDisplayNames } from '../lib/appUsersDisplayNames';

export interface PaymentInvoiceRef {
  invoice_id: string;
  invoice_number: string;
}

export interface Payment {
  id: string;
  amount: number;
  payment_method: string;
  reference_number: string | null;
  payment_date: string;
  notes: string | null;
  recorded_by: string | null;
  created_at: string;
  bank_name?: string | null;
  description?: string | null;
  recorded_by_name?: string | null;
  recorded_by_display_name?: string;
  invoice_refs?: PaymentInvoiceRef[];
}

export function usePayments(salesOrderId: string | null) {
  const { activeOrganizationId } = useOrganizationContext();
  const [payments, setPayments] = useState<Payment[]>([]);
  const [loading, setLoading] = useState(false);

  const fetchPayments = useCallback(async () => {
    if (!salesOrderId || !activeOrganizationId) {
      setPayments([]);
      return;
    }
    setLoading(true);
    try {
      // 1) Payments directly linked to this SO
      const { data: directData, error: directError } = await supabase
        .from('Payments')
        .select('id, amount, payment_method, reference_number, payment_date, notes, recorded_by, recorded_by_name, created_at, bank_name, description')
        .eq('organization_id', activeOrganizationId)
        .eq('sales_order_id', salesOrderId)
        .eq('deleted', false)
        .order('payment_date', { ascending: false });
      if (directError) throw directError;

      // 2) Payments related to invoices of this SO (even if payment.sales_order_id is null/other)
      const { data: soInvoices, error: soInvoicesError } = await supabase
        .from('DealerInvoices')
        .select('id')
        .eq('organization_id', activeOrganizationId)
        .eq('sales_order_id', salesOrderId)
        .eq('deleted', false);
      const soInvoiceIds = soInvoicesError
        ? []
        : ((soInvoices ?? []) as Array<{ id: string }>).map((row) => row.id);
      let relatedRows: Payment[] = [];
      if (soInvoiceIds.length > 0) {
        const { data: soApplications, error: soApplicationsError } = await supabase
          .from('PaymentApplications')
          .select('payment_id')
          .in('invoice_id', soInvoiceIds);
        if (!soApplicationsError) {
          const relatedPaymentIds = Array.from(
            new Set(
              ((soApplications ?? []) as Array<{ payment_id: string | null }>)
                .map((row) => row.payment_id)
                .filter((id): id is string => Boolean(id))
            )
          );

          if (relatedPaymentIds.length > 0) {
            const { data: relatedData, error: relatedError } = await supabase
              .from('Payments')
              .select('id, amount, payment_method, reference_number, payment_date, notes, recorded_by, recorded_by_name, created_at, bank_name, description')
              .eq('organization_id', activeOrganizationId)
              .in('id', relatedPaymentIds)
              .eq('deleted', false)
              .order('payment_date', { ascending: false });
            if (!relatedError) {
              relatedRows = (relatedData ?? []) as Payment[];
            }
          }
        }
      }

      const dedupedRowsById = new Map<string, Payment>();
      ([...((directData ?? []) as Payment[]), ...relatedRows]).forEach((row) => {
        dedupedRowsById.set(row.id, row);
      });
      const rows = Array.from(dedupedRowsById.values()).sort(
        (a, b) => new Date(b.payment_date || b.created_at).getTime() - new Date(a.payment_date || a.created_at).getTime()
      );
      if (rows.length === 0) {
        setPayments([]);
        return;
      }

      try {
        const paymentIds = rows.map((p) => p.id);
        const missingRecordedByIds = rows
          .filter((p) => !p.recorded_by_name && p.recorded_by)
          .map((p) => p.recorded_by as string);
        const appUserNameMap = await getAppUsersDisplayNames(missingRecordedByIds);

        const { data: applicationsData } = await supabase
          .from('PaymentApplications')
          .select('payment_id, invoice_id')
          .in('payment_id', paymentIds);

        const invoiceIds = Array.from(
          new Set(
            ((applicationsData ?? []) as Array<{ payment_id: string; invoice_id: string | null }>)
              .map((row) => row.invoice_id)
              .filter((id): id is string => Boolean(id))
          )
        );
        const { data: invoicesData } = invoiceIds.length > 0
          ? await supabase
              .from('DealerInvoices')
              .select('id, invoice_number')
              .eq('organization_id', activeOrganizationId)
              .in('id', invoiceIds)
          : { data: [] as Array<{ id: string; invoice_number: string }> };

        const invoiceNumberById = new Map<string, string>(
          ((invoicesData ?? []) as Array<{ id: string; invoice_number: string }>).map((inv) => [inv.id, inv.invoice_number])
        );

        const invoiceRefsByPaymentId = new Map<string, PaymentInvoiceRef[]>();
        ((applicationsData ?? []) as Array<{ payment_id: string; invoice_id: string | null }>).forEach((app) => {
          if (!app.invoice_id) return;
          const invoiceNumber = invoiceNumberById.get(app.invoice_id);
          if (!invoiceNumber) return;
          const list = invoiceRefsByPaymentId.get(app.payment_id) ?? [];
          if (!list.some((ref) => ref.invoice_id === app.invoice_id)) {
            list.push({ invoice_id: app.invoice_id, invoice_number: invoiceNumber });
            invoiceRefsByPaymentId.set(app.payment_id, list);
          }
        });

        const enrichedRows = rows.map((row) => ({
          ...row,
          recorded_by_display_name:
            row.recorded_by_name?.trim() ||
            (row.recorded_by ? appUserNameMap.get(row.recorded_by) : undefined) ||
            '—',
          invoice_refs: invoiceRefsByPaymentId.get(row.id) ?? [],
        }));

        setPayments(enrichedRows);
      } catch {
        // Keep payments visible even if enrichment fails.
        setPayments(
          rows.map((row) => ({
            ...row,
            recorded_by_display_name: row.recorded_by_name?.trim() || '—',
            invoice_refs: [],
          }))
        );
      }
    } catch {
      setPayments([]);
    } finally {
      setLoading(false);
    }
  }, [salesOrderId, activeOrganizationId]);

  useEffect(() => {
    void fetchPayments();
  }, [fetchPayments]);

  return { payments, loading, refetch: fetchPayments };
}

export function useRecordPayment() {
  useOrganizationContext();
  const [isRecording, setIsRecording] = useState(false);
  const addNotification = useUIStore((s) => s.addNotification);

  const recordPayment = useCallback(
    async (
      soId: string,
      amount: number,
      method: string,
      reference: string,
      userId: string,
      userName?: string
    ) => {
      setIsRecording(true);
      try {
        const { data, error } = await supabase.rpc('record_payment', {
          p_so_id: soId,
          p_amount: amount,
          p_method: method,
          p_reference: reference,
          p_user_id: userId,
          p_user_name: userName ?? null,
        });
        if (error) throw error;
        addNotification({ type: 'success', title: 'Payment Recorded', message: 'Payment recorded successfully.' });
        return data;
      } catch (err: unknown) {
        const msg =
          (err && typeof err === 'object' && 'message' in err && typeof (err as { message: unknown }).message === 'string')
            ? (err as { message: string }).message
            : err instanceof Error
              ? err.message
              : 'Failed to record payment';
        addNotification({ type: 'error', title: 'Error', message: msg });
        throw err;
      } finally {
        setIsRecording(false);
      }
    },
    [addNotification]
  );

  return { recordPayment, isRecording };
}

export interface RecordPaymentForSOParams {
  salesOrderId: string;
  dealerId: string | null;
  organizationId: string;
  amount: number;
  method: string;
  reference: string;
  paymentDate: string;
  bankName?: string | null;
  description?: string | null;
  userId: string | null;
  userName?: string | null;
}

export function useRecordPaymentForSO() {
  const { activeOrganizationId } = useOrganizationContext();
  const [isRecording, setIsRecording] = useState(false);
  const addNotification = useUIStore((s) => s.addNotification);

  const recordPaymentForSO = useCallback(
    async (
      params: RecordPaymentForSOParams,
      onSuccess?: () => void
    ): Promise<{ id: string } | null> => {
      const orgId = params.organizationId || activeOrganizationId;
      if (!orgId) {
        addNotification({ type: 'error', title: 'Error', message: 'Organization context required.' });
        return null;
      }
      setIsRecording(true);
      try {
        const { data, error } = await supabase
          .from('Payments')
          .insert({
            organization_id: orgId,
            sales_order_id: params.salesOrderId,
            dealer_id: params.dealerId || null,
            amount: params.amount,
            payment_method: params.method,
            reference_number: params.reference.trim() || null,
            payment_date: params.paymentDate,
            bank_name: params.bankName?.trim() || null,
            description: params.description?.trim() || null,
            recorded_by: params.userId,
            recorded_by_name: params.userName ?? null,
            deleted: false,
          })
          .select('id')
          .single();
        if (error) throw error;
        addNotification({ type: 'success', title: 'Payment Recorded', message: 'Payment recorded successfully.' });
        onSuccess?.();
        return data as { id: string };
      } catch (err: unknown) {
        const msg =
          (err && typeof err === 'object' && 'message' in err && typeof (err as { message: unknown }).message === 'string')
            ? (err as { message: string }).message
            : err instanceof Error
              ? err.message
              : 'Failed to record payment';
        addNotification({ type: 'error', title: 'Error', message: msg });
        throw err;
      } finally {
        setIsRecording(false);
      }
    },
    [activeOrganizationId, addNotification]
  );

  return { recordPaymentForSO, isRecording };
}
