import type { WorkOrderTask } from '../hooks/useWorkOrderTasks';

const HOURS_PER_DAY = 8;

interface ScheduledSlot {
  id: string;
  planned_start_at: string;
  planned_end_at: string;
}

function addWorkingHours(start: Date, hours: number): Date {
  const result = new Date(start);
  let remaining = hours;

  while (remaining > 0) {
    const dayOfWeek = result.getDay();
    if (dayOfWeek === 0 || dayOfWeek === 6) {
      result.setDate(result.getDate() + 1);
      result.setHours(8, 0, 0, 0);
      continue;
    }
    const currentHour = result.getHours() + result.getMinutes() / 60;
    const hoursLeftToday = Math.max(0, 17 - currentHour);
    if (hoursLeftToday <= 0) {
      result.setDate(result.getDate() + 1);
      result.setHours(8, 0, 0, 0);
      continue;
    }
    const consume = Math.min(remaining, hoursLeftToday);
    remaining -= consume;
    result.setTime(result.getTime() + consume * 3600_000);
  }

  return result;
}

/**
 * Topological sort + schedule calculation.
 * Given an MO start date and the list of WO tasks (with durations and deps),
 * returns planned_start_at / planned_end_at for each task.
 */
export function computeSchedule(
  moStartDate: Date,
  tasks: WorkOrderTask[]
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

    let taskStart: Date;
    const deps = task.depends_on_task_ids ?? [];

    if (deps.length === 0) {
      taskStart = new Date(moStartDate);
      taskStart.setHours(8, 0, 0, 0);
    } else {
      const depEnds: Date[] = [];
      for (const depId of deps) {
        if (taskMap.has(depId)) {
          depEnds.push(resolve(depId));
        }
      }
      if (depEnds.length === 0) {
        taskStart = new Date(moStartDate);
        taskStart.setHours(8, 0, 0, 0);
      } else if (task.dependency_type === 'start_to_start') {
        const depStarts = deps
          .filter((id) => startTimes.has(id))
          .map((id) => startTimes.get(id)!);
        taskStart = depStarts.length > 0
          ? new Date(Math.max(...depStarts.map((d) => d.getTime())))
          : new Date(moStartDate);
        taskStart.setHours(8, 0, 0, 0);
      } else {
        taskStart = new Date(Math.max(...depEnds.map((d) => d.getTime())));
        if (taskStart.getHours() >= 17 || taskStart.getDay() === 0 || taskStart.getDay() === 6) {
          taskStart.setDate(taskStart.getDate() + 1);
          taskStart.setHours(8, 0, 0, 0);
          while (taskStart.getDay() === 0 || taskStart.getDay() === 6) {
            taskStart.setDate(taskStart.getDate() + 1);
          }
        }
      }
    }

    startTimes.set(taskId, new Date(taskStart));
    const taskEnd = addWorkingHours(new Date(taskStart), task.estimated_duration_hours ?? HOURS_PER_DAY);
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
  const totalDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

  return { slots, moEndDate, totalDays };
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
    warnings.push('Materials incomplete — generate Purchase Order first');
  }

  return {
    canSchedule: blockers.length === 0,
    blockers,
    warnings,
  };
}
