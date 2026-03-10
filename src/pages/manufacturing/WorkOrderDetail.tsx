import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../../lib/supabase/client';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { MANUFACTURING_SUBMODULES } from './manufacturingSubmodules';
import { useWorkOrderTasks, type WorkOrderTask } from '../../hooks/useWorkOrderTasks';
import StatusBadge from '../../components/shared/StatusBadge';
import { generateWorkOrderPDF } from '../../lib/pdf/workOrderPdf';
import { generatePartLabelsPDF, type PartLabel } from '../../lib/pdf/partLabelPdf';
import {
  ArrowLeft,
  Play,
  CheckCircle2,
  Loader2,
  Printer,
  Tag,
  Package,
  User,
  Calendar,
  ClipboardList,
  ExternalLink,
  ChevronDown,
  ChevronRight,
} from 'lucide-react';

interface MOInfo {
  mo_number: string;
  product_name: string;
  customer_name: string;
  so_number: string;
  due_date: string | null;
}

interface WorkOrderDetailProps {
  moId: string;
}

function StationCard({ task, onToggleLine, onStatusChange, moMeta }: {
  task: WorkOrderTask;
  onToggleLine: (lineId: string, completed: boolean) => void;
  onStatusChange: (taskId: string, status: 'pending' | 'in_progress' | 'completed') => void;
  moMeta: MOInfo;
}) {
  const [expanded, setExpanded] = useState(true);
  const completedCount = task.lines.filter(l => l.completed).length;
  const totalCount = task.lines.length;
  const pct = totalCount > 0 ? Math.round((completedCount / totalCount) * 100) : 0;

  const stationName = task.work_center?.name ?? 'Station';
  const stationCode = task.work_center?.code ?? '';

  return (
    <div className="border border-gray-200 rounded-lg bg-white overflow-hidden">
      <div className="flex items-center justify-between px-4 py-3 bg-gray-50 border-b border-gray-200">
        <div className="flex items-center gap-3">
          <button type="button" onClick={() => setExpanded(!expanded)} className="text-gray-500 hover:text-gray-700">
            {expanded ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
          </button>
          <div>
            <span className="font-semibold text-sm text-gray-900">{stationName}</span>
            <span className="ml-2 text-xs text-gray-400 font-mono">{stationCode}</span>
          </div>
          <StatusBadge status={task.status} type="workOrder" size="sm" />
        </div>

        <div className="flex items-center gap-3">
          <span className="text-xs text-gray-500">{completedCount}/{totalCount} lines</span>
          <div className="w-20 h-1.5 bg-gray-200 rounded-full overflow-hidden">
            <div
              className={`h-full rounded-full transition-all ${pct === 100 ? 'bg-green-500' : pct > 0 ? 'bg-blue-500' : 'bg-gray-300'}`}
              style={{ width: `${pct}%` }}
            />
          </div>

          {task.status === 'pending' && (
            <button type="button" onClick={() => onStatusChange(task.id, 'in_progress')} className="inline-flex items-center gap-1 text-xs px-2 py-1 rounded bg-blue-600 text-white hover:bg-blue-700">
              <Play className="h-3 w-3" /> Start
            </button>
          )}
          {task.status === 'in_progress' && completedCount === totalCount && totalCount > 0 && (
            <button type="button" onClick={() => onStatusChange(task.id, 'completed')} className="inline-flex items-center gap-1 text-xs px-2 py-1 rounded bg-green-600 text-white hover:bg-green-700">
              <CheckCircle2 className="h-3 w-3" /> Complete
            </button>
          )}

          <button type="button" onClick={() => {
            const pdf = generateWorkOrderPDF({
              moNumber: moMeta.mo_number,
              stationName,
              stationCode,
              customerName: moMeta.customer_name,
              productName: moMeta.product_name,
              salesOrderNo: moMeta.so_number,
              date: new Date().toLocaleDateString(),
              lines: task.lines.map(l => ({ sku: l.sku ?? '', description: l.item_name ?? '', role: l.component_role ?? '', qty: l.qty, uom: l.uom, cutLength: l.cut_length_mm != null ? Number(l.cut_length_mm) : null, cutWidth: l.cut_width_mm != null ? Number(l.cut_width_mm) : null })),
            });
            pdf.save(`WO-${moMeta.mo_number}-${stationCode}.pdf`);
          }} className="p-1.5 rounded hover:bg-gray-200 text-gray-500" title="Print work sheet">
            <Printer className="h-3.5 w-3.5" />
          </button>
          <button type="button" onClick={async () => {
            const labels: PartLabel[] = task.lines.map(l => ({
              moNumber: moMeta.mo_number,
              soNumber: moMeta.so_number,
              customerName: moMeta.customer_name,
              date: new Date().toLocaleDateString(),
              sku: l.sku ?? '',
              itemName: l.item_name ?? '',
              cutDimension: l.cut_length_mm != null ? `X ${Math.round(Number(l.cut_length_mm))} mm` : (l.cut_width_mm != null ? `Y ${Math.round(Number(l.cut_width_mm))} mm` : '—'),
              qty: l.qty,
              lineId: l.id,
            }));
            const pdf = await generatePartLabelsPDF(labels);
            pdf.save(`Labels-${moMeta.mo_number}-${stationCode}.pdf`);
          }} className="p-1.5 rounded hover:bg-gray-200 text-gray-500" title="Print labels">
            <Tag className="h-3.5 w-3.5" />
          </button>
        </div>
      </div>

      {expanded && (
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100 text-gray-500 text-xs">
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
            {task.lines.map(line => (
              <tr key={line.id} className={`border-t border-gray-50 ${line.completed ? 'bg-green-50/30' : 'hover:bg-gray-50/50'}`}>
                <td className="px-4 py-2">
                  <input
                    type="checkbox"
                    checked={line.completed}
                    onChange={e => onToggleLine(line.id, e.target.checked)}
                    className="rounded border-gray-300"
                    disabled={task.status === 'completed'}
                  />
                </td>
                <td className={`px-4 py-2 font-mono ${line.completed ? 'line-through text-gray-400' : 'text-gray-800'}`}>{line.sku || '—'}</td>
                <td className={`px-4 py-2 ${line.completed ? 'line-through text-gray-400' : 'text-gray-700'}`}>
                  {line.item_name || '—'}
                  {(line.component_role === 'fabric' || line.component_role === 'tape') && (line.cut_length_mm != null || line.cut_width_mm != null) && (
                    <div className="text-[11px] text-blue-600 font-medium mt-0.5">
                      CUT: {line.cut_length_mm != null ? `${Math.round(Number(line.cut_length_mm))} mm` : ''}{line.cut_length_mm != null && line.cut_width_mm != null ? ' × ' : ''}{line.cut_width_mm != null ? `${Math.round(Number(line.cut_width_mm))} mm` : ''}
                    </div>
                  )}
                </td>
                <td className="px-4 py-2">
                  {line.component_role && <span className={`text-xs px-1.5 py-0.5 rounded ${line.component_role === 'fabric' ? 'bg-blue-50 text-blue-700' : line.component_role === 'tape' ? 'bg-purple-50 text-purple-700' : 'bg-gray-100 text-gray-600'}`}>{line.component_role}</span>}
                </td>
                <td className="px-4 py-2 text-right text-gray-700">{Number(line.qty).toFixed(line.uom === 'ea' ? 0 : 3)}</td>
                <td className="px-4 py-2 text-gray-500">{line.uom}</td>
                <td className="px-4 py-2 text-right text-gray-600">{line.cut_length_mm != null ? Math.round(Number(line.cut_length_mm)) : '—'}</td>
                <td className="px-4 py-2 text-right text-gray-600">{line.cut_width_mm != null ? Math.round(Number(line.cut_width_mm)) : '—'}</td>
              </tr>
            ))}
            {task.lines.length === 0 && (
              <tr><td colSpan={8} className="px-4 py-6 text-center text-gray-400 text-sm">No lines in this station</td></tr>
            )}
          </tbody>
        </table>
      )}
    </div>
  );
}

export default function WorkOrderDetail({ moId }: WorkOrderDetailProps) {
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const { tasks, loading: tasksLoading, toggleLineCompleted, updateTaskStatus } = useWorkOrderTasks(moId);
  const [moInfo, setMoInfo] = useState<MOInfo | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    registerSubmodules('Manufacturing', [...MANUFACTURING_SUBMODULES]);
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/manufacturing')) clearSubmoduleNav();
    };
  }, [registerSubmodules, clearSubmoduleNav]);

  const fetchMOInfo = useCallback(async () => {
    setLoading(true);
    try {
      const { data: mo } = await supabase
        .from('ManufacturingOrders')
        .select('manufacturing_order_no, product_name, sales_order_id')
        .eq('id', moId)
        .single();

      if (!mo) { setMoInfo(null); setLoading(false); return; }

      let customerName = '—';
      let soNumber = '—';
      let dueDate: string | null = null;

      if (mo.sales_order_id) {
        const { data: so } = await supabase
          .from('SalesOrders')
          .select('sales_order_no, customer_id, expected_delivery_date')
          .eq('id', mo.sales_order_id)
          .single();
        if (so) {
          soNumber = so.sales_order_no ?? '—';
          dueDate = so.expected_delivery_date ?? null;
          if (so.customer_id) {
            const { data: cust } = await supabase.from('DirectoryCustomers').select('customer_name').eq('id', so.customer_id).single();
            customerName = cust?.customer_name ?? '—';
          }
        }
      }

      setMoInfo({
        mo_number: mo.manufacturing_order_no ?? '—',
        product_name: mo.product_name ?? '—',
        customer_name: customerName,
        so_number: soNumber,
        due_date: dueDate,
      });
    } catch {
      setMoInfo(null);
    } finally {
      setLoading(false);
    }
  }, [moId]);

  useEffect(() => { fetchMOInfo(); }, [fetchMOInfo]);

  if (loading || tasksLoading) {
    return (
      <div className="flex items-center justify-center py-20">
        <Loader2 className="h-6 w-6 animate-spin text-gray-400" />
      </div>
    );
  }

  if (!moInfo) {
    return (
      <div className="py-6 px-6">
        <button onClick={() => router.navigate('/manufacturing/work-orders')} className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700 mb-4">
          <ArrowLeft className="w-4 h-4" /> Back to Work Orders
        </button>
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <p className="text-gray-500">Work order not found</p>
        </div>
      </div>
    );
  }

  const allLines = tasks.flatMap(t => t.lines);
  const totalLines = allLines.length;
  const completedLines = allLines.filter(l => l.completed).length;
  const globalPct = totalLines > 0 ? Math.round((completedLines / totalLines) * 100) : 0;

  const globalStatus = (() => {
    if (tasks.length === 0) return 'pending';
    if (tasks.every(t => t.status === 'completed')) return 'completed';
    if (tasks.some(t => t.status === 'in_progress' || t.status === 'completed')) return 'in_progress';
    return 'pending';
  })();

  return (
    <div className="py-6 px-6">
      <button
        onClick={() => router.navigate('/manufacturing/work-orders')}
        className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700 mb-4"
      >
        <ArrowLeft className="w-4 h-4" /> Back to Work Orders
      </button>

      {/* Header */}
      <div className="bg-white border border-gray-200 rounded-lg p-6 mb-6">
        <div className="flex items-start justify-between">
          <div>
            <div className="flex items-center gap-3 mb-1">
              <h1 className="text-xl font-semibold text-gray-900">{moInfo.mo_number}</h1>
              <StatusBadge status={globalStatus} type="workOrder" size="md" />
            </div>
            <p className="text-sm text-gray-500">{moInfo.product_name}</p>
          </div>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mt-6">
          <div className="flex items-start gap-2.5">
            <ClipboardList className="w-4 h-4 text-gray-400 mt-0.5 shrink-0" />
            <div>
              <p className="text-xs text-gray-400">MO #</p>
              <button
                onClick={() => router.navigate(`/manufacturing/manufacturing-orders/${moId}`)}
                className="text-sm font-medium text-primary hover:underline"
              >
                {moInfo.mo_number}
                <ExternalLink className="w-3 h-3 inline ml-1" />
              </button>
            </div>
          </div>
          <div className="flex items-start gap-2.5">
            <User className="w-4 h-4 text-gray-400 mt-0.5 shrink-0" />
            <div>
              <p className="text-xs text-gray-400">Customer</p>
              <p className="text-sm font-medium text-gray-900">{moInfo.customer_name}</p>
            </div>
          </div>
          <div className="flex items-start gap-2.5">
            <Package className="w-4 h-4 text-gray-400 mt-0.5 shrink-0" />
            <div>
              <p className="text-xs text-gray-400">SO #</p>
              <p className="text-sm font-medium text-gray-900">{moInfo.so_number}</p>
            </div>
          </div>
          <div className="flex items-start gap-2.5">
            <Calendar className="w-4 h-4 text-gray-400 mt-0.5 shrink-0" />
            <div>
              <p className="text-xs text-gray-400">Due Date</p>
              <p className="text-sm font-medium text-gray-900">{moInfo.due_date ? new Date(moInfo.due_date).toLocaleDateString() : '—'}</p>
            </div>
          </div>
        </div>

        {/* Global Progress */}
        <div className="mt-6">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs text-gray-500">Global Progress</span>
            <span className="text-xs font-medium text-gray-700">{completedLines}/{totalLines} lines · {globalPct}%</span>
          </div>
          <div className="w-full h-2 bg-gray-200 rounded-full overflow-hidden">
            <div
              className={`h-full rounded-full transition-all ${globalPct === 100 ? 'bg-green-500' : globalPct > 0 ? 'bg-blue-500' : 'bg-gray-300'}`}
              style={{ width: `${globalPct}%` }}
            />
          </div>
        </div>
      </div>

      {/* Station Cards */}
      <div className="space-y-4">
        {tasks.map(task => (
          <StationCard
            key={task.id}
            task={task}
            onToggleLine={toggleLineCompleted}
            onStatusChange={updateTaskStatus}
            moMeta={moInfo}
          />
        ))}
        {tasks.length === 0 && (
          <div className="bg-white border border-gray-200 rounded-lg p-8 text-center">
            <p className="text-sm text-gray-500">No work order tasks found for this Manufacturing Order.</p>
          </div>
        )}
      </div>
    </div>
  );
}
