import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';
import { warehouseLocationsListKey } from '../lib/queryKeys';

export interface WarehouseLocationRow {
  id: string;
  organization_id: string;
  warehouse_id: string;
  zone: string | null;
  rack: string | null;
  level: string | null;
  bin: string | null;
  location_code: string;
  is_pickable: boolean;
  is_active: boolean;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface WarehouseLocationWithWarehouse extends WarehouseLocationRow {
  warehouse_name: string | null;
}

interface UseWarehouseLocationsParams {
  organizationId: string | null | undefined;
  warehouseId?: string | null;
  scopeKey: string;
  /** Include inactive locations. Default: false. */
  includeInactive?: boolean;
}

/** List warehouse locations for an org (optionally filtered by warehouse). */
export function useWarehouseLocations({
  organizationId,
  warehouseId,
  scopeKey,
  includeInactive = false,
}: UseWarehouseLocationsParams) {
  const queryKey = [
    ...warehouseLocationsListKey(scopeKey, warehouseId ?? null),
    includeInactive ? 'all' : 'active',
  ];
  const query = useQuery({
    queryKey,
    queryFn: async (): Promise<WarehouseLocationWithWarehouse[]> => {
      if (!organizationId) {return [];}
      let q = supabase
        .from('WarehouseLocations')
        .select('id, organization_id, warehouse_id, zone, rack, level, bin, location_code, is_pickable, is_active, notes, created_at, updated_at, Warehouses(name)')
        .eq('organization_id', organizationId)
        .order('warehouse_id', { ascending: true })
        .order('location_code', { ascending: true });
      if (warehouseId) {q = q.eq('warehouse_id', warehouseId);}
      if (!includeInactive) {q = q.eq('is_active', true);}
      const { data, error } = await q;
      if (error) {throw error;}
      return ((data ?? []) as Array<WarehouseLocationRow & { Warehouses?: { name: string | null } | null }>).map((r) => ({
        ...r,
        warehouse_name: r.Warehouses?.name ?? null,
      }));
    },
    enabled: !!organizationId,
    placeholderData: keepPreviousData,
    refetchOnMount: false,
  });

  return {
    locations: query.data ?? [],
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    error: query.error ? (query.error as Error).message : null,
    refetch: query.refetch,
  };
}

export interface UpsertWarehouseLocationInput {
  id?: string;
  organization_id: string;
  warehouse_id: string;
  zone?: string | null;
  rack?: string | null;
  level?: string | null;
  bin?: string | null;
  location_code?: string | null;
  is_pickable?: boolean;
  is_active?: boolean;
  notes?: string | null;
}

export function useCreateWarehouseLocation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (input: UpsertWarehouseLocationInput) => {
      const payload = {
        organization_id: input.organization_id,
        warehouse_id: input.warehouse_id,
        zone: input.zone ?? null,
        rack: input.rack ?? null,
        level: input.level ?? null,
        bin: input.bin ?? null,
        location_code: input.location_code ?? null,
        is_pickable: input.is_pickable ?? true,
        is_active: input.is_active ?? true,
        notes: input.notes ?? null,
      };
      const { data, error } = await supabase
        .from('WarehouseLocations')
        .insert(payload)
        .select()
        .single();
      if (error) {throw error;}
      return data as WarehouseLocationRow;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['inventory', 'warehouse-locations'] });
    },
  });
}

export function useUpdateWarehouseLocation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (input: UpsertWarehouseLocationInput & { id: string }) => {
      const patch: Record<string, unknown> = {};
      if (input.zone !== undefined) {patch.zone = input.zone;}
      if (input.rack !== undefined) {patch.rack = input.rack;}
      if (input.level !== undefined) {patch.level = input.level;}
      if (input.bin !== undefined) {patch.bin = input.bin;}
      if (input.location_code !== undefined) {patch.location_code = input.location_code;}
      if (input.is_pickable !== undefined) {patch.is_pickable = input.is_pickable;}
      if (input.is_active !== undefined) {patch.is_active = input.is_active;}
      if (input.notes !== undefined) {patch.notes = input.notes;}
      const { data, error } = await supabase
        .from('WarehouseLocations')
        .update(patch)
        .eq('id', input.id)
        .select()
        .single();
      if (error) {throw error;}
      return data as WarehouseLocationRow;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['inventory', 'warehouse-locations'] });
    },
  });
}
