import { useState, useCallback } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export type MovementType = 'receipt' | 'issue_to_production' | 'transfer' | 'adjustment' | 'return';
export type MovementStatus = 'draft' | 'confirmed';
export type AdjustmentReason = 'physical_count' | 'damaged' | 'theft_shrinkage' | 'write_off' | 'opening_stock' | 'correction' | 'return_to_stock' | 'other';

export const ADJUSTMENT_REASON_LABELS: Record<AdjustmentReason, string> = {
  physical_count: 'Physical Count',
  damaged: 'Damaged Goods',
  theft_shrinkage: 'Theft / Shrinkage',
  write_off: 'Write-off',
  opening_stock: 'Opening Stock',
  correction: 'Correction / Error',
  return_to_stock: 'Return to Stock',
  other: 'Other',
};

export interface InventoryMovement {
  id: string;
  organization_id: string;
  warehouse_id: string;
  movement_type: MovementType;
  reference_type: string | null;
  reference_id: string | null;
  movement_no: string | null;
  movement_date: string;
  status: MovementStatus;
  notes: string | null;
  adjustment_reason: AdjustmentReason | null;
  confirmed_at: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
  deleted: boolean;
  Warehouses?: { name: string; code: string | null } | null;
  line_count?: number;
}

export interface InventoryMovementLine {
  id: string;
  inventory_movement_id: string;
  catalog_item_id: string;
  quantity: number;
  unit: string | null;
  notes: string | null;
  created_at: string;
  CatalogItems?: { sku: string; name: string } | null;
}

const MOVEMENTS_KEY = 'inventory-movements';

export function useInventoryMovements(filters?: {
  warehouseId?: string;
  movementType?: MovementType;
  status?: MovementStatus;
}) {
  const { activeOrganizationId } = useOrganizationContext();

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: [MOVEMENTS_KEY, activeOrganizationId, filters?.warehouseId, filters?.movementType, filters?.status],
    queryFn: async (): Promise<InventoryMovement[]> => {
      if (!activeOrganizationId) return [];
      let q = supabase
        .from('InventoryMovements')
        .select('*, Warehouses(name, code)')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('created_at', { ascending: false });

      if (filters?.warehouseId) q = q.eq('warehouse_id', filters.warehouseId);
      if (filters?.movementType) q = q.eq('movement_type', filters.movementType);
      if (filters?.status) q = q.eq('status', filters.status);

      const { data: rows, error: e } = await q;
      if (e) throw e;
      return (rows ?? []) as InventoryMovement[];
    },
    enabled: !!activeOrganizationId,
  });

  return {
    movements: data ?? [],
    loading: isLoading,
    error: error ? (error as Error).message : null,
    refetch,
  };
}

export function useInventoryMovementDetail(movementId: string | null) {
  const { data: movement, isLoading: loadingMovement, refetch: refetchMovement } = useQuery({
    queryKey: [MOVEMENTS_KEY, 'detail', movementId],
    queryFn: async () => {
      if (!movementId) return null;
      const { data, error } = await supabase
        .from('InventoryMovements')
        .select('*, Warehouses(name, code)')
        .eq('id', movementId)
        .eq('deleted', false)
        .single();
      if (error) throw error;
      return data as InventoryMovement;
    },
    enabled: !!movementId,
  });

  const { data: lines, isLoading: loadingLines, refetch: refetchLines } = useQuery({
    queryKey: [MOVEMENTS_KEY, 'lines', movementId],
    queryFn: async () => {
      if (!movementId) return [];
      const { data, error } = await supabase
        .from('InventoryMovementLines')
        .select('*, CatalogItems(sku, name)')
        .eq('inventory_movement_id', movementId)
        .order('created_at', { ascending: true });
      if (error) throw error;
      return (data ?? []) as InventoryMovementLine[];
    },
    enabled: !!movementId,
  });

  return {
    movement: movement ?? null,
    lines: lines ?? [],
    loading: loadingMovement || loadingLines,
    refetch: () => { refetchMovement(); refetchLines(); },
  };
}

export function useCreateMovement() {
  const [isCreating, setIsCreating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();
  const queryClient = useQueryClient();

  const createMovement = useCallback(async (params: {
    warehouse_id: string;
    movement_type: MovementType;
    reference_type?: string;
    reference_id?: string;
    movement_date?: string;
    notes?: string;
    adjustment_reason?: AdjustmentReason;
    created_by?: string;
  }) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    setIsCreating(true);
    try {
      const { data, error } = await supabase
        .from('InventoryMovements')
        .insert({
          organization_id: activeOrganizationId,
          warehouse_id: params.warehouse_id,
          movement_type: params.movement_type,
          reference_type: params.reference_type ?? null,
          reference_id: params.reference_id ?? null,
          movement_date: params.movement_date ?? new Date().toISOString().slice(0, 10),
          notes: params.notes ?? null,
          adjustment_reason: params.adjustment_reason ?? null,
          created_by: params.created_by ?? null,
          status: 'draft',
          deleted: false,
        })
        .select()
        .single();
      if (error) throw error;
      queryClient.invalidateQueries({ queryKey: [MOVEMENTS_KEY] });
      return data;
    } finally {
      setIsCreating(false);
    }
  }, [activeOrganizationId, queryClient]);

  return { createMovement, isCreating };
}

export function useConfirmMovement() {
  const [isConfirming, setIsConfirming] = useState(false);
  const queryClient = useQueryClient();

  const confirmMovement = useCallback(async (movementId: string) => {
    setIsConfirming(true);
    try {
      const { data, error } = await supabase.rpc('confirm_inventory_movement', { p_movement_id: movementId });
      if (error) throw error;
      const result = data as any;
      if (result && !result.ok) throw new Error(result.error || 'Failed to confirm movement');
      queryClient.invalidateQueries({ queryKey: [MOVEMENTS_KEY] });
      return result;
    } finally {
      setIsConfirming(false);
    }
  }, [queryClient]);

  return { confirmMovement, isConfirming };
}

export function useIssueMaterials() {
  const [isIssuing, setIsIssuing] = useState(false);
  const queryClient = useQueryClient();

  const issueMaterials = useCallback(async (manufacturingOrderId: string, warehouseId: string) => {
    setIsIssuing(true);
    try {
      const { data, error } = await supabase.rpc('issue_materials_for_manufacturing_order', {
        p_manufacturing_order_id: manufacturingOrderId,
        p_warehouse_id: warehouseId,
      });
      if (error) throw error;
      const result = data as any;
      if (result && !result.ok) throw new Error(result.error || 'Failed to issue materials');
      queryClient.invalidateQueries({ queryKey: [MOVEMENTS_KEY] });
      return result;
    } finally {
      setIsIssuing(false);
    }
  }, [queryClient]);

  return { issueMaterials, isIssuing };
}
