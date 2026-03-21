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

export interface MOAllocationRow {
  id: string;
  catalog_item_id: string;
  sku: string | null;
  item_name: string | null;
  allocated_qty: number;
  status: string;
  allocated_at: string;
}

export function useMOAllocations(manufacturingOrderId: string | null) {
  const { activeOrganizationId } = useOrganizationContext();

  const { data, isLoading, refetch } = useQuery({
    queryKey: [ALLOCATIONS_KEY, 'mo', manufacturingOrderId],
    queryFn: async (): Promise<MOAllocationRow[]> => {
      if (!manufacturingOrderId) return [];
      const { data: rows, error } = await supabase
        .from('InventoryAllocations')
        .select('id, catalog_item_id, allocated_qty, status, allocated_at, CatalogItems:catalog_item_id(sku, name)')
        .eq('manufacturing_order_id', manufacturingOrderId)
        .eq('status', 'reserved')
        .order('allocated_at', { ascending: true });
      if (error) throw error;
      return (rows ?? []).map((r: any) => ({
        id: r.id,
        catalog_item_id: r.catalog_item_id,
        sku: r.CatalogItems?.sku ?? null,
        item_name: r.CatalogItems?.name ?? null,
        allocated_qty: Number(r.allocated_qty),
        status: r.status,
        allocated_at: r.allocated_at,
      }));
    },
    enabled: !!manufacturingOrderId && !!activeOrganizationId,
  });

  return { allocations: data ?? [], loading: isLoading, refetch };
}

export function useAllocateToMO() {
  const [isAllocating, setIsAllocating] = useState(false);
  const queryClient = useQueryClient();

  const allocate = useCallback(async (
    orgId: string,
    warehouseId: string,
    manufacturingOrderId: string,
    items: { catalog_item_id: string; qty: number }[]
  ) => {
    setIsAllocating(true);
    try {
      const { data, error } = await supabase.rpc('allocate_inventory_to_mo', {
        p_org_id: orgId,
        p_warehouse_id: warehouseId,
        p_manufacturing_order_id: manufacturingOrderId,
        p_items: items,
      });
      if (error) throw error;
      queryClient.invalidateQueries({ queryKey: [ALLOCATIONS_KEY] });
      queryClient.invalidateQueries({ queryKey: [FULFILLMENT_KEY] });
      return data as { ok: boolean; results: any[] };
    } finally {
      setIsAllocating(false);
    }
  }, [queryClient]);

  return { allocate, isAllocating };
}

export function useReleaseMOAllocation() {
  const [isReleasing, setIsReleasing] = useState(false);
  const queryClient = useQueryClient();

  const release = useCallback(async (
    manufacturingOrderId: string,
    catalogItemId?: string
  ) => {
    setIsReleasing(true);
    try {
      const { data, error } = await supabase.rpc('release_mo_allocation', {
        p_manufacturing_order_id: manufacturingOrderId,
        p_catalog_item_id: catalogItemId ?? null,
      });
      if (error) throw error;
      queryClient.invalidateQueries({ queryKey: [ALLOCATIONS_KEY] });
      queryClient.invalidateQueries({ queryKey: [FULFILLMENT_KEY] });
      return data as { ok: boolean; released_count: number };
    } finally {
      setIsReleasing(false);
    }
  }, [queryClient]);

  return { release, isReleasing };
}

export interface MOAllocationDetail {
  manufacturing_order_id: string;
  mo_number: string;
  mo_status: string;
  priority: string;
  product_name: string;
  customer_name: string;
  due_date: string | null;
  allocated_qty: number;
  warehouse_id: string;
  is_current: boolean;
}

/** @deprecated Use useAllMOAllocationsForItem instead */
export type OtherMOAllocation = MOAllocationDetail;

export function useAllMOAllocationsForItem(catalogItemId: string | null, currentMoId: string | null, orgId: string | null) {
  const { data, isLoading, refetch } = useQuery({
    queryKey: [ALLOCATIONS_KEY, 'all-mos-for-item', catalogItemId, currentMoId],
    queryFn: async (): Promise<MOAllocationDetail[]> => {
      if (!catalogItemId || !orgId) return [];
      const { data: rows, error } = await supabase
        .from('InventoryAllocations')
        .select(`
          manufacturing_order_id, allocated_qty, warehouse_id,
          ManufacturingOrders:manufacturing_order_id (
            manufacturing_order_no, status, priority, product_name,
            SalesOrders:sales_order_id (
              expected_delivery_date,
              DirectoryCustomers:customer_id ( customer_name )
            )
          )
        `)
        .eq('catalog_item_id', catalogItemId)
        .eq('organization_id', orgId)
        .eq('status', 'reserved')
        .not('manufacturing_order_id', 'is', null);

      if (error) throw error;

      const grouped = new Map<string, MOAllocationDetail>();
      for (const r of (rows ?? []) as any[]) {
        const moId = r.manufacturing_order_id as string;
        const mo = r.ManufacturingOrders;
        const existing = grouped.get(moId);
        if (existing) {
          existing.allocated_qty += Number(r.allocated_qty);
        } else {
          grouped.set(moId, {
            manufacturing_order_id: moId,
            mo_number: mo?.manufacturing_order_no ?? '—',
            mo_status: mo?.status ?? 'unknown',
            priority: mo?.priority ?? 'normal',
            product_name: mo?.product_name ?? '—',
            customer_name: mo?.SalesOrders?.DirectoryCustomers?.customer_name ?? '—',
            due_date: mo?.SalesOrders?.expected_delivery_date ?? null,
            allocated_qty: Number(r.allocated_qty),
            warehouse_id: r.warehouse_id,
            is_current: moId === currentMoId,
          });
        }
      }
      const priorityOrder: Record<string, number> = { urgent: 0, high: 1, normal: 2, low: 3 };
      return [...grouped.values()].sort((a, b) => {
        if (a.is_current) return -1;
        if (b.is_current) return 1;
        return (priorityOrder[a.priority] ?? 2) - (priorityOrder[b.priority] ?? 2);
      });
    },
    enabled: !!catalogItemId && !!orgId,
  });

  return { moAllocations: data ?? [], loading: isLoading, refetch };
}

/** @deprecated Use useAllMOAllocationsForItem */
export function useOtherMOAllocations(catalogItemId: string | null, excludeMoId: string | null, orgId: string | null) {
  const { moAllocations, loading, refetch } = useAllMOAllocationsForItem(catalogItemId, excludeMoId, orgId);
  return {
    otherAllocations: moAllocations.filter(a => !a.is_current),
    loading,
    refetch,
  };
}

export function useTransferAllocation() {
  const [isTransferring, setIsTransferring] = useState(false);
  const queryClient = useQueryClient();

  const transfer = useCallback(async (
    sourceMoId: string,
    targetMoId: string,
    catalogItemId: string,
    qty: number,
    orgId: string,
    warehouseId: string
  ) => {
    setIsTransferring(true);
    try {
      const { data, error } = await supabase.rpc('transfer_mo_allocation', {
        p_source_mo_id: sourceMoId,
        p_target_mo_id: targetMoId,
        p_catalog_item_id: catalogItemId,
        p_qty: qty,
        p_org_id: orgId,
        p_warehouse_id: warehouseId,
      });
      if (error) throw error;
      const result = data as { ok: boolean; transferred_qty?: number; error?: string };
      if (!result.ok) throw new Error(result.error ?? 'Transfer failed');
      queryClient.invalidateQueries({ queryKey: [ALLOCATIONS_KEY] });
      queryClient.invalidateQueries({ queryKey: [FULFILLMENT_KEY] });
      return result;
    } finally {
      setIsTransferring(false);
    }
  }, [queryClient]);

  return { transfer, isTransferring };
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
