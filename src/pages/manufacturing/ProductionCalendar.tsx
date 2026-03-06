import { useMemo, useState, useEffect, useRef, useCallback } from 'react';
import { ChevronLeft, ChevronRight, CalendarDays, Filter, AlertCircle, Package, GanttChart, Calendar, Zap } from 'lucide-react';
import { DndContext, useDraggable, useDroppable, type DragEndEvent } from '@dnd-kit/core';
import { router } from '../../lib/router';
import { useManufacturingOrders, useUpdateManufacturingOrder } from '../../hooks/useManufacturing';
import type { ManufacturingOrder } from '../../hooks/useManufacturing';
import { supabase } from '../../lib/supabase/client';
import { useDealers } from '../../hooks/useDealers';
import { useWorkCenters } from '../../hooks/useWorkCenters';
import { useUIStore } from '../../stores/ui-store';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { MANUFACTURING_SUBMODULES } from './manufacturingSubmodules';

function toMonthStart(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), 1);
}

function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function dayInRange(day: Date, startIso: string | null, endIso: string | null): boolean {
  if (!startIso || !endIso) return false;
  const start = new Date(startIso);
  const end = new Date(endIso);
  const dStart = new Date(day.getFullYear(), day.getMonth(), day.getDate(), 0, 0, 0);
  const dEnd = new Date(day.getFullYear(), day.getMonth(), day.getDate(), 23, 59, 59);
  return dStart <= end && dEnd >= start;
}

function getBlockVariant(mo: ManufacturingOrder, isLate: boolean, materialIncomplete: boolean): string {
  if (mo.status === 'cancelled') return 'bg-gray-100 border-gray-200 text-gray-500';
  if (materialIncomplete) return 'bg-amber-50 border-amber-300 text-amber-900';
  if (isLate) return 'bg-red-50 border-red-300 text-red-900';
  switch (mo.status) {
    case 'draft':
    case 'planned':
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
  const start = mo.planned_start_at ? new Date(mo.planned_start_at) : new Date();
  const end = mo.planned_end_at ? new Date(mo.planned_end_at) : new Date();
  const durationMs = end.getTime() - start.getTime();
  const newStart = new Date(targetDay.getFullYear(), targetDay.getMonth(), targetDay.getDate(), 0, 0, 0, 0);
  const newEnd = new Date(newStart.getTime() + durationMs);
  return { planned_start_at: newStart.toISOString(), planned_end_at: newEnd.toISOString() };
}

// Draggable block: id = mo.id
function DraggableBlock({
  mo,
  variant,
  showDeadline,
  isLate,
  materialIncomplete,
  onNavigate,
  justDroppedRef,
}: {
  mo: ManufacturingOrder;
  variant: string;
  showDeadline: boolean;
  isLate: boolean;
  materialIncomplete: boolean;
  onNavigate: (id: string) => void;
  justDroppedRef: React.MutableRefObject<boolean>;
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
      } ${isDragging ? 'opacity-60 shadow-md' : ''}`}
      title={`${mo.manufacturing_order_no} · ${mo.status}`}
    >
      <div className="flex items-center gap-1 font-medium truncate">
        {isLate && <AlertCircle className="w-3 h-3 shrink-0 text-red-600" aria-label="Overdue" />}
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
  { key: 'planned', label: 'Planned', statuses: ['draft', 'planned'] },
  { key: 'in_production', label: 'In Production', statuses: ['in_production', 'quality_check', 'ready_for_pickup'] },
  { key: 'completed', label: 'Completed', statuses: ['delivered', 'completed'] },
  { key: 'late', label: 'Late', virtual: true },
];

export default function ProductionCalendar() {
  const addNotification = useUIStore((s) => s.addNotification);
  const { registerSubmodules } = useSubmoduleNav();
  const { dealers } = useDealers();

  useEffect(() => {
    registerSubmodules('Manufacturing', [...MANUFACTURING_SUBMODULES]);
  }, [registerSubmodules]);
  const [dealerFilter, setDealerFilter] = useState<string | null>(null);
  const [statusFilters, setStatusFilters] = useState<Set<string>>(new Set(['planned', 'in_production', 'completed', 'late']));
  const { manufacturingOrders, loading, error, refetch } = useManufacturingOrders(dealerFilter ?? undefined);
  const { updateManufacturingOrder, isUpdating } = useUpdateManufacturingOrder();
  const [monthCursor, setMonthCursor] = useState(() => toMonthStart(new Date()));
  const [materialReadinessMap, setMaterialReadinessMap] = useState<Record<string, { status: string; has_shortage: boolean }>>({});
  const justDroppedRef = useRef(false);
  const [viewMode, setViewMode] = useState<'order' | 'work_center'>('order');
  const [calendarViewMode, setCalendarViewMode] = useState<'month' | 'week' | 'gantt'>('month');
  const { centers: workCenters } = useWorkCenters();
  const [wcToMoIds, setWcToMoIds] = useState<Record<string, Set<string>>>({});

  const monthStart = useMemo(() => toMonthStart(monthCursor), [monthCursor]);
  const monthEnd = useMemo(() => {
    const d = new Date(monthStart.getFullYear(), monthStart.getMonth() + 1, 0, 23, 59, 59);
    return d;
  }, [monthStart]);

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

  const scheduledMOs = useMemo(() => {
    let list = manufacturingOrders.filter(
      (mo) =>
        mo.planned_start_at &&
        mo.planned_end_at &&
        !['cancelled'].includes(mo.status)
    );
    if (statusFilters.size === 0) return list;
    list = list.filter((mo) => {
      const isLate =
        mo.planned_end_at &&
        new Date(mo.planned_end_at) < today &&
        !['delivered', 'completed'].includes(mo.status);
      for (const opt of STATUS_FILTER_OPTIONS) {
        if (!statusFilters.has(opt.key)) continue;
        if (opt.virtual && opt.key === 'late') {
          if (isLate) return true;
          continue;
        }
        if (opt.statuses?.includes(mo.status)) return true;
      }
      return false;
    });
    return list;
  }, [manufacturingOrders, statusFilters, today]);

  const getMOsForDay = (day: Date) =>
    scheduledMOs.filter((mo) =>
      dayInRange(day, mo.planned_start_at ?? null, mo.planned_end_at ?? null)
    );

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

  const unscheduledMOs = useMemo(() => {
    return manufacturingOrders.filter(
      (mo) =>
        mo.status !== 'cancelled' &&
        (!mo.planned_start_at || !mo.planned_end_at)
    );
  }, [manufacturingOrders]);

  const getMOsForDayAndWC = (day: Date, wcId: string) => {
    const moIds = wcToMoIds[wcId];
    if (!moIds || moIds.size === 0) return [];
    return scheduledMOs.filter(
      (mo) =>
        moIds.has(mo.id) &&
        dayInRange(day, mo.planned_start_at ?? null, mo.planned_end_at ?? null)
    );
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
      const { planned_start_at, planned_end_at } = moveMoToDay(mo, targetDay);
      justDroppedRef.current = true;
      setTimeout(() => { justDroppedRef.current = false; }, 300);
      try {
        await updateManufacturingOrder(moId, { planned_start_at, planned_end_at });
        addNotification({ type: 'success', title: 'Schedule updated', message: `${mo.manufacturing_order_no} moved to ${targetDay.toLocaleDateString()}.` });
        refetch();
      } catch (err) {
        const msg = err instanceof Error ? err.message : 'Failed to update schedule';
        addNotification({ type: 'error', title: 'Error', message: msg });
      }
    },
    [calendarDays, scheduledMOs, updateManufacturingOrder, refetch, addNotification]
  );

  const goPrev = () => setMonthCursor((d) => new Date(d.getFullYear(), d.getMonth() - 1, 1));
  const goNext = () => setMonthCursor((d) => new Date(d.getFullYear(), d.getMonth() + 1, 1));

  const handleAutoSchedule = useCallback(async () => {
    const toSchedule = manufacturingOrders.filter((mo) => mo.status !== 'cancelled');
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
    let cursor = new Date(monthStart);
    cursor.setHours(8, 0, 0, 0);
    const skipWeekend = (d: Date) => {
      while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() + 1);
    };
    skipWeekend(cursor);
    for (const mo of sorted) {
      const durationMs = mo.planned_start_at && mo.planned_end_at
        ? new Date(mo.planned_end_at).getTime() - new Date(mo.planned_start_at).getTime()
        : oneDayMs;
      const end = new Date(cursor.getTime() + durationMs);
      try {
        await updateManufacturingOrder(mo.id, {
          planned_start_at: cursor.toISOString(),
          planned_end_at: end.toISOString(),
        });
      } catch (err) {
        addNotification({ type: 'error', title: 'Auto Schedule', message: (err as Error).message });
        return;
      }
      cursor = new Date(end.getTime());
      skipWeekend(cursor);
    }
    addNotification({ type: 'success', title: 'Auto Schedule', message: `${sorted.length} MO(s) scheduled.` });
    refetch();
  }, [manufacturingOrders, monthStart, updateManufacturingOrder, refetch, addNotification]);

  const renderBlock = (mo: ManufacturingOrder, day: Date) => {
    const isLate = !!(
      mo.planned_end_at &&
      new Date(mo.planned_end_at) < today &&
      !['delivered', 'completed'].includes(mo.status)
    );
    const readiness = materialReadinessMap[mo.id];
    const materialIncomplete = Boolean(readiness?.status === 'incomplete' || readiness?.has_shortage);
    const variant = getBlockVariant(mo, isLate, materialIncomplete);
    const expectedDelivery = mo.SalesOrders?.expected_delivery_date ? new Date(mo.SalesOrders.expected_delivery_date) : null;
    const showDeadline = expectedDelivery && isSameDay(day, expectedDelivery);
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

  const toggleStatusFilter = (key: string) => {
    setStatusFilters((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  };

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
            <div className="flex items-center gap-3 flex-wrap">
              <span className="text-sm text-gray-600">Status</span>
              {STATUS_FILTER_OPTIONS.map((opt) => (
                <label key={opt.key} className="flex items-center gap-1.5 text-sm text-gray-700 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={statusFilters.has(opt.key)}
                    onChange={() => toggleStatusFilter(opt.key)}
                    className="rounded border-gray-300"
                  />
                  {opt.label}
                </label>
              ))}
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

        <DndContext onDragEnd={handleDragEnd}>
          {calendarViewMode === 'gantt' ? (
            <div className="rounded-lg border border-gray-200 overflow-hidden">
              <div className="overflow-x-auto">
                <div className="min-w-[600px] py-2">
                  {scheduledMOs.map((mo) => {
                    const start = mo.planned_start_at ? new Date(mo.planned_start_at) : null;
                    const end = mo.planned_end_at ? new Date(mo.planned_end_at) : null;
                    const isLate = end && end < today && !['delivered', 'completed'].includes(mo.status);
                    const readiness = materialReadinessMap[mo.id];
                    const materialIncomplete = readiness?.status === 'incomplete' || readiness?.has_shortage;
                    const variant = getBlockVariant(mo, !!isLate, !!materialIncomplete);
                    const rangeStart = new Date(monthStart.getFullYear(), monthStart.getMonth(), 1, 0, 0, 0);
                    const rangeEnd = new Date(monthEnd.getTime() + 24 * 60 * 60 * 1000);
                    const totalMs = rangeEnd.getTime() - rangeStart.getTime();
                    const leftPct = start && totalMs > 0 ? ((start.getTime() - rangeStart.getTime()) / totalMs) * 100 : 0;
                    const widthPct = start && end && totalMs > 0 ? ((end.getTime() - start.getTime()) / totalMs) * 100 : 10;
                    return (
                      <div key={mo.id} className="flex items-center gap-2 py-1 border-b border-gray-100 last:border-0">
                        <button
                          type="button"
                          onClick={() => router.navigate(`/manufacturing/manufacturing-orders/${mo.id}`)}
                          className="w-32 text-left text-xs font-medium text-blue-600 hover:underline truncate shrink-0"
                        >
                          {mo.manufacturing_order_no}
                        </button>
                        <div className="flex-1 h-6 relative bg-gray-100 rounded overflow-hidden">
                          <button
                            type="button"
                            onClick={() => router.navigate(`/manufacturing/manufacturing-orders/${mo.id}`)}
                            className={`absolute inset-y-0 rounded ${variant}`}
                            style={{ left: `${Math.max(0, leftPct)}%`, width: `${Math.min(100 - leftPct, widthPct)}%` }}
                            title={`${mo.planned_start_at ? new Date(mo.planned_start_at).toLocaleDateString() : ''} – ${mo.planned_end_at ? new Date(mo.planned_end_at).toLocaleDateString() : ''}`}
                          />
                        </div>
                      </div>
                    );
                  })}
                  {scheduledMOs.length === 0 && (
                    <p className="text-sm text-gray-500 py-4 text-center">No scheduled orders in this month.</p>
                  )}
                </div>
              </div>
            </div>
          ) : viewMode === 'order' ? (
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
