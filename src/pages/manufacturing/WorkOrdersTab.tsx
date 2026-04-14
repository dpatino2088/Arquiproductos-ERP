import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../../lib/supabase/client';
import { formatDate } from '../../lib/utils';
import { useWorkOrderTasks, type WorkOrderTask } from '../../hooks/useWorkOrderTasks';
import { useMoMaterialReadiness } from '../../hooks/useManufacturing';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import StatusBadge from '../../components/shared/StatusBadge';
import { generateWorkOrderPDF } from '../../lib/pdf/workOrderPdf';
import { generatePartLabelsPDF, type PartLabel } from '../../lib/pdf/partLabelPdf';
import { router } from '../../lib/router';
import { ChevronDown, ChevronRight, Printer, Tag, CheckCircle2, Circle, Loader2, Zap, ArrowUpRight, RefreshCw, Package, CalendarDays, X, Clock } from 'lucide-react';
import AssemblyDetail from '../../components/manufacturing/assembly/AssemblyDetail';

interface OperatorOption {
  user_id: string;
  display_name: string;
}

interface WorkOrdersTabProps {
  moId: string;
  moNumber?: string;
  customerName?: string;
  dealerName?: string;
  productName?: string;
  salesOrderNo?: string;
  moStatus?: string;
}

function StationCard({ task, moMeta, siblingTasks }: {
  task: WorkOrderTask;
  moMeta: { moNumber: string; customerName: string; productName: string; salesOrderNo?: string };
  siblingTasks?: WorkOrderTask[];
}) {
  const [expanded, setExpanded] = useState(false);
  const completedCount = task.lines.filter((l) => l.completed).length;
  const totalCount = task.lines.length;
  const pct = totalCount > 0 ? Math.round((completedCount / totalCount) * 100) : 0;

  const stationName = task.work_center?.name ?? 'Station';
  const stationCode = task.work_center?.code ?? '';
  const upperStationCode = stationCode.toUpperCase();
  const isAssembly = upperStationCode === 'ASSEMBLY';
  const isRollCut = upperStationCode === 'CUT-ROLL';
  const isProfileCut = upperStationCode === 'CUT-PROFILE';
  const columnCount = 8;

  return (
    <div className="bg-white overflow-hidden">
      <div className="flex items-center h-9 px-4 bg-gray-50 border-b border-gray-100">
        <button type="button" onClick={() => setExpanded(!expanded)} className="text-gray-400 hover:text-gray-600 mr-2 flex-shrink-0">
          {expanded ? <ChevronDown className="h-3.5 w-3.5" /> : <ChevronRight className="h-3.5 w-3.5" />}
        </button>
        <span className="font-semibold text-gray-700 text-xs uppercase tracking-wide w-40 truncate flex-shrink-0">{stationName}</span>
        <span className="text-[10px] text-gray-400 font-mono w-24 truncate flex-shrink-0">{stationCode}</span>
        <div className="flex-shrink-0 mr-3">
          <StatusBadge status={task.status} type="workOrder" size="sm" />
        </div>
        <div className="flex-1" />
        <span className="text-[11px] text-gray-400 mr-2">{completedCount}/{totalCount} lines</span>
        <div className="w-14 h-1 bg-gray-200 rounded-full overflow-hidden mr-3 flex-shrink-0">
          <div className="h-full bg-green-500 rounded-full transition-all" style={{ width: `${pct}%` }} />
        </div>
        <button type="button" onClick={() => {
          const pdf = generateWorkOrderPDF({
            moNumber: moMeta.moNumber,
            stationName: task.work_center?.name ?? 'Station',
            stationCode: task.work_center?.code ?? '',
            customerName: moMeta.customerName,
            productName: moMeta.productName,
            salesOrderNo: moMeta.salesOrderNo,
            date: formatDate(new Date()),
            lines: task.lines.map((l) => ({ sku: l.sku ?? '', description: l.item_name ?? '', role: l.component_role ?? '', qty: l.qty, uom: l.uom, cutLength: l.cut_length_mm != null ? Number(l.cut_length_mm) : null, cutWidth: l.cut_width_mm != null ? Number(l.cut_width_mm) : null })),
          });
          pdf.save(`WO-${moMeta.moNumber}-${task.work_center?.code ?? 'station'}.pdf`);
        }} className="p-1 rounded hover:bg-gray-200 text-gray-400 flex-shrink-0" title="Print work sheet">
          <Printer className="h-3.5 w-3.5" />
        </button>
        <button type="button" onClick={async () => {
          const labels: PartLabel[] = task.lines.map((l) => ({
            moNumber: moMeta.moNumber,
            soNumber: moMeta.salesOrderNo,
            customerName: moMeta.customerName,
            date: formatDate(new Date()),
            sku: l.sku ?? '',
            itemName: l.item_name ?? '',
            cutDimension: l.cut_length_mm != null ? `X ${Math.round(Number(l.cut_length_mm))} mm` : (l.cut_width_mm != null ? `Y ${Math.round(Number(l.cut_width_mm))} mm` : '—'),
            qty: l.qty,
            lineId: l.id,
          }));
          const pdf = await generatePartLabelsPDF(labels);
          pdf.save(`Labels-${moMeta.moNumber}-${task.work_center?.code ?? 'station'}.pdf`);
        }} className="p-1 rounded hover:bg-gray-200 text-gray-400 flex-shrink-0 ml-1" title="Print labels">
          <Tag className="h-3.5 w-3.5" />
        </button>
      </div>

      {expanded && isAssembly && (
        <div className="p-3">
          <AssemblyDetail
            manufacturingOrderId={task.manufacturing_order_id}
            moNumber={moMeta.moNumber}
            productName={moMeta.productName}
            readOnly
            lines={task.lines.map(l => ({
              id: l.id,
              sku: l.sku,
              item_name: l.item_name,
              component_role: l.component_role,
              qty: l.qty,
              uom: l.uom,
              cut_length_mm: l.cut_length_mm != null ? Number(l.cut_length_mm) : null,
              cut_width_mm: l.cut_width_mm != null ? Number(l.cut_width_mm) : null,
              completed: l.completed,
              bom_instance_line_id: l.bom_instance_line_id,
            }))}
            onToggleLine={() => {}}
            siblingTasks={siblingTasks?.map(t => ({
              code: t.work_center?.code ?? '',
              status: t.status,
            })).filter(t => t.code !== 'ASSEMBLY')}
          />
        </div>
      )}

      {expanded && !isAssembly && (
        <table className="w-full text-sm table-fixed">
          <colgroup>
            <col className="w-8" />
            <col className="w-[16%]" />
            <col className="w-[34%]" />
            <col className="w-[12%]" />
            <col className="w-[8%]" />
            <col className="w-[8%]" />
            <col className="w-[11%]" />
            <col className="w-[11%]" />
          </colgroup>
          <thead>
            <tr className="border-b border-gray-100 text-gray-500 text-xs">
              <th className="text-left px-4 py-2 w-8"></th>
              <th className="text-left px-4 py-2">SKU</th>
              <th className="text-left px-4 py-2">Description</th>
              <th className="text-left px-4 py-2">Role</th>
              <th className="text-right px-4 py-2">Qty</th>
              <th className="text-left px-4 py-2">UOM</th>
              <th className="text-right px-4 py-2">
                {isRollCut ? 'Length X (mm)' : isProfileCut ? 'Length (mm)' : ''}
              </th>
              <th className="text-right px-4 py-2">{isRollCut ? 'Length Y (mm)' : ''}</th>
            </tr>
          </thead>
          <tbody>
            {task.lines.map((line) => (
              <tr key={line.id} className={`border-t border-gray-50 ${line.completed ? 'bg-green-50/30' : 'hover:bg-gray-50/50'}`}>
                <td className="px-4 py-2">
                  {line.completed
                    ? <CheckCircle2 className="h-4 w-4 text-green-500" />
                    : <Circle className="h-4 w-4 text-gray-300" />}
                </td>
                <td className={`px-4 py-2 font-mono ${line.completed ? 'line-through text-gray-400' : 'text-gray-800'}`}>{line.sku || '—'}</td>
                <td className={`px-4 py-2 ${line.completed ? 'line-through text-gray-400' : 'text-gray-700'}`}>{line.item_name || '—'}</td>
                <td className="px-4 py-2">
                  {line.component_role
                    ? <span className="text-xs bg-gray-100 text-gray-600 px-1.5 py-0.5 rounded">{line.component_role}</span>
                    : <span className="text-gray-400">—</span>}
                </td>
                <td className="px-4 py-2 text-right text-gray-700">{line.qty}</td>
                <td className="px-4 py-2 text-gray-500">{line.uom}</td>
                <td className="px-4 py-2 text-right text-gray-600">
                  {isRollCut || isProfileCut
                    ? (line.cut_length_mm != null ? Math.round(Number(line.cut_length_mm)) : '—')
                    : '—'}
                </td>
                <td className="px-4 py-2 text-right text-gray-600">
                  {isRollCut
                    ? (line.cut_width_mm != null ? Math.round(Number(line.cut_width_mm)) : '—')
                    : '—'}
                </td>
              </tr>
            ))}
            {task.lines.length === 0 && (
              <tr><td colSpan={columnCount} className="px-4 py-6 text-center text-gray-400 text-sm">No lines in this station</td></tr>
            )}
          </tbody>
        </table>
      )}
    </div>
  );
}

function formatShortDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const match = iso.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!match) return '—';
  const [, , m, d] = match;
  return `${d}/${m}`;
}

function toDateInput(iso: string | null | undefined): string {
  if (!iso) return '';
  const match = iso.match(/^(\d{4}-\d{2}-\d{2})/);
  if (match) return match[1];
  return '';
}

function clampDateToToday(dateStr: string, today: string): string {
  if (!dateStr) return today;
  return dateStr < today ? today : dateStr;
}

const STATION_ORDER: Record<string, number> = { 'CUT-ROLL': 0, 'CUT-PROFILE': 0, 'PICK': 1, 'ASSEMBLY': 2 };
function stationPhase(code: string): number { return STATION_ORDER[code.toUpperCase()] ?? 1; }

function SchedulePopup({
  label,
  tasks,
  isGlobal,
  onSave,
  onClose,
}: {
  label: string;
  tasks: WorkOrderTask[];
  isGlobal: boolean;
  onSave: (updates: { id: string; planned_start_at: string }[]) => Promise<void>;
  onClose: () => void;
}) {
  const stationTypes = useMemo(() => {
    const m = new Map<string, { name: string; code: string; count: number; defaultHours: number }>();
    for (const t of tasks) {
      const code = t.work_center?.code ?? '';
      if (!m.has(code)) {
        m.set(code, {
          name: t.work_center?.name ?? 'Station',
          code,
          count: 0,
          defaultHours: t.estimated_duration_hours ?? 8,
        });
      }
      m.get(code)!.count++;
    }
    return [...m.values()].sort((a, b) => stationPhase(a.code) - stationPhase(b.code));
  }, [tasks]);

  const today = useMemo(() => {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  }, []);

  const existingStart = useMemo(() => {
    const starts = tasks.map(t => toDateInput(t.planned_start_at)).filter(Boolean);
    return starts.length > 0 ? starts.sort()[0] : '';
  }, [tasks]);

  const [startDate, setStartDate] = useState(clampDateToToday(existingStart || today, today));
  const [saving, setSaving] = useState(false);

  const [perLineDates, setPerLineDates] = useState<Record<string, string>>(() => {
    if (isGlobal) return {};
    const m: Record<string, string> = {};
    for (const t of tasks) m[t.id] = clampDateToToday(toDateInput(t.planned_start_at) || '', today);
    return m;
  });

  const computeDates = useCallback((base: string) => {
    const safeBase = clampDateToToday(base, today);
    const updates: { id: string; planned_start_at: string }[] = [];
    const phaseMap = new Map<number, string>();

    for (const st of stationTypes) {
      const phase = stationPhase(st.code);
      if (!phaseMap.has(phase)) {
        if (phase === 0) {
          phaseMap.set(0, safeBase);
        } else {
          const prevPhase = phase - 1;
          const prevDate = phaseMap.get(prevPhase) ?? safeBase;
          const d = new Date(`${prevDate}T00:00:00`);
          d.setDate(d.getDate() + 1);
          while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() + 1);
          phaseMap.set(phase, `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`);
        }
      }
    }

    for (const t of tasks) {
      const code = t.work_center?.code ?? '';
      const phase = stationPhase(code);
      const dateStr = phaseMap.get(phase) ?? safeBase;
      updates.push({ id: t.id, planned_start_at: dateStr });
    }
    return updates;
  }, [tasks, stationTypes, today]);

  const preview = useMemo(() => {
    if (!startDate) return [];
    const updates = computeDates(startDate);
    const byPhase = new Map<string, string>();
    for (const u of updates) {
      const t = tasks.find(x => x.id === u.id);
      const code = t?.work_center?.code ?? '';
      if (!byPhase.has(code)) byPhase.set(code, u.planned_start_at);
    }
    return stationTypes.map(st => ({
      ...st,
      date: byPhase.get(st.code) ?? startDate,
      parallel: stationPhase(st.code) === 0,
    }));
  }, [startDate, computeDates, tasks, stationTypes]);

  const handleSave = async () => {
    setSaving(true);
    if (isGlobal) {
      await onSave(computeDates(clampDateToToday(startDate, today)));
    } else {
      const updates = tasks
        .filter(t => perLineDates[t.id])
        .map(t => ({ id: t.id, planned_start_at: clampDateToToday(perLineDates[t.id], today) }));
      if (updates.length > 0) await onSave(updates);
    }
    setSaving(false);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30" onClick={onClose}>
      <div className="bg-white rounded-xl shadow-xl w-full max-w-md mx-4" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between px-5 py-3 border-b border-gray-100">
          <div className="flex items-center gap-2">
            <CalendarDays className="w-4 h-4 text-gray-500" />
            <span className="text-sm font-semibold text-gray-900">Schedule — {label}</span>
          </div>
          <button type="button" onClick={onClose} className="p-1 rounded hover:bg-gray-100 text-gray-400">
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="px-5 py-4 space-y-4">
          {/* Start date */}
          <div>
            <label className="text-[10px] text-gray-400 uppercase tracking-wide block mb-1">
              {isGlobal ? 'Production Start Date (all lines)' : 'Start Date'}
            </label>
            {isGlobal ? (
              <input
                type="date"
                value={startDate}
                min={today}
                onChange={e => setStartDate(clampDateToToday(e.target.value, today))}
                className="text-sm border border-gray-200 rounded-lg px-3 py-1.5 w-full text-gray-700 focus:ring-1 focus:ring-primary focus:border-primary"
              />
            ) : (
              <input
                type="date"
                value={startDate}
                min={today}
                onChange={e => {
                  const safeDate = clampDateToToday(e.target.value, today);
                  setStartDate(safeDate);
                  const updates = computeDates(safeDate);
                  const m: Record<string, string> = {};
                  for (const u of updates) m[u.id] = u.planned_start_at;
                  setPerLineDates(m);
                }}
                className="text-sm border border-gray-200 rounded-lg px-3 py-1.5 w-full text-gray-700 focus:ring-1 focus:ring-primary focus:border-primary"
              />
            )}
            {existingStart && existingStart < today && (
              <p className="text-[11px] text-amber-600 mt-1">
                Existing schedule had past dates. New assignments are clamped to today or later.
              </p>
            )}
          </div>

          {/* Station phase preview */}
          {startDate && (
            <div className="space-y-1.5">
              <span className="text-[10px] text-gray-400 uppercase tracking-wide">Station Schedule</span>
              {preview.map((st, idx) => (
                <div key={st.code || idx} className="flex items-center gap-3 py-1.5 px-2 rounded bg-gray-50">
                  <div className="flex-1 min-w-0">
                    <span className="text-xs font-medium text-gray-700">{st.name}</span>
                    {st.parallel && <span className="ml-1.5 text-[9px] text-blue-500 font-medium">PARALLEL</span>}
                    {isGlobal && st.count > 1 && <span className="ml-1.5 text-[9px] text-gray-400">×{st.count} tasks</span>}
                  </div>
                  {isGlobal ? (
                    <span className="text-xs text-gray-600 font-mono">{formatShortDate(st.date)}</span>
                  ) : (
                    <input
                      type="date"
                      value={perLineDates[tasks.find(t => t.work_center?.code === st.code)?.id ?? ''] || st.date}
                      min={today}
                      onChange={e => {
                        const taskId = tasks.find(t => t.work_center?.code === st.code)?.id;
                        if (taskId) {
                          const safeDate = clampDateToToday(e.target.value, today);
                          setPerLineDates(prev => ({ ...prev, [taskId]: safeDate }));
                        }
                      }}
                      className="text-xs border border-gray-200 rounded px-2 py-1 w-32 text-gray-700 focus:ring-1 focus:ring-primary focus:border-primary"
                    />
                  )}
                </div>
              ))}
              {isGlobal && (
                <p className="text-[10px] text-gray-400 mt-1">
                  Cut stations run in parallel. Pick starts after cuts. Assembly starts after pick.
                </p>
              )}
            </div>
          )}
        </div>

        <div className="flex items-center justify-end gap-2 px-5 py-3 border-t border-gray-100">
          <button type="button" onClick={onClose} className="text-xs px-3 py-1.5 rounded border border-gray-200 text-gray-600 hover:bg-gray-50">
            Cancel
          </button>
          <button
            type="button"
            onClick={handleSave}
            disabled={saving || !startDate}
            className="text-xs px-4 py-1.5 rounded bg-primary text-white hover:bg-primary/90 disabled:opacity-50 inline-flex items-center gap-1.5"
          >
            {saving && <Loader2 className="w-3 h-3 animate-spin" />}
            {isGlobal ? 'Apply to All Lines' : 'Save Schedule'}
          </button>
        </div>
      </div>
    </div>
  );
}

interface LineProductInfo {
  sales_order_line_id: string;
  description: string | null;
  product_type: string | null;
  collection_name: string | null;
  variant_name: string | null;
  hardware_color: string | null;
  quantity: number;
  catalogName: string | null;
  manufacturer: string | null;
  sku: string | null;
}

export default function WorkOrdersTab({ moId, moNumber = '', customerName = '', dealerName = '', productName = '', salesOrderNo, moStatus }: WorkOrdersTabProps) {
  const { tasks, loading, error, generateWorkOrders, refetch: refetchTasks } = useWorkOrderTasks(moId);
  const { readiness: materialReadiness } = useMoMaterialReadiness(moId);
  const { activeOrganizationId } = useOrganizationContext();
  const addNotification = useUIStore((s) => s.addNotification);
  const { dialogState, showConfirm, closeDialog, handleConfirm } = useConfirmDialog();
  const [generating, setGenerating] = useState(false);
  const [operators, setOperators] = useState<OperatorOption[]>([]);
  const [lineProductMap, setLineProductMap] = useState<Map<string, LineProductInfo>>(new Map());
  const [expandedGroups, setExpandedGroups] = useState<Set<string>>(new Set());
  const [schedulePopup, setSchedulePopup] = useState<{ label: string; tasks: WorkOrderTask[]; isGlobal: boolean } | null>(null);
  const toggleGroup = useCallback((key: string) => {
    setExpandedGroups(prev => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key); else next.add(key);
      return next;
    });
  }, []);
  const materialsIncomplete = materialReadiness?.hasShortage === true;
  const canGenerateByStatus = ['materials_ready', 'in_production'].includes(moStatus ?? '');
  const allOperatorsAssigned = useMemo(
    () => tasks.length > 0 && tasks.every((t) => Boolean(t.assigned_to_user_id)),
    [tasks],
  );
  const canOpenSchedule = !materialsIncomplete && allOperatorsAssigned;

  useEffect(() => {
    if (!moId) return;
    (async () => {
      const { data: molData } = await supabase
        .from('ManufacturingOrderLines')
        .select('sales_order_line_id')
        .eq('manufacturing_order_id', moId)
        .eq('deleted', false);
      const solIds = [...new Set((molData ?? []).map((m: any) => m.sales_order_line_id).filter(Boolean))];
      if (solIds.length === 0) return;
      const { data: solData } = await supabase
        .from('SaleOrderLines')
        .select('id, description, product_type, collection_name, variant_name, hardware_color, quantity, catalog_item_id')
        .in('id', solIds);
      if (!solData) return;
      const catIds = [...new Set(solData.map((s: any) => s.catalog_item_id).filter(Boolean))];
      let catMap = new Map<string, any>();
      if (catIds.length > 0) {
        const { data: catData } = await supabase.from('CatalogItems').select('id, name, sku, manufacturer').in('id', catIds);
        if (catData) catMap = new Map(catData.map((c: any) => [c.id, c]));
      }
      const m = new Map<string, LineProductInfo>();
      for (const s of solData) {
        const cat = s.catalog_item_id ? catMap.get(s.catalog_item_id) : null;
        m.set(s.id, {
          sales_order_line_id: s.id,
          description: s.description,
          product_type: s.product_type,
          collection_name: s.collection_name,
          variant_name: s.variant_name,
          hardware_color: s.hardware_color,
          quantity: s.quantity,
          catalogName: cat?.name ?? null,
          manufacturer: cat?.manufacturer ?? null,
          sku: cat?.sku ?? null,
        });
      }
      setLineProductMap(m);
    })();
  }, [moId]);

  const stationRank = (code?: string | null) => {
    const c = (code ?? '').toUpperCase();
    if (c === 'CUT-ROLL') return 0;
    if (c === 'CUT-PROFILE') return 1;
    if (c.includes('PICK')) return 2;
    return 10;
  };

  const lineGroups = useMemo(() => {
    const byLine = new Map<string, WorkOrderTask[]>();
    const ungrouped: WorkOrderTask[] = [];
    for (const t of tasks) {
      if (t.sales_order_line_id) {
        const arr = byLine.get(t.sales_order_line_id) ?? [];
        arr.push(t);
        byLine.set(t.sales_order_line_id, arr);
      } else {
        ungrouped.push(t);
      }
    }
    const sortTasks = (arr: WorkOrderTask[]) =>
      [...arr].sort((a, b) => {
        const r = stationRank(a.work_center?.code) - stationRank(b.work_center?.code);
        return r !== 0 ? r : (a.work_center?.name ?? '').localeCompare(b.work_center?.name ?? '');
      });

    const groups: { lineId: string | null; label: string; product: LineProductInfo | null; tasks: WorkOrderTask[] }[] = [];
    let lineIdx = 0;
    for (const [lineId, lineTasks] of byLine.entries()) {
      lineIdx++;
      const prod = lineProductMap.get(lineId) ?? null;
      const label = `Line ${lineIdx}`;
      groups.push({ lineId, label, product: prod, tasks: sortTasks(lineTasks) });
    }
    if (ungrouped.length > 0) {
      groups.push({ lineId: null, label: 'Unassigned', product: null, tasks: sortTasks(ungrouped) });
    }
    return groups;
  }, [tasks, lineProductMap]);

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

  const handleAssignByWorkstation = useCallback(async (workCenterId: string, userId: string) => {
    const displayName = operators.find(o => o.user_id === userId)?.display_name ?? null;
    if (!displayName) return;
    await supabase
      .from('WorkOrderTasks')
      .update({
        assigned_to_user_id: userId,
        assigned_to: displayName,
        updated_at: new Date().toISOString(),
      })
      .eq('manufacturing_order_id', moId)
      .eq('work_center_id', workCenterId)
      .eq('deleted', false);
    await refetchTasks();
    addNotification({ type: 'success', title: 'Assigned', message: `Assigned ${displayName} to workstation.` });
  }, [operators, moId, refetchTasks, addNotification]);

  const handleGenerate = async (regenerate = false) => {
    if (!canGenerateByStatus) {
      addNotification({
        type: 'warning',
        title: 'Status Required',
        message: 'Work Orders can only be generated when MO is Material Ready, Planned, or In Production.',
      });
      return;
    }
    if (regenerate) {
      const confirmed = await showConfirm({
        title: 'Regenerate Work Orders',
        message: 'This will delete existing work orders and regenerate them. Continue?',
        confirmText: 'Regenerate',
        cancelText: 'Cancel',
        variant: 'warning',
      });
      if (!confirmed) return;
    }
    setGenerating(true);
    try {
      await generateWorkOrders(regenerate);
    } catch (e) {
      addNotification({
        type: 'error',
        title: 'Work Orders',
        message: e instanceof Error ? e.message : 'Error generating work orders',
      });
    } finally {
      setGenerating(false);
    }
  };

  const handleSaveSchedule = useCallback(async (updates: { id: string; planned_start_at: string }[]) => {
    try {
      if (materialsIncomplete) {
        addNotification({
          type: 'warning',
          title: 'Material Ready Required',
          message: 'Complete material readiness before setting calendar dates.',
        });
        return;
      }
      if (!allOperatorsAssigned) {
        addNotification({
          type: 'warning',
          title: 'Operator Assignment Required',
          message: 'Assign all workstation operators before setting calendar dates.',
        });
        return;
      }
      const today = (() => {
        const d = new Date();
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
      })();
      for (const u of updates) {
        const safeDate = clampDateToToday(u.planned_start_at, today);
        await supabase
          .from('WorkOrderTasks')
          .update({ planned_start_at: safeDate, updated_at: new Date().toISOString() })
          .eq('id', u.id);
      }
      await refetchTasks();
      addNotification({ type: 'success', title: 'Schedule Saved', message: 'Planned dates updated.' });
    } catch {
      addNotification({ type: 'error', title: 'Error', message: 'Could not save schedule.' });
    }
  }, [refetchTasks, addNotification, materialsIncomplete, allOperatorsAssigned]);

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
          <div className="mb-4 flex items-center gap-2 px-3 py-1.5 rounded-md bg-amber-50 border border-amber-100 w-fit mx-auto">
            <span className="inline-block w-1.5 h-1.5 rounded-full bg-amber-400 flex-shrink-0" />
            <span className="text-xs text-amber-700">
              Material shortage on some lines — <button type="button" onClick={() => router.navigate(`/inventory/material-demand?mo_id=${moId}`)} className="underline font-medium">open Material Demand</button> to complete pending lines.
            </span>
          </div>
        )}
        <Zap className="h-10 w-10 text-gray-300 mx-auto mb-3" />
        <p className="text-sm text-gray-500 mb-2">No work orders generated yet.</p>
        <p className="text-xs text-gray-400 mb-4">Work orders are auto-generated when a line is confirmed in the Lines tab.</p>
        <button type="button" onClick={() => handleGenerate()} disabled={generating || !canGenerateByStatus} className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:opacity-90 disabled:opacity-60">
          {generating ? <Loader2 className="h-4 w-4 animate-spin" /> : <Zap className="h-4 w-4" />}
          Generate All Work Orders
        </button>
      </div>
    );
  }

  const globalTotalLines = tasks.reduce((s, t) => s + t.lines.length, 0);
  const globalCompletedLines = tasks.reduce((s, t) => s + t.lines.filter(l => l.completed).length, 0);
  const globalPct = globalTotalLines > 0 ? Math.round((globalCompletedLines / globalTotalLines) * 100) : 0;
  const woNumber = moNumber.replace(/^MO-/, 'WO-');

  const globalEarliestStart = tasks.reduce<string | null>((acc, t) => {
    if (!t.planned_start_at) return acc;
    return !acc || t.planned_start_at < acc ? t.planned_start_at : acc;
  }, null);

  const workstationAssignments = (() => {
    const byCenter = new Map<string, { workCenterId: string; name: string; code: string; taskCount: number; value: string }>();
    for (const t of tasks) {
      const wcId = t.work_center_id;
      if (!wcId) continue;
      const current = byCenter.get(wcId);
      const assigned = t.assigned_to_user_id ?? '__unassigned__';
      if (!current) {
        byCenter.set(wcId, {
          workCenterId: wcId,
          name: t.work_center?.name ?? 'Station',
          code: t.work_center?.code ?? '',
          taskCount: 1,
          value: assigned,
        });
      } else {
        current.taskCount += 1;
        if (current.value !== assigned) current.value = '__mixed__';
      }
    }
    return [...byCenter.values()].sort((a, b) => stationRank(a.code) - stationRank(b.code));
  })();

  const woLineCount = lineGroups.filter(g => g.lineId).length;

  return (
    <div className="space-y-4">
      {/* Summary Header */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
        {/* Top bar: WO title + status + link */}
        <div className="flex items-center justify-between px-5 py-3 border-b border-gray-100">
          <div className="flex items-center gap-3">
            <h2 className="text-base font-semibold text-gray-900">{woNumber}</h2>
            <StatusBadge status={moStatus ?? 'draft'} type="manufacturing" size="sm" />
            <span className="hidden sm:inline text-sm text-gray-400">·</span>
            <span className="hidden sm:inline text-sm text-gray-500 truncate max-w-[260px]">{productName}</span>
          </div>
          <button
            type="button"
            onClick={() => router.navigate(`/manufacturing/work-orders/${moId}`)}
            className="inline-flex items-center gap-1.5 text-xs text-primary hover:underline flex-shrink-0"
          >
            Open in Work Orders <ArrowUpRight className="w-3 h-3" />
          </button>
        </div>

        {/* Reference row */}
        <div className="px-5 py-3 border-b border-gray-50 flex flex-wrap items-center gap-x-6 gap-y-1 text-xs">
          <span className="text-gray-400">MO</span>
          <span className="font-medium text-gray-700 -ml-4">{moNumber}</span>
          <span className="text-gray-300">|</span>
          <span className="text-gray-400">SO</span>
          <span className="font-medium text-gray-700 -ml-4">{salesOrderNo || '—'}</span>
          <span className="text-gray-300">|</span>
          <span className="text-gray-400">Customer</span>
          <span className="font-medium text-gray-700 -ml-4">{customerName || '—'}</span>
          <span className="text-gray-300">|</span>
          <span className="text-gray-400">Dealer</span>
          <span className="font-medium text-gray-700 -ml-4">{dealerName || '—'}</span>
          <span className="text-gray-300">|</span>
          <span className="text-gray-400">Lines</span>
          <span className="font-medium text-gray-700 -ml-4">{woLineCount}</span>
          <span className="text-gray-300">|</span>
          <span className="text-gray-400">Start</span>
          <span className="font-medium text-gray-700 -ml-4">{globalEarliestStart ? formatShortDate(globalEarliestStart) : '—'}</span>
          <button
            type="button"
            title="Schedule all lines"
            onClick={() => {
              if (!canOpenSchedule) {
                addNotification({
                  type: 'warning',
                  title: 'Schedule Locked',
                  message: materialsIncomplete
                    ? 'Material Ready is required before setting calendar.'
                    : 'Assign all operators before setting calendar.',
                });
                return;
              }
              setSchedulePopup({ label: 'All Lines', tasks, isGlobal: true });
            }}
            className={`p-0.5 rounded -ml-3 ${canOpenSchedule ? 'hover:bg-gray-100 text-gray-400 hover:text-primary' : 'text-gray-300 cursor-not-allowed'}`}
          >
            <CalendarDays className="w-3.5 h-3.5" />
          </button>
        </div>

        {/* Progress bar (inline) */}
        <div className="px-5 py-2.5 flex items-center gap-3">
          <span className="text-[10px] text-gray-400 uppercase tracking-wide flex-shrink-0">Progress</span>
          <div className="flex-1 h-1.5 bg-gray-100 rounded-full overflow-hidden">
            <div
              className={`h-full rounded-full transition-all ${globalPct === 100 ? 'bg-green-500' : globalPct > 0 ? 'bg-blue-500' : 'bg-gray-300'}`}
              style={{ width: `${globalPct}%` }}
            />
          </div>
          <span className="text-[11px] font-medium text-gray-500 flex-shrink-0 tabular-nums">{globalCompletedLines}/{globalTotalLines} · {globalPct}%</span>
        </div>

        {/* Operator assignment (collapsible row) */}
        {operators.length > 0 && workstationAssignments.length > 0 && (
          <div className="px-5 py-2.5 border-t border-gray-50 flex flex-wrap items-center gap-x-4 gap-y-2">
            <span className="text-[10px] text-gray-400 uppercase tracking-wide flex-shrink-0 mr-1">Operators</span>
            {workstationAssignments.map((ws) => (
              <div key={ws.workCenterId} className="inline-flex items-center gap-1.5">
                <span className="text-[11px] text-gray-500 font-medium">{ws.name}</span>
                <select
                  value={ws.value}
                  onChange={e => {
                    if (e.target.value === '__mixed__' || e.target.value === '__unassigned__') return;
                    void handleAssignByWorkstation(ws.workCenterId, e.target.value);
                  }}
                  className="text-[11px] border border-gray-200 rounded px-1.5 py-0.5 bg-white text-gray-600 focus:ring-1 focus:ring-primary focus:border-primary min-w-[120px]"
                >
                  <option value="__unassigned__" disabled>—</option>
                  <option value="__mixed__" disabled>Mixed</option>
                  {operators.map(op => (
                    <option key={op.user_id} value={op.user_id}>{op.display_name}</option>
                  ))}
                </select>
              </div>
            ))}
          </div>
        )}

        {materialsIncomplete && (
          <div className="px-5 py-2 border-t border-amber-100 bg-amber-50 flex items-center gap-2">
            <span className="inline-block w-1.5 h-1.5 rounded-full bg-amber-400 flex-shrink-0" />
            <span className="text-xs text-amber-700">
              Material shortage — only ready lines can be advanced.
              <button type="button" onClick={() => router.navigate(`/inventory/material-demand?mo_id=${moId}`)} className="underline font-medium ml-1">Material Demand</button>
            </span>
          </div>
        )}
        {!materialsIncomplete && !allOperatorsAssigned && (
          <div className="px-5 py-2 border-t border-blue-100 bg-blue-50 flex items-center gap-2">
            <span className="inline-block w-1.5 h-1.5 rounded-full bg-blue-400 flex-shrink-0" />
            <span className="text-xs text-blue-700">
              Assign all workstation operators to unlock calendar scheduling.
            </span>
          </div>
        )}
      </div>

      {lineGroups.map((group) => {
        const totalLines = group.tasks.reduce((s, t) => s + t.lines.length, 0);
        const completedLines = group.tasks.reduce((s, t) => s + t.lines.filter(l => l.completed).length, 0);
        const allCompleted = group.tasks.length > 0 && group.tasks.every(t => t.status === 'completed');
        const anyInProgress = group.tasks.some(t => t.status === 'in_progress');
        const groupStatus = allCompleted ? 'completed' : anyInProgress ? 'in_progress' : 'pending';
        const ptLabels: Record<string, string> = {
          roller: 'Roller Shade', roller_shade: 'Roller Shade',
          drapery: 'Drapery', dual: 'Dual Shade', dual_shade: 'Dual Shade',
          triple: 'Triple Shade', triple_shade: 'Triple Shade',
          zebra: 'Zebra Shade', zebra_shade: 'Zebra Shade',
        };
        const ptRaw = (group.product?.product_type || '').toLowerCase();
        const ptLabel = ptLabels[ptRaw] || (ptRaw ? ptRaw.charAt(0).toUpperCase() + ptRaw.slice(1) : '');
        const fabricName = group.product?.description || group.product?.catalogName || group.product?.variant_name || 'Product';

        const groupKey = group.lineId ?? 'ungrouped';
        const isExpanded = expandedGroups.has(groupKey);

        const earliestStart = group.tasks.reduce<string | null>((acc, t) => {
          if (!t.planned_start_at) return acc;
          return !acc || t.planned_start_at < acc ? t.planned_start_at : acc;
        }, null);

        return (
          <div key={groupKey} className="rounded-xl border border-gray-200 bg-white overflow-hidden">
            <div
              className="w-full flex items-center justify-between px-5 py-3 bg-gradient-to-r from-gray-50 to-white border-b border-gray-200 hover:from-gray-100 transition-colors cursor-pointer text-left"
              onClick={() => toggleGroup(groupKey)}
            >
              <div className="flex items-center gap-3">
                {isExpanded
                  ? <ChevronDown className="w-4 h-4 text-gray-500 flex-shrink-0" />
                  : <ChevronRight className="w-4 h-4 text-gray-500 flex-shrink-0" />}
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-bold text-gray-900 text-sm tracking-wide">{group.label}</span>
                    <StatusBadge status={groupStatus} type="workOrder" size="sm" />
                  </div>
                  {group.product && (
                    <div className="text-xs text-gray-500 mt-0.5">
                      {ptLabel}{ptLabel && ' — '}{fabricName}
                      {group.product.manufacturer && <span className="text-gray-400"> | {group.product.manufacturer}</span>}
                      {group.product.hardware_color && <span className="text-gray-400"> · {group.product.hardware_color}</span>}
                    </div>
                  )}
                </div>
              </div>
              <div className="flex items-center gap-3 text-xs text-gray-500">
                {earliestStart && (
                  <span className="inline-flex items-center gap-1 text-[11px] text-gray-500">
                    <Clock className="w-3 h-3" />{formatShortDate(earliestStart)}
                  </span>
                )}
                <button
                  type="button"
                  title="Schedule line"
                  onClick={e => {
                    e.stopPropagation();
                    if (!canOpenSchedule) {
                      addNotification({
                        type: 'warning',
                        title: 'Schedule Locked',
                        message: materialsIncomplete
                          ? 'Material Ready is required before setting calendar.'
                          : 'Assign all operators before setting calendar.',
                      });
                      return;
                    }
                    setSchedulePopup({ label: group.label, tasks: group.tasks, isGlobal: false });
                  }}
                  className={`p-1 rounded ${canOpenSchedule ? 'hover:bg-gray-200 text-gray-400 hover:text-primary' : 'text-gray-300 cursor-not-allowed'}`}
                >
                  <CalendarDays className="w-3.5 h-3.5" />
                </button>
                <span className="text-gray-300">|</span>
                <span>{group.tasks.length} stations</span>
                <span>·</span>
                <span>{completedLines}/{totalLines} components</span>
                <div className="w-16 h-1.5 bg-gray-200 rounded-full overflow-hidden">
                  <div className="h-full bg-green-500 rounded-full transition-all" style={{ width: `${totalLines > 0 ? Math.round((completedLines / totalLines) * 100) : 0}%` }} />
                </div>
              </div>
            </div>
            {isExpanded && (
              <div className="divide-y divide-gray-200">
                {group.tasks.map((task) => (
                  <StationCard
                    key={task.id}
                    task={task}
                    moMeta={{ moNumber, customerName, productName, salesOrderNo }}
                    siblingTasks={group.tasks}
                  />
                ))}
              </div>
            )}
          </div>
        );
      })}

      <ConfirmDialog
        isOpen={dialogState.isOpen}
        onClose={closeDialog}
        onConfirm={handleConfirm}
        title={dialogState.title}
        message={dialogState.message}
        confirmText={dialogState.confirmText}
        cancelText={dialogState.cancelText}
        variant={dialogState.variant}
        isLoading={dialogState.isLoading}
      />

      {schedulePopup && (
        <SchedulePopup
          label={schedulePopup.label}
          tasks={schedulePopup.tasks}
          isGlobal={schedulePopup.isGlobal}
          onSave={handleSaveSchedule}
          onClose={() => setSchedulePopup(null)}
        />
      )}
    </div>
  );
}
