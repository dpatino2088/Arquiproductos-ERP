import { useState, useCallback, useMemo } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { purchaseOrdersListKey, purchaseOrderDetailKey } from '../lib/queryKeys';
import { generateNextPurchaseOrderNumber } from '../lib/sequential-numbers';
import { resolveInventoryUnitModel, type MeasureBasis } from '../lib/inventoryUnitModel';

export type PurchaseOrderStatus = 'DRAFT' | 'OPEN' | 'PARTIAL' | 'CLOSED' | 'CANCELLED' | 'ARCHIVED';

export interface PurchaseOrder {
  id: string;
  organization_id: string;
  warehouse_id: string;
  vendor_id: string | null;
  ship_to_address_id: string | null;
  ship_to_address_snapshot: string | null;
  po_number: string | null;
  expected_date: string | null;
  status: PurchaseOrderStatus;
  billing_status: string | null;
  notes: string | null;
  subtotal: number;
  total: number;
  currency: string;
  created_at: string;
  updated_at: string;
  Warehouses?: { name: string; code: string | null } | null;
  DirectoryVendors?: { id: string; name: string } | null;
  PurchaseOrderLines?: PurchaseOrderLine[];
}

export interface PurchaseOrderLine {
  id: string;
  purchase_order_id: string;
  catalog_item_id: string | null;
  ordered_qty: number;
  received_qty: number;
  unit_cost: number;
  line_total: number;
  description: string | null;
  is_one_off: boolean;
  notes: string | null;
  unit: string | null;
  allocation_type: 'stock' | 'manufacturing_order';
  allocation_mo_id: string | null;
  allocation_notes: string | null;
  sku_snapshot?: string | null;
  item_name_snapshot?: string | null;
  purchase_unit_snapshot?: string | null;
  purchase_uom_snapshot?: string | null;
  purchase_mode_snapshot?: 'unit_packaged' | 'linear_direct' | 'roll' | null;
  stock_basis_snapshot?: 'ea' | 'linear_m' | null;
  units_per_purchase_unit_snapshot?: number | null;
  moq_snapshot?: number | null;
  unit_of_measure_snapshot?: string | null;
  is_roll_snapshot?: boolean | null;
  roll_width_value_snapshot?: number | null;
  roll_width_uom_snapshot?: string | null;
  roll_length_value_snapshot?: number | null;
  roll_length_uom_snapshot?: string | null;
  created_at: string;
  updated_at: string;
  CatalogItems?: {
    sku: string;
    name: string;
    description?: string | null;
    cost_exw?: number | null;
    unit_of_measure?: string | null;
    measure_basis?: 'unit' | 'linear' | 'area' | null;
    is_roll?: boolean | null;
    purchase_unit?: string | null;
    units_per_purchase_unit?: number | null;
    moq?: number | null;
  } | null;
}

function safeLineSubtotal(lines: { ordered_qty: number; unit_cost: number }[] | undefined): number {
  let subtotal = 0;
  if (lines) {
    for (const l of lines) {
      subtotal += (Number(l.ordered_qty) || 0) * (Number(l.unit_cost) || 0);
    }
  }
  if (!Number.isFinite(subtotal)) return 0;
  return subtotal;
}

export async function resolvePurchaseTaxPct(params: {
  organizationId: string;
  vendorId: string | null | undefined;
}): Promise<number> {
  const { organizationId, vendorId } = params;
  if (!vendorId) return 0;

  const { data: vendor } = await supabase
    .from('DirectoryVendors')
    .select('tax_rule')
    .eq('id', vendorId)
    .maybeSingle();

  if ((vendor?.tax_rule ?? 'taxable') === 'tax_exempt') return 0;

  const { data: settings } = await supabase
    .from('CostSettings')
    .select('tax_pct')
    .eq('organization_id', organizationId)
    .maybeSingle();

  const pct = Number(settings?.tax_pct ?? 0);
  return Number.isFinite(pct) && pct > 0 ? pct : 0;
}

export function usePurchaseOrders(filters?: {
  status?: PurchaseOrderStatus;
  warehouseId?: string;
  search?: string;
}) {
  const { activeOrganizationId } = useOrganizationContext();
  const scopeKey = activeOrganizationId ?? 'none';

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: [...purchaseOrdersListKey(scopeKey), filters?.status, filters?.warehouseId, filters?.search],
    queryFn: async (): Promise<PurchaseOrder[]> => {
      if (!activeOrganizationId) return [];
      let q = supabase
        .from('PurchaseOrders')
        .select('*, Warehouses(name, code), DirectoryVendors(id, name), PurchaseOrderLines(id, allocation_type, allocation_mo_id)')
        .eq('organization_id', activeOrganizationId)
        .order('created_at', { ascending: false });

      if (filters?.status) q = q.eq('status', filters.status);
      if (filters?.warehouseId) q = q.eq('warehouse_id', filters.warehouseId);
      if (filters?.search && filters.search.trim()) {
        q = q.ilike('po_number', `%${filters.search.trim()}%`);
      }

      const { data: rows, error: e } = await q;
      if (e) throw e;
      return (rows ?? []) as PurchaseOrder[];
    },
    enabled: !!activeOrganizationId,
  });

  return {
    purchaseOrders: data ?? [],
    loading: isLoading,
    error: error ? (error as Error).message : null,
    refetch,
  };
}

export function usePurchaseOrderDetail(poId: string | null) {
  const { activeOrganizationId } = useOrganizationContext();
  const scopeKey = activeOrganizationId ?? 'none';

  const { data: po, isLoading: loadingPo, refetch: refetchPo } = useQuery({
    queryKey: purchaseOrderDetailKey(scopeKey, poId ?? ''),
    queryFn: async () => {
      if (!poId) return null;
      const { data, error } = await supabase
        .from('PurchaseOrders')
        .select('*, Warehouses(name, code), DirectoryVendors(id, name)')
        .eq('id', poId)
        .single();
      if (error) {
        if (error.code === 'PGRST116') return null;
        throw error;
      }
      return data as PurchaseOrder;
    },
    enabled: !!poId && !!activeOrganizationId,
    retry: (failureCount, error: any) => {
      if (error?.code === 'PGRST116') return false;
      return failureCount < 2;
    },
  });

  const { data: lines, isLoading: loadingLines, refetch: refetchLines } = useQuery({
    queryKey: [...purchaseOrderDetailKey(scopeKey, poId ?? ''), 'lines'],
    queryFn: async () => {
      if (!poId) return [];
      const { data, error } = await supabase
        .from('PurchaseOrderLines')
        .select('*, CatalogItems(sku, name, description, cost_exw, unit_of_measure, measure_basis, is_roll, purchase_unit, units_per_purchase_unit, moq, roll_width_value, roll_width_uom, roll_length_value, roll_length_uom)')
        .eq('purchase_order_id', poId)
        .order('created_at', { ascending: true });
      if (error) throw error;
      return (data ?? []) as PurchaseOrderLine[];
    },
    enabled: !!poId && !!activeOrganizationId,
  });

  const stableLines = useMemo(() => lines ?? [], [lines]);

  const { data: linkedMOs } = useQuery({
    queryKey: [...purchaseOrderDetailKey(scopeKey, poId ?? ''), 'linked-mos'],
    queryFn: async () => {
      if (!poId) return [];
      const { data, error } = await supabase
        .from('PurchaseOrderManufacturingOrders')
        .select('manufacturing_order_id, ManufacturingOrders(manufacturing_order_no)')
        .eq('purchase_order_id', poId)
        .eq('deleted', false);
      if (error) return [];
      return (data ?? []).map((r: any) => ({
        id: r.manufacturing_order_id as string,
        manufacturing_order_no: (r.ManufacturingOrders?.manufacturing_order_no ?? r.manufacturing_order_id.slice(0, 8)) as string,
      }));
    },
    enabled: !!poId && !!activeOrganizationId,
  });

  return {
    purchaseOrder: po ?? null,
    lines: stableLines,
    linkedMOs: linkedMOs ?? [],
    loading: loadingPo || loadingLines,
    refetch: () => { refetchPo(); refetchLines(); },
  };
}

export interface CreatePOLineInput {
  catalog_item_id?: string | null;
  ordered_qty: number;
  unit_cost: number;
  unit?: string;
  description?: string | null;
  is_one_off?: boolean;
  notes?: string | null;
  allocation_type?: 'stock' | 'manufacturing_order';
  allocation_mo_id?: string | null;
  sku_snapshot?: string | null;
  item_name_snapshot?: string | null;
  purchase_unit_snapshot?: string | null;
  purchase_uom_snapshot?: string | null;
  purchase_mode_snapshot?: 'unit_packaged' | 'linear_direct' | 'roll' | null;
  stock_basis_snapshot?: 'ea' | 'linear_m' | null;
  units_per_purchase_unit_snapshot?: number | null;
  moq_snapshot?: number | null;
  unit_of_measure_snapshot?: string | null;
  is_roll_snapshot?: boolean | null;
  roll_width_value_snapshot?: number | null;
  roll_width_uom_snapshot?: string | null;
  roll_length_value_snapshot?: number | null;
  roll_length_uom_snapshot?: string | null;
}

export function useCreatePurchaseOrder() {
  const [isCreating, setIsCreating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();
  const queryClient = useQueryClient();

  const createPurchaseOrder = useCallback(async (params: {
    warehouse_id: string;
    vendor_id?: string | null;
    ship_to_address_id?: string | null;
    ship_to_address_snapshot?: string | null;
    expected_date?: string | null;
    po_number?: string | null;
    notes?: string | null;
    currency?: string;
    status?: PurchaseOrderStatus;
    lines?: CreatePOLineInput[];
    manufacturing_order_ids?: string[];
  }) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    setIsCreating(true);
    try {
      const poNumber = params.po_number ?? await generateNextPurchaseOrderNumber(activeOrganizationId);
      const subtotal = safeLineSubtotal(params.lines);
      const taxPct = await resolvePurchaseTaxPct({
        organizationId: activeOrganizationId,
        vendorId: params.vendor_id ?? null,
      });
      const total = subtotal + (subtotal * taxPct);

      const { data: po, error: poError } = await supabase
        .from('PurchaseOrders')
        .insert({
          organization_id: activeOrganizationId,
          warehouse_id: params.warehouse_id,
          vendor_id: params.vendor_id ?? null,
          ship_to_address_id: params.ship_to_address_id ?? null,
          ship_to_address_snapshot: params.ship_to_address_snapshot ?? null,
          expected_date: params.expected_date ?? null,
          po_number: poNumber,
          status: params.status ?? 'DRAFT',
          notes: params.notes ?? null,
          currency: params.currency ?? 'USD',
          subtotal,
          total,
        })
        .select()
        .single();
      if (poError) throw poError;

      if (params.lines && params.lines.length > 0) {
        const needsSnapshot = params.lines.some(
          l => l.catalog_item_id && (l.purchase_mode_snapshot == null && l.stock_basis_snapshot == null && l.purchase_uom_snapshot == null)
        );
        let linesToInsert = params.lines;
        if (needsSnapshot) {
          const catalogIds = [...new Set(params.lines.map(l => l.catalog_item_id).filter((id): id is string => !!id))];
          const { data: catalogRows } = await supabase
            .from('CatalogItems')
            .select('id, sku, name, unit_of_measure, measure_basis, is_roll, purchase_unit, units_per_purchase_unit, moq')
            .in('id', catalogIds);
          const catalogMap = new Map((catalogRows ?? []).map((r: Record<string, unknown>) => [r.id as string, r]));
          linesToInsert = params.lines.map(l => {
            if (!l.catalog_item_id || (l.sku_snapshot != null && l.item_name_snapshot != null))
              return l;
            const ci = catalogMap.get(l.catalog_item_id) as Record<string, unknown> | undefined;
            if (!ci) return l;
            const isRoll = Boolean(ci.is_roll);
            const measureBasis = ci.measure_basis as string | null;
            const derivedMode: 'unit_packaged' | 'linear_direct' | 'roll' = isRoll ? 'roll' : (measureBasis === 'linear' ? 'linear_direct' : 'unit_packaged');
            const derivedBasis: 'ea' | 'linear_m' = measureBasis === 'linear' ? 'linear_m' : 'ea';
            return {
              ...l,
              sku_snapshot: (l.sku_snapshot ?? ci.sku ?? null) as string | null,
              item_name_snapshot: (l.item_name_snapshot ?? ci.name ?? null) as string | null,
              purchase_mode_snapshot: (l.purchase_mode_snapshot ?? derivedMode) as 'unit_packaged' | 'linear_direct' | 'roll' | null,
              stock_basis_snapshot: (l.stock_basis_snapshot ?? derivedBasis) as 'ea' | 'linear_m' | null,
              purchase_uom_snapshot: (l.purchase_uom_snapshot ?? ci.purchase_unit ?? ci.unit_of_measure ?? null) as string | null,
              purchase_unit_snapshot: (l.purchase_unit_snapshot ?? ci.purchase_unit ?? null) as string | null,
              moq_snapshot: (l.moq_snapshot ?? ci.moq ?? 0) as number | null,
              unit_of_measure_snapshot: (l.unit_of_measure_snapshot ?? ci.unit_of_measure ?? null) as string | null,
              is_roll_snapshot: (l.is_roll_snapshot ?? ci.is_roll ?? null) as boolean | null,
            };
          });
        }
        const lineRows = linesToInsert.map(l => ({
          purchase_order_id: po.id,
          catalog_item_id: l.catalog_item_id ?? null,
          ordered_qty: l.ordered_qty || 0,
          received_qty: 0,
          unit_cost: Number(l.unit_cost) || 0,
          unit: l.unit ?? 'ea',
          description: l.description ?? null,
          is_one_off: l.is_one_off ?? false,
          notes: l.notes ?? null,
          allocation_type: l.allocation_type ?? 'stock',
          allocation_mo_id: l.allocation_mo_id ?? null,
          sku_snapshot: l.sku_snapshot ?? null,
          item_name_snapshot: l.item_name_snapshot ?? null,
          purchase_unit_snapshot: l.purchase_unit_snapshot ?? null,
          purchase_uom_snapshot: l.purchase_uom_snapshot ?? null,
          purchase_mode_snapshot: l.purchase_mode_snapshot ?? null,
          stock_basis_snapshot: l.stock_basis_snapshot ?? null,
          units_per_purchase_unit_snapshot: l.units_per_purchase_unit_snapshot ?? null,
          moq_snapshot: l.moq_snapshot ?? null,
          unit_of_measure_snapshot: l.unit_of_measure_snapshot ?? null,
          is_roll_snapshot: l.is_roll_snapshot ?? null,
          roll_width_value_snapshot: l.roll_width_value_snapshot ?? null,
          roll_width_uom_snapshot: l.roll_width_uom_snapshot ?? null,
          roll_length_value_snapshot: l.roll_length_value_snapshot ?? null,
          roll_length_uom_snapshot: l.roll_length_uom_snapshot ?? null,
        }));
        const { error: linesError } = await supabase.from('PurchaseOrderLines').insert(lineRows);
        if (linesError) {
          const msg = String(linesError.message ?? '').toLowerCase();
          if (msg.includes('snapshot') && msg.includes('schema cache')) {
            const coreRows = lineRows.map((r: Record<string, unknown>) => {
              const core: Record<string, unknown> = {};
              for (const [k, v] of Object.entries(r)) {
                if (!k.endsWith('_snapshot')) core[k] = v;
              }
              return core;
            });
            const { error: retryErr } = await supabase.from('PurchaseOrderLines').insert(coreRows);
            if (retryErr) {
              await supabase.from('PurchaseOrders').delete().eq('id', po.id);
              throw retryErr;
            }
          } else {
            await supabase.from('PurchaseOrders').delete().eq('id', po.id);
            throw linesError;
          }
        }
      }

      if (params.manufacturing_order_ids && params.manufacturing_order_ids.length > 0) {
        const pivotRows = [...new Set(params.manufacturing_order_ids)].map(moId => ({
          organization_id: activeOrganizationId,
          purchase_order_id: po.id,
          manufacturing_order_id: moId,
        }));
        await supabase
          .from('PurchaseOrderManufacturingOrders')
          .upsert(pivotRows, { onConflict: 'purchase_order_id,manufacturing_order_id' });
      }

      // refetchType 'all' also refetches the (currently inactive) list query, so the
      // new PO is present in the cache before the user navigates back to the list.
      queryClient.invalidateQueries({ queryKey: purchaseOrdersListKey(activeOrganizationId), refetchType: 'all' });
      return po as PurchaseOrder;
    } finally {
      setIsCreating(false);
    }
  }, [activeOrganizationId, queryClient]);

  return { createPurchaseOrder, isCreating };
}

export interface UpdatePOLineInput {
  id?: string;
  catalog_item_id?: string | null;
  ordered_qty: number;
  unit_cost: number;
  unit?: string;
  description?: string | null;
  is_one_off?: boolean;
  notes?: string | null;
  allocation_type?: 'stock' | 'manufacturing_order';
  allocation_mo_id?: string | null;
  sku_snapshot?: string | null;
  item_name_snapshot?: string | null;
  purchase_unit_snapshot?: string | null;
  purchase_uom_snapshot?: string | null;
  purchase_mode_snapshot?: 'unit_packaged' | 'linear_direct' | 'roll' | null;
  stock_basis_snapshot?: 'ea' | 'linear_m' | null;
  units_per_purchase_unit_snapshot?: number | null;
  moq_snapshot?: number | null;
  unit_of_measure_snapshot?: string | null;
  is_roll_snapshot?: boolean | null;
  roll_width_value_snapshot?: number | null;
  roll_width_uom_snapshot?: string | null;
  roll_length_value_snapshot?: number | null;
  roll_length_uom_snapshot?: string | null;
}

export function useUpdatePurchaseOrder() {
  const [isUpdating, setIsUpdating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();
  const queryClient = useQueryClient();

  const updatePurchaseOrder = useCallback(async (poId: string, params: {
    warehouse_id?: string;
    vendor_id?: string | null;
    ship_to_address_id?: string | null;
    ship_to_address_snapshot?: string | null;
    expected_date?: string | null;
    notes?: string | null;
    currency?: string;
    lines?: UpdatePOLineInput[];
  }) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    setIsUpdating(true);
    try {
      let subtotal = params.lines ? safeLineSubtotal(params.lines) : 0;
      if (!params.lines && params.vendor_id !== undefined) {
        const { data: existingLines } = await supabase
          .from('PurchaseOrderLines')
          .select('ordered_qty, unit_cost')
          .eq('purchase_order_id', poId);
        subtotal = safeLineSubtotal((existingLines ?? []) as { ordered_qty: number; unit_cost: number }[]);
      }

      const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };
      if (params.warehouse_id != null) updates.warehouse_id = params.warehouse_id;
      if (params.vendor_id !== undefined) updates.vendor_id = params.vendor_id;
      if (params.ship_to_address_id !== undefined) updates.ship_to_address_id = params.ship_to_address_id;
      if (params.ship_to_address_snapshot !== undefined) updates.ship_to_address_snapshot = params.ship_to_address_snapshot;
      if (params.expected_date !== undefined) updates.expected_date = params.expected_date;
      if (params.notes !== undefined) updates.notes = params.notes;
      if (params.currency !== undefined) updates.currency = params.currency;
      if (params.lines || params.vendor_id !== undefined) {
        const vendorIdForTax = params.vendor_id !== undefined ? params.vendor_id : undefined;
        const taxPct = await resolvePurchaseTaxPct({
          organizationId: activeOrganizationId,
          vendorId: vendorIdForTax,
        });
        updates.subtotal = subtotal;
        updates.total = subtotal + (subtotal * taxPct);
      }

      if (Object.keys(updates).length > 1) {
        const { error } = await supabase
          .from('PurchaseOrders')
          .update(updates)
          .eq('id', poId);
        if (error) throw error;
      }

      if (params.lines !== undefined) {
        const { data: existing } = await supabase
          .from('PurchaseOrderLines')
          .select('id, received_qty')
          .eq('purchase_order_id', poId);
        type LineRow = { id: string; received_qty: number };
        const existingRows = (existing ?? []) as LineRow[];
        const existingMap = new Map<string, LineRow>(existingRows.map(r => [r.id, r]));
        const toUpdate = params.lines.filter(l => l.id && existingMap.has(l.id));
        const toInsert = params.lines.filter(l => !l.id || !existingMap.has(l.id));
        const keptIds = new Set(params.lines.map(l => l.id).filter((id): id is string => id != null));
        const toDelete = existingRows.map(r => r.id).filter(id => !keptIds.has(id));

        for (const l of toUpdate) {
          if (!l.id) continue;
          const existingLine = existingMap.get(l.id);
          const newOrderedQty = Math.max(l.ordered_qty, existingLine?.received_qty ?? 0);
          await supabase
            .from('PurchaseOrderLines')
            .update({
              catalog_item_id: l.catalog_item_id ?? null,
              ordered_qty: newOrderedQty,
              unit_cost: l.unit_cost,
              unit: l.unit ?? 'ea',
              description: l.description ?? null,
              is_one_off: l.is_one_off ?? false,
              notes: l.notes ?? null,
              allocation_type: l.allocation_type ?? 'stock',
              allocation_mo_id: l.allocation_mo_id ?? null,
              sku_snapshot: l.sku_snapshot ?? null,
              item_name_snapshot: l.item_name_snapshot ?? null,
              purchase_unit_snapshot: l.purchase_unit_snapshot ?? null,
              purchase_uom_snapshot: l.purchase_uom_snapshot ?? null,
              purchase_mode_snapshot: l.purchase_mode_snapshot ?? null,
              stock_basis_snapshot: l.stock_basis_snapshot ?? null,
              units_per_purchase_unit_snapshot: l.units_per_purchase_unit_snapshot ?? null,
              moq_snapshot: l.moq_snapshot ?? null,
              unit_of_measure_snapshot: l.unit_of_measure_snapshot ?? null,
              is_roll_snapshot: l.is_roll_snapshot ?? null,
              roll_width_value_snapshot: l.roll_width_value_snapshot ?? null,
              roll_width_uom_snapshot: l.roll_width_uom_snapshot ?? null,
              roll_length_value_snapshot: l.roll_length_value_snapshot ?? null,
              roll_length_uom_snapshot: l.roll_length_uom_snapshot ?? null,
              updated_at: new Date().toISOString(),
            })
            .eq('id', l.id);
        }
        if (toInsert.length > 0) {
          await supabase.from('PurchaseOrderLines').insert(toInsert.map(l => ({
            purchase_order_id: poId,
            catalog_item_id: l.catalog_item_id ?? null,
            ordered_qty: l.ordered_qty,
            received_qty: 0,
            unit_cost: l.unit_cost,
            unit: l.unit ?? 'ea',
            description: l.description ?? null,
            is_one_off: l.is_one_off ?? false,
            notes: l.notes ?? null,
            allocation_type: l.allocation_type ?? 'stock',
            allocation_mo_id: l.allocation_mo_id ?? null,
            sku_snapshot: l.sku_snapshot ?? null,
            item_name_snapshot: l.item_name_snapshot ?? null,
            purchase_unit_snapshot: l.purchase_unit_snapshot ?? null,
            purchase_uom_snapshot: l.purchase_uom_snapshot ?? null,
            purchase_mode_snapshot: l.purchase_mode_snapshot ?? null,
            stock_basis_snapshot: l.stock_basis_snapshot ?? null,
            units_per_purchase_unit_snapshot: l.units_per_purchase_unit_snapshot ?? null,
            moq_snapshot: l.moq_snapshot ?? null,
            unit_of_measure_snapshot: l.unit_of_measure_snapshot ?? null,
            is_roll_snapshot: l.is_roll_snapshot ?? null,
            roll_width_value_snapshot: l.roll_width_value_snapshot ?? null,
            roll_width_uom_snapshot: l.roll_width_uom_snapshot ?? null,
            roll_length_value_snapshot: l.roll_length_value_snapshot ?? null,
            roll_length_uom_snapshot: l.roll_length_uom_snapshot ?? null,
          })));
        }
        for (const id of toDelete) {
          const line = existingMap.get(id);
          if (line && line.received_qty > 0) continue;
          await supabase.from('PurchaseOrderLines').delete().eq('id', id);
        }
      }

      queryClient.invalidateQueries({ queryKey: purchaseOrdersListKey(activeOrganizationId), refetchType: 'all' });
      queryClient.invalidateQueries({ queryKey: purchaseOrderDetailKey(activeOrganizationId, poId), refetchType: 'all' });
    } finally {
      setIsUpdating(false);
    }
  }, [activeOrganizationId, queryClient]);

  return { updatePurchaseOrder, isUpdating };
}

export function useDeletePurchaseOrder() {
  const [isDeleting, setIsDeleting] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();
  const queryClient = useQueryClient();

  const deletePurchaseOrder = useCallback(async (poId: string) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    setIsDeleting(true);
    try {
      const { error } = await supabase.from('PurchaseOrders').delete().eq('id', poId);
      if (error) throw error;
      queryClient.invalidateQueries({ queryKey: purchaseOrdersListKey(activeOrganizationId), refetchType: 'all' });
    } finally {
      setIsDeleting(false);
    }
  }, [activeOrganizationId, queryClient]);

  return { deletePurchaseOrder, isDeleting };
}

export function useReceivePurchaseOrder() {
  const [isReceiving, setIsReceiving] = useState(false);
  const queryClient = useQueryClient();
  const { activeOrganizationId } = useOrganizationContext();

  const receivePurchaseOrder = useCallback(async (
    purchaseOrderId: string,
    lines: { purchase_order_line_id: string; received_qty: number }[]
  ) => {
    setIsReceiving(true);
    try {
      const { data, error } = await supabase.rpc('receive_purchase_order', {
        p_purchase_order_id: purchaseOrderId,
        p_lines: lines,
      });
      if (error) throw new Error(`Receipt RPC failed: ${error.message}`);
      const result = data as { ok?: boolean; error?: string; movement_id?: string; movement_no?: string };
      if (result && !result.ok) throw new Error(result.error || 'Receipt failed: unknown RPC error');
      queryClient.invalidateQueries({ queryKey: ['inventory', 'purchase-orders'], refetchType: 'all' });
      queryClient.invalidateQueries({ queryKey: ['inventory-movements'] });
      queryClient.invalidateQueries({ queryKey: ['inventory-allocations'] });
      if (activeOrganizationId) {
        queryClient.invalidateQueries({ queryKey: ['material-demand', activeOrganizationId] });
      }

      // Auto-advance linked MOs to materials_ready if all demand is covered.
      // Wrap in async IIFE because supabase.rpc builder is not a native Promise at call-site.
      void (async () => {
        try {
          await supabase.rpc('check_mo_readiness_after_po_receive', { p_po_id: purchaseOrderId });
        } catch {
          // Best-effort side effect; receipt success should not be blocked.
        }
      })();

      return result;
    } finally {
      setIsReceiving(false);
    }
  }, [queryClient, activeOrganizationId]);

  return { receivePurchaseOrder, isReceiving };
}

export interface CatalogItemCostInfo {
  cost_exw: number;
  purchase_unit: string;
  purchase_uom: string;
  purchase_mode: 'unit_packaged' | 'linear_direct' | 'roll';
  stock_basis: 'ea' | 'linear_m';
  units_per_purchase_unit: number;
  moq: number;
  unit_of_measure: string;
}

/**
 * Fetch cost_exw and purchase unit info from CatalogItems.
 * Used to pre-fill unit_cost and unit on PO lines as a snapshot.
 */
export async function fetchCatalogItemCostInfo(itemId: string): Promise<CatalogItemCostInfo> {
  const { data, error } = await supabase
    .from('CatalogItems')
    .select('cost_exw, purchase_unit, units_per_purchase_unit, moq, unit_of_measure, measure_basis, is_roll')
    .eq('id', itemId)
    .single();
  if (error || !data) {
    return {
      cost_exw: 0,
      purchase_unit: 'each',
      purchase_uom: 'each',
      purchase_mode: 'unit_packaged',
      stock_basis: 'ea',
      units_per_purchase_unit: 1,
      moq: 0,
      unit_of_measure: 'ea',
    };
  }
  const isRoll = Boolean(data.is_roll);
  const measureBasis = (data.measure_basis ?? 'unit') as MeasureBasis;
  const model = resolveInventoryUnitModel({ isRoll, measureBasis, purchaseUnit: data.purchase_unit });
  const purchaseMode = model.purchaseMode;
  const stockBasis = model.stockBasis;
  return {
    cost_exw: Number(data.cost_exw ?? 0),
    purchase_unit: data.purchase_unit ?? 'each',
    purchase_uom: data.purchase_unit ?? data.unit_of_measure ?? 'each',
    purchase_mode: purchaseMode,
    stock_basis: stockBasis,
    units_per_purchase_unit: Number(data.units_per_purchase_unit ?? 1),
    moq: Number(data.moq ?? 0),
    unit_of_measure: data.unit_of_measure ?? 'ea',
  };
}

const VALID_PO_TRANSITIONS: Record<PurchaseOrderStatus, PurchaseOrderStatus[]> = {
  DRAFT: ['OPEN', 'CANCELLED'],
  OPEN: ['CANCELLED'],
  PARTIAL: ['CANCELLED'],
  CLOSED: ['ARCHIVED'],
  CANCELLED: [],
  ARCHIVED: [],
};

export function useUpdatePurchaseOrderStatus() {
  const [isUpdating, setIsUpdating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();
  const queryClient = useQueryClient();

  const updateStatus = useCallback(async (poId: string, newStatus: PurchaseOrderStatus) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    setIsUpdating(true);
    try {
      const { data: po, error: fetchErr } = await supabase
        .from('PurchaseOrders')
        .select('status')
        .eq('id', poId)
        .single();
      if (fetchErr) throw fetchErr;

      const current = po.status as PurchaseOrderStatus;
      const allowed = VALID_PO_TRANSITIONS[current] ?? [];
      if (!allowed.includes(newStatus)) {
        throw new Error(`Cannot transition PO from ${current} to ${newStatus}`);
      }

      const { error } = await supabase
        .from('PurchaseOrders')
        .update({ status: newStatus, updated_at: new Date().toISOString() })
        .eq('id', poId);
      if (error) throw error;

      queryClient.invalidateQueries({ queryKey: purchaseOrdersListKey(activeOrganizationId), refetchType: 'all' });
      queryClient.invalidateQueries({ queryKey: purchaseOrderDetailKey(activeOrganizationId, poId), refetchType: 'all' });
    } finally {
      setIsUpdating(false);
    }
  }, [activeOrganizationId, queryClient]);

  return { updateStatus, isUpdating };
}

/** @deprecated Use fetchCatalogItemCostInfo instead */
export async function fetchCatalogItemCost(itemId: string): Promise<number> {
  const info = await fetchCatalogItemCostInfo(itemId);
  return info.cost_exw;
}
