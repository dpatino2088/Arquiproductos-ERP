import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { withReturnTo } from '../../lib/navigation/returnTo';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { usePurchaseOrders, PurchaseOrderStatus } from '../../hooks/usePurchaseOrders';
import { useWarehouses } from '../../hooks/useWarehouses';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { Search, SortAsc, SortDesc, Plus } from 'lucide-react';
import Input from '../../components/ui/Input';

const INVENTORY_SUBMODULES = [
  { id: 'warehouse', label: 'Warehouse', href: '/inventory/warehouse' },
  { id: 'purchase-orders', label: 'Purchase Orders', href: '/inventory/purchase-orders' },
  { id: 'receipts', label: 'Receipts', href: '/inventory/receipts' },
  { id: 'transactions', label: 'Transactions', href: '/inventory/transactions' },
  { id: 'adjustments', label: 'Adjustments', href: '/inventory/adjustments' },
  { id: 'material-demand', label: 'Material Demand', href: '/inventory/material-demand' },
];

const STATUS_COLORS: Record<string, string> = {
  OPEN: 'bg-blue-50 text-blue-700',
  PARTIAL: 'bg-yellow-50 text-yellow-700',
  CLOSED: 'bg-green-50 text-green-700',
};

function fmtCurrency(v: number, currency = 'USD'): string {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(v);
}

export default function PurchaseOrders() {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { warehouses } = useWarehouses(activeOrganizationId);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<PurchaseOrderStatus | ''>('');
  const [warehouseFilter, setWarehouseFilter] = useState('');
  const [sortBy, setSortBy] = useState<'po_number' | 'expected_date' | 'status' | 'created_at' | 'total'>('created_at');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 25;

  const { purchaseOrders, loading, error } = usePurchaseOrders({
    status: statusFilter || undefined,
    warehouseId: warehouseFilter || undefined,
    search: searchTerm || undefined,
  });

  useEffect(() => {
    registerSubmodules('Inventory', INVENTORY_SUBMODULES);
  }, [registerSubmodules]);

  const filtered = useMemo(() => {
    let result = [...purchaseOrders];
    result.sort((a, b) => {
      let cmp = 0;
      if (sortBy === 'po_number') cmp = (a.po_number ?? '').localeCompare(b.po_number ?? '');
      else if (sortBy === 'expected_date') cmp = (a.expected_date ?? '').localeCompare(b.expected_date ?? '');
      else if (sortBy === 'status') cmp = a.status.localeCompare(b.status);
      else if (sortBy === 'created_at') cmp = a.created_at.localeCompare(b.created_at);
      else if (sortBy === 'total') cmp = (a.total ?? 0) - (b.total ?? 0);
      return sortOrder === 'asc' ? cmp : -cmp;
    });
    return result;
  }, [purchaseOrders, sortBy, sortOrder]);

  const totalPages = Math.ceil(filtered.length / itemsPerPage);
  const paginated = filtered.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const handleSort = (col: typeof sortBy) => {
    if (sortBy === col) setSortOrder(o => o === 'asc' ? 'desc' : 'asc');
    else { setSortBy(col); setSortOrder(sortBy === 'created_at' ? 'desc' : 'asc'); }
  };

  const SortIcon = ({ col }: { col: typeof sortBy }) => {
    if (sortBy !== col) return null;
    return sortOrder === 'asc' ? <SortAsc className="w-3.5 h-3.5 inline ml-1" /> : <SortDesc className="w-3.5 h-3.5 inline ml-1" />;
  };

  const lineCount = (po: { PurchaseOrderLines?: { id: string }[] }) =>
    po.PurchaseOrderLines?.length ?? 0;

  const refLabel = (po: { PurchaseOrderLines?: { id: string; allocation_type?: string; allocation_mo_id?: string | null }[] }) => {
    const poLines = po.PurchaseOrderLines ?? [];
    const moIds = new Set(poLines.filter(l => l.allocation_type === 'manufacturing_order' && l.allocation_mo_id).map(l => l.allocation_mo_id!));
    if (moIds.size > 1) return `MO×${moIds.size}`;
    if (moIds.size === 1) return 'MO';
    return null;
  };

  return (
    <div className="py-6 px-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Purchase Orders</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {purchaseOrders.length} purchase order{purchaseOrders.length === 1 ? '' : 's'}
          </p>
        </div>
        <button
          type="button"
          onClick={() => router.navigate('/inventory/purchase-orders/new')}
          className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-gray-800 rounded-lg hover:bg-gray-700"
        >
          <Plus className="w-4 h-4" />
          New Purchase Order
        </button>
      </div>

      <div className="mb-4 flex items-center gap-3 flex-wrap">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <Input
            type="text"
            placeholder="Search by PO number..."
            value={searchTerm}
            onChange={e => { setSearchTerm(e.target.value); setCurrentPage(1); }}
            className="pl-10"
          />
        </div>
        <select
          value={statusFilter}
          onChange={e => { setStatusFilter(e.target.value as PurchaseOrderStatus | ''); setCurrentPage(1); }}
          className="px-3 py-2 border border-gray-300 rounded-lg text-sm bg-white"
        >
          <option value="">All Status</option>
          <option value="OPEN">Open</option>
          <option value="PARTIAL">Partial</option>
          <option value="CLOSED">Closed</option>
        </select>
        {warehouses.length > 1 && (
          <select
            value={warehouseFilter}
            onChange={e => { setWarehouseFilter(e.target.value); setCurrentPage(1); }}
            className="px-3 py-2 border border-gray-300 rounded-lg text-sm bg-white"
          >
            <option value="">All Warehouses</option>
            {warehouses.map(w => (
              <option key={w.id} value={w.id}>{w.name}</option>
            ))}
          </select>
        )}
      </div>

      {error && (
        <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          <strong>Error loading purchase orders:</strong> {error}
        </div>
      )}

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
                <th className="px-4 py-3 text-left font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('po_number')}>
                  PO # <SortIcon col="po_number" />
                </th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Vendor</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Warehouse</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('expected_date')}>
                  Expected Date <SortIcon col="expected_date" />
                </th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Lines</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('total')}>
                  Total <SortIcon col="total" />
                </th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Ref</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('status')}>
                  Status <SortIcon col="status" />
                </th>
              </tr>
            </thead>
            <tbody>
              {paginated.length === 0 ? (
                <tr><td colSpan={8} className="px-4 py-8 text-center text-gray-500">No purchase orders found</td></tr>
              ) : paginated.map(po => (
                <tr
                  key={po.id}
                  className="border-t hover:bg-gray-50 cursor-pointer"
                  onClick={() => router.navigate(withReturnTo(`/inventory/purchase-orders/${po.id}`))}
                >
                  <td className="px-4 py-3 font-medium text-gray-900">{po.po_number ?? '—'}</td>
                  <td className="px-4 py-3 text-gray-700">{po.DirectoryVendors?.name ?? '—'}</td>
                  <td className="px-4 py-3 text-gray-700">{po.Warehouses?.name ?? '—'}</td>
                  <td className="px-4 py-3 text-gray-700">
                    {po.expected_date ? new Date(po.expected_date).toLocaleDateString() : '—'}
                  </td>
                  <td className="px-4 py-3 text-center text-gray-600">{lineCount(po)}</td>
                  <td className="px-4 py-3 text-right font-mono tabular-nums text-gray-900">
                    {(po.total ?? 0) > 0 ? fmtCurrency(po.total, po.currency) : '—'}
                  </td>
                  <td className="px-4 py-3 text-center">
                    {refLabel(po) ? (
                      <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-indigo-50 text-indigo-700">
                        {refLabel(po)}
                      </span>
                    ) : ''}
                  </td>
                  <td className="px-4 py-3">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${STATUS_COLORS[po.status] ?? 'bg-gray-50 text-gray-700'}`}>
                      {po.status}
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
