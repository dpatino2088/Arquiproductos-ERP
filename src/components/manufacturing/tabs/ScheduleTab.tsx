import { useEffect, useMemo, useState, useCallback } from 'react';
import {
  CalendarDays, Clock, Loader2, Play,
  Link2, Unlink, CheckCircle2, AlertTriangle, History,
  Pencil, Lock, User,
} from 'lucide-react';
import { useQuery } from '@tanstack/react-query';
import { useManufacturingOrder, useUpdateManufacturingOrder, useMoMaterialReadiness } from '../../../hooks/useManufacturing';
import { useWorkOrderTasks } from '../../../hooks/useWorkOrderTasks';
import { useWorkCenterWorkload, toDateKey } from '../../../hooks/useWorkCenterWorkload';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { useUIStore } from '../../../stores/ui-store';
import { supabase } from '../../../lib/supabase/client';

interface OperatorOption {
  user_id: string;
  display_name: string;
}
import { scheduleChangelogKey } from '../../../lib/queryKeys';
import {
  computeSchedule, computeScheduleWithOverrides,
  checkScheduleReadiness, moveTaskToDate, findDependents,
  isWorkDay, endHourForDay,
  type ScheduledSlot, type DateOverride,
} from '../../../lib/scheduling';
import InteractiveGantt from '../InteractiveGantt';
import WorkloadHeatmap from '../WorkloadHeatmap';

interface ScheduleTabProps {
  moId: string;
  canEdit: boolean;
}

interface SplitPrompt {
  taskId: string;
  taskName: string;
  targetDate: Date;
  hours: number;
  existingLoad: number;
  dayCapacity: number;
  available: number;
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

function durationLabel(hours: number): string {
  if (hours % 1 === 0) return `${hours}h`;
  return `${hours.toFixed(1)}h`;
}

function remainderPreview(totalHours: number, firstDayH: number): string {
  const rest = Math.max(0, totalHours - firstDayH);
  if (rest <= 0) return 'completes first day';
  const fullDays = Math.floor(rest / 8);
  const partial = Math.round((rest % 8) * 10) / 10;
  const parts: string[] = [];
  if (fullDays > 0) parts.push(`${fullDays}d × 8h`);
  if (partial > 0) parts.push(`${partial}h`);
  return `+ ${parts.join(' + ')} remaining`;
}

const STATUS_DOT: Record<string, string> = {
  completed: 'bg-green-500',
  in_progress: 'bg-blue-500',
  pending: 'bg-gray-300',
};

export default function ScheduleTab({ moId, canEdit }: ScheduleTabProps) {
  const { manufacturingOrder: mo, loading: moLoading } = useManufacturingOrder(moId);
  const { updateManufacturingOrder, isUpdating } = useUpdateManufacturingOrder();
  const {
    tasks, loading: tasksLoading, refetch: refetchTasks,
    updateTaskScheduling, bulkUpdatePlannedDates, updateTaskPlannedDates,
  } = useWorkOrderTasks(moId);
  const { readiness: materialReadiness } = useMoMaterialReadiness(moId);
  const { activeOrganizationId } = useOrganizationContext();
  const addNotification = useUIStore((s) => s.addNotification);

  const [startDate, setStartDate] = useState('');
  const [saving, setSaving] = useState(false);
  const [selectedTaskId, setSelectedTaskId] = useState<string | null>(null);
  const [splitPrompt, setSplitPrompt] = useState<SplitPrompt | null>(null);
  const [splitFirstDayHours, setSplitFirstDayHours] = useState(0);

  const [overloadPrompt, setOverloadPrompt] = useState<{
    taskId: string;
    taskName: string;
    targetDate: Date;
    currentLoad: number;
    capacity: number;
    suggestedDate: string | null;
    suggestedAvailable: number | null;
    searching: boolean;
  } | null>(null);

  const [depConflictPrompt, setDepConflictPrompt] = useState<{
    taskId: string;
    taskName: string;
    requestedDate: Date;
    earliestDate: Date;
    depName: string;
  } | null>(null);

  const [editDurationValue, setEditDurationValue] = useState('1');
  const [operators, setOperators] = useState<OperatorOption[]>([]);

  // Fetch operators from the organization
  useEffect(() => {
    if (!activeOrganizationId) return;
    (async () => {
      const { data } = await supabase
        .from('AppUsers')
        .select('id, display_name, email, role_code')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .in('role_code', ['operator', 'operator_member', 'operator_admin', 'admin', 'superadmin']);
      setOperators((data ?? []).map((o: any) => ({
        user_id: o.id,
        display_name: o.display_name ?? o.email,
      })));
    })();
  }, [activeOrganizationId]);

  const handleAssignOperator = useCallback(async (taskId: string, userId: string) => {
    if (materialReadiness?.hasShortage) {
      addNotification({
        type: 'warning',
        title: 'Materials Incomplete',
        message: 'Resolve Material Demand before assigning operators.',
      });
      return;
    }
    const displayName = operators.find((o) => o.user_id === userId)?.display_name ?? null;
    if (!displayName) {
      addNotification({ type: 'warning', title: 'Operator Required', message: 'Select a valid operator.' });
      return;
    }
    await supabase
      .from('WorkOrderTasks')
      .update({
        assigned_to_user_id: userId,
        assigned_to: displayName,
        updated_at: new Date().toISOString(),
      })
      .eq('id', taskId);
    await refetchTasks();
    addNotification({ type: 'success', title: 'Assigned', message: `Assigned to ${displayName}` });
  }, [operators, addNotification, refetchTasks, materialReadiness?.hasShortage]);

  const [manualOverrides, setManualOverrides] = useState<Map<string, DateOverride>>(new Map());
  const [editOverrideTaskId, setEditOverrideTaskId] = useState<string | null>(null);

  const todayStr = useMemo(() => {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  }, []);

  const buildSavedOverrides = useCallback((): Map<string, DateOverride> => {
    if (!startDate) return new Map();
    const moStart = new Date(`${startDate}T08:00:00`);
    const m = new Map<string, DateOverride>();
    for (const t of tasks) {
      if (t.planned_start_at && t.planned_end_at) {
        const s = new Date(t.planned_start_at);
        if (s.getTime() >= moStart.getTime()) {
          m.set(t.id, { start: s, end: new Date(t.planned_end_at) });
        }
      }
    }
    return m;
  }, [tasks, startDate]);

  const resetOverrides = useCallback(() => {
    const saved = buildSavedOverrides();
    setManualOverrides(saved.size > 0 ? saved : new Map());
  }, [buildSavedOverrides]);

  useEffect(() => {
    if (mo?.planned_start_at) {
      const saved = toInputDate(mo.planned_start_at);
      const effective = saved < todayStr ? todayStr : saved;
      setStartDate((prev) => {
        if (prev !== effective) setManualOverrides(new Map());
        return effective;
      });
    } else if (!mo?.planned_start_at && mo) {
      setStartDate(todayStr);
      setManualOverrides(new Map());
    }
  }, [mo, todayStr]);

  const scheduleCheck = useMemo(
    () => checkScheduleReadiness(tasks, materialReadiness?.status ?? null),
    [tasks, materialReadiness]
  );

  const computed = useMemo(() => {
    if (!startDate || tasks.length === 0) return null;
    try {
      const moStart = new Date(`${startDate}T08:00:00`);
      if (manualOverrides.size > 0) {
        const cleaned = new Map<string, DateOverride>();
        for (const [id, ov] of manualOverrides) {
          if (ov.start.getTime() >= moStart.getTime()) {
            cleaned.set(id, ov);
          }
        }
        if (cleaned.size > 0) {
          return computeScheduleWithOverrides(moStart, tasks, cleaned);
        }
      }
      return computeSchedule(moStart, tasks);
    } catch {
      return null;
    }
  }, [startDate, tasks, manualOverrides]);

  const workloadRange = useMemo(() => {
    if (!startDate) return undefined;
    const from = new Date(`${startDate}T00:00:00`);
    const to = new Date(from);
    to.setDate(to.getDate() + 30);
    return { from, to };
  }, [startDate]);

  const { workCenters, workload } = useWorkCenterWorkload(
    activeOrganizationId,
    workloadRange,
    moId,
  );

  const simulatedLoad = useMemo(() => {
    if (!computed) return undefined;
    const sim = new Map<string, Map<string, number>>();

    for (const slot of computed.slots) {
      const task = tasks.find((t) => t.id === slot.id);
      if (!task) continue;
      const wcId = task.work_center_id;
      const totalHours = task.estimated_duration_hours ?? 8;
      const start = new Date(slot.planned_start_at);
      const end = new Date(slot.planned_end_at);

      const startDay = new Date(start); startDay.setHours(0, 0, 0, 0);
      const endDay = new Date(end); endDay.setHours(0, 0, 0, 0);

      let remaining = totalHours;
      const cursor = new Date(startDay);
      const startHour = start.getHours() + start.getMinutes() / 60;
      let lastValidKey: string | null = null;

      while (cursor <= endDay && remaining > 0.01) {
        const dow = cursor.getDay();
        if (dow !== 0) {
          const dayEndHour = endHourForDay(dow);
          const dayStartHour = cursor.getTime() === startDay.getTime()
            ? Math.max(8, startHour)
            : 8;
          const availableToday = Math.max(0, dayEndHour - dayStartHour);
          const consume = Math.min(remaining, availableToday);
          if (consume > 0) {
            lastValidKey = toDateKey(cursor);
            const key = toDateKey(cursor);
            if (!sim.has(wcId)) sim.set(wcId, new Map());
            const wcMap = sim.get(wcId)!;
            wcMap.set(key, (wcMap.get(key) ?? 0) + Math.round(consume * 10) / 10);
            remaining -= consume;
          }
        }
        cursor.setDate(cursor.getDate() + 1);
      }

      if (remaining > 0.01 && lastValidKey) {
        if (!sim.has(wcId)) sim.set(wcId, new Map());
        const wcMap = sim.get(wcId)!;
        wcMap.set(lastValidKey, (wcMap.get(lastValidKey) ?? 0) + Math.round(remaining * 10) / 10);
      }
    }

    return sim;
  }, [computed, tasks]);

  const heatmapDays = useMemo(() => {
    if (!computed || !startDate) return 14;
    return Math.max(14, computed.totalDays + 5);
  }, [computed, startDate]);

  const heatmapStart = useMemo(() => {
    if (!startDate) return new Date();
    return new Date(`${startDate}T00:00:00`);
  }, [startDate]);

  const selectedTask = useMemo(
    () => selectedTaskId ? tasks.find((t) => t.id === selectedTaskId) ?? null : null,
    [selectedTaskId, tasks]
  );

  const selectedSlot = useMemo(
    () => selectedTaskId ? computed?.slots.find((s) => s.id === selectedTaskId) ?? null : null,
    [selectedTaskId, computed]
  );

  useEffect(() => {
    if (selectedTask) {
      setEditDurationValue(String(selectedTask.estimated_duration_hours));
    }
  }, [selectedTask]);

  // ── Core move logic ──
  const applyMoveTask = useCallback((
    taskId: string,
    targetDate: Date,
    mode: 'normal' | 'singleDay' | 'customSplit',
    firstDayHours?: number,
  ) => {
    if (!computed || !startDate) return;
    const moStart = new Date(`${startDate}T08:00:00`);

    if (mode === 'singleDay') {
      const dependentIds = findDependents(tasks, taskId);
      const overrides = new Map<string, DateOverride>();

      for (const slot of computed.slots) {
        if (slot.id === taskId || dependentIds.has(slot.id)) continue;
        overrides.set(slot.id, {
          start: new Date(slot.planned_start_at),
          end: new Date(slot.planned_end_at),
        });
      }

      const task = tasks.find((t) => t.id === taskId);
      const adjustedStart = new Date(targetDate);
      adjustedStart.setHours(8, 0, 0, 0);
      // Respect dependency constraints on the same day
      const deps = task?.depends_on_task_ids ?? [];
      if (deps.length > 0 && task?.dependency_type !== 'start_to_start') {
        const depEndDates = deps
          .map((depId) => computed.slots.find((s) => s.id === depId))
          .filter(Boolean)
          .map((s) => new Date(s!.planned_end_at));
        if (depEndDates.length > 0) {
          const latestDepEnd = new Date(Math.max(...depEndDates.map((d) => d.getTime())));
          const depDay = toInputDate(latestDepEnd.toISOString());
          const targetDay = toInputDate(targetDate.toISOString());
          if (depDay === targetDay) {
            const depH = latestDepEnd.getHours() + latestDepEnd.getMinutes() / 60;
            if (depH > 8) adjustedStart.setHours(Math.ceil(depH), 0, 0, 0);
          }
        }
      }
      const dow = adjustedStart.getDay();
      const dayEnd = new Date(targetDate);
      dayEnd.setHours(endHourForDay(dow), 0, 0, 0);
      overrides.set(taskId, { start: adjustedStart, end: dayEnd });

      const result = computeScheduleWithOverrides(moStart, tasks, overrides);

      const finalOverrides = new Map<string, DateOverride>();
      for (const slot of result.slots) {
        if (slot.id === taskId) {
          finalOverrides.set(slot.id, { start: adjustedStart, end: dayEnd });
        } else {
          finalOverrides.set(slot.id, {
            start: new Date(slot.planned_start_at),
            end: new Date(slot.planned_end_at),
          });
        }
      }
      setManualOverrides(finalOverrides);
    } else if (mode === 'customSplit' && firstDayHours !== undefined) {
      const dow = targetDate.getDay();
      const dayEnd = endHourForDay(dow);
      const startHour = Math.max(8, dayEnd - firstDayHours);
      const adjustedStart = new Date(targetDate);
      adjustedStart.setHours(startHour, 0, 0, 0);

      const newSlots = moveTaskToDate(moStart, tasks, taskId, adjustedStart, computed.slots);
      const newOverrides = new Map<string, DateOverride>();
      for (const slot of newSlots) {
        newOverrides.set(slot.id, {
          start: new Date(slot.planned_start_at),
          end: new Date(slot.planned_end_at),
        });
      }
      setManualOverrides(newOverrides);
    } else {
      const newSlots = moveTaskToDate(moStart, tasks, taskId, targetDate, computed.slots);
      const newOverrides = new Map<string, DateOverride>();
      for (const slot of newSlots) {
        newOverrides.set(slot.id, {
          start: new Date(slot.planned_start_at),
          end: new Date(slot.planned_end_at),
        });
      }
      setManualOverrides(newOverrides);
    }
  }, [computed, startDate, tasks]);

  const clampToDepConstraints = useCallback((taskId: string, targetDate: Date): Date => {
    if (!computed || !startDate) return targetDate;
    const task = tasks.find((t) => t.id === taskId);
    if (!task) return targetDate;
    let clamped = new Date(targetDate);

    const moStart = new Date(`${startDate}T08:00:00`);
    if (clamped < moStart) clamped = new Date(moStart);

    const deps = task.depends_on_task_ids ?? [];
    if (deps.length > 0 && task.dependency_type !== 'start_to_start') {
      const depEndDates = deps
        .map((depId) => computed.slots.find((s) => s.id === depId))
        .filter(Boolean)
        .map((s) => new Date(s!.planned_end_at));

      if (depEndDates.length > 0) {
        const latestDepEnd = new Date(Math.max(...depEndDates.map((d) => d.getTime())));
        const depEndHour = latestDepEnd.getHours() + latestDepEnd.getMinutes() / 60;
        const depDow = latestDepEnd.getDay();
        const depDayEnd = endHourForDay(depDow);
        let minStart: Date;
        if (depEndHour <= 8 && isWorkDay(depDow)) {
          minStart = new Date(latestDepEnd);
          minStart.setHours(8, 0, 0, 0);
        } else if (isWorkDay(depDow) && depEndHour < depDayEnd) {
          minStart = new Date(latestDepEnd);
        } else {
          minStart = new Date(latestDepEnd);
          minStart.setDate(minStart.getDate() + 1);
          minStart.setHours(8, 0, 0, 0);
          while (!isWorkDay(minStart.getDay())) minStart.setDate(minStart.getDate() + 1);
        }
        if (clamped < minStart) clamped = minStart;
      }
    }

    return clamped;
  }, [computed, startDate, tasks]);

  const handleMoveTask = useCallback((taskId: string, newStartDate: Date) => {
    if (!computed || !startDate) return;
    const task = tasks.find((t) => t.id === taskId);
    if (!task) return;

    const todayMidnight = new Date();
    todayMidnight.setHours(0, 0, 0, 0);
    if (newStartDate < todayMidnight) {
      addNotification({ type: 'warning', title: 'Invalid date', message: 'Cannot schedule tasks before today.' });
      return;
    }

    if ((task.status === 'in_progress' || task.status === 'completed') && editOverrideTaskId !== taskId) {
      addNotification({
        type: 'warning',
        title: 'Cannot move',
        message: `"${task.work_center?.name ?? 'Task'}" is ${task.status === 'in_progress' ? 'in progress' : 'completed'}. Click the lock icon to unlock editing.`,
      });
      return;
    }

    const validDate = clampToDepConstraints(taskId, newStartDate);
    if (validDate.getTime() !== newStartDate.getTime()) {
      const deps = task.depends_on_task_ids ?? [];
      const depNames = deps
        .map((id) => tasks.find((t) => t.id === id)?.work_center?.name)
        .filter(Boolean)
        .join(', ');
      setDepConflictPrompt({
        taskId,
        taskName: task.work_center?.name ?? `Task #${task.sequence}`,
        requestedDate: newStartDate,
        earliestDate: validDate,
        depName: depNames || 'previous tasks',
      });
      return;
    }

    const dateKey = toDateKey(validDate);
    const globalLoad = workload.get(task.work_center_id)?.get(dateKey)?.totalHours ?? 0;
    const dow = validDate.getDay();
    const dayCapacity = endHourForDay(dow) - 8;
    const totalLoad = globalLoad + task.estimated_duration_hours;

    if (totalLoad > dayCapacity && dayCapacity > 0) {
      addNotification({
        type: 'warning',
        title: 'Overload',
        message: `"${task.work_center?.name ?? 'Task'}" adds ${task.estimated_duration_hours}h to a day with ${Math.round(globalLoad * 10) / 10}h load (${dayCapacity}h capacity).`,
      });
    }

    applyMoveTask(taskId, validDate, 'normal');
  }, [computed, startDate, tasks, workload, applyMoveTask, clampToDepConstraints, addNotification, activeOrganizationId, editOverrideTaskId]);

  const handleSplitChoice = useCallback((mode: 'singleDay' | 'customSplit' | 'cancel') => {
    if (!splitPrompt || mode === 'cancel') {
      setSplitPrompt(null);
      return;
    }
    if (mode === 'singleDay') {
      applyMoveTask(splitPrompt.taskId, splitPrompt.targetDate, 'singleDay');
    } else {
      applyMoveTask(splitPrompt.taskId, splitPrompt.targetDate, 'customSplit', splitFirstDayHours);
    }
    setSplitPrompt(null);
  }, [splitPrompt, applyMoveTask, splitFirstDayHours]);

  const handleHeatmapCellClick = useCallback((_dateKey: string, date: Date) => {
    if (!selectedTaskId || !computed || !startDate) return;
    const task = tasks.find((t) => t.id === selectedTaskId);
    if (!task) return;

    const todayMidnight = new Date();
    todayMidnight.setHours(0, 0, 0, 0);
    if (date < todayMidnight) {
      addNotification({ type: 'warning', title: 'Invalid date', message: 'Cannot schedule tasks before today.' });
      return;
    }

    if ((task.status === 'in_progress' || task.status === 'completed') && editOverrideTaskId !== selectedTaskId) {
      addNotification({ type: 'warning', title: 'Cannot move', message: `Task is ${task.status}.` });
      return;
    }

    const validDate = clampToDepConstraints(selectedTaskId, date);
    if (validDate.getTime() !== date.getTime()) {
      const depNames = (task.depends_on_task_ids ?? [])
        .map((id) => tasks.find((t) => t.id === id)?.work_center?.name)
        .filter(Boolean)
        .join(', ');
      setDepConflictPrompt({
        taskId: selectedTaskId,
        taskName: task.work_center?.name ?? `Task #${task.sequence}`,
        requestedDate: date,
        earliestDate: validDate,
        depName: depNames || 'previous tasks',
      });
      return;
    }

    const dow = validDate.getDay();
    const dayCapacity = endHourForDay(dow) - 8;
    if (task.estimated_duration_hours > dayCapacity && dayCapacity > 0) {
      addNotification({
        type: 'warning',
        title: 'Overload',
        message: `"${task.work_center?.name ?? 'Task'}" (${task.estimated_duration_hours}h) compressed into ${dayCapacity}h on this day.`,
      });
    }
    applyMoveTask(selectedTaskId, validDate, 'singleDay');
  }, [selectedTaskId, computed, startDate, tasks, applyMoveTask, clampToDepConstraints, addNotification, editOverrideTaskId]);

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

      const savedOverrides = new Map<string, DateOverride>();
      for (const s of computed.slots) {
        savedOverrides.set(s.id, {
          start: new Date(s.planned_start_at),
          end: new Date(s.planned_end_at),
        });
      }
      setManualOverrides(savedOverrides);
      addNotification({
        type: 'success',
        title: 'Schedule Saved',
        message: `MO scheduled: ${startDate} → ${toInputDate(computed.moEndDate.toISOString())}`,
      });
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

  const handleDurationSave = useCallback(async () => {
    if (!selectedTaskId) return;
    const val = parseFloat(editDurationValue);
    if (Number.isNaN(val) || val <= 0) {
      addNotification({ type: 'error', title: 'Invalid', message: 'Duration must be a positive number' });
      return;
    }
    const hours = val;
    try {
      await updateTaskScheduling(selectedTaskId, { estimated_duration_hours: hours });
      resetOverrides();
      addNotification({ type: 'success', title: 'Updated', message: 'Duration updated' });
    } catch (err) {
      addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed' });
    }
  }, [selectedTaskId, editDurationValue, updateTaskScheduling, addNotification, resetOverrides]);

  const handleToggleDependency = useCallback(async (depId: string) => {
    if (!selectedTask) return;
    const currentDeps = selectedTask.depends_on_task_ids ?? [];
    const newDeps = currentDeps.includes(depId)
      ? currentDeps.filter((d) => d !== depId)
      : [...currentDeps, depId];
    try {
      await updateTaskScheduling(selectedTask.id, { depends_on_task_ids: newDeps });
      resetOverrides();
    } catch (err) {
      addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed' });
    }
  }, [selectedTask, updateTaskScheduling, addNotification, resetOverrides]);

  const handleTaskDateChange = useCallback((newDateStr: string) => {
    if (!selectedTaskId || !newDateStr) return;
    const newDate = new Date(`${newDateStr}T08:00:00`);
    handleMoveTask(selectedTaskId, newDate);
  }, [selectedTaskId, handleMoveTask]);

  const handleEndDateForce = useCallback((endDateStr: string) => {
    if (!selectedTaskId || !computed || !startDate || !endDateStr) return;
    const task = tasks.find((t) => t.id === selectedTaskId);
    if (!task) return;

    const selectedSlot = computed.slots.find((s) => s.id === selectedTaskId);
    if (!selectedSlot) return;

    const currentStart = new Date(selectedSlot.planned_start_at);
    const endDateLocal = new Date(`${endDateStr}T17:00:00`);
    const endDow = endDateLocal.getDay();
    const endH = endHourForDay(endDow);
    const forcedEnd = new Date(`${endDateStr}T${String(endH).padStart(2, '0')}:00:00`);

    const currentStartDay = toInputDate(currentStart.toISOString());
    let forcedStart: Date;

    if (endDateStr !== currentStartDay) {
      // Move start to forced end day — at 08:00 or after deps, whichever is later
      forcedStart = new Date(`${endDateStr}T08:00:00`);
      const deps = task.depends_on_task_ids ?? [];
      if (deps.length > 0 && task.dependency_type !== 'start_to_start') {
        const depEndDates = deps
          .map((depId) => computed.slots.find((s) => s.id === depId))
          .filter(Boolean)
          .map((s) => new Date(s!.planned_end_at));
        if (depEndDates.length > 0) {
          const latestDepEnd = new Date(Math.max(...depEndDates.map((d) => d.getTime())));
          const depDay = toInputDate(latestDepEnd.toISOString());
          if (depDay === endDateStr) {
            const depEndHour = latestDepEnd.getHours() + latestDepEnd.getMinutes() / 60;
            if (depEndHour > 8) forcedStart = new Date(latestDepEnd);
          }
        }
      }
    } else {
      forcedStart = new Date(currentStart);
    }

    if (forcedEnd.getTime() <= forcedStart.getTime()) {
      addNotification({ type: 'warning', title: 'Invalid end date', message: 'End date must be after the task start.' });
      return;
    }

    const moStart = new Date(`${startDate}T08:00:00`);
    const dependentIds = findDependents(tasks, selectedTaskId);
    const overrides = new Map<string, DateOverride>();

    for (const slot of computed.slots) {
      if (slot.id === selectedTaskId || dependentIds.has(slot.id)) continue;
      overrides.set(slot.id, {
        start: new Date(slot.planned_start_at),
        end: new Date(slot.planned_end_at),
      });
    }
    overrides.set(selectedTaskId, { start: forcedStart, end: forcedEnd });

    const result = computeScheduleWithOverrides(moStart, tasks, overrides);
    const finalOverrides = new Map<string, DateOverride>();
    for (const slot of result.slots) {
      if (slot.id === selectedTaskId) {
        finalOverrides.set(slot.id, { start: forcedStart, end: forcedEnd });
      } else {
        finalOverrides.set(slot.id, {
          start: new Date(slot.planned_start_at),
          end: new Date(slot.planned_end_at),
        });
      }
    }
    setManualOverrides(finalOverrides);

    const cap = endH - (forcedStart.getHours() + forcedStart.getMinutes() / 60);
    if (task.estimated_duration_hours > cap && cap > 0) {
      addNotification({
        type: 'warning',
        title: 'Overload',
        message: `"${task.work_center?.name ?? 'Task'}" (${task.estimated_duration_hours}h) compressed into ${Math.round(cap * 10) / 10}h available on ${endDateStr}. Heatmap shows overload.`,
      });
    }
  }, [selectedTaskId, computed, startDate, tasks, addNotification]);

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

  const hasUnsavedChanges = manualOverrides.size > 0;

  return (
    <div className="space-y-4">
      {/* Blockers + Warnings */}
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

      {/* ① Schedule Header */}
      <div className="rounded-lg border border-gray-200 bg-white p-4">
        <div className="flex items-center justify-between gap-3 mb-3">
          <h3 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
            <CalendarDays className="w-4 h-4 text-gray-500" />
            Schedule
          </h3>
          <div className="flex items-center gap-2">
            {hasUnsavedChanges && (
              <span className="text-[10px] text-amber-600 bg-amber-50 px-2 py-0.5 rounded-full border border-amber-200">
                Unsaved changes
              </span>
            )}
            {canEdit && scheduleCheck.canSchedule && (
              <button
                type="button"
                onClick={handleSaveSchedule}
                disabled={saving || isUpdating || !startDate || !computed}
                className={`flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white rounded-lg disabled:opacity-50 transition-colors ${
                  hasUnsavedChanges
                    ? 'bg-amber-500 hover:bg-amber-600'
                    : 'bg-primary hover:bg-primary/90'
                }`}
              >
                {saving ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Play className="w-3.5 h-3.5" />}
                {saving ? 'Saving...' : hasUnsavedChanges ? 'Save Changes' : 'Set Schedule'}
              </button>
            )}
          </div>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <label className="block">
            <span className="block text-xs font-medium text-gray-500 mb-1">Production Start</span>
            <div className="relative">
              <input
                type="date"
                value={startDate}
                min={todayStr}
                onChange={(e) => {
                  if (e.target.value < todayStr) return;
                  setStartDate(e.target.value);
                  setManualOverrides(new Map());
                }}
                disabled={!canEdit || !scheduleCheck.canSchedule}
                className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 disabled:bg-gray-50 text-transparent"
              />
              <span className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-sm text-gray-900">
                {startDate ? formatDate(startDate) : '—'}
              </span>
            </div>
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
              {computed ? (() => {
                const totalH = tasks.reduce((sum, t) => sum + (t.estimated_duration_hours ?? 0), 0);
                return `${totalH}h (${Math.ceil(totalH / 8)} working day${Math.ceil(totalH / 8) !== 1 ? 's' : ''})`;
              })() : '—'}
            </div>
          </div>
        </div>
      </div>

      {/* ② Workload Heatmap */}
      {startDate && tasks.length > 0 && workCenters.length > 0 && (
        <WorkloadHeatmap
          workCenters={workCenters}
          workload={workload}
          startDate={heatmapStart}
          days={heatmapDays}
          simulatedLoad={simulatedLoad}
          selectedTaskWorkCenterId={selectedTask?.work_center_id ?? null}
          onCellClick={canEdit ? handleHeatmapCellClick : undefined}
        />
      )}

      {/* ③ Interactive Gantt */}
      {computed && tasks.length > 0 && (
        <InteractiveGantt
          tasks={tasks}
          slots={computed.slots}
          startDate={heatmapStart}
          totalDays={computed.totalDays}
          selectedTaskId={selectedTaskId}
          onSelectTask={(id) => { setSelectedTaskId(id); setEditOverrideTaskId(null); }}
          onMoveTask={handleMoveTask}
          canEdit={canEdit && scheduleCheck.canSchedule}
        />
      )}

      {/* Split Day Dialog */}
      {splitPrompt && (
        <div className="rounded-lg border-2 border-amber-300 bg-amber-50 p-4 shadow-sm">
          <div className="flex items-start gap-3">
            <AlertTriangle className="w-5 h-5 text-amber-500 shrink-0 mt-0.5" />
            <div className="flex-1 space-y-3">
              <h4 className="text-sm font-semibold text-gray-900">
                &quot;{splitPrompt.taskName}&quot; — {splitPrompt.hours}h total
              </h4>

              {/* Existing load info */}
              <div className="grid grid-cols-3 gap-2 text-xs">
                <div className="bg-white/80 rounded px-2 py-1.5 border border-amber-200">
                  <span className="block text-gray-500">Existing load</span>
                  <span className="font-semibold text-gray-800">{splitPrompt.existingLoad}h</span>
                </div>
                <div className="bg-white/80 rounded px-2 py-1.5 border border-amber-200">
                  <span className="block text-gray-500">Day capacity</span>
                  <span className="font-semibold text-gray-800">{splitPrompt.dayCapacity}h</span>
                </div>
                <div className={`rounded px-2 py-1.5 border ${splitPrompt.available <= 0 ? 'bg-red-50 border-red-200' : 'bg-green-50 border-green-200'}`}>
                  <span className="block text-gray-500">Available</span>
                  <span className={`font-semibold ${splitPrompt.available <= 0 ? 'text-red-700' : 'text-green-700'}`}>{splitPrompt.available}h</span>
                </div>
              </div>

              {/* First-day hours slider + input */}
              <div>
                <label className="flex items-center justify-between text-xs text-gray-600 mb-1">
                  <span>Hours on first day</span>
                  <span className="text-gray-500">{remainderPreview(splitPrompt.hours, splitFirstDayHours)}</span>
                </label>
                <div className="flex items-center gap-2">
                  <input
                    type="range"
                    min={1}
                    max={Math.min(splitPrompt.hours, splitPrompt.dayCapacity)}
                    step={0.5}
                    value={splitFirstDayHours}
                    onChange={(e) => setSplitFirstDayHours(Number(e.target.value))}
                    className="flex-1 accent-amber-500 h-2"
                  />
                  <input
                    type="number"
                    min={1}
                    max={Math.min(splitPrompt.hours, splitPrompt.dayCapacity)}
                    step={0.5}
                    value={splitFirstDayHours}
                    onChange={(e) => {
                      const v = Math.min(
                        Math.max(1, Number(e.target.value)),
                        Math.min(splitPrompt.hours, splitPrompt.dayCapacity),
                      );
                      setSplitFirstDayHours(v);
                    }}
                    className="w-16 text-center text-sm border border-amber-300 rounded px-1.5 py-1"
                  />
                  <span className="text-xs text-gray-500">h</span>
                </div>
              </div>

              {/* Actions */}
              <div className="flex flex-wrap gap-2 pt-1">
                <button
                  type="button"
                  onClick={() => handleSplitChoice('customSplit')}
                  className="inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium text-blue-800 bg-blue-50 border border-blue-200 rounded-lg hover:bg-blue-100 transition-colors"
                >
                  <CalendarDays className="w-3.5 h-3.5" />
                  Split: {splitFirstDayHours}h day 1 + {Math.round((splitPrompt.hours - splitFirstDayHours) * 10) / 10}h rest
                </button>
                <button
                  type="button"
                  onClick={() => handleSplitChoice('singleDay')}
                  className="inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium text-amber-800 bg-amber-100 border border-amber-300 rounded-lg hover:bg-amber-200 transition-colors"
                >
                  <Clock className="w-3.5 h-3.5" />
                  All in 1 day ({splitPrompt.hours}h)
                </button>
                <button
                  type="button"
                  onClick={() => handleSplitChoice('cancel')}
                  className="inline-flex items-center px-3 py-2 text-sm text-gray-500 border border-gray-200 rounded-lg hover:bg-gray-100 transition-colors"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ③b Overload Suggestion Dialog */}
      {overloadPrompt && (
        <div className="rounded-xl border-2 border-red-200 bg-red-50 p-4 shadow-sm">
          <div className="flex items-start gap-3">
            <div className="p-2 bg-red-100 rounded-lg flex-shrink-0">
              <AlertTriangle className="w-4 h-4 text-red-600" />
            </div>
            <div className="flex-1 min-w-0">
              <h3 className="text-sm font-semibold text-gray-900">
                {overloadPrompt.taskName} — Overloaded Day
              </h3>
              <p className="text-xs text-gray-600 mt-1">
                This cell has {overloadPrompt.currentLoad}h programmed (capacity {overloadPrompt.capacity}h).
                Adding this task would exceed capacity.
              </p>

              {overloadPrompt.searching && (
                <div className="flex items-center gap-2 mt-2 text-xs text-gray-500">
                  <Loader2 className="w-3 h-3 animate-spin" />
                  Searching for best available slot...
                </div>
              )}

              {!overloadPrompt.searching && overloadPrompt.suggestedDate && (
                <p className="text-xs text-green-700 mt-2">
                  Best slot: <span className="font-medium">{formatDate(overloadPrompt.suggestedDate)}</span>
                  {overloadPrompt.suggestedAvailable != null && ` (${overloadPrompt.suggestedAvailable}h available)`}
                </p>
              )}

              {!overloadPrompt.searching && !overloadPrompt.suggestedDate && (
                <p className="text-xs text-gray-500 mt-2">No available slots found in the next 14 days.</p>
              )}

              <div className="flex flex-wrap gap-2 mt-3">
                <button
                  type="button"
                  onClick={() => {
                    applyMoveTask(overloadPrompt.taskId, overloadPrompt.targetDate, 'normal');
                    setOverloadPrompt(null);
                  }}
                  className="inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium text-red-800 bg-red-100 border border-red-200 rounded-lg hover:bg-red-200 transition-colors"
                >
                  Place Here Anyway
                </button>
                {overloadPrompt.suggestedDate && (
                  <button
                    type="button"
                    onClick={() => {
                      const suggested = new Date(`${overloadPrompt.suggestedDate}T08:00:00`);
                      applyMoveTask(overloadPrompt.taskId, suggested, 'normal');
                      setOverloadPrompt(null);
                    }}
                    className="inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium text-green-800 bg-green-100 border border-green-200 rounded-lg hover:bg-green-200 transition-colors"
                  >
                    <CalendarDays className="w-3.5 h-3.5" />
                    Move to {formatDate(overloadPrompt.suggestedDate)}
                  </button>
                )}
                <button
                  type="button"
                  onClick={() => setOverloadPrompt(null)}
                  className="inline-flex items-center px-3 py-2 text-sm text-gray-500 border border-gray-200 rounded-lg hover:bg-gray-100 transition-colors"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ③c Dependency Conflict Dialog */}
      {depConflictPrompt && (
        <div className="rounded-xl border-2 border-amber-200 bg-amber-50 p-4 shadow-sm">
          <div className="flex items-start gap-3">
            <div className="p-2 bg-amber-100 rounded-lg flex-shrink-0">
              <AlertTriangle className="w-4 h-4 text-amber-600" />
            </div>
            <div className="flex-1 min-w-0">
              <h3 className="text-sm font-semibold text-gray-900">
                {depConflictPrompt.taskName} — Dependency Conflict
              </h3>
              <p className="text-xs text-gray-600 mt-1">
                This task depends on <span className="font-medium">{depConflictPrompt.depName}</span> which hasn't finished by that date.
                Earliest available start: <span className="font-medium">{formatDate(depConflictPrompt.earliestDate.toISOString())}</span>.
              </p>
              <div className="flex flex-wrap gap-2 mt-3">
                <button
                  type="button"
                  onClick={() => {
                    const { taskId, earliestDate } = depConflictPrompt;
                    setDepConflictPrompt(null);
                    const task = tasks.find((t) => t.id === taskId);
                    if (!task) return;
                    const dow = earliestDate.getDay();
                    const dayCapacity = endHourForDay(dow) - 8;

                    if (task.estimated_duration_hours > dayCapacity && dayCapacity > 0) {
                      addNotification({
                        type: 'warning',
                        title: 'Overload',
                        message: `"${task.work_center?.name ?? 'Task'}" (${task.estimated_duration_hours}h) compressed into ${dayCapacity}h on ${formatDate(earliestDate.toISOString())}.`,
                      });
                    }
                    applyMoveTask(taskId, earliestDate, 'singleDay');
                  }}
                  className="inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium text-amber-800 bg-amber-100 border border-amber-300 rounded-lg hover:bg-amber-200 transition-colors"
                >
                  <CalendarDays className="w-3.5 h-3.5" />
                  Move to {formatDate(depConflictPrompt.earliestDate.toISOString())}
                </button>
                <button
                  type="button"
                  onClick={() => setDepConflictPrompt(null)}
                  className="inline-flex items-center px-3 py-2 text-sm text-gray-500 border border-gray-200 rounded-lg hover:bg-gray-100 transition-colors"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ④ Inline Task Detail Panel */}
      {selectedTask && (() => {
        const isOverridden = editOverrideTaskId === selectedTask.id;
        const isTaskEditable = selectedTask.status === 'pending' || isOverridden;
        const isLocked = selectedTask.status !== 'pending' && !isOverridden;

        return (
        <div className={`rounded-lg border-2 p-4 ${isOverridden ? 'border-amber-300 bg-amber-50/30' : 'border-primary/30 bg-primary/5'}`}>
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
              <div className={`w-2.5 h-2.5 rounded-full ${STATUS_DOT[selectedTask.status]}`} />
              {selectedTask.work_center?.name ?? `Task #${selectedTask.sequence}`}
              {selectedTask.status === 'completed' && <CheckCircle2 className="w-3.5 h-3.5 text-green-500" />}
              {selectedTask.status !== 'pending' && canEdit && (
                <button
                  type="button"
                  onClick={() => setEditOverrideTaskId(isOverridden ? null : selectedTask.id)}
                  className={`inline-flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded-full transition-colors ${
                    isOverridden
                      ? 'bg-amber-100 text-amber-700 hover:bg-amber-200'
                      : 'bg-gray-100 text-gray-500 hover:bg-gray-200'
                  }`}
                  title={isOverridden ? 'Lock task' : 'Unlock to edit schedule'}
                >
                  {isOverridden ? <Pencil className="w-3 h-3" /> : <Lock className="w-3 h-3" />}
                  {isOverridden ? 'Editing' : 'Locked'}
                </button>
              )}
            </h3>
            <button
              type="button"
              onClick={() => { setSelectedTaskId(null); setEditOverrideTaskId(null); }}
              className="text-xs text-gray-400 hover:text-gray-600 px-2 py-0.5 rounded hover:bg-gray-100"
            >
              Close
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-5 gap-3 mb-3">
            {/* Duration */}
            <div>
              <span className="block text-xs font-medium text-gray-500 mb-1">Duration</span>
              {canEdit && isTaskEditable ? (
                <div className="flex items-center gap-1">
                  <input
                    type="number"
                    step="1"
                    min="1"
                    value={editDurationValue}
                    onChange={(e) => setEditDurationValue(e.target.value)}
                    onKeyDown={(e) => { if (e.key === 'Enter') handleDurationSave(); }}
                    className="w-16 px-2 py-1.5 border border-gray-200 rounded-lg text-sm text-center focus:outline-none focus:ring-2 focus:ring-primary/20"
                  />
                  <span className="px-2 py-1.5 text-sm text-gray-500">Hours</span>
                  <button
                    type="button"
                    onClick={handleDurationSave}
                    className="px-2 py-1.5 text-xs font-medium text-white bg-primary rounded-lg hover:bg-primary/90"
                  >
                    Apply
                  </button>
                </div>
              ) : (
                <div className="px-3 py-1.5 border border-gray-100 rounded-lg text-sm bg-gray-50 text-gray-700">
                  {durationLabel(selectedTask.estimated_duration_hours)}
                </div>
              )}
            </div>

            {/* Start Date */}
            <div>
              <span className="block text-xs font-medium text-gray-500 mb-1">Start Date</span>
              {canEdit && isTaskEditable ? (() => {
                const deps = selectedTask.depends_on_task_ids ?? [];
                let minDate = todayStr;
                if (deps.length > 0 && computed) {
                  const depEndDates = deps
                    .map((depId) => computed.slots.find((s) => s.id === depId))
                    .filter(Boolean)
                    .map((s) => toInputDate(s!.planned_end_at));
                  const latestDep = depEndDates.sort().pop();
                  if (latestDep && latestDep > minDate) minDate = latestDep;
                }
                return (
                  <div className="relative">
                    <input
                      type="date"
                      value={selectedSlot ? toInputDate(selectedSlot.planned_start_at) : ''}
                      min={minDate}
                      onChange={(e) => {
                        if (e.target.value < minDate) return;
                        handleTaskDateChange(e.target.value);
                      }}
                      className="w-full px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 text-transparent"
                    />
                    <span className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-sm text-gray-700">
                      {selectedSlot ? formatDate(selectedSlot.planned_start_at) : '—'}
                    </span>
                  </div>
                );
              })() : (
                <div className="px-3 py-1.5 border border-gray-100 rounded-lg text-sm bg-gray-50 text-gray-700">
                  {selectedSlot ? formatDate(selectedSlot.planned_start_at) : '—'}
                </div>
              )}
            </div>

            {/* End Date */}
            <div>
              <span className="block text-xs font-medium text-gray-500 mb-1">End Date</span>
              {canEdit && isTaskEditable ? (
                <div className="relative">
                  <input
                    type="date"
                    value={selectedSlot ? toInputDate(selectedSlot.planned_end_at) : ''}
                    min={selectedSlot ? toInputDate(selectedSlot.planned_start_at) : todayStr}
                    onChange={(e) => {
                      if (!e.target.value) return;
                      handleEndDateForce(e.target.value);
                    }}
                    className="w-full px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 text-transparent"
                  />
                  <span className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-sm text-gray-700">
                    {selectedSlot ? formatDate(selectedSlot.planned_end_at) : '—'}
                  </span>
                </div>
              ) : (
                <div className="px-3 py-1.5 border border-gray-100 rounded-lg text-sm bg-gray-50 text-gray-700">
                  {selectedSlot ? formatDate(selectedSlot.planned_end_at) : '—'}
                </div>
              )}
            </div>

            {/* Status */}
            <div>
              <span className="block text-xs font-medium text-gray-500 mb-1">Status</span>
              <div className="px-3 py-1.5 border border-gray-100 rounded-lg text-sm bg-gray-50">
                <div className="flex items-center gap-2">
                  <div className={`w-2 h-2 rounded-full ${STATUS_DOT[selectedTask.status]}`} />
                  <span className="text-gray-700 capitalize">{selectedTask.status.replace(/_/g, ' ')}</span>
                </div>
                {selectedTask.started_at && (
                  <div className="text-[10px] text-blue-500 mt-0.5">Started: {formatDate(selectedTask.started_at)}</div>
                )}
                {selectedTask.completed_at && (
                  <div className="text-[10px] text-green-500 mt-0.5">Completed: {formatDate(selectedTask.completed_at)}</div>
                )}
              </div>
            </div>

            {/* Operator Assignment */}
            <div>
              <span className="block text-xs font-medium text-gray-500 mb-1 flex items-center gap-1">
                <User className="w-3 h-3" /> Operator
              </span>
              {canEdit ? (
                <select
                  value={selectedTask.assigned_to_user_id ?? '__unassigned__'}
                  onChange={e => {
                    if (e.target.value === '__unassigned__') return;
                    handleAssignOperator(selectedTask.id, e.target.value);
                  }}
                  disabled={materialReadiness?.hasShortage}
                  className="w-full px-2 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 disabled:bg-gray-50 disabled:text-gray-400"
                >
                  <option value="__unassigned__" disabled>Select operator</option>
                  {operators.map(op => (
                    <option key={op.user_id} value={op.user_id}>{op.display_name}</option>
                  ))}
                </select>
              ) : (
                <div className="px-3 py-1.5 border border-gray-100 rounded-lg text-sm bg-gray-50 text-gray-700">
                  {selectedTask.assigned_to ?? 'Unassigned'}
                </div>
              )}
            </div>
          </div>

          {/* Dependencies */}
          {canEdit && (
            <div>
              <span className="block text-xs font-medium text-gray-500 mb-1.5 flex items-center gap-1">
                <Clock className="w-3 h-3" /> Dependencies
              </span>
              <div className="flex flex-wrap items-center gap-1.5">
                {tasks.filter((t) => t.id !== selectedTask.id).map((other) => {
                  const isLinked = (selectedTask.depends_on_task_ids ?? []).includes(other.id);
                  return (
                    <button
                      key={other.id}
                      type="button"
                      onClick={() => handleToggleDependency(other.id)}
                      className={`inline-flex items-center gap-1 px-2 py-1 rounded-lg text-xs border transition-colors ${
                        isLinked
                          ? 'bg-blue-50 border-blue-200 text-blue-700 hover:bg-blue-100'
                          : 'bg-gray-50 border-gray-200 text-gray-400 hover:border-gray-300 hover:text-gray-600'
                      }`}
                    >
                      {isLinked ? <Link2 className="w-3 h-3" /> : <Unlink className="w-3 h-3" />}
                      {other.work_center?.name ?? `#${other.sequence}`}
                    </button>
                  );
                })}
                {tasks.length <= 1 && (
                  <span className="text-xs text-gray-300 italic">No other tasks available</span>
                )}
              </div>
            </div>
          )}

          {/* Schedule History */}
          <TaskChangeHistory taskId={selectedTask.id} />
        </div>
        );
      })()}

      {/* No task selected hint */}
      {computed && tasks.length > 0 && !selectedTask && (
        <div className="text-center py-2">
          <p className="text-xs text-gray-400">Click a task bar or name in the timeline to edit its schedule</p>
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

const SOURCE_BADGE: Record<string, { bg: string; text: string }> = {
  manual: { bg: 'bg-blue-100', text: 'text-blue-700' },
  auto_schedule: { bg: 'bg-violet-100', text: 'text-violet-700' },
  drag_drop: { bg: 'bg-amber-100', text: 'text-amber-700' },
  system: { bg: 'bg-gray-100', text: 'text-gray-600' },
};

function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

function formatChangeValue(iso: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return iso;
  return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
}

function TaskChangeHistory({ taskId }: { taskId: string }) {
  const { data: changelog, isLoading } = useQuery({
    queryKey: scheduleChangelogKey(taskId),
    queryFn: async () => {
      const { data, error } = await supabase
        .from('schedule_changelog')
        .select('*')
        .eq('work_order_task_id', taskId)
        .order('changed_at', { ascending: false })
        .limit(10);
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!taskId,
    staleTime: 30000,
  });

  if (isLoading) {
    return (
      <div className="mt-3">
        <span className="block text-xs font-medium text-gray-500 mb-1.5 flex items-center gap-1">
          <History className="w-3 h-3" /> History
        </span>
        <div className="text-xs text-gray-400 italic">Loading...</div>
      </div>
    );
  }

  if (!changelog || changelog.length === 0) return null;

  return (
    <div className="mt-3">
      <span className="block text-xs font-medium text-gray-500 mb-1.5 flex items-center gap-1">
        <History className="w-3 h-3" /> History
      </span>
      <div className="space-y-1.5 max-h-32 overflow-y-auto">
        {changelog.map((entry: any) => {
          const badge = SOURCE_BADGE[entry.change_source] ?? SOURCE_BADGE.system;
          const fieldLabel = entry.field_changed === 'planned_start_at' ? 'start' : 'end';
          return (
            <div key={entry.id} className="flex items-center gap-2 text-xs text-gray-600">
              <span className="text-gray-400 flex-shrink-0 w-14 text-right">{relativeTime(entry.changed_at)}</span>
              <span>
                Moved {fieldLabel} from{' '}
                <span className="font-medium">{formatChangeValue(entry.old_value)}</span>
                {' → '}
                <span className="font-medium">{formatChangeValue(entry.new_value)}</span>
              </span>
              <span className={`px-1.5 py-0.5 rounded text-[10px] font-medium ${badge.bg} ${badge.text} flex-shrink-0`}>
                {entry.change_source.replace(/_/g, ' ')}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
