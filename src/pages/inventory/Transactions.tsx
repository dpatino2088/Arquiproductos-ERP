import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useInventoryMovements, MovementType, MovementStatus } from '../../hooks/useInventoryMovements';
import { supabase } from '../../lib/supabase/client';
import { Search, SortAsc, SortDesc, Plus } from 'lucide-react';
import Input from '../../components/ui/Input';

interface TransactionsProps {
  defaultTypeFilter?: MovementType;
  title?: string;
}

const INVENTORY_SUBMODULES = [
  { id: 'warehouse', label: 'Warehouse', href: '/inventory/warehouse' },
  { id: 'purchase-orders', label: 'Purchase Orders', href: '/inventory/purchase-orders' },
  { id: 'receipts', label: 'Receipts', href: '/inventory/receipts' },
  { id: 'transactions', label: 'Transactions', href: '/inventory/transactions' },
  { id: 'adjustments', label: 'Adjustments', href: '/inventory/adjustments' },
  { id: 'material-demand', label: 'Material Demand', href: '/inventory/material-demand' },
];

const TYPE_LABELS: Record<string, string> = {
  receipt: 'Receipt',
  issue_to_production: 'Issue to Production',
  transfer: 'Transfer',
  adjustment: 'Adjustment',
  return: 'Return',
};

const TYPE_COLORS: Record<string, string> = {
  receipt: 'bg-green-50 text-green-700',
  issue_to_production: 'bg-blue-50 text-blue-700',
  transfer: 'bg-purple-50 text-purple-700',
  adjustment: 'bg-yellow-50 text-yellow-700',
  return: 'bg-orange-50 text-orange-700',
};

export default function Transactions({ defaultTypeFilter, title }: TransactionsProps = {}) {
  const { registerSubmodules } = useSubmoduleNav();
  const { movements, loading, refetch } = useInventoryMovements(
    defaultTypeFilter ? { movementType: defaultTypeFilter } : undefined
  );
  const [searchTerm, setSearchTerm] = useState('');
  const [typeFilter, setTypeFilter] = useState<MovementType | ''>(defaultTypeFilter ?? '');
  const [statusFilter, setStatusFilter] = useState<MovementStatus | ''>('');
  const [sortBy, setSortBy] = useState<'movement_no' | 'movement_date' | 'movement_type'>('movement_date');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 25;

  const [moNumberMap, setMoNumberMap] = useState<Map<string, string>>(new Map());

  useEffect(() => {
    registerSubmodules('Inventory', INVENTORY_SUBMODULES);
  }, [registerSubmodules]);

  useEffect(() => {
    const moIds = movements
      .filter(m => m.reference_type === 'manufacturing_order' && m.reference_id)
      .map(m => m.reference_id!);
    const uniqueIds = [...new Set(moIds)];
    if (uniqueIds.length === 0) { setMoNumberMap(new Map()); return; }
    supabase
      .from('ManufacturingOrders')
      .select('id, manufacturing_order_no')
      .in('id', uniqueIds)
      .then((res: { data: { id: string; manufacturing_order_no: string }[] | null }) => {
        const map = new Map<string, string>();
        (res.data ?? []).forEach((r) => map.set(r.id, r.manufacturing_order_no));
        setMoNumberMap(map);
      });
  }, [movements]);

  const filtered = useMemo(() => {
    let result = [...movements];
    if (searchTerm) {
      const q = searchTerm.toLowerCase();
      result = result.filter(m =>
        (m.movement_no ?? '').toLowerCase().includes(q) ||
        (m.notes ?? '').toLowerCase().includes(q) ||
        (m.Warehouses?.name ?? '').toLowerCase().includes(q)
      );
    }
    if (typeFilter) result = result.filter(m => m.movement_type === typeFilter);
    if (statusFilter) result = result.filter(m => m.status === statusFilter);

    result.sort((a, b) => {
      let cmp = 0;
      if (sortBy === 'movement_no') cmp = (a.movement_no ?? '').localeCompare(b.movement_no ?? '');
      else if (sortBy === 'movement_date') cmp = (a.movement_date ?? '').localeCompare(b.movement_date ?? '');
      else if (sortBy === 'movement_type') cmp = a.movement_type.localeCompare(b.movement_type);
      return sortOrder === 'asc' ? cmp : -cmp;
    });
    return result;
  }, [movements, searchTerm, typeFilter, statusFilter, sortBy, sortOrder]);

  const totalPages = Math.ceil(filtered.length / itemsPerPage);
  const paginated = filtered.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const handleSort = (col: typeof sortBy) => {
    if (sortBy === col) setSortOrder(o => o === 'asc' ? 'desc' : 'asc');
    else { setSortBy(col); setSortOrder('desc'); }
  };

  const SortIcon = ({ col }: { col: typeof sortBy }) => {
    if (sortBy !== col) return null;
    return sortOrder === 'asc' ? <SortAsc className="w-3.5 h-3.5 inline ml-1" /> : <SortDesc className="w-3.5 h-3.5 inline ml-1" />;
  };

  return (
    <div className="py-6 px-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">{title ?? 'Inventory Transactions'}</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {movements.length} transaction{movements.length === 1 ? '' : 's'}
          </p>
        </div>
        <button
          type="button"
          onClick={() => router.navigate('/inventory/transactions/new')}
          className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-gray-800 rounded-lg hover:bg-gray-700"
        >
          <Plus className="w-4 h-4" />
          New Transaction
        </button>
      </div>

      {/* Filters */}
      <div className="mb-4 flex items-center gap-3 flex-wrap">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <Input
            type="text"
            placeholder="Search by movement #, notes, warehouse..."
            value={searchTerm}
            onChange={e => { setSearchTerm(e.target.value); setCurrentPage(1); }}
            className="pl-10"
          />
        </div>
        <select
          value={typeFilter}
          onChange={e => { setTypeFilter(e.target.value as any); setCurrentPage(1); }}
          className="px-3 py-2 border border-gray-300 rounded-lg text-sm bg-white"
        >
          <option value="">All Types</option>
          <option value="receipt">Receipt</option>
          <option value="issue_to_production">Issue to Production</option>
          <option value="transfer">Transfer</option>
          <option value="adjustment">Adjustment</option>
          <option value="return">Return</option>
        </select>
        <select
          value={statusFilter}
          onChange={e => { setStatusFilter(e.target.value as any); setCurrentPage(1); }}
          className="px-3 py-2 border border-gray-300 rounded-lg text-sm bg-white"
        >
          <option value="">All Status</option>
          <option value="draft">Draft</option>
          <option value="confirmed">Confirmed</option>
        </select>
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
                  Movement # <SortIcon col="movement_no" />
                </th>
                <th className="px-4 py-3 text-left font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('movement_type')}>
                  Type <SortIcon col="movement_type" />
                </th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Warehouse</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Reference</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('movement_date')}>
                  Date <SortIcon col="movement_date" />
                </th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Status</th>
              </tr>
            </thead>
            <tbody>
              {paginated.length === 0 ? (
                <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-500">No transactions found</td></tr>
              ) : paginated.map(m => (
                <tr
                  key={m.id}
                  className="border-t hover:bg-gray-50 cursor-pointer"
                  onClick={() => {
                    sessionStorage.setItem('currentTransactionId', m.id);
                    router.navigate(`/inventory/transactions/${m.id}`);
                  }}
                >
                  <td className="px-4 py-3 font-medium text-gray-900">{m.movement_no ?? '—'}</td>
                  <td className="px-4 py-3">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${TYPE_COLORS[m.movement_type] ?? 'bg-gray-50 text-gray-700'}`}>
                      {TYPE_LABELS[m.movement_type] ?? m.movement_type}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-gray-700">{m.Warehouses?.name ?? '—'}</td>
                  <td className="px-4 py-3 text-xs">
                    {m.reference_type === 'manufacturing_order' && m.reference_id ? (
                      <button
                        type="button"
                        onClick={(e) => { e.stopPropagation(); router.navigate(`/manufacturing/manufacturing-orders/${m.reference_id}`); }}
                        className="text-primary hover:underline font-medium"
                      >
                        {moNumberMap.get(m.reference_id) ?? m.reference_id.slice(0, 8)}
                      </button>
                    ) : m.reference_type ? (
                      <span className="text-gray-600">{m.reference_type}</span>
                    ) : '—'}
                  </td>
                  <td className="px-4 py-3 text-gray-700">{m.movement_date ? new Date(m.movement_date).toLocaleDateString() : '—'}</td>
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
