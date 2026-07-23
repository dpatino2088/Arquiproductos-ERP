import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { formatDate } from '../../lib/utils';
import { withReturnTo } from '../../lib/navigation/returnTo';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { usePurchaseOrders, PurchaseOrderStatus } from '../../hooks/usePurchaseOrders';
import { useWarehouses } from '../../hooks/useWarehouses';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { usePermissions } from '../../hooks/usePermissions';
import { Search, SortAsc, SortDesc, Plus } from 'lucide-react';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../../components/ui/SelectShadcn';

import { INVENTORY_SUBMODULES } from './inventorySubmodules';

const STATUS_COLORS: Record<string, string> = {
  DRAFT: 'bg-gray-100 text-gray-600',
  OPEN: 'bg-blue-50 text-blue-700',
  PARTIAL: 'bg-yellow-50 text-yellow-700',
  CLOSED: 'bg-green-50 text-green-700',
  CANCELLED: 'bg-red-50 text-red-600',
  ARCHIVED: 'bg-slate-100 text-slate-500',
};

function fmtCurrency(v: number, currency = 'USD'): string {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(v);
}

export default function PurchaseOrders() {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { can } = usePermissions();
  const canManagePOs = can('inventory.purchase_orders.write');
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
        {canManagePOs && (
          <button
            type="button"
            onClick={() => router.navigate('/inventory/purchase-orders/new')}
            className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-gray-800 rounded-lg hover:bg-gray-700"
          >
            <Plus className="w-4 h-4" />
            New Purchase Order
          </button>
        )}
      </div>

      <div className="mb-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center justify-between gap-3 flex-wrap">
            <div className="flex-1 relative min-w-[240px]">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search by PO number..."
                value={searchTerm}
                onChange={(e) => { setSearchTerm(e.target.value); setCurrentPage(1); }}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search purchase orders"
              />
            </div>
            <div className="flex items-center gap-2">
              <div className="w-[170px] shrink-0">
            <Select
              value={statusFilter || '__all__'}
              onValueChange={(v) => { setStatusFilter(v === '__all__' ? '' : v as PurchaseOrderStatus); setCurrentPage(1); }}
            >
              <SelectTrigger className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px]">
                <SelectValue placeholder="All Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="__all__">All Status</SelectItem>
                <SelectItem value="DRAFT">Draft</SelectItem>
                <SelectItem value="OPEN">Open</SelectItem>
                <SelectItem value="PARTIAL">Partial</SelectItem>
                <SelectItem value="CLOSED">Closed</SelectItem>
                <SelectItem value="CANCELLED">Cancelled</SelectItem>
                <SelectItem value="ARCHIVED">Archived</SelectItem>
              </SelectContent>
            </Select>
              </div>
              {warehouses.length > 1 && (
                <div className="w-[190px] shrink-0">
                  <Select
                    value={warehouseFilter || '__all__'}
                    onValueChange={(v) => { setWarehouseFilter(v === '__all__' ? '' : v); setCurrentPage(1); }}
                  >
                    <SelectTrigger className="px-3 py-1 border border-gray-200 rounded text-sm bg-white min-h-[32px]">
                      <SelectValue placeholder="All Warehouses" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="__all__">All Warehouses</SelectItem>
                      {warehouses.map(w => (
                        <SelectItem key={w.id} value={w.id}>{w.name}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              )}
            </div>
          </div>
        </div>
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
                <th className="px-4 py-3 text-center font-medium text-gray-700">Billing</th>
              </tr>
            </thead>
            <tbody>
              {paginated.length === 0 ? (
                <tr><td colSpan={9} className="px-4 py-8 text-center text-gray-500">No purchase orders found</td></tr>
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
                    {formatDate(po.expected_date)}
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
                  <td className="px-4 py-3 text-center">
                    {(() => {
                      const bs = (po as unknown as Record<string, unknown>).billing_status as string | undefined;
                      if (!bs || bs === 'unbilled') return <span className="text-xs text-gray-400">Unbilled</span>;
                      const colors: Record<string, string> = { partial: 'bg-amber-100 text-amber-700', billed: 'bg-green-100 text-green-700' };
                      return <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${colors[bs] ?? 'bg-gray-100 text-gray-700'}`}>{bs.charAt(0).toUpperCase() + bs.slice(1)}</span>;
                    })()}
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
