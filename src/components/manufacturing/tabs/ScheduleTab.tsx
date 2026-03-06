import { useEffect, useMemo, useState, useCallback } from 'react';
import {
  CalendarDays, CheckCircle2, Clock, Loader2,
  Link2, Unlink, Play,
} from 'lucide-react';
import { useManufacturingOrder, useUpdateManufacturingOrder, useMoMaterialReadiness } from '../../../hooks/useManufacturing';
import { useWorkOrderTasks } from '../../../hooks/useWorkOrderTasks';
import { useUIStore } from '../../../stores/ui-store';
import { computeSchedule, checkScheduleReadiness } from '../../../lib/scheduling';

interface ScheduleTabProps {
  moId: string;
  canEdit: boolean;
}

function toInputDate(value?: string | null): string {
  if (!value) return '';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function formatDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
}

function formatDateShort(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}`;
}

function durationLabel(hours: number): string {
  if (hours >= 8) {
    const days = hours / 8;
    return days === 1 ? '1 day' : `${days % 1 === 0 ? days : days.toFixed(1)} days`;
  }
  return `${hours}h`;
}

const STATUS_COLORS: Record<string, string> = {
  completed: 'bg-green-500',
  in_progress: 'bg-blue-500',
  pending: 'bg-gray-300',
};

const STATUS_BAR_COLORS: Record<string, string> = {
  completed: 'bg-green-400',
  in_progress: 'bg-blue-400',
  pending: 'bg-gray-200',
};

export default function ScheduleTab({ moId, canEdit }: ScheduleTabProps) {
  const { manufacturingOrder: mo, loading: moLoading } = useManufacturingOrder(moId);
  const { updateManufacturingOrder, isUpdating } = useUpdateManufacturingOrder();
  const { tasks, loading: tasksLoading, updateTaskScheduling, bulkUpdatePlannedDates } = useWorkOrderTasks(moId);
  const { readiness: materialReadiness } = useMoMaterialReadiness(moId);
  const addNotification = useUIStore((s) => s.addNotification);

  const [startDate, setStartDate] = useState('');
  const [editingDuration, setEditingDuration] = useState<string | null>(null);
  const [durationValue, setDurationValue] = useState('1');
  const [durationUnit, setDurationUnit] = useState<'days' | 'hours'>('days');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (mo?.planned_start_at) {
      setStartDate(toInputDate(mo.planned_start_at));
    }
  }, [mo]);

  const scheduleCheck = useMemo(
    () => checkScheduleReadiness(tasks, materialReadiness?.status ?? null),
    [tasks, materialReadiness]
  );

  const computed = useMemo(() => {
    if (!startDate || tasks.length === 0) return null;
    try {
      const moStart = new Date(`${startDate}T08:00:00`);
      return computeSchedule(moStart, tasks);
    } catch {
      return null;
    }
  }, [startDate, tasks]);

  const ganttRange = useMemo(() => {
    if (!computed || !startDate) return { start: new Date(), end: new Date(), totalDays: 1 };
    const start = new Date(`${startDate}T00:00:00`);
    const end = computed.moEndDate;
    const totalDays = Math.max(1, Math.ceil((end.getTime() - start.getTime()) / 86_400_000) + 1);
    return { start, end, totalDays };
  }, [computed, startDate]);

  const handleSaveSchedule = useCallback(async () => {
    if (!mo || !computed || !startDate) return;
    setSaving(true);
    try {
      await bulkUpdatePlannedDates(computed.slots.map((s) => ({
        id: s.id,
        planned_start_at: s.planned_start_at,
        planned_end_at: s.planned_end_at,
      })));

      await updateManufacturingOrder(mo.id, {
        planned_start_at: new Date(`${startDate}T08:00:00`).toISOString(),
        planned_end_at: computed.moEndDate.toISOString(),
      });

      addNotification({ type: 'success', title: 'Schedule Saved', message: `MO scheduled: ${startDate} → ${toInputDate(computed.moEndDate.toISOString())}` });
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Error',
        message: err instanceof Error ? err.message : 'Failed to save schedule',
      });
    } finally {
      setSaving(false);
    }
  }, [mo, computed, startDate, bulkUpdatePlannedDates, updateManufacturingOrder, addNotification]);

  const handleDurationSave = useCallback(async (taskId: string) => {
    const val = parseFloat(durationValue);
    if (Number.isNaN(val) || val <= 0) {
      addNotification({ type: 'error', title: 'Invalid', message: 'Duration must be a positive number' });
      return;
    }
    const hours = durationUnit === 'days' ? val * 8 : val;
    try {
      await updateTaskScheduling(taskId, { estimated_duration_hours: hours });
      setEditingDuration(null);
      addNotification({ type: 'success', title: 'Updated', message: 'Duration updated' });
    } catch (err) {
      addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed' });
    }
  }, [durationValue, durationUnit, updateTaskScheduling, addNotification]);

  const handleToggleDependency = useCallback(async (taskId: string, depId: string) => {
    const task = tasks.find((t) => t.id === taskId);
    if (!task) return;
    const currentDeps = task.depends_on_task_ids ?? [];
    const newDeps = currentDeps.includes(depId)
      ? currentDeps.filter((d) => d !== depId)
      : [...currentDeps, depId];
    try {
      await updateTaskScheduling(taskId, { depends_on_task_ids: newDeps });
    } catch (err) {
      addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed' });
    }
  }, [tasks, updateTaskScheduling, addNotification]);

  const loading = moLoading || tasksLoading;

  if (loading) {
    return (
      <div className="p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-10 bg-gray-200 rounded" />
          <div className="h-64 bg-gray-200 rounded" />
        </div>
      </div>
    );
  }

  if (!mo) {
    return <div className="p-6 text-center text-gray-500">Manufacturing order not found</div>;
  }

  return (
    <div className="space-y-4">
      {/* Blockers + Warnings — compact inline pills */}
      {(!scheduleCheck.canSchedule || scheduleCheck.warnings.length > 0) && (
        <div className="flex flex-wrap gap-2">
          {!scheduleCheck.canSchedule && scheduleCheck.blockers.map((r) => (
            <div key={r} className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-red-50 border border-red-100">
              <span className="w-1.5 h-1.5 rounded-full bg-red-400 shrink-0" />
              <span className="text-xs text-red-700">{r}</span>
            </div>
          ))}
          {scheduleCheck.warnings.map((r) => (
            <div key={r} className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-amber-50 border border-amber-100">
              <span className="w-1.5 h-1.5 rounded-full bg-amber-400 shrink-0" />
              <span className="text-xs text-amber-700">{r}</span>
            </div>
          ))}
        </div>
      )}

      {/* Start Date + Summary */}
      <div className="rounded-lg border border-gray-200 bg-white p-4">
        <div className="flex items-center justify-between gap-3 mb-3">
          <h3 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
            <CalendarDays className="w-4 h-4 text-gray-500" />
            Schedule
          </h3>
          {canEdit && scheduleCheck.canSchedule && (
            <button
              type="button"
              onClick={handleSaveSchedule}
              disabled={saving || isUpdating || !startDate || !computed}
              className="flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50"
            >
              {saving ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Play className="w-3.5 h-3.5" />}
              {saving ? 'Saving...' : 'Set Schedule'}
            </button>
          )}
        </div>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <label className="block">
            <span className="block text-xs font-medium text-gray-500 mb-1">Production Start</span>
            <input
              type="date"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              disabled={!canEdit || !scheduleCheck.canSchedule}
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 disabled:bg-gray-50"
            />
          </label>
          <div>
            <span className="block text-xs font-medium text-gray-500 mb-1">Calculated End</span>
            <div className="px-3 py-2 border border-gray-100 rounded-lg text-sm bg-gray-50 text-gray-700">
              {computed ? formatDate(computed.moEndDate.toISOString()) : '—'}
            </div>
          </div>
          <div>
            <span className="block text-xs font-medium text-gray-500 mb-1">Total Duration</span>
            <div className="px-3 py-2 border border-gray-100 rounded-lg text-sm bg-gray-50 text-gray-700">
              {computed ? `${computed.totalDays} working day${computed.totalDays !== 1 ? 's' : ''}` : '—'}
            </div>
          </div>
        </div>
      </div>

      {/* WO Task Configuration */}
      {tasks.length > 0 && (
        <div className="rounded-lg border border-gray-200 bg-white p-4">
          <h3 className="text-sm font-semibold text-gray-900 mb-3 flex items-center gap-2">
            <Clock className="w-4 h-4 text-gray-500" />
            Work Order Breakdown
          </h3>
          <div className="space-y-2">
            {tasks.map((task) => {
              const slot = computed?.slots.find((s) => s.id === task.id);
              const isCompleted = task.status === 'completed';
              const isActive = task.status === 'in_progress';
              const depNames = (task.depends_on_task_ids ?? [])
                .map((depId) => tasks.find((t) => t.id === depId)?.work_center?.name)
                .filter(Boolean);

              return (
                <div key={task.id} className="border border-gray-100 rounded-lg p-3">
                  <div className="flex items-center justify-between gap-2">
                    <div className="flex items-center gap-2 min-w-0">
                      <div className={`w-2.5 h-2.5 rounded-full shrink-0 ${STATUS_COLORS[task.status]}`} />
                      <span className="text-sm font-medium text-gray-900 truncate">
                        {task.work_center?.name ?? `Task #${task.sequence}`}
                      </span>
                      {isCompleted && <CheckCircle2 className="w-3.5 h-3.5 text-green-500 shrink-0" />}
                    </div>
                    <div className="flex items-center gap-2 text-xs text-gray-500 shrink-0">
                      {/* Duration */}
                      {editingDuration === task.id ? (
                        <div className="flex items-center gap-1 bg-gray-50 border border-gray-200 rounded-lg px-2 py-1">
                          <input
                            type="number"
                            step="1"
                            min="1"
                            value={durationValue}
                            onChange={(e) => setDurationValue(e.target.value)}
                            onKeyDown={(e) => { if (e.key === 'Enter') handleDurationSave(task.id); if (e.key === 'Escape') setEditingDuration(null); }}
                            className="w-12 px-1 py-0.5 border border-gray-300 rounded text-xs text-center bg-white"
                            autoFocus
                          />
                          <select
                            value={durationUnit}
                            onChange={(e) => setDurationUnit(e.target.value as 'days' | 'hours')}
                            className="px-1 py-0.5 border border-gray-300 rounded text-xs bg-white"
                          >
                            <option value="days">Days</option>
                            <option value="hours">Hours</option>
                          </select>
                          <button type="button" onClick={() => handleDurationSave(task.id)} className="px-2 py-0.5 text-xs font-medium text-white bg-primary rounded hover:bg-primary/90">OK</button>
                          <button type="button" onClick={() => setEditingDuration(null)} className="px-1 py-0.5 text-xs text-gray-400 hover:text-gray-600">✕</button>
                        </div>
                      ) : (
                        <button
                          type="button"
                          onClick={() => {
                            if (!canEdit) return;
                            setEditingDuration(task.id);
                            const h = task.estimated_duration_hours;
                            if (h >= 8 && h % 8 === 0) {
                              setDurationValue(String(h / 8));
                              setDurationUnit('days');
                            } else {
                              setDurationValue(String(h));
                              setDurationUnit('hours');
                            }
                          }}
                          className={`px-2 py-0.5 rounded border text-xs font-medium ${canEdit ? 'hover:border-primary hover:text-primary cursor-pointer' : ''} border-gray-200`}
                          title="Click to edit duration"
                        >
                          {durationLabel(task.estimated_duration_hours)}
                        </button>
                      )}
                      {/* Planned dates */}
                      {slot && (
                        <span className="text-xs text-gray-400">
                          {formatDateShort(slot.planned_start_at)} → {formatDateShort(slot.planned_end_at)}
                        </span>
                      )}
                      {task.started_at && (
                        <span className="text-xs text-blue-500" title={`Started: ${formatDate(task.started_at)}`}>
                          ▶ {formatDateShort(task.started_at)}
                        </span>
                      )}
                      {task.completed_at && (
                        <span className="text-xs text-green-500" title={`Completed: ${formatDate(task.completed_at)}`}>
                          ✓ {formatDateShort(task.completed_at)}
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Dependencies */}
                  {canEdit && (
                    <div className="mt-2 flex flex-wrap items-center gap-1.5">
                      <span className="text-[10px] text-gray-400 uppercase tracking-wide">Depends on:</span>
                      {tasks.filter((t) => t.id !== task.id).map((other) => {
                        const isLinked = (task.depends_on_task_ids ?? []).includes(other.id);
                        return (
                          <button
                            key={other.id}
                            type="button"
                            onClick={() => handleToggleDependency(task.id, other.id)}
                            className={`inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded text-[10px] border transition-colors ${
                              isLinked
                                ? 'bg-blue-50 border-blue-200 text-blue-700'
                                : 'bg-gray-50 border-gray-200 text-gray-400 hover:border-gray-300'
                            }`}
                            title={isLinked ? `Remove dependency on ${other.work_center?.name}` : `Add dependency on ${other.work_center?.name}`}
                          >
                            {isLinked ? <Link2 className="w-2.5 h-2.5" /> : <Unlink className="w-2.5 h-2.5" />}
                            {other.work_center?.name ?? `#${other.sequence}`}
                          </button>
                        );
                      })}
                      {depNames.length === 0 && (
                        <span className="text-[10px] text-gray-300 italic">None (starts immediately)</span>
                      )}
                    </div>
                  )}

                  {/* Mini progress bar */}
                  <div className="mt-2 h-1.5 bg-gray-100 rounded-full overflow-hidden">
                    <div
                      className={`h-full rounded-full transition-all ${STATUS_BAR_COLORS[task.status]}`}
                      style={{ width: isCompleted ? '100%' : isActive ? '50%' : '0%' }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Mini Gantt */}
      {computed && tasks.length > 0 && (
        <div className="rounded-lg border border-gray-200 bg-white p-4">
          <h3 className="text-sm font-semibold text-gray-900 mb-3">Timeline</h3>

          {/* Day headers */}
          <div className="flex mb-1">
            <div className="w-32 shrink-0" />
            <div className="flex-1 flex">
              {Array.from({ length: ganttRange.totalDays }, (_, i) => {
                const d = new Date(ganttRange.start);
                d.setDate(d.getDate() + i);
                const isWeekend = d.getDay() === 0 || d.getDay() === 6;
                return (
                  <div
                    key={i}
                    className={`flex-1 text-center text-[9px] leading-tight ${isWeekend ? 'text-gray-300' : 'text-gray-500'}`}
                    style={{ minWidth: 28 }}
                  >
                    <div>{d.toLocaleDateString(undefined, { weekday: 'short' })}</div>
                    <div>{d.getDate()}</div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Bars */}
          {tasks.map((task) => {
            const slot = computed.slots.find((s) => s.id === task.id);
            if (!slot) return null;
            const slotStart = new Date(slot.planned_start_at);
            const slotEnd = new Date(slot.planned_end_at);
            const totalMs = ganttRange.totalDays * 86_400_000;
            const leftPct = Math.max(0, ((slotStart.getTime() - ganttRange.start.getTime()) / totalMs) * 100);
            const widthPct = Math.max(2, ((slotEnd.getTime() - slotStart.getTime()) / totalMs) * 100);

            const barColor = task.status === 'completed'
              ? 'bg-green-400'
              : task.status === 'in_progress'
                ? 'bg-blue-400'
                : 'bg-gray-300';

            return (
              <div key={task.id} className="flex items-center h-7">
                <div className="w-32 shrink-0 text-xs text-gray-700 truncate pr-2">
                  {task.work_center?.name ?? `#${task.sequence}`}
                </div>
                <div className="flex-1 relative h-5 bg-gray-50 rounded">
                  <div
                    className={`absolute top-0.5 bottom-0.5 rounded ${barColor}`}
                    style={{ left: `${leftPct}%`, width: `${widthPct}%` }}
                    title={`${formatDate(slot.planned_start_at)} → ${formatDate(slot.planned_end_at)}`}
                  />
                  {/* Actual start milestone */}
                  {task.started_at && (() => {
                    const actualPct = ((new Date(task.started_at).getTime() - ganttRange.start.getTime()) / totalMs) * 100;
                    if (actualPct < 0 || actualPct > 100) return null;
                    return (
                      <div
                        className="absolute top-0 bottom-0 w-0.5 bg-blue-600"
                        style={{ left: `${actualPct}%` }}
                        title={`Started: ${new Date(task.started_at).toLocaleString()}`}
                      />
                    );
                  })()}
                  {/* Actual end milestone */}
                  {task.completed_at && (() => {
                    const actualPct = ((new Date(task.completed_at).getTime() - ganttRange.start.getTime()) / totalMs) * 100;
                    if (actualPct < 0 || actualPct > 100) return null;
                    return (
                      <div
                        className="absolute top-0 bottom-0 w-0.5 bg-green-600"
                        style={{ left: `${actualPct}%` }}
                        title={`Completed: ${new Date(task.completed_at).toLocaleString()}`}
                      />
                    );
                  })()}
                </div>
              </div>
            );
          })}

          {/* Legend */}
          <div className="flex items-center gap-4 mt-3 text-[10px] text-gray-500">
            <div className="flex items-center gap-1"><div className="w-3 h-2 rounded bg-gray-300" /> Pending</div>
            <div className="flex items-center gap-1"><div className="w-3 h-2 rounded bg-blue-400" /> In Progress</div>
            <div className="flex items-center gap-1"><div className="w-3 h-2 rounded bg-green-400" /> Completed</div>
            <div className="flex items-center gap-1"><div className="w-0.5 h-3 bg-blue-600" /> Actual Start</div>
            <div className="flex items-center gap-1"><div className="w-0.5 h-3 bg-green-600" /> Actual End</div>
          </div>
        </div>
      )}

      {/* No WOs message */}
      {tasks.length === 0 && !tasksLoading && (
        <div className="rounded-lg border border-gray-200 bg-white p-6 text-center">
          <p className="text-sm text-gray-500">No Work Orders generated yet.</p>
          <p className="text-xs text-gray-400 mt-1">Generate Work Orders first from the Work Orders tab, then configure durations and dependencies here.</p>
        </div>
      )}
    </div>
  );
}
