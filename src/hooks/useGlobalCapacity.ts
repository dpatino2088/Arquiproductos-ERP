import { useQuery } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';
import { globalCapacityKey } from '../lib/queryKeys';

export interface CapacityCell {
  station_id: string;
  station_name: string;
  station_code: string;
  day: string;
  capacity_hours: number;
  used_hours: number;
  available_hours: number;
  utilization_pct: number;
  is_overloaded: boolean;
}

export interface SlotResult {
  date: string;
  available_hours: number;
  capacity_hours: number;
  used_hours: number;
  utilization_after_pct: number;
  fits: boolean;
}

function toIsoDate(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

async function fetchGlobalCapacity(orgId: string, days: number, from: string): Promise<CapacityCell[]> {
  const { data, error } = await supabase.rpc('get_global_capacity', {
    p_org_id: orgId,
    p_days: days,
    p_from: from,
  });
  if (error) throw error;
  return (data ?? []) as CapacityCell[];
}

export async function findAvailableSlot(
  orgId: string,
  stationId: string,
  requiredHours: number,
): Promise<SlotResult[]> {
  const { data, error } = await supabase.rpc('find_available_slot', {
    p_org_id: orgId,
    p_station_id: stationId,
    p_required_hours: requiredHours,
  });
  if (error) throw error;
  return (data ?? []) as SlotResult[];
}

export async function simulateAddOrder(
  orgId: string,
  tasks: { station_id: string; hours: number; task_name: string }[],
  desiredStart: string,
  dueDate: string,
) {
  const { data, error } = await supabase.rpc('simulate_add_order', {
    p_org_id: orgId,
    p_tasks: tasks,
    p_desired_start: desiredStart,
    p_due_date: dueDate,
  });
  if (error) throw error;
  return data;
}

export function useGlobalCapacity(organizationId: string | null, days: number = 7, from?: Date) {
  const fromStr = from ? toIsoDate(from) : toIsoDate(new Date());
  const scopeKey = organizationId ?? '';

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: globalCapacityKey(scopeKey, days, fromStr),
    queryFn: () => fetchGlobalCapacity(organizationId!, days, fromStr),
    enabled: !!organizationId,
    refetchInterval: 5 * 60 * 1000,
    staleTime: 2 * 60 * 1000,
  });

  return {
    cells: data ?? [],
    loading: isLoading,
    error,
    refetch,
  };
}
