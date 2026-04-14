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
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';

const INVENTORY_SUBMODULES = [
  { id: 'warehouse', label: 'Warehouse', href: '/inventory/warehouse' },
  { id: 'purchase-orders', label: 'Purchase Orders', href: '/inventory/purchase-orders' },
  { id: 'receipts', label: 'Receipts', href: '/inventory/receipts' },
  { id: 'transactions', label: 'Transactions', href: '/inventory/transactions' },
  { id: 'adjustments', label: 'Adjustments', href: '/inventory/adjustments' },
  { id: 'material-demand', label: 'Material Demand', href: '/inventory/material-demand' },
];

/** Convert length/width value + UOM to meters (for roll length/width). */
function toMeters(value: number | null | undefined, uom: string | null | undefined): number | null {
  const v = Number(value ?? 0);
  if (!Number.isFinite(v)) return null;
  const u = (uom ?? '').toLowerCase();
  if (u === 'm' || u === 'meter' || u === 'meters' || u === 'metre' || u === 'metres') return v;
  if (u === 'yd' || u === 'yard' || u === 'yards') return v * 0.9144;
  if (u === 'ft' || u === 'foot' || u === 'feet') return v * 0.3048;
  if (u === 'in' || u === 'inch' || u === 'inches') return v * 0.0254;
  if (u === 'cm') return v / 100;
  if (u === 'mm') return v / 1000;
  return null;
}

/** Convert internal meters back to a display UOM. */
function fromMeters(meters: number, uom: string): number {
  const u = uom.toLowerCase();
  if (u === 'yd' || u === 'yard' || u === 'yards') return meters / 0.9144;
  if (u === 'ft' || u === 'foot' || u === 'feet') return meters / 0.3048;
  if (u === 'in' || u === 'inch' || u === 'inches') return meters / 0.0254;
  if (u === 'cm') return meters * 100;
  if (u === 'mm') return meters * 1000;
  return meters;
}

interface StockRow {
  id: string;
  catalogItemId: string;
  sku: string;
  itemName: string;
  uom: string;
  category: string | null;
  onHand: number;
  /** On hand in the manufacturer's UOM (e.g. yd) for linear/roll items, null for ea items. */
  onHandDisplay: number | null;
  /** The manufacturer's unit label (e.g. 'yd'). */
  displayUom: string | null;
  warehouseName: string;
  onOrder: number;
  assigned: number;
  required: number;
  available: number;
  balance: number;
  /** When stock_basis === 'linear_m', on hand in meters (same as onHand). */
  onHandM: number | null;
  /** When is_roll and roll length known, estimated number of rolls. */
  estimatedRolls: number | null;
  /** When linear_m and width known, reference area in m² (length_m × width_m). */
  m2Reference: number | null;
}

/** Balance color: green if covered, orange if close, red if deficit. */
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
        .select('catalog_item_id, quantity, warehouse_id, Warehouses(name), CatalogItems(sku, name, unit_of_measure, measure_basis, is_roll, roll_length_value, roll_length_uom, roll_width_value, roll_width_uom, roll_width_m, CatalogCategories(name))')
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
          .in('mo_status', ['draft', 'confirmed', 'procurement', 'materials_ready', 'in_production', 'quality_check']);
        if (demandError) throw demandError;

        (demandRows ?? []).forEach((r: any) => {
          const qty = Number(r.required_qty ?? 0);
          requiredMap.set(r.catalog_item_id, (requiredMap.get(r.catalog_item_id) || 0) + qty);
        });

        const { data: allocRows } = await supabase
          .from('inventory_allocated')
          .select('catalog_item_id, allocated_qty')
          .eq('organization_id', activeOrganizationId)
          .in('catalog_item_id', catalogIds);
        (allocRows ?? []).forEach((r: any) => {
          assignedMap.set(r.catalog_item_id, (assignedMap.get(r.catalog_item_id) || 0) + Number(r.allocated_qty || 0));
        });
      }

      return (balances as any[]).map(b => {
        const onHand = Number(b.quantity ?? 0);
        const measureBasis = (b.CatalogItems?.measure_basis ?? '').toLowerCase();
        const uom = (b.CatalogItems?.unit_of_measure ?? '').toLowerCase();
        const isLinearStock = measureBasis === 'linear' || ['m', 'yd', 'ft'].includes(uom);
        const isRoll = !!b.CatalogItems?.is_roll;
        const rollLengthM = toMeters(b.CatalogItems?.roll_length_value, b.CatalogItems?.roll_length_uom);
        const widthM = b.CatalogItems?.roll_width_m != null && Number.isFinite(Number(b.CatalogItems.roll_width_m))
          ? Number(b.CatalogItems.roll_width_m)
          : toMeters(b.CatalogItems?.roll_width_value, b.CatalogItems?.roll_width_uom);
        const onHandM = isLinearStock ? onHand : null;
        const estimatedRolls =
          isRoll && isLinearStock && rollLengthM != null && rollLengthM > 0
            ? onHand / rollLengthM
            : null;
        const m2Reference =
          isLinearStock && widthM != null && widthM > 0 ? onHand * widthM : null;
        const rawUom = (b.CatalogItems?.unit_of_measure ?? 'ea').toLowerCase();
        const needsConversion = isLinearStock && rawUom !== 'm';
        const onHandDisplay = needsConversion ? fromMeters(onHand, rawUom) : null;
        const displayUom = needsConversion ? rawUom : null;
        return {
          id: b.catalog_item_id + ':' + b.warehouse_id,
          catalogItemId: b.catalog_item_id,
          sku: b.CatalogItems?.sku ?? '—',
          itemName: b.CatalogItems?.name ?? '—',
          uom: b.CatalogItems?.is_roll ? 'm' : (b.CatalogItems?.unit_of_measure ?? 'ea'),
          category: b.CatalogItems?.CatalogCategories?.name ?? null,
          onHand,
          onHandDisplay,
          displayUom,
          warehouseName: b.Warehouses?.name ?? '—',
          onOrder: onOrderMap.get(b.catalog_item_id) ?? 0,
          assigned: assignedMap.get(b.catalog_item_id) ?? 0,
          required: requiredMap.get(b.catalog_item_id) ?? 0,
          available: Math.round(Math.max(0, onHand - (assignedMap.get(b.catalog_item_id) ?? 0)) * 100) / 100,
          balance: Math.round((onHand + (onOrderMap.get(b.catalog_item_id) ?? 0) - (requiredMap.get(b.catalog_item_id) ?? 0)) * 100) / 100,
          onHandM,
          estimatedRolls,
          m2Reference,
        };
      });
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
  const selectedWarehouseName = useMemo(
    () => warehouses.find((w) => w.id === effectiveWarehouseId)?.name ?? null,
    [warehouses, effectiveWarehouseId]
  );

  const handleSort = (col: typeof sortBy) => {
    if (sortBy === col) setSortOrder(o => o === 'asc' ? 'desc' : 'asc');
    else { setSortBy(col); setSortOrder('asc'); }
  };

  const SortIcon = ({ col }: { col: typeof sortBy }) => {
    if (sortBy !== col) return null;
    return sortOrder === 'asc' ? <SortAsc className="w-3.5 h-3.5 inline ml-1" /> : <SortDesc className="w-3.5 h-3.5 inline ml-1" />;
  };

  return (
    <div className="px-6 py-6">
      <div className="flex items-start justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Warehouse Inventory</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {filtered.length} SKU{filtered.length === 1 ? '' : 's'} in stock
            {selectedWarehouseName ? ` · ${selectedWarehouseName}` : ' · All warehouses'}
          </p>
        </div>
      </div>

      {/* Filters */}
      <div className="mb-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center justify-between gap-3 flex-wrap">
            <div className="flex-1 relative min-w-[240px]">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search SKU, item name, or category..."
                value={searchTerm}
                onChange={(e) => { setSearchTerm(e.target.value); setCurrentPage(1); }}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search warehouse inventory"
              />
            </div>
            {warehouses.length > 1 && (
              <div className="w-[190px] shrink-0">
                <Select
                  value={selectedWarehouseId || '__all__'}
                  onValueChange={(v) => { setSelectedWarehouseId(v === '__all__' ? '' : v); setCurrentPage(1); }}
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

      {isLoading ? (
        <div className="animate-pulse space-y-3">
          <div className="h-10 bg-gray-100 rounded" />
          <div className="h-10 bg-gray-100 rounded" />
          <div className="h-10 bg-gray-100 rounded" />
        </div>
      ) : (
        <div className="rounded-lg border border-gray-200 bg-white shadow-sm overflow-auto max-h-[calc(100vh-220px)]">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b sticky top-0 z-10">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('sku')}>
                  SKU <SortIcon col="sku" />
                </th>
                <th className="px-4 py-3 text-left font-medium text-gray-700 cursor-pointer" onClick={() => handleSort('itemName')}>
                  Item Name <SortIcon col="itemName" />
                </th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Category</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Warehouse</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700 whitespace-nowrap cursor-pointer min-w-[90px]" onClick={() => handleSort('onHand')}>
                  On Hand <SortIcon col="onHand" />
                </th>
                <th className="px-3 py-3 text-right font-medium text-gray-700 w-16" title="Normalized quantity in meters">m</th>
                <th className="px-3 py-3 text-right font-medium text-gray-700 w-14" title="Estimated roll count">Rolls</th>
                <th className="px-3 py-3 text-right font-medium text-gray-700 w-16" title="Reference area (m²)">m² ref</th>
                <th className="px-3 py-3 text-right font-medium text-gray-700 whitespace-nowrap">On Order</th>
                <th className="px-3 py-3 text-right font-medium text-gray-700">Required</th>
                <th className="px-3 py-3 text-right font-medium text-gray-700">Assigned</th>
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
                <tr><td colSpan={15} className="px-4 py-8 text-center text-gray-500">No stock data found</td></tr>
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
                  <td className="px-4 py-3 text-right tabular-nums whitespace-nowrap">
                    {row.onHandDisplay != null ? (
                      <>{Number(row.onHandDisplay).toFixed(2)}<span className="text-[10px] text-gray-400 ml-0.5">{row.displayUom}</span></>
                    ) : (
                      <>{Number(row.onHand).toFixed(2)}<span className="text-[10px] text-gray-400 ml-0.5">{row.uom === 'm' ? 'm' : 'ea'}</span></>
                    )}
                  </td>
                  <td className="px-4 py-3 text-right tabular-nums text-gray-600">{row.onHandM != null ? Number(row.onHandM).toFixed(2) : '—'}</td>
                  <td className="px-4 py-3 text-right tabular-nums text-gray-600">{row.estimatedRolls != null ? Number(row.estimatedRolls).toFixed(1) : '—'}</td>
                  <td className="px-4 py-3 text-right tabular-nums text-gray-600">{row.m2Reference != null ? Number(row.m2Reference).toFixed(2) : '—'}</td>
                  <td className="px-4 py-3 text-right tabular-nums text-gray-600">{row.onOrder > 0 ? Number(row.onOrder).toFixed(2) : '—'}</td>
                  <td className="px-4 py-3 text-right tabular-nums text-gray-600">{row.required > 0 ? Number(row.required).toFixed(2) : '—'}</td>
                  <td className="px-4 py-3 text-right tabular-nums text-gray-600">{row.assigned > 0 ? Number(row.assigned).toFixed(2) : '—'}</td>
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
