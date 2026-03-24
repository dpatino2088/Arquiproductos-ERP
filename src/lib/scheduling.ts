import type { WorkOrderTask } from '../hooks/useWorkOrderTasks';

const HOURS_PER_DAY = 8;
const WORK_START = 8;
const WORK_END = 17;
const SAT_WORK_END = 12;

export interface ScheduledSlot {
  id: string;
  planned_start_at: string;
  planned_end_at: string;
}

export interface DateOverride {
  start: Date;
  end?: Date;
}

export function isWorkDay(dayOfWeek: number): boolean {
  return dayOfWeek !== 0;
}

export function endHourForDay(dayOfWeek: number): number {
  return dayOfWeek === 6 ? SAT_WORK_END : WORK_END;
}

function skipToNextWorkday(d: Date): Date {
  const r = new Date(d);
  while (!isWorkDay(r.getDay())) {
    r.setDate(r.getDate() + 1);
  }
  return r;
}

export function addWorkingHours(start: Date, hours: number): Date {
  const result = new Date(start);
  let remaining = hours;

  while (remaining > 0) {
    const dow = result.getDay();
    if (!isWorkDay(dow)) {
      result.setDate(result.getDate() + 1);
      result.setHours(WORK_START, 0, 0, 0);
      continue;
    }
    const currentHour = result.getHours() + result.getMinutes() / 60;
    const dayEnd = endHourForDay(dow);
    const hoursLeftToday = Math.max(0, dayEnd - currentHour);
    if (hoursLeftToday <= 0) {
      result.setDate(result.getDate() + 1);
      result.setHours(WORK_START, 0, 0, 0);
      continue;
    }
    const consume = Math.min(remaining, hoursLeftToday);
    remaining -= consume;
    result.setTime(result.getTime() + consume * 3600_000);
  }

  return result;
}

/**
 * Topological sort + schedule calculation (auto mode).
 * Given an MO start date and the list of WO tasks (with durations and deps),
 * returns planned_start_at / planned_end_at for each task.
 */
export function computeSchedule(
  moStartDate: Date,
  tasks: WorkOrderTask[]
): { slots: ScheduledSlot[]; moEndDate: Date; totalDays: number } {
  return computeScheduleWithOverrides(moStartDate, tasks, new Map());
}

/**
 * Schedule with manual date overrides.
 * Tasks with an override use those dates directly; others are auto-scheduled
 * respecting dependencies on overridden tasks.
 */
export function computeScheduleWithOverrides(
  moStartDate: Date,
  tasks: WorkOrderTask[],
  overrides: Map<string, DateOverride>
): { slots: ScheduledSlot[]; moEndDate: Date; totalDays: number } {
  if (tasks.length === 0) {
    return { slots: [], moEndDate: moStartDate, totalDays: 0 };
  }

  const taskMap = new Map(tasks.map((t) => [t.id, t]));
  const endTimes = new Map<string, Date>();
  const startTimes = new Map<string, Date>();
  const visited = new Set<string>();
  const visiting = new Set<string>();

  function resolve(taskId: string): Date {
    if (endTimes.has(taskId)) return endTimes.get(taskId)!;
    if (visiting.has(taskId)) {
      throw new Error('Circular dependency detected in Work Order tasks');
    }
    visiting.add(taskId);

    const task = taskMap.get(taskId);
    if (!task) throw new Error(`Task ${taskId} not found`);

    const override = overrides.get(taskId);
    const hours = task.estimated_duration_hours ?? HOURS_PER_DAY;

    let taskStart: Date;
    let taskEnd: Date;

    if (override) {
      const requestedStart = skipToNextWorkday(new Date(override.start));
      const ovH = new Date(override.start).getHours();
      const dayEndH = endHourForDay(requestedStart.getDay());
      if (ovH >= WORK_START && ovH < dayEndH) {
        requestedStart.setHours(ovH, new Date(override.start).getMinutes(), 0, 0);
      } else {
        requestedStart.setHours(WORK_START, 0, 0, 0);
      }
      taskStart = new Date(requestedStart);

      const deps = task.depends_on_task_ids ?? [];
      if (deps.length > 0 && task.dependency_type !== 'start_to_start') {
        const depEnds: Date[] = [];
        for (const depId of deps) {
          if (taskMap.has(depId)) depEnds.push(resolve(depId));
        }
        if (depEnds.length > 0) {
          const latestEnd = new Date(Math.max(...depEnds.map((d) => d.getTime())));
          const leh = latestEnd.getHours() + latestEnd.getMinutes() / 60;
          const depDow = latestEnd.getDay();
          const depDayEnd = endHourForDay(depDow);
          let minStart: Date;
          if (leh <= WORK_START && isWorkDay(depDow)) {
            minStart = new Date(latestEnd);
            minStart.setHours(WORK_START, 0, 0, 0);
          } else if (isWorkDay(depDow) && leh < depDayEnd) {
            minStart = new Date(latestEnd);
          } else {
            minStart = new Date(latestEnd);
            minStart.setDate(minStart.getDate() + 1);
            minStart.setHours(WORK_START, 0, 0, 0);
            minStart = skipToNextWorkday(minStart);
          }
          if (taskStart < minStart) taskStart = minStart;
        }
      }

      taskEnd = override.end
        ? new Date(override.end)
        : addWorkingHours(new Date(taskStart), hours);
    } else {
      const deps = task.depends_on_task_ids ?? [];

      if (deps.length === 0) {
        taskStart = skipToNextWorkday(new Date(moStartDate));
        taskStart.setHours(WORK_START, 0, 0, 0);
        } else {
          const depEnds: Date[] = [];
          for (const depId of deps) {
            if (taskMap.has(depId)) {
              depEnds.push(resolve(depId));
            }
          }
          if (depEnds.length === 0) {
            taskStart = skipToNextWorkday(new Date(moStartDate));
            taskStart.setHours(WORK_START, 0, 0, 0);
          } else if (task.dependency_type === 'start_to_start') {
            const depStarts = deps
              .filter((id) => startTimes.has(id))
              .map((id) => startTimes.get(id)!);
            taskStart = depStarts.length > 0
              ? new Date(Math.max(...depStarts.map((d) => d.getTime())))
              : skipToNextWorkday(new Date(moStartDate));
            taskStart.setHours(WORK_START, 0, 0, 0);
          } else {
            const latestEnd = new Date(Math.max(...depEnds.map((d) => d.getTime())));
            const endHour = latestEnd.getHours() + latestEnd.getMinutes() / 60;
            const depDow = latestEnd.getDay();
            const depDayEnd = endHourForDay(depDow);

            if (endHour <= WORK_START && isWorkDay(depDow)) {
              taskStart = new Date(latestEnd);
              taskStart.setHours(WORK_START, 0, 0, 0);
            } else if (isWorkDay(depDow) && endHour < depDayEnd) {
              taskStart = new Date(latestEnd);
            } else {
              taskStart = new Date(latestEnd);
              taskStart.setDate(taskStart.getDate() + 1);
              taskStart.setHours(WORK_START, 0, 0, 0);
              taskStart = skipToNextWorkday(taskStart);
            }
          }
        }

      taskEnd = addWorkingHours(new Date(taskStart), hours);
    }

    startTimes.set(taskId, new Date(taskStart));
    endTimes.set(taskId, taskEnd);
    visiting.delete(taskId);
    visited.add(taskId);

    return taskEnd;
  }

  for (const t of tasks) {
    if (!visited.has(t.id)) {
      resolve(t.id);
    }
  }

  const slots: ScheduledSlot[] = tasks.map((t) => ({
    id: t.id,
    planned_start_at: startTimes.get(t.id)!.toISOString(),
    planned_end_at: endTimes.get(t.id)!.toISOString(),
  }));

  const allEnds = Array.from(endTimes.values());
  const moEndDate = new Date(Math.max(...allEnds.map((d) => d.getTime())));

  const diffMs = moEndDate.getTime() - moStartDate.getTime();
  const totalDays = Math.max(1, Math.ceil(diffMs / (1000 * 60 * 60 * 24)));

  return { slots, moEndDate, totalDays };
}

/**
 * Move a single task to a new start date (keeping duration), then
 * cascade dependent tasks forward.
 */
export function moveTaskToDate(
  moStartDate: Date,
  tasks: WorkOrderTask[],
  taskId: string,
  newStartDate: Date,
  existingSlots: ScheduledSlot[]
): ScheduledSlot[] {
  const overrides = new Map<string, DateOverride>();

  for (const slot of existingSlots) {
    if (slot.id === taskId) {
      overrides.set(taskId, { start: newStartDate });
    } else {
      overrides.set(slot.id, {
        start: new Date(slot.planned_start_at),
        end: new Date(slot.planned_end_at),
      });
    }
  }

  const dependentIds = findDependents(tasks, taskId);
  for (const depId of dependentIds) {
    overrides.delete(depId);
  }

  const result = computeScheduleWithOverrides(moStartDate, tasks, overrides);
  return result.slots;
}

export function findDependents(tasks: WorkOrderTask[], taskId: string): Set<string> {
  const result = new Set<string>();
  const queue = [taskId];
  while (queue.length > 0) {
    const current = queue.shift()!;
    for (const t of tasks) {
      if (result.has(t.id)) continue;
      if ((t.depends_on_task_ids ?? []).includes(current)) {
        result.add(t.id);
        queue.push(t.id);
      }
    }
  }
  return result;
}

/**
 * Check if an MO is ready to be scheduled (release check).
 */
export interface ScheduleReadiness {
  canSchedule: boolean;
  blockers: string[];
  warnings: string[];
}

export function checkScheduleReadiness(
  tasks: WorkOrderTask[],
  materialStatus: 'complete' | 'incomplete' | null,
): ScheduleReadiness {
  const blockers: string[] = [];
  const warnings: string[] = [];

  if (tasks.length === 0) {
    blockers.push('No Work Orders generated');
  }

  const missingDuration = tasks.filter((t) => !t.estimated_duration_hours || t.estimated_duration_hours <= 0);
  if (missingDuration.length > 0) {
    blockers.push(`${missingDuration.length} WO(s) missing estimated duration`);
  }

  const missingWC = tasks.filter((t) => !t.work_center_id);
  if (missingWC.length > 0) {
    blockers.push(`${missingWC.length} WO(s) missing Work Center`);
  }

  if (materialStatus === 'incomplete') {
    blockers.push('Materials incomplete — resolve Material Demand before scheduling');
  }

  return {
    canSchedule: blockers.length === 0,
    blockers,
    warnings,
  };
}
