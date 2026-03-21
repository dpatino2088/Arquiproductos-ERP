import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { formatDate } from '../../lib/utils';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useInventoryMovements, ADJUSTMENT_REASON_LABELS, AdjustmentReason } from '../../hooks/useInventoryMovements';
import { Search, SortAsc, SortDesc, Plus } from 'lucide-react';
import Input from '../../components/ui/Input';
import StatusTabs from '../../components/shared/StatusTabs';

const INVENTORY_SUBMODULES = [
  { id: 'warehouse', label: 'Warehouse', href: '/inventory/warehouse' },
  { id: 'purchase-orders', label: 'Purchase Orders', href: '/inventory/purchase-orders' },
  { id: 'receipts', label: 'Receipts', href: '/inventory/receipts' },
  { id: 'transactions', label: 'Transactions', href: '/inventory/transactions' },
  { id: 'adjustments', label: 'Adjustments', href: '/inventory/adjustments' },
  { id: 'material-demand', label: 'Material Demand', href: '/inventory/material-demand' },
];

type SortCol = 'movement_no' | 'movement_date' | 'adjustment_reason';

export default function Adjustments() {
  const { registerSubmodules } = useSubmoduleNav();
  const { movements, loading } = useInventoryMovements({ movementType: 'adjustment' });

  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [sortBy, setSortBy] = useState<SortCol>('movement_date');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 25;

  useEffect(() => {
    registerSubmodules('Inventory', INVENTORY_SUBMODULES);
  }, [registerSubmodules]);

  const statusCounts = useMemo(() => {
    let all = 0, draft = 0, confirmed = 0;
    for (const m of movements) {
      all++;
      if (m.status === 'draft') draft++;
      else if (m.status === 'confirmed') confirmed++;
    }
    return { all, draft, confirmed };
  }, [movements]);

  const statusTabs = useMemo(() => [
    { label: 'All', value: 'all', count: statusCounts.all },
    { label: 'Draft', value: 'draft', count: statusCounts.draft },
    { label: 'Confirmed', value: 'confirmed', count: statusCounts.confirmed },
  ], [statusCounts]);

  const filtered = useMemo(() => {
    let result = [...movements];
    if (statusFilter !== 'all') result = result.filter(m => m.status === statusFilter);
    if (searchTerm) {
      const q = searchTerm.toLowerCase();
      result = result.filter(m =>
        (m.movement_no ?? '').toLowerCase().includes(q) ||
        (m.notes ?? '').toLowerCase().includes(q) ||
        (m.Warehouses?.name ?? '').toLowerCase().includes(q) ||
        (m.adjustment_reason ? (ADJUSTMENT_REASON_LABELS[m.adjustment_reason as AdjustmentReason] ?? '').toLowerCase().includes(q) : false)
      );
    }
    result.sort((a, b) => {
      let cmp = 0;
      if (sortBy === 'movement_no') cmp = (a.movement_no ?? '').localeCompare(b.movement_no ?? '');
      else if (sortBy === 'movement_date') cmp = (a.movement_date ?? '').localeCompare(b.movement_date ?? '');
      else if (sortBy === 'adjustment_reason') cmp = (a.adjustment_reason ?? '').localeCompare(b.adjustment_reason ?? '');
      return sortOrder === 'asc' ? cmp : -cmp;
    });
    return result;
  }, [movements, searchTerm, statusFilter, sortBy, sortOrder]);

  const totalPages = Math.ceil(filtered.length / itemsPerPage);
  const paginated = filtered.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const handleSort = (col: SortCol) => {
    if (sortBy === col) setSortOrder(o => o === 'asc' ? 'desc' : 'asc');
    else { setSortBy(col); setSortOrder('desc'); }
  };

  const SortIcon = ({ col }: { col: SortCol }) => {
    if (sortBy !== col) return null;
    return sortOrder === 'asc' ? <SortAsc className="w-3.5 h-3.5 inline ml-1" /> : <SortDesc className="w-3.5 h-3.5 inline ml-1" />;
  };

  return (
    <div className="py-6 px-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Adjustments</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {statusCounts.all} adjustment{statusCounts.all === 1 ? '' : 's'}
          </p>
        </div>
        <button
          type="button"
          onClick={() => router.navigate('/inventory/adjustments/new')}
          className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-gray-800 rounded-lg hover:bg-gray-700"
        >
          <Plus className="w-4 h-4" />
          New Adjustment
        </button>
      </div>

      <StatusTabs
        tabs={statusTabs}
        activeTab={statusFilter}
        onChange={(val) => { setStatusFilter(val); setCurrentPage(1); }}
      />

      <div className="mb-4 flex items-center gap-3 flex-wrap">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <Input
            type="text"
            placeholder="Search by adjustment #, notes, warehouse, reason..."
            value={searchTerm}
            onChange={e => { setSearchTerm(e.target.value); setCurrentPage(1); }}
            className="pl-10"
          />
        </div>
      </div>

      {loading ? (
        <div className="animate-pulse space-y-3">
          <div className="h-10 bg-gray-100 rounded" />
          <div className="h-10 bg-gray-100 rounded" />
          <div className="h-10 bg-gray-100 rounded" />
        </div>
      ) : (
        <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('movement_no')}>
                  Adjustment # <SortIcon col="movement_no" />
                </th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Warehouse</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('adjustment_reason')}>
                  Reason <SortIcon col="adjustment_reason" />
                </th>
                <th className="px-4 py-3 text-left font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('movement_date')}>
                  Date <SortIcon col="movement_date" />
                </th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Status</th>
              </tr>
            </thead>
            <tbody>
              {paginated.length === 0 ? (
                <tr><td colSpan={5} className="px-4 py-8 text-center text-gray-500">No adjustments found</td></tr>
              ) : paginated.map(m => (
                <tr
                  key={m.id}
                  className="border-t hover:bg-gray-50 cursor-pointer"
                  onClick={() => {
                    sessionStorage.setItem('currentTransactionId', m.id);
                    router.navigate(`/inventory/adjustments/${m.id}`);
                  }}
                >
                  <td className="px-4 py-3 font-medium text-gray-900">{m.movement_no ?? '—'}</td>
                  <td className="px-4 py-3 text-gray-700">{m.Warehouses?.name ?? '—'}</td>
                  <td className="px-4 py-3 text-gray-600">
                    {m.adjustment_reason
                      ? (
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-yellow-50 text-yellow-700">
                          {ADJUSTMENT_REASON_LABELS[m.adjustment_reason as AdjustmentReason] ?? m.adjustment_reason}
                        </span>
                      )
                      : <span className="text-gray-400">—</span>
                    }
                  </td>
                  <td className="px-4 py-3 text-gray-700">{formatDate(m.movement_date)}</td>
                  <td className="px-4 py-3 text-center">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${m.status === 'confirmed' ? 'bg-green-50 text-green-700' : 'bg-yellow-50 text-yellow-700'}`}>
                      {m.status === 'confirmed' ? 'Confirmed' : 'Draft'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {totalPages > 1 && (
        <div className="flex items-center justify-between mt-4 text-sm text-gray-600">
          <span>Page {currentPage} of {totalPages} ({filtered.length} results)</span>
          <div className="flex gap-2">
            <button disabled={currentPage <= 1} onClick={() => setCurrentPage(p => p - 1)} className="px-3 py-1 border rounded disabled:opacity-50">Prev</button>
            <button disabled={currentPage >= totalPages} onClick={() => setCurrentPage(p => p + 1)} className="px-3 py-1 border rounded disabled:opacity-50">Next</button>
          </div>
        </div>
      )}
    </div>
  );
}
