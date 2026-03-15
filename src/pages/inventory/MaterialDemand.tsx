import { useEffect, useState, useMemo, useCallback } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { supabase } from '../../lib/supabase/client';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useCreatePurchaseOrder, type CreatePOLineInput } from '../../hooks/usePurchaseOrders';
import { useWarehouses } from '../../hooks/useWarehouses';
import { router } from '../../lib/router';
import {
  Search, SortAsc, SortDesc, ShoppingCart, ChevronDown, Filter, X, ExternalLink, Loader2,
} from 'lucide-react';
import Input from '../../components/ui/Input';
import { resolveInventoryUnitModel, convertInternalToPurchaseQty, type MeasureBasis } from '../../lib/inventoryUnitModel';

const INVENTORY_SUBMODULES = [
  { id: 'warehouse', label: 'Warehouse', href: '/inventory/warehouse' },
  { id: 'purchase-orders', label: 'Purchase Orders', href: '/inventory/purchase-orders' },
  { id: 'receipts', label: 'Receipts', href: '/inventory/receipts' },
  { id: 'transactions', label: 'Transactions', href: '/inventory/transactions' },
  { id: 'adjustments', label: 'Adjustments', href: '/inventory/adjustments' },
  { id: 'material-demand', label: 'Material Demand', href: '/inventory/material-demand' },
];

interface DemandRow {
  manufacturing_order_id: string;
  organization_id: string;
  catalog_item_id: string;
  sku: string | null;
  item_name: string | null;
  required_qty: number;
  uom: string | null;
  manufacturing_order_no: string;
  mo_status: string;
  on_hand: number;
  on_order: number;
  manufacturer_id: string | null;
  manufacturer_name: string | null;
  vendor_id: string | null;
  vendor_name: string | null;
  cost_exw: number;
  item_min_qty: number;
  need_to_buy: number;
  purchase_unit: string | null;
  units_per_purchase_unit: number;
  is_roll: boolean;
  roll_length_m: number | null;
  roll_length_value: number | null;
  roll_length_uom: string | null;
  unit_of_measure: string | null;
  measure_basis: string;
}

interface CreatedPO {
  id: string;
  po_number: string;
  manufacturer_name: string | null;
  vendor_name: string | null;
  line_count: number;
}

type SortCol = 'sku' | 'required_qty' | 'need_to_buy';

export default function MaterialDemand() {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const addNotification = useUIStore(s => s.addNotification);
  const queryClient = useQueryClient();
  const { createPurchaseOrder, isCreating } = useCreatePurchaseOrder();
  const { defaultWarehouse } = useWarehouses(activeOrganizationId);

  const [searchTerm, setSearchTerm] = useState('');
  const [createdPOs, setCreatedPOs] = useState<CreatedPO[] | null>(null);
  const [sortBy, setSortBy] = useState<SortCol>('sku');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedRows, setSelectedRows] = useState<Set<string>>(new Set());
  const [filterMoId, setFilterMoId] = useState<string | null>(null);
  const [needToBuyOnly, setNeedToBuyOnly] = useState(true);
  const [showMODropdown, setShowMODropdown] = useState(false);
  const [moFilterSearch, setMoFilterSearch] = useState('');

  useEffect(() => {
    registerSubmodules('Inventory', INVENTORY_SUBMODULES);
  }, [registerSubmodules]);

  useEffect(() => {
    const url = new URL(window.location.href);
    const moId = url.searchParams.get('mo_id');
    if (moId) {
      setFilterMoId(moId);
    }
  }, []);

  // Demand view
  const { data: demandRows, isLoading: demandLoading } = useQuery({
    queryKey: ['material-demand', activeOrganizationId],
    queryFn: async (): Promise<DemandRow[]> => {
      if (!activeOrganizationId) return [];
      const { data: demand, error } = await supabase
        .from('manufacturing_order_material_demand')
        .select('*')
        .eq('organization_id', activeOrganizationId)
        .in('mo_status', ['draft', 'planned', 'in_production', 'quality_check']);
      if (error) throw error;
      if (!demand?.length) return [];

      const catalogIds = [...new Set(demand.map((d: any) => d.catalog_item_id).filter(Boolean))];
      const onHandMap = new Map<string, number>();
      const onOrderMap = new Map<string, number>();

      const vendorMap = new Map<string, {
        manufacturer_id: string | null;
        manufacturer_name: string | null;
        vendor_id: string | null;
        vendor_name: string | null;
        cost_exw: number;
        item_min_qty: number;
        purchase_unit: string | null;
        units_per_purchase_unit: number;
        is_roll: boolean;
        roll_length_m: number | null;
        roll_length_value: number | null;
        roll_length_uom: string | null;
        unit_of_measure: string | null;
        measure_basis: string;
      }>();

      const resolveItemMinQty = (item: Record<string, unknown>): number => {
        const candidates = [
          item.minimum_stock,
          item.minimum_stock_qty,
          item.min_stock,
          item.min_stock_qty,
          item.minimum_qty,
          item.min_qty,
          item.reorder_point,
          item.safety_stock,
          item.stock_minimum,
          item.stock_min,
        ];
        for (const c of candidates) {
          const n = Number(c ?? 0);
          if (Number.isFinite(n) && n > 0) return n;
        }
        return 0;
      };

      if (catalogIds.length > 0) {
        const { data: ohRows } = await supabase
          .from('inventory_on_hand')
          .select('catalog_item_id, on_hand_qty')
          .eq('organization_id', activeOrganizationId)
          .in('catalog_item_id', catalogIds);
        (ohRows ?? []).forEach((r: any) => {
          onHandMap.set(r.catalog_item_id, (onHandMap.get(r.catalog_item_id) || 0) + Number(r.on_hand_qty || 0));
        });
        const { data: ooRows } = await supabase
          .from('inventory_on_order')
          .select('catalog_item_id, on_order_qty')
          .eq('organization_id', activeOrganizationId)
          .in('catalog_item_id', catalogIds);
        (ooRows ?? []).forEach((r: any) => {
          onOrderMap.set(r.catalog_item_id, (onOrderMap.get(r.catalog_item_id) || 0) + Number(r.on_order_qty || 0));
        });

        const { data: ciRows } = await supabase
          .from('CatalogItems')
          .select('*')
          .in('id', catalogIds);
        const mfrIds = [...new Set((ciRows ?? []).map((c: any) => c.manufacturer_id).filter(Boolean))];

        // Lookup vendor for each manufacturer via VendorManufacturers junction table
        const mfrVendorMap = new Map<string, { id: string; name: string }>();
        const mfrNameMap = new Map<string, string>();
        if (mfrIds.length > 0) {
          // Junction table lookup (preferred)
          const { data: vmRows } = await supabase
            .from('VendorManufacturers')
            .select('manufacturer_id, vendor_id')
            .eq('organization_id', activeOrganizationId)
            .in('manufacturer_id', mfrIds);
          const vendorIdsNeeded = [...new Set((vmRows ?? []).map((r: any) => r.vendor_id))];
          const vendorNameMap = new Map<string, string>();
          if (vendorIdsNeeded.length > 0) {
            const { data: dvRows } = await supabase
              .from('DirectoryVendors')
              .select('id, name')
              .in('id', vendorIdsNeeded)
              .eq('deleted', false);
            (dvRows ?? []).forEach((v: any) => vendorNameMap.set(v.id, v.name));
          }
          (vmRows ?? []).forEach((r: any) => {
            if (!mfrVendorMap.has(r.manufacturer_id)) {
              const vName = vendorNameMap.get(r.vendor_id);
              if (vName) mfrVendorMap.set(r.manufacturer_id, { id: r.vendor_id, name: vName });
            }
          });

          // Fallback: legacy DirectoryVendors.manufacturer_id for any mfr not in junction
          const missingMfrIds = mfrIds.filter(id => !mfrVendorMap.has(id));
          if (missingMfrIds.length > 0) {
            const { data: dvFallback } = await supabase
              .from('DirectoryVendors')
              .select('id, name, manufacturer_id')
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false)
              .in('manufacturer_id', missingMfrIds);
            (dvFallback ?? []).forEach((v: any) => {
              if (!mfrVendorMap.has(v.manufacturer_id)) {
                mfrVendorMap.set(v.manufacturer_id, { id: v.id, name: v.name });
              }
            });
          }

          // Manufacturer names
          const { data: mfrRows } = await supabase
            .from('Manufacturers')
            .select('id, name')
            .in('id', mfrIds);
          (mfrRows ?? []).forEach((m: any) => mfrNameMap.set(m.id, m.name));
        }

        (ciRows ?? []).forEach((c: any) => {
          const vendor = c.manufacturer_id ? mfrVendorMap.get(c.manufacturer_id) : undefined;
          vendorMap.set(c.id, {
            manufacturer_id: c.manufacturer_id ?? null,
            manufacturer_name: c.manufacturer_id ? (mfrNameMap.get(c.manufacturer_id) ?? null) : null,
            vendor_id: vendor?.id ?? null,
            vendor_name: vendor?.name ?? null,
            cost_exw: Number(c.cost_exw ?? 0),
            item_min_qty: resolveItemMinQty(c as Record<string, unknown>),
            purchase_unit: c.purchase_unit ?? null,
            units_per_purchase_unit: Number(c.units_per_purchase_unit ?? 1) || 1,
            is_roll: Boolean(c.is_roll),
            roll_length_m: c.roll_length_m != null ? Number(c.roll_length_m) : null,
            roll_length_value: c.roll_length_value != null ? Number(c.roll_length_value) : null,
            roll_length_uom: c.roll_length_uom ?? null,
            unit_of_measure: c.unit_of_measure ?? null,
            measure_basis: (c.measure_basis ?? 'unit') as string,
          });
        });
      }

      // Aggregate total required per catalog_item across ALL MOs
      const totalRequiredPerItem = new Map<string, number>();
      for (const d of demand) {
        const itemId = (d as any).catalog_item_id as string;
        totalRequiredPerItem.set(itemId, (totalRequiredPerItem.get(itemId) ?? 0) + Number((d as any).required_qty ?? 0));
      }

      // Compute item-level need_to_buy (aggregate deficit, not per-MO)
      const itemNeedToBuyMap = new Map<string, number>();
      for (const [itemId, totalReq] of totalRequiredPerItem) {
        const v = vendorMap.get(itemId);
        const onHand = onHandMap.get(itemId) ?? 0;
        const onOrder = onOrderMap.get(itemId) ?? 0;
        const minQty = Number(v?.item_min_qty ?? 0);
        itemNeedToBuyMap.set(itemId, Math.round(Math.max(0, totalReq + minQty - onHand - onOrder) * 100) / 100);
      }

      return demand.map((d: any) => {
        const v = vendorMap.get(d.catalog_item_id);
        return {
          ...d,
          required_qty: Number(d.required_qty ?? 0),
          on_hand: onHandMap.get(d.catalog_item_id) ?? 0,
          on_order: onOrderMap.get(d.catalog_item_id) ?? 0,
          manufacturer_id: v?.manufacturer_id ?? null,
          manufacturer_name: v?.manufacturer_name ?? null,
          vendor_id: v?.vendor_id ?? null,
          vendor_name: v?.vendor_name ?? null,
          cost_exw: v?.cost_exw ?? 0,
          item_min_qty: Number(v?.item_min_qty ?? 0),
          purchase_unit: v?.purchase_unit ?? null,
          units_per_purchase_unit: v?.units_per_purchase_unit ?? 1,
          is_roll: v?.is_roll ?? false,
          roll_length_m: v?.roll_length_m ?? null,
          roll_length_value: v?.roll_length_value ?? null,
          roll_length_uom: v?.roll_length_uom ?? null,
          unit_of_measure: v?.unit_of_measure ?? null,
          measure_basis: (v?.measure_basis ?? 'unit') as string,
          need_to_buy: itemNeedToBuyMap.get(d.catalog_item_id) ?? 0,
        };
      });
    },
    enabled: !!activeOrganizationId,
  });

  const moOptions = useMemo(() => {
    const map = new Map<string, string>();
    for (const r of demandRows ?? []) {
      if (!map.has(r.manufacturing_order_id)) map.set(r.manufacturing_order_id, r.manufacturing_order_no);
    }
    return Array.from(map.entries())
      .map(([id, no]) => ({ id, manufacturing_order_no: no }))
      .sort((a, b) => a.manufacturing_order_no.localeCompare(b.manufacturing_order_no));
  }, [demandRows]);

  const filteredMoOptions = useMemo(() => {
    if (!moFilterSearch.trim()) return moOptions;
    const s = moFilterSearch.toLowerCase();
    return moOptions.filter(mo => mo.manufacturing_order_no.toLowerCase().includes(s));
  }, [moOptions, moFilterSearch]);

  const selectedMOLabel = useMemo(
    () => moOptions.find(mo => mo.id === filterMoId)?.manufacturing_order_no ?? null,
    [moOptions, filterMoId]
  );

  // Filtered demand
  const filteredDemand = useMemo(() => {
    let rows = demandRows ?? [];
    if (filterMoId) {
      rows = rows.filter(r => r.manufacturing_order_id === filterMoId);
    }
    if (needToBuyOnly) {
      rows = rows.filter(r => r.need_to_buy > 0);
    }
    if (searchTerm.trim()) {
      const s = searchTerm.toLowerCase();
      rows = rows.filter(r =>
        (r.sku ?? '').toLowerCase().includes(s) ||
        (r.item_name ?? '').toLowerCase().includes(s) ||
        r.manufacturing_order_no.toLowerCase().includes(s)
      );
    }
    rows.sort((a, b) => {
      let cmp = 0;
      if (sortBy === 'sku') cmp = (a.sku ?? '').localeCompare(b.sku ?? '');
      else if (sortBy === 'required_qty') cmp = a.required_qty - b.required_qty;
      else if (sortBy === 'need_to_buy') cmp = a.need_to_buy - b.need_to_buy;
      return sortOrder === 'asc' ? cmp : -cmp;
    });
    return rows;
  }, [demandRows, filterMoId, needToBuyOnly, searchTerm, sortBy, sortOrder]);

  const handleSort = (col: SortCol) => {
    if (sortBy === col) setSortOrder(o => o === 'asc' ? 'desc' : 'asc');
    else { setSortBy(col); setSortOrder('asc'); }
  };

  const SortIcon = ({ col }: { col: SortCol }) => {
    if (sortBy !== col) return null;
    return sortOrder === 'asc' ? <SortAsc className="w-3.5 h-3.5 inline ml-1" /> : <SortDesc className="w-3.5 h-3.5 inline ml-1" />;
  };

  const rowKey = (r: DemandRow) => `${r.manufacturing_order_id}:${r.catalog_item_id}`;

  const buyableRows = useMemo(() => filteredDemand.filter(r => r.need_to_buy > 0), [filteredDemand]);

  const allFilteredSelected = useMemo(() => {
    if (buyableRows.length === 0) return false;
    return buyableRows.every(r => selectedRows.has(rowKey(r)));
  }, [buyableRows, selectedRows]);

  const toggleSelectAll = useCallback(() => {
    setSelectedRows(prev => {
      const next = new Set(prev);
      if (allFilteredSelected) {
        buyableRows.forEach(r => next.delete(rowKey(r)));
      } else {
        buyableRows.forEach(r => next.add(rowKey(r)));
      }
      return next;
    });
  }, [allFilteredSelected, buyableRows]);

  const toggleSelectRow = useCallback((key: string) => {
    setSelectedRows(prev => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key); else next.add(key);
      return next;
    });
  }, []);

  useEffect(() => {
    setSelectedRows(new Set());
  }, [filterMoId, needToBuyOnly, searchTerm]);

  const handleCreatePOFromSelected = useCallback(async () => {
    if (!defaultWarehouse) {
      addNotification({ type: 'error', title: 'Error', message: 'No warehouse configured. Please set up a default warehouse first.' });
      return;
    }

    const allRows = demandRows ?? [];
    const selected = allRows.filter(r => selectedRows.has(rowKey(r)));
    const withNeedToBuy = selected.filter(r => r.need_to_buy > 0);

    if (withNeedToBuy.length === 0) {
      addNotification({ type: 'warning', title: 'Nothing to Buy', message: 'Selected items do not require additional purchase.' });
      return;
    }

    const groups = new Map<string, {
      manufacturer_id: string | null;
      manufacturer_name: string | null;
      vendor_id: string | null;
      vendor_name: string | null;
      rows: DemandRow[];
    }>();
    for (const r of withNeedToBuy) {
      const key = r.manufacturer_id ?? '__no_manufacturer__';
      if (!groups.has(key)) {
        groups.set(key, {
          manufacturer_id: r.manufacturer_id,
          manufacturer_name: r.manufacturer_name,
          vendor_id: r.vendor_id,
          vendor_name: r.vendor_name,
          rows: [],
        });
      }
      groups.get(key)!.rows.push(r);
    }

    const results: CreatedPO[] = [];
    for (const [, group] of groups) {
      const lines: CreatePOLineInput[] = [];

      // De-duplicate by catalog_item_id: only one PO line per item
      const itemLineMap = new Map<string, DemandRow>();
      for (const r of group.rows) {
        if (r.need_to_buy <= 0) continue;
        if (!itemLineMap.has(r.catalog_item_id)) {
          itemLineMap.set(r.catalog_item_id, r);
        }
      }

      for (const [, r] of itemLineMap) {
        const needToBuy = r.need_to_buy;
        const costExw = Number(r.cost_exw) || 0;

        const model = resolveInventoryUnitModel({
          isRoll: r.is_roll,
          measureBasis: (r.measure_basis || 'unit') as MeasureBasis,
          purchaseUnit: r.purchase_unit,
        });

        const conversion = convertInternalToPurchaseQty({
          internalQty: needToBuy,
          purchaseMode: model.purchaseMode,
          purchaseUnit: r.purchase_unit || 'ea',
          unitsPerPurchaseUnit: r.units_per_purchase_unit,
          rollLengthValue: r.roll_length_value,
          rollLengthUom: r.roll_length_uom,
        });

        const orderQty = conversion.orderQty;
        const lineUnit = conversion.lineUnit;
        const unitCost = conversion.unitCost(costExw);

        const moIds = group.rows
          .filter(row => row.catalog_item_id === r.catalog_item_id)
          .map(row => row.manufacturing_order_id);

        lines.push({
          catalog_item_id: r.catalog_item_id,
          ordered_qty: orderQty,
          unit_cost: unitCost,
          unit: lineUnit,
          description: r.item_name ?? null,
          is_one_off: false,
          allocation_type: 'manufacturing_order' as const,
          allocation_mo_id: moIds[0],
          sku_snapshot: r.sku ?? null,
          item_name_snapshot: r.item_name ?? null,
          purchase_unit_snapshot: r.purchase_unit ?? null,
          units_per_purchase_unit_snapshot: r.units_per_purchase_unit ?? 1,
          is_roll_snapshot: r.is_roll,
          roll_length_value_snapshot: r.roll_length_value ?? null,
          roll_length_uom_snapshot: r.roll_length_uom ?? null,
          unit_of_measure_snapshot: r.unit_of_measure ?? null,
        });
      }

      const allMoIds = [...new Set(group.rows.map(r => r.manufacturing_order_id))];

      try {
        const po = await createPurchaseOrder({
          warehouse_id: defaultWarehouse.id,
          vendor_id: group.vendor_id,
          lines,
          manufacturing_order_ids: allMoIds,
        });
        results.push({
          id: po.id,
          po_number: po.po_number ?? po.id,
          manufacturer_name: group.manufacturer_name,
          vendor_name: group.vendor_name,
          line_count: lines.length,
        });
      } catch (err: unknown) {
        const label = group.manufacturer_name ?? group.vendor_name ?? 'Unknown';
        addNotification({ type: 'error', title: 'Error', message: `Failed to create PO for ${label}: ${(err as Error).message}` });
      }
    }

    if (results.length > 0) {
      setCreatedPOs(results);
      setSelectedRows(new Set());
      const noVendor = results.filter(r => !r.vendor_name);
      if (noVendor.length > 0) {
        const names = noVendor.map(r => r.manufacturer_name ?? 'Unknown').join(', ');
        addNotification({
          type: 'warning',
          title: 'POs Created Without Vendor',
          message: `${noVendor.length} PO(s) created without a vendor for: ${names}. Assign vendors in Partners > Vendors.`,
        });
      }
      addNotification({ type: 'success', title: 'Purchase Orders Created', message: `${results.length} PO(s) created successfully.` });
      await queryClient.invalidateQueries({ queryKey: ['material-demand', activeOrganizationId] });
    }
  }, [demandRows, selectedRows, defaultWarehouse, createPurchaseOrder, addNotification, queryClient, activeOrganizationId]);

  return (
    <div className="py-6 px-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Material Demand</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Materials required by open Manufacturing Orders
          </p>
        </div>
        {selectedRows.size > 0 && (
          <div className="flex items-center gap-3">
            <span className="text-sm text-gray-500">{selectedRows.size} selected</span>
            <button
              type="button"
              onClick={handleCreatePOFromSelected}
              disabled={isCreating}
              className="inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {isCreating ? <Loader2 className="w-4 h-4 animate-spin" /> : <ShoppingCart className="w-4 h-4" />}
              {isCreating ? 'Creating POs...' : 'Create PO(s) from Selected'}
            </button>
          </div>
        )}
      </div>

      {/* Filters */}
      <div className="mb-4 flex items-center gap-3 flex-wrap">
          <div className="relative min-w-[200px]">
            <button
              type="button"
              onClick={() => setShowMODropdown(!showMODropdown)}
              className="w-full flex items-center justify-between px-3 py-2 border border-gray-300 rounded-lg text-sm bg-white hover:bg-gray-50"
            >
              <span className="flex items-center gap-1.5">
                <Filter className="w-3.5 h-3.5 text-gray-400" />
                <span className={filterMoId ? 'text-gray-900' : 'text-gray-400'}>
                  {selectedMOLabel ?? 'All MOs'}
                </span>
              </span>
              {filterMoId ? (
                <button type="button" onClick={e => { e.stopPropagation(); setFilterMoId(null); }} className="p-0.5 hover:bg-gray-100 rounded">
                  <X className="w-3.5 h-3.5 text-gray-400" />
                </button>
              ) : (
                <ChevronDown className="w-4 h-4 text-gray-400" />
              )}
            </button>
            {showMODropdown && (
              <div className="absolute z-30 mt-1 w-full bg-white border border-gray-200 rounded-lg shadow-lg max-h-64 overflow-hidden">
                <div className="p-2 border-b">
                  <input
                    type="text"
                    placeholder="Search MO#..."
                    value={moFilterSearch}
                    onChange={e => setMoFilterSearch(e.target.value)}
                    className="w-full px-2 py-1.5 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                    autoFocus
                  />
                </div>
                <div className="max-h-48 overflow-y-auto">
                  <button
                    type="button"
                    onClick={() => { setFilterMoId(null); setShowMODropdown(false); setMoFilterSearch(''); }}
                    className={`w-full text-left px-3 py-2 text-sm hover:bg-gray-50 ${!filterMoId ? 'bg-primary/5 font-medium' : ''}`}
                  >
                    All MOs
                  </button>
                  {filteredMoOptions.length === 0 ? (
                    <div className="px-3 py-4 text-sm text-gray-500 text-center">No MOs found</div>
                  ) : filteredMoOptions.map(mo => (
                    <button
                      key={mo.id}
                      type="button"
                      onClick={() => { setFilterMoId(mo.id); setShowMODropdown(false); setMoFilterSearch(''); }}
                      className={`w-full text-left px-3 py-2 text-sm hover:bg-gray-50 ${filterMoId === mo.id ? 'bg-primary/5 font-medium' : ''}`}
                    >
                      {mo.manufacturing_order_no}
                    </button>
                  ))}
                </div>
              </div>
            )}
          </div>

        <div className="relative flex-1 min-w-[200px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <Input
            type="text"
            placeholder="Search SKU, item name..."
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
            className="pl-10"
          />
        </div>

        <label className="inline-flex items-center gap-2 text-sm text-gray-600 cursor-pointer whitespace-nowrap select-none">
          <input
            type="checkbox"
            checked={needToBuyOnly}
            onChange={e => setNeedToBuyOnly(e.target.checked)}
            className="rounded border-gray-300 text-primary focus:ring-primary/20"
          />
          Need to Buy
        </label>
      </div>

      {/* Created POs Banner */}
      {createdPOs && createdPOs.length > 0 && (
        <div className="mb-4 rounded-lg border border-green-200 bg-green-50 p-4">
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-semibold text-green-800">Purchase Orders Created</h3>
            <button type="button" onClick={() => setCreatedPOs(null)} className="text-green-600 hover:text-green-800">
              <X className="w-4 h-4" />
            </button>
          </div>
          <div className="space-y-1.5">
            {createdPOs.map(po => (
              <div key={po.id} className="flex items-center justify-between text-sm">
                <span className="text-green-900">
                  <span className="font-medium">{po.po_number}</span>
                  <span className="text-green-700 ml-2">{po.manufacturer_name ?? 'Unknown'}</span>
                  {po.vendor_name
                    ? <span className="text-green-600 ml-1">→ {po.vendor_name}</span>
                    : <span className="text-amber-600 ml-1">(no vendor assigned)</span>
                  }
                  <span className="text-green-600 ml-2">({po.line_count} lines)</span>
                </span>
                <button
                  type="button"
                  onClick={() => {
                    sessionStorage.setItem('currentPurchaseOrderId', po.id);
                    router.navigate(`/inventory/purchase-orders/${po.id}`);
                  }}
                  className="inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline"
                >
                  Open <ExternalLink className="w-3 h-3" />
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Loading */}
      {demandLoading ? (
        <div className="animate-pulse space-y-3">
          <div className="h-10 bg-gray-100 rounded" />
          <div className="h-10 bg-gray-100 rounded" />
          <div className="h-10 bg-gray-100 rounded" />
        </div>
      ) : (
        /* MO Demand Table */
        <div className="rounded-lg border border-gray-200 bg-white shadow-sm overflow-auto max-h-[calc(100vh-260px)]">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b sticky top-0 z-10">
              <tr>
                <th className="px-4 py-3 text-center w-10">
                  <input
                    type="checkbox"
                    checked={allFilteredSelected && filteredDemand.length > 0}
                    onChange={toggleSelectAll}
                    className="rounded border-gray-300 text-primary focus:ring-primary/20"
                  />
                </th>
                <th className="px-4 py-3 text-left font-medium text-gray-700 w-36">MO #</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700 w-32">Status</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700 cursor-pointer w-36" onClick={() => handleSort('sku')}>
                  SKU <SortIcon col="sku" />
                </th>
                <th className="px-4 py-3 text-left font-medium text-gray-700 min-w-[220px]">Item</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700 w-20">UOM</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700 cursor-pointer w-28" onClick={() => handleSort('required_qty')}>
                  Required <SortIcon col="required_qty" />
                </th>
                <th className="px-4 py-3 text-right font-medium text-gray-700 w-28">On Hand</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700 w-28">On Order</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700 cursor-pointer w-32" onClick={() => handleSort('need_to_buy')}>
                  Status <SortIcon col="need_to_buy" />
                </th>
              </tr>
            </thead>
            <tbody>
              {filteredDemand.length === 0 ? (
                <tr><td colSpan={10} className="px-4 py-8 text-center text-gray-500">
                  {needToBuyOnly && (demandRows ?? []).length > 0
                    ? 'All materials are covered (on hand + on order). Uncheck "Need to Buy" to see all items.'
                    : 'No material demand found'}
                </td></tr>
              ) : filteredDemand.map((r, i) => {
                const needToBuy = r.need_to_buy;
                const key = rowKey(r);
                return (
                  <tr key={`${r.manufacturing_order_id}-${r.catalog_item_id}-${i}`} className="border-t hover:bg-gray-50">
                    <td className="px-4 py-3 text-center">
                      <input
                        type="checkbox"
                        checked={selectedRows.has(key)}
                        onChange={() => toggleSelectRow(key)}
                        disabled={needToBuy <= 0}
                        className="rounded border-gray-300 text-primary focus:ring-primary/20 disabled:opacity-30 disabled:cursor-not-allowed"
                      />
                    </td>
                    <td className="px-4 py-3 font-medium text-gray-900">{r.manufacturing_order_no}</td>
                    <td className="px-4 py-3">
                      <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                        r.mo_status === 'in_production' ? 'bg-yellow-50 text-yellow-700' :
                        r.mo_status === 'planned' ? 'bg-blue-50 text-blue-700' :
                        'bg-gray-50 text-gray-700'
                      }`}>
                        {r.mo_status.replace(/_/g, ' ')}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-gray-900">{r.sku ?? '—'}</td>
                    <td className="px-4 py-3 text-gray-700">{r.item_name ?? '—'}</td>
                    <td className="px-4 py-3 text-gray-600">{r.uom ?? 'ea'}</td>
                    <td className="px-4 py-3 text-right tabular-nums font-medium">{Number(r.required_qty).toFixed(2)}</td>
                    <td className="px-4 py-3 text-right tabular-nums text-gray-600">{Number(r.on_hand).toFixed(2)}</td>
                    <td className="px-4 py-3 text-right tabular-nums text-gray-600">{r.on_order > 0 ? Number(r.on_order).toFixed(2) : '—'}</td>
                    <td className="px-4 py-3 text-right">
                      {needToBuy > 0 ? (
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-red-50 text-red-700">
                          -{needToBuy.toFixed(2)}
                        </span>
                      ) : (
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-50 text-green-700">
                          In Stock
                        </span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {/* Row count */}
      <div className="mt-3 text-xs text-gray-500">
        {filteredDemand.length} item{filteredDemand.length === 1 ? '' : 's'}
        {selectedRows.size > 0 && ` · ${selectedRows.size} selected`}
      </div>
    </div>
  );
}
