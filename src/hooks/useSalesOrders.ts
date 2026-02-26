import { useState, useEffect, useCallback, useRef } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useDealerScope } from './useDealerScope';

/**
 * SalesOrder shape canónico para UI
 */
export interface SalesOrder {
  id: string;
  organization_id: string;
  dealer_id?: string;
  quote_id: string;
  sales_order_no: string;
  status?: string;
  tracking_status?: string;
  workflow_status?: string;
  priority?: string;
  total?: number;
  total_amount?: number;
  notes?: string;
  currency?: string;
  deleted: boolean;
  created_at: string;
  updated_at: string;
  archived?: boolean;
  customer_id?: string;
  Quotes?: {
    id: string;
    quote_no: string;
    dealer_id: string;
  };
  DirectoryCustomers?: {
    id: string;
    customer_name: string;
  };
  Dealers?: {
    dealer_name: string;
    dealer_no?: string | null;
  };
}

/**
 * Hook para obtener SalesOrders
 * Filtra por organization_id Y dealer_id (vía Quotes)
 *
 * @param dealerId - Opcional: filtra solo por ese dealer_id
 */
export function useSalesOrders(dealerId?: string | null) {
  const [salesOrders, setSalesOrders] = useState<SalesOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();
  const { scopeKey, activeDealerId, effectiveDealerId: scopeEffectiveDealerId } = useDealerScope();
  const effectiveDealerId = dealerId ?? scopeEffectiveDealerId ?? activeDealerId;
  const fetchSalesOrdersRef = useRef<(signal?: AbortSignal) => Promise<void>>(null!);

  const fetchSalesOrders = useCallback(async (signal?: AbortSignal) => {
    if (!activeOrganizationId) {
      setLoading(false);
      setSalesOrders([]);
      setError(null);
      return;
    }
    if (signal?.aborted) return;

    setLoading(true);
    setError(null);

    try {
      let query = supabase
        .from('SalesOrders')
        .select(`
          *,
          Quotes:quote_id (
            id,
            quote_no,
            dealer_id
          ),
          DirectoryCustomers:customer_id (
            id,
            customer_name
          ),
          Dealers:dealer_id (
            dealer_name,
            dealer_no
          )
        `)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false);

      if (effectiveDealerId) {
        const { data: quotesData } = await supabase
          .from('Quotes')
          .select('id')
          .eq('organization_id', activeOrganizationId)
          .eq('dealer_id', effectiveDealerId)
          .eq('deleted', false);

        if (signal?.aborted) return;

        if (quotesData && quotesData.length > 0) {
          const quoteIds = quotesData.map((q: { id: string }) => q.id);
          query = query.in('quote_id', quoteIds);
        } else {
          setSalesOrders([]);
          setLoading(false);
          return;
        }
      } else {
        if (import.meta.env.DEV) {
          console.warn('[useSalesOrders] No dealer_id provided. SalesOrders without dealer_id (via Quotes) will be included.');
        }
      }

      const { data, error: queryError } = await query
        .order('created_at', { ascending: false });

      if (queryError) throw queryError;
      if (signal?.aborted) return;

      if (import.meta.env.DEV && data && data.length > 0) {
        const withoutDealerId = data.filter((so: any) => {
          const quote = so.Quotes;
          return !quote || !quote.dealer_id;
        });
        if (withoutDealerId.length > 0) {
          console.warn('[useSalesOrders] Found', withoutDealerId.length, 'SalesOrders without dealer_id (via Quotes):', withoutDealerId.map((so: any) => ({ id: so.id, sales_order_no: so.sales_order_no })));
        }
      }

      setSalesOrders(data || []);
    } catch (err: any) {
      if (err?.name === 'AbortError') return;
      const errorMessage = err instanceof Error ? err.message : 'Error loading sales orders';
      console.error('[useSalesOrders] Error:', errorMessage);
      setError(errorMessage);
      setSalesOrders([]);
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId, effectiveDealerId]);

  fetchSalesOrdersRef.current = fetchSalesOrders;

  const refetch = useCallback(() => {
    fetchSalesOrdersRef.current();
  }, []);

  useEffect(() => {
    const ctrl = new AbortController();
    fetchSalesOrdersRef.current(ctrl.signal);

    return () => {
      ctrl.abort();
    };
  }, [scopeKey]);

  return { salesOrders, loading, error, refetch };
}
