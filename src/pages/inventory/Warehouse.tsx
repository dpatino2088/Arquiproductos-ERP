import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useWarehouses } from '../../hooks/useWarehouses';
import { supabase } from '../../lib/supabase/client';
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useActiveDealer } from '../../hooks/useActiveDealer';
import { useAccessContext } from '../../hooks/useAccessContext';
import { buildDirectoryScopeKey } from '../../lib/directoryScopeKey';
import { warehouseStockListKey } from '../../lib/queryKeys';
import {
  Search,
  SortAsc,
  SortDesc,
  Eye,
} from 'lucide-react';
import Input from '../../components/ui/Input';

const INVENTORY_SUBMODULES = [
  { id: 'warehouse', label: 'Warehouse', href: '/inventory/warehouse' },
  { id: 'purchase-orders', label: 'Purchase Orders', href: '/inventory/purchase-orders' },
  { id: 'receipts', label: 'Receipts', href: '/inventory/receipts' },
  { id: 'transactions', label: 'Transactions', href: '/inventory/transactions' },
  { id: 'adjustments', label: 'Adjustments', href: '/inventory/adjustments' },
  { id: 'material-demand', label: 'Material Demand', href: '/inventory/material-demand' },
];

interface StockRow {
  id: string;
  catalogItemId: string;
  sku: string;
  itemName: string;
  uom: string;
  category: string | null;
  onHand: number;
  warehouseName: string;
  onOrder: number;
  assigned: number;
  required: number;
  available: number;
  balance: number;
}

const getBalanceBadgeColor = (balance: number, required: number) => {
  if (balance >= 0) return 'bg-green-50 text-green-700';
  const threshold = Math.abs(Number(required) || 0) * 0.1;
  if (Math.abs(balance) <= threshold) return 'bg-orange-50 text-orange-700';
  return 'bg-red-50 text-red-700';
};

export default function Warehouse() {
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { activeDealerId } = useActiveDealer();
  const { userType } = useAccessContext();
  const { warehouses, defaultWarehouse } = useWarehouses(activeOrganizationId);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedWarehouseId, setSelectedWarehouseId] = useState<string>('');
  const [sortBy, setSortBy] = useState<'sku' | 'itemName' | 'onHand' | 'available' | 'balance'>('sku');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 25;

  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/inventory')) {
      registerSubmodules('Inventory', INVENTORY_SUBMODULES);
    }
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/inventory')) clearSubmoduleNav();
    };
  }, [registerSubmodules, clearSubmoduleNav]);

  const effectiveWarehouseId = selectedWarehouseId || defaultWarehouse?.id || '';
  const scopeKey = useMemo(
    () =>
      buildDirectoryScopeKey({
        orgId: activeOrganizationId ?? null,
        activeDealerId: activeDealerId ?? null,
        userRole: userType,
      }),
    [activeOrganizationId, activeDealerId, userType]
  );

  const { data: stockRows, isLoading, isFetching } = useQuery({
    queryKey: warehouseStockListKey(scopeKey, effectiveWarehouseId || 'all'),
    queryFn: async (): Promise<StockRow[]> => {
      if (!activeOrganizationId) return [];

      let balanceQuery = supabase
        .from('InventoryBalances')
        .select('catalog_item_id, quantity, warehouse_id, Warehouses(name), CatalogItems(sku, name, unit_of_measure, is_roll, CatalogCategories(name))')
        .eq('organization_id', activeOrganizationId);

      if (effectiveWarehouseId) {
        balanceQuery = balanceQuery.eq('warehouse_id', effectiveWarehouseId);
      }

      const { data: balances, error } = await balanceQuery;
      if (error) throw error;
      if (!balances?.length) return [];

      const catalogIds = [...new Set((balances as any[]).map(b => b.catalog_item_id))];

      const onOrderMap = new Map<string, number>();
      const requiredMap = new Map<string, number>();
      const assignedMap = new Map<string, number>();
      if (catalogIds.length > 0) {
        const { data: onOrderRows, error: onOrderError } = await supabase
          .from('inventory_on_order')
          .select('catalog_item_id, on_order_qty')
          .eq('organization_id', activeOrganizationId)
          .in('catalog_item_id', catalogIds);
        if (onOrderError) throw onOrderError;
        (onOrderRows ?? []).forEach((r: any) => {
          onOrderMap.set(r.catalog_item_id, (onOrderMap.get(r.catalog_item_id) || 0) + Number(r.on_order_qty || 0));
        });

        const { data: demandRows, error: demandError } = await supabase
          .from('manufacturing_order_material_demand')
          .select('catalog_item_id, required_qty')
          .eq('organization_id', activeOrganizationId)
          .in('catalog_item_id', catalogIds)
          .in('mo_status', ['draft', 'planned', 'quality_check']);
        if (demandError) throw demandError;

        (demandRows ?? []).forEach((r: any) => {
          const qty = Number(r.required_qty ?? 0);
          requiredMap.set(r.catalog_item_id, (requiredMap.get(r.catalog_item_id) || 0) + qty);
          // Soft reservation model: assigned is planning allocation and can be reassigned.
          assignedMap.set(r.catalog_item_id, (assignedMap.get(r.catalog_item_id) || 0) + qty);
        });
      }

      return (balances as any[]).map(b => ({
        id: b.catalog_item_id + ':' + b.warehouse_id,
        catalogItemId: b.catalog_item_id,
        sku: b.CatalogItems?.sku ?? '—',
        itemName: b.CatalogItems?.name ?? '—',
        uom: b.CatalogItems?.is_roll ? 'm' : (b.CatalogItems?.unit_of_measure ?? 'ea'),
        category: b.CatalogItems?.CatalogCategories?.name ?? null,
        onHand: Number(b.quantity ?? 0),
        warehouseName: b.Warehouses?.name ?? '—',
        onOrder: onOrderMap.get(b.catalog_item_id) ?? 0,
        assigned: assignedMap.get(b.catalog_item_id) ?? 0,
        required: requiredMap.get(b.catalog_item_id) ?? 0,
        available: Number(b.quantity ?? 0) - (assignedMap.get(b.catalog_item_id) ?? 0),
        balance: Number(b.quantity ?? 0) + (onOrderMap.get(b.catalog_item_id) ?? 0) - (requiredMap.get(b.catalog_item_id) ?? 0),
      }));
    },
    enabled: !!activeOrganizationId,
    placeholderData: keepPreviousData,
    refetchOnMount: false,
  });

  const hasData = (stockRows?.length ?? 0) > 0;

  const filtered = useMemo(() => {
    let rows = stockRows ?? [];
    if (searchTerm) {
      const q = searchTerm.toLowerCase();
      rows = rows.filter(r =>
        r.sku.toLowerCase().includes(q) ||
        r.itemName.toLowerCase().includes(q) ||
        (r.category ?? '').toLowerCase().includes(q)
      );
    }
    rows.sort((a, b) => {
      let cmp = 0;
      if (sortBy === 'sku') cmp = a.sku.localeCompare(b.sku);
      else if (sortBy === 'itemName') cmp = a.itemName.localeCompare(b.itemName);
      else if (sortBy === 'onHand') cmp = a.onHand - b.onHand;
      else if (sortBy === 'available') cmp = a.available - b.available;
      else if (sortBy === 'balance') cmp = a.balance - b.balance;
      return sortOrder === 'asc' ? cmp : -cmp;
    });
    return rows;
  }, [stockRows, searchTerm, sortBy, sortOrder]);

  const totalPages = Math.ceil(filtered.length / itemsPerPage);
  const paginated = filtered.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const handleSort = (col: typeof sortBy) => {
    if (sortBy === col) setSortOrder(o => o === 'asc' ? 'desc' : 'asc');
    else { setSortBy(col); setSortOrder('asc'); }
  };

  const SortIcon = ({ col }: { col: typeof sortBy }) => {
    if (sortBy !== col) return null;
    return sortOrder === 'asc' ? <SortAsc className="w-3.5 h-3.5 inline ml-1" /> : <SortDesc className="w-3.5 h-3.5 inline ml-1" />;
  };

  return (
    <div className="py-6 px-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Warehouse Stock</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {filtered.length} item{filtered.length === 1 ? '' : 's'} in stock
          </p>
        </div>
      </div>

      {/* Filters */}
      <div className="mb-4 flex items-center gap-3 flex-wrap">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <Input
            type="text"
            placeholder="Search by SKU, item name, or category..."
            value={searchTerm}
            onChange={e => { setSearchTerm(e.target.value); setCurrentPage(1); }}
            className="pl-10"
          />
        </div>
        {warehouses.length > 1 && (
          <select
            value={selectedWarehouseId}
            onChange={e => { setSelectedWarehouseId(e.target.value); setCurrentPage(1); }}
            className="px-3 py-2 border border-gray-300 rounded-lg text-sm bg-white"
          >
            <option value="">All Warehouses</option>
            {warehouses.map(w => (
              <option key={w.id} value={w.id}>{w.name}</option>
            ))}
          </select>
        )}
      </div>

      {isLoading ? (
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
                <th className="px-4 py-3 text-left font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('sku')}>
                  SKU <SortIcon col="sku" />
                </th>
                <th className="px-4 py-3 text-left font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('itemName')}>
                  Item Name <SortIcon col="itemName" />
                </th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Category</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Warehouse</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('onHand')}>
                  On Hand <SortIcon col="onHand" />
                </th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">On Order</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Assigned</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Required</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('available')}>
                  Available <SortIcon col="available" />
                </th>
                <th className="px-4 py-3 text-right font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('balance')}>
                  Balance <SortIcon col="balance" />
                </th>
                <th className="px-4 py-3 text-center font-medium text-gray-700">Actions</th>
              </tr>
            </thead>
            <tbody>
              {paginated.length === 0 ? (
                <tr><td colSpan={12} className="px-4 py-8 text-center text-gray-500">No stock data found</td></tr>
              ) : paginated.map(row => (
                <tr
                  key={row.id}
                  className={`border-t hover:bg-gray-50 ${row.catalogItemId ? 'cursor-pointer' : ''}`}
                  tabIndex={row.catalogItemId ? 0 : -1}
                  onClick={() => {
                    if (!row.catalogItemId) return;
                    sessionStorage.setItem('currentInventoryItemId', row.catalogItemId);
                    router.navigate(`/inventory/items/${row.catalogItemId}`);
                  }}
                  onKeyDown={(e) => {
                    if (!row.catalogItemId) return;
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault();
                      sessionStorage.setItem('currentInventoryItemId', row.catalogItemId);
                      router.navigate(`/inventory/items/${row.catalogItemId}`);
                    }
                  }}
                >
                  <td className="px-4 py-3 font-medium text-gray-900">{row.sku}</td>
                  <td className="px-4 py-3 text-gray-700">{row.itemName}</td>
                  <td className="px-4 py-3 text-gray-600">{row.category ?? '—'}</td>
                  <td className="px-4 py-3 text-gray-600">{row.warehouseName}</td>
                  <td className="px-4 py-3 text-right tabular-nums">{Number(row.onHand).toFixed(2)}</td>
                  <td className="px-4 py-3 text-right tabular-nums text-gray-600">{row.onOrder > 0 ? Number(row.onOrder).toFixed(2) : '—'}</td>
                  <td className="px-4 py-3 text-right tabular-nums text-gray-600">{row.assigned > 0 ? Number(row.assigned).toFixed(2) : '—'}</td>
                  <td className="px-4 py-3 text-right tabular-nums text-gray-600">{row.required > 0 ? Number(row.required).toFixed(2) : '—'}</td>
                  <td className="px-4 py-3 text-right tabular-nums">{Number(row.available).toFixed(2)}</td>
                  <td className="px-4 py-3 text-right">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getBalanceBadgeColor(row.balance, row.required)}`}>
                      {Number(row.balance).toFixed(2)}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-center" onClick={(e) => e.stopPropagation()}>
                    <button
                      type="button"
                      onClick={() => {
                        sessionStorage.setItem('currentInventoryItemId', row.catalogItemId);
                        router.navigate(`/inventory/items/${row.catalogItemId}`);
                      }}
                      className="inline-flex items-center justify-center p-1.5 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded"
                      aria-label={`Open ${row.sku}`}
                      title={`Open ${row.sku}`}
                    >
                      <Eye className="w-4 h-4" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {hasData && isFetching ? (
            <div className="border-t bg-gray-50/80 px-4 py-2 text-xs text-gray-600">
              Updating...
            </div>
          ) : null}
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
