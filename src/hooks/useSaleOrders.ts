import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export type SaleOrderStatus = 'Draft' | 'Confirmed' | 'Scheduled for Production' | 'In Production' | 'Ready for Delivery' | 'Delivered' | 'Cancelled';

export interface SaleOrder {
  id: string;
  organization_id: string;
  quote_id: string;
  customer_id: string;
  sale_order_no: string;
  status: SaleOrderStatus;
  currency: string;
  subtotal: number;
  tax: number;
  discount_amount: number;
  total: number;
  notes?: string | null;
  order_date: string;
  requested_delivery_date?: string | null;
  actual_delivery_date?: string | null;
  created_at: string;
  updated_at: string;
  deleted: boolean;
  archived: boolean;
  created_by?: string | null;
  updated_by?: string | null;
  DirectoryCustomers?: {
    id: string;
    customer_name: string;
  };
  Quotes?: {
    id: string;
    quote_no: string;
  };
}

export interface SaleOrderLine {
  id: string;
  organization_id: string;
  sales_order_id: string;
  quote_line_id?: string | null;
  catalog_item_id: string;
  line_number: number;
  description?: string | null;
  qty: number;
  unit_price?: number | null;
  discount_percentage?: number | null;
  discount_amount?: number | null;
  line_total?: number | null;
  // ✅ Pricing fields (copied from QuoteLines)
  list_unit_price_snapshot?: number | null; // MSRP Sale Out (PVP)
  unit_price_snapshot?: number | null; // Net price with tier discount
  unit_cost_snapshot?: number | null;
  total_unit_cost_snapshot?: number | null;
  computed_qty?: number | null;
  discount_pct_used?: number | null; // Tier discount percentage
  customer_type_snapshot?: string | null; // Customer tier (VIP, Partner, Reseller, Distributor)
  price_basis?: string | null;
  margin_pct_used?: number | null;
  measure_basis_snapshot?: string | null;
  width_m?: number | null;
  height_m?: number | null;
  area?: string | null;
  position?: string | null;
  collection_name?: string | null;
  variant_name?: string | null;
  product_type?: string | null;
  product_type_id?: string | null;
  drive_type?: string | null;
  bottom_rail_type?: string | null;
  cassette?: boolean | null;
  cassette_type?: string | null;
  side_channel?: boolean | null;
  side_channel_type?: string | null;
  hardware_color?: string | null;
  created_at: string;
  updated_at: string;
  deleted: boolean;
  archived: boolean;
  CatalogItems?: {
    id: string;
    item_name: string;
    sku: string;
  };
}

export function useSaleOrders() {
  const [saleOrders, setSaleOrders] = useState<SaleOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchSaleOrders() {
      if (!activeOrganizationId) {
        setLoading(false);
        setSaleOrders([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        // Query with JOINs (DirectoryCustomers and Quotes)
        const { data, error: queryError } = await supabase
          .from('SalesOrders')
          .select(`
            *,
            DirectoryCustomers:customer_id (
              id,
              customer_name
            ),
            Quotes:quote_id (
              id,
              quote_no
            )
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: false });

        if (queryError) {
          console.error('[useSaleOrders] Error fetching SalesOrders:', queryError);
          throw queryError;
        }

        setSaleOrders(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading sale orders';
        console.error('[useSaleOrders] Error:', errorMessage);
        setError(errorMessage);
        setSaleOrders([]);
      } finally {
        setLoading(false);
      }
    }

    fetchSaleOrders();
  }, [activeOrganizationId, refreshTrigger]);

  return { saleOrders, loading, error, refetch };
}

export function useSaleOrderLines(saleOrderId: string | null) {
  const [lines, setLines] = useState<SaleOrderLine[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchLines() {
      if (!activeOrganizationId || !saleOrderId) {
        setLoading(false);
        setLines([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('SalesOrderLines')
          .select(`
            *,
            CatalogItems:catalog_item_id (
              id,
              item_name,
              sku
            )
          `)
          .eq('sales_order_id', saleOrderId)
          .eq('deleted', false)
          .order('line_number', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching SaleOrderLines:', queryError.message);
          }
          throw queryError;
        }

        setLines(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading sale order lines';
        if (import.meta.env.DEV) {
          console.error('Error fetching SaleOrderLines:', err instanceof Error ? err.message : String(err));
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchLines();
  }, [activeOrganizationId, saleOrderId, refreshTrigger]);

  return { lines, loading, error, refetch };
}

export function useUpdateSaleOrder() {
  const [isUpdating, setIsUpdating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const updateSaleOrder = async (id: string, saleOrderData: Partial<SaleOrder>) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsUpdating(true);
    try {
      const { data, error } = await supabase
        .from('SalesOrders')
        .update(saleOrderData)
        .eq('id', id)
        .eq('organization_id', activeOrganizationId)
        .select()
        .single();

      if (error) {
        if (import.meta.env.DEV) {
          console.error('Error updating sale order:', error.message);
        }
        throw error;
      }
      
      if (!data) {
        throw new Error('Sale order not found or you do not have permission to update it');
      }
      
      return data;
    } finally {
      setIsUpdating(false);
    }
  };

  return { updateSaleOrder, isUpdating };
}

