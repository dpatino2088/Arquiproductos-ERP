import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useActiveCompany } from './useActiveCompany';

/**
 * SalesOrder shape canónico para UI
 */
export interface SalesOrder {
  id: string;
  organization_id: string;
  company_id: string; // Requerido en nuevo schema
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
    company_id: string;
  };
  DirectoryCustomers?: {
    id: string;
    customer_name: string;
  };
}

/**
 * Hook para obtener SalesOrders
 * IMPORTANTE: Filtra por organization_id Y company_id
 * 
 * @param companyId - Opcional: si se proporciona, filtra solo por ese company_id específico
 */
export function useSalesOrders(companyId?: string | null) {
  const [salesOrders, setSalesOrders] = useState<SalesOrder[]>([]);
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

        // Query: filtrar por organization_id Y company_id (si está disponible)
        let query = supabase
          .from('SalesOrders')
          .select(`
            *,
            Quotes:quote_id (
              id,
              quote_no,
              company_id
            ),
            DirectoryCustomers:customer_id (
              id,
              customer_name
            )
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        // Filtrar por company_id si está disponible
        if (effectiveCompanyId) {
          // SalesOrders no tiene company_id directamente, filtrar a través de Quotes
          // Primero obtener Quotes con este company_id
          const { data: quotesData } = await supabase
            .from('Quotes')
            .select('id')
            .eq('organization_id', activeOrganizationId)
            .eq('company_id', effectiveCompanyId)
            .eq('deleted', false);

          if (quotesData && quotesData.length > 0) {
            const quoteIds = quotesData.map((q: { id: string }) => q.id);
            query = query.in('quote_id', quoteIds);
          } else {
            // No hay Quotes para este company, retornar vacío
            setSalesOrders([]);
            setLoading(false);
            return;
          }
        } else {
          // Warning en DEV si hay SalesOrders sin company_id (a través de Quotes)
          if (import.meta.env.DEV) {
            console.warn('[useSalesOrders] No company_id provided. SalesOrders without company_id (via Quotes) will be included.');
          }
        }

        const { data, error: queryError } = await query
          .order('created_at', { ascending: false });

        if (queryError) {
          console.error('[useSalesOrders] Error fetching SalesOrders:', queryError);
          throw queryError;
        }

        // Warning en DEV si hay SalesOrders sin company_id
        if (import.meta.env.DEV && data && data.length > 0) {
          const withoutCompanyId = data.filter((so: any) => {
            const quote = so.Quotes;
            return !quote || !quote.company_id;
          });
          if (withoutCompanyId.length > 0) {
            console.warn('[useSalesOrders] Found', withoutCompanyId.length, 'SalesOrders without company_id (via Quotes):', withoutCompanyId.map((so: any) => ({ id: so.id, sales_order_no: so.sales_order_no })));
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
  }, [activeOrganizationId, effectiveCompanyId, refreshTrigger]);

  return { salesOrders, loading, error, refetch };
}
