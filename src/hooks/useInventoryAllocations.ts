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
      queryClient.invalidateQueries({ queryKey: ['material-demand', orgId] });
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
      queryClient.invalidateQueries({ queryKey: ['material-demand'] });
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

export interface MOMaterialSubstituteCandidate {
  catalog_item_id: string;
  sku: string;
  name: string;
  measure_basis: string;
  part_roles: string[] | null;
  /** parent | child | fabric | parent+child | role — from RPC slot fingerprint */
  slot_hierarchy: string | null;
  unit_cost: number;
  available_qty: number;
  on_hand_qty: number;
  uom: string;
}

export interface MOMaterialSubstitutionRow {
  id: string;
  bom_instance_line_id: string;
  original_catalog_item_id: string;
  substitute_catalog_item_id: string;
  qty: number;
  original_unit_cost: number | null;
  substitute_unit_cost: number | null;
  created_at: string;
  original_sku: string | null;
  original_name: string | null;
}

const SUBSTITUTIONS_KEY = 'mo-material-substitutions';

/** Latest substitution audit rows for an MO (for badges / tooltips). */
export function useMOMaterialSubstitutions(moId: string | null) {
  const { data, isLoading, refetch } = useQuery({
    queryKey: [SUBSTITUTIONS_KEY, moId],
    queryFn: async (): Promise<MOMaterialSubstitutionRow[]> => {
      if (!moId) return [];
      const { data: rows, error } = await supabase
        .from('MOMaterialSubstitutions')
        .select(`
          id,
          bom_instance_line_id,
          original_catalog_item_id,
          substitute_catalog_item_id,
          qty,
          original_unit_cost,
          substitute_unit_cost,
          created_at,
          original:CatalogItems!original_catalog_item_id ( sku, name )
        `)
        .eq('mo_id', moId)
        .order('created_at', { ascending: false });
      if (error) throw error;
      return (rows ?? []).map((r: any) => ({
        id: r.id,
        bom_instance_line_id: r.bom_instance_line_id,
        original_catalog_item_id: r.original_catalog_item_id,
        substitute_catalog_item_id: r.substitute_catalog_item_id,
        qty: Number(r.qty) || 0,
        original_unit_cost: r.original_unit_cost != null ? Number(r.original_unit_cost) : null,
        substitute_unit_cost: r.substitute_unit_cost != null ? Number(r.substitute_unit_cost) : null,
        created_at: r.created_at,
        original_sku: r.original?.sku ?? null,
        original_name: r.original?.name ?? null,
      }));
    },
    enabled: !!moId,
  });

  /** Map current (substitute) catalog_item_id → most recent original SKU info */
  const bySubstituteId = new Map<string, MOMaterialSubstitutionRow>();
  /** Map BIL id → most recent substitution (best for Line / WO / Workstation) */
  const byBomInstanceLineId = new Map<string, MOMaterialSubstitutionRow>();
  for (const row of data ?? []) {
    if (!bySubstituteId.has(row.substitute_catalog_item_id)) {
      bySubstituteId.set(row.substitute_catalog_item_id, row);
    }
    if (!byBomInstanceLineId.has(row.bom_instance_line_id)) {
      byBomInstanceLineId.set(row.bom_instance_line_id, row);
    }
  }

  return {
    substitutions: data ?? [],
    bySubstituteId,
    byBomInstanceLineId,
    loading: isLoading,
    refetch,
  };
}

export interface MOMaterialSubstituteListResult {
  candidates: MOMaterialSubstituteCandidate[];
  /** Locked roles from BIL for this SKU on the MO */
  part_roles: string[] | null;
  /** parent | child | fabric | … — slot fingerprint for the original SKU */
  slot_hierarchy: string | null;
}

export function useListMOMaterialSubstitutes(
  moId: string | null,
  originalCatalogItemId: string | null,
  warehouseId: string | null,
  enabled = true,
  /** Fallback role when list returns no candidates (still show Role · hierarchy hint) */
  fallbackPartRole?: string | null,
) {
  const { data, isLoading, refetch, error } = useQuery({
    queryKey: [SUBSTITUTIONS_KEY, 'candidates', moId, originalCatalogItemId, warehouseId, fallbackPartRole ?? ''],
    queryFn: async (): Promise<MOMaterialSubstituteListResult> => {
      if (!moId || !originalCatalogItemId || !warehouseId) {
        return { candidates: [], part_roles: null, slot_hierarchy: null };
      }
      const { data: rows, error: e } = await supabase.rpc('list_mo_material_substitutes', {
        p_mo_id: moId,
        p_original_catalog_item_id: originalCatalogItemId,
        p_warehouse_id: warehouseId,
      });
      if (e) throw e;
      const candidates: MOMaterialSubstituteCandidate[] = (rows ?? []).map((r: any) => ({
        catalog_item_id: r.catalog_item_id,
        sku: r.sku ?? '',
        name: r.name ?? '',
        measure_basis: r.measure_basis ?? '',
        part_roles: r.part_roles ?? null,
        slot_hierarchy: r.slot_hierarchy ?? null,
        unit_cost: Number(r.unit_cost) || 0,
        available_qty: Number(r.available_qty) || 0,
        on_hand_qty: Number(r.on_hand_qty) || 0,
        uom: r.uom ?? 'ea',
      }));

      let part_roles = candidates[0]?.part_roles ?? null;
      let slot_hierarchy = candidates[0]?.slot_hierarchy ?? null;

      if (!slot_hierarchy || !part_roles?.length) {
        const role = part_roles?.[0] || fallbackPartRole?.trim() || null;
        if (role) {
          const { data: mo } = await supabase
            .from('ManufacturingOrders')
            .select('organization_id')
            .eq('id', moId)
            .maybeSingle();
          const orgId = (mo as { organization_id?: string } | null)?.organization_id;
          if (orgId) {
            if (!part_roles?.length) part_roles = [role];
            if (!slot_hierarchy) {
              const { data: slot } = await supabase.rpc('_mo_substitute_slot_label', {
                p_org_id: orgId,
                p_catalog_item_id: originalCatalogItemId,
                p_part_role: role,
              });
              if (typeof slot === 'string' && slot) slot_hierarchy = slot;
            }
          }
        }
      }

      return { candidates, part_roles, slot_hierarchy };
    },
    enabled: enabled && !!moId && !!originalCatalogItemId && !!warehouseId,
  });

  return {
    candidates: data?.candidates ?? [],
    part_roles: data?.part_roles ?? null,
    slot_hierarchy: data?.slot_hierarchy ?? null,
    loading: isLoading,
    error: error ? (error as Error).message : null,
    refetch,
  };
}

export function useSubstituteMOMaterial() {
  const [isSubstituting, setIsSubstituting] = useState(false);
  const queryClient = useQueryClient();

  const substitute = useCallback(async (params: {
    moId: string;
    warehouseId: string;
    originalCatalogItemId: string;
    substituteCatalogItemId: string;
    bomInstanceLineIds?: string[];
    reason?: string;
  }) => {
    setIsSubstituting(true);
    try {
      const { data, error } = await supabase.rpc('substitute_mo_material', {
        p_mo_id: params.moId,
        p_warehouse_id: params.warehouseId,
        p_original_catalog_item_id: params.originalCatalogItemId,
        p_substitute_catalog_item_id: params.substituteCatalogItemId,
        p_bom_instance_line_ids: params.bomInstanceLineIds ?? null,
        p_reason: params.reason ?? null,
      });
      if (error) throw error;
      const result = data as { ok: boolean; error?: string; lines_updated?: number; allocated_qty?: number };
      if (!result?.ok) throw new Error(result?.error ?? 'Substitution failed');
      queryClient.invalidateQueries({ queryKey: [ALLOCATIONS_KEY] });
      queryClient.invalidateQueries({ queryKey: [FULFILLMENT_KEY] });
      queryClient.invalidateQueries({ queryKey: [SUBSTITUTIONS_KEY] });
      queryClient.invalidateQueries({ queryKey: ['material-demand'] });
      return result;
    } finally {
      setIsSubstituting(false);
    }
  }, [queryClient]);

  return { substitute, isSubstituting };
}
