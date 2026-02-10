import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useActiveDealer } from './useActiveDealer';

/**
 * SalesOrder shape canónico para UI
 */
export interface SalesOrder {
  id: string;
  organization_id: string;
  dealer_id: string;
  quote_id: string;
  sales_order_no: string;
  tracking_status: string;
  workflow_status?: string;
  total?: number;
  currency?: string;
  deleted: boolean;
  created_at: string;
  updated_at: string;
  Quotes?: {
    id: string;
    quote_no: string;
    dealer_id: string;
  };
  DirectoryCustomers?: {
    id: string;
    customer_name: string;
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
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();
  const { activeDealerId } = useActiveDealer();

  const effectiveDealerId = dealerId ?? activeDealerId;

  const refetch = useCallback(() => {
    setRefreshTrigger(prev => prev + 1);
  }, []);

  useEffect(() => {
    async function fetchSalesOrders() {
      if (!activeOrganizationId) {
        setLoading(false);
        setSalesOrders([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

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

        if (queryError) {
          console.error('[useSalesOrders] Error fetching SalesOrders:', queryError);
          throw queryError;
        }

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
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading sales orders';
        console.error('[useSalesOrders] Error:', errorMessage);
        setError(errorMessage);
        setSalesOrders([]);
      } finally {
        setLoading(false);
      }
    }

    fetchSalesOrders();
  }, [activeOrganizationId, effectiveDealerId, refreshTrigger]);

  return { salesOrders, loading, error, refetch };
}
