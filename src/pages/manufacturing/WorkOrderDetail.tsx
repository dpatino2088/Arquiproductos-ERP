import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../../lib/supabase/client';
import { formatDate } from '../../lib/utils';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useFilteredMfgSubmodules } from './manufacturingSubmodules';
import { useWorkOrderTasks, type WorkOrderTask } from '../../hooks/useWorkOrderTasks';
import StatusBadge from '../../components/shared/StatusBadge';
import AssemblyDetail from '../../components/manufacturing/assembly/AssemblyDetail';
import { generateWorkOrderPDF } from '../../lib/pdf/workOrderPdf';
import { generatePartLabelsPDF, type PartLabel } from '../../lib/pdf/partLabelPdf';

import {
  ArrowLeft, Play, CheckCircle2, Loader2, Printer, Tag, Package, User, Calendar,
  ClipboardList, ExternalLink, ChevronDown, ChevronRight, Scissors, Box, AlertTriangle,
} from 'lucide-react';

interface MOInfo {
  mo_number: string;
  product_name: string;
  customer_name: string;
  dealer_name: string;
  so_number: string;
  due_date: string | null;
}

interface WorkOrderDetailProps {
  moId: string;
}

interface LineGroup {
  lineIndex: number;
  solId: string | null;
  description: string;
  tasks: WorkOrderTask[];
  totalComponents: number;
  completedComponents: number;
  globalStatus: 'pending' | 'in_progress' | 'completed';
}

function deriveStatus(tasks: WorkOrderTask[]): 'pending' | 'in_progress' | 'completed' {
  if (tasks.length === 0) return 'pending';
  if (tasks.every(t => t.status === 'completed')) return 'completed';
  if (tasks.some(t => t.status === 'in_progress' || t.status === 'completed')) return 'in_progress';
  return 'pending';
}

/* ─── Station Card (unchanged core logic) ─── */
function StationCard({ task, onToggleLine, onStatusChange, moMeta, siblingTasks }: {
  task: WorkOrderTask;
  onToggleLine: (lineId: string, completed: boolean) => void;
  onStatusChange: (taskId: string, status: 'pending' | 'in_progress' | 'completed') => void;
  moMeta: MOInfo;
  siblingTasks?: WorkOrderTask[];
}) {
  const [expanded, setExpanded] = useState(false);
  const completedCount = task.lines.filter(l => l.completed).length;
  const totalCount = task.lines.length;
  const pct = totalCount > 0 ? Math.round((completedCount / totalCount) * 100) : 0;

  const stationName = task.work_center?.name ?? 'Station';
  const stationCode = task.work_center?.code ?? '';

  const isAssembly = stationCode === 'ASSEMBLY';
  const upstreamTasks = isAssembly && siblingTasks ? siblingTasks.filter(t => t.work_center?.code !== 'ASSEMBLY') : [];
  const allUpstreamReady = upstreamTasks.length === 0 || upstreamTasks.every(t => t.status === 'completed');

  const depIds = task.depends_on_task_ids ?? [];
  const depsBlocked = depIds.length > 0 && siblingTasks ? !depIds.every(depId => siblingTasks.find(s => s.id === depId)?.status === 'completed') : false;
  // Start gating is dependency-driven; calendar remains informative.
  const canStart = !depsBlocked && (isAssembly ? allUpstreamReady : true);

  const formatTaskDateTime = (value: string | null) => {
    if (!value) return '—';
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return '—';
    return d.toLocaleString([], { month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' });
  };

  return (
    <div className="border border-gray-200 rounded-lg bg-white overflow-hidden">
      <div className="flex flex-col gap-2 px-4 py-3 bg-gradient-to-r from-gray-50 to-white border-b border-gray-200">
        <div className="flex items-center justify-between gap-3">
          <div className="flex items-center gap-2 min-w-0">
            <button type="button" onClick={() => setExpanded(!expanded)} className="text-gray-500 hover:text-gray-700">
              {expanded ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
            </button>
            <span className="font-semibold text-sm text-gray-900">{stationName}</span>
            <span className="text-xs text-gray-400 font-mono">{stationCode}</span>
            <StatusBadge status={task.status} type="workOrder" size="sm" />
          </div>

          <div className="flex items-center gap-3 shrink-0">
            <div className="text-right">
              <div className="text-xs text-gray-500">{completedCount}/{totalCount}</div>
              <div className="w-20 h-1.5 bg-gray-200 rounded-full overflow-hidden mt-0.5">
                <div className={`h-full rounded-full transition-all ${pct === 100 ? 'bg-green-500' : pct > 0 ? 'bg-blue-500' : 'bg-gray-300'}`} style={{ width: `${pct}%` }} />
              </div>
            </div>
            {task.status === 'pending' && canStart && (
              <button type="button" onClick={() => onStatusChange(task.id, 'in_progress')} className="inline-flex items-center gap-1 text-xs px-2.5 py-1.5 rounded bg-blue-600 text-white hover:bg-blue-700"><Play className="h-3 w-3" /> Start</button>
            )}
            {task.status === 'pending' && !canStart && (
              <span className="inline-flex items-center gap-1 text-[10px] px-2 py-1 rounded bg-gray-100 text-gray-400 border border-gray-200" title="Blocked"><AlertTriangle className="h-3 w-3" /> Blocked</span>
            )}
            {task.status === 'in_progress' && completedCount === totalCount && totalCount > 0 && canStart && (
              <button type="button" onClick={() => onStatusChange(task.id, 'completed')} className="inline-flex items-center gap-1 text-xs px-2.5 py-1.5 rounded bg-green-600 text-white hover:bg-green-700"><CheckCircle2 className="h-3 w-3" /> Complete</button>
            )}
          </div>
        </div>

        <div className="flex items-center justify-between gap-3">
          <div className="flex items-center gap-2 flex-wrap">
            <span className="inline-flex items-center gap-1 text-[11px] px-2 py-1 rounded-md bg-white text-gray-700 border border-gray-200">
              <Calendar className="w-3 h-3 text-gray-400" /> Start: {formatTaskDateTime(task.planned_start_at ?? task.started_at)}
            </span>
            <span className="inline-flex items-center gap-1 text-[11px] px-2 py-1 rounded-md bg-white text-gray-700 border border-gray-200">
              <Calendar className="w-3 h-3 text-gray-400" /> End: {formatTaskDateTime(task.planned_end_at ?? task.completed_at)}
            </span>
            {task.assigned_to && (
              <span className="inline-flex items-center gap-1 text-[11px] px-2 py-1 rounded-md bg-blue-50 text-blue-700 border border-blue-100"><User className="w-3 h-3" /> {task.assigned_to}</span>
            )}
            {!task.assigned_to_user_id && (
              <span className="inline-flex items-center gap-1 text-[11px] px-2 py-1 rounded-md bg-amber-50 text-amber-700 border border-amber-100"><AlertTriangle className="w-3 h-3" /> Operator Required</span>
            )}
          </div>
          <div className="flex items-center gap-1.5 shrink-0">
            <button type="button" onClick={() => {
              const pdf = generateWorkOrderPDF({ moNumber: moMeta.mo_number, stationName, stationCode, customerName: moMeta.customer_name, productName: moMeta.product_name, salesOrderNo: moMeta.so_number, date: formatDate(new Date()),
                lines: task.lines.map(l => ({ sku: l.sku ?? '', description: l.item_name ?? '', role: l.component_role ?? '', qty: l.qty, uom: l.uom, cutLength: l.cut_length_mm != null ? Number(l.cut_length_mm) : null, cutWidth: l.cut_width_mm != null ? Number(l.cut_width_mm) : null })) });
              pdf.save(`WO-${moMeta.mo_number}-${stationCode}.pdf`);
            }} className="p-1.5 rounded hover:bg-gray-200 text-gray-500" title="Print work sheet"><Printer className="h-3.5 w-3.5" /></button>
            <button type="button" onClick={async () => {
              const labels: PartLabel[] = task.lines.map(l => ({ moNumber: moMeta.mo_number, soNumber: moMeta.so_number, customerName: moMeta.customer_name, date: formatDate(new Date()), sku: l.sku ?? '', itemName: l.item_name ?? '',
                cutDimension: l.cut_length_mm != null ? `X ${Math.round(Number(l.cut_length_mm))} mm` : (l.cut_width_mm != null ? `Y ${Math.round(Number(l.cut_width_mm))} mm` : '—'), qty: l.qty, lineId: l.id }));
              const pdf = await generatePartLabelsPDF(labels);
              pdf.save(`Labels-${moMeta.mo_number}-${stationCode}.pdf`);
            }} className="p-1.5 rounded hover:bg-gray-200 text-gray-500" title="Print labels"><Tag className="h-3.5 w-3.5" /></button>
            {(stationCode === 'CUT-PROFILE' || stationCode === 'CUT-ROLL') && (
              <button
                type="button"
                onClick={() => {
                  const optimizeMode = stationCode === 'CUT-ROLL' ? 'fabric' : 'profiles';
                  router.navigate(`/manufacturing/cut-optimization?mode=${optimizeMode}`);
                }}
                className="inline-flex items-center gap-1 text-xs px-2 py-1 rounded bg-amber-50 text-amber-700 border border-amber-200 hover:bg-amber-100"
              >
                <Scissors className="h-3 w-3" /> Optimize
              </button>
            )}
          </div>
        </div>
      </div>

      {expanded && isAssembly && upstreamTasks.length > 0 && (
        <div className="px-4 py-2.5 border-b border-gray-100 bg-white flex flex-wrap items-center gap-3">
          <span className="text-xs font-medium text-gray-500 uppercase tracking-wider">Readiness:</span>
          {upstreamTasks.map(ut => {
            const utName = ut.work_center?.name ?? ut.work_center?.code ?? 'Task';
            const isReady = ut.status === 'completed';
            const isActive = ut.status === 'in_progress';
            return (
              <span key={ut.id} className={`inline-flex items-center gap-1.5 text-xs font-medium px-2.5 py-1 rounded-full ${isReady ? 'bg-green-100 text-green-700' : isActive ? 'bg-blue-100 text-blue-700' : 'bg-gray-100 text-gray-500'}`}>
                {isReady ? <CheckCircle2 className="w-3 h-3" /> : isActive ? <Play className="w-3 h-3" /> : <Package className="w-3 h-3" />}{utName}
              </span>
            );
          })}
          {allUpstreamReady && <span className="inline-flex items-center gap-1 text-xs font-semibold text-green-700 bg-green-50 border border-green-200 px-2.5 py-1 rounded-full"><CheckCircle2 className="w-3.5 h-3.5" /> All Ready</span>}
        </div>
      )}

      {expanded && isAssembly && (
        <div className="p-3">
          <AssemblyDetail manufacturingOrderId={task.manufacturing_order_id} moNumber={moMeta.mo_number} productName={moMeta.product_name}
            lines={task.lines.map(l => ({ id: l.id, sku: l.sku, item_name: l.item_name, component_role: l.component_role, qty: l.qty, uom: l.uom, cut_length_mm: l.cut_length_mm != null ? Number(l.cut_length_mm) : null, cut_width_mm: l.cut_width_mm != null ? Number(l.cut_width_mm) : null, completed: l.completed, bom_instance_line_id: l.bom_instance_line_id }))}
            onToggleLine={onToggleLine}
            siblingTasks={siblingTasks?.map(t => ({ code: t.work_center?.code ?? '', status: t.status })).filter(t => t.code !== 'ASSEMBLY')} />
        </div>
      )}

      {expanded && !isAssembly && (
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100 text-gray-500 text-xs">
              <th className="text-center px-2 py-2 w-6"></th>
              <th className="text-left px-4 py-2 w-8"></th>
              <th className="text-left px-4 py-2">SKU</th>
              <th className="text-left px-4 py-2">Description</th>
              <th className="text-left px-4 py-2">Role</th>
              <th className="text-right px-4 py-2">Qty</th>
              <th className="text-left px-4 py-2">UOM</th>
              <th className="text-right px-4 py-2">Length X (mm)</th>
              <th className="text-right px-4 py-2">Length Y (mm)</th>
            </tr>
          </thead>
          <tbody>
            {task.lines.map(line => {
              const dotColor = line.completed
                ? 'bg-green-500'
                : task.status === 'in_progress'
                  ? 'bg-amber-400'
                  : 'bg-gray-300';
              const dotTitle = line.completed
                ? 'Completed'
                : task.status === 'in_progress'
                  ? 'In progress'
                  : 'Pending';
              return (
                <tr key={line.id} className={`border-t border-gray-50 ${line.completed ? 'bg-green-50/30' : 'hover:bg-gray-50/50'}`}>
                  <td className="px-2 py-2 text-center"><span className={`inline-block w-2.5 h-2.5 rounded-full ${dotColor}`} title={dotTitle} /></td>
                  <td className="px-4 py-2"><input type="checkbox" checked={line.completed} onChange={e => onToggleLine(line.id, e.target.checked)} className="rounded border-gray-300" disabled={task.status !== 'in_progress'} /></td>
                  <td className={`px-4 py-2 font-mono ${line.completed ? 'line-through text-gray-400' : 'text-gray-800'}`}>{line.sku || '—'}</td>
                  <td className={`px-4 py-2 ${line.completed ? 'line-through text-gray-400' : 'text-gray-700'}`}>
                    {line.item_name || '—'}
                    {(line.component_role === 'fabric' || line.component_role === 'tape') && (line.cut_length_mm != null || line.cut_width_mm != null) && (
                      <div className="text-[11px] text-blue-600 font-medium mt-0.5">CUT: {line.cut_length_mm != null ? `${Math.round(Number(line.cut_length_mm))} mm` : ''}{line.cut_length_mm != null && line.cut_width_mm != null ? ' × ' : ''}{line.cut_width_mm != null ? `${Math.round(Number(line.cut_width_mm))} mm` : ''}</div>
                    )}
                  </td>
                  <td className="px-4 py-2">{line.component_role && <span className={`text-xs px-1.5 py-0.5 rounded ${line.component_role === 'fabric' ? 'bg-blue-50 text-blue-700' : line.component_role === 'tape' ? 'bg-purple-50 text-purple-700' : 'bg-gray-100 text-gray-600'}`}>{line.component_role}</span>}</td>
                  <td className="px-4 py-2 text-right text-gray-700">{Number(line.qty).toFixed(line.uom === 'ea' ? 0 : 3)}</td>
                  <td className="px-4 py-2 text-gray-500">{line.uom}</td>
                  <td className="px-4 py-2 text-right text-gray-600">{line.cut_length_mm != null ? Math.round(Number(line.cut_length_mm)) : '—'}</td>
                  <td className="px-4 py-2 text-right text-gray-600">{line.cut_width_mm != null ? Math.round(Number(line.cut_width_mm)) : '—'}</td>
                </tr>
              );
            })}
            {task.lines.length === 0 && <tr><td colSpan={9} className="px-4 py-6 text-center text-gray-400 text-sm">No lines in this station</td></tr>}
          </tbody>
        </table>
      )}
    </div>
  );
}

/* ─── Line Accordion ─── */
function LineAccordion({ group, allTasks, onToggleLine, onStatusChange, moMeta }: {
  group: LineGroup;
  allTasks: WorkOrderTask[];
  onToggleLine: (lineId: string, completed: boolean) => void;
  onStatusChange: (taskId: string, status: 'pending' | 'in_progress' | 'completed') => void;
  moMeta: MOInfo;
}) {
  const [expanded, setExpanded] = useState(false);
  const pct = group.totalComponents > 0 ? Math.round((group.completedComponents / group.totalComponents) * 100) : 0;

  return (
    <div className="border border-gray-200 rounded-lg overflow-hidden bg-white">
      <button
        type="button"
        onClick={() => setExpanded(!expanded)}
        className="w-full flex items-center justify-between gap-3 px-5 py-4 bg-gray-50 hover:bg-gray-100 transition-colors text-left"
      >
        <div className="flex items-center gap-3 min-w-0">
          {expanded ? <ChevronDown className="h-4 w-4 text-gray-500 shrink-0" /> : <ChevronRight className="h-4 w-4 text-gray-500 shrink-0" />}
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <span className="text-sm font-semibold text-gray-900">Line {group.lineIndex}</span>
              <StatusBadge status={group.globalStatus} type="workOrder" size="sm" />
            </div>
            <p className="text-xs text-gray-500 mt-0.5 truncate">{group.description}</p>
          </div>
        </div>
        <div className="flex items-center gap-4 shrink-0">
          <div className="flex gap-2">
            {group.tasks.map(t => {
              const code = t.work_center?.code ?? '—';
              const chipColor = t.status === 'completed' ? 'bg-green-100 text-green-700' : t.status === 'in_progress' ? 'bg-blue-100 text-blue-700' : 'bg-gray-100 text-gray-500';
              const completedInTask = t.lines.filter(l => l.completed).length;
              const totalInTask = t.lines.length;
              return (
                <div key={t.id} className="flex flex-col items-center gap-0.5">
                  <span className={`inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium ${chipColor}`}>{code}</span>
                  {totalInTask > 0 && (
                    <div className="flex gap-px">
                      {t.lines.map(l => (
                        <span key={l.id} className={`w-1.5 h-1.5 rounded-full ${l.completed ? 'bg-green-500' : t.status === 'in_progress' ? 'bg-amber-400' : 'bg-gray-300'}`} />
                      ))}
                    </div>
                  )}
                  {totalInTask > 0 && (
                    <span className="text-[9px] text-gray-400 tabular-nums">{completedInTask}/{totalInTask}</span>
                  )}
                </div>
              );
            })}
          </div>
          <div className="flex items-center gap-2">
            <div className="w-16 h-1.5 bg-gray-200 rounded-full overflow-hidden">
              <div className={`h-full rounded-full transition-all ${pct === 100 ? 'bg-green-500' : pct > 0 ? 'bg-blue-500' : 'bg-gray-300'}`} style={{ width: `${pct}%` }} />
            </div>
            <span className="text-xs text-gray-500 tabular-nums">{group.completedComponents}/{group.totalComponents}</span>
          </div>
        </div>
      </button>

      {expanded && (
        <div className="p-4 space-y-3">
          {group.tasks.map(task => (
            <StationCard key={task.id} task={task} onToggleLine={onToggleLine} onStatusChange={onStatusChange} moMeta={moMeta} siblingTasks={group.tasks} />
          ))}
        </div>
      )}
    </div>
  );
}

/* ─── Main Component ─── */
export default function WorkOrderDetail({ moId }: WorkOrderDetailProps) {
  const filteredSubmodules = useFilteredMfgSubmodules();
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const { tasks, loading: tasksLoading, toggleLineCompleted, updateTaskStatus } = useWorkOrderTasks(moId);
  const [moInfo, setMoInfo] = useState<MOInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [solDescriptions, setSolDescriptions] = useState<Record<string, string>>({});

  useEffect(() => {
    registerSubmodules('Manufacturing', filteredSubmodules);
    return () => { const path = window.location.pathname; if (!path.startsWith('/manufacturing')) clearSubmoduleNav(); };
  }, [registerSubmodules, clearSubmoduleNav, filteredSubmodules]);

  const fetchMOInfo = useCallback(async () => {
    setLoading(true);
    try {
      const { data: mo } = await supabase.from('ManufacturingOrders').select('manufacturing_order_no, product_name, sales_order_id').eq('id', moId).single();
      if (!mo) { setMoInfo(null); setLoading(false); return; }

      let customerName = '—';
      let dealerName = '—';
      let soNumber = '—';
      let dueDate: string | null = null;

      if (mo.sales_order_id) {
        const { data: so } = await supabase.from('SalesOrders').select('sales_order_no, customer_id, dealer_id, expected_delivery_date').eq('id', mo.sales_order_id).single();
        if (so) {
          soNumber = so.sales_order_no ?? '—';
          dueDate = so.expected_delivery_date ?? null;
          if (so.customer_id) {
            const { data: cust } = await supabase.from('DirectoryCustomers').select('customer_name').eq('id', so.customer_id).single();
            customerName = cust?.customer_name ?? '—';
          }
          if (so.dealer_id) {
            const { data: dealer } = await supabase.from('Dealers').select('dealer_name').eq('id', so.dealer_id).single();
            dealerName = dealer?.dealer_name ?? '—';
          }
        }
      }

      setMoInfo({ mo_number: mo.manufacturing_order_no ?? '—', product_name: mo.product_name ?? '—', customer_name: customerName, dealer_name: dealerName, so_number: soNumber, due_date: dueDate });
    } catch { setMoInfo(null); } finally { setLoading(false); }
  }, [moId]);

  useEffect(() => { fetchMOInfo(); }, [fetchMOInfo]);

  // Fetch SOL descriptions for line labels
  useEffect(() => {
    const solIds = [...new Set(tasks.map(t => t.sales_order_line_id).filter(Boolean))] as string[];
    if (solIds.length === 0) return;
    supabase.from('SaleOrderLines').select('id, description, variant_name, product_type').in('id', solIds).then((res: { data: Array<{ id: string; description: string | null; variant_name: string | null; product_type: string | null }> | null }) => {
      const data = res.data ?? [];
      const map: Record<string, string> = {};
      for (const sol of data) map[sol.id] = sol.description || sol.variant_name || sol.product_type || 'Line';
      setSolDescriptions(map);
    });
  }, [tasks]);

  // Group tasks by sales_order_line_id
  const lineGroups: LineGroup[] = useMemo(() => {
    const grouped: Record<string, WorkOrderTask[]> = {};
    const lineOrder: string[] = [];
    for (const t of tasks) {
      const key = t.sales_order_line_id ?? '__no_line__';
      if (!grouped[key]) { grouped[key] = []; lineOrder.push(key); }
      grouped[key].push(t);
    }

    return lineOrder.map((key, idx) => {
      const lineTasks = grouped[key];
      const totalComponents = lineTasks.reduce((sum, t) => sum + t.lines.length, 0);
      const completedComponents = lineTasks.reduce((sum, t) => sum + t.lines.filter(l => l.completed).length, 0);
      return {
        lineIndex: idx + 1,
        solId: key === '__no_line__' ? null : key,
        description: key === '__no_line__' ? (moInfo?.product_name ?? '—') : (solDescriptions[key] ?? 'Line'),
        tasks: lineTasks.sort((a, b) => (a.work_center?.sequence ?? 0) - (b.work_center?.sequence ?? 0)),
        totalComponents,
        completedComponents,
        globalStatus: deriveStatus(lineTasks),
      };
    });
  }, [tasks, solDescriptions, moInfo?.product_name]);

  if (loading || tasksLoading) {
    return <div className="flex items-center justify-center py-20"><Loader2 className="h-6 w-6 animate-spin text-gray-400" /></div>;
  }

  if (!moInfo) {
    return (
      <div className="py-6 px-6">
        <button onClick={() => router.navigate(`/manufacturing/manufacturing-orders/${moId}`)} className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700 mb-4"><ArrowLeft className="w-4 h-4" /> Back to MO</button>
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center"><p className="text-gray-500">Work order not found</p></div>
      </div>
    );
  }

  const allLines = tasks.flatMap(t => t.lines);
  const unassignedCount = tasks.filter(t => !t.assigned_to_user_id).length;
  const totalLines = allLines.length;
  const completedLines = allLines.filter(l => l.completed).length;
  const globalPct = totalLines > 0 ? Math.round((completedLines / totalLines) * 100) : 0;
  const woNumber = moInfo.mo_number.replace(/^MO-/, 'WO-');

  const globalStatus = (() => {
    if (tasks.length === 0) return 'pending';
    if (tasks.every(t => t.status === 'completed')) return 'completed';
    if (tasks.some(t => t.status === 'in_progress' || t.status === 'completed')) return 'in_progress';
    return 'pending';
  })();

  return (
    <div className="py-6 px-6">
      <button onClick={() => router.navigate('/manufacturing/work-orders')} className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700 mb-4">
        <ArrowLeft className="w-4 h-4" /> Back to Work Orders
      </button>

      {/* Header */}
      <div className="bg-white border border-gray-200 rounded-lg p-6 mb-6">
        <div className="flex items-start justify-between">
          <div>
            <div className="flex items-center gap-3 mb-1">
              <h1 className="text-xl font-semibold text-gray-900">{woNumber}</h1>
              <StatusBadge status={globalStatus} type="workOrder" size="md" />
            </div>
            <p className="text-sm text-gray-500">{moInfo.product_name}</p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-x-5 gap-y-1 mt-4 text-sm text-gray-600">
          <div className="flex items-center gap-1.5">
            <ClipboardList className="w-3.5 h-3.5 text-gray-400" />
            <span className="text-gray-400">MO</span>
            <button onClick={() => router.navigate(`/manufacturing/manufacturing-orders/${moId}`)} className="font-medium text-primary hover:underline">
              {moInfo.mo_number} <ExternalLink className="w-3 h-3 inline" />
            </button>
          </div>
          <span className="text-gray-300">|</span>
          <div className="flex items-center gap-1.5">
            <Package className="w-3.5 h-3.5 text-gray-400" />
            <span className="text-gray-400">SO</span>
            <span className="font-medium text-gray-900">{moInfo.so_number}</span>
          </div>
          <span className="text-gray-300">|</span>
          <div className="flex items-center gap-1.5">
            <User className="w-3.5 h-3.5 text-gray-400" />
            <span className="text-gray-400">Customer</span>
            <span className="font-medium text-gray-900">{moInfo.customer_name}</span>
          </div>
          <span className="text-gray-300">|</span>
          <div className="flex items-center gap-1.5">
            <Box className="w-3.5 h-3.5 text-gray-400" />
            <span className="text-gray-400">Dealer</span>
            <span className="font-medium text-gray-900">{moInfo.dealer_name}</span>
          </div>
          <span className="text-gray-300">|</span>
          <div className="flex items-center gap-1.5">
            <Calendar className="w-3.5 h-3.5 text-gray-400" />
            <span className="text-gray-400">Due</span>
            <span className="font-medium text-gray-900">{formatDate(moInfo.due_date)}</span>
          </div>
          <span className="text-gray-300">|</span>
          <div className="flex items-center gap-1.5">
            <span className="text-gray-400">Lines</span>
            <span className="font-semibold text-gray-900">{lineGroups.length}</span>
          </div>
        </div>

        {/* Global Progress */}
        <div className="mt-5">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs text-gray-500">Global Progress</span>
            <span className="text-xs font-medium text-gray-700">{completedLines}/{totalLines} components · {globalPct}%</span>
          </div>
          <div className="w-full h-2 bg-gray-200 rounded-full overflow-hidden">
            <div className={`h-full rounded-full transition-all ${globalPct === 100 ? 'bg-green-500' : globalPct > 0 ? 'bg-blue-500' : 'bg-gray-300'}`} style={{ width: `${globalPct}%` }} />
          </div>
        </div>

        {unassignedCount > 0 && (
          <div className="mt-4 flex items-center gap-2 px-3 py-2 rounded-md bg-amber-50 border border-amber-100">
            <AlertTriangle className="w-3.5 h-3.5 text-amber-600" />
            <span className="text-xs text-amber-800">{unassignedCount} station(s) without operator. Assign from MO &gt; Work Orders tab.</span>
          </div>
        )}
      </div>

      {/* Lines grouped by SOL */}
      <div className="space-y-4">
        {lineGroups.map(group => (
          <LineAccordion key={group.solId ?? '__no_line__'} group={group} allTasks={tasks} onToggleLine={toggleLineCompleted} onStatusChange={updateTaskStatus} moMeta={moInfo} />
        ))}
        {lineGroups.length === 0 && (
          <div className="bg-white border border-gray-200 rounded-lg p-8 text-center">
            <p className="text-sm text-gray-500">No work order tasks found for this Manufacturing Order.</p>
          </div>
        )}
      </div>
    </div>
  );
}
