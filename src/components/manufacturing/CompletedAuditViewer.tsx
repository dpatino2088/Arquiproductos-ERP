import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import AssemblyDetail from './assembly/AssemblyDetail';
import PanelCutDetail from './PanelCutDetail';
import StatusBadge from '../shared/StatusBadge';
import {
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  Loader2,
  Scissors,
  User,
} from 'lucide-react';

interface AuditLine {
  id: string;
  sku: string | null;
  item_name: string | null;
  component_role: string | null;
  qty: number;
  uom: string;
  cut_length_mm: number | null;
  cut_width_mm: number | null;
  completed: boolean;
  bom_instance_line_id: string | null;
  catalog_item_id: string | null;
  product_type: string | null;
  product_width_m: number | null;
  product_height_m: number | null;
  roll_width_m: number | null;
}

interface AuditTask {
  id: string;
  status: string;
  assigned_to: string | null;
  completed_at: string | null;
  started_at: string | null;
  station_code: string;
  station_name: string;
  line_label: string;
  line_area: string | null;
  line_position: string | null;
  lines: AuditLine[];
}

interface CompletedAuditViewerProps {
  moId: string;
  moNumber: string;
  productName: string;
}

const STATION_ORDER = ['CUT-ROLL', 'CUT-PROFILE', 'PICK', 'ASSEMBLY'];

export default function CompletedAuditViewer({
  moId,
  moNumber,
  productName,
}: CompletedAuditViewerProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const [stationFilter, setStationFilter] = useState<string>('all');
  const [expandedTasks, setExpandedTasks] = useState<Set<string>>(new Set());
  const [fabricLineId, setFabricLineId] = useState<string | null>(null);

  const { data: tasks = [], isLoading } = useQuery({
    queryKey: ['workstation-audit-detail', activeOrganizationId, moId],
    enabled: !!activeOrganizationId && !!moId,
    queryFn: async (): Promise<AuditTask[]> => {
      const { data: taskData, error } = await supabase
        .from('WorkOrderTasks')
        .select(`
          id, status, assigned_to, completed_at, started_at, sales_order_line_id, sequence,
          WorkCenters:work_center_id (code, name)
        `)
        .eq('manufacturing_order_id', moId)
        .eq('organization_id', activeOrganizationId!)
        .eq('deleted', false)
        .eq('status', 'completed')
        .order('sequence');
      if (error) throw new Error(error.message);
      if (!taskData?.length) return [];

      const solIds = [...new Set(taskData.map((t: any) => t.sales_order_line_id).filter(Boolean))] as string[];
      const solMap: Record<string, { label: string; area: string | null; position: string | null }> = {};
      if (solIds.length > 0) {
        const { data: solRows } = await supabase
          .from('SaleOrderLines')
          .select('id, description, variant_name, collection_name, product_type, area, position')
          .in('id', solIds);
        for (const s of solRows ?? []) {
          solMap[s.id] = {
            label: s.variant_name || s.description || s.collection_name || s.product_type || 'Line',
            area: s.area ?? null,
            position: s.position ?? null,
          };
        }
      }

      const taskIds = taskData.map((t: any) => t.id as string);
      const { data: lineData, error: lineErr } = await supabase
        .from('WorkOrderTaskLines')
        .select('id, task_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm, completed, bom_instance_line_id, catalog_item_id')
        .in('task_id', taskIds)
        .order('created_at');
      if (lineErr) throw new Error(lineErr.message);

      // Enrich fabric lines with product dims / roll width (same pattern as Workstation).
      const fabricLines = (lineData ?? []).filter(
        (l: any) => (l.component_role === 'fabric' || l.component_role === 'tape') && l.bom_instance_line_id,
      );
      const bilMetaMap: Record<string, { product_type: string | null; width_m: number | null; height_m: number | null }> = {};
      const catDimMap: Record<string, number | null> = {};
      if (fabricLines.length > 0) {
        const bilIds = [...new Set(fabricLines.map((l: any) => l.bom_instance_line_id).filter(Boolean))] as string[];
        if (bilIds.length > 0) {
          const { data: bilRows } = await supabase.from('BOMInstanceLines').select('id, bom_instance_id').in('id', bilIds);
          const biMap: Record<string, string> = {};
          (bilRows ?? []).forEach((r: any) => { if (r.bom_instance_id) biMap[r.id] = r.bom_instance_id; });
          const biIds = [...new Set(Object.values(biMap))];
          const { data: biRows } = biIds.length
            ? await supabase.from('BOMInstances').select('id, sales_order_line_id').in('id', biIds)
            : { data: [] as any[] };
          const biSolMap: Record<string, string> = {};
          (biRows ?? []).forEach((r: any) => { if (r.sales_order_line_id) biSolMap[r.id] = r.sales_order_line_id; });
          const enrichSolIds = [...new Set(Object.values(biSolMap))];
          const { data: solDimRows } = enrichSolIds.length
            ? await supabase.from('SaleOrderLines').select('id, product_type, width_m, height_m').in('id', enrichSolIds)
            : { data: [] as any[] };
          const solDimMap: Record<string, any> = {};
          (solDimRows ?? []).forEach((r: any) => { solDimMap[r.id] = r; });
          bilIds.forEach((bilId) => {
            const biId = biMap[bilId];
            const solId = biId ? biSolMap[biId] : null;
            const sol = solId ? solDimMap[solId] : null;
            bilMetaMap[bilId] = {
              product_type: sol?.product_type ?? null,
              width_m: sol?.width_m != null ? Number(sol.width_m) : null,
              height_m: sol?.height_m != null ? Number(sol.height_m) : null,
            };
          });
        }
        const catIds = [...new Set(fabricLines.map((l: any) => l.catalog_item_id).filter(Boolean))] as string[];
        if (catIds.length > 0) {
          const { data: catRows } = await supabase.from('CatalogItems').select('id, roll_width_m').in('id', catIds);
          (catRows ?? []).forEach((r: any) => {
            catDimMap[r.id] = r.roll_width_m != null ? Number(r.roll_width_m) : null;
          });
        }
      }

      const linesByTask: Record<string, AuditLine[]> = {};
      for (const l of lineData ?? []) {
        if (!linesByTask[l.task_id]) linesByTask[l.task_id] = [];
        const meta = l.bom_instance_line_id ? bilMetaMap[l.bom_instance_line_id] : null;
        linesByTask[l.task_id].push({
          id: l.id,
          sku: l.sku,
          item_name: l.item_name,
          component_role: l.component_role,
          qty: Number(l.qty),
          uom: l.uom,
          cut_length_mm: l.cut_length_mm != null ? Number(l.cut_length_mm) : null,
          cut_width_mm: l.cut_width_mm != null ? Number(l.cut_width_mm) : null,
          completed: !!l.completed,
          bom_instance_line_id: l.bom_instance_line_id,
          catalog_item_id: l.catalog_item_id,
          product_type: meta?.product_type ?? null,
          product_width_m: meta?.width_m ?? null,
          product_height_m: meta?.height_m ?? null,
          roll_width_m: l.catalog_item_id ? (catDimMap[l.catalog_item_id] ?? null) : null,
        });
      }

      return taskData.map((t: any) => {
        const wc = t.WorkCenters;
        const sol = t.sales_order_line_id ? solMap[t.sales_order_line_id] : null;
        return {
          id: t.id,
          status: t.status,
          assigned_to: t.assigned_to,
          completed_at: t.completed_at,
          started_at: t.started_at,
          station_code: wc?.code ?? '—',
          station_name: wc?.name ?? wc?.code ?? 'Station',
          line_label: sol?.label ?? productName,
          line_area: sol?.area ?? null,
          line_position: sol?.position ?? null,
          lines: linesByTask[t.id] ?? [],
        } satisfies AuditTask;
      });
    },
  });

  const stations = useMemo(() => {
    const map = new Map<string, { code: string; name: string; count: number }>();
    for (const t of tasks) {
      const cur = map.get(t.station_code) ?? { code: t.station_code, name: t.station_name, count: 0 };
      cur.count += 1;
      map.set(t.station_code, cur);
    }
    return [...map.values()].sort(
      (a, b) => STATION_ORDER.indexOf(a.code) - STATION_ORDER.indexOf(b.code),
    );
  }, [tasks]);

  const filteredTasks = useMemo(
    () => (stationFilter === 'all' ? tasks : tasks.filter((t) => t.station_code === stationFilter)),
    [tasks, stationFilter],
  );

  const tasksByStation = useMemo(() => {
    const map = new Map<string, AuditTask[]>();
    for (const t of filteredTasks) {
      const list = map.get(t.station_code) ?? [];
      list.push(t);
      map.set(t.station_code, list);
    }
    return [...map.entries()].sort(
      (a, b) => STATION_ORDER.indexOf(a[0]) - STATION_ORDER.indexOf(b[0]),
    );
  }, [filteredTasks]);

  const toggleTask = (id: string) => {
    setExpandedTasks((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-8">
        <Loader2 className="h-5 w-5 animate-spin text-gray-400" />
      </div>
    );
  }

  if (tasks.length === 0) {
    return <p className="text-sm text-gray-500 px-1 py-2">No completed station history for this MO.</p>;
  }

  return (
    <div className="space-y-3" onClick={(e) => e.stopPropagation()}>
      <div className="flex flex-wrap items-center gap-2">
        <button
          type="button"
          onClick={() => setStationFilter('all')}
          className={`text-xs px-2.5 py-1 rounded-md border transition-colors ${
            stationFilter === 'all'
              ? 'bg-gray-800 text-white border-gray-800'
              : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
          }`}
        >
          All stations · {tasks.length}
        </button>
        {stations.map((st) => (
          <button
            key={st.code}
            type="button"
            onClick={() => setStationFilter(st.code)}
            className={`inline-flex items-center gap-1.5 text-xs px-2.5 py-1 rounded-md border transition-colors ${
              stationFilter === st.code
                ? 'bg-green-700 text-white border-green-700'
                : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
            }`}
          >
            <CheckCircle2 className="h-3 w-3" />
            {st.name}
            <span className={stationFilter === st.code ? 'text-green-100' : 'text-gray-400'}>· {st.count}</span>
          </button>
        ))}
      </div>

      <div className="space-y-3">
        {tasksByStation.map(([code, stationTasks]) => {
          const stationName = stationTasks[0]?.station_name ?? code;
          const isAssembly = code === 'ASSEMBLY';
          return (
            <div key={code} className="rounded-lg border border-gray-200 bg-white overflow-hidden">
              <div className="px-3 py-2 bg-gray-50 border-b border-gray-100 flex items-center justify-between">
                <span className="text-xs font-semibold text-gray-800">{stationName}</span>
                <span className="text-[11px] text-gray-400">{stationTasks.length} task(s)</span>
              </div>
              <div className="divide-y divide-gray-100">
                {stationTasks.map((task) => {
                  const open = expandedTasks.has(task.id);
                  const partsDone = task.lines.filter((l) => l.completed).length;
                  return (
                    <div key={task.id}>
                      <button
                        type="button"
                        onClick={() => toggleTask(task.id)}
                        className="w-full flex items-center justify-between gap-3 px-3 py-2.5 hover:bg-gray-50/80 text-left"
                      >
                        <div className="flex items-center gap-2 min-w-0">
                          {open ? <ChevronDown className="h-3.5 w-3.5 text-gray-400" /> : <ChevronRight className="h-3.5 w-3.5 text-gray-400" />}
                          {(task.line_position || task.line_area) && (
                            <span className="text-[11px] px-1.5 py-0.5 rounded bg-indigo-50 text-indigo-700 border border-indigo-100">
                              {[task.line_position, task.line_area].filter(Boolean).join(' · ')}
                            </span>
                          )}
                          <span className="text-xs text-gray-800 truncate">{task.line_label}</span>
                          <StatusBadge status={task.status} type="manufacturing" size="sm" />
                          {task.assigned_to && (
                            <span className="inline-flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded bg-blue-50 text-blue-700 border border-blue-100">
                              <User className="w-3 h-3" /> {task.assigned_to}
                            </span>
                          )}
                        </div>
                        <div className="flex items-center gap-3 text-[11px] text-gray-400 flex-shrink-0">
                          <span>{partsDone}/{task.lines.length} parts</span>
                          {task.completed_at && (
                            <span>{new Date(task.completed_at).toLocaleString()}</span>
                          )}
                        </div>
                      </button>

                      {open && isAssembly && (
                        <div className="p-3 bg-gray-50/50 border-t border-gray-100">
                          <AssemblyDetail
                            manufacturingOrderId={moId}
                            moNumber={moNumber}
                            productName={productName}
                            lines={task.lines}
                            onToggleLine={() => {}}
                            readOnly
                          />
                        </div>
                      )}

                      {open && !isAssembly && (
                        <div className="border-t border-gray-100 overflow-x-auto">
                          <table className="w-full text-sm">
                            <thead>
                              <tr className="text-xs text-gray-500 border-b border-gray-100 bg-gray-50/60">
                                <th className="text-left px-3 py-2 w-8" />
                                <th className="text-left px-3 py-2">SKU</th>
                                <th className="text-left px-3 py-2">Description</th>
                                <th className="text-left px-3 py-2">Role</th>
                                <th className="text-right px-3 py-2">Qty</th>
                                <th className="text-left px-3 py-2">UOM</th>
                                <th className="text-right px-3 py-2">Cut X</th>
                                <th className="text-right px-3 py-2">Cut Y</th>
                              </tr>
                            </thead>
                            <tbody>
                              {task.lines.map((line) => {
                                const isFabric = line.component_role === 'fabric' || line.component_role === 'tape';
                                const hasCut = isFabric && (line.cut_length_mm != null || line.cut_width_mm != null);
                                const detailOpen = fabricLineId === line.id;
                                return (
                                  <tr key={line.id} className="border-t border-gray-50">
                                    <td className="px-3 py-2">
                                      <CheckCircle2 className={`h-3.5 w-3.5 ${line.completed ? 'text-green-500' : 'text-gray-300'}`} />
                                    </td>
                                    <td className="px-3 py-2 font-mono text-xs text-gray-700">{line.sku ?? '—'}</td>
                                    <td className="px-3 py-2 text-xs text-gray-700">
                                      {line.item_name ?? '—'}
                                      {hasCut && (
                                        <button
                                          type="button"
                                          className="flex items-center gap-1 text-[11px] text-blue-600 font-medium mt-0.5 hover:underline"
                                          onClick={() => setFabricLineId(detailOpen ? null : line.id)}
                                        >
                                          <Scissors className="w-3 h-3" />
                                          CUT:{' '}
                                          {line.cut_length_mm != null ? `${Math.round(line.cut_length_mm)} mm` : ''}
                                          {line.cut_length_mm != null && line.cut_width_mm != null ? ' × ' : ''}
                                          {line.cut_width_mm != null ? `${Math.round(line.cut_width_mm)} mm` : ''}
                                          <span className="text-gray-400 font-normal">· view</span>
                                        </button>
                                      )}
                                      {detailOpen && hasCut && (
                                        <div className="mt-2">
                                          <PanelCutDetail
                                            moNumber={moNumber}
                                            sku={line.sku ?? ''}
                                            itemName={line.item_name ?? ''}
                                            productType={line.product_type ?? 'roller'}
                                            productWidthMm={line.product_width_m ? line.product_width_m * 1000 : (line.cut_length_mm ?? 0)}
                                            productHeightMm={line.product_height_m ? line.product_height_m * 1000 : (line.cut_width_mm ?? 0)}
                                            cutWidthMm={line.cut_length_mm ?? 0}
                                            cutHeightMm={line.cut_width_mm ?? 0}
                                            rollWidthMm={(line.roll_width_m ?? 2.8) * 1000}
                                            rule={{
                                              tube_wrap_mm: 0,
                                              bottom_wrap_mm: 0,
                                              safety_margin_mm: 0,
                                              top_hem_mm: 0,
                                              bottom_hem_mm: 0,
                                              side_hem_mm: 0,
                                              panel_multiplier: 1,
                                              fullness_factor: 1,
                                              heatseal_price_per_m: 0,
                                              waste_pct: 0,
                                              bottom_bar_wrap_pct: 0,
                                            }}
                                            onClose={() => setFabricLineId(null)}
                                          />
                                        </div>
                                      )}
                                    </td>
                                    <td className="px-3 py-2 text-xs text-gray-500">{line.component_role ?? '—'}</td>
                                    <td className="px-3 py-2 text-right text-xs">{Number(line.qty).toFixed(line.uom === 'ea' ? 0 : 3)}</td>
                                    <td className="px-3 py-2 text-xs text-gray-500">{line.uom}</td>
                                    <td className="px-3 py-2 text-right text-xs tabular-nums">
                                      {line.cut_length_mm != null ? Math.round(line.cut_length_mm) : '—'}
                                    </td>
                                    <td className="px-3 py-2 text-right text-xs tabular-nums">
                                      {line.cut_width_mm != null ? Math.round(line.cut_width_mm) : '—'}
                                    </td>
                                  </tr>
                                );
                              })}
                            </tbody>
                          </table>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
