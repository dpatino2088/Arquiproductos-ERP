import { useState } from 'react';
import { useWorkOrderTasks, type WorkOrderTask } from '../../hooks/useWorkOrderTasks';
import { useMoMaterialReadiness } from '../../hooks/useManufacturing';
import StatusBadge from '../../components/shared/StatusBadge';
import { generateWorkOrderPDF } from '../../lib/pdf/workOrderPdf';
import { generatePartLabelsPDF, type PartLabel } from '../../lib/pdf/partLabelPdf';
import { router } from '../../lib/router';
import { ChevronDown, ChevronRight, Printer, Tag, Play, CheckCircle2, Loader2, Zap, ArrowUpRight, RefreshCw } from 'lucide-react';

interface WorkOrdersTabProps {
  moId: string;
  moNumber?: string;
  customerName?: string;
  productName?: string;
  salesOrderNo?: string;
}

function StationCard({ task, onToggleLine, onStatusChange, moMeta }: {
  task: WorkOrderTask;
  onToggleLine: (lineId: string, completed: boolean) => void;
  onStatusChange: (taskId: string, status: 'pending' | 'in_progress' | 'completed') => void;
  moMeta: { moNumber: string; customerName: string; productName: string; salesOrderNo?: string };
}) {
  const [expanded, setExpanded] = useState(true);
  const completedCount = task.lines.filter((l) => l.completed).length;
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
            <span className="font-semibold text-gray-900 text-sm">{stationName}</span>
            <span className="ml-2 text-xs text-gray-400 font-mono">{stationCode}</span>
          </div>
          <StatusBadge status={task.status} type="workOrder" size="sm" />
        </div>

        <div className="flex items-center gap-3">
          <span className="text-xs text-gray-500">{completedCount}/{totalCount} lines</span>
          <div className="w-20 h-1.5 bg-gray-200 rounded-full overflow-hidden">
            <div className="h-full bg-green-500 rounded-full transition-all" style={{ width: `${pct}%` }} />
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
              moNumber: moMeta.moNumber,
              stationName: task.work_center?.name ?? 'Station',
              stationCode: task.work_center?.code ?? '',
              customerName: moMeta.customerName,
              productName: moMeta.productName,
              salesOrderNo: moMeta.salesOrderNo,
              date: new Date().toLocaleDateString(),
              lines: task.lines.map((l) => ({ sku: l.sku ?? '', description: l.item_name ?? '', role: l.component_role ?? '', qty: l.qty, uom: l.uom, cutLength: l.cut_length_mm != null ? Number(l.cut_length_mm) : null, cutWidth: l.cut_width_mm != null ? Number(l.cut_width_mm) : null })),
            });
            pdf.save(`WO-${moMeta.moNumber}-${task.work_center?.code ?? 'station'}.pdf`);
          }} className="p-1.5 rounded hover:bg-gray-200 text-gray-500" title="Print work sheet">
            <Printer className="h-3.5 w-3.5" />
          </button>
          <button type="button" onClick={async () => {
            const labels: PartLabel[] = task.lines.map((l) => ({
              moNumber: moMeta.moNumber,
              soNumber: moMeta.salesOrderNo,
              customerName: moMeta.customerName,
              date: new Date().toLocaleDateString(),
              sku: l.sku ?? '',
              itemName: l.item_name ?? '',
              cutDimension: l.cut_length_mm != null ? `X ${Math.round(Number(l.cut_length_mm))} mm` : (l.cut_width_mm != null ? `Y ${Math.round(Number(l.cut_width_mm))} mm` : '—'),
              qty: l.qty,
              lineId: l.id,
            }));
            const pdf = await generatePartLabelsPDF(labels);
            pdf.save(`Labels-${moMeta.moNumber}-${task.work_center?.code ?? 'station'}.pdf`);
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
            {task.lines.map((line) => (
              <tr key={line.id} className={`border-t border-gray-50 ${line.completed ? 'bg-green-50/30' : 'hover:bg-gray-50/50'}`}>
                <td className="px-4 py-2">
                  <input
                    type="checkbox"
                    checked={line.completed}
                    onChange={(e) => onToggleLine(line.id, e.target.checked)}
                    className="rounded border-gray-300"
                  />
                </td>
                <td className={`px-4 py-2 font-mono ${line.completed ? 'line-through text-gray-400' : 'text-gray-800'}`}>{line.sku || '—'}</td>
                <td className={`px-4 py-2 ${line.completed ? 'line-through text-gray-400' : 'text-gray-700'}`}>{line.item_name || '—'}</td>
                <td className="px-4 py-2">
                  {line.component_role && <span className="text-xs bg-gray-100 text-gray-600 px-1.5 py-0.5 rounded">{line.component_role}</span>}
                </td>
                <td className="px-4 py-2 text-right text-gray-700">{line.qty}</td>
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

export default function WorkOrdersTab({ moId, moNumber = '', customerName = '', productName = '', salesOrderNo }: WorkOrdersTabProps) {
  const { tasks, loading, error, toggleLineCompleted, updateTaskStatus, generateWorkOrders } = useWorkOrderTasks(moId);
  const { readiness: materialReadiness } = useMoMaterialReadiness(moId);
  const [generating, setGenerating] = useState(false);
  const materialsIncomplete = materialReadiness?.hasShortage === true;

  const handleGenerate = async (regenerate = false) => {
    if (regenerate && !confirm('This will delete existing work orders and regenerate them. Continue?')) return;
    setGenerating(true);
    try {
      await generateWorkOrders(regenerate);
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Error generating work orders');
    } finally {
      setGenerating(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="h-6 w-6 animate-spin text-gray-400" />
      </div>
    );
  }

  if (error) {
    return <div className="text-sm text-red-600 bg-red-50 rounded px-4 py-3">{error}</div>;
  }

  if (tasks.length === 0) {
    return (
      <div className="rounded-lg border border-gray-200 bg-white p-8 text-center">
        {materialsIncomplete && (
          <div className="mb-4 flex items-center gap-2 px-3 py-1.5 rounded-md bg-amber-50 border border-amber-100 w-fit">
            <span className="inline-block w-1.5 h-1.5 rounded-full bg-amber-400 flex-shrink-0" />
            <span className="text-xs text-amber-700">
              Material shortage — <button type="button" onClick={() => router.navigate(`/inventory/material-demand?mo_id=${moId}`)} className="underline font-medium">open Material Demand</button> to cover before generating.
            </span>
          </div>
        )}
        <Zap className="h-10 w-10 text-gray-300 mx-auto mb-3" />
        <p className="text-sm text-gray-500 mb-4">No work orders generated yet for this Manufacturing Order.</p>
        <button type="button" onClick={() => handleGenerate()} disabled={generating || materialsIncomplete} className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:opacity-90 disabled:opacity-60" title={materialsIncomplete ? 'Materials incomplete. Cover demand first.' : undefined}>
          {generating ? <Loader2 className="h-4 w-4 animate-spin" /> : <Zap className="h-4 w-4" />}
          Generate Work Orders
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {materialsIncomplete && (
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-md bg-amber-50 border border-amber-100 w-fit">
          <span className="inline-block w-1.5 h-1.5 rounded-full bg-amber-400 flex-shrink-0" />
          <span className="text-xs text-amber-700">Material shortage — regeneration blocked until demand is covered.</span>
        </div>
      )}
      <div className="flex items-center justify-between">
        <button
          type="button"
          onClick={() => handleGenerate(true)}
          disabled={generating || materialsIncomplete}
          title={materialsIncomplete ? 'Materials incomplete. Cover demand first.' : undefined}
          className="inline-flex items-center gap-1.5 text-xs px-2.5 py-1.5 rounded border border-gray-200 text-gray-600 hover:bg-gray-50 disabled:opacity-50"
        >
          {generating ? <Loader2 className="h-3 w-3 animate-spin" /> : <RefreshCw className="h-3 w-3" />}
          Regenerate
        </button>
        <button
          type="button"
          onClick={() => router.navigate(`/manufacturing/work-orders/${moId}`)}
          className="inline-flex items-center gap-1.5 text-xs text-primary hover:underline"
        >
          Open in Work Orders <ArrowUpRight className="w-3 h-3" />
        </button>
      </div>
      {tasks.map((task) => (
        <StationCard
          key={task.id}
          task={task}
          onToggleLine={toggleLineCompleted}
          onStatusChange={updateTaskStatus}
          moMeta={{ moNumber, customerName, productName, salesOrderNo }}
        />
      ))}
    </div>
  );
}
