import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useUIStore } from '../stores/ui-store';

export interface Payment {
  id: string;
  amount: number;
  payment_method: string;
  reference_number: string | null;
  payment_date: string;
  notes: string | null;
  recorded_by: string | null;
  created_at: string;
}

export function usePayments(salesOrderId: string | null) {
  useOrganizationContext();
  const [payments, setPayments] = useState<Payment[]>([]);
  const [loading, setLoading] = useState(false);

  const fetchPayments = useCallback(async () => {
    if (!salesOrderId) {
      setPayments([]);
      return;
    }
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('Payments')
        .select('id, amount, payment_method, reference_number, payment_date, notes, recorded_by, created_at')
        .eq('sales_order_id', salesOrderId)
        .eq('deleted', false)
        .order('payment_date', { ascending: false });
      if (error) throw error;
      setPayments((data ?? []) as Payment[]);
    } catch {
      setPayments([]);
    } finally {
      setLoading(false);
    }
  }, [salesOrderId]);

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
