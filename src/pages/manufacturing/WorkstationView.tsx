import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useWorkCenters, type WorkCenter } from '../../hooks/useWorkCenters';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuth } from '../../hooks/useAuth';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import StatusBadge from '../../components/shared/StatusBadge';
import PanelCutDetail from '../../components/manufacturing/PanelCutDetail';
import AssemblyDetail from '../../components/manufacturing/assembly/AssemblyDetail';
import { router } from '../../lib/router';
import { advanceMOOnTaskStart, advanceMOOnAllTasksComplete } from '../../lib/moLifecycle';
import {
  Factory,
  ChevronDown,
  ChevronRight,
  Play,
  CheckCircle2,
  Loader2,
  Scissors,
  Box,
  User,
  AlertTriangle,
} from 'lucide-react';

interface FabricRuleInfo {
  product_type_code: string;
  allow_rotation: boolean;
  heatseal_price_per_m: number;
  heatseal_direction: 'horizontal' | 'vertical' | 'none';
  tube_wrap_mm: number;
  bottom_wrap_mm: number;
  safety_margin_mm: number;
  top_hem_cm: number;
  bottom_hem_cm: number;
  side_hem_cm: number;
  fullness_factor: number;
  panel_multiplier: number;
  waste_pct: number;
  bottom_bar_wrap_pct: number;
}

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
  bom_instance_line_id: string | null;
  catalog_item_id: string | null;
  product_type: string | null;
  product_width_m: number | null;
  product_height_m: number | null;
  roll_width_m: number | null;
}

interface TaskWithMO {
  id: string;
  manufacturing_order_id: string;
  sequence: number;
  status: 'pending' | 'in_progress' | 'completed';
  assigned_to: string | null;
  assigned_to_user_id: string | null;
  started_at: string | null;
  completed_at: string | null;
  mo_number: string;
  customer_name: string;
  product_name: string;
  due_date: string | null;
  lines: TaskLine[];
  siblingStatuses?: { code: string; status: string }[];
}

interface WorkstationViewProps {
  workCenterId?: string;
}

export default function WorkstationView({ workCenterId }: WorkstationViewProps) {
  const { centers, loading: centersLoading } = useWorkCenters();
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuth();
  const { role } = useCurrentOrgRole();
  const isOperator = role === 'operator' || role === 'operator_member';
  const [selectedCenter, setSelectedCenter] = useState<string | null>(workCenterId ?? null);
  const [tasks, setTasks] = useState<TaskWithMO[]>([]);
  const [loadingTasks, setLoadingTasks] = useState(false);
  const [expandedTask, setExpandedTask] = useState<string | null>(null);
  const [fabricRules, setFabricRules] = useState<FabricRuleInfo[]>([]);
  const [selectedFabricLineId, setSelectedFabricLineId] = useState<string | null>(null);

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
        .select('id, manufacturing_order_id, sequence, status, assigned_to, assigned_to_user_id, started_at, completed_at')
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
        .select('id, task_id, sku, item_name, component_role, qty, uom, cut_length_mm, cut_width_mm, completed, bom_instance_line_id, catalog_item_id')
        .in('task_id', taskIds)
        .order('created_at');

      if (lErr) throw new Error(lErr.message);

      // Enrich fabric lines with product_type, product dimensions, and roll_width
      const fabricLines = (lineData ?? []).filter(
        (l: any) => (l.component_role === 'fabric' || l.component_role === 'tape') && l.bom_instance_line_id,
      );

      const bilMetaMap: Record<string, { product_type: string | null; width_m: number | null; height_m: number | null }> = {};
      const catDimMap: Record<string, number | null> = {};

      if (fabricLines.length > 0) {
        const bilIds = [...new Set(fabricLines.map((l: any) => l.bom_instance_line_id).filter(Boolean))] as string[];
        if (bilIds.length > 0) {
          const { data: bilRows } = await supabase
            .from('BOMInstanceLines')
            .select('id, bom_instance_id')
            .in('id', bilIds);

          const biMap: Record<string, string> = {};
          (bilRows ?? []).forEach((r: any) => { if (r.bom_instance_id) biMap[r.id] = r.bom_instance_id; });

          const biIds = [...new Set(Object.values(biMap))];
          const { data: biRows } = await supabase
            .from('BOMInstances')
            .select('id, sales_order_line_id')
            .in('id', biIds);

          const biSolMap: Record<string, string> = {};
          (biRows ?? []).forEach((r: any) => { if (r.sales_order_line_id) biSolMap[r.id] = r.sales_order_line_id; });

          const solIds = [...new Set(Object.values(biSolMap))];
          const { data: solRows } = solIds.length > 0
            ? await supabase.from('SaleOrderLines').select('id, product_type, width_m, height_m').in('id', solIds)
            : { data: [] };

          const solMap: Record<string, any> = {};
          (solRows ?? []).forEach((r: any) => { solMap[r.id] = r; });

          bilIds.forEach(bilId => {
            const biId = biMap[bilId];
            const solId = biId ? biSolMap[biId] : null;
            const sol = solId ? solMap[solId] : null;
            bilMetaMap[bilId] = {
              product_type: sol?.product_type ?? null,
              width_m: sol?.width_m != null ? Number(sol.width_m) : null,
              height_m: sol?.height_m != null ? Number(sol.height_m) : null,
            };
          });
        }

        const catIds = [...new Set(fabricLines.map((l: any) => l.catalog_item_id).filter(Boolean))];
        if (catIds.length > 0) {
          const { data: catRows } = await supabase
            .from('CatalogItems')
            .select('id, roll_width_m')
            .in('id', catIds);
          (catRows ?? []).forEach((r: any) => { catDimMap[r.id] = r.roll_width_m != null ? Number(r.roll_width_m) : null; });
        }
      }

      const linesByTask: Record<string, TaskLine[]> = {};
      for (const l of (lineData ?? [])) {
        if (!linesByTask[l.task_id]) linesByTask[l.task_id] = [];
        const meta = l.bom_instance_line_id ? bilMetaMap[l.bom_instance_line_id] : null;
        linesByTask[l.task_id].push({
          ...l,
          product_type: meta?.product_type ?? null,
          product_width_m: meta?.width_m ?? null,
          product_height_m: meta?.height_m ?? null,
          roll_width_m: l.catalog_item_id ? (catDimMap[l.catalog_item_id] ?? null) : null,
        });
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
          assigned_to_user_id: t.assigned_to_user_id ?? null,
          started_at: t.started_at,
          completed_at: t.completed_at,
          mo_number: mo?.manufacturing_order_no ?? '—',
          customer_name: soId ? (customerMap[soId] ?? 'N/A') : 'N/A',
          product_name: mo?.product_name ?? '—',
          due_date: soId ? (dueDateMap[soId] ?? null) : null,
          lines: linesByTask[t.id] ?? [],
        };
      });

      // For ASSEMBLY station, fetch sibling task statuses per MO for readiness
      const isAssemblyCenter = centers.find(c => c.id === selectedCenter)?.code === 'ASSEMBLY';
      if (isAssemblyCenter && moIds.length > 0) {
        const { data: sibData } = await supabase
          .from('WorkOrderTasks')
          .select('id, manufacturing_order_id, status, WorkCenters:work_center_id (code)')
          .in('manufacturing_order_id', moIds)
          .eq('deleted', false)
          .neq('work_center_id', selectedCenter);

        if (sibData) {
          const sibByMO: Record<string, { code: string; status: string }[]> = {};
          for (const s of sibData) {
            const code = (s as any).WorkCenters?.code;
            if (!code) continue;
            if (!sibByMO[s.manufacturing_order_id]) sibByMO[s.manufacturing_order_id] = [];
            sibByMO[s.manufacturing_order_id].push({ code, status: s.status });
          }
          for (const t of result) {
            t.siblingStatuses = sibByMO[t.manufacturing_order_id] ?? [];
          }
        }
      }

      setTasks(result);
    } catch {
      setTasks([]);
    } finally {
      setLoadingTasks(false);
    }
  }, [selectedCenter, activeOrganizationId]);

  useEffect(() => { fetchTasks(); }, [fetchTasks]);

  useEffect(() => {
    if (!activeOrganizationId) return;
    (async () => {
      const [{ data: frData }, { data: ptData }] = await Promise.all([
        supabase
          .from('FabricRules')
          .select('product_type_id, allow_rotation, heatseal_price_per_m, heatseal_direction, tube_wrap_mm, bottom_wrap_mm, safety_margin_mm, top_hem_cm, bottom_hem_cm, side_hem_cm, fullness_factor, panel_multiplier, waste_pct, bottom_bar_wrap_pct')
          .eq('is_active', true),
        supabase.from('ProductTypes').select('id, code'),
      ]);
      if (!frData || !ptData) return;
      const ptMap: Record<string, string> = {};
      ptData.forEach((pt: any) => { ptMap[pt.id] = pt.code; });
      setFabricRules(frData.map((r: any) => ({
        product_type_code: ptMap[r.product_type_id] ?? '',
        allow_rotation: r.allow_rotation ?? true,
        heatseal_price_per_m: Number(r.heatseal_price_per_m ?? 0),
        heatseal_direction: (r.heatseal_direction as FabricRuleInfo['heatseal_direction']) ?? 'none',
        tube_wrap_mm: Number(r.tube_wrap_mm ?? 0),
        bottom_wrap_mm: Number(r.bottom_wrap_mm ?? 0),
        safety_margin_mm: Number(r.safety_margin_mm ?? 0),
        top_hem_cm: Number(r.top_hem_cm ?? 0),
        bottom_hem_cm: Number(r.bottom_hem_cm ?? 0),
        side_hem_cm: Number(r.side_hem_cm ?? 0),
        fullness_factor: Number(r.fullness_factor ?? 1),
        panel_multiplier: Number(r.panel_multiplier ?? 1),
        waste_pct: Number(r.waste_pct ?? 0),
        bottom_bar_wrap_pct: Number(r.bottom_bar_wrap_pct ?? 0),
      })));
    })();
  }, [activeOrganizationId]);

  const fabricRuleMap = useMemo(() => {
    const map: Record<string, FabricRuleInfo> = {};
    fabricRules.forEach(r => { map[r.product_type_code] = r; });
    return map;
  }, [fabricRules]);

  const toggleLine = async (lineId: string, completed: boolean) => {
    const now = new Date().toISOString();
    await supabase
      .from('WorkOrderTaskLines')
      .update({ completed, completed_at: completed ? now : null })
      .eq('id', lineId);

    if (completed) {
      const { data: lineRow } = await supabase
        .from('WorkOrderTaskLines')
        .select('task_id')
        .eq('id', lineId)
        .single();

      if (lineRow) {
        const { data: siblings } = await supabase
          .from('WorkOrderTaskLines')
          .select('id, completed')
          .eq('task_id', lineRow.task_id);

        const allDone = siblings?.every((l: { id: string; completed: boolean }) =>
          l.id === lineId ? true : l.completed,
        );
        if (allDone) {
          const { data: taskRow } = await supabase
            .from('WorkOrderTasks')
            .select('status')
            .eq('id', lineRow.task_id)
            .single();

          if (taskRow?.status === 'in_progress') {
            await completeTask(lineRow.task_id);
            return;
          }
        }
      }
    }

    await fetchTasks();
  };

  const startTask = async (taskId: string) => {
    const now = new Date().toISOString();
    const task = tasks.find((t) => t.id === taskId);

    await supabase
      .from('WorkOrderTasks')
      .update({
        status: 'in_progress',
        started_at: now,
        updated_at: now,
      })
      .eq('id', taskId);

    if (task) {
      await advanceMOOnTaskStart(task.manufacturing_order_id);
    }

    await fetchTasks();
  };

  const completeTask = async (taskId: string) => {
    const now = new Date().toISOString();
    await supabase
      .from('WorkOrderTasks')
      .update({ status: 'completed', completed_at: now, updated_at: now, completed_by_user_id: user?.id ?? null })
      .eq('id', taskId);

    const task = tasks.find((t) => t.id === taskId);
    if (task && activeOrganizationId) {
      const { data: allTasks } = await supabase
        .from('WorkOrderTasks')
        .select('id, status, depends_on_task_ids')
        .eq('manufacturing_order_id', task.manufacturing_order_id)
        .eq('deleted', false);

      if (allTasks) {
        const completedIds = new Set(
          allTasks.filter((t: any) => t.id === taskId || t.status === 'completed').map((t: any) => t.id)
        );

        const toAutoStart = allTasks.filter((t: any) => {
          if (t.id === taskId) return false;
          if (t.status !== 'pending') return false;
          const deps = t.depends_on_task_ids ?? [];
          if (deps.length === 0) return false;
          return deps.every((depId: string) => completedIds.has(depId));
        });

        if (toAutoStart.length > 0) {
          await supabase
            .from('WorkOrderTasks')
            .update({ status: 'in_progress', started_at: now, updated_at: now })
            .in('id', toAutoStart.map((t: any) => t.id));
        }

        const allCompleted = allTasks.every((t: any) =>
          t.id === taskId ? true : t.status === 'completed'
        );
        if (allCompleted) {
          await advanceMOOnAllTasksComplete(task.manufacturing_order_id);
        }
      }
    }

    await fetchTasks();
  };

  const currentCenter = centers.find((c) => c.id === selectedCenter);
  const isAssemblyStation = currentCenter?.code === 'ASSEMBLY';

  const filteredTasks = useMemo(() => {
    if (isOperator && user?.id) {
      return tasks.filter(t => !t.assigned_to_user_id || t.assigned_to_user_id === user.id);
    }
    return tasks;
  }, [tasks, isOperator, user?.id]);

  const pendingCount = filteredTasks.filter((t) => t.status === 'pending').length;
  const inProgressCount = filteredTasks.filter((t) => t.status === 'in_progress').length;

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
          <span>{filteredTasks.length} total</span>
        </div>
      )}

      {loadingTasks ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-6 w-6 animate-spin text-gray-400" />
        </div>
      ) : filteredTasks.length === 0 ? (
        <div className="rounded-lg border border-gray-200 bg-white p-8 text-center">
          <CheckCircle2 className="h-10 w-10 text-green-400 mx-auto mb-3" />
          <p className="text-sm text-gray-500">No pending tasks at this station.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filteredTasks.map((task) => {
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
                    {task.assigned_to && (
                      <span className="inline-flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded bg-blue-50 text-blue-700 border border-blue-100">
                        <User className="w-3 h-3" /> {task.assigned_to}
                      </span>
                    )}
                  </div>

                  <div className="flex items-center gap-3">
                    <span className="text-xs text-gray-500">{task.product_name}</span>
                    {task.due_date && <span className="text-xs text-gray-400">{task.due_date}</span>}
                    <span className="text-xs text-gray-500">{completedCount}/{totalCount}</span>

                    {(() => {
                      const upstreamOk = !isAssemblyStation || !task.siblingStatuses?.length ||
                        task.siblingStatuses.every(s => s.status === 'completed');
                      return (
                        <>
                          {task.status === 'pending' && upstreamOk && (
                            <button type="button" onClick={() => startTask(task.id)} className="inline-flex items-center gap-1 text-xs px-2 py-1 rounded bg-blue-600 text-white hover:bg-blue-700">
                              <Play className="h-3 w-3" /> Start
                            </button>
                          )}
                          {task.status === 'pending' && !upstreamOk && (
                            <span className="inline-flex items-center gap-1 text-[10px] px-2 py-1 rounded bg-gray-100 text-gray-400 border border-gray-200" title="Upstream tasks must be completed first">
                              <AlertTriangle className="h-3 w-3" /> Blocked
                            </span>
                          )}
                          {task.status === 'in_progress' && completedCount === totalCount && totalCount > 0 && upstreamOk && (
                            <button type="button" onClick={() => completeTask(task.id)} className="inline-flex items-center gap-1 text-xs px-2 py-1 rounded bg-green-600 text-white hover:bg-green-700">
                              <CheckCircle2 className="h-3 w-3" /> Complete
                            </button>
                          )}
                        </>
                      );
                    })()}
                  </div>
                </div>

                {isExpanded && isAssemblyStation && (
                  <div className="p-3">
                    <AssemblyDetail
                      manufacturingOrderId={task.manufacturing_order_id}
                      moNumber={task.mo_number}
                      productName={task.product_name}
                      lines={task.lines}
                      onToggleLine={toggleLine}
                      siblingTasks={task.siblingStatuses}
                    />
                  </div>
                )}

                {isExpanded && !isAssemblyStation && (
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
                      {task.lines.map((line) => {
                        const isFabric = line.component_role === 'fabric' || line.component_role === 'tape';
                        const hasCut = isFabric && (line.cut_length_mm != null || line.cut_width_mm != null);
                        const isDetailOpen = selectedFabricLineId === line.id;
                        const rule = isFabric && line.product_type ? fabricRuleMap[line.product_type] : null;

                        return (
                          <React.Fragment key={line.id}>
                            <tr className={`border-t border-gray-50 ${line.completed ? 'bg-green-50/30' : ''} ${hasCut && rule ? 'cursor-pointer hover:bg-blue-50/40' : ''}`}
                              onClick={hasCut && rule ? () => setSelectedFabricLineId(isDetailOpen ? null : line.id) : undefined}
                            >
                              <td className="px-4 py-2">
                                <input
                                  type="checkbox"
                                  checked={line.completed}
                                  onChange={(e) => { e.stopPropagation(); toggleLine(line.id, e.target.checked); }}
                                  className="rounded border-gray-300"
                                />
                              </td>
                              <td className={`px-4 py-2 font-mono ${line.completed ? 'line-through text-gray-400' : 'text-gray-800'}`}>{line.sku ?? '—'}</td>
                              <td className={`px-4 py-2 ${line.completed ? 'line-through text-gray-400' : 'text-gray-700'}`}>
                                {line.item_name ?? '—'}
                                {hasCut && (
                                  <div className="flex items-center gap-1.5 text-[11px] text-blue-600 font-medium mt-0.5">
                                    <Scissors className="w-3 h-3" />
                                    CUT: {line.cut_length_mm != null ? `${Math.round(Number(line.cut_length_mm))} mm` : ''}{line.cut_length_mm != null && line.cut_width_mm != null ? ' × ' : ''}{line.cut_width_mm != null ? `${Math.round(Number(line.cut_width_mm))} mm` : ''}
                                    {rule && <span className="text-gray-400 ml-1">· click for detail</span>}
                                  </div>
                                )}
                              </td>
                              <td className="px-4 py-2">{line.component_role && <span className={`text-xs px-1.5 py-0.5 rounded ${line.component_role === 'fabric' ? 'bg-blue-50 text-blue-700' : line.component_role === 'tape' ? 'bg-purple-50 text-purple-700' : 'bg-gray-100 text-gray-600'}`}>{line.component_role}</span>}</td>
                              <td className="px-4 py-2 text-right text-gray-700">{Number(line.qty).toFixed(line.uom === 'ea' ? 0 : 3)}</td>
                              <td className="px-4 py-2 text-gray-500">{line.uom}</td>
                              <td className="px-4 py-2 text-right text-gray-600">{line.cut_length_mm != null ? Math.round(Number(line.cut_length_mm)) : '—'}</td>
                              <td className="px-4 py-2 text-right text-gray-600">{line.cut_width_mm != null ? Math.round(Number(line.cut_width_mm)) : '—'}</td>
                            </tr>
                            {isDetailOpen && rule && (
                              <tr className="border-t border-blue-100">
                                <td colSpan={8} className="p-3 bg-blue-50/30">
                                  <PanelCutDetail
                                    moNumber={task.mo_number}
                                    sku={line.sku ?? ''}
                                    itemName={line.item_name ?? ''}
                                    productType={line.product_type ?? 'roller'}
                                    productWidthMm={line.product_width_m ? line.product_width_m * 1000 : (line.cut_length_mm ?? 0)}
                                    productHeightMm={line.product_height_m ? line.product_height_m * 1000 : (line.cut_width_mm ?? 0)}
                                    cutWidthMm={line.cut_length_mm ?? 0}
                                    cutHeightMm={line.cut_width_mm ?? 0}
                                    rollWidthMm={(line.roll_width_m ?? 2.8) * 1000}
                                    heatsealDirection={rule.heatseal_direction}
                                    rule={{
                                      tube_wrap_mm: rule.tube_wrap_mm,
                                      bottom_wrap_mm: rule.bottom_wrap_mm,
                                      safety_margin_mm: rule.safety_margin_mm,
                                      top_hem_mm: rule.top_hem_cm * 10,
                                      bottom_hem_mm: rule.bottom_hem_cm * 10,
                                      side_hem_mm: rule.side_hem_cm * 10,
                                      panel_multiplier: rule.panel_multiplier,
                                      fullness_factor: rule.fullness_factor,
                                      heatseal_price_per_m: rule.heatseal_price_per_m,
                                      waste_pct: rule.waste_pct,
                                      bottom_bar_wrap_pct: rule.bottom_bar_wrap_pct,
                                    }}
                                    onClose={() => setSelectedFabricLineId(null)}
                                  />
                                </td>
                              </tr>
                            )}
                          </React.Fragment>
                        );
                      })}
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
