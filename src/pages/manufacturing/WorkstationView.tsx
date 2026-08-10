import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '../../lib/supabase/client';
import { useWorkCenters, type WorkCenter } from '../../hooks/useWorkCenters';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuth } from '../../hooks/useAuth';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useFilteredMfgSubmodules } from './manufacturingSubmodules';
import { useUIStore } from '../../stores/ui-store';
import StatusBadge from '../../components/shared/StatusBadge';
import StatusTabs from '../../components/shared/StatusTabs';
import PanelCutDetail from '../../components/manufacturing/PanelCutDetail';
import AssemblyDetail from '../../components/manufacturing/assembly/AssemblyDetail';
import CompletedAuditViewer from '../../components/manufacturing/CompletedAuditViewer';
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
  RotateCcw,
} from 'lucide-react';

/** Global Completed queue (not a work center) — MOs whose Assembly work is done. */
const COMPLETED_TAB = '__completed__';

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
  /** Original SKU when this BIL was substituted at allocate time */
  substituted_from_sku?: string | null;
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
  planned_start_at: string | null;
  planned_end_at: string | null;
  mo_number: string;
  customer_name: string;
  product_name: string;
  due_date: string | null;
  sol_id: string | null;
  line_label: string;
  line_area: string | null;
  line_position: string | null;
  lines: TaskLine[];
  siblingStatuses?: { code: string; status: string }[];
  station_code?: string | null;
  station_name?: string | null;
}

interface CompletedMoGroup {
  moId: string;
  moNumber: string;
  customerName: string;
  productName: string;
  moStatus: string;
  completedAt: string | null;
  stations: { code: string; name: string; taskCount: number; completedAt: string | null }[];
  assemblyTaskIds: string[];
}

interface WorkstationViewProps {
  workCenterId?: string;
}

function parseIsoDate(value: string): Date {
  return /^\d{4}-\d{2}-\d{2}$/.test(value) ? new Date(`${value}T00:00:00`) : new Date(value);
}

export default function WorkstationView({ workCenterId }: WorkstationViewProps) {
  const { centers, loading: centersLoading } = useWorkCenters();
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuth();
  const { role } = useCurrentOrgRole();
  const isOperator = role === 'operator' || role === 'operator_member';
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const filteredSubmodules = useFilteredMfgSubmodules();
  const [selectedCenter, setSelectedCenter] = useState<string | null>(workCenterId ?? null);
  const [activeTab, setActiveTab] = useState<string>(() => {
    const qp = new URLSearchParams(window.location.search);
    return qp.get('view') === 'completed' ? COMPLETED_TAB : (workCenterId ?? '');
  });
  const isCompletedView = activeTab === COMPLETED_TAB;
  const queryClient = useQueryClient();
  // Cut Optimization reads the same WorkOrderTaskLines; drop its cache so it
  // reflects completions/starts made here (refetchOnMount is disabled globally).
  const syncCutCache = useCallback(() => {
    queryClient.removeQueries({ queryKey: ['cut-pending'] });
    queryClient.invalidateQueries({ queryKey: ['workstation-completed-mos'] });
    queryClient.invalidateQueries({ queryKey: ['workstation-open-counts'] });
    queryClient.invalidateQueries({ queryKey: ['workstation-completed-count'] });
  }, [queryClient]);

  const [expandedTasks, setExpandedTasks] = useState<Set<string>>(new Set());
  const toggleTask = useCallback((taskId: string) => {
    setExpandedTasks((prev) => {
      const next = new Set(prev);
      if (next.has(taskId)) next.delete(taskId); else next.add(taskId);
      return next;
    });
  }, []);
  const [expandedMOs, setExpandedMOs] = useState<Set<string>>(new Set());
  const [fabricRules, setFabricRules] = useState<FabricRuleInfo[]>([]);
  const [selectedFabricLineId, setSelectedFabricLineId] = useState<string | null>(null);
  const [startingMO, setStartingMO] = useState<string | null>(null);
  const [reactivatingMO, setReactivatingMO] = useState<string | null>(null);
  const addNotification = useUIStore((s) => s.addNotification);

  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/manufacturing')) registerSubmodules('Manufacturing', filteredSubmodules);
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/manufacturing')) clearSubmoduleNav();
    };
  }, [registerSubmodules, clearSubmoduleNav, filteredSubmodules]);

  useEffect(() => {
    if (workCenterId) {
      setSelectedCenter(workCenterId);
      setActiveTab(workCenterId);
    }
  }, [workCenterId]);

  useEffect(() => {
    if (centers.length === 0) return;
    if (!selectedCenter) setSelectedCenter(centers[0].id);
    if (!activeTab) {
      const qp = new URLSearchParams(window.location.search);
      setActiveTab(qp.get('view') === 'completed' ? COMPLETED_TAB : (workCenterId || centers[0].id));
    }
  }, [centers, selectedCenter, activeTab, workCenterId]);

  const fetchTasks = useCallback(async (): Promise<TaskWithMO[]> => {
    if (!selectedCenter || !activeOrganizationId) return [];
    const { data: taskData, error: tErr } = await supabase
      .from('WorkOrderTasks')
      .select('id, manufacturing_order_id, sales_order_line_id, sequence, status, assigned_to, assigned_to_user_id, started_at, completed_at, planned_start_at, planned_end_at')
      .eq('work_center_id', selectedCenter)
      .eq('organization_id', activeOrganizationId)
      .eq('deleted', false)
      .in('status', ['pending', 'in_progress'])
      .order('sequence');

    if (tErr) throw new Error(tErr.message);
    if (!taskData || taskData.length === 0) return [];

    {

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

      // Resolve which sales-order line each task belongs to (area / position / variant)
      const taskSolIds = [...new Set(taskData.map((t: any) => t.sales_order_line_id).filter(Boolean))] as string[];
      const solInfoMap: Record<string, { label: string; area: string | null; position: string | null }> = {};
      if (taskSolIds.length > 0) {
        const { data: solInfoRows } = await supabase
          .from('SaleOrderLines')
          .select('id, description, variant_name, collection_name, product_type, area, position')
          .in('id', taskSolIds);
        for (const s of (solInfoRows ?? []) as any[]) {
          const label = s.variant_name || s.description || s.collection_name || s.product_type || 'Line';
          solInfoMap[s.id] = { label, area: s.area ?? null, position: s.position ?? null };
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

      // Material substitutions (allocate-time Replace) — show original SKU on workstation
      const moIdsForSubs = [...new Set(taskData.map((t: any) => t.manufacturing_order_id).filter(Boolean))] as string[];
      const subByBil = new Map<string, string>();
      if (moIdsForSubs.length > 0) {
        const { data: subRows } = await supabase
          .from('MOMaterialSubstitutions')
          .select('bom_instance_line_id, original:CatalogItems!original_catalog_item_id(sku)')
          .in('mo_id', moIdsForSubs)
          .order('created_at', { ascending: false });
        for (const row of subRows ?? []) {
          const bilId = (row as any).bom_instance_line_id as string;
          if (!bilId || subByBil.has(bilId)) continue;
          subByBil.set(bilId, (row as any).original?.sku ?? '');
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
          substituted_from_sku: l.bom_instance_line_id ? (subByBil.get(l.bom_instance_line_id) || null) : null,
        });
      }

      const result: TaskWithMO[] = taskData.map((t: any) => {
        const mo = moMap[t.manufacturing_order_id];
        const soId = mo?.sales_order_id;
        const solInfo = t.sales_order_line_id ? solInfoMap[t.sales_order_line_id] : null;
        return {
          id: t.id,
          manufacturing_order_id: t.manufacturing_order_id,
          sequence: t.sequence,
          status: t.status,
          assigned_to: t.assigned_to,
          assigned_to_user_id: t.assigned_to_user_id ?? null,
          started_at: t.started_at,
          completed_at: t.completed_at,
          planned_start_at: t.planned_start_at ?? null,
          planned_end_at: t.planned_end_at ?? null,
          mo_number: mo?.manufacturing_order_no ?? '—',
          customer_name: soId ? (customerMap[soId] ?? 'N/A') : 'N/A',
          product_name: solInfo?.label ?? mo?.product_name ?? '—',
          due_date: soId ? (dueDateMap[soId] ?? null) : null,
          sol_id: t.sales_order_line_id ?? null,
          line_label: solInfo?.label ?? (mo?.product_name ?? '—'),
          line_area: solInfo?.area ?? null,
          line_position: solInfo?.position ?? null,
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

      return result;
    }
  }, [selectedCenter, activeOrganizationId, centers]);

  const tasksQueryKey = useMemo(
    () => ['workstation-tasks', activeOrganizationId, selectedCenter] as const,
    [activeOrganizationId, selectedCenter],
  );

  const {
    data: tasks = [],
    isLoading: loadingTasks,
    refetch: refetchTasksQuery,
  } = useQuery({
    queryKey: tasksQueryKey,
    queryFn: fetchTasks,
    enabled: !!selectedCenter && !!activeOrganizationId && !isCompletedView,
  });

  const refetchTasks = useCallback(async () => {
    await refetchTasksQuery();
  }, [refetchTasksQuery]);

  // MOs that finished Assembly → global Completed audit queue (all stations shown per MO).
  const fetchCompletedMos = useCallback(async (): Promise<CompletedMoGroup[]> => {
    if (!activeOrganizationId) return [];
    const assemblyCenterIds = centers.filter((c) => c.code === 'ASSEMBLY').map((c) => c.id);
    if (assemblyCenterIds.length === 0) return [];

    const { data: assemblyDone, error } = await supabase
      .from('WorkOrderTasks')
      .select('id, manufacturing_order_id, completed_at, work_center_id')
      .eq('organization_id', activeOrganizationId)
      .eq('deleted', false)
      .eq('status', 'completed')
      .in('work_center_id', assemblyCenterIds)
      .order('completed_at', { ascending: false })
      .limit(500);
    if (error) throw new Error(error.message);
    if (!assemblyDone?.length) return [];

    type TaskRow = {
      id: string;
      manufacturing_order_id: string;
      completed_at: string | null;
      work_center_id: string;
      status?: string;
    };
    type MoRow = {
      id: string;
      manufacturing_order_no: string;
      product_name: string | null;
      status: string;
      sales_order_id: string | null;
    };

    const doneRows = assemblyDone as TaskRow[];
    // Only MOs whose Assembly tasks are all completed (none still open at Assembly).
    const moIds = [...new Set(doneRows.map((t) => t.manufacturing_order_id))];
    const { data: openAssembly } = await supabase
      .from('WorkOrderTasks')
      .select('manufacturing_order_id')
      .eq('organization_id', activeOrganizationId)
      .eq('deleted', false)
      .in('work_center_id', assemblyCenterIds)
      .in('manufacturing_order_id', moIds)
      .in('status', ['pending', 'in_progress']);
    const stillOpen = new Set(
      ((openAssembly ?? []) as { manufacturing_order_id: string }[]).map((r) => r.manufacturing_order_id),
    );
    const closedMoIds = moIds.filter((id) => !stillOpen.has(id));
    if (closedMoIds.length === 0) return [];

    const [{ data: moData }, { data: allCompletedTasks }] = await Promise.all([
      supabase
        .from('ManufacturingOrders')
        .select('id, manufacturing_order_no, product_name, status, sales_order_id')
        .in('id', closedMoIds),
      supabase
        .from('WorkOrderTasks')
        .select('id, manufacturing_order_id, completed_at, work_center_id, status')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .eq('status', 'completed')
        .in('manufacturing_order_id', closedMoIds),
    ]);

    const moRows = (moData ?? []) as MoRow[];
    const completedRows = (allCompletedTasks ?? []) as TaskRow[];
    const moMap = new Map(moRows.map((m) => [m.id, m]));
    const soIds = [...new Set(moRows.map((m) => m.sales_order_id).filter(Boolean))] as string[];
    const customerBySo: Record<string, string> = {};
    if (soIds.length > 0) {
      const { data: soData } = await supabase.from('SalesOrders').select('id, customer_id').in('id', soIds);
      const soRows = (soData ?? []) as { id: string; customer_id: string | null }[];
      const custIds = [...new Set(soRows.map((s) => s.customer_id).filter(Boolean))] as string[];
      const custLookup: Record<string, string> = {};
      if (custIds.length > 0) {
        const { data: custData } = await supabase.from('DirectoryCustomers').select('id, customer_name').in('id', custIds);
        for (const c of (custData ?? []) as { id: string; customer_name: string }[]) {
          custLookup[c.id] = c.customer_name;
        }
      }
      for (const so of soRows) {
        if (so.customer_id) customerBySo[so.id] = custLookup[so.customer_id] ?? 'N/A';
      }
    }

    const centerById = new Map(centers.map((c) => [c.id, c]));
    const assemblyIdsByMo = new Map<string, string[]>();
    for (const t of doneRows) {
      if (!closedMoIds.includes(t.manufacturing_order_id)) continue;
      const list = assemblyIdsByMo.get(t.manufacturing_order_id) ?? [];
      list.push(t.id);
      assemblyIdsByMo.set(t.manufacturing_order_id, list);
    }

    const groups: CompletedMoGroup[] = closedMoIds.map((moId) => {
      const mo = moMap.get(moId);
      const moTasks = completedRows.filter((t) => t.manufacturing_order_id === moId);
      const byStation = new Map<string, { code: string; name: string; taskCount: number; completedAt: string | null }>();
      let latest: string | null = null;
      for (const t of moTasks) {
        const wc = centerById.get(t.work_center_id);
        const code = wc?.code ?? '—';
        const name = wc?.name ?? code;
        const cur = byStation.get(code) ?? { code, name, taskCount: 0, completedAt: null };
        cur.taskCount += 1;
        if (t.completed_at && (!cur.completedAt || t.completed_at > cur.completedAt)) {
          cur.completedAt = t.completed_at;
        }
        byStation.set(code, cur);
        if (t.completed_at && (!latest || t.completed_at > latest)) latest = t.completed_at;
      }
      const stationOrder = ['CUT-ROLL', 'CUT-PROFILE', 'PICK', 'ASSEMBLY'];
      const stations = [...byStation.values()].sort(
        (a, b) => stationOrder.indexOf(a.code) - stationOrder.indexOf(b.code),
      );
      return {
        moId,
        moNumber: mo?.manufacturing_order_no ?? '—',
        customerName: mo?.sales_order_id ? (customerBySo[mo.sales_order_id] ?? 'N/A') : 'N/A',
        productName: mo?.product_name ?? '—',
        moStatus: mo?.status ?? '—',
        completedAt: latest,
        stations,
        assemblyTaskIds: assemblyIdsByMo.get(moId) ?? [],
      };
    });

    groups.sort((a, b) => String(b.completedAt ?? '').localeCompare(String(a.completedAt ?? '')));
    return groups;
  }, [activeOrganizationId, centers]);

  const {
    data: completedMos = [],
    isLoading: loadingCompleted,
    refetch: refetchCompleted,
  } = useQuery({
    queryKey: ['workstation-completed-mos', activeOrganizationId],
    queryFn: fetchCompletedMos,
    enabled: !!activeOrganizationId && centers.length > 0 && isCompletedView,
    refetchOnMount: true,
  });

  const { data: completedCount = 0 } = useQuery({
    queryKey: ['workstation-completed-count', activeOrganizationId],
    queryFn: async () => {
      const groups = await fetchCompletedMos();
      return groups.length;
    },
    enabled: !!activeOrganizationId && centers.length > 0,
    refetchOnMount: true,
  });

  const reactivateMO = useCallback(async (group: CompletedMoGroup) => {
    if (group.assemblyTaskIds.length === 0) return;
    setReactivatingMO(group.moId);
    try {
      const now = new Date().toISOString();
      const { error } = await supabase
        .from('WorkOrderTasks')
        .update({
          status: 'in_progress',
          completed_at: null,
          completed_by_user_id: null,
          updated_at: now,
        })
        .in('id', group.assemblyTaskIds);
      if (error) {
        addNotification({ type: 'error', title: 'Reactivate failed', message: error.message });
        return;
      }

      if (group.moStatus === 'quality_check') {
        const { data, error: moErr } = await supabase.rpc('transition_mo_status', {
          p_mo_id: group.moId,
          p_new_status: 'in_production',
          p_user_id: user?.id ?? '00000000-0000-0000-0000-000000000000',
          p_user_name: user?.email ?? 'Workstation reopen',
        });
        if (moErr || !(data as { ok?: boolean } | null)?.ok) {
          addNotification({
            type: 'warning',
            title: 'Tasks reopened',
            message: (data as { error?: string } | null)?.error
              ?? moErr?.message
              ?? 'Assembly reopened; MO status could not be moved back to In Production.',
          });
        }
      }

      addNotification({
        type: 'success',
        title: 'Returned to Active',
        message: `${group.moNumber} Assembly is active again.`,
      });
      await refetchCompleted();
      syncCutCache();
      // Jump to Assembly station so the operator sees it in the active queue.
      const assembly = centers.find((c) => c.code === 'ASSEMBLY');
      if (assembly) {
        setSelectedCenter(assembly.id);
        setActiveTab(assembly.id);
        router.navigate(`/manufacturing/workstations/${assembly.id}`, false);
      }
    } finally {
      setReactivatingMO(null);
    }
  }, [addNotification, centers, refetchCompleted, syncCutCache, user?.email, user?.id]);

  // Optimistically flip line/task state in the cache so the UI responds
  // instantly; the DB write happens in the background and reverts on error.
  const patchLineInCache = useCallback((taskId: string, lineId: string, completed: boolean) => {
    queryClient.setQueryData<TaskWithMO[]>(tasksQueryKey, (old) =>
      old?.map((t) => t.id === taskId
        ? { ...t, lines: t.lines.map((l) => (l.id === lineId ? { ...l, completed } : l)) }
        : t),
    );
  }, [queryClient, tasksQueryKey]);

  const patchAllLinesInCache = useCallback((taskId: string, completed: boolean) => {
    queryClient.setQueryData<TaskWithMO[]>(tasksQueryKey, (old) =>
      old?.map((t) => t.id === taskId
        ? { ...t, lines: t.lines.map((l) => ({ ...l, completed })) }
        : t),
    );
  }, [queryClient, tasksQueryKey]);

  const patchTaskStatusInCache = useCallback((taskId: string, status: TaskWithMO['status']) => {
    queryClient.setQueryData<TaskWithMO[]>(tasksQueryKey, (old) =>
      old?.map((t) => (t.id === taskId ? { ...t, status } : t)),
    );
  }, [queryClient, tasksQueryKey]);

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

  const ensureLineMaterialsReady = useCallback(async (lineId: string): Promise<boolean> => {
    const { data: lineRow } = await supabase
      .from('WorkOrderTaskLines')
      .select('task_id, bom_instance_line_id')
      .eq('id', lineId)
      .single();
    if (!lineRow?.task_id) return false;
    if (!lineRow.bom_instance_line_id) return true;

    const { data: taskRow } = await supabase
      .from('WorkOrderTasks')
      .select('manufacturing_order_id')
      .eq('id', lineRow.task_id)
      .single();
    if (!taskRow?.manufacturing_order_id) return true;

    const { data: bilRow } = await supabase
      .from('BOMInstanceLines')
      .select('bom_instance_id')
      .eq('id', lineRow.bom_instance_line_id)
      .single();
    if (!bilRow?.bom_instance_id) return true;

    const { data: biRow } = await supabase
      .from('BOMInstances')
      .select('manufacturing_order_line_id')
      .eq('id', bilRow.bom_instance_id)
      .single();
    const molId = biRow?.manufacturing_order_line_id as string | null;
    if (!molId) return true;

    const { data: readinessRows, error: readinessErr } = await supabase.rpc('get_mo_line_material_readiness', {
      p_mo_id: taskRow.manufacturing_order_id,
    });
    if (readinessErr) {
      addNotification({ type: 'error', title: 'Materials', message: readinessErr.message || 'Could not validate line material readiness.' });
      return false;
    }

    const row = ((readinessRows as Array<{ manufacturing_order_line_id: string; readiness_status: string }> | null) ?? [])
      .find((r) => r.manufacturing_order_line_id === molId);
    if (row && row.readiness_status === 'incomplete') {
      addNotification({
        type: 'warning',
        title: 'Line Not Ready',
        message: 'This line is incomplete. Cover missing materials before marking progress.',
      });
      return false;
    }
    return true;
  }, [addNotification]);

  const toggleLine = async (lineId: string, completed: boolean) => {
    // Resolve the task/line from local cache — no extra round-trips for guards.
    const task = tasks.find((t) => t.lines.some((l) => l.id === lineId));
    if (!task) return;

    if (completed && task.status !== 'in_progress') {
      addNotification({
        type: 'warning',
        title: 'Task Not Started',
        message: 'Press Play to start this task before checking lines.',
      });
      return;
    }

    // Instant UI feedback.
    patchLineInCache(task.id, lineId, completed);

    if (completed) {
      const lineReady = await ensureLineMaterialsReady(lineId);
      if (!lineReady) {
        patchLineInCache(task.id, lineId, false);
        return;
      }
    }

    const now = new Date().toISOString();
    const { error } = await supabase
      .from('WorkOrderTaskLines')
      .update({ completed, completed_at: completed ? now : null })
      .eq('id', lineId);
    if (error) {
      patchLineInCache(task.id, lineId, !completed); // revert
      addNotification({ type: 'error', title: 'Update Failed', message: error.message });
      return;
    }

    // If this completes the last line, auto-complete the task.
    const willAllBeDone = completed && task.lines.every((l) => (l.id === lineId ? true : l.completed));
    if (willAllBeDone) {
      await completeTask(task.id);
      return;
    }
    syncCutCache();
  };

  // Bulk-toggle every line of a task (the "Select all" header checkbox).
  const toggleAllLines = async (task: TaskWithMO, checked: boolean) => {
    if (task.status !== 'in_progress' || task.lines.length === 0) return;
    patchAllLinesInCache(task.id, checked); // instant UI
    const now = new Date().toISOString();
    const ids = task.lines.map((l) => l.id);
    const { error } = await supabase
      .from('WorkOrderTaskLines')
      .update({ completed: checked, completed_at: checked ? now : null })
      .in('id', ids);
    if (error) {
      patchAllLinesInCache(task.id, !checked); // revert
      addNotification({ type: 'error', title: 'Update Failed', message: error.message });
      return;
    }
    if (checked) {
      // All lines done → complete the task, mirroring single-line behavior.
      await completeTask(task.id);
      return;
    }
    syncCutCache();
  };

  const startTask = async (taskId: string) => {
    const now = new Date().toISOString();
    const task = tasks.find((t) => t.id === taskId);
    // Schedule and operator are optional and never block. An explicitly
    // scheduled future date is the only thing that prevents starting early.
    const plannedStart = task?.planned_start_at ? parseIsoDate(task.planned_start_at) : null;
    if (plannedStart && plannedStart.getTime() > Date.now()) {
      addNotification({
        type: 'warning',
        title: 'Too Early to Start',
        message: 'This task is scheduled for a future date; it can only start on or after that date/time.',
      });
      return;
    }

    patchTaskStatusInCache(taskId, 'in_progress'); // instant UI

    const { error } = await supabase
      .from('WorkOrderTasks')
      .update({
        status: 'in_progress',
        started_at: now,
        planned_start_at: task?.planned_start_at ?? now,
        updated_at: now,
      })
      .eq('id', taskId);
    if (error) {
      patchTaskStatusInCache(taskId, 'pending'); // revert
      addNotification({ type: 'error', title: 'Start Failed', message: error.message });
      return;
    }

    if (task) {
      await advanceMOOnTaskStart(task.manufacturing_order_id, (msg) => {
        // Cut Optimization lists Started cut tasks even if the MO stays at
        // materials_ready; still warn so the floor knows production status
        // did not advance (usually material readiness).
        addNotification({ type: 'warning', title: 'Task Started', message: msg });
      });
    }
    syncCutCache();
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
        .select('id, status, depends_on_task_ids, assigned_to_user_id, planned_start_at')
        .eq('manufacturing_order_id', task.manufacturing_order_id)
        .eq('deleted', false);

      if (allTasks) {
        const completedIds = new Set(
          allTasks.filter((t: any) => t.id === taskId || t.status === 'completed').map((t: any) => t.id)
        );

        const toAutoStart = allTasks.filter((t: any) => {
          if (t.id === taskId) return false;
          if (t.status !== 'pending') return false;
          if (!t.assigned_to_user_id) return false;
          if (!t.planned_start_at || parseIsoDate(t.planned_start_at).getTime() > Date.now()) return false;
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

    await refetchTasks();
    syncCutCache();
  };

  const currentCenter = centers.find((c) => c.id === selectedCenter);
  const isAssemblyStation = currentCenter?.code === 'ASSEMBLY';

  // Open-task counts per station for the tab bar badges.
  const { data: stationOpenCounts = {} } = useQuery({
    queryKey: ['workstation-open-counts', activeOrganizationId],
    queryFn: async (): Promise<Record<string, number>> => {
      if (!activeOrganizationId) return {};
      const { data, error } = await supabase
        .from('WorkOrderTasks')
        .select('work_center_id')
        .eq('organization_id', activeOrganizationId)
        .in('status', ['pending', 'in_progress']);
      if (error) throw error;
      const counts: Record<string, number> = {};
      for (const row of data ?? []) {
        const id = (row as { work_center_id?: string | null }).work_center_id;
        if (!id) continue;
        counts[id] = (counts[id] || 0) + 1;
      }
      return counts;
    },
    enabled: !!activeOrganizationId && centers.length > 0,
    refetchOnMount: true,
  });

  const stationTabs = useMemo(
    () => [
      ...centers.map((wc) => ({
        label: wc.name,
        value: wc.id,
        count: stationOpenCounts[wc.id] || 0,
      })),
      {
        label: 'Completed',
        value: COMPLETED_TAB,
        count: completedCount || 0,
      },
    ],
    [centers, stationOpenCounts, completedCount],
  );

  const handleTabChange = useCallback((value: string) => {
    setActiveTab(value);
    if (value === COMPLETED_TAB) {
      router.navigate('/manufacturing/workstations?view=completed', false);
      return;
    }
    setSelectedCenter(value);
    router.navigate(`/manufacturing/workstations/${value}`, false);
  }, []);

  const filteredTasks = useMemo(() => {
    if (isOperator && user?.id) {
      return tasks.filter((t) => t.assigned_to_user_id === user.id);
    }
    return tasks;
  }, [tasks, isOperator, user?.id]);

  const pendingCount = filteredTasks.filter((t) => t.status === 'pending').length;
  const inProgressCount = filteredTasks.filter((t) => t.status === 'in_progress').length;

  // Returns how many pending tasks in a given MO can be started right now
  // (a future-scheduled date is the only thing that defers a start).
  const countStartableInMO = useCallback((moId: string) => {
    return filteredTasks.filter((t) =>
      t.manufacturing_order_id === moId &&
      t.status === 'pending' &&
      !(t.planned_start_at && parseIsoDate(t.planned_start_at).getTime() > Date.now())
    ).length;
  }, [filteredTasks]);

  // Start every startable task within a single Manufacturing Order.
  const startMOTasks = useCallback(async (moId: string) => {
    const groupStartable = filteredTasks.filter((t) =>
      t.manufacturing_order_id === moId &&
      t.status === 'pending' &&
      !(t.planned_start_at && parseIsoDate(t.planned_start_at).getTime() > Date.now())
    );
    if (groupStartable.length === 0) return;
    setStartingMO(moId);
    try {
      const now = new Date().toISOString();
      const ids = groupStartable.map((t) => t.id);
      const { error } = await supabase
        .from('WorkOrderTasks')
        .update({ status: 'in_progress', started_at: now, updated_at: now })
        .in('id', ids);
      if (error) {
        addNotification({ type: 'error', title: 'Start Failed', message: error.message });
        return;
      }
      await advanceMOOnTaskStart(moId, (msg) => {
        addNotification({ type: 'warning', title: 'Tasks Started', message: msg });
      });
      addNotification({ type: 'success', title: 'Tasks Started', message: `${ids.length} task(s) started.` });
      await refetchTasks();
      syncCutCache();
    } finally {
      setStartingMO(null);
    }
  }, [filteredTasks, addNotification, refetchTasks, syncCutCache]);

  // Group tasks by Manufacturing Order so long, multi-project queues stay compact.
  const moGroups = useMemo(() => {
    const map = new Map<string, { moId: string; moNumber: string; customerName: string; tasks: TaskWithMO[] }>();
    for (const t of filteredTasks) {
      let g = map.get(t.manufacturing_order_id);
      if (!g) {
        g = { moId: t.manufacturing_order_id, moNumber: t.mo_number, customerName: t.customer_name, tasks: [] };
        map.set(t.manufacturing_order_id, g);
      }
      g.tasks.push(t);
    }
    return [...map.values()];
  }, [filteredTasks]);

  const toggleMO = useCallback((moId: string) => {
    setExpandedMOs((prev) => {
      const next = new Set(prev);
      if (next.has(moId)) next.delete(moId); else next.add(moId);
      return next;
    });
  }, []);

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

      {stationTabs.length > 0 && (
        <StatusTabs
          tabs={stationTabs}
          activeTab={activeTab || selectedCenter || stationTabs[0]?.value || ''}
          onChange={handleTabChange}
        />
      )}

      {isCompletedView ? (
        <>
          <div className="flex items-center gap-4 text-sm text-gray-500">
            <span className="font-medium text-gray-900">Completed</span>
            <span>{completedMos.length} MO{completedMos.length === 1 ? '' : 's'} past Assembly</span>
            <span className="text-gray-400">Audit / reopen</span>
          </div>
          {loadingCompleted ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-6 w-6 animate-spin text-gray-400" />
            </div>
          ) : completedMos.length === 0 ? (
            <div className="rounded-lg border border-gray-200 bg-white p-8 text-center">
              <CheckCircle2 className="h-10 w-10 text-green-400 mx-auto mb-3" />
              <p className="text-sm text-gray-500">No completed Assembly work yet.</p>
            </div>
          ) : (
            <div className="space-y-3">
              {completedMos.map((group) => {
                const moExpanded = expandedMOs.has(group.moId);
                return (
                  <div
                    key={group.moId}
                    className="border border-gray-200 border-l-4 border-l-green-500 rounded-xl bg-white overflow-hidden"
                  >
                    <div
                      className="flex items-center justify-between gap-4 px-5 py-3.5 hover:bg-gray-50/70 cursor-pointer"
                      onClick={() => toggleMO(group.moId)}
                    >
                      <div className="flex items-center gap-3 min-w-0">
                        {moExpanded
                          ? <ChevronDown className="h-4 w-4 text-gray-400 flex-shrink-0" />
                          : <ChevronRight className="h-4 w-4 text-gray-400 flex-shrink-0" />}
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            router.navigate(`/manufacturing/manufacturing-orders/${group.moId}?tab=work-orders`);
                          }}
                          className="font-semibold text-sm text-primary hover:underline flex-shrink-0"
                        >
                          {group.moNumber}
                        </button>
                        <StatusBadge status={group.moStatus} type="manufacturing" size="sm" />
                        {group.customerName && group.customerName !== 'N/A' && (
                          <span className="text-xs text-gray-400 truncate">{group.customerName}</span>
                        )}
                        <span className="text-xs text-gray-500 truncate max-w-[220px]">{group.productName}</span>
                      </div>
                      <div className="flex items-center gap-3 flex-shrink-0">
                        {group.completedAt && (
                          <span className="text-[11px] text-gray-400">
                            Done {new Date(group.completedAt).toLocaleString()}
                          </span>
                        )}
                        <button
                          type="button"
                          disabled={reactivatingMO === group.moId}
                          onClick={(e) => {
                            e.stopPropagation();
                            void reactivateMO(group);
                          }}
                          className="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium text-amber-800 bg-amber-50 border border-amber-200 rounded-lg hover:bg-amber-100 disabled:opacity-60"
                          title="Reopen Assembly and return this MO to the active queue"
                        >
                          {reactivatingMO === group.moId
                            ? <Loader2 className="h-3.5 w-3.5 animate-spin" />
                            : <RotateCcw className="h-3.5 w-3.5" />}
                          Return to Active
                        </button>
                      </div>
                    </div>
                    {moExpanded && (
                      <div className="border-t border-gray-100 px-5 py-4 space-y-3 bg-gray-50/40">
                        <div className="flex items-center justify-between gap-3">
                          <p className="text-[11px] uppercase tracking-wider text-gray-400">
                            Production history (audit viewer)
                          </p>
                          <button
                            type="button"
                            onClick={() => router.navigate(`/manufacturing/manufacturing-orders/${group.moId}?tab=work-orders`)}
                            className="text-xs text-primary hover:underline"
                          >
                            Open MO Work Orders →
                          </button>
                        </div>
                        <CompletedAuditViewer
                          moId={group.moId}
                          moNumber={group.moNumber}
                          productName={group.productName}
                        />
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </>
      ) : (
      <>
      {currentCenter && (
        <div className="flex items-center justify-between gap-4">
          <div className="flex items-center gap-4 text-sm text-gray-500">
            <span className="font-medium text-gray-900">{currentCenter.name}</span>
            <span>{pendingCount} pending</span>
            <span>{inProgressCount} in progress</span>
            <span>{filteredTasks.length} total</span>
          </div>
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
        <div className="space-y-4">
          {moGroups.map((group) => {
            const moExpanded = expandedMOs.has(group.moId);
            const moPending = group.tasks.filter((t) => t.status === 'pending').length;
            const moInProgress = group.tasks.filter((t) => t.status === 'in_progress').length;
            const moPartsDone = group.tasks.reduce((s, t) => s + t.lines.filter((l) => l.completed).length, 0);
            const moPartsTotal = group.tasks.reduce((s, t) => s + t.lines.length, 0);
            const moPct = moPartsTotal > 0 ? Math.round((moPartsDone / moPartsTotal) * 100) : 0;
            const moCompleted = group.tasks.every((t) => t.status === 'completed');
            const moStarted = moInProgress > 0 || moPartsDone > 0 || moCompleted;

            return (
              <div key={group.moId} className={`border rounded-xl bg-white overflow-hidden border-l-4 transition-colors ${
                moCompleted ? 'border-l-green-500 border-gray-200'
                : moStarted ? 'border-l-blue-500 border-gray-200'
                : 'border-l-gray-200 border-gray-200'
              }`}>
                {/* MO group header */}
                <div
                  className={`flex items-center justify-between gap-4 px-5 py-3.5 hover:bg-gray-50/70 cursor-pointer ${moStarted ? '' : 'bg-gray-50/30'}`}
                  onClick={() => toggleMO(group.moId)}
                >
                  <div className="flex items-center gap-3 min-w-0">
                    {moExpanded
                      ? <ChevronDown className="h-4 w-4 text-gray-400 flex-shrink-0" />
                      : <ChevronRight className="h-4 w-4 text-gray-400 flex-shrink-0" />}
                    <button
                      type="button"
                      onClick={(e) => { e.stopPropagation(); router.navigate(`/manufacturing/manufacturing-orders/${group.moId}`); }}
                      className={`font-semibold text-sm hover:underline flex-shrink-0 ${moStarted ? 'text-primary' : 'text-gray-400'}`}
                    >
                      {group.moNumber}
                    </button>
                    {!moStarted && (
                      <span className="text-[10px] font-medium px-1.5 py-0.5 rounded bg-gray-100 text-gray-500 border border-gray-200 flex-shrink-0">
                        Not started
                      </span>
                    )}
                    {group.customerName && group.customerName !== 'N/A' && (
                      <span className="text-xs text-gray-400 truncate">{group.customerName}</span>
                    )}
                    <span className="text-[11px] text-gray-400 flex-shrink-0">
                      {group.tasks.length} {group.tasks.length === 1 ? 'line' : 'lines'}
                    </span>
                  </div>
                  <div className="flex items-center gap-3 flex-shrink-0">
                    {(() => {
                      const moStartable = countStartableInMO(group.moId);
                      if (moStartable === 0) return null;
                      return (
                        <button
                          type="button"
                          disabled={startingMO === group.moId}
                          onClick={(e) => { e.stopPropagation(); void startMOTasks(group.moId); }}
                          className="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-60 transition-colors"
                          title="Start all pending tasks in this MO"
                        >
                          {startingMO === group.moId ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Play className="h-3.5 w-3.5" />}
                          Start All ({moStartable})
                        </button>
                      );
                    })()}
                    {moInProgress > 0 && <span className="hidden sm:inline text-[11px] text-indigo-600">{moInProgress} in progress</span>}
                    {moPending > 0 && <span className="hidden sm:inline text-[11px] text-gray-400">{moPending} pending</span>}
                    <span className="text-[11px] text-gray-500 tabular-nums">{moPartsDone}/{moPartsTotal} parts</span>
                    <div className="w-20 h-2 bg-gray-100 rounded-full overflow-hidden">
                      <div className={`h-full rounded-full transition-all ${moPct === 100 ? 'bg-green-500' : moPct > 0 ? 'bg-blue-500' : 'bg-gray-300'}`} style={{ width: `${moPct}%` }} />
                    </div>
                    <span className="text-[11px] font-medium text-gray-500 tabular-nums w-8 text-right">{moPct}%</span>
                  </div>
                </div>

                {moExpanded && (
                  <div className="divide-y divide-gray-100 border-t border-gray-100">
                    {group.tasks.map((task) => {
                      const completedCount = task.lines.filter((l) => l.completed).length;
                      const totalCount = task.lines.length;
                      const isExpanded = expandedTasks.has(task.id);

                      return (
              <div key={task.id} className={`bg-white border-l-4 transition-colors ${
                task.status === 'in_progress' ? 'border-l-blue-500'
                : task.status === 'completed' ? 'border-l-green-500'
                : 'border-l-gray-200'
              }`}>
                <div className={`flex items-center justify-between px-4 py-3 ${isExpanded ? 'border-b border-gray-100 bg-gray-50/50' : 'hover:bg-gray-50/40'} ${task.status === 'pending' ? 'bg-gray-50/40' : ''}`}>
                  <div className={`flex items-center gap-3 min-w-0 ${task.status === 'pending' ? 'opacity-50' : ''}`}>
                    <button type="button" onClick={() => toggleTask(task.id)} className="text-gray-400 hover:text-gray-600 flex-shrink-0">
                      {isExpanded ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
                    </button>
                    {(task.line_position || task.line_area) && (
                      <span className="inline-flex items-center gap-1 text-[11px] font-medium px-1.5 py-0.5 rounded bg-indigo-50 text-indigo-700 border border-indigo-100 flex-shrink-0">
                        {task.line_position && <span>{task.line_position}</span>}
                        {task.line_position && task.line_area && <span className="text-indigo-300">·</span>}
                        {task.line_area && <span>{task.line_area}</span>}
                      </span>
                    )}
                    <span className="text-xs text-gray-700 truncate max-w-[240px]">{task.line_label}</span>
                    <StatusBadge status={task.status} type="manufacturing" size="sm" />
                    {task.assigned_to && (
                      <span className="inline-flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded bg-blue-50 text-blue-700 border border-blue-100 flex-shrink-0">
                        <User className="w-3 h-3" /> {task.assigned_to}
                      </span>
                    )}
                  </div>

                  <div className="flex items-center gap-3">
                    {task.due_date && <span className="text-xs text-gray-400">{task.due_date}</span>}
                    <span className="text-xs text-gray-500" title="Components done / total">{completedCount}/{totalCount} parts</span>

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
                        <th className="text-left px-4 py-2 w-8">
                          <input
                            type="checkbox"
                            title="Select all"
                            className="rounded border-gray-300"
                            disabled={task.status !== 'in_progress' || task.lines.length === 0}
                            checked={task.lines.length > 0 && task.lines.every((l) => l.completed)}
                            ref={(el) => {
                              if (el) {
                                const done = task.lines.filter((l) => l.completed).length;
                                el.indeterminate = done > 0 && done < task.lines.length;
                              }
                            }}
                            onChange={(e) => { void toggleAllLines(task, e.target.checked); }}
                          />
                        </th>
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
                                  disabled={task.status !== 'in_progress'}
                                />
                              </td>
                              <td className={`px-4 py-2 font-mono ${line.completed ? 'line-through text-gray-400' : 'text-gray-800'}`}>
                                <div className="flex flex-col gap-0.5">
                                  <span>{line.sku ?? '—'}</span>
                                  {line.substituted_from_sku && (
                                    <span className="inline-flex items-center gap-1 text-[10px] font-medium text-violet-700">
                                      <span className="px-1.5 py-0.5 rounded bg-violet-100">Substituted</span>
                                      <span className="text-gray-400 line-through font-normal">{line.substituted_from_sku}</span>
                                    </span>
                                  )}
                                </div>
                              </td>
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
          })}
        </div>
      )}
      </>
      )}
    </div>
  );
}
