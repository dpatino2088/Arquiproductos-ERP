import { useState, useEffect, useCallback, useRef } from 'react';
import { supabase } from '../lib/supabase/client';
import { advanceMOOnTaskStart, advanceMOOnAllTasksComplete } from '../lib/moLifecycle';
import { useUIStore } from '../stores/ui-store';

export interface WorkOrderTaskLine {
  id: string;
  task_id: string;
  bom_instance_line_id: string | null;
  catalog_item_id: string | null;
  sku: string | null;
  item_name: string | null;
  component_role: string | null;
  qty: number;
  uom: string;
  cut_length_mm: number | null;
  cut_width_mm: number | null;
  completed: boolean;
  completed_at: string | null;
}

export interface WorkOrderTask {
  id: string;
  organization_id: string;
  manufacturing_order_id: string;
  work_center_id: string;
  sales_order_line_id: string | null;
  sequence: number;
  status: 'pending' | 'in_progress' | 'completed';
  assigned_to: string | null;
  assigned_to_user_id: string | null;
  completed_by_user_id: string | null;
  started_at: string | null;
  completed_at: string | null;
  estimated_duration_hours: number;
  planned_start_at: string | null;
  planned_end_at: string | null;
  depends_on_task_ids: string[];
  dependency_type: 'finish_to_start' | 'start_to_start';
  work_center?: { id: string; code: string; name: string; sequence: number } | null;
  lines: WorkOrderTaskLine[];
}

export function useWorkOrderTasks(moId: string | null | undefined) {
  const [tasks, setTasks] = useState<WorkOrderTask[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const initialLoadDone = useRef(false);
  const addNotification = useUIStore((s) => s.addNotification);

  const fetchAll = useCallback(async () => {
    if (!moId) { setTasks([]); return; }
    if (!initialLoadDone.current) setLoading(true);
    setError(null);
    try {
      const { data: taskData, error: tErr } = await supabase
        .from('WorkOrderTasks')
        .select(`
          id, organization_id, manufacturing_order_id, work_center_id,
          sales_order_line_id,
          sequence, status, assigned_to, assigned_to_user_id, completed_by_user_id,
          started_at, completed_at,
          estimated_duration_hours, planned_start_at, planned_end_at,
          depends_on_task_ids, dependency_type,
          WorkCenters:work_center_id (id, code, name, sequence)
        `)
        .eq('manufacturing_order_id', moId)
        .eq('deleted', false)
        .order('sequence');

      if (tErr) throw new Error(tErr.message);
      if (!taskData || taskData.length === 0) { setTasks([]); setLoading(false); initialLoadDone.current = true; return; }

      const taskIds = taskData.map((t: any) => t.id);
      const { data: lineData, error: lErr } = await supabase
        .from('WorkOrderTaskLines')
        .select('*')
        .in('task_id', taskIds)
        .order('created_at');

      if (lErr) throw new Error(lErr.message);

      const linesByTask: Record<string, WorkOrderTaskLine[]> = {};
      for (const l of (lineData ?? [])) {
        if (!linesByTask[l.task_id]) linesByTask[l.task_id] = [];
        linesByTask[l.task_id].push(l);
      }

      const result: WorkOrderTask[] = taskData.map((t: any) => ({
        id: t.id,
        organization_id: t.organization_id,
        manufacturing_order_id: t.manufacturing_order_id,
        work_center_id: t.work_center_id,
        sales_order_line_id: t.sales_order_line_id ?? null,
        sequence: t.sequence,
        status: t.status,
        assigned_to: t.assigned_to,
        assigned_to_user_id: t.assigned_to_user_id ?? null,
        completed_by_user_id: t.completed_by_user_id ?? null,
        started_at: t.started_at,
        completed_at: t.completed_at,
        estimated_duration_hours: t.estimated_duration_hours ?? 8,
        planned_start_at: t.planned_start_at ?? null,
        planned_end_at: t.planned_end_at ?? null,
        depends_on_task_ids: t.depends_on_task_ids ?? [],
        dependency_type: t.dependency_type ?? 'finish_to_start',
        work_center: t.WorkCenters ?? null,
        lines: linesByTask[t.id] ?? [],
      }));

      setTasks(result);
      initialLoadDone.current = true;
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error loading work order tasks');
    } finally {
      setLoading(false);
    }
  }, [moId]);

  useEffect(() => { fetchAll(); }, [fetchAll]);

  // Operator assignment is optional and never blocks starting/completing a task.
  // Kept for call-site compatibility; always allows the action to proceed.
  const ensureTaskAssigned = useCallback(
    async (_taskId: string, _actionLabel: string): Promise<boolean> => true,
    [],
  );

  const patchTask = useCallback((taskId: string, patch: Partial<WorkOrderTask>) => {
    setTasks((prev) => prev.map((t) => t.id === taskId ? { ...t, ...patch } : t));
  }, []);

  const patchLine = useCallback((lineId: string, patch: Partial<WorkOrderTaskLine>) => {
    setTasks((prev) => prev.map((t) => ({
      ...t,
      lines: t.lines.map((l) => l.id === lineId ? { ...l, ...patch } : l),
    })));
  }, []);

  const ensureLineMaterialsReady = useCallback(async (lineId: string): Promise<boolean> => {
    const { data: lineData } = await supabase
      .from('WorkOrderTaskLines')
      .select('task_id, bom_instance_line_id')
      .eq('id', lineId)
      .single();
    if (!lineData?.task_id) return false;
    if (!lineData.bom_instance_line_id) return true;

    const { data: taskData } = await supabase
      .from('WorkOrderTasks')
      .select('manufacturing_order_id')
      .eq('id', lineData.task_id)
      .single();
    if (!taskData?.manufacturing_order_id) return true;

    const { data: bilData } = await supabase
      .from('BOMInstanceLines')
      .select('bom_instance_id')
      .eq('id', lineData.bom_instance_line_id)
      .single();
    if (!bilData?.bom_instance_id) return true;

    const { data: biData } = await supabase
      .from('BOMInstances')
      .select('manufacturing_order_line_id')
      .eq('id', bilData.bom_instance_id)
      .single();
    const molId = biData?.manufacturing_order_line_id as string | null;
    if (!molId) return true;

    const { data: readinessRows, error } = await supabase.rpc('get_mo_line_material_readiness', {
      p_mo_id: taskData.manufacturing_order_id,
    });
    if (error) {
      addNotification({
        type: 'error',
        title: 'Materials',
        message: error.message ?? 'Could not validate line material readiness.',
      });
      return false;
    }

    const lineReadiness = ((readinessRows as Array<{ manufacturing_order_line_id: string; readiness_status: string }> | null) ?? [])
      .find((r) => r.manufacturing_order_line_id === molId);
    if (lineReadiness?.readiness_status === 'incomplete') {
      addNotification({
        type: 'warning',
        title: 'Line Not Ready',
        message: 'This line is incomplete. Cover missing materials before marking progress.',
      });
      return false;
    }

    return true;
  }, [addNotification]);

  const toggleLineCompleted = useCallback(async (lineId: string, completed: boolean) => {
    if (completed) {
      const { data: lineTask } = await supabase
        .from('WorkOrderTaskLines')
        .select('task_id')
        .eq('id', lineId)
        .single();
      const taskIdForLine = lineTask?.task_id ?? null;
      if (taskIdForLine) {
        const { data: taskForLine } = await supabase
          .from('WorkOrderTasks')
          .select('status')
          .eq('id', taskIdForLine)
          .single();
        if (taskForLine?.status !== 'in_progress') {
          addNotification({
            type: 'warning',
            title: 'Task Not Started',
            message: 'Press Play to start this task before checking lines.',
          });
          return;
        }
        const canAdvance = await ensureTaskAssigned(taskIdForLine, 'completing line items');
        if (!canAdvance) return;
        const lineReady = await ensureLineMaterialsReady(lineId);
        if (!lineReady) return;
      }
    }

    const now = new Date().toISOString();
    patchLine(lineId, { completed, completed_at: completed ? now : null });

    const { error: err } = await supabase
      .from('WorkOrderTaskLines')
      .update({ completed, completed_at: completed ? now : null })
      .eq('id', lineId);
    if (err) {
      patchLine(lineId, { completed: !completed, completed_at: null });
      throw new Error(err.message);
    }

    if (!completed) return;

    const { data: siblingLines } = await supabase
      .from('WorkOrderTaskLines')
      .select('id, completed, task_id')
      .eq('task_id', (await supabase
        .from('WorkOrderTaskLines')
        .select('task_id')
        .eq('id', lineId)
        .single()
      ).data?.task_id ?? '')
      .order('created_at');

    if (!siblingLines || siblingLines.length === 0) return;

    const taskId = siblingLines[0].task_id;
    const allLinesCompleted = siblingLines.every((l: { id: string; completed: boolean }) =>
      l.id === lineId ? true : l.completed,
    );
    if (!allLinesCompleted) return;

    const { data: taskRow } = await supabase
      .from('WorkOrderTasks')
      .select('status')
      .eq('id', taskId)
      .single();

    if (taskRow?.status === 'in_progress') {
      await updateTaskStatusInternal(taskId, 'completed');
    }
  }, [patchLine, ensureTaskAssigned, ensureLineMaterialsReady, addNotification]);

  /**
   * Bulk toggle a set of assembly lines belonging to the same task.
   * - Single DB UPDATE for all lines (no N round-trips).
   * - Auto-transitions the task to 'in_progress' BEFORE touching lines, since
   *   a DB trigger forbids updating WorkOrderTaskLines.completed when the task
   *   is not in_progress. This handles both the "pending" path and the broken
   *   "completed-with-uncompleted-lines" recovery path.
   * - Auto-completes the task if every line in it is completed after the update.
   * Optimistic UI: one setTasks call per DB step -> no flicker, no race conditions.
   */
  const bulkToggleAssemblyLines = useCallback(
    async (lineIds: string[], completed: boolean) => {
      if (lineIds.length === 0) return;

      // Find the task that owns these lines from local state.
      let task = tasks.find((t) => t.lines.some((l) => lineIds.includes(l.id)));
      if (!task) {
        const { data: lineRow } = await supabase
          .from('WorkOrderTaskLines')
          .select('task_id')
          .eq('id', lineIds[0])
          .single();
        if (!lineRow?.task_id) return;
        task = tasks.find((t) => t.id === lineRow.task_id);
        if (!task) return;
      }
      const taskId = task.id;
      const prevTask = task;

      const canAdvance = await ensureTaskAssigned(
        taskId,
        completed ? 'completing line items' : 'undoing line items',
      );
      if (!canAdvance) return;

      const now = new Date().toISOString();
      const lineSet = new Set(lineIds);
      const effectiveMoId = moId ?? prevTask.manufacturing_order_id;

      // ─── Phase A: ensure task is in_progress before touching lines ────────
      // The DB trigger trg_woline_completed_requires_task_in_progress enforces
      // that lines can only be (un)completed while the task is in_progress.
      const taskMustBeInProgress = prevTask.status !== 'in_progress';
      if (taskMustBeInProgress) {
        const dbStartUpdates: Record<string, unknown> = {
          status: 'in_progress',
          updated_at: now,
        };
        if (!prevTask.started_at) dbStartUpdates.started_at = now;
        // If we're recovering from 'completed', clear completed_at.
        if (prevTask.status === 'completed') dbStartUpdates.completed_at = null;

        // Optimistic: flip task to in_progress.
        setTasks((prev) =>
          prev.map((t) =>
            t.id !== taskId
              ? t
              : {
                  ...t,
                  status: 'in_progress',
                  started_at: t.started_at ?? now,
                  completed_at: prevTask.status === 'completed' ? null : t.completed_at,
                },
          ),
        );

        const { error: startErr } = await supabase
          .from('WorkOrderTasks')
          .update(dbStartUpdates)
          .eq('id', taskId);
        if (startErr) {
          // Rollback to original task snapshot.
          setTasks((prev) => prev.map((t) => (t.id !== taskId ? t : prevTask)));
          throw new Error(startErr.message);
        }

        if (prevTask.status === 'pending' && effectiveMoId) {
          await advanceMOOnTaskStart(effectiveMoId).catch(() => {});
        }
      }

      // ─── Phase B: bulk update line completion ─────────────────────────────
      const nextLines = prevTask.lines.map((l) =>
        lineSet.has(l.id) ? { ...l, completed, completed_at: completed ? now : null } : l,
      );

      // Optimistic: apply line changes.
      setTasks((prev) =>
        prev.map((t) =>
          t.id !== taskId
            ? t
            : {
                ...t,
                lines: nextLines,
              },
        ),
      );

      const { error: linesErr } = await supabase
        .from('WorkOrderTaskLines')
        .update({ completed, completed_at: completed ? now : null })
        .in('id', lineIds);
      if (linesErr) {
        // Roll back lines to previous; leave task as in_progress (safe state).
        setTasks((prev) =>
          prev.map((t) => (t.id !== taskId ? t : { ...t, lines: prevTask.lines })),
        );
        throw new Error(linesErr.message);
      }

      // ─── Phase C: maybe auto-complete the task ───────────────────────────
      const allCompletedAfter = nextLines.every((l) => l.completed);
      if (completed && allCompletedAfter) {
        const dbCompleteUpdates: Record<string, unknown> = {
          status: 'completed',
          completed_at: now,
          updated_at: now,
        };

        setTasks((prev) =>
          prev.map((t) =>
            t.id !== taskId
              ? t
              : { ...t, status: 'completed', completed_at: now },
          ),
        );

        const { error: completeErr } = await supabase
          .from('WorkOrderTasks')
          .update(dbCompleteUpdates)
          .eq('id', taskId);
        if (completeErr) {
          // Soft-fail: lines are saved, but task didn't auto-complete.
          // Don't rollback line state since lines are correctly persisted.
          setTasks((prev) =>
            prev.map((t) =>
              t.id !== taskId ? t : { ...t, status: 'in_progress', completed_at: null },
            ),
          );
          // eslint-disable-next-line no-console
          console.warn('[useWorkOrderTasks] task auto-complete failed:', completeErr);
          return;
        }

        if (effectiveMoId) {
          // Auto-start downstream tasks whose deps are now met.
          const { data: allTasks } = await supabase
            .from('WorkOrderTasks')
            .select('id, status, depends_on_task_ids, assigned_to_user_id, planned_start_at')
            .eq('manufacturing_order_id', effectiveMoId)
            .eq('deleted', false);
          if (allTasks) {
            const completedIds = new Set(
              allTasks
                .filter((t: any) => t.id === taskId || t.status === 'completed')
                .map((t: any) => t.id),
            );
            const toAutoStart = allTasks.filter((t: any) => {
              if (t.id === taskId) return false;
              if (t.status !== 'pending') return false;
              if (!t.assigned_to_user_id) return false;
              if (!t.planned_start_at || new Date(t.planned_start_at).getTime() > Date.now()) {
                return false;
              }
              const deps = t.depends_on_task_ids ?? [];
              if (deps.length === 0) return false;
              return deps.every((depId: string) => completedIds.has(depId));
            });
            if (toAutoStart.length > 0) {
              const autoStartIds = toAutoStart.map((t: any) => t.id);
              setTasks((prev) =>
                prev.map((t) =>
                  autoStartIds.includes(t.id)
                    ? { ...t, status: 'in_progress', started_at: now }
                    : t,
                ),
              );
              await supabase
                .from('WorkOrderTasks')
                .update({ status: 'in_progress', started_at: now, updated_at: now })
                .in('id', autoStartIds)
                .then(() => {}, () => {});
            }
            const allCompleted = allTasks.every((t: any) =>
              t.id === taskId ? true : t.status === 'completed',
            );
            if (allCompleted) {
              await advanceMOOnAllTasksComplete(effectiveMoId).catch(() => {});
            }
          }
        }
      }
    },
    [tasks, ensureTaskAssigned, moId],
  );

  const updateTaskStatusInternal = useCallback(async (taskId: string, status: 'pending' | 'in_progress' | 'completed') => {
    const { data: currentTask } = await supabase
      .from('WorkOrderTasks')
      .select('status, started_at, completed_at, manufacturing_order_id, planned_start_at')
      .eq('id', taskId)
      .single();

    if (status === 'in_progress' || status === 'completed') {
      const canAdvance = await ensureTaskAssigned(
        taskId,
        status === 'in_progress' ? 'starting this task' : 'completing this task',
      );
      if (!canAdvance) return;

      if (status === 'in_progress') {
        // Schedule is optional: if there is no planned start, it defaults to now()
        // (also enforced by the DB). Only an explicitly scheduled future date blocks.
        const plannedStart = currentTask?.planned_start_at ? new Date(currentTask.planned_start_at) : null;
        if (plannedStart && plannedStart.getTime() > Date.now()) {
          addNotification({
            type: 'warning',
            title: 'Too Early to Start',
            message: 'This task is scheduled for a future date; it can only start on or after that date/time.',
          });
          return;
        }
      }
    }

    const now = new Date().toISOString();

    const prevStatus = currentTask?.status;
    const prevStarted = currentTask?.started_at;
    const prevCompleted = currentTask?.completed_at;
    const effectiveMoId = moId ?? currentTask?.manufacturing_order_id;

    const optimistic: Partial<WorkOrderTask> = { status };
    const dbUpdates: Record<string, unknown> = { status, updated_at: now };

    if (status === 'in_progress' && !currentTask?.started_at) {
      optimistic.started_at = now;
      dbUpdates.started_at = now;
    }
    if (status === 'in_progress' && !currentTask?.planned_start_at) {
      optimistic.planned_start_at = now;
      dbUpdates.planned_start_at = now;
    }
    if (status === 'completed') {
      optimistic.completed_at = now;
      dbUpdates.completed_at = now;
    }

    patchTask(taskId, optimistic);

    const { error: err } = await supabase
      .from('WorkOrderTasks')
      .update(dbUpdates)
      .eq('id', taskId);
    if (err) {
      patchTask(taskId, { status: prevStatus, started_at: prevStarted, completed_at: prevCompleted });
      throw new Error(err.message);
    }

    if (status === 'in_progress' && effectiveMoId) {
      await advanceMOOnTaskStart(effectiveMoId, (msg) => {
        addNotification({ type: 'warning', title: 'Task Started', message: msg });
      });
    }

    if (status === 'completed' && effectiveMoId) {
      const { data: allTasks } = await supabase
        .from('WorkOrderTasks')
        .select('id, status, depends_on_task_ids, assigned_to_user_id, planned_start_at')
        .eq('manufacturing_order_id', effectiveMoId)
        .eq('deleted', false);

      if (allTasks) {
        const completedIds = new Set(
          allTasks.filter((t: any) => t.id === taskId || t.status === 'completed').map((t: any) => t.id)
        );

        const toAutoStart = allTasks.filter((t: any) => {
          if (t.id === taskId) return false;
          if (t.status !== 'pending') return false;
          if (!t.assigned_to_user_id) return false;
          if (!t.planned_start_at || new Date(t.planned_start_at).getTime() > Date.now()) return false;
          const deps = t.depends_on_task_ids ?? [];
          if (deps.length === 0) return false;
          return deps.every((depId: string) => completedIds.has(depId));
        });

        if (toAutoStart.length > 0) {
          const autoStartIds = toAutoStart.map((t: any) => t.id);
          for (const t of toAutoStart) {
            patchTask(t.id, { status: 'in_progress', started_at: now });
          }
          await supabase
            .from('WorkOrderTasks')
            .update({ status: 'in_progress', started_at: now, updated_at: now })
            .in('id', autoStartIds)
            .catch(() => {});
        }

        const allCompleted = allTasks.every((t: any) =>
          t.id === taskId ? true : t.status === 'completed'
        );
        if (allCompleted && effectiveMoId) {
          await advanceMOOnAllTasksComplete(effectiveMoId);
        }
      }

      // No fetchAll() here: optimistic patches already reflect the new state.
      // Refetching wipes references and re-triggers structural fetches in
      // children (e.g. AssemblyDetail), which causes the visible flicker.
    }
  }, [patchTask, moId, ensureTaskAssigned, addNotification]);

  const updateTaskStatus = updateTaskStatusInternal;

  const updateTaskScheduling = useCallback(async (
    taskId: string,
    updates: {
      estimated_duration_hours?: number;
      depends_on_task_ids?: string[];
      dependency_type?: 'finish_to_start' | 'start_to_start';
      planned_start_at?: string | null;
      planned_end_at?: string | null;
    }
  ) => {
    const task = tasks.find((t) => t.id === taskId);
    const prev = task ? { ...task } : null;

    patchTask(taskId, updates as Partial<WorkOrderTask>);

    const { error: err } = await supabase
      .from('WorkOrderTasks')
      .update({ ...updates, updated_at: new Date().toISOString() })
      .eq('id', taskId);
    if (err) {
      if (prev) patchTask(taskId, prev);
      throw new Error(err.message);
    }
  }, [tasks, patchTask]);

  const bulkUpdatePlannedDates = useCallback(async (
    updates: { id: string; planned_start_at: string; planned_end_at: string }[]
  ) => {
    const prevTasks = [...tasks];

    for (const u of updates) {
      patchTask(u.id, { planned_start_at: u.planned_start_at, planned_end_at: u.planned_end_at });
    }

    try {
      for (const u of updates) {
        const { error: err } = await supabase
          .from('WorkOrderTasks')
          .update({
            planned_start_at: u.planned_start_at,
            planned_end_at: u.planned_end_at,
            updated_at: new Date().toISOString(),
          })
          .eq('id', u.id);
        if (err) throw new Error(err.message);
      }
    } catch (e) {
      setTasks(prevTasks);
      throw e;
    }
  }, [tasks, patchTask]);

  const generateWorkOrders = useCallback(async (regenerate = false) => {
    if (!moId) return;
    const { data, error: err } = await supabase.rpc('generate_work_orders_for_mo', {
      p_mo_id: moId,
      p_regenerate: regenerate,
    });
    if (err) throw new Error(err.message);
    const result = data as { ok?: boolean; error?: string } | null;
    if (result?.ok === false && result?.error) throw new Error(result.error);
    await fetchAll();
    return data;
  }, [moId, fetchAll]);

  const updateTaskPlannedDates = useCallback(async (
    taskId: string,
    planned_start_at: string,
    planned_end_at: string
  ) => {
    const task = tasks.find((t) => t.id === taskId);
    const prevStart = task?.planned_start_at ?? null;
    const prevEnd = task?.planned_end_at ?? null;

    patchTask(taskId, { planned_start_at, planned_end_at });

    const { error: err } = await supabase
      .from('WorkOrderTasks')
      .update({ planned_start_at, planned_end_at, updated_at: new Date().toISOString() })
      .eq('id', taskId);
    if (err) {
      patchTask(taskId, { planned_start_at: prevStart, planned_end_at: prevEnd });
      throw new Error(err.message);
    }
  }, [tasks, patchTask]);

  return {
    tasks, loading, error, refetch: fetchAll,
    toggleLineCompleted, bulkToggleAssemblyLines,
    updateTaskStatus, updateTaskScheduling,
    bulkUpdatePlannedDates, updateTaskPlannedDates, generateWorkOrders,
  };
}
