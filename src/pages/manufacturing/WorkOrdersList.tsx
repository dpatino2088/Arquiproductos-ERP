import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { MANUFACTURING_SUBMODULES } from './manufacturingSubmodules';
import { router } from '../../lib/router';
import StatusBadge from '../../components/shared/StatusBadge';
import StatusTabs from '../../components/shared/StatusTabs';
import Input from '../../components/ui/Input';
import { Search, Eye, Loader2, SortAsc, SortDesc } from 'lucide-react';

interface MOWorkOrder {
  mo_id: string;
  mo_number: string;
  product_name: string;
  customer_name: string;
  due_date: string | null;
  global_status: 'pending' | 'in_progress' | 'completed';
  total_lines: number;
  completed_lines: number;
  stations: { name: string; code: string; status: string; completed: number; total: number }[];
}

type SortColumn = 'mo_number' | 'status' | 'progress' | 'customer_name';

function deriveGlobalStatus(stations: { status: string }[]): 'pending' | 'in_progress' | 'completed' {
  if (stations.length === 0) return 'pending';
  const allCompleted = stations.every(s => s.status === 'completed');
  if (allCompleted) return 'completed';
  const anyActive = stations.some(s => s.status === 'in_progress' || s.status === 'completed');
  return anyActive ? 'in_progress' : 'pending';
}

export default function WorkOrdersList() {
  const { activeOrganizationId } = useOrganizationContext();
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const [rows, setRows] = useState<MOWorkOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusTab, setStatusTab] = useState('all');
  const [sortBy, setSortBy] = useState<SortColumn>('mo_number');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');

  const fetchData = useCallback(async () => {
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
        .select('id, manufacturing_order_id, work_center_id, sequence, status')
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
      const dueDateMap: Record<string, string | null> = {};
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
            if (so.customer_id) customerMap[so.id] = custLookup[so.customer_id] ?? '';
          }
        }
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

      const grouped: Record<string, { tasks: any[] }> = {};
      for (const t of taskData) {
        const key = t.manufacturing_order_id;
        if (!grouped[key]) grouped[key] = { tasks: [] };
        grouped[key].tasks.push(t);
      }

      const result: MOWorkOrder[] = Object.entries(grouped).map(([moId, { tasks }]) => {
        const mo = moMap[moId];
        const soId = mo?.sales_order_id;

        const stations = tasks
          .sort((a: any, b: any) => (wcMap[a.work_center_id]?.sequence ?? 0) - (wcMap[b.work_center_id]?.sequence ?? 0))
          .map((t: any) => {
            const wc = wcMap[t.work_center_id];
            const stats = lineStats[t.id] ?? { total: 0, completed: 0 };
            return {
              name: wc?.name ?? '—',
              code: wc?.code ?? '—',
              status: t.status,
              completed: stats.completed,
              total: stats.total,
            };
          });

        const totalLines = stations.reduce((sum, s) => sum + s.total, 0);
        const completedLines = stations.reduce((sum, s) => sum + s.completed, 0);

        return {
          mo_id: moId,
          mo_number: mo?.manufacturing_order_no ?? '—',
          product_name: mo?.product_name ?? '—',
          customer_name: soId ? (customerMap[soId] ?? '—') : '—',
          due_date: soId ? (dueDateMap[soId] ?? null) : null,
          global_status: deriveGlobalStatus(stations),
          total_lines: totalLines,
          completed_lines: completedLines,
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

  useEffect(() => { fetchData(); }, [fetchData]);

  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/manufacturing')) {
      registerSubmodules('Manufacturing', [...MANUFACTURING_SUBMODULES]);
    }
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/manufacturing')) clearSubmoduleNav();
    };
  }, [registerSubmodules, clearSubmoduleNav]);

  const statusCounts = useMemo(() => {
    const counts = { all: 0, pending: 0, in_progress: 0, completed: 0 };
    for (const r of rows) {
      counts.all++;
      counts[r.global_status]++;
    }
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
        r.mo_number.toLowerCase().includes(q) ||
        r.customer_name.toLowerCase().includes(q) ||
        r.product_name.toLowerCase().includes(q)
      );
    }
    data = [...data].sort((a, b) => {
      let cmp = 0;
      switch (sortBy) {
        case 'mo_number': cmp = a.mo_number.localeCompare(b.mo_number); break;
        case 'status': {
          const order = { pending: 0, in_progress: 1, completed: 2 };
          cmp = order[a.global_status] - order[b.global_status];
          break;
        }
        case 'progress': {
          const pctA = a.total_lines > 0 ? a.completed_lines / a.total_lines : 0;
          const pctB = b.total_lines > 0 ? b.completed_lines / b.total_lines : 0;
          cmp = pctA - pctB;
          break;
        }
        case 'customer_name': cmp = a.customer_name.localeCompare(b.customer_name); break;
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
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
          <Input
            type="text"
            placeholder="Search by MO #, customer, or product..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-10"
          />
        </div>
      </div>

      {loading ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <Loader2 className="h-6 w-6 animate-spin text-gray-400 mx-auto" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <p className="text-gray-500 mb-2">No work orders found</p>
          <p className="text-sm text-gray-400">
            {searchTerm || statusTab !== 'all'
              ? 'Try adjusting your search or filters'
              : 'Work orders are generated from Manufacturing Orders'}
          </p>
        </div>
      ) : (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <div className="table-fit-wrapper">
            <table className="table-fit">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="py-3 px-6 text-left">
                    <button onClick={() => handleSort('mo_number')} className="flex items-center gap-1 text-xs font-medium text-gray-700 hover:text-gray-900">
                      MO # <SortIcon col="mo_number" />
                    </button>
                  </th>
                  <th className="py-3 px-6 text-left text-xs font-medium text-gray-700">Product</th>
                  <th className="py-3 px-6 text-left">
                    <button onClick={() => handleSort('customer_name')} className="flex items-center gap-1 text-xs font-medium text-gray-700 hover:text-gray-900">
                      Customer <SortIcon col="customer_name" />
                    </button>
                  </th>
                  <th className="py-3 px-6 text-left text-xs font-medium text-gray-700">Stations</th>
                  <th className="py-3 px-6 text-left">
                    <button onClick={() => handleSort('status')} className="flex items-center gap-1 text-xs font-medium text-gray-700 hover:text-gray-900">
                      Status <SortIcon col="status" />
                    </button>
                  </th>
                  <th className="py-3 px-6 text-left">
                    <button onClick={() => handleSort('progress')} className="flex items-center gap-1 text-xs font-medium text-gray-700 hover:text-gray-900">
                      Progress <SortIcon col="progress" />
                    </button>
                  </th>
                  <th className="py-3 px-6 text-left text-xs font-medium text-gray-700">Due Date</th>
                  <th className="py-3 px-6 text-right text-xs font-medium text-gray-700">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filtered.map((wo) => {
                  const pct = wo.total_lines > 0 ? Math.round((wo.completed_lines / wo.total_lines) * 100) : 0;
                  return (
                    <tr
                      key={wo.mo_id}
                      className="hover:bg-gray-50 cursor-pointer transition-colors"
                      onClick={() => router.navigate(`/manufacturing/work-orders/${wo.mo_id}`)}
                    >
                      <td className="py-4 px-6">
                        <span className="text-sm font-medium text-gray-900">{wo.mo_number}</span>
                      </td>
                      <td className="py-4 px-6 text-sm text-gray-700 max-w-[200px] truncate">{wo.product_name}</td>
                      <td className="py-4 px-6 text-sm text-gray-700">{wo.customer_name}</td>
                      <td className="py-4 px-6">
                        <div className="flex gap-1 flex-wrap">
                          {wo.stations.map((s, i) => {
                            const color = s.status === 'completed' ? 'bg-green-100 text-green-700'
                              : s.status === 'in_progress' ? 'bg-blue-100 text-blue-700'
                              : 'bg-gray-100 text-gray-500';
                            return (
                              <span key={i} className={`inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium ${color}`}>
                                {s.code}
                              </span>
                            );
                          })}
                        </div>
                      </td>
                      <td className="py-4 px-6">
                        <StatusBadge status={wo.global_status} type="workOrder" size="sm" />
                      </td>
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-2">
                          <div className="w-16 h-1.5 bg-gray-200 rounded-full overflow-hidden">
                            <div
                              className={`h-full rounded-full transition-all ${pct === 100 ? 'bg-green-500' : pct > 0 ? 'bg-blue-500' : 'bg-gray-300'}`}
                              style={{ width: `${pct}%` }}
                            />
                          </div>
                          <span className="text-xs text-gray-500 tabular-nums">{wo.completed_lines}/{wo.total_lines}</span>
                        </div>
                      </td>
                      <td className="py-4 px-6 text-sm text-gray-500">
                        {wo.due_date ? new Date(wo.due_date).toLocaleDateString() : '—'}
                      </td>
                      <td className="py-4 px-6 text-right">
                        <button
                          onClick={(e) => { e.stopPropagation(); router.navigate(`/manufacturing/work-orders/${wo.mo_id}`); }}
                          className="p-1.5 rounded hover:bg-gray-200 text-gray-400 hover:text-gray-600"
                          title="View detail"
                        >
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
