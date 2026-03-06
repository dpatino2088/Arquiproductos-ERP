import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useWorkCenters, type WorkCenter } from '../../hooks/useWorkCenters';
import { useOrganizationContext } from '../../context/OrganizationContext';
import StatusBadge from '../../components/shared/StatusBadge';
import { router } from '../../lib/router';
import {
  Factory,
  ChevronDown,
  ChevronRight,
  Play,
  CheckCircle2,
  Loader2,
  Printer,
  Tag,
  ArrowLeft,
} from 'lucide-react';

interface TaskLine {
  id: string;
  sku: string | null;
  item_name: string | null;
  component_role: string | null;
  qty: number;
  uom: string;
  cut_length_mm: number | null;
  cut_width_mm: number | null;
  completed: boolean;
}

interface TaskWithMO {
  id: string;
  manufacturing_order_id: string;
  sequence: number;
  status: 'pending' | 'in_progress' | 'completed';
  assigned_to: string | null;
  started_at: string | null;
  completed_at: string | null;
  mo_number: string;
  customer_name: string;
  product_name: string;
  due_date: string | null;
  lines: TaskLine[];
}

interface WorkstationViewProps {
  workCenterId?: string;
}

export default function WorkstationView({ workCenterId }: WorkstationViewProps) {
  const { centers, loading: centersLoading } = useWorkCenters();
  const { activeOrganizationId } = useOrganizationContext();
  const [selectedCenter, setSelectedCenter] = useState<string | null>(workCenterId ?? null);
  const [tasks, setTasks] = useState<TaskWithMO[]>([]);
  const [loadingTasks, setLoadingTasks] = useState(false);
  const [expandedTask, setExpandedTask] = useState<string | null>(null);

  useEffect(() => {
    if (workCenterId) setSelectedCenter(workCenterId);
  }, [workCenterId]);

  useEffect(() => {
    if (centers.length > 0 && !selectedCenter) {
      setSelectedCenter(centers[0].id);
    }
  }, [centers, selectedCenter]);

  const fetchTasks = useCallback(async () => {
    if (!selectedCenter || !activeOrganizationId) return;
    setLoadingTasks(true);
    try {
      const { data: taskData, error: tErr } = await supabase
        .from('WorkOrderTasks')
        .select('id, manufacturing_order_id, sequence, status, assigned_to, started_at, completed_at')
        .eq('work_center_id', selectedCenter)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .in('status', ['pending', 'in_progress'])
        .order('sequence');

      if (tErr) throw new Error(tErr.message);
      if (!taskData || taskData.length === 0) { setTasks([]); setLoadingTasks(false); return; }

      const moIds = [...new Set(taskData.map((t: any) => t.manufacturing_order_id))];
      const { data: moData } = await supabase
        .from('ManufacturingOrders')
        .select('id, manufacturing_order_no, product_name, sales_order_id')
        .in('id', moIds);

      const moMap: Record<string, any> = {};
      for (const mo of (moData ?? [])) moMap[mo.id] = mo;

      const soIds = [...new Set((moData ?? []).map((m: any) => m.sales_order_id).filter(Boolean))];
      let customerMap: Record<string, string> = {};
      let dueDateMap: Record<string, string | null> = {};
      if (soIds.length > 0) {
        const { data: soData } = await supabase
          .from('SalesOrders')
          .select('id, customer_id, expected_delivery_date')
          .in('id', soIds);
        const custIds = [...new Set((soData ?? []).map((s: any) => s.customer_id).filter(Boolean))];
        for (const so of (soData ?? [])) dueDateMap[so.id] = so.expected_delivery_date ?? null;
        if (custIds.length > 0) {
          const { data: custData } = await supabase
            .from('DirectoryCustomers')
            .select('id, customer_name')
            .in('id', custIds);
          const custLookup: Record<string, string> = {};
          for (const c of (custData ?? [])) custLookup[c.id] = c.customer_name;
          for (const so of (soData ?? [])) {
            if (so.customer_id) customerMap[so.id] = custLookup[so.customer_id] ?? 'N/A';
          }
        }
      }

      const taskIds = taskData.map((t: any) => t.id);
      const { data: lineData, error: lErr } = await supabase
        .from('WorkOrderTaskLines')
        .select('id, task_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm, completed')
        .in('task_id', taskIds)
        .order('created_at');

      if (lErr) throw new Error(lErr.message);

      const linesByTask: Record<string, TaskLine[]> = {};
      for (const l of (lineData ?? [])) {
        if (!linesByTask[l.task_id]) linesByTask[l.task_id] = [];
        linesByTask[l.task_id].push(l);
      }

      const result: TaskWithMO[] = taskData.map((t: any) => {
        const mo = moMap[t.manufacturing_order_id];
        const soId = mo?.sales_order_id;
        return {
          id: t.id,
          manufacturing_order_id: t.manufacturing_order_id,
          sequence: t.sequence,
          status: t.status,
          assigned_to: t.assigned_to,
          started_at: t.started_at,
          completed_at: t.completed_at,
          mo_number: mo?.manufacturing_order_no ?? '—',
          customer_name: soId ? (customerMap[soId] ?? 'N/A') : 'N/A',
          product_name: mo?.product_name ?? '—',
          due_date: soId ? (dueDateMap[soId] ?? null) : null,
          lines: linesByTask[t.id] ?? [],
        };
      });

      setTasks(result);
    } catch {
      setTasks([]);
    } finally {
      setLoadingTasks(false);
    }
  }, [selectedCenter, activeOrganizationId]);

  useEffect(() => { fetchTasks(); }, [fetchTasks]);

  const toggleLine = async (lineId: string, completed: boolean) => {
    await supabase
      .from('WorkOrderTaskLines')
      .update({ completed, completed_at: completed ? new Date().toISOString() : null })
      .eq('id', lineId);
    await fetchTasks();
  };

  const startTask = async (taskId: string) => {
    await supabase
      .from('WorkOrderTasks')
      .update({ status: 'in_progress', started_at: new Date().toISOString(), updated_at: new Date().toISOString() })
      .eq('id', taskId);
    await fetchTasks();
  };

  const completeTask = async (taskId: string) => {
    await supabase
      .from('WorkOrderTasks')
      .update({ status: 'completed', completed_at: new Date().toISOString(), updated_at: new Date().toISOString() })
      .eq('id', taskId);
    await fetchTasks();
  };

  const currentCenter = centers.find((c) => c.id === selectedCenter);
  const pendingCount = tasks.filter((t) => t.status === 'pending').length;
  const inProgressCount = tasks.filter((t) => t.status === 'in_progress').length;

  if (centersLoading) {
    return (
      <div className="flex items-center justify-center py-20">
        <Loader2 className="h-6 w-6 animate-spin text-gray-400" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Factory className="h-5 w-5 text-gray-700" />
          <h1 className="text-lg font-semibold text-gray-900">Workstations</h1>
        </div>
      </div>

      <div className="flex gap-2 flex-wrap">
        {centers.map((wc) => (
          <button
            key={wc.id}
            type="button"
            onClick={() => {
              setSelectedCenter(wc.id);
              router.navigate(`/manufacturing/workstations/${wc.id}`, false);
            }}
            className={`px-4 py-2 rounded-lg text-sm font-medium border transition-colors ${
              selectedCenter === wc.id
                ? 'bg-primary text-white border-primary'
                : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
            }`}
          >
            {wc.name}
          </button>
        ))}
      </div>

      {currentCenter && (
        <div className="flex items-center gap-4 text-sm text-gray-500">
          <span className="font-medium text-gray-900">{currentCenter.name}</span>
          <span>{pendingCount} pending</span>
          <span>{inProgressCount} in progress</span>
          <span>{tasks.length} total</span>
        </div>
      )}

      {loadingTasks ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-6 w-6 animate-spin text-gray-400" />
        </div>
      ) : tasks.length === 0 ? (
        <div className="rounded-lg border border-gray-200 bg-white p-8 text-center">
          <CheckCircle2 className="h-10 w-10 text-green-400 mx-auto mb-3" />
          <p className="text-sm text-gray-500">No pending tasks at this station.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {tasks.map((task) => {
            const completedCount = task.lines.filter((l) => l.completed).length;
            const totalCount = task.lines.length;
            const isExpanded = expandedTask === task.id;

            return (
              <div key={task.id} className="border border-gray-200 rounded-lg bg-white overflow-hidden">
                <div className="flex items-center justify-between px-4 py-3 bg-gray-50 border-b border-gray-100">
                  <div className="flex items-center gap-3">
                    <button type="button" onClick={() => setExpandedTask(isExpanded ? null : task.id)} className="text-gray-500">
                      {isExpanded ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
                    </button>
                    <div>
                      <button
                        type="button"
                        onClick={() => router.navigate(`/manufacturing/manufacturing-orders/${task.manufacturing_order_id}`)}
                        className="font-semibold text-sm text-primary hover:underline"
                      >
                        {task.mo_number}
                      </button>
                      <span className="ml-2 text-xs text-gray-500">{task.customer_name}</span>
                    </div>
                    <StatusBadge status={task.status} type="manufacturing" size="sm" />
                  </div>

                  <div className="flex items-center gap-3">
                    <span className="text-xs text-gray-500">{task.product_name}</span>
                    {task.due_date && <span className="text-xs text-gray-400">{task.due_date}</span>}
                    <span className="text-xs text-gray-500">{completedCount}/{totalCount}</span>

                    {task.status === 'pending' && (
                      <button type="button" onClick={() => startTask(task.id)} className="inline-flex items-center gap-1 text-xs px-2 py-1 rounded bg-blue-600 text-white hover:bg-blue-700">
                        <Play className="h-3 w-3" /> Start
                      </button>
                    )}
                    {task.status === 'in_progress' && completedCount === totalCount && totalCount > 0 && (
                      <button type="button" onClick={() => completeTask(task.id)} className="inline-flex items-center gap-1 text-xs px-2 py-1 rounded bg-green-600 text-white hover:bg-green-700">
                        <CheckCircle2 className="h-3 w-3" /> Complete
                      </button>
                    )}
                  </div>
                </div>

                {isExpanded && (
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="text-xs text-gray-500 border-b border-gray-100">
                        <th className="text-left px-4 py-2 w-8"></th>
                        <th className="text-left px-4 py-2">SKU</th>
                        <th className="text-left px-4 py-2">Description</th>
                        <th className="text-left px-4 py-2">Role</th>
                        <th className="text-right px-4 py-2">Qty</th>
                        <th className="text-left px-4 py-2">UOM</th>
                        <th className="text-right px-4 py-2">Length X</th>
                        <th className="text-right px-4 py-2">Length Y</th>
                      </tr>
                    </thead>
                    <tbody>
                      {task.lines.map((line) => (
                        <tr key={line.id} className={`border-t border-gray-50 ${line.completed ? 'bg-green-50/30' : ''}`}>
                          <td className="px-4 py-2">
                            <input
                              type="checkbox"
                              checked={line.completed}
                              onChange={(e) => toggleLine(line.id, e.target.checked)}
                              className="rounded border-gray-300"
                            />
                          </td>
                          <td className={`px-4 py-2 font-mono ${line.completed ? 'line-through text-gray-400' : 'text-gray-800'}`}>{line.sku ?? '—'}</td>
                          <td className={`px-4 py-2 ${line.completed ? 'line-through text-gray-400' : 'text-gray-700'}`}>{line.item_name ?? '—'}</td>
                          <td className="px-4 py-2">{line.component_role && <span className="text-xs bg-gray-100 text-gray-600 px-1.5 py-0.5 rounded">{line.component_role}</span>}</td>
                          <td className="px-4 py-2 text-right text-gray-700">{line.qty}</td>
                          <td className="px-4 py-2 text-gray-500">{line.uom}</td>
                          <td className="px-4 py-2 text-right text-gray-600">{line.cut_length_mm != null ? Math.round(Number(line.cut_length_mm)) : '—'}</td>
                          <td className="px-4 py-2 text-right text-gray-600">{line.cut_width_mm != null ? Math.round(Number(line.cut_width_mm)) : '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
