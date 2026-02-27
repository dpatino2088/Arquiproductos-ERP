import { useCallback, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface FulfillmentRow {
  catalog_item_id: string;
  sku: string;
  item_name: string;
  part_role: string;
  manufacturer_id: string | null;
  manufacturer_name: string;
  required_qty: number;
  uom: string;
  on_hand_qty: number;
  allocated_qty: number;
  on_order_qty: number;
  available_qty: number;
  shortage: number;
  purchase_unit: string;
  units_per_purchase_unit: number;
  fulfillment_status: 'fulfilled' | 'partial' | 'shortage';
}

const FULFILLMENT_KEY = 'so-fulfillment';
const ALLOCATIONS_KEY = 'inventory-allocations';

export function useSOFulfillment(salesOrderId: string | null) {
  const { data, isLoading, error, refetch } = useQuery({
    queryKey: [FULFILLMENT_KEY, salesOrderId],
    queryFn: async (): Promise<FulfillmentRow[]> => {
      if (!salesOrderId) return [];
      const { data: rows, error: e } = await supabase.rpc('get_so_fulfillment_status', {
        p_sales_order_id: salesOrderId,
      });
      if (e) throw e;
      return (rows ?? []) as FulfillmentRow[];
    },
    enabled: !!salesOrderId,
  });

  return {
    fulfillment: data ?? [],
    loading: isLoading,
    error: error ? (error as Error).message : null,
    refetch,
  };
}

export function useAllocateInventory() {
  const [isAllocating, setIsAllocating] = useState(false);
  const queryClient = useQueryClient();

  const allocate = useCallback(async (
    orgId: string,
    warehouseId: string,
    salesOrderId: string,
    items: { catalog_item_id: string; qty: number }[]
  ) => {
    setIsAllocating(true);
    try {
      const { data, error } = await supabase.rpc('allocate_inventory_to_so', {
        p_org_id: orgId,
        p_warehouse_id: warehouseId,
        p_sales_order_id: salesOrderId,
        p_items: items,
      });
      if (error) throw error;
      queryClient.invalidateQueries({ queryKey: [FULFILLMENT_KEY] });
      queryClient.invalidateQueries({ queryKey: [ALLOCATIONS_KEY] });
      queryClient.invalidateQueries({ queryKey: ['inventory-movements'] });
      return data as { ok: boolean; results: { catalog_item_id: string; ok: boolean; allocated_qty?: number; error?: string }[] };
    } finally {
      setIsAllocating(false);
    }
  }, [queryClient]);

  return { allocate, isAllocating };
}

export function useReleaseAllocation() {
  const [isReleasing, setIsReleasing] = useState(false);
  const queryClient = useQueryClient();

  const release = useCallback(async (allocationId: string) => {
    setIsReleasing(true);
    try {
      const { data, error } = await supabase.rpc('release_allocation', {
        p_allocation_id: allocationId,
      });
      if (error) throw error;
      queryClient.invalidateQueries({ queryKey: [FULFILLMENT_KEY] });
      queryClient.invalidateQueries({ queryKey: [ALLOCATIONS_KEY] });
      return data as { ok: boolean; error?: string };
    } finally {
      setIsReleasing(false);
    }
  }, [queryClient]);

  return { release, isReleasing };
}

export function useSOFulfillmentSummary(salesOrderId: string | null) {
  const { fulfillment, loading } = useSOFulfillment(salesOrderId);

  const summary = {
    total: fulfillment.length,
    fulfilled: fulfillment.filter(r => r.fulfillment_status === 'fulfilled').length,
    partial: fulfillment.filter(r => r.fulfillment_status === 'partial').length,
    shortage: fulfillment.filter(r => r.fulfillment_status === 'shortage').length,
    totalRequired: fulfillment.reduce((s, r) => s + Number(r.required_qty), 0),
    totalAllocated: fulfillment.reduce((s, r) => s + Number(r.allocated_qty), 0),
    totalOnOrder: fulfillment.reduce((s, r) => s + Number(r.on_order_qty), 0),
    totalShortage: fulfillment.reduce((s, r) => s + Number(r.shortage), 0),
  };

  const overallStatus: 'fulfilled' | 'partial' | 'shortage' =
    summary.shortage > 0 ? 'shortage' :
    summary.partial > 0 ? 'partial' : 'fulfilled';

  return { summary, overallStatus, loading };
}
