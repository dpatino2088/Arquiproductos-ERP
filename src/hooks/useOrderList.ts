import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useActiveDealer } from './useActiveDealer';
import { useAccessContext } from './useAccessContext';

/**
 * OrderList shape canónico para UI
 */
export interface OrderList {
  id: string;
  organization_id: string;
  dealer_id: string;
  sales_order_id: string;
  tracking_status: string;
  deleted: boolean;
  created_at: string;
  updated_at: string;
  SalesOrders?: {
    id: string;
    sales_order_no: string;
    dealer_id: string;
  };
}

/**
 * Hook para obtener OrderList
 * Filtra por organization_id Y dealer_id (vía SalesOrders -> Quotes)
 *
 * @param dealerId - Opcional: filtra solo por ese dealer_id
 */
export function useOrderList(dealerId?: string | null) {
  const [orderList, setOrderList] = useState<OrderList[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();
  const { activeDealerId, hasHydrated } = useActiveDealer();
  const { userType } = useAccessContext();

  const effectiveDealerId = dealerId ?? activeDealerId;

  const refetch = useCallback(() => {
    setRefreshTrigger(prev => prev + 1);
  }, []);

  useEffect(() => {
    if (userType === 'internal' && !hasHydrated) return;
    async function fetchOrderList() {
      if (!activeOrganizationId) {
        setLoading(false);
        setOrderList([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        let query = supabase
          .from('OrderList')
          .select(`
            *,
            SalesOrders:sales_order_id (
              id,
              sales_order_no,
              quote_id,
              Quotes:quote_id (
                dealer_id
              )
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
            const { data: salesOrdersData } = await supabase
              .from('SalesOrders')
              .select('id')
              .eq('organization_id', activeOrganizationId)
              .in('quote_id', quoteIds)
              .eq('deleted', false);

            if (salesOrdersData && salesOrdersData.length > 0) {
              const salesOrderIds = salesOrdersData.map((so: { id: string }) => so.id);
              query = query.in('sales_order_id', salesOrderIds);
            } else {
              setOrderList([]);
              setLoading(false);
              return;
            }
          } else {
            setOrderList([]);
            setLoading(false);
            return;
          }
        } else {
          if (import.meta.env.DEV) {
            console.warn('[useOrderList] No dealer_id provided. OrderList without dealer_id (via SalesOrders -> Quotes) will be included.');
          }
        }

        const { data, error: queryError } = await query
          .order('created_at', { ascending: false });

        if (queryError) {
          console.error('[useOrderList] Error fetching OrderList:', queryError);
          throw queryError;
        }

        if (import.meta.env.DEV && data && data.length > 0) {
          const withoutDealerId = data.filter((ol: any) => {
            const salesOrder = ol.SalesOrders;
            const quote = salesOrder?.Quotes;
            return !quote || !quote.dealer_id;
          });
          if (withoutDealerId.length > 0) {
            console.warn('[useOrderList] Found', withoutDealerId.length, 'OrderList without dealer_id (via SalesOrders -> Quotes):', withoutDealerId.map((ol: any) => ({ id: ol.id, sales_order_id: ol.sales_order_id })));
          }
        }

        setOrderList(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading order list';
        console.error('[useOrderList] Error:', errorMessage);
        setError(errorMessage);
        setOrderList([]);
      } finally {
        setLoading(false);
      }
    }

    fetchOrderList();
  }, [activeOrganizationId, effectiveDealerId, refreshTrigger, userType, hasHydrated]);

  return { orderList, loading, error, refetch };
}
