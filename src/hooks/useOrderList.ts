import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useActiveCompany } from './useActiveCompany';

/**
 * OrderList shape canónico para UI
 */
export interface OrderList {
  id: string;
  organization_id: string;
  company_id: string; // Requerido en nuevo schema (a través de SalesOrders -> Quotes)
  sales_order_id: string;
  tracking_status: string;
  deleted: boolean;
  created_at: string;
  updated_at: string;
  SalesOrders?: {
    id: string;
    sales_order_no: string;
    company_id: string; // A través de Quotes
  };
}

/**
 * Hook para obtener OrderList
 * IMPORTANTE: Filtra por organization_id Y company_id (a través de SalesOrders -> Quotes)
 * 
 * @param companyId - Opcional: si se proporciona, filtra solo por ese company_id específico
 */
export function useOrderList(companyId?: string | null) {
  const [orderList, setOrderList] = useState<OrderList[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();
  const { activeCompanyId } = useActiveCompany();
  
  // Usar companyId proporcionado o el activo del hook
  const effectiveCompanyId = companyId ?? activeCompanyId;

  const refetch = useCallback(() => {
    setRefreshTrigger(prev => prev + 1);
  }, []);

  useEffect(() => {
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

        // Query: filtrar por organization_id Y company_id (si está disponible)
        let query = supabase
          .from('OrderList')
          .select(`
            *,
            SalesOrders:sales_order_id (
              id,
              sales_order_no,
              quote_id,
              Quotes:quote_id (
                company_id
              )
            )
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        // Filtrar por company_id si está disponible
        if (effectiveCompanyId) {
          // OrderList no tiene company_id directamente, filtrar a través de SalesOrders -> Quotes
          // Primero obtener Quotes con este company_id
          const { data: quotesData } = await supabase
            .from('Quotes')
            .select('id')
            .eq('organization_id', activeOrganizationId)
            .eq('company_id', effectiveCompanyId)
            .eq('deleted', false);

          if (quotesData && quotesData.length > 0) {
            const quoteIds = quotesData.map((q: { id: string }) => q.id);
            // Obtener SalesOrders para estos Quotes
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
              // No hay SalesOrders para este company, retornar vacío
              setOrderList([]);
              setLoading(false);
              return;
            }
          } else {
            // No hay Quotes para este company, retornar vacío
            setOrderList([]);
            setLoading(false);
            return;
          }
        } else {
          // Warning en DEV si hay OrderList sin company_id
          if (import.meta.env.DEV) {
            console.warn('[useOrderList] No company_id provided. OrderList without company_id (via SalesOrders -> Quotes) will be included.');
          }
        }

        const { data, error: queryError } = await query
          .order('created_at', { ascending: false });

        if (queryError) {
          console.error('[useOrderList] Error fetching OrderList:', queryError);
          throw queryError;
        }

        // Warning en DEV si hay OrderList sin company_id
        if (import.meta.env.DEV && data && data.length > 0) {
          const withoutCompanyId = data.filter((ol: any) => {
            const salesOrder = ol.SalesOrders;
            const quote = salesOrder?.Quotes;
            return !quote || !quote.company_id;
          });
          if (withoutCompanyId.length > 0) {
            console.warn('[useOrderList] Found', withoutCompanyId.length, 'OrderList without company_id (via SalesOrders -> Quotes):', withoutCompanyId.map((ol: any) => ({ id: ol.id, sales_order_id: ol.sales_order_id })));
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
  }, [activeOrganizationId, effectiveCompanyId, refreshTrigger]);

  return { orderList, loading, error, refetch };
}
