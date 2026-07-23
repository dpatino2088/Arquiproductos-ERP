import { useEffect, useMemo, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, Edit } from 'lucide-react';
import { router } from '../../lib/router';
import { formatDate } from '../../lib/utils';
import { withReturnTo } from '../../lib/navigation/returnTo';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useActiveDealer } from '../../hooks/useActiveDealer';
import { useAccessContext } from '../../hooks/useAccessContext';
import { buildDirectoryScopeKey } from '../../lib/directoryScopeKey';
import { inventoryItemDetailKey } from '../../lib/queryKeys';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';

import { INVENTORY_SUBMODULES } from './inventorySubmodules';

interface InventoryItemDetailProps {
  itemId?: string;
}

type InventoryHeaderData = {
  id: string;
  sku: string;
  name: string;
  category: string | null;
  uom: string | null;
  onHand: number;
  onOrder: number;
  required: number;
  assigned: number;
  available: number;
  /** When stock_basis === 'linear_m', on hand in meters. */
  onHandM: number | null;
  /** When is_roll and roll length known, estimated number of rolls. */
  estimatedRolls: number | null;
  /** When linear_m and width known, reference area in m². */
  m2Reference: number | null;
  /** Primary storage location code (auto-derived "Zone-Rack-Level-Bin"). */
  locationCode: string | null;
};

type PurchaseHistoryRow = {
  lineId: string;
  poNumber: string;
  vendor: string;
  date: string;
  quantity: number;
  unitCost: number;
  warehouse: string;
};

type LedgerRow = {
  lineId: string;
  date: string;
  movementType: string;
  reference: string;
  qty: number;
  cost: number | null;
  runningBalance: number;
};

type AssignmentRow = {
  moId: string;
  moNumber: string;
  status: string;
  required: number;
  assigned: number;
  remaining: number;
};

type WarehouseSeedRow = {
  catalogItemId: string;
  sku: string;
  itemName: string;
  category: string | null;
  uom: string;
  onHand: number;
  onOrder: number;
  required: number;
  assigned: number;
  available: number;
  onHandM?: number | null;
  estimatedRolls?: number | null;
  m2Reference?: number | null;
};

/** Convert length/width value + UOM to meters. */
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

function fmtQty(v: number | null | undefined): string {
  return Number(v ?? 0).toFixed(2);
}

function fmtCurrency(v: number | null | undefined): string {
  const n = Number(v ?? 0);
  if (!Number.isFinite(n)) return '-';
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n);
}

function prettyType(type: string | null | undefined): string {
  const s = (type ?? '').replace(/_/g, ' ').trim();
  if (!s) return 'movement';
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function signedMovementQty(movementType: string | null | undefined, qty: number): number {
  if (movementType === 'issue_to_production') return -Math.abs(qty);
  return qty;
}

export default function InventoryItemDetail({ itemId: propItemId }: InventoryItemDetailProps) {
  const [itemId, setItemId] = useState<string | null>(propItemId ?? null);
  const { registerSubmodules } = useSubmoduleNav();
  const queryClient = useQueryClient();
  const { activeOrganizationId } = useOrganizationContext();
  const { activeDealerId } = useActiveDealer();
  const { userType } = useAccessContext();

  useEffect(() => {
    registerSubmodules('Inventory', INVENTORY_SUBMODULES);
  }, [registerSubmodules]);

  useEffect(() => {
    if (itemId) return;
    const path = window.location.pathname;
    const match = path.match(/\/inventory\/items\/([^/]+)/);
    if (match?.[1]) {
      setItemId(match[1]);
      sessionStorage.setItem('currentInventoryItemId', match[1]);
    }
  }, [itemId]);

  const scopeKey = useMemo(
    () =>
      buildDirectoryScopeKey({
        orgId: activeOrganizationId ?? null,
        activeDealerId: activeDealerId ?? null,
        userRole: userType,
      }),
    [activeOrganizationId, activeDealerId, userType]
  );

  const seedHeader = useMemo(() => {
    if (!itemId) return undefined;
    const cached = queryClient.getQueriesData<WarehouseSeedRow[]>({
      queryKey: ['inventory', 'warehouse', 'stock', 'list'],
    });
    for (const [, rows] of cached) {
      const row = (rows ?? []).find((r) => r.catalogItemId === itemId);
      if (!row) continue;
      return {
        id: itemId,
        sku: row.sku,
        name: row.itemName,
        category: row.category ?? null,
        uom: row.uom ?? 'ea',
        onHand: Number(row.onHand ?? 0),
        onOrder: Number(row.onOrder ?? 0),
        required: Number(row.required ?? 0),
        assigned: Number(row.assigned ?? 0),
        available: Number(row.available ?? 0),
        onHandM: row.onHandM ?? null,
        estimatedRolls: row.estimatedRolls ?? null,
        m2Reference: row.m2Reference ?? null,
        locationCode: (row as WarehouseSeedRow & { locationCode?: string | null }).locationCode ?? null,
      } as InventoryHeaderData;
    }
    return undefined;
  }, [itemId, queryClient]);

  const { data: header, isLoading: loadingHeader, isFetching: fetchingHeader } = useQuery({
    queryKey: inventoryItemDetailKey(scopeKey, itemId ?? ''),
    queryFn: async (): Promise<InventoryHeaderData | null> => {
      if (!activeOrganizationId || !itemId) return null;

      const { data: item, error: itemError } = await supabase
        .from('CatalogItems')
        .select('id, sku, name, unit_of_measure, is_roll, stock_basis, roll_length_value, roll_length_uom, roll_width_value, roll_width_uom, roll_width_m, primary_location_id, CatalogCategories(name), WarehouseLocations(location_code)')
        .eq('id', itemId)
        .single();
      if (itemError) throw itemError;

      const { data: balanceRows, error: balError } = await supabase
        .from('InventoryBalances')
        .select('quantity')
        .eq('organization_id', activeOrganizationId)
        .eq('catalog_item_id', itemId);
      if (balError) throw balError;
      const onHand = (balanceRows ?? []).reduce((acc: number, r: any) => acc + Number(r.quantity ?? 0), 0);
      const stockBasis = (item.stock_basis ?? '').toLowerCase();
      const isRoll = !!item.is_roll;
      const rollLengthM = toMeters(item.roll_length_value, item.roll_length_uom);
      const widthM = item.roll_width_m != null && Number.isFinite(Number(item.roll_width_m))
        ? Number(item.roll_width_m)
        : toMeters(item.roll_width_value, item.roll_width_uom);
      const onHandM = stockBasis === 'linear_m' ? onHand : null;
      const estimatedRolls = isRoll && stockBasis === 'linear_m' && rollLengthM != null && rollLengthM > 0 ? onHand / rollLengthM : null;
      const m2Reference = stockBasis === 'linear_m' && widthM != null && widthM > 0 ? onHand * widthM : null;

      const { data: onOrderRows, error: onOrderError } = await supabase
        .from('inventory_on_order')
        .select('on_order_qty')
        .eq('organization_id', activeOrganizationId)
        .eq('catalog_item_id', itemId);
      if (onOrderError) throw onOrderError;
      const onOrder = (onOrderRows ?? []).reduce((acc: number, r: any) => acc + Number(r.on_order_qty ?? 0), 0);

      const { data: demandRows, error: demandError } = await supabase
        .from('manufacturing_order_material_demand')
        .select('required_qty')
        .eq('organization_id', activeOrganizationId)
        .eq('catalog_item_id', itemId)
        .in('mo_status', ['draft', 'confirmed', 'procurement', 'material_available', 'materials_ready', 'in_production', 'quality_check']);
      if (demandError) throw demandError;
      const required = (demandRows ?? []).reduce((acc: number, r: any) => acc + Number(r.required_qty ?? 0), 0);
      const assigned = required;

      return {
        id: item.id,
        sku: item.sku ?? '—',
        name: item.name ?? '—',
        category: item.CatalogCategories?.name ?? null,
        uom: item.is_roll ? 'm' : (item.unit_of_measure ?? 'ea'),
        onHand,
        onOrder,
        required,
        assigned,
        available: onHand - assigned,
        onHandM,
        estimatedRolls,
        m2Reference,
        locationCode: (item as { WarehouseLocations?: { location_code: string | null } | null }).WarehouseLocations?.location_code ?? null,
      };
    },
    enabled: !!activeOrganizationId && !!itemId,
    initialData: seedHeader,
  });

  const { data: purchaseHistory, isLoading: loadingHistory, isFetching: fetchingHistory } = useQuery({
    queryKey: [...inventoryItemDetailKey(scopeKey, itemId ?? ''), 'purchase-history'],
    queryFn: async (): Promise<PurchaseHistoryRow[]> => {
      if (!activeOrganizationId || !itemId) return [];
      const { data, error } = await supabase
        .from('PurchaseOrderLines')
        .select('id, ordered_qty, unit_cost, created_at, purchase_order_id, PurchaseOrders(po_number, created_at, DirectoryVendors(name), Warehouses(name))')
        .eq('catalog_item_id', itemId)
        .order('created_at', { ascending: false });
      if (error) throw error;
      return (data ?? []).map((r: any) => ({
        lineId: r.id,
        poNumber: r.PurchaseOrders?.po_number ?? r.purchase_order_id ?? '—',
        vendor: r.PurchaseOrders?.DirectoryVendors?.name ?? 'No Vendor',
        date: r.PurchaseOrders?.created_at ?? r.created_at,
        quantity: Number(r.ordered_qty ?? 0),
        unitCost: Number(r.unit_cost ?? 0),
        warehouse: r.PurchaseOrders?.Warehouses?.name ?? '—',
      }));
    },
    enabled: !!activeOrganizationId && !!itemId,
  });

  const { data: ledgerRows, isLoading: loadingLedger, isFetching: fetchingLedger } = useQuery({
    queryKey: [...inventoryItemDetailKey(scopeKey, itemId ?? ''), 'ledger'],
    queryFn: async (): Promise<LedgerRow[]> => {
      if (!activeOrganizationId || !itemId) return [];
      const { data, error } = await supabase
        .from('InventoryMovementLines')
        .select('id, quantity, inventory_movement_id, InventoryMovements(movement_no, movement_type, movement_date, reference_type, reference_id)')
        .eq('catalog_item_id', itemId)
        .order('created_at', { ascending: true });
      if (error) return [];

      let running = 0;
      const rows = (data ?? []).map((r: any) => {
        const signedQty = signedMovementQty(r.InventoryMovements?.movement_type, Number(r.quantity ?? 0));
        running += signedQty;
        const referenceNo = r.InventoryMovements?.movement_no ?? r.InventoryMovements?.reference_id ?? '—';
        return {
          lineId: r.id,
          date: r.InventoryMovements?.movement_date ?? '',
          movementType: prettyType(r.InventoryMovements?.movement_type),
          reference: referenceNo,
          qty: signedQty,
          cost: null,
          runningBalance: running,
        };
      });

      return rows.reverse();
    },
    enabled: !!activeOrganizationId && !!itemId,
  });

  const { data: assignments, isLoading: loadingAssignments, isFetching: fetchingAssignments } = useQuery({
    queryKey: [...inventoryItemDetailKey(scopeKey, itemId ?? ''), 'mo-assignments'],
    queryFn: async (): Promise<AssignmentRow[]> => {
      if (!activeOrganizationId || !itemId) return [];
      const { data, error } = await supabase
        .from('manufacturing_order_material_demand')
        .select('manufacturing_order_id, manufacturing_order_no, mo_status, required_qty')
        .eq('organization_id', activeOrganizationId)
        .eq('catalog_item_id', itemId)
        .in('mo_status', ['draft', 'confirmed', 'procurement', 'material_available', 'materials_ready', 'in_production', 'quality_check'])
        .order('manufacturing_order_no', { ascending: true });
      if (error) throw error;

      return (data ?? []).map((r: any) => {
        const required = Number(r.required_qty ?? 0);
        const assigned = required;
        return {
          moId: r.manufacturing_order_id,
          moNumber: r.manufacturing_order_no ?? '—',
          status: String(r.mo_status ?? 'draft'),
          required,
          assigned,
          remaining: Math.max(0, required - assigned),
        };
      });
    },
    enabled: !!activeOrganizationId && !!itemId,
  });

  if (!itemId) {
    return (
      <div className="py-6 px-6">
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          Inventory item ID is required.
        </div>
      </div>
    );
  }

  const showHeaderLoading = !header && loadingHeader;
  const purchaseHistoryRows = purchaseHistory ?? [];
  const movementLedgerRows = ledgerRows ?? [];
  const moAssignmentRows = assignments ?? [];

  return (
    <div className="py-6 px-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-foreground">{header?.sku ?? 'Item'}</h1>
          <p className="text-xs text-gray-500">Inventory availability detail</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => router.navigate('/inventory/warehouse')}
            className="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to Warehouse
          </button>
          <button
            type="button"
            onClick={() =>
              router.navigate(withReturnTo(`/catalog/items/edit/${itemId}`, '/inventory/warehouse'))
            }
            className="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90"
          >
            <Edit className="w-4 h-4" />
            Edit Catalog Item
          </button>
        </div>
      </div>

      <div className="rounded-lg border border-gray-200 bg-white p-5">
        {showHeaderLoading ? (
          <div className="text-sm text-gray-500">Loading item availability...</div>
        ) : (
          <div className="grid grid-cols-2 md:grid-cols-4 xl:grid-cols-8 gap-4 text-sm">
            <div><p className="text-gray-500">SKU</p><p className="font-medium">{header?.sku ?? '—'}</p></div>
            <div><p className="text-gray-500">Item Name</p><p className="font-medium">{header?.name ?? '—'}</p></div>
            <div><p className="text-gray-500">Category</p><p className="font-medium">{header?.category ?? '—'}</p></div>
            <div><p className="text-gray-500">UOM</p><p className="font-medium">{header?.uom ?? 'ea'}</p></div>
            <div>
              <p className="text-gray-500">Location</p>
              <p className="font-medium">
                {header?.locationCode ? (
                  <span className="inline-flex items-center px-2 py-0.5 rounded bg-gray-50 border border-gray-200 text-[11px] font-mono">
                    {header.locationCode}
                  </span>
                ) : (
                  <span className="text-gray-400">—</span>
                )}
              </p>
            </div>
            <div><p className="text-gray-500">On Hand</p><p className="font-medium tabular-nums">{fmtQty(header?.onHand)}</p></div>
            <div><p className="text-gray-500">On Order</p><p className="font-medium tabular-nums">{fmtQty(header?.onOrder)}</p></div>
            <div><p className="text-gray-500">Assigned</p><p className="font-medium tabular-nums">{fmtQty(header?.assigned)}</p></div>
            <div><p className="text-gray-500">Available</p><p className="font-semibold tabular-nums">{fmtQty(header?.available)}</p></div>
            {header?.onHandM != null ? <div><p className="text-gray-500">On Hand (m)</p><p className="font-medium tabular-nums">{fmtQty(header.onHandM)}</p></div> : null}
            {header?.estimatedRolls != null ? <div><p className="text-gray-500">Est. Rolls</p><p className="font-medium tabular-nums">{Number(header.estimatedRolls).toFixed(1)}</p></div> : null}
            {header?.m2Reference != null ? <div><p className="text-gray-500">m² ref</p><p className="font-medium tabular-nums">{Number(header.m2Reference).toFixed(2)}</p></div> : null}
          </div>
        )}
        {header && fetchingHeader ? <div className="mt-3 text-xs text-gray-500">Updating...</div> : null}
      </div>

      <section className="rounded-lg border border-gray-200 overflow-hidden bg-white">
        <div className="px-4 py-3 border-b bg-gray-50">
          <h2 className="text-sm font-semibold text-gray-900">Purchase History</h2>
        </div>
        <table className="w-full text-sm">
          <thead className="bg-gray-50/70 border-b">
            <tr>
              <th className="px-4 py-2 text-left font-medium text-gray-700">PO Number</th>
              <th className="px-4 py-2 text-left font-medium text-gray-700">Vendor</th>
              <th className="px-4 py-2 text-left font-medium text-gray-700">Date</th>
              <th className="px-4 py-2 text-right font-medium text-gray-700">Quantity</th>
              <th className="px-4 py-2 text-right font-medium text-gray-700">Unit Cost</th>
              <th className="px-4 py-2 text-left font-medium text-gray-700">Warehouse</th>
            </tr>
          </thead>
          <tbody>
            {loadingHistory && purchaseHistoryRows.length === 0 ? (
              <tr><td colSpan={6} className="px-4 py-6 text-center text-gray-500">Loading purchase history...</td></tr>
            ) : purchaseHistoryRows.length === 0 ? (
              <tr><td colSpan={6} className="px-4 py-6 text-center text-gray-500">No purchase history found</td></tr>
            ) : (
              purchaseHistoryRows.map((r) => (
                <tr key={r.lineId} className="border-t">
                  <td className="px-4 py-2 font-medium text-gray-900">{r.poNumber}</td>
                  <td className="px-4 py-2 text-gray-700">{r.vendor}</td>
                  <td className="px-4 py-2 text-gray-600">{formatDate(r.date)}</td>
                  <td className="px-4 py-2 text-right tabular-nums">{fmtQty(r.quantity)}</td>
                  <td className="px-4 py-2 text-right tabular-nums">{fmtCurrency(r.unitCost)}</td>
                  <td className="px-4 py-2 text-gray-600">{r.warehouse}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
        {purchaseHistoryRows.length > 0 && fetchingHistory ? (
          <div className="border-t bg-gray-50/80 px-4 py-2 text-xs text-gray-600">Updating...</div>
        ) : null}
      </section>

      <section className="rounded-lg border border-gray-200 overflow-hidden bg-white">
        <div className="px-4 py-3 border-b bg-gray-50">
          <h2 className="text-sm font-semibold text-gray-900">Stock Movement / Ledger</h2>
        </div>
        <table className="w-full text-sm">
          <thead className="bg-gray-50/70 border-b">
            <tr>
              <th className="px-4 py-2 text-left font-medium text-gray-700">Date</th>
              <th className="px-4 py-2 text-left font-medium text-gray-700">Movement Type</th>
              <th className="px-4 py-2 text-left font-medium text-gray-700">Reference</th>
              <th className="px-4 py-2 text-right font-medium text-gray-700">Qty (+/-)</th>
              <th className="px-4 py-2 text-right font-medium text-gray-700">Cost</th>
              <th className="px-4 py-2 text-right font-medium text-gray-700">Running Balance</th>
            </tr>
          </thead>
          <tbody>
            {loadingLedger && movementLedgerRows.length === 0 ? (
              <tr><td colSpan={6} className="px-4 py-6 text-center text-gray-500">Loading movement ledger...</td></tr>
            ) : movementLedgerRows.length === 0 ? (
              <tr><td colSpan={6} className="px-4 py-6 text-center text-gray-500">No movement ledger entries yet</td></tr>
            ) : (
              movementLedgerRows.map((r) => (
                <tr key={r.lineId} className="border-t">
                  <td className="px-4 py-2 text-gray-600">{formatDate(r.date)}</td>
                  <td className="px-4 py-2 text-gray-700">{r.movementType}</td>
                  <td className="px-4 py-2 text-gray-700">{r.reference}</td>
                  <td className={`px-4 py-2 text-right tabular-nums ${r.qty < 0 ? 'text-red-600' : 'text-green-700'}`}>{fmtQty(r.qty)}</td>
                  <td className="px-4 py-2 text-right tabular-nums">{r.cost == null ? '—' : fmtCurrency(r.cost)}</td>
                  <td className="px-4 py-2 text-right tabular-nums font-medium">{fmtQty(r.runningBalance)}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
        {movementLedgerRows.length > 0 && fetchingLedger ? (
          <div className="border-t bg-gray-50/80 px-4 py-2 text-xs text-gray-600">Updating...</div>
        ) : null}
      </section>

      <section className="rounded-lg border border-gray-200 overflow-hidden bg-white">
        <div className="px-4 py-3 border-b bg-gray-50">
          <h2 className="text-sm font-semibold text-gray-900">MO Assignments</h2>
        </div>
        <table className="w-full text-sm">
          <thead className="bg-gray-50/70 border-b">
            <tr>
              <th className="px-4 py-2 text-left font-medium text-gray-700">MO Number</th>
              <th className="px-4 py-2 text-left font-medium text-gray-700">Status</th>
              <th className="px-4 py-2 text-right font-medium text-gray-700">Required Qty</th>
              <th className="px-4 py-2 text-right font-medium text-gray-700">Assigned Qty</th>
              <th className="px-4 py-2 text-right font-medium text-gray-700">Remaining</th>
            </tr>
          </thead>
          <tbody>
            {loadingAssignments && moAssignmentRows.length === 0 ? (
              <tr><td colSpan={5} className="px-4 py-6 text-center text-gray-500">Loading MO assignments...</td></tr>
            ) : moAssignmentRows.length === 0 ? (
              <tr><td colSpan={5} className="px-4 py-6 text-center text-gray-500">No MO assignments for this SKU</td></tr>
            ) : (
              moAssignmentRows.map((r) => (
                <tr key={`${r.moId}-${r.moNumber}`} className="border-t">
                  <td className="px-4 py-2 font-medium text-gray-900">{r.moNumber}</td>
                  <td className="px-4 py-2 text-gray-700">{r.status.replace(/_/g, ' ')}</td>
                  <td className="px-4 py-2 text-right tabular-nums">{fmtQty(r.required)}</td>
                  <td className="px-4 py-2 text-right tabular-nums">{fmtQty(r.assigned)}</td>
                  <td className="px-4 py-2 text-right tabular-nums">{fmtQty(r.remaining)}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
        {moAssignmentRows.length > 0 && fetchingAssignments ? (
          <div className="border-t bg-gray-50/80 px-4 py-2 text-xs text-gray-600">Updating...</div>
        ) : null}
      </section>
    </div>
  );
}
