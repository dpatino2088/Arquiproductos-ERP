import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../../lib/supabase/client';
import { formatDate } from '../../lib/utils';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useFilteredMfgSubmodules } from './manufacturingSubmodules';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useAuth } from '../../hooks/useAuth';
import { router } from '../../lib/router';
import StatusBadge from '../../components/shared/StatusBadge';
import StatusTabs from '../../components/shared/StatusTabs';
import {
  Search, Eye, Loader2, SortAsc, SortDesc,
  Calendar, Clock, ChevronRight, Play,
} from 'lucide-react';

/* ─── Types ─────────────────────────────────────────── */

interface WorkOrderRow {
  mo_id: string;
  mo_number: string;
  wo_number: string;
  product_types: string[];
  customer_name: string;
  dealer_name: string;
  due_date: string | null;
  global_status: 'pending' | 'in_progress' | 'completed';
  lines_count: number;
  total_components: number;
  completed_components: number;
  stations: { code: string; status: string }[];
}

interface MyTask {
  task_id: string;
  mo_id: string;
  mo_number: string;
  product_name: string;
  customer_name: string;
  station_name: string;
  station_code: string;
  status: string;
  planned_start_at: string | null;
  planned_end_at: string | null;
  total_lines: number;
  completed_lines: number;
  sol_id: string | null;
  line_description: string;
}

type SortColumn = 'wo_number' | 'status' | 'progress' | 'customer_name' | 'lines_count';

function deriveGlobalStatus(tasks: { status: string }[]): 'pending' | 'in_progress' | 'completed' {
  if (tasks.length === 0) return 'pending';
  if (tasks.every(t => t.status === 'completed')) return 'completed';
  if (tasks.some(t => t.status === 'in_progress' || t.status === 'completed')) return 'in_progress';
  return 'pending';
}

function toDayKey(iso: string | null): string {
  if (!iso) return 'unscheduled';
  if (/^\d{4}-\d{2}-\d{2}$/.test(iso)) return iso;
  const d = new Date(iso);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function dayLabel(key: string): string {
  if (key === 'unscheduled') return 'Unscheduled';
  const d = new Date(`${key}T00:00:00`);
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today); tomorrow.setDate(tomorrow.getDate() + 1);
  if (d.getTime() === today.getTime()) return 'Today';
  if (d.getTime() === tomorrow.getTime()) return 'Tomorrow';
  return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
}

function formatWoNumber(moNumber: string): string {
  return moNumber.replace(/^MO-/, 'WO-');
}

/* ─── Component ─────────────────────────────────────── */

export default function WorkOrdersList() {
  const filteredSubmodules = useFilteredMfgSubmodules();
  const { activeOrganizationId } = useOrganizationContext();
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const { role, loading: roleLoading } = useCurrentOrgRole();
  const { user } = useAuth();
  const isOperator = role === 'operator' || role === 'operator_member';
  const currentUserId = user?.id ?? null;

  const [rows, setRows] = useState<WorkOrderRow[]>([]);
  const [myTasks, setMyTasks] = useState<MyTask[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusTab, setStatusTab] = useState('all');
  const [sortBy, setSortBy] = useState<SortColumn>('wo_number');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [myTasksTab, setMyTasksTab] = useState('active');

  /* ─── Admin fetch: group by MO (one row per WO) ─── */
  const fetchAdminData = useCallback(async () => {
    if (!activeOrganizationId) return;
    setLoading(true);
    try {
      const { data: wcData } = await supabase
        .from('WorkCenters')
        .select('id, name, code, sequence')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .eq('is_active', true)
        .order('sequence');
      const wcMap: Record<string, { name: string; code: string; sequence: number }> = {};
      for (const wc of (wcData ?? [])) wcMap[wc.id] = { name: wc.name, code: wc.code, sequence: wc.sequence };

      const { data: taskData, error: tErr } = await supabase
        .from('WorkOrderTasks')
        .select('id, manufacturing_order_id, work_center_id, sequence, status, sales_order_line_id')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('sequence');
      if (tErr) throw tErr;
      if (!taskData || taskData.length === 0) { setRows([]); setLoading(false); return; }

      const moIds = [...new Set(taskData.map((t: any) => t.manufacturing_order_id))];
      const { data: moData } = await supabase
        .from('ManufacturingOrders')
        .select('id, manufacturing_order_no, product_name, sales_order_id')
        .in('id', moIds);
      const moMap: Record<string, any> = {};
      for (const mo of (moData ?? [])) moMap[mo.id] = mo;

      const soIds = [...new Set((moData ?? []).map((m: any) => m.sales_order_id).filter(Boolean))];
      const customerMap: Record<string, string> = {};
      const dealerMap: Record<string, string> = {};
      const dueDateMap: Record<string, string | null> = {};
      if (soIds.length > 0) {
        const { data: soData } = await supabase
          .from('SalesOrders')
          .select('id, customer_id, dealer_id, expected_delivery_date')
          .in('id', soIds);
        for (const so of (soData ?? [])) dueDateMap[so.id] = so.expected_delivery_date ?? null;
        const custIds = [...new Set((soData ?? []).map((s: any) => s.customer_id).filter(Boolean))];
        const dealerIds = [...new Set((soData ?? []).map((s: any) => s.dealer_id).filter(Boolean))];
        if (custIds.length > 0) {
          const { data: custData } = await supabase.from('DirectoryCustomers').select('id, customer_name').in('id', custIds);
          const custLookup: Record<string, string> = {};
          for (const c of (custData ?? [])) custLookup[c.id] = c.customer_name;
          for (const so of (soData ?? [])) { if (so.customer_id) customerMap[so.id] = custLookup[so.customer_id] ?? ''; }
        }
        if (dealerIds.length > 0) {
          const { data: dealerData } = await supabase.from('Dealers').select('id, dealer_name').in('id', dealerIds);
          const dealerLookup: Record<string, string> = {};
          for (const d of (dealerData ?? [])) dealerLookup[d.id] = d.dealer_name;
          for (const so of (soData ?? [])) { if (so.dealer_id) dealerMap[so.id] = dealerLookup[so.dealer_id] ?? ''; }
        }
      }

      // Fetch product_type from SaleOrderLines for each task's SOL
      const solIds = [...new Set(taskData.map((t: any) => t.sales_order_line_id).filter(Boolean))];
      const solProductTypeMap: Record<string, string> = {};
      if (solIds.length > 0) {
        const { data: solData } = await supabase.from('SaleOrderLines').select('id, product_type').in('id', solIds);
        for (const sol of (solData ?? [])) { if (sol.product_type) solProductTypeMap[sol.id] = sol.product_type; }
      }

      const taskIds = taskData.map((t: any) => t.id);
      const { data: lineData } = await supabase
        .from('WorkOrderTaskLines')
        .select('task_id, completed')
        .in('task_id', taskIds);
      const lineStats: Record<string, { total: number; completed: number }> = {};
      for (const l of (lineData ?? [])) {
        if (!lineStats[l.task_id]) lineStats[l.task_id] = { total: 0, completed: 0 };
        lineStats[l.task_id].total++;
        if (l.completed) lineStats[l.task_id].completed++;
      }

      // Group by mo_id (one row per WO/MO)
      const byMo: Record<string, any[]> = {};
      for (const t of taskData) {
        if (!byMo[t.manufacturing_order_id]) byMo[t.manufacturing_order_id] = [];
        byMo[t.manufacturing_order_id].push(t);
      }

      const result: WorkOrderRow[] = Object.entries(byMo).map(([moId, tasks]) => {
        const mo = moMap[moId];
        const soId = mo?.sales_order_id;
        const moNumber = mo?.manufacturing_order_no ?? '—';

        // Unique lines + derive product type from SOLs
        const uniqueLines = new Set(tasks.map((t: any) => t.sales_order_line_id).filter(Boolean));
        const productTypesSet = new Set<string>();
        for (const solId of uniqueLines) { const pt = solProductTypeMap[solId]; if (pt) productTypesSet.add(pt); }
        const productTypesArr = productTypesSet.size > 0
          ? [...productTypesSet].map(pt => pt.charAt(0).toUpperCase() + pt.slice(1).replace(/_/g, ' '))
          : [mo?.product_name ?? '—'];

        // Unique stations (deduplicated by work_center code, show worst status)
        const stationMap: Record<string, string> = {};
        for (const t of tasks.sort((a: any, b: any) => (wcMap[a.work_center_id]?.sequence ?? 0) - (wcMap[b.work_center_id]?.sequence ?? 0))) {
          const code = wcMap[t.work_center_id]?.code ?? '—';
          const prev = stationMap[code];
          if (!prev || prev === 'completed') stationMap[code] = t.status;
          else if (prev === 'pending' && (t.status === 'in_progress')) stationMap[code] = 'in_progress';
        }
        const stations = Object.entries(stationMap).map(([code, status]) => ({ code, status }));

        let totalComponents = 0;
        let completedComponents = 0;
        for (const t of tasks) {
          const s = lineStats[t.id] ?? { total: 0, completed: 0 };
          totalComponents += s.total;
          completedComponents += s.completed;
        }

        return {
          mo_id: moId,
          mo_number: moNumber,
          wo_number: formatWoNumber(moNumber),
          product_types: productTypesArr,
          customer_name: soId ? (customerMap[soId] ?? '—') : '—',
          dealer_name: soId ? (dealerMap[soId] ?? '—') : '—',
          due_date: soId ? (dueDateMap[soId] ?? null) : null,
          global_status: deriveGlobalStatus(tasks),
          lines_count: uniqueLines.size,
          total_components: totalComponents,
          completed_components: completedComponents,
          stations,
        };
      });

      setRows(result);
    } catch {
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId]);

  /* ─── Operator fetch (my tasks only) ─── */
  const fetchMyTasks = useCallback(async () => {
    if (!activeOrganizationId || !currentUserId) return;
    setLoading(true);
    try {
      const { data: taskData } = await supabase
        .from('WorkOrderTasks')
        .select('id, manufacturing_order_id, work_center_id, status, planned_start_at, planned_end_at, assigned_to_user_id, sales_order_line_id')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .eq('assigned_to_user_id', currentUserId)
        .order('planned_start_at', { ascending: true, nullsFirst: false });
      if (!taskData || taskData.length === 0) { setMyTasks([]); setLoading(false); return; }

      const moIds = [...new Set(taskData.map((t: any) => t.manufacturing_order_id))];
      const { data: moData } = await supabase
        .from('ManufacturingOrders')
        .select('id, manufacturing_order_no, product_name, sales_order_id')
        .in('id', moIds);
      const moMap: Record<string, any> = {};
      for (const mo of (moData ?? [])) moMap[mo.id] = mo;

      const solIds = [...new Set(taskData.map((t: any) => t.sales_order_line_id).filter(Boolean))];
      const solMap: Record<string, string> = {};
      if (solIds.length > 0) {
        const { data: solData } = await supabase.from('SaleOrderLines').select('id, description, variant_name, product_type').in('id', solIds);
        for (const sol of (solData ?? [])) solMap[sol.id] = sol.description || sol.variant_name || sol.product_type || 'Line';
      }

      const soIds = [...new Set((moData ?? []).map((m: any) => m.sales_order_id).filter(Boolean))];
      const customerMap: Record<string, string> = {};
      if (soIds.length > 0) {
        const { data: soData } = await supabase.from('SalesOrders').select('id, customer_id').in('id', soIds);
        const custIds = [...new Set((soData ?? []).map((s: any) => s.customer_id).filter(Boolean))];
        if (custIds.length > 0) {
          const { data: custData } = await supabase.from('DirectoryCustomers').select('id, customer_name').in('id', custIds);
          const custLookup: Record<string, string> = {};
          for (const c of (custData ?? [])) custLookup[c.id] = c.customer_name;
          for (const so of (soData ?? [])) { if (so.customer_id) customerMap[so.id] = custLookup[so.customer_id] ?? ''; }
        }
      }

      const { data: wcData } = await supabase.from('WorkCenters').select('id, name, code').eq('organization_id', activeOrganizationId);
      const wcMap: Record<string, { name: string; code: string }> = {};
      for (const wc of (wcData ?? [])) wcMap[wc.id] = { name: wc.name, code: wc.code };

      const taskIds = taskData.map((t: any) => t.id);
      const { data: lineData } = await supabase.from('WorkOrderTaskLines').select('task_id, completed').in('task_id', taskIds);
      const lineStats: Record<string, { total: number; completed: number }> = {};
      for (const l of (lineData ?? [])) {
        if (!lineStats[l.task_id]) lineStats[l.task_id] = { total: 0, completed: 0 };
        lineStats[l.task_id].total++;
        if (l.completed) lineStats[l.task_id].completed++;
      }

      const result: MyTask[] = taskData.map((t: any) => {
        const mo = moMap[t.manufacturing_order_id];
        const soId = mo?.sales_order_id;
        const wc = wcMap[t.work_center_id];
        const stats = lineStats[t.id] ?? { total: 0, completed: 0 };
        const lineDesc = t.sales_order_line_id ? (solMap[t.sales_order_line_id] ?? 'Line') : (mo?.product_name ?? '—');
        return {
          task_id: t.id,
          mo_id: t.manufacturing_order_id,
          mo_number: mo?.manufacturing_order_no ?? '—',
          product_name: lineDesc,
          customer_name: soId ? (customerMap[soId] ?? '—') : '—',
          station_name: wc?.name ?? '—',
          station_code: wc?.code ?? '—',
          status: t.status,
          planned_start_at: t.planned_start_at,
          planned_end_at: t.planned_end_at,
          total_lines: stats.total,
          completed_lines: stats.completed,
          sol_id: t.sales_order_line_id ?? null,
          line_description: lineDesc,
        };
      });
      setMyTasks(result);
    } catch {
      setMyTasks([]);
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId, currentUserId]);

  useEffect(() => {
    if (roleLoading) return;
    if (isOperator) fetchMyTasks();
    else fetchAdminData();
  }, [roleLoading, isOperator, fetchAdminData, fetchMyTasks]);

  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/manufacturing')) registerSubmodules('Manufacturing', filteredSubmodules);
    return () => { const path = window.location.pathname; if (!path.startsWith('/manufacturing')) clearSubmoduleNav(); };
  }, [registerSubmodules, clearSubmoduleNav, filteredSubmodules]);

  /* ─── Admin filtering / sorting ─── */
  const statusCounts = useMemo(() => {
    const counts: Record<string, number> = { all: 0, pending: 0, in_progress: 0, completed: 0 };
    for (const r of rows) { counts.all++; counts[r.global_status] = (counts[r.global_status] ?? 0) + 1; }
    return counts;
  }, [rows]);

  const statusTabs = useMemo(() => [
    { label: 'All', value: 'all', count: statusCounts.all },
    { label: 'Pending', value: 'pending', count: statusCounts.pending },
    { label: 'In Progress', value: 'in_progress', count: statusCounts.in_progress },
    { label: 'Completed', value: 'completed', count: statusCounts.completed },
  ], [statusCounts]);

  const filtered = useMemo(() => {
    let data = rows;
    if (statusTab !== 'all') data = data.filter(r => r.global_status === statusTab);
    if (searchTerm.trim()) {
      const q = searchTerm.toLowerCase();
      data = data.filter(r =>
        r.wo_number.toLowerCase().includes(q) ||
        r.mo_number.toLowerCase().includes(q) ||
        r.customer_name.toLowerCase().includes(q) ||
        r.dealer_name.toLowerCase().includes(q) ||
        r.product_types.some(pt => pt.toLowerCase().includes(q))
      );
    }
    data = [...data].sort((a, b) => {
      let cmp = 0;
      const statusOrder: Record<string, number> = { pending: 0, in_progress: 1, completed: 2 };
      switch (sortBy) {
        case 'wo_number': cmp = a.wo_number.localeCompare(b.wo_number); break;
        case 'status': cmp = (statusOrder[a.global_status] ?? 0) - (statusOrder[b.global_status] ?? 0); break;
        case 'progress': {
          const pctA = a.total_components > 0 ? a.completed_components / a.total_components : 0;
          const pctB = b.total_components > 0 ? b.completed_components / b.total_components : 0;
          cmp = pctA - pctB;
          break;
        }
        case 'customer_name': cmp = a.customer_name.localeCompare(b.customer_name); break;
        case 'lines_count': cmp = a.lines_count - b.lines_count; break;
      }
      return sortOrder === 'asc' ? cmp : -cmp;
    });
    return data;
  }, [rows, statusTab, searchTerm, sortBy, sortOrder]);

  const handleSort = (col: SortColumn) => {
    if (sortBy === col) setSortOrder(prev => prev === 'asc' ? 'desc' : 'asc');
    else { setSortBy(col); setSortOrder('desc'); }
  };

  const SortIcon = ({ col }: { col: SortColumn }) => {
    if (sortBy !== col) return null;
    return sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />;
  };

  /* ─── Operator grouping by day ─── */
  const myTasksFiltered = useMemo(() => {
    let data = myTasks;
    if (myTasksTab === 'active') data = data.filter(t => t.status !== 'completed');
    else if (myTasksTab === 'completed') data = data.filter(t => t.status === 'completed');
    if (searchTerm.trim()) {
      const q = searchTerm.toLowerCase();
      data = data.filter(t => t.mo_number.toLowerCase().includes(q) || t.product_name.toLowerCase().includes(q) || t.station_name.toLowerCase().includes(q));
    }
    return data;
  }, [myTasks, myTasksTab, searchTerm]);

  const dayGroups = useMemo(() => {
    const groups = new Map<string, MyTask[]>();
    for (const t of myTasksFiltered) { const key = toDayKey(t.planned_start_at); if (!groups.has(key)) groups.set(key, []); groups.get(key)!.push(t); }
    return [...groups.entries()].sort(([a], [b]) => { if (a === 'unscheduled') return 1; if (b === 'unscheduled') return -1; return a.localeCompare(b); });
  }, [myTasksFiltered]);

  const myTasksCounts = useMemo(() => ({
    all: myTasks.length,
    active: myTasks.filter(t => t.status !== 'completed').length,
    completed: myTasks.filter(t => t.status === 'completed').length,
  }), [myTasks]);

  const myStatusTabs = useMemo(() => [
    { label: 'Active', value: 'active', count: myTasksCounts.active },
    { label: 'Completed', value: 'completed', count: myTasksCounts.completed },
    { label: 'All', value: 'all', count: myTasksCounts.all },
  ], [myTasksCounts]);

  /* ─── Operator "My Tasks" view ─── */
  if (isOperator) {
    return (
      <div className="py-6 px-6">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-xl font-semibold text-foreground mb-1">My Tasks</h1>
            <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
              {myTasksCounts.active} active task{myTasksCounts.active !== 1 ? 's' : ''} assigned to you
            </p>
          </div>
        </div>

        <StatusTabs tabs={myStatusTabs} activeTab={myTasksTab} onChange={setMyTasksTab} />

        <div className="mb-4 mt-4">
          <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
            <div className="flex items-center justify-between gap-3 flex-wrap">
              <div className="flex-1 relative min-w-[240px]">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
                <input type="text" placeholder="Search by MO #, product, or station..." value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50" />
              </div>
            </div>
          </div>
        </div>

        {loading ? (
          <div className="bg-white border border-gray-200 rounded-lg p-12 text-center"><Loader2 className="h-6 w-6 animate-spin text-gray-400 mx-auto" /></div>
        ) : myTasksFiltered.length === 0 ? (
          <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
            <Calendar className="h-8 w-8 text-gray-300 mx-auto mb-2" />
            <p className="text-gray-500 mb-1">No tasks found</p>
            <p className="text-sm text-gray-400">{searchTerm ? 'Try adjusting your search' : 'No tasks have been assigned to you yet'}</p>
          </div>
        ) : (
          <div className="space-y-4">
            {dayGroups.map(([dayKey, tasks]) => {
              const isToday = dayKey === toDayKey(new Date().toISOString());
              return (
                <div key={dayKey}>
                  <div className={`flex items-center gap-2 mb-2 px-1 ${isToday ? 'text-primary' : 'text-gray-500'}`}>
                    <Calendar className="w-3.5 h-3.5" />
                    <span className={`text-xs font-semibold uppercase tracking-wide ${isToday ? 'text-primary' : ''}`}>{dayLabel(dayKey)}</span>
                    <span className="text-[10px] text-gray-400">{tasks.length} task{tasks.length !== 1 ? 's' : ''}</span>
                  </div>
                  <div className="space-y-2">
                    {tasks.map(task => {
                      const pct = task.total_lines > 0 ? Math.round((task.completed_lines / task.total_lines) * 100) : 0;
                      const statusColor = task.status === 'completed' ? 'border-l-green-500' : task.status === 'in_progress' ? 'border-l-blue-500' : 'border-l-gray-300';
                      const stationColor = task.status === 'completed' ? 'bg-green-100 text-green-700' : task.status === 'in_progress' ? 'bg-blue-100 text-blue-700' : 'bg-gray-100 text-gray-600';
                      return (
                        <div key={task.task_id}
                          className={`bg-white border border-gray-200 border-l-4 ${statusColor} rounded-lg p-4 hover:shadow-sm cursor-pointer transition-all`}
                          onClick={() => router.navigate(`/manufacturing/work-orders/${task.mo_id}`)}
                        >
                          <div className="flex items-center justify-between">
                            <div className="flex items-center gap-3 min-w-0">
                              <span className={`inline-flex items-center px-2 py-1 rounded text-xs font-semibold ${stationColor}`}>{task.station_code}</span>
                              <div className="min-w-0">
                                <div className="flex items-center gap-2">
                                  <span className="text-sm font-medium text-gray-900">{task.mo_number}</span>
                                  <span className="text-xs text-gray-400">·</span>
                                  <span className="text-xs text-gray-500 truncate">{task.product_name}</span>
                                </div>
                                {task.customer_name !== '—' && <p className="text-xs text-gray-400 mt-0.5">{task.customer_name}</p>}
                              </div>
                            </div>
                            <div className="flex items-center gap-3 flex-shrink-0">
                              {task.planned_start_at && (
                                <div className="flex items-center gap-1 text-xs text-gray-400">
                                  <Clock className="w-3 h-3" />
                                  {new Date(task.planned_start_at).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false })}
                                </div>
                              )}
                              {task.total_lines > 0 && (
                                <div className="flex items-center gap-2">
                                  <div className="w-12 h-1.5 bg-gray-200 rounded-full overflow-hidden">
                                    <div className={`h-full rounded-full ${pct === 100 ? 'bg-green-500' : pct > 0 ? 'bg-blue-500' : 'bg-gray-300'}`} style={{ width: `${pct}%` }} />
                                  </div>
                                  <span className="text-[10px] text-gray-400 tabular-nums">{task.completed_lines}/{task.total_lines}</span>
                                </div>
                              )}
                              {task.status === 'pending' && <Play className="w-3.5 h-3.5 text-gray-400" />}
                              <ChevronRight className="w-4 h-4 text-gray-300" />
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    );
  }

  /* ─── Admin table view (one row per WO = one row per MO) ─── */
  return (
    <div className="py-6 px-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Work Orders</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Track and manage {rows.length} work {rows.length === 1 ? 'order' : 'orders'}
          </p>
        </div>
      </div>

      <StatusTabs tabs={statusTabs} activeTab={statusTab} onChange={setStatusTab} />

      <div className="mb-4 mt-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center justify-between gap-3 flex-wrap">
            <div className="flex-1 relative min-w-[240px]">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input type="text" placeholder="Search by WO #, MO #, customer, or dealer..." value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50" />
            </div>
          </div>
        </div>
      </div>

      {loading ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center"><Loader2 className="h-6 w-6 animate-spin text-gray-400 mx-auto" /></div>
      ) : filtered.length === 0 ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <p className="text-gray-500 mb-2">No work orders found</p>
          <p className="text-sm text-gray-400">
            {searchTerm || statusTab !== 'all' ? 'Try adjusting your search or filters' : 'Work orders are generated from Manufacturing Orders'}
          </p>
        </div>
      ) : (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <div className="table-fit-wrapper">
            <table className="table-fit">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="py-3 px-6 text-left">
                    <button onClick={() => handleSort('wo_number')} className="flex items-center gap-1 text-xs font-medium text-gray-700 hover:text-gray-900">WO # <SortIcon col="wo_number" /></button>
                  </th>
                  <th className="py-3 px-6 text-left text-xs font-medium text-gray-700">Product Type</th>
                  <th className="py-3 px-6 text-left">
                    <button onClick={() => handleSort('customer_name')} className="flex items-center gap-1 text-xs font-medium text-gray-700 hover:text-gray-900">Customer <SortIcon col="customer_name" /></button>
                  </th>
                  <th className="py-3 px-6 text-left text-xs font-medium text-gray-700">Dealer</th>
                  <th className="py-3 px-6 text-center">
                    <button onClick={() => handleSort('lines_count')} className="flex items-center gap-1 text-xs font-medium text-gray-700 hover:text-gray-900">Lines <SortIcon col="lines_count" /></button>
                  </th>
                  <th className="py-3 px-6 text-left text-xs font-medium text-gray-700">Stations</th>
                  <th className="py-3 px-6 text-left">
                    <button onClick={() => handleSort('status')} className="flex items-center gap-1 text-xs font-medium text-gray-700 hover:text-gray-900">Status <SortIcon col="status" /></button>
                  </th>
                  <th className="py-3 px-6 text-left">
                    <button onClick={() => handleSort('progress')} className="flex items-center gap-1 text-xs font-medium text-gray-700 hover:text-gray-900">Progress <SortIcon col="progress" /></button>
                  </th>
                  <th className="py-3 px-6 text-left text-xs font-medium text-gray-700">Due Date</th>
                  <th className="py-3 px-6 text-right text-xs font-medium text-gray-700">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filtered.map((wo) => {
                  const pct = wo.total_components > 0 ? Math.round((wo.completed_components / wo.total_components) * 100) : 0;
                  return (
                    <tr key={wo.mo_id} className="hover:bg-gray-50 cursor-pointer transition-colors" onClick={() => router.navigate(`/manufacturing/work-orders/${wo.mo_id}`)}>
                      <td className="py-4 px-6">
                        <div className="flex flex-col">
                          <span className="text-sm font-semibold text-gray-900">{wo.wo_number}</span>
                          <span className="text-[10px] text-gray-400 font-mono">{wo.mo_number}</span>
                        </div>
                      </td>
                      <td className="py-4 px-6">
                        <div className="flex gap-1 flex-wrap">
                          {wo.product_types.map((pt, i) => (
                            <span key={i} className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-indigo-50 text-indigo-700 border border-indigo-100">{pt}</span>
                          ))}
                        </div>
                      </td>
                      <td className="py-4 px-6 text-sm text-gray-700">{wo.customer_name}</td>
                      <td className="py-4 px-6 text-sm text-gray-500">{wo.dealer_name}</td>
                      <td className="py-4 px-6 text-center">
                        <span className="inline-flex items-center justify-center w-7 h-7 rounded-full bg-gray-100 text-xs font-semibold text-gray-700">{wo.lines_count}</span>
                      </td>
                      <td className="py-4 px-6">
                        <div className="flex gap-1 flex-wrap">
                          {wo.stations.map((s, i) => {
                            const color = s.status === 'completed' ? 'bg-green-100 text-green-700' : s.status === 'in_progress' ? 'bg-blue-100 text-blue-700' : 'bg-gray-100 text-gray-500';
                            return <span key={i} className={`inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium ${color}`}>{s.code}</span>;
                          })}
                        </div>
                      </td>
                      <td className="py-4 px-6"><StatusBadge status={wo.global_status} type="workOrder" size="sm" /></td>
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-2">
                          <div className="w-16 h-1.5 bg-gray-200 rounded-full overflow-hidden">
                            <div className={`h-full rounded-full transition-all ${pct === 100 ? 'bg-green-500' : pct > 0 ? 'bg-blue-500' : 'bg-gray-300'}`} style={{ width: `${pct}%` }} />
                          </div>
                          <span className="text-xs text-gray-500 tabular-nums">{wo.completed_components}/{wo.total_components}</span>
                        </div>
                      </td>
                      <td className="py-4 px-6 text-sm text-gray-500">{formatDate(wo.due_date)}</td>
                      <td className="py-4 px-6 text-right">
                        <button onClick={(e) => { e.stopPropagation(); router.navigate(`/manufacturing/work-orders/${wo.mo_id}`); }}
                          className="p-1.5 rounded hover:bg-gray-200 text-gray-400 hover:text-gray-600" title="View detail">
                          <Eye className="w-4 h-4" />
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
