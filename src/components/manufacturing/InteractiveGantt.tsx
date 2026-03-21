import { useMemo, useRef, useCallback, useState } from 'react';
import type { WorkOrderTask } from '../../hooks/useWorkOrderTasks';
import type { ScheduledSlot } from '../../lib/scheduling';
import { isWorkDay, endHourForDay, addWorkingHours } from '../../lib/scheduling';

interface InteractiveGanttProps {
  tasks: WorkOrderTask[];
  slots: ScheduledSlot[];
  startDate: Date;
  totalDays: number;
  selectedTaskId: string | null;
  onSelectTask: (taskId: string | null) => void;
  onMoveTask: (taskId: string, newStartDate: Date) => void;
  canEdit: boolean;
  urgencyMap?: Map<string, string>;
}

const PX_PER_HOUR = 24;
const LABEL_W = 200;
const ROW_H = 40;
const MIN_BAR_W = 28;
const TICK_EVERY = 8;

const STATUS_BAR: Record<string, string> = {
  completed: 'bg-green-500/80 border-green-600',
  in_progress: 'bg-blue-500/80 border-blue-600',
  pending: 'bg-gray-400/80 border-gray-500',
};

const SELECTED_RING = 'ring-2 ring-primary ring-offset-1';

const URGENCY_RING: Record<string, string> = {
  critical: 'ring-2 ring-red-500 ring-offset-1',
  at_risk: 'ring-2 ring-orange-400 ring-offset-1',
  blocked: 'ring-2 ring-blue-400 ring-offset-1',
};

function hoursLabel(hours: number): string {
  if (hours % 1 === 0) return `${hours}h`;
  return `${hours.toFixed(1)}h`;
}

/**
 * Count working hours between two local Date objects.
 * Both must represent local times (not UTC midnight from date-only strings).
 */
function workingHoursBetween(from: Date, to: Date): number {
  if (to.getTime() <= from.getTime()) return 0;
  let hours = 0;
  const cursor = new Date(from);

  let safety = 0;
  while (cursor.getTime() < to.getTime() && safety < 500) {
    safety++;
    const dow = cursor.getDay();
    if (!isWorkDay(dow)) {
      cursor.setDate(cursor.getDate() + 1);
      cursor.setHours(8, 0, 0, 0);
      continue;
    }
    const h = cursor.getHours() + cursor.getMinutes() / 60;
    const dayEnd = endHourForDay(dow);
    if (h < 8 || h >= dayEnd) {
      cursor.setDate(cursor.getDate() + 1);
      cursor.setHours(8, 0, 0, 0);
      continue;
    }
    const availToday = dayEnd - h;
    const gap = (to.getTime() - cursor.getTime()) / 3_600_000;
    const consume = Math.min(availToday, gap);
    hours += consume;
    if (gap <= availToday) break;
    cursor.setDate(cursor.getDate() + 1);
    cursor.setHours(8, 0, 0, 0);
  }
  return Math.max(0, Math.round(hours * 100) / 100);
}

export default function InteractiveGantt({
  tasks,
  slots,
  startDate,
  totalDays: _totalDays,
  selectedTaskId,
  onSelectTask,
  onMoveTask,
  canEdit,
  urgencyMap,
}: InteractiveGanttProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [dragState, setDragState] = useState<{
    taskId: string;
    startX: number;
    origLeftPx: number;
  } | null>(null);
  const [dragPxDelta, setDragPxDelta] = useState(0);

  const slotMap = useMemo(() => {
    const m = new Map<string, ScheduledSlot>();
    for (const s of slots) m.set(s.id, s);
    return m;
  }, [slots]);

  const moStart = useMemo(() => {
    const d = new Date(startDate);
    d.setHours(8, 0, 0, 0);
    return d;
  }, [startDate]);

  const barPositions = useMemo(() => {
    const positions = new Map<string, { left: number; width: number }>();
    for (const task of tasks) {
      const slot = slotMap.get(task.id);
      if (!slot) continue;
      const slotStart = new Date(slot.planned_start_at);
      const leftHours = workingHoursBetween(moStart, slotStart);
      const widthHours = task.estimated_duration_hours ?? 8;
      positions.set(task.id, {
        left: leftHours * PX_PER_HOUR,
        width: Math.max(MIN_BAR_W, widthHours * PX_PER_HOUR),
      });
    }
    return positions;
  }, [tasks, slotMap, moStart]);

  const totalWorkingHours = useMemo(() => {
    let maxEnd = 0;
    for (const [, pos] of barPositions) {
      maxEnd = Math.max(maxEnd, pos.left + pos.width);
    }
    return Math.max(40 * PX_PER_HOUR, maxEnd + 8 * PX_PER_HOUR) / PX_PER_HOUR;
  }, [barPositions]);

  const gridWidth = Math.max(400, Math.ceil(totalWorkingHours) * PX_PER_HOUR);

  const hourTicks = useMemo(() => {
    const ticks: { hour: number; px: number; label: string }[] = [];
    for (let h = 0; h <= totalWorkingHours; h += TICK_EVERY) {
      ticks.push({ hour: h, px: h * PX_PER_HOUR, label: `${h}h` });
    }
    return ticks;
  }, [totalWorkingHours]);

  const handlePointerDown = useCallback((e: React.PointerEvent, taskId: string) => {
    if (!canEdit) return;
    const task = tasks.find((t) => t.id === taskId);
    if (task && (task.status === 'in_progress' || task.status === 'completed')) return;
    e.preventDefault();
    e.stopPropagation();
    const pos = barPositions.get(taskId);
    if (!pos) return;
    setDragState({ taskId, startX: e.clientX, origLeftPx: pos.left });
    setDragPxDelta(0);
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
  }, [canEdit, tasks, barPositions]);

  const handlePointerMove = useCallback((e: React.PointerEvent) => {
    if (!dragState) return;
    setDragPxDelta(e.clientX - dragState.startX);
  }, [dragState]);

  const handlePointerUp = useCallback((e: React.PointerEvent) => {
    if (!dragState) return;
    (e.target as HTMLElement).releasePointerCapture(e.pointerId);

    const snappedDelta = Math.round(dragPxDelta / PX_PER_HOUR) * PX_PER_HOUR;
    if (Math.abs(snappedDelta) >= PX_PER_HOUR) {
      const newLeftPx = Math.max(0, dragState.origLeftPx + snappedDelta);
      const newHourOffset = newLeftPx / PX_PER_HOUR;
      const newDate = addWorkingHours(new Date(moStart), newHourOffset);
      onMoveTask(dragState.taskId, newDate);
    }

    setDragState(null);
    setDragPxDelta(0);
  }, [dragState, dragPxDelta, moStart, onMoveTask]);

  const handleBarClick = useCallback((e: React.MouseEvent, taskId: string) => {
    if (dragState) return;
    e.stopPropagation();
    onSelectTask(selectedTaskId === taskId ? null : taskId);
  }, [dragState, selectedTaskId, onSelectTask]);

  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4">
      <h3 className="text-sm font-semibold text-gray-900 mb-3">Timeline</h3>

      <div
        className="flex select-none"
        onClick={() => { if (!dragState) onSelectTask(null); }}
      >
        {/* Fixed left column: task labels */}
        <div style={{ width: LABEL_W, minWidth: LABEL_W }} className="shrink-0 border-r border-gray-100">
          <div className="h-6 mb-1" />
          {tasks.map((task) => {
            const slot = slotMap.get(task.id);
            if (!slot) return null;
            const isSelected = selectedTaskId === task.id;
            return (
              <div key={task.id} style={{ height: ROW_H }} className="flex items-center">
                <button
                  type="button"
                  onClick={(e) => handleBarClick(e, task.id)}
                  className={`text-left text-xs font-medium truncate w-full px-2 py-1 rounded transition-colors ${
                    isSelected ? 'bg-primary/10 text-primary font-medium' : 'text-gray-700 hover:text-primary'
                  }`}
                >
                  {task.work_center?.name ?? `#${task.sequence}`}
                </button>
              </div>
            );
          })}
        </div>

        {/* Scrollable right column: hour-based timeline */}
        <div ref={containerRef} className="overflow-x-auto flex-1">
          <div style={{ width: gridWidth, minWidth: gridWidth }}>
            {/* Hour scale header */}
            <div className="relative h-6 mb-1 border-b border-gray-100">
              {hourTicks.map((tick) => (
                <div
                  key={tick.hour}
                  className="absolute top-0 bottom-0 flex flex-col items-center"
                  style={{ left: tick.px }}
                >
                  <div className="w-px h-2.5 bg-gray-300" />
                  <span className="text-[10px] text-gray-400 mt-px leading-none">{tick.label}</span>
                </div>
              ))}
            </div>

            {/* Task rows */}
            {tasks.map((task) => {
              const pos = barPositions.get(task.id);
              if (!pos) return null;
              const isSelected = selectedTaskId === task.id;
              const isDragging = dragState?.taskId === task.id;
              const barStyle = STATUS_BAR[task.status] ?? STATUS_BAR.pending;

              const displayLeft = isDragging
                ? Math.max(0, pos.left + dragPxDelta)
                : pos.left;

              return (
                <div key={task.id} style={{ height: ROW_H }} className="relative">
                  <div className="relative h-8 mt-1" style={{ width: gridWidth }}>
                    {/* Subtle grid lines */}
                    {hourTicks.map((tick) => (
                      <div
                        key={tick.hour}
                        className="absolute top-0 bottom-0 w-px bg-gray-50 pointer-events-none"
                        style={{ left: tick.px }}
                      />
                    ))}

                    {/* Bar */}
                    <div
                      className={`absolute top-0.5 bottom-0.5 rounded-md border transition-shadow ${barStyle} ${
                        isSelected ? SELECTED_RING : (urgencyMap?.get(task.id) ? (URGENCY_RING[urgencyMap.get(task.id)!] ?? '') : '')
                      } ${isDragging ? 'opacity-80 shadow-lg z-20' : 'hover:shadow-md'} ${
                        canEdit && task.status === 'pending'
                          ? (isDragging ? 'cursor-grabbing' : 'cursor-grab')
                          : 'cursor-pointer'
                      }`}
                      style={{
                        left: displayLeft,
                        width: pos.width - 2,
                      }}
                      onClick={(e) => handleBarClick(e, task.id)}
                      onPointerDown={(e) => handlePointerDown(e, task.id)}
                      onPointerMove={handlePointerMove}
                      onPointerUp={handlePointerUp}
                      title={`${task.work_center?.name}: ${hoursLabel(task.estimated_duration_hours)}`}
                    >
                      <div className="absolute inset-0 flex items-center justify-center text-[11px] font-semibold text-white truncate px-1">
                        {pos.width >= 50 ? hoursLabel(task.estimated_duration_hours) : ''}
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Legend */}
      <div className="flex items-center gap-4 mt-3 text-[11px] text-gray-500">
        <div className="flex items-center gap-1"><div className="w-3 h-2 rounded bg-gray-400/80" /> Pending</div>
        <div className="flex items-center gap-1"><div className="w-3 h-2 rounded bg-blue-500/80" /> In Progress</div>
        <div className="flex items-center gap-1"><div className="w-3 h-2 rounded bg-green-500/80" /> Completed</div>
        {canEdit && <div className="flex items-center gap-1 text-primary"><span>⇔</span> Drag to reschedule (pending only)</div>}
      </div>
    </div>
  );
}
