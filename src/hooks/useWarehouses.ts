import { useQuery } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';

export interface WarehouseRow {
  id: string;
  organization_id: string;
  name: string;
  code: string | null;
  is_default: boolean;
  created_at: string;
  updated_at: string;
}

/**
 * Fetch warehouses for the given organization.
 * Used to get default warehouse for inventory availability (informative).
 */
export function useWarehouses(organizationId: string | null | undefined) {
  const { data, isLoading, error } = useQuery({
    queryKey: ['warehouses', organizationId ?? ''],
    queryFn: async (): Promise<WarehouseRow[]> => {
      if (!organizationId) return [];
      const { data: rows, error: e } = await supabase
        .from('Warehouses')
        .select('id, organization_id, name, code, is_default, created_at, updated_at')
        .eq('organization_id', organizationId)
        .order('is_default', { ascending: false })
        .order('name');
      if (e) throw e;
      return (rows ?? []) as WarehouseRow[];
    },
    enabled: !!organizationId,
  });

  const defaultWarehouse = data?.find((w) => w.is_default) ?? data?.[0] ?? null;
  return {
    warehouses: data ?? [],
    defaultWarehouse,
    loading: isLoading,
    error: error ? (error as Error).message : null,
  };
}
