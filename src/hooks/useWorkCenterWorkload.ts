import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../lib/supabase/client';

export interface WorkCenter {
  id: string;
  name: string;
  code: string;
  capacity_hours_per_day: number;
}

interface ScheduledTask {
  id: string;
  manufacturing_order_id: string;
  work_center_id: string;
  estimated_duration_hours: number;
  planned_start_at: string;
  planned_end_at: string;
  mo_no: string | null;
}

export interface DayLoad {
  totalHours: number;
  capacity: number;
  level: 'ok' | 'warning' | 'overload';
  tasks: { id: string; moNo: string | null; hours: number }[];
}

export type WorkloadMap = Map<string, Map<string, DayLoad>>;

function toDateKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function distributeHoursPerDay(
  startIso: string,
  endIso: string,
  totalHours: number
): { dateKey: string; hours: number }[] {
  const start = new Date(startIso);
  const end = new Date(endIso);
  const result: { dateKey: string; hours: number }[] = [];

  let workingDays = 0;
  const cursor = new Date(start);
  cursor.setHours(0, 0, 0, 0);
  const endDay = new Date(end);
  endDay.setHours(0, 0, 0, 0);

  while (cursor <= endDay) {
    if (cursor.getDay() !== 0) workingDays++;
    cursor.setDate(cursor.getDate() + 1);
  }

  if (workingDays === 0) return result;

  const hoursPerWorkDay = totalHours / workingDays;

  const cursor2 = new Date(start);
  cursor2.setHours(0, 0, 0, 0);
  while (cursor2 <= endDay) {
    if (cursor2.getDay() !== 0) {
      result.push({ dateKey: toDateKey(cursor2), hours: hoursPerWorkDay });
    }
    cursor2.setDate(cursor2.getDate() + 1);
  }

  return result;
}

function computeLevel(totalHours: number, _capacity: number): 'ok' | 'warning' | 'overload' {
  if (totalHours <= 8) return 'ok';
  if (totalHours <= 12) return 'warning';
  return 'overload';
}

export function useWorkCenterWorkload(
  organizationId: string | null,
  dateRange?: { from: Date; to: Date },
  excludeMoId?: string | null,
) {
  const [workCenters, setWorkCenters] = useState<WorkCenter[]>([]);
  const [tasks, setTasks] = useState<ScheduledTask[]>([]);
  const [loading, setLoading] = useState(false);

  const fetchData = useCallback(async () => {
    if (!organizationId) return;
    setLoading(true);
    try {
      const [wcRes, taskRes] = await Promise.all([
        supabase
          .from('WorkCenters')
          .select('id, name, code, capacity_hours_per_day')
          .eq('organization_id', organizationId)
          .eq('deleted', false)
          .eq('is_active', true)
          .order('sequence'),
        supabase
          .from('WorkOrderTasks')
          .select(`
            id, manufacturing_order_id, work_center_id,
            estimated_duration_hours, planned_start_at, planned_end_at,
            ManufacturingOrders!inner(manufacturing_order_no)
          `)
          .eq('organization_id', organizationId)
          .eq('deleted', false)
          .not('planned_start_at', 'is', null)
          .not('planned_end_at', 'is', null),
      ]);

      if (wcRes.data) setWorkCenters(wcRes.data as WorkCenter[]);
      if (taskRes.data) {
        setTasks(
          (taskRes.data as any[]).map((t) => ({
            id: t.id,
            manufacturing_order_id: t.manufacturing_order_id,
            work_center_id: t.work_center_id,
            estimated_duration_hours: t.estimated_duration_hours ?? 8,
            planned_start_at: t.planned_start_at,
            planned_end_at: t.planned_end_at,
            mo_no: t.ManufacturingOrders?.manufacturing_order_no ?? null,
          }))
        );
      }
    } finally {
      setLoading(false);
    }
  }, [organizationId]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const workload: WorkloadMap = useMemo(() => {
    const map: WorkloadMap = new Map();
    const capacityByWc = new Map(workCenters.map((wc) => [wc.id, wc.capacity_hours_per_day]));

    const filteredTasks = excludeMoId
      ? tasks.filter((t) => t.manufacturing_order_id !== excludeMoId)
      : tasks;

    for (const task of filteredTasks) {
      if (dateRange) {
        const tEnd = new Date(task.planned_end_at);
        const tStart = new Date(task.planned_start_at);
        if (tEnd < dateRange.from || tStart > dateRange.to) continue;
      }

      const dayLoads = distributeHoursPerDay(
        task.planned_start_at,
        task.planned_end_at,
        task.estimated_duration_hours
      );

      for (const { dateKey, hours } of dayLoads) {
        if (!map.has(task.work_center_id)) map.set(task.work_center_id, new Map());
        const wcMap = map.get(task.work_center_id)!;

        if (!wcMap.has(dateKey)) {
          const cap = capacityByWc.get(task.work_center_id) ?? 8;
          wcMap.set(dateKey, { totalHours: 0, capacity: cap, level: 'ok', tasks: [] });
        }

        const day = wcMap.get(dateKey)!;
        day.totalHours += hours;
        day.tasks.push({ id: task.id, moNo: task.mo_no, hours });
        day.level = computeLevel(day.totalHours, day.capacity);
      }
    }

    return map;
  }, [tasks, workCenters, dateRange, excludeMoId]);

  const getDayLoad = useCallback(
    (workCenterId: string, date: Date): DayLoad | null => {
      const key = toDateKey(date);
      return workload.get(workCenterId)?.get(key) ?? null;
    },
    [workload]
  );

  const getDayLoadByKey = useCallback(
    (workCenterId: string, dateKey: string): DayLoad | null => {
      return workload.get(workCenterId)?.get(dateKey) ?? null;
    },
    [workload]
  );

  return {
    workCenters,
    workload,
    loading,
    getDayLoad,
    getDayLoadByKey,
    refetch: fetchData,
  };
}

export { toDateKey };
