import { useMemo, useState, useEffect, useRef, useCallback } from 'react';
import { ChevronLeft, ChevronRight, CalendarDays, Filter, AlertCircle, Package, GanttChart, Calendar, Zap } from 'lucide-react';
import { DndContext, useDraggable, useDroppable, type DragEndEvent } from '@dnd-kit/core';
import { router } from '../../lib/router';
import { formatDate } from '../../lib/utils';
import { useManufacturingOrders, useUpdateManufacturingOrder } from '../../hooks/useManufacturing';
import type { ManufacturingOrder } from '../../hooks/useManufacturing';
import { supabase } from '../../lib/supabase/client';
import { useDealers } from '../../hooks/useDealers';
import { useWorkCenters } from '../../hooks/useWorkCenters';
import { useWorkCenterWorkload } from '../../hooks/useWorkCenterWorkload';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useFilteredMfgSubmodules } from './manufacturingSubmodules';
import WorkloadHeatmap from '../../components/manufacturing/WorkloadHeatmap';
import StatusTabs from '../../components/shared/StatusTabs';
import { isWorkDay, endHourForDay } from '../../lib/scheduling';

function toMonthStart(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), 1);
}

function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function parseIsoDate(value: string): Date {
  return /^\d{4}-\d{2}-\d{2}$/.test(value) ? new Date(`${value}T00:00:00`) : new Date(value);
}

function dayInRange(day: Date, startIso: string | null, endIso: string | null): boolean {
  if (!startIso || !endIso) return false;
  const start = parseIsoDate(startIso);
  const end = parseIsoDate(endIso);
  const dStart = new Date(day.getFullYear(), day.getMonth(), day.getDate(), 0, 0, 0);
  const dEnd = new Date(day.getFullYear(), day.getMonth(), day.getDate(), 23, 59, 59);
  return dStart <= end && dEnd >= start;
}

function dayKeyLocal(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function nextWorkStart(d: Date): Date {
  const out = new Date(d);
  out.setHours(8, 0, 0, 0);
  while (!isWorkDay(out.getDay())) {
    out.setDate(out.getDate() + 1);
    out.setHours(8, 0, 0, 0);
  }
  return out;
}

function workedDayKeys(startIso: string | null, estimatedHours: number | null | undefined, endIso: string | null): string[] {
  if (!startIso) return [];
  const start = parseIsoDate(startIso);
  const hours = Number(estimatedHours ?? 0);

  if (Number.isFinite(hours) && hours > 0) {
    const keys = new Set<string>();
    let cursor = new Date(start);
    let remaining = hours;

    while (remaining > 0.0001) {
      if (!isWorkDay(cursor.getDay())) {
        cursor = nextWorkStart(cursor);
        continue;
      }

      const dayEnd = endHourForDay(cursor.getDay());
      let currentHour = cursor.getHours() + cursor.getMinutes() / 60;
      if (currentHour < 8) {
        cursor.setHours(8, 0, 0, 0);
        currentHour = 8;
      }
      if (currentHour >= dayEnd) {
        cursor = nextWorkStart(new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + 1, 8, 0, 0, 0));
        continue;
      }

      keys.add(dayKeyLocal(cursor));
      const availableToday = Math.max(0, dayEnd - currentHour);
      const consume = Math.min(remaining, availableToday);
      remaining -= consume;
      cursor = new Date(cursor.getTime() + consume * 3600_000);
    }
    return [...keys];
  }

  if (!endIso) return [dayKeyLocal(start)];
  const end = parseIsoDate(endIso);
  const keys = new Set<string>();
  const cursor = new Date(start.getFullYear(), start.getMonth(), start.getDate(), 0, 0, 0, 0);
  const endDay = new Date(end.getFullYear(), end.getMonth(), end.getDate(), 0, 0, 0, 0);
  while (cursor <= endDay) {
    if (isWorkDay(cursor.getDay())) keys.add(dayKeyLocal(cursor));
    cursor.setDate(cursor.getDate() + 1);
  }
  return [...keys];
}

function getBlockVariant(mo: ManufacturingOrder, isLate: boolean, materialIncomplete: boolean): string {
  if (mo.status === 'cancelled') return 'bg-gray-100 border-gray-200 text-gray-500';
  if (materialIncomplete) return 'bg-amber-50 border-amber-300 text-amber-900';
  if (isLate) return 'bg-red-50 border-red-300 text-red-900';
  switch (mo.status) {
    case 'draft':
      return 'bg-gray-100 border-gray-300 text-gray-800';
    case 'in_production':
      return 'bg-blue-50 border-blue-300 text-blue-900';
    case 'quality_check':
    case 'ready_for_pickup':
      return 'bg-amber-50 border-amber-300 text-amber-900';
    case 'delivered':
    case 'completed':
      return 'bg-green-50 border-green-300 text-green-900';
    default:
      return 'bg-gray-100 border-gray-300 text-gray-800';
  }
}

function moveMoToDay(mo: ManufacturingOrder, targetDay: Date): { planned_start_at: string; planned_end_at: string } {
  const start = mo.planned_start_at ? parseIsoDate(mo.planned_start_at) : new Date();
  const end = mo.planned_end_at ? parseIsoDate(mo.planned_end_at) : new Date();
  const durationMs = end.getTime() - start.getTime();
  const newStart = new Date(targetDay.getFullYear(), targetDay.getMonth(), targetDay.getDate(), 0, 0, 0, 0);
  const newEnd = new Date(newStart.getTime() + durationMs);
  return { planned_start_at: newStart.toISOString(), planned_end_at: newEnd.toISOString() };
}

// Draggable block: id = mo.id
const URGENCY_BADGE_MAP: Record<string, { icon: string; color: string }> = {
  critical: { icon: '!', color: 'bg-red-500 text-white' },
  at_risk: { icon: '⚠', color: 'bg-orange-400 text-white' },
  blocked: { icon: '🔒', color: 'bg-blue-400 text-white' },
};

function DraggableBlock({
  mo,
  variant,
  showDeadline,
  isLate,
  materialIncomplete,
  onNavigate,
  justDroppedRef,
  urgency,
  dimmed,
}: {
  mo: ManufacturingOrder;
  variant: string;
  showDeadline: boolean;
  isLate: boolean;
  materialIncomplete: boolean;
  onNavigate: (id: string) => void;
  justDroppedRef: React.MutableRefObject<boolean>;
  urgency?: string;
  dimmed?: boolean;
}) {
  const { attributes, listeners, setNodeRef, isDragging } = useDraggable({ id: mo.id, data: { mo } });
  const pointerDownPos = useRef<{ x: number; y: number } | null>(null);
  return (
    <div
      ref={setNodeRef}
      {...listeners}
      {...attributes}
      onPointerDown={(e) => {
        pointerDownPos.current = { x: e.clientX, y: e.clientY };
        listeners?.onPointerDown?.(e as never);
      }}
      onPointerUp={(e) => {
        const start = pointerDownPos.current;
        if (!start) return;
        const dx = Math.abs(e.clientX - start.x);
        const dy = Math.abs(e.clientY - start.y);
        if (dx < 5 && dy < 5 && !justDroppedRef.current) {
          onNavigate(mo.id);
        }
        pointerDownPos.current = null;
      }}
      className={`text-left rounded border px-1.5 py-1 text-xs truncate cursor-pointer hover:opacity-90 ${variant} ${
        showDeadline ? 'border-r-4 border-r-orange-500' : ''
      } ${isDragging ? 'opacity-60 shadow-md' : ''} ${dimmed ? 'opacity-20' : ''}`}
      title={`${mo.manufacturing_order_no} · ${mo.status}${urgency ? ` · ${urgency}` : ''}`}
    >
      <div className="flex items-center gap-1 font-medium truncate">
        {urgency && URGENCY_BADGE_MAP[urgency] && (
          <span className={`w-4 h-4 rounded-full flex items-center justify-center text-[8px] flex-shrink-0 ${URGENCY_BADGE_MAP[urgency].color}`}>
            {URGENCY_BADGE_MAP[urgency].icon}
          </span>
        )}
        {isLate && !urgency && <AlertCircle className="w-3 h-3 shrink-0 text-red-600" aria-label="Overdue" />}
        {materialIncomplete && <Package className="w-3 h-3 shrink-0 text-amber-600" aria-label="Waiting material" />}
        <span className="truncate">{mo.manufacturing_order_no}</span>
      </div>
    </div>
  );
}

// Droppable day cell: id = day-{idx}
function DroppableDay({
  id,
  day,
  isCurrentMonth,
  isToday,
  children,
  loadPct,
}: {
  id: string;
  day: Date;
  isCurrentMonth: boolean;
  isToday: boolean;
  children: React.ReactNode;
  loadPct?: number;
}) {
  const { setNodeRef, isOver } = useDroppable({ id, data: { day } });
  return (
    <div
      ref={setNodeRef}
      className={`min-h-[100px] p-1.5 flex flex-col gap-1 ${
        isCurrentMonth ? 'bg-white' : 'bg-gray-50'
      } ${isToday ? 'ring-1 ring-inset ring-blue-400' : ''} ${isOver ? 'ring-2 ring-inset ring-blue-400 bg-blue-50/50' : ''}`}
    >
      <span className={`text-xs font-medium ${isCurrentMonth ? 'text-gray-700' : 'text-gray-400'} ${isToday ? 'text-blue-600' : ''}`}>
        {day.getDate()}
      </span>
      <div className="flex-1 flex flex-col gap-1 overflow-auto">{children}</div>
      {loadPct != null && (
        <div className="h-1 bg-gray-200 rounded overflow-hidden" title={`Load: ${Math.round(loadPct)}%`}>
          <div className="h-full bg-blue-400 rounded" style={{ width: `${Math.min(100, loadPct)}%` }} />
        </div>
      )}
    </div>
  );
}

type StatusFilterOpt = { key: string; label: string; statuses?: readonly string[]; virtual?: boolean };
const STATUS_FILTER_OPTIONS: StatusFilterOpt[] = [
  { key: 'planned', label: 'Pre-Production', statuses: ['draft', 'confirmed', 'procurement', 'material_available', 'materials_ready'] },
  { key: 'in_production', label: 'In Production', statuses: ['in_production', 'quality_check', 'ready_for_pickup'] },
  { key: 'completed', label: 'Completed', statuses: ['delivered', 'completed'] },
  { key: 'late', label: 'Late', virtual: true },
];

export default function ProductionCalendar() {
  const filteredSubmodules = useFilteredMfgSubmodules();
  const addNotification = useUIStore((s) => s.addNotification);
  const { registerSubmodules } = useSubmoduleNav();
  const { dealers } = useDealers();
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    registerSubmodules('Manufacturing', filteredSubmodules);
  }, [registerSubmodules, filteredSubmodules]);
  const [dealerFilter, setDealerFilter] = useState<string | null>(null);
  const [statusTab, setStatusTab] = useState<'all' | 'planned' | 'in_production' | 'completed' | 'late'>('all');
  const { manufacturingOrders, loading, error, refetch } = useManufacturingOrders(dealerFilter ?? undefined);
  const { updateManufacturingOrder } = useUpdateManufacturingOrder();
  const [monthCursor, setMonthCursor] = useState(() => toMonthStart(new Date()));
  const [materialReadinessMap, setMaterialReadinessMap] = useState<Record<string, { status: string; has_shortage: boolean }>>({});
  const justDroppedRef = useRef(false);
  const [viewMode, setViewMode] = useState<'order' | 'work_center'>('order');
  const [calendarViewMode, setCalendarViewMode] = useState<'month' | 'week' | 'gantt'>('month');
  const { centers: workCenters } = useWorkCenters();
  const [wcToMoIds, setWcToMoIds] = useState<Record<string, Set<string>>>({});
  const [calendarTaskRows, setCalendarTaskRows] = useState<Array<{
    id: string;
    manufacturing_order_id: string;
    work_center_id: string | null;
    planned_start_at: string | null;
    planned_end_at: string | null;
    estimated_duration_hours: number | null;
  }>>([]);
  const [ganttTasks, setGanttTasks] = useState<Record<string, { id: string; wc_name: string; wc_code: string; status: string; planned_start_at: string | null; planned_end_at: string | null }[]>>({});

  const monthStart = useMemo(() => toMonthStart(monthCursor), [monthCursor]);
  const monthEnd = useMemo(() => {
    const d = new Date(monthStart.getFullYear(), monthStart.getMonth() + 1, 0, 23, 59, 59);
    return d;
  }, [monthStart]);

  const calendarWorkloadRange = useMemo(() => ({
    from: monthStart,
    to: monthEnd,
  }), [monthStart, monthEnd]);

  const {
    workCenters: wlWorkCenters,
    workload: calendarWorkload,
  } = useWorkCenterWorkload(activeOrganizationId, calendarWorkloadRange);

  const calendarDays = useMemo(() => {
    const start = toMonthStart(monthCursor);
    const firstWeekday = (start.getDay() + 6) % 7;
    const gridStart = new Date(start);
    gridStart.setDate(start.getDate() - firstWeekday);
    return Array.from({ length: 42 }, (_, idx) => {
      const d = new Date(gridStart);
      d.setDate(gridStart.getDate() + idx);
      return d;
    });
  }, [monthCursor]);

  const weekDays = useMemo(() => {
    const d = new Date(monthCursor);
    const dayOfWeek = (d.getDay() + 6) % 7;
    const monday = new Date(d);
    monday.setDate(d.getDate() - dayOfWeek);
    return Array.from({ length: 7 }, (_, i) => {
      const day = new Date(monday);
      day.setDate(monday.getDate() + i);
      return day;
    });
  }, [monthCursor]);

  const displayDays = calendarViewMode === 'week' ? weekDays : calendarDays;

  const today = useMemo(() => new Date(), []);

  const statusOptionCounts = useMemo(() => {
    const base = manufacturingOrders.filter(
      (mo) => mo.planned_start_at && mo.planned_end_at && !['cancelled'].includes(mo.status)
    );
    const isLateMo = (mo: ManufacturingOrder) =>
      !!(
        mo.planned_end_at &&
        parseIsoDate(mo.planned_end_at) < today &&
        !['delivered', 'completed'].includes(mo.status)
      );
    const counts: Record<string, number> = {};
    for (const opt of STATUS_FILTER_OPTIONS) {
      counts[opt.key] = base.filter((mo) => {
        if (opt.virtual && opt.key === 'late') return isLateMo(mo);
        return !!opt.statuses?.includes(mo.status);
      }).length;
    }
    return counts;
  }, [manufacturingOrders, today]);

  const statusTabs = useMemo(
    () => [
      {
        label: 'All',
        value: 'all',
        count: manufacturingOrders.filter((mo) => mo.planned_start_at && mo.planned_end_at && !['cancelled'].includes(mo.status)).length,
      },
      ...STATUS_FILTER_OPTIONS.map((opt) => ({
        label: opt.label,
        value: opt.key,
        count: statusOptionCounts[opt.key] ?? 0,
      })),
    ],
    [statusOptionCounts, manufacturingOrders]
  );

  const scheduledMOs = useMemo(() => {
    let list = manufacturingOrders.filter(
      (mo) =>
        mo.planned_start_at &&
        mo.planned_end_at &&
        !['cancelled'].includes(mo.status)
    );
    if (statusTab === 'all') return list;
    const selected = STATUS_FILTER_OPTIONS.find((opt) => opt.key === statusTab);
    if (!selected) return list;
    list = list.filter((mo) => {
      const isLate =
        mo.planned_end_at &&
        parseIsoDate(mo.planned_end_at) < today &&
        !['delivered', 'completed'].includes(mo.status);
      if (selected.virtual && selected.key === 'late') return Boolean(isLate);
      return Boolean(selected.statuses?.includes(mo.status));
    });
    return list;
  }, [manufacturingOrders, statusTab, today]);

  const moUrgencyMap = useMemo(() => {
    const map = new Map<string, string>();
    for (const mo of scheduledMOs) {
      if (['completed', 'delivered', 'cancelled'].includes(mo.status)) continue;
      const dueDate = mo.SalesOrders?.expected_delivery_date
        ? new Date(mo.SalesOrders.expected_delivery_date) : null;
      if (dueDate && today > dueDate) {
        map.set(mo.id, 'critical');
      } else if (dueDate) {
        const daysLeft = (dueDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24);
        if (daysLeft <= 2) map.set(mo.id, 'at_risk');
      }
    }
    return map;
  }, [scheduledMOs, today]);

  const moTaskDayMap = useMemo(() => {
    const map = new Map<string, Set<string>>();
    for (const t of calendarTaskRows) {
      if (!t.manufacturing_order_id || !t.planned_start_at) continue;
      const keys = workedDayKeys(t.planned_start_at, t.estimated_duration_hours, t.planned_end_at);
      if (!map.has(t.manufacturing_order_id)) map.set(t.manufacturing_order_id, new Set());
      const bucket = map.get(t.manufacturing_order_id)!;
      for (const k of keys) bucket.add(k);
    }
    return map;
  }, [calendarTaskRows]);

  const wcTaskDayMap = useMemo(() => {
    const map = new Map<string, Map<string, Set<string>>>();
    for (const t of calendarTaskRows) {
      if (!t.work_center_id || !t.manufacturing_order_id || !t.planned_start_at) continue;
      const keys = workedDayKeys(t.planned_start_at, t.estimated_duration_hours, t.planned_end_at);
      if (!map.has(t.work_center_id)) map.set(t.work_center_id, new Map());
      const byDay = map.get(t.work_center_id)!;
      for (const k of keys) {
        if (!byDay.has(k)) byDay.set(k, new Set());
        byDay.get(k)!.add(t.manufacturing_order_id);
      }
    }
    return map;
  }, [calendarTaskRows]);


  const getMOsForDay = (day: Date) =>
    scheduledMOs.filter((mo) => {
      const days = moTaskDayMap.get(mo.id);
      if (days && days.size > 0) return days.has(dayKeyLocal(day));
      return dayInRange(day, mo.planned_start_at ?? null, mo.planned_end_at ?? null);
    });

  const loadPerDay = useMemo(() => {
    return displayDays.map((day) => getMOsForDay(day).length);
  }, [displayDays, scheduledMOs]);
  const maxLoad = Math.max(1, ...loadPerDay);

  const moIdsInMonth = useMemo(() => {
    const ids: string[] = [];
    const start = new Date(monthStart.getTime());
    const end = new Date(monthEnd.getTime());
    for (const mo of scheduledMOs) {
      const moStart = new Date(mo.planned_start_at!);
      const moEnd = new Date(mo.planned_end_at!);
      if (moEnd >= start && moStart <= end) ids.push(mo.id);
    }
    return ids;
  }, [scheduledMOs, monthStart, monthEnd]);

  useEffect(() => {
    if (moIdsInMonth.length === 0) {
      setMaterialReadinessMap({});
      return;
    }
    supabase
      .rpc('get_mo_material_readiness_batch', { p_mo_ids: moIdsInMonth })
      .then(({ data, error: err }: { data: unknown; error: unknown }) => {
        if (err || !Array.isArray(data)) {
          setMaterialReadinessMap({});
          return;
        }
        const map: Record<string, { status: string; has_shortage: boolean }> = {};
        for (const row of data as { mo_id: string; status: string; has_shortage: boolean }[]) {
          if (row?.mo_id) map[row.mo_id] = { status: row.status ?? 'incomplete', has_shortage: Boolean(row.has_shortage) };
        }
        setMaterialReadinessMap(map);
      });
  }, [moIdsInMonth.join(',')]);

  useEffect(() => {
    if (moIdsInMonth.length === 0) {
      setCalendarTaskRows([]);
      return;
    }
    supabase
      .from('WorkOrderTasks')
      .select('id, manufacturing_order_id, work_center_id, planned_start_at, planned_end_at, estimated_duration_hours')
      .in('manufacturing_order_id', moIdsInMonth)
      .eq('deleted', false)
      .then(({ data, error: err }: { data: unknown; error: unknown }) => {
        if (err || !Array.isArray(data)) {
          setCalendarTaskRows([]);
          return;
        }
        setCalendarTaskRows(data as Array<{
          id: string;
          manufacturing_order_id: string;
          work_center_id: string | null;
          planned_start_at: string | null;
          planned_end_at: string | null;
          estimated_duration_hours: number | null;
        }>);
      });
  }, [moIdsInMonth.join(',')]);

  useEffect(() => {
    if (viewMode !== 'work_center' || moIdsInMonth.length === 0) {
      setWcToMoIds({});
      return;
    }
    supabase
      .from('WorkOrderTasks')
      .select('manufacturing_order_id, work_center_id')
      .in('manufacturing_order_id', moIdsInMonth)
      .eq('deleted', false)
      .then(({ data, error: err }: { data: unknown; error: unknown }) => {
        if (err || !Array.isArray(data)) {
          setWcToMoIds({});
          return;
        }
        const map: Record<string, Set<string>> = {};
        for (const row of data as { manufacturing_order_id: string; work_center_id: string }[]) {
          if (!row?.work_center_id || !row?.manufacturing_order_id) continue;
          if (!map[row.work_center_id]) map[row.work_center_id] = new Set();
          map[row.work_center_id].add(row.manufacturing_order_id);
        }
        setWcToMoIds(map);
      });
  }, [viewMode, moIdsInMonth.join(',')]);

  useEffect(() => {
    if (calendarViewMode !== 'gantt' || moIdsInMonth.length === 0) {
      setGanttTasks({});
      return;
    }
    (async () => {
      const { data: taskData, error: tErr } = await supabase
        .from('WorkOrderTasks')
        .select('id, manufacturing_order_id, work_center_id, status, planned_start_at, planned_end_at, sequence')
        .in('manufacturing_order_id', moIdsInMonth)
        .eq('deleted', false)
        .order('sequence');
      if (tErr || !taskData) { setGanttTasks({}); return; }

      const wcIds = [...new Set(taskData.map((t: any) => t.work_center_id).filter(Boolean))];
      let wcLookup: Record<string, { name: string; code: string }> = {};
      if (wcIds.length > 0) {
        const { data: wcData } = await supabase
          .from('WorkCenters')
          .select('id, name, code')
          .in('id', wcIds);
        if (wcData) {
          for (const wc of wcData) wcLookup[wc.id] = { name: wc.name, code: wc.code };
        }
      }

      const map: Record<string, typeof ganttTasks[string]> = {};
      for (const t of taskData as any[]) {
        const moId = t.manufacturing_order_id;
        if (!map[moId]) map[moId] = [];
        const wc = wcLookup[t.work_center_id];
        map[moId].push({
          id: t.id,
          wc_name: wc?.name ?? 'Station',
          wc_code: wc?.code ?? '',
          status: t.status,
          planned_start_at: t.planned_start_at,
          planned_end_at: t.planned_end_at,
        });
      }
      setGanttTasks(map);
    })();
  }, [calendarViewMode, moIdsInMonth.join(',')]);

  const unscheduledMOs = useMemo(() => {
    return manufacturingOrders.filter(
      (mo) =>
        mo.status !== 'cancelled' &&
        (!mo.planned_start_at || !mo.planned_end_at)
    );
  }, [manufacturingOrders]);

  const getMOsForDayAndWC = (day: Date, wcId: string) => {
    const moIds = wcToMoIds[wcId];
    const dayMap = wcTaskDayMap.get(wcId);
    const key = dayKeyLocal(day);
    return scheduledMOs.filter((mo) => {
      const byTasks = dayMap?.get(key);
      if (byTasks && byTasks.size > 0) return byTasks.has(mo.id);
      if (!moIds || moIds.size === 0) return false;
      return moIds.has(mo.id) && dayInRange(day, mo.planned_start_at ?? null, mo.planned_end_at ?? null);
    });
  };

  const handleDragEnd = useCallback(
    async (event: DragEndEvent) => {
      const { active, over } = event;
      if (!over || over.id === active.id) return;
      const moId = String(active.id);
      const overId = String(over.id);
      let idx: number;
      if (overId.startsWith('wc-') && overId.includes('-day-')) {
        const dayPart = overId.split('-day-')[1];
        idx = parseInt(dayPart ?? '', 10);
      } else if (overId.startsWith('day-')) {
        idx = parseInt(overId.replace('day-', ''), 10);
      } else return;
      if (Number.isNaN(idx) || idx < 0 || idx >= calendarDays.length) return;
      const targetDay = calendarDays[idx];
      const mo = scheduledMOs.find((m) => m.id === moId);
      if (!mo?.planned_start_at || !mo?.planned_end_at) return;
      const readiness = materialReadinessMap[moId];
      const materialIncomplete = Boolean(readiness?.status === 'incomplete' || readiness?.has_shortage);
      if (materialIncomplete) {
        addNotification({
          type: 'warning',
          title: 'Materials Incomplete',
          message: 'Resolve Material Demand before scheduling this MO.',
        });
        return;
      }
      const { planned_start_at, planned_end_at } = moveMoToDay(mo, targetDay);
      justDroppedRef.current = true;
      setTimeout(() => { justDroppedRef.current = false; }, 300);
      try {
        await updateManufacturingOrder(moId, { planned_start_at, planned_end_at });
        addNotification({ type: 'success', title: 'Schedule updated', message: `${mo.manufacturing_order_no} moved to ${formatDate(targetDay)}.` });
        refetch();
      } catch (err) {
        const msg = err instanceof Error ? err.message : 'Failed to update schedule';
        addNotification({ type: 'error', title: 'Error', message: msg });
      }
    },
    [calendarDays, scheduledMOs, updateManufacturingOrder, refetch, addNotification, materialReadinessMap]
  );

  const goPrev = () => setMonthCursor((d) => new Date(d.getFullYear(), d.getMonth() - 1, 1));
  const goNext = () => setMonthCursor((d) => new Date(d.getFullYear(), d.getMonth() + 1, 1));

  const handleAutoSchedule = useCallback(async () => {
    const schedulableStatuses = new Set(['draft', 'confirmed', 'procurement', 'material_available', 'materials_ready']);
    const toSchedule = manufacturingOrders.filter((mo) => {
      if (!schedulableStatuses.has(mo.status)) return false;
      const readiness = materialReadinessMap[mo.id];
      return !(readiness?.status === 'incomplete' || readiness?.has_shortage);
    });
    const skippedIncomplete = manufacturingOrders.filter((mo) => {
      const readiness = materialReadinessMap[mo.id];
      return mo.status !== 'cancelled' && Boolean(readiness?.status === 'incomplete' || readiness?.has_shortage);
    }).length;
    if (toSchedule.length === 0) {
      addNotification({ type: 'warning', title: 'Auto Schedule', message: 'No MOs eligible for scheduling. Resolve Material Demand first.' });
      return;
    }
    const withDeadline = toSchedule
      .filter((mo) => mo.SalesOrders?.expected_delivery_date)
      .sort((a, b) => {
        const da = new Date(a.SalesOrders!.expected_delivery_date!).getTime();
        const db = new Date(b.SalesOrders!.expected_delivery_date!).getTime();
        if (da !== db) return da - db;
        const order = { urgent: 0, high: 1, normal: 2, low: 3 };
        return (order[a.priority as keyof typeof order] ?? 2) - (order[b.priority as keyof typeof order] ?? 2);
      });
    const noDeadline = toSchedule.filter((mo) => !mo.SalesOrders?.expected_delivery_date);
    const sorted = [...withDeadline, ...noDeadline];
    const oneDayMs = 24 * 60 * 60 * 1000;

    type Interval = { start: Date; end: Date };
    const toScheduleIds = new Set(sorted.map((m) => m.id));
    const busyIntervals: Interval[] = manufacturingOrders
      .filter(
        (mo) =>
          !toScheduleIds.has(mo.id) &&
          !!mo.planned_start_at &&
          !!mo.planned_end_at &&
          mo.status !== 'cancelled'
      )
      .map((mo) => ({
        start: parseIsoDate(mo.planned_start_at!),
        end: parseIsoDate(mo.planned_end_at!),
      }));

    // Always schedule from "today". If labor hours are over, move to next workday.
    let cursor = new Date();
    const normalizeCursor = (d: Date) => {
      const dayStart = new Date(d);
      dayStart.setHours(8, 0, 0, 0);
      const dayEnd = new Date(d);
      dayEnd.setHours(17, 0, 0, 0);
      if (d < dayStart) return dayStart;
      if (d >= dayEnd) {
        const next = new Date(d);
        next.setDate(next.getDate() + 1);
        next.setHours(8, 0, 0, 0);
        return next;
      }
      return d;
    };
    const skipWeekend = (d: Date) => {
      while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() + 1);
    };
    const overlapsBusy = (start: Date, end: Date): boolean =>
      busyIntervals.some((it) => start < it.end && end > it.start);

    cursor = normalizeCursor(cursor);
    skipWeekend(cursor);
    cursor = normalizeCursor(cursor);
    for (const mo of sorted) {
      const durationMs = mo.planned_start_at && mo.planned_end_at
        ? parseIsoDate(mo.planned_end_at).getTime() - parseIsoDate(mo.planned_start_at).getTime()
        : oneDayMs;
      const safeDurationMs = durationMs > 0 ? durationMs : oneDayMs;
      let startCandidate = new Date(cursor);
      let endCandidate = new Date(startCandidate.getTime() + safeDurationMs);

      // Move forward until we find a free slot (no overlap with existing busy ranges).
      while (overlapsBusy(startCandidate, endCandidate)) {
        startCandidate.setDate(startCandidate.getDate() + 1);
        startCandidate.setHours(8, 0, 0, 0);
        skipWeekend(startCandidate);
        startCandidate = normalizeCursor(startCandidate);
        endCandidate = new Date(startCandidate.getTime() + safeDurationMs);
      }

      try {
        await updateManufacturingOrder(mo.id, {
          planned_start_at: startCandidate.toISOString(),
          planned_end_at: endCandidate.toISOString(),
        });
      } catch (err) {
        addNotification({ type: 'error', title: 'Auto Schedule', message: (err as Error).message });
        return;
      }
      busyIntervals.push({ start: new Date(startCandidate), end: new Date(endCandidate) });
      cursor = new Date(endCandidate.getTime());
      cursor = normalizeCursor(cursor);
      skipWeekend(cursor);
      cursor = normalizeCursor(cursor);
    }
    addNotification({
      type: 'success',
      title: 'Auto Schedule',
      message: skippedIncomplete > 0
        ? `${sorted.length} MO(s) scheduled. ${skippedIncomplete} skipped due to incomplete materials.`
        : `${sorted.length} MO(s) scheduled.`,
    });
    refetch();
  }, [manufacturingOrders, updateManufacturingOrder, refetch, addNotification, materialReadinessMap]);

  const renderBlock = (mo: ManufacturingOrder, day: Date) => {
    const isLate = !!(
      mo.planned_end_at &&
      parseIsoDate(mo.planned_end_at) < today &&
      !['delivered', 'completed'].includes(mo.status)
    );
    const readiness = materialReadinessMap[mo.id];
    const materialIncomplete = Boolean(readiness?.status === 'incomplete' || readiness?.has_shortage);
    const variant = getBlockVariant(mo, isLate, materialIncomplete);
    const expectedDelivery = mo.SalesOrders?.expected_delivery_date ? new Date(mo.SalesOrders.expected_delivery_date) : null;
    const showDeadline = expectedDelivery && isSameDay(day, expectedDelivery);
    const moUrgency = moUrgencyMap.get(mo.id);
    return (
      <DraggableBlock
        key={mo.id}
        mo={mo}
        variant={variant}
        showDeadline={!!showDeadline}
        isLate={!!isLate}
        materialIncomplete={!!materialIncomplete}
        onNavigate={(id) => router.navigate(`/manufacturing/manufacturing-orders/${id}`)}
        justDroppedRef={justDroppedRef}
        urgency={moUrgency}
        dimmed={false}
      />
    );
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-10 bg-gray-200 rounded" />
          <div className="h-96 bg-gray-200 rounded" />
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6 text-red-600">
        {error}
      </div>
    );
  }

  const monthLabel = monthCursor.toLocaleDateString(undefined, { month: 'long', year: 'numeric' });

  return (
    <div className="p-6 space-y-4">
      <div className="rounded-lg border border-gray-200 bg-white p-4">
        <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
          <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
            <CalendarDays className="w-5 h-5 text-gray-500" />
            Production Calendar
          </h2>
          <div className="flex flex-wrap items-center gap-4">
            <div className="flex items-center gap-2">
              <Filter className="w-4 h-4 text-gray-500" />
              <label htmlFor="calendar-dealer" className="text-sm text-gray-600">Dealer</label>
              <select
                id="calendar-dealer"
                value={dealerFilter === null ? 'all' : dealerFilter}
                onChange={(e) => setDealerFilter(e.target.value === 'all' ? null : e.target.value || null)}
                className="text-sm border border-gray-300 rounded-md px-2 py-1.5 bg-white min-w-[140px]"
              >
                <option value="all">All</option>
                {dealers.map((d) => (
                  <option key={d.id} value={d.id}>{d.dealer_name}</option>
                ))}
              </select>
            </div>
            <div className="flex items-center gap-3">
              <span className="text-sm text-gray-600">View</span>
              <div className="flex rounded-md border border-gray-300 bg-white overflow-hidden">
                <button
                  type="button"
                  onClick={() => setViewMode('order')}
                  className={`px-3 py-1.5 text-sm font-medium ${viewMode === 'order' ? 'bg-gray-100 text-gray-900' : 'text-gray-600 hover:bg-gray-50'}`}
                >
                  By order
                </button>
                <button
                  type="button"
                  onClick={() => setViewMode('work_center')}
                  className={`px-3 py-1.5 text-sm font-medium ${viewMode === 'work_center' ? 'bg-gray-100 text-gray-900' : 'text-gray-600 hover:bg-gray-50'}`}
                >
                  By Work Center
                </button>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <span className="text-sm text-gray-600">Calendar</span>
              <div className="flex rounded-md border border-gray-300 bg-white overflow-hidden">
                <button
                  type="button"
                  onClick={() => setCalendarViewMode('month')}
                  className={`flex items-center gap-1 px-3 py-1.5 text-sm font-medium ${calendarViewMode === 'month' ? 'bg-gray-100 text-gray-900' : 'text-gray-600 hover:bg-gray-50'}`}
                  title="Month"
                >
                  <Calendar className="w-3.5 h-3.5" /> Month
                </button>
                <button
                  type="button"
                  onClick={() => setCalendarViewMode('week')}
                  className={`flex items-center gap-1 px-3 py-1.5 text-sm font-medium ${calendarViewMode === 'week' ? 'bg-gray-100 text-gray-900' : 'text-gray-600 hover:bg-gray-50'}`}
                  title="Week"
                >
                  <Calendar className="w-3.5 h-3.5" /> Week
                </button>
                <button
                  type="button"
                  onClick={() => setCalendarViewMode('gantt')}
                  className={`flex items-center gap-1 px-3 py-1.5 text-sm font-medium ${calendarViewMode === 'gantt' ? 'bg-gray-100 text-gray-900' : 'text-gray-600 hover:bg-gray-50'}`}
                  title="Gantt"
                >
                  <GanttChart className="w-3.5 h-3.5" /> Gantt
                </button>
              </div>
            </div>
            <button
              type="button"
              onClick={handleAutoSchedule}
              className="flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-md border border-gray-300 bg-white hover:bg-gray-50 text-gray-700"
              title="Auto Schedule Production"
            >
              <Zap className="w-3.5 h-3.5" /> Auto Schedule
            </button>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={goPrev}
                className="p-2 rounded border border-gray-300 bg-white hover:bg-gray-50"
                aria-label="Previous month"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              <span className="min-w-[180px] text-center font-medium text-gray-700 capitalize">
                {monthLabel}
              </span>
              <button
                type="button"
                onClick={goNext}
                className="p-2 rounded border border-gray-300 bg-white hover:bg-gray-50"
                aria-label="Next month"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>
        <div className="mb-4 flex flex-wrap items-start gap-3">
          <div className="min-w-[360px] flex-1">
            <StatusTabs tabs={statusTabs} activeTab={statusTab} onChange={(v) => setStatusTab(v as typeof statusTab)} />
          </div>
        </div>

        <DndContext onDragEnd={handleDragEnd}>
          {calendarViewMode === 'gantt' ? (() => {
            const rangeStart = new Date(monthStart.getFullYear(), monthStart.getMonth(), 1, 0, 0, 0);
            const rangeEnd = new Date(monthEnd.getTime() + 24 * 60 * 60 * 1000);
            const totalMs = rangeEnd.getTime() - rangeStart.getTime();
            const daysInRange = Math.ceil(totalMs / 86_400_000);
            const dayHeaders = Array.from({ length: daysInRange }, (_, i) => {
              const d = new Date(rangeStart);
              d.setDate(d.getDate() + i);
              return d;
            });

            const TASK_BAR_COLORS: Record<string, string> = {
              completed: 'bg-green-400',
              in_progress: 'bg-blue-400',
              pending: 'bg-gray-300',
            };

            return (
              <div className="rounded-lg border border-gray-200 overflow-hidden">
                <div className="overflow-x-auto">
                  <div className="min-w-[800px]">
                    {/* Day column headers */}
                    <div className="flex border-b border-gray-200">
                      <div className="w-36 shrink-0 bg-gray-50 px-2 py-1 text-[10px] font-medium text-gray-500 border-r border-gray-200" />
                      <div className="flex-1 flex">
                        {dayHeaders.map((d, i) => {
                          const isWeekend = d.getDay() === 0 || d.getDay() === 6;
                          const isTodayCol = isSameDay(d, today);
                          return (
                            <div
                              key={i}
                              className={`flex-1 text-center text-[9px] leading-tight py-1 border-r border-gray-100 last:border-r-0 ${isWeekend ? 'bg-gray-50 text-gray-300' : isTodayCol ? 'bg-blue-50 text-blue-600 font-semibold' : 'text-gray-500'}`}
                              style={{ minWidth: 20 }}
                            >
                              <div>{d.toLocaleDateString(undefined, { weekday: 'narrow' })}</div>
                              <div>{d.getDate()}</div>
                            </div>
                          );
                        })}
                      </div>
                    </div>

                    {/* MO rows with WO task sub-rows */}
                    {scheduledMOs.map((mo) => {
                      const start = mo.planned_start_at ? parseIsoDate(mo.planned_start_at) : null;
                      const end = mo.planned_end_at ? parseIsoDate(mo.planned_end_at) : null;
                      const isLate = end && end < today && !['delivered', 'completed'].includes(mo.status);
                      const readiness = materialReadinessMap[mo.id];
                      const materialIncomplete = readiness?.status === 'incomplete' || readiness?.has_shortage;
                      const variant = getBlockVariant(mo, !!isLate, !!materialIncomplete);
                      const leftPct = start && totalMs > 0 ? ((start.getTime() - rangeStart.getTime()) / totalMs) * 100 : 0;
                      const widthPct = start && end && totalMs > 0 ? ((end.getTime() - start.getTime()) / totalMs) * 100 : 10;
                      const tasks = ganttTasks[mo.id] ?? [];
                      const hasScheduledTasks = tasks.some((t) => t.planned_start_at && t.planned_end_at);

                      return (
                        <div key={mo.id} className="border-b border-gray-100 last:border-0">
                          {/* MO bar */}
                          <div className="flex items-center gap-0">
                            <button
                              type="button"
                              onClick={() => router.navigate(`/manufacturing/manufacturing-orders/${mo.id}`)}
                              className="w-36 shrink-0 text-left text-xs font-medium text-blue-600 hover:underline truncate px-2 py-1.5 border-r border-gray-200"
                            >
                              {mo.manufacturing_order_no}
                            </button>
                            <div className="flex-1 h-6 relative bg-gray-50 rounded-sm">
                              <button
                                type="button"
                                onClick={() => router.navigate(`/manufacturing/manufacturing-orders/${mo.id}`)}
                                className={`absolute inset-y-0 rounded-sm ${variant} opacity-70`}
                                style={{ left: `${Math.max(0, leftPct)}%`, width: `${Math.min(100 - leftPct, widthPct)}%` }}
                                title={`${mo.planned_start_at ? formatDate(mo.planned_start_at) : ''} – ${mo.planned_end_at ? formatDate(mo.planned_end_at) : ''}`}
                              />
                            </div>
                          </div>

                          {/* WO task sub-bars */}
                          {hasScheduledTasks && tasks.map((task) => {
                            if (!task.planned_start_at || !task.planned_end_at) return null;
                            const tStart = new Date(task.planned_start_at);
                            const tEnd = new Date(task.planned_end_at);
                            const tLeftPct = totalMs > 0 ? ((tStart.getTime() - rangeStart.getTime()) / totalMs) * 100 : 0;
                            const tWidthPct = totalMs > 0 ? ((tEnd.getTime() - tStart.getTime()) / totalMs) * 100 : 2;
                            return (
                              <div key={task.id} className="flex items-center gap-0">
                                <div className="w-36 shrink-0 text-right text-[10px] text-gray-400 truncate px-2 py-0.5 border-r border-gray-200">
                                  {task.wc_name}
                                </div>
                                <div className="flex-1 h-4 relative">
                                  <div
                                    className={`absolute top-0.5 bottom-0.5 rounded-sm ${TASK_BAR_COLORS[task.status] ?? 'bg-gray-300'}`}
                                    style={{ left: `${Math.max(0, tLeftPct)}%`, width: `${Math.max(0.5, Math.min(100 - tLeftPct, tWidthPct))}%` }}
                                    title={`${task.wc_name}: ${formatDate(task.planned_start_at)} – ${formatDate(task.planned_end_at)} (${task.status})`}
                                  />
                                </div>
                              </div>
                            );
                          })}
                        </div>
                      );
                    })}

                    {scheduledMOs.length === 0 && (
                      <p className="text-sm text-gray-500 py-4 text-center">No scheduled orders in this month.</p>
                    )}
                  </div>
                </div>

                {/* Gantt legend */}
                <div className="flex items-center gap-4 px-4 py-2 border-t border-gray-100 text-[10px] text-gray-500">
                  <div className="flex items-center gap-1"><div className="w-3 h-2 rounded bg-gray-300" /> Pending</div>
                  <div className="flex items-center gap-1"><div className="w-3 h-2 rounded bg-blue-400" /> In Progress</div>
                  <div className="flex items-center gap-1"><div className="w-3 h-2 rounded bg-green-400" /> Completed</div>
                </div>
              </div>
            );
          })()
          : viewMode === 'order' ? (
            <div className="grid grid-cols-7 gap-px bg-gray-200 rounded-lg overflow-hidden border border-gray-200">
              {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((wd) => (
                <div key={wd} className="bg-gray-50 p-1.5 text-center text-xs font-medium text-gray-600">
                  {wd}
                </div>
              ))}
              {displayDays.map((day, idx) => {
                const isCurrentMonth = day.getMonth() === monthCursor.getMonth();
                const isToday = isSameDay(day, today);
                const moList = getMOsForDay(day);
                const loadPct = maxLoad > 0 ? (loadPerDay[idx] ?? 0) / maxLoad * 100 : 0;
                return (
                  <DroppableDay
                    key={idx}
                    id={`day-${idx}`}
                    day={day}
                    isCurrentMonth={isCurrentMonth}
                    isToday={isToday}
                    loadPct={loadPct}
                  >
                    {moList.map((mo) => renderBlock(mo, day))}
                  </DroppableDay>
                );
              })}
            </div>
          ) : (
            <div className="space-y-4">
              {workCenters.map((wc) => (
                <div key={wc.id} className="rounded-lg border border-gray-200 overflow-hidden">
                  <div className="bg-gray-100 px-3 py-2 text-sm font-medium text-gray-800 border-b border-gray-200">
                    {wc.name}
                  </div>
                  <div className="grid grid-cols-7 gap-px bg-gray-200">
                    {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((wd) => (
                      <div key={wd} className="bg-gray-50 p-1 text-center text-xs font-medium text-gray-600">
                        {wd}
                      </div>
                    ))}
                    {calendarDays.map((day, idx) => {
                      const isCurrentMonth = day.getMonth() === monthCursor.getMonth();
                      const isToday = isSameDay(day, today);
                      const moList = getMOsForDayAndWC(day, wc.id);
                      return (
                        <DroppableDay
                          key={idx}
                          id={`wc-${wc.id}-day-${idx}`}
                          day={day}
                          isCurrentMonth={isCurrentMonth}
                          isToday={isToday}
                        >
                          {moList.map((mo) => renderBlock(mo, day))}
                        </DroppableDay>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          )}
        </DndContext>
      </div>

      {wlWorkCenters.length > 0 && (
        <WorkloadHeatmap
          workCenters={wlWorkCenters}
          workload={calendarWorkload}
          startDate={monthStart}
          days={Math.ceil((monthEnd.getTime() - monthStart.getTime()) / 86_400_000) + 1}
        />
      )}

      {unscheduledMOs.length > 0 && (
        <div className="rounded-lg border border-gray-200 bg-white p-4">
          <h3 className="text-sm font-semibold text-gray-900 mb-2">Sin programar</h3>
          <ul className="space-y-1">
            {unscheduledMOs.slice(0, 20).map((mo) => (
              <li key={mo.id}>
                <button
                  type="button"
                  onClick={() =>
                    router.navigate(`/manufacturing/manufacturing-orders/${mo.id}`)
                  }
                  className="text-sm text-blue-600 hover:underline"
                >
                  {mo.manufacturing_order_no}
                  {mo.product_name ? ` · ${mo.product_name}` : ''}
                  {mo.quantity != null ? ` × ${mo.quantity}` : ''}
                </button>
              </li>
            ))}
            {unscheduledMOs.length > 20 && (
              <li className="text-sm text-gray-500">
                … y {unscheduledMOs.length - 20} más
              </li>
            )}
          </ul>
        </div>
      )}
    </div>
  );
}
