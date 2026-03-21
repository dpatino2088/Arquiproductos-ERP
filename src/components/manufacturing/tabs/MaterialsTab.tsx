import { useState, useEffect, useMemo, useCallback } from 'react';
import { useManufacturingMaterials } from '../../../hooks/useManufacturing';
import { formatCurrency } from '../../../lib/utils';
import type { ManufacturingOrderStatus } from '../../../hooks/useManufacturing';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { useWarehouses } from '../../../hooks/useWarehouses';
import { useInventoryAvailability } from '../../../hooks/useInventoryAvailability';
import { InventoryAvailabilityBadge } from '../../inventory/InventoryAvailabilityBadge';
import { useMOAllocations, useAllocateToMO, useReleaseMOAllocation, useAllMOAllocationsForItem, useTransferAllocation } from '../../../hooks/useInventoryAllocations';
import type { InventoryAvailabilityRow } from '../../../types/inventory';
import { useUIStore } from '../../../stores/ui-store';
import StatusBadge from '../../shared/StatusBadge';
import { Package, XCircle, Loader2, ArrowRightLeft, ChevronRight, ChevronDown, Search, AlertTriangle, Calendar, ShieldAlert, ShoppingCart } from 'lucide-react';

interface MaterialsTabProps {
  moId: string;
  saleOrderId: string | null;
  moStatus: ManufacturingOrderStatus;
  currency?: string;
  /** Called after BOM is generated so parent can refresh MO lines / timeline */
  onBOMGenerated?: () => void;
}

// Category order matches the new BOM structure
const CATEGORY_ORDER = [
  'fabric',
  'tube',
  'motor',
  'bracket',
  'cassette',
  'side_channel',
  'bottom_channel',
  'accessory',
];

// Category labels organized by block_type/category
const CATEGORY_LABELS: Record<string, string> = {
  fabric: 'Fabric',
  tube: 'Tube',
  motor: 'Motor / Drive',
  bracket: 'Bracket',
  cassette: 'Cassette',
  side_channel: 'Side Channel',
  bottom_channel: 'Bottom Rail / Bottom Channel',
  accessory: 'Accessory',
};

type ViewMode = 'category' | 'sku';

interface AggregatedMaterial {
  catalog_item_id: string;
  sku: string;
  item_name: string;
  part_role: string;
  uom: string;
  totalQty: number;
  unitCost: number | undefined;
  totalCost: number;
  unitMsrp: number | undefined;
  totalMsrp: number;
}

export default function MaterialsTab({ moId, saleOrderId: _saleOrderId, moStatus, currency = 'USD', onBOMGenerated: _onBOMGenerated }: MaterialsTabProps) {
  const { materials, bomTotals, loading, error, hasBomInstances, hasBomLines, debugCounts } = useManufacturingMaterials(moId);
  const [showCosts, setShowCosts] = useState(false);
  const [viewMode, setViewMode] = useState<ViewMode>('category');
  const [shouldShowError, setShouldShowError] = useState(false);

  const { activeOrganizationId } = useOrganizationContext();
  const { defaultWarehouse } = useWarehouses(activeOrganizationId);
  const addNotification = useUIStore((s) => s.addNotification);

  const { allocations, loading: allocLoading, refetch: refetchAllocations } = useMOAllocations(moId);
  const { allocate, isAllocating } = useAllocateToMO();
  const { release, isReleasing } = useReleaseMOAllocation();
  const [showReleaseConfirm, setShowReleaseConfirm] = useState(false);
  const [allocSearch, setAllocSearch] = useState('');
  const [allocFilter, setAllocFilter] = useState<'all' | 'shortages' | 'ok'>('all');
  const [expandedSkuId, setExpandedSkuId] = useState<string | null>(null);
  const [materialSubTab, setMaterialSubTab] = useState<'materials' | 'allocation'>('materials');

  const allocationMap = useMemo(() => {
    const map = new Map<string, number>();
    for (const a of allocations) {
      map.set(a.catalog_item_id, (map.get(a.catalog_item_id) ?? 0) + a.allocated_qty);
    }
    return map;
  }, [allocations]);

  const aggregatedBySku = useMemo<AggregatedMaterial[]>(() => {
    const map = new Map<string, AggregatedMaterial>();
    for (const m of materials) {
      const existing = map.get(m.catalog_item_id);
      if (existing) {
        existing.totalQty += m.qty;
        existing.totalCost += m.total_cost_exw;
        existing.totalMsrp += (m.total_msrp || 0);
      } else {
        map.set(m.catalog_item_id, {
          catalog_item_id: m.catalog_item_id,
          sku: m.sku,
          item_name: m.item_name,
          part_role: m.part_role,
          uom: m.uom,
          totalQty: m.qty,
          unitCost: m.unit_cost_exw,
          totalCost: m.total_cost_exw,
          unitMsrp: m.unit_msrp,
          totalMsrp: m.total_msrp || 0,
        });
      }
    }
    return [...map.values()].sort((a, b) => a.sku.localeCompare(b.sku));
  }, [materials]);

  const allocStats = useMemo(() => {
    return aggregatedBySku.reduce((acc, agg) => {
      const allocated = allocationMap.get(agg.catalog_item_id) ?? 0;
      const gap = Math.round((agg.totalQty - allocated) * 10000) / 10000;
      acc.totalRequired += agg.totalQty;
      acc.totalAllocated += allocated;
      if (gap <= 0) acc.ok++;
      else if (allocated > 0) acc.partial++;
      else acc.shortage++;
      return acc;
    }, { totalRequired: 0, totalAllocated: 0, ok: 0, partial: 0, shortage: 0 });
  }, [aggregatedBySku, allocationMap]);

  const allocPct = useMemo(() => {
    return allocStats.totalRequired > 0
      ? Math.min(100, Math.round((allocStats.totalAllocated / allocStats.totalRequired) * 100))
      : 0;
  }, [allocStats]);

  const handleAllocateAll = useCallback(async () => {
    if (!activeOrganizationId || !defaultWarehouse) return;
    const MIN_QTY = 0.0001;
    const items = aggregatedBySku
      .map(m => {
        const alreadyAllocated = allocationMap.get(m.catalog_item_id) ?? 0;
        const gap = Math.round((m.totalQty - alreadyAllocated) * 10000) / 10000;
        return { catalog_item_id: m.catalog_item_id, qty: gap };
      })
      .filter(item => item.qty >= MIN_QTY);
    if (items.length === 0) {
      addNotification({ type: 'info', title: 'Allocation', message: 'All materials already allocated.' });
      return;
    }
    try {
      const result = await allocate(activeOrganizationId, defaultWarehouse.id, moId, items);
      const allocated = (result?.results ?? []).filter((r: any) => r.allocated > 0).length;
      addNotification({ type: 'success', title: 'Allocated', message: `${allocated} material(s) allocated from warehouse.` });
      refetchAllocations();
    } catch (err: unknown) {
      addNotification({ type: 'error', title: 'Error', message: (err as Error).message });
    }
  }, [activeOrganizationId, defaultWarehouse, moId, aggregatedBySku, allocationMap, allocate, addNotification, refetchAllocations]);

  const handleReleaseAll = useCallback(async () => {
    if (allocations.length === 0) return;
    try {
      const result = await release(moId);
      addNotification({ type: 'success', title: 'Released', message: `${result?.released_count ?? 0} allocation(s) released.` });
      refetchAllocations();
    } catch (err: unknown) {
      addNotification({ type: 'error', title: 'Error', message: (err as Error).message });
    }
  }, [moId, allocations, release, addNotification, refetchAllocations]);

  const handleReleaseItem = useCallback(async (catalogItemId: string) => {
    try {
      await release(moId, catalogItemId);
      addNotification({ type: 'success', title: 'Released', message: 'Allocation released.' });
      refetchAllocations();
    } catch (err: unknown) {
      addNotification({ type: 'error', title: 'Error', message: (err as Error).message });
    }
  }, [moId, release, addNotification, refetchAllocations]);
  const catalogItemIds = useMemo(
    () => [...new Set(materials.map((m) => m.catalog_item_id).filter(Boolean))],
    [materials]
  );
  const { map: availabilityMap } = useInventoryAvailability({
    organizationId: activeOrganizationId ?? null,
    warehouseId: defaultWarehouse?.id ?? null,
    catalogItemIds,
  });

  // Only show error if it persists after loading completes (not stale state)
  useEffect(() => {
    if (error && !loading) {
      // Delay showing error to avoid flashing during refetch
      const timer = setTimeout(() => {
        setShouldShowError(true);
      }, 100);
      return () => clearTimeout(timer);
    } else if (!error) {
      setShouldShowError(false);
    }
  }, [error, loading]);

  // ✅ FIX: Group materials by category_code first (fallback to part_role)
  // This ensures consistent grouping by category (hardware/tube/drive/bottom_bar/bracket/fabric/accessory)
  // instead of by role which can be inconsistent (e.g., operating_system_drive vs drive_manual)
  const groupedMaterials = materials.reduce((acc, material) => {
    // Use category_code as primary grouping key, fallback to part_role if category_code is null
    const category = material.category_code || material.part_role || 'accessory';
    if (!acc[category]) {
      acc[category] = [];
    }
    acc[category].push(material);
    return acc;
  }, {} as Record<string, typeof materials>);
  
  useEffect(() => {
    // Track materials for debugging (DEV only)
    if (materials.length > 0 && import.meta.env.DEV) {
      const uomCounts = materials.reduce((acc, m) => {
        acc[m.uom] = (acc[m.uom] || 0) + 1;
        return acc;
      }, {} as Record<string, number>);
      console.warn('[DEBUG] Materials displayed', {
        materialsCount: materials.length,
        groupedCategories: Object.keys(groupedMaterials),
        uomDistribution: uomCounts
      });
    }
  }, [materials, groupedMaterials]);

  // Sort categories by predefined order
  const sortedCategories = Object.keys(groupedMaterials).sort((a, b) => {
    const indexA = CATEGORY_ORDER.indexOf(a);
    const indexB = CATEGORY_ORDER.indexOf(b);
    if (indexA === -1 && indexB === -1) return a.localeCompare(b);
    if (indexA === -1) return 1;
    if (indexB === -1) return -1;
    return indexA - indexB;
  });

  if (loading) {
    return (
      <div className="p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-gray-200 rounded"></div>
          <div className="h-32 bg-gray-200 rounded"></div>
        </div>
      </div>
    );
  }

  if (error && shouldShowError) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error loading materials</p>
          <p className="text-sm text-red-700">{error}</p>
        </div>
      </div>
    );
  }

  // Show appropriate message based on state
  if (!hasBomInstances) {
    return (
      <div className="p-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
          <div className="flex items-start gap-3">
            <div className="flex-shrink-0">
              <svg className="h-5 w-5 text-yellow-600" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
              </svg>
            </div>
            <div className="flex-1">
              <h3 className="text-sm font-medium text-yellow-800 mb-1">
                No se crearon BOMInstances para este Manufacturing Order
              </h3>
              <p className="text-sm text-yellow-700 mb-3">
                No hay BOMInstances asociados a este MO. Revisa que el MO tenga ManufacturingOrderLines y BOM Templates configurados.
              </p>
              <div className="text-xs text-yellow-600 space-y-1">
                <p>• Debug: BOMInstances = {debugCounts.bomInstances}, BOMInstanceLines = {debugCounts.bomLines}</p>
                <p>• Verifica que el MO tenga SalesOrderLines asociados</p>
                <p>• Verifica que exista un BOM Template activo para el product_type de cada línea</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (hasBomInstances && !hasBomLines) {
    return (
      <div className="p-6">
        <div className="bg-orange-50 border border-orange-200 rounded-lg p-4 mb-4">
          <div className="flex items-start gap-3">
            <div className="flex-shrink-0">
              <svg className="h-5 w-5 text-orange-600" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
              </svg>
            </div>
            <div className="flex-1">
              <h3 className="text-sm font-medium text-orange-800 mb-1">
                BOMInstances creados pero 0 líneas generadas
              </h3>
              <p className="text-sm text-orange-700 mb-3">
                Se crearon {debugCounts.bomInstances} BOMInstance(s) pero no se generaron BOMInstanceLines. Revisa BomTemplateComponents y reglas de auto-select.
              </p>
              <div className="text-xs text-orange-600 space-y-1">
                <p>• Debug: BOMInstances = {debugCounts.bomInstances}, BOMInstanceLines = {debugCounts.bomLines}</p>
                <p>• Verifica que el BOM Template tenga componentes (BomTemplateComponents) con component_item_id no NULL</p>
                <p>• Verifica que los CatalogItems referenciados existan y estén activos</p>
                <p>• Revisa los logs de la RPC para ver warnings específicos</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (materials.length === 0) {
    return (
      <div className="p-6">
        <div className="text-center text-gray-500 py-12">
          <p className="mb-2">No frozen BOM materials found for this Sale Order yet.</p>
          <p className="text-xs mt-2 text-gray-400">Materials are generated automatically when creating the Manufacturing Order.</p>
        </div>
      </div>
    );
  }

  return (
    <div>
      {/* Sub-tabs: Materials / Allocation */}
      <div className="flex border-b border-gray-200 mb-4">
        <button
          type="button"
          onClick={() => setMaterialSubTab('materials')}
          className={`px-4 py-2.5 text-sm font-medium border-b-2 transition-colors ${
            materialSubTab === 'materials'
              ? 'border-gray-900 text-gray-900'
              : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
        >
          Materials
        </button>
        <button
          type="button"
          onClick={() => setMaterialSubTab('allocation')}
          className={`px-4 py-2.5 text-sm font-medium border-b-2 transition-colors flex items-center gap-2 ${
            materialSubTab === 'allocation'
              ? 'border-gray-900 text-gray-900'
              : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
        >
          Allocation
          {(allocStats.shortage + allocStats.partial > 0) && (
            <span className={`inline-flex items-center px-1.5 py-0.5 rounded-full text-[10px] font-medium ${
              allocStats.shortage > 0 ? 'bg-red-100 text-red-700' : 'bg-amber-100 text-amber-700'
            }`}>
              {allocStats.shortage + allocStats.partial}
            </span>
          )}
          {allocStats.shortage + allocStats.partial === 0 && allocPct === 100 && (
            <span className="inline-flex items-center px-1.5 py-0.5 rounded-full text-[10px] font-medium bg-green-100 text-green-700">OK</span>
          )}
        </button>
      </div>

      {materialSubTab === 'materials' && (<>
      {/* Controls */}
      <div className="mb-4 space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-semibold text-gray-900">Manufacturing BOM / Material List</h3>
          <div className="flex items-center gap-4">
            <div className="inline-flex rounded-lg border border-gray-300 overflow-hidden">
              <button
                onClick={() => setViewMode('category')}
                className={`px-3 py-1.5 text-xs font-medium transition-colors ${
                  viewMode === 'category'
                    ? 'bg-gray-900 text-white'
                    : 'bg-white text-gray-700 hover:bg-gray-50'
                }`}
              >
                By Category
              </button>
              <button
                onClick={() => setViewMode('sku')}
                className={`px-3 py-1.5 text-xs font-medium transition-colors border-l border-gray-300 ${
                  viewMode === 'sku'
                    ? 'bg-gray-900 text-white'
                    : 'bg-white text-gray-700 hover:bg-gray-50'
                }`}
              >
                By SKU
              </button>
            </div>
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={showCosts}
                onChange={(e) => setShowCosts(e.target.checked)}
                className="rounded border-gray-300 text-primary focus:ring-primary"
              />
              <span className="text-sm text-gray-700">Show costs</span>
            </label>
          </div>
        </div>
      </div>

      {viewMode === 'sku' ? (
        /* ===== BY SKU VIEW (aggregated summary) ===== */
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <div className="bg-gray-50 px-6 py-3 border-b border-gray-200">
            <h4 className="text-sm font-semibold text-gray-900">
              Material Summary — {aggregatedBySku.length} unique SKUs
            </h4>
          </div>
          <div className="max-h-[60vh] overflow-y-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200 sticky top-0 z-10 shadow-[0_1px_0_0_theme(colors.gray.200)]">
                <tr>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">SKU</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Description</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Role</th>
                  <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Total Qty</th>
                  <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">UoM</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Availability</th>
                  {showCosts && (
                    <>
                      <th className="text-right py-3 px-6 font-medium text-blue-900 text-xs">Unit MSRP</th>
                      <th className="text-right py-3 px-6 font-medium text-blue-900 text-xs">Total MSRP</th>
                      <th className="text-right py-3 px-6 font-medium text-gray-500 text-xs">Unit Cost</th>
                      <th className="text-right py-3 px-6 font-medium text-gray-500 text-xs">Total Cost</th>
                    </>
                  )}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {aggregatedBySku.map((agg) => (
                  <tr key={agg.catalog_item_id} className="hover:bg-gray-50">
                    <td className="py-3 px-6 text-sm text-gray-900 font-mono">{agg.sku}</td>
                    <td className="py-3 px-6 text-sm text-gray-700">{agg.item_name}</td>
                    <td className="py-3 px-6 text-sm text-gray-700">{agg.part_role}</td>
                    <td className="py-3 px-6 text-sm text-gray-900 text-right font-semibold">
                      {agg.uom === 'm' ? agg.totalQty.toFixed(2) : agg.totalQty.toFixed(0)}
                    </td>
                    <td className="py-3 px-6 text-sm text-gray-700 text-right">{agg.uom}</td>
                    <td className="py-3 px-6 text-sm">
                      <InventoryAvailabilityBadge row={availabilityMap[agg.catalog_item_id]} />
                    </td>
                    {showCosts && (
                      <>
                        <td className="py-3 px-6 text-sm text-blue-700 text-right font-medium">
                          {agg.unitMsrp ? formatCurrency(agg.unitMsrp, currency) : 'N/A'}
                        </td>
                        <td className="py-3 px-6 text-sm text-blue-900 text-right font-bold">
                          {agg.totalMsrp ? formatCurrency(agg.totalMsrp, currency) : 'N/A'}
                        </td>
                        <td className="py-3 px-6 text-sm text-gray-500 text-right text-xs">
                          {agg.unitCost ? formatCurrency(agg.unitCost, currency) : 'N/A'}
                        </td>
                        <td className="py-3 px-6 text-sm text-gray-500 text-right text-xs">
                          {formatCurrency(agg.totalCost, currency)}
                        </td>
                      </>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        /* ===== BY CATEGORY VIEW (detailed, per BOMInstance line) ===== */
        <div className="space-y-6">
          {sortedCategories.map((category) => {
            const categoryMaterials = groupedMaterials[category];
            if (!categoryMaterials || categoryMaterials.length === 0) return null;

            const categoryTotal = categoryMaterials.reduce((sum, m) => sum + m.total_cost_exw, 0);
            const categoryTotalMSRP = categoryMaterials.reduce((sum, m) => sum + (m.total_msrp || 0), 0);

            return (
              <div key={category} className="bg-white border border-gray-200 rounded-lg overflow-hidden">
                <div className="bg-gray-50 px-4 py-2.5 border-b border-gray-200">
                  <div className="flex items-center justify-between">
                    <h4 className="text-sm font-semibold text-gray-900">
                      {CATEGORY_LABELS[category] || category}
                    </h4>
                    {showCosts && (
                      <div className="flex items-center gap-4">
                        <span className="text-sm font-medium text-gray-700">
                          Cost: {formatCurrency(categoryTotal, currency)}
                        </span>
                        <span className="text-sm font-bold text-blue-700">
                          MSRP: {formatCurrency(categoryTotalMSRP, currency)}
                        </span>
                      </div>
                    )}
                  </div>
                </div>

                <div className="table-fit-wrapper">
                  <table className="table-fit w-full">
                    <thead className="bg-gray-50 border-b border-gray-200">
                      <tr>
                        <th className="text-left py-2.5 px-4 font-medium text-gray-900 text-xs">SKU</th>
                        <th className="text-left py-2.5 px-4 font-medium text-gray-900 text-xs">Description</th>
                        <th className="text-left py-2.5 px-4 font-medium text-gray-900 text-xs">Role</th>
                        <th className="text-right py-2.5 px-4 font-medium text-gray-900 text-xs">Qty</th>
                        <th className="text-right py-2.5 px-4 font-medium text-gray-900 text-xs">UoM</th>
                        <th className="text-right py-2.5 px-4 font-medium text-gray-900 text-xs">Width (mm)</th>
                        <th className="text-right py-2.5 px-4 font-medium text-gray-900 text-xs">Height (mm)</th>
                        <th className="text-left py-2.5 px-4 font-medium text-gray-900 text-xs">Availability</th>
                        {showCosts && (
                          <>
                            <th className="text-right py-2.5 px-4 font-medium text-blue-900 text-xs">Unit MSRP</th>
                            <th className="text-right py-2.5 px-4 font-medium text-blue-900 text-xs">Total MSRP</th>
                            <th className="text-right py-2.5 px-4 font-medium text-gray-500 text-xs">Unit Cost</th>
                            <th className="text-right py-2.5 px-4 font-medium text-gray-500 text-xs">Total Cost</th>
                          </>
                        )}
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-200">
                      {categoryMaterials.map((material) => (
                        <tr key={material.bom_instance_line_id} className="hover:bg-gray-50">
                          <td className="py-2.5 px-4 text-sm text-gray-900 font-mono">{material.sku || 'N/A'}</td>
                          <td className="py-2.5 px-4 text-sm text-gray-700">{material.item_name || 'N/A'}</td>
                          <td className="py-2.5 px-4 text-sm text-gray-700">{material.part_role || 'N/A'}</td>
                          <td className="py-2.5 px-4 text-sm text-gray-900 text-right font-medium">
                            {material.uom === 'm' ? material.qty.toFixed(2) : material.qty.toFixed(0)}
                          </td>
                          <td className="py-2.5 px-4 text-sm text-gray-700 text-right">{material.uom}</td>
                          <td className="py-2.5 px-4 text-sm text-gray-700 text-right">
                            {material.product_width_mm != null ? material.product_width_mm.toLocaleString() : '—'}
                          </td>
                          <td className="py-2.5 px-4 text-sm text-gray-700 text-right">
                            {material.product_height_mm != null ? material.product_height_mm.toLocaleString() : '—'}
                          </td>
                          <td className="py-2.5 px-4 text-sm">
                            <InventoryAvailabilityBadge row={availabilityMap[material.catalog_item_id]} />
                          </td>
                          {showCosts && (
                            <>
                              <td className="py-2.5 px-4 text-sm text-blue-700 text-right font-medium">
                                {material.unit_msrp ? formatCurrency(material.unit_msrp, currency) : 'N/A'}
                              </td>
                              <td className="py-2.5 px-4 text-sm text-blue-900 text-right font-bold">
                                {material.total_msrp ? formatCurrency(material.total_msrp, currency) : 'N/A'}
                              </td>
                              <td className="py-2.5 px-4 text-sm text-gray-500 text-right text-xs">
                                {material.unit_cost_exw ? formatCurrency(material.unit_cost_exw, currency) : 'N/A'}
                              </td>
                              <td className="py-2.5 px-4 text-sm text-gray-500 text-right text-xs">
                                {formatCurrency(material.total_cost_exw, currency)}
                              </td>
                            </>
                          )}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Grand Total / Summary */}
      {(materials.length > 0 || bomTotals.totalCostWithLabor > 0) && (
        <div className="mt-6 bg-gray-50 border border-gray-200 rounded-lg p-4">
          <div className="space-y-3">
            <div className="flex justify-between items-center">
              <span className="text-sm font-semibold text-gray-900">Grand Totals:</span>
              <div className="flex items-center gap-6">
                <div className="text-right">
                  <div className="text-xs text-gray-600 mb-1">Total Cost (Items)</div>
                  <div className="text-lg font-bold text-gray-900">
                    {formatCurrency(
                      materials.reduce((sum, m) => sum + m.total_cost_exw, 0),
                      currency
                    )}
                  </div>
                </div>
                {bomTotals.totalLaborCost > 0 && (
                  <div className="text-right">
                    <div className="text-xs text-orange-600 mb-1">Labor Cost</div>
                    <div className="text-lg font-bold text-orange-700">
                      {formatCurrency(bomTotals.totalLaborCost, currency)}
                    </div>
                  </div>
                )}
                <div className="text-right">
                  <div className="text-xs text-gray-700 mb-1">Total Cost (with Labor)</div>
                  <div className="text-lg font-bold text-gray-900">
                    {formatCurrency(bomTotals.totalCostWithLabor || materials.reduce((sum, m) => sum + m.total_cost_exw, 0), currency)}
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-xs text-blue-600 mb-1">Total MSRP (PVP)</div>
                  <div className="text-lg font-bold text-blue-700">
                    {formatCurrency(
                      bomTotals.totalMSRPWithLabor || materials.reduce((sum, m) => sum + (m.total_msrp || 0), 0),
                      currency
                    )}
                  </div>
                </div>
              </div>
            </div>
            {bomTotals.totalLaborCost > 0 && (
              <div className="text-xs text-gray-500 pt-2 border-t border-gray-300">
                * MSRP includes labor cost in the calculation
              </div>
            )}
          </div>
        </div>
      )}
      </>)}

      {/* ===== INVENTORY ALLOCATION ===== */}
      {materialSubTab === 'allocation' && materials.length > 0 && (() => {
        const searchLc = allocSearch.toLowerCase();
        const filteredSkus = aggregatedBySku.filter(agg => {
          if (searchLc && !agg.sku.toLowerCase().includes(searchLc) && !agg.item_name.toLowerCase().includes(searchLc)) return false;
          if (allocFilter === 'all') return true;
          const allocated = allocationMap.get(agg.catalog_item_id) ?? 0;
          const gap = Math.round((agg.totalQty - allocated) * 10000) / 10000;
          if (allocFilter === 'shortages') return gap > 0;
          return gap <= 0;
        });

        return (
          <div className="mt-6 bg-white border border-gray-200 rounded-lg overflow-hidden">
            {/* Header with actions */}
            <div className="bg-gray-50 px-4 py-3 border-b flex items-center justify-between">
              <h4 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
                <Package className="w-4 h-4" />
                Inventory Allocation
              </h4>
              <div className="flex items-center gap-2">
                {allocations.length > 0 && (
                  <button
                    type="button"
                    onClick={() => setShowReleaseConfirm(true)}
                    disabled={isReleasing}
                    className="inline-flex items-center gap-1 px-3 py-1.5 text-xs font-medium text-red-700 bg-red-50 rounded-lg hover:bg-red-100 disabled:opacity-50 transition-colors"
                  >
                    {isReleasing ? <Loader2 className="w-3 h-3 animate-spin" /> : <XCircle className="w-3 h-3" />}
                    Release All
                  </button>
                )}
                <button
                  type="button"
                  onClick={handleAllocateAll}
                  disabled={isAllocating || !defaultWarehouse}
                  className="inline-flex items-center gap-1 px-3 py-1.5 text-xs font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50 transition-colors"
                >
                  {isAllocating ? <Loader2 className="w-3 h-3 animate-spin" /> : <Package className="w-3 h-3" />}
                  Allocate Available
                </button>
              </div>
            </div>

            {/* Summary bar */}
            <div className="px-4 py-3 border-b bg-gray-50/50">
              <div className="flex items-center gap-4 mb-2">
                <span className="text-xs font-medium text-gray-700">{aggregatedBySku.length} SKUs</span>
                <span className="text-xs text-green-700 font-medium">{allocStats.ok} OK</span>
                {allocStats.partial > 0 && (
                  <span className="text-xs text-amber-700 font-medium">{allocStats.partial} Partial</span>
                )}
                {allocStats.shortage > 0 && (
                  <span className="text-xs text-red-600 font-medium">{allocStats.shortage} Shortage{allocStats.shortage !== 1 ? 's' : ''}</span>
                )}
                <span className="ml-auto text-xs text-gray-500 tabular-nums">{allocPct}% allocated</span>
              </div>
              <div className="w-full h-2 bg-gray-200 rounded-full overflow-hidden">
                <div
                  className={`h-full rounded-full transition-all duration-500 ${allocPct === 100 ? 'bg-green-500' : allocPct > 0 ? 'bg-amber-500' : 'bg-gray-300'}`}
                  style={{ width: `${allocPct}%` }}
                />
              </div>
            </div>

            {/* Search + Filter row */}
            <div className="px-4 py-2.5 border-b flex items-center gap-3">
              <div className="relative flex-1 max-w-xs">
                <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-400" />
                <input
                  type="text"
                  value={allocSearch}
                  onChange={e => setAllocSearch(e.target.value)}
                  placeholder="Search SKU or name..."
                  className="w-full pl-8 pr-3 py-1.5 text-xs border border-gray-300 rounded-lg focus:ring-1 focus:ring-primary focus:border-primary"
                />
              </div>
              <div className="inline-flex rounded-lg border border-gray-300 overflow-hidden">
                {(['all', 'shortages', 'ok'] as const).map(f => (
                  <button
                    key={f}
                    onClick={() => setAllocFilter(f)}
                    className={`px-3 py-1.5 text-xs font-medium transition-colors ${f !== 'all' ? 'border-l border-gray-300' : ''} ${
                      allocFilter === f ? 'bg-gray-900 text-white' : 'bg-white text-gray-600 hover:bg-gray-50'
                    }`}
                  >
                    {f === 'all' ? `All (${aggregatedBySku.length})` : f === 'shortages' ? `Shortages (${allocStats.shortage + allocStats.partial})` : `OK (${allocStats.ok})`}
                  </button>
                ))}
              </div>
            </div>

            {/* Unified table */}
            {allocLoading ? (
              <div className="px-4 py-8 text-center text-gray-400 text-sm">Loading allocations...</div>
            ) : filteredSkus.length === 0 ? (
              <div className="px-4 py-8 text-center text-gray-400 text-sm">
                {allocSearch ? 'No items match your search.' : 'No items in this filter.'}
              </div>
            ) : (
              <div className="max-h-[60vh] overflow-y-auto">
                <table className="w-full text-sm">
                  <thead className="bg-gray-50 border-b sticky top-0 z-10 shadow-[0_1px_0_0_theme(colors.gray.200)]">
                    <tr>
                      <th className="w-8 px-2 py-2"></th>
                      <th className="px-3 py-2 text-left font-medium text-gray-700 text-xs">SKU</th>
                      <th className="px-3 py-2 text-left font-medium text-gray-700 text-xs">Item</th>
                      <th className="px-3 py-2 text-right font-medium text-gray-700 text-xs">Required</th>
                      <th className="px-3 py-2 text-right font-medium text-gray-700 text-xs">On Hand</th>
                      <th className="px-3 py-2 text-right font-medium text-gray-700 text-xs">Allocated</th>
                      <th className="px-3 py-2 text-right font-medium text-gray-700 text-xs">Gap</th>
                      <th className="px-3 py-2 text-center font-medium text-gray-700 text-xs">Status</th>
                      <th className="px-3 py-2 text-center font-medium text-gray-700 text-xs">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {filteredSkus.map(agg => {
                      const allocated = allocationMap.get(agg.catalog_item_id) ?? 0;
                      const gap = Math.round((agg.totalQty - allocated) * 10000) / 10000;
                      const avail = availabilityMap[agg.catalog_item_id];
                      const onHand = avail?.on_hand_qty ?? 0;
                      const isExpanded = expandedSkuId === agg.catalog_item_id;
                      const statusLabel = gap <= 0 ? 'OK' : allocated > 0 ? 'Partial' : 'Shortage';
                      const statusColor = gap <= 0 ? 'bg-green-100 text-green-700' : allocated > 0 ? 'bg-amber-100 text-amber-700' : 'bg-red-100 text-red-700';
                      const rowBg = gap <= 0 ? '' : 'bg-red-50/40';

                      return (
                        <AllocationRow
                          key={agg.catalog_item_id}
                          agg={agg}
                          allocated={allocated}
                          gap={gap}
                          onHand={onHand}
                          statusLabel={statusLabel}
                          statusColor={statusColor}
                          rowBg={rowBg}
                          isExpanded={isExpanded}
                          onToggle={() => setExpandedSkuId(isExpanded ? null : agg.catalog_item_id)}
                          onRelease={() => handleReleaseItem(agg.catalog_item_id)}
                          isReleasing={isReleasing}
                          moId={moId}
                          orgId={activeOrganizationId}
                          warehouseId={defaultWarehouse?.id ?? null}
                          availability={avail ?? null}
                          onTransferred={refetchAllocations}
                        />
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        );
      })()}

      {showReleaseConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center">
          <div className="absolute inset-0 bg-black/40" onClick={() => setShowReleaseConfirm(false)} />
          <div className="relative bg-white rounded-xl shadow-2xl w-full max-w-md p-6">
            <h3 className="text-base font-semibold text-gray-900 mb-2">Release All Allocations?</h3>
            <p className="text-sm text-gray-600 mb-1">
              This will release <span className="font-semibold text-red-600">{allocations.length} allocated item{allocations.length > 1 ? 's' : ''}</span> back
              to the warehouse, making them available for other MOs.
            </p>
            <p className="text-xs text-gray-500 mb-5">This action cannot be undone. You can re-allocate later if stock is still available.</p>
            <div className="flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setShowReleaseConfirm(false)}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => { setShowReleaseConfirm(false); handleReleaseAll(); }}
                disabled={isReleasing}
                className="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-lg hover:bg-red-700 disabled:opacity-50"
              >
                {isReleasing ? 'Releasing...' : 'Yes, Release All'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

/* ================================================================
   AllocationRow — single SKU row + expandable detail panel
   ================================================================ */

const PRIORITY_CONFIG: Record<string, { label: string; color: string; warn: boolean }> = {
  urgent: { label: 'Urgent', color: 'bg-red-100 text-red-700', warn: true },
  high: { label: 'High', color: 'bg-orange-100 text-orange-700', warn: true },
  normal: { label: 'Normal', color: 'bg-gray-100 text-gray-600', warn: false },
  low: { label: 'Low', color: 'bg-green-100 text-green-700', warn: false },
};

function formatShortDate(d: string | null) {
  if (!d) return null;
  try {
    const dt = new Date(d);
    return `${String(dt.getDate()).padStart(2, '0')}/${String(dt.getMonth() + 1).padStart(2, '0')}`;
  } catch { return null; }
}

interface AllocationRowProps {
  agg: AggregatedMaterial;
  allocated: number;
  gap: number;
  onHand: number;
  statusLabel: string;
  statusColor: string;
  rowBg: string;
  isExpanded: boolean;
  onToggle: () => void;
  onRelease: () => void;
  isReleasing: boolean;
  moId: string;
  orgId: string | null;
  warehouseId: string | null;
  availability: InventoryAvailabilityRow | null;
  onTransferred: () => void;
}

function AllocationRow({
  agg, allocated, gap, onHand, statusLabel, statusColor, rowBg,
  isExpanded, onToggle, onRelease, isReleasing,
  moId, orgId, warehouseId, availability, onTransferred,
}: AllocationRowProps) {
  const fmt = (qty: number) => agg.uom === 'm' ? qty.toFixed(2) : qty.toFixed(0);

  return (
    <>
      <tr
        className={`hover:bg-gray-50 cursor-pointer transition-colors ${rowBg}`}
        onClick={onToggle}
      >
        <td className="px-2 py-2 text-center">
          {isExpanded
            ? <ChevronDown className="w-4 h-4 text-gray-500" />
            : <ChevronRight className="w-4 h-4 text-gray-400" />
          }
        </td>
        <td className="px-3 py-2 font-mono text-gray-900 text-xs">{agg.sku}</td>
        <td className="px-3 py-2 text-gray-700 text-xs truncate max-w-[200px]" title={agg.item_name}>{agg.item_name}</td>
        <td className="px-3 py-2 text-right tabular-nums text-xs">{fmt(agg.totalQty)}</td>
        <td className="px-3 py-2 text-right tabular-nums text-xs">{fmt(onHand)}</td>
        <td className="px-3 py-2 text-right tabular-nums text-xs font-medium text-green-700">
          {allocated > 0 ? fmt(allocated) : '—'}
        </td>
        <td className={`px-3 py-2 text-right tabular-nums text-xs font-medium ${gap > 0 ? 'text-red-600' : 'text-green-600'}`}>
          {gap > 0 ? `-${fmt(gap)}` : 'OK'}
        </td>
        <td className="px-3 py-2 text-center">
          <span className={`inline-block text-[10px] px-2 py-0.5 rounded-full font-medium ${statusColor}`}>{statusLabel}</span>
        </td>
        <td className="px-3 py-2 text-center" onClick={e => e.stopPropagation()}>
          {allocated > 0 && (
            <button
              type="button"
              onClick={onRelease}
              disabled={isReleasing}
              className="text-[10px] text-red-600 hover:text-red-800 disabled:opacity-50"
              title="Release allocation for this item"
            >
              Unassign
            </button>
          )}
        </td>
      </tr>
      {isExpanded && (
        <tr>
          <td colSpan={9} className="p-0">
            <AllocationDetailPanel
              catalogItemId={agg.catalog_item_id}
              sku={agg.sku}
              itemName={agg.item_name}
              uom={agg.uom}
              requiredQty={agg.totalQty}
              allocatedQty={allocated}
              gap={gap}
              availability={availability}
              moId={moId}
              orgId={orgId}
              warehouseId={warehouseId}
              onTransferred={onTransferred}
            />
          </td>
        </tr>
      )}
    </>
  );
}

/* ================================================================
   AllocationDetailPanel — inline expandable detail for a SKU
   ================================================================ */

interface AllocationDetailPanelProps {
  catalogItemId: string;
  sku: string;
  itemName: string;
  uom: string;
  requiredQty: number;
  allocatedQty: number;
  gap: number;
  availability: InventoryAvailabilityRow | null;
  moId: string;
  orgId: string | null;
  warehouseId: string | null;
  onTransferred: () => void;
}

function AllocationDetailPanel({
  catalogItemId, sku, itemName, uom, requiredQty, allocatedQty, gap,
  availability, moId, orgId, warehouseId, onTransferred,
}: AllocationDetailPanelProps) {
  const { moAllocations, loading } = useAllMOAllocationsForItem(catalogItemId, moId, orgId);
  const { transfer, isTransferring } = useTransferAllocation();
  const [transferAmounts, setTransferAmounts] = useState<Record<string, number>>({});
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  const fmt = (qty: number) => uom === 'm' ? qty.toFixed(2) : qty.toFixed(0);

  const onHand = availability?.on_hand_qty ?? 0;
  const onOrder = availability?.on_order_qty ?? 0;
  const nextEta = availability?.next_eta ?? null;
  const totalReservedAllMOs = moAllocations.reduce((s, a) => s + a.allocated_qty, 0);
  const freeStock = Math.max(0, onHand - totalReservedAllMOs);
  const otherMOs = moAllocations.filter(a => !a.is_current);

  const isInProduction = (status: string) => ['in_production', 'quality_check', 'ready_for_pickup'].includes(status);

  const handleTransfer = useCallback(async (sourceMoId: string, sourceWarehouseId: string) => {
    const qty = transferAmounts[sourceMoId];
    if (!qty || qty <= 0 || !orgId) return;
    setError(null);
    setSuccessMsg(null);
    try {
      const result = await transfer(sourceMoId, moId, catalogItemId, qty, orgId, sourceWarehouseId);
      setSuccessMsg(`Transferred ${fmt(result.transferred_qty ?? qty)} ${uom}`);
      setTransferAmounts(prev => ({ ...prev, [sourceMoId]: 0 }));
      onTransferred();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Transfer failed');
    }
  }, [transferAmounts, transfer, moId, catalogItemId, orgId, onTransferred, uom]);

  return (
    <div className="bg-slate-50 border-t border-b border-slate-200 px-6 py-4 space-y-4">
      {/* Section A — Inventory Summary */}
      <div>
        <h5 className="text-xs font-semibold text-gray-700 mb-2 uppercase tracking-wide">Inventory Summary</h5>
        <div className="grid grid-cols-4 gap-3">
          <div className="bg-white rounded-lg border border-gray-200 px-3 py-2">
            <div className="text-[10px] text-gray-500 uppercase">On Hand</div>
            <div className="text-sm font-semibold text-gray-900 tabular-nums">{fmt(onHand)} {uom}</div>
          </div>
          <div className="bg-white rounded-lg border border-gray-200 px-3 py-2">
            <div className="text-[10px] text-gray-500 uppercase">Total Reserved</div>
            <div className="text-sm font-semibold text-amber-700 tabular-nums">{fmt(totalReservedAllMOs)} {uom}</div>
          </div>
          <div className="bg-white rounded-lg border border-gray-200 px-3 py-2">
            <div className="text-[10px] text-gray-500 uppercase">Free Stock</div>
            <div className={`text-sm font-semibold tabular-nums ${freeStock > 0 ? 'text-green-700' : 'text-gray-400'}`}>{fmt(freeStock)} {uom}</div>
          </div>
          <div className="bg-white rounded-lg border border-gray-200 px-3 py-2">
            <div className="text-[10px] text-gray-500 uppercase">On Order (PO)</div>
            <div className="text-sm font-semibold text-blue-700 tabular-nums">
              {onOrder > 0 ? `${fmt(onOrder)} ${uom}` : '—'}
            </div>
            {nextEta && onOrder > 0 && (
              <div className="text-[10px] text-blue-500 flex items-center gap-1 mt-0.5">
                <Calendar className="w-2.5 h-2.5" /> ETA {formatShortDate(nextEta)}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Section B — Reservations by MO */}
      <div>
        <h5 className="text-xs font-semibold text-gray-700 mb-2 uppercase tracking-wide">Reserved by Manufacturing Orders</h5>

        {error && (
          <div className="mb-2 flex items-center gap-2 px-3 py-1.5 rounded-lg bg-red-50 text-red-700 text-xs">
            <AlertTriangle className="w-3.5 h-3.5 shrink-0" /> {error}
          </div>
        )}
        {successMsg && (
          <div className="mb-2 flex items-center gap-2 px-3 py-1.5 rounded-lg bg-green-50 text-green-700 text-xs">
            <Package className="w-3.5 h-3.5 shrink-0" /> {successMsg}
          </div>
        )}

        {loading ? (
          <div className="flex items-center justify-center py-6">
            <Loader2 className="w-4 h-4 animate-spin text-gray-400" />
          </div>
        ) : moAllocations.length === 0 ? (
          <div className="text-xs text-gray-400 py-3">No MOs have this item reserved.</div>
        ) : (
          <div className="space-y-2">
            {moAllocations.map(alloc => {
              const prio = PRIORITY_CONFIG[alloc.priority] ?? PRIORITY_CONFIG.normal;
              const inProd = isInProduction(alloc.mo_status);
              const dueStr = formatShortDate(alloc.due_date);
              const amt = transferAmounts[alloc.manufacturing_order_id] ?? 0;
              const maxQty = Math.min(alloc.allocated_qty, gap > 0 ? gap : 0);

              return (
                <div
                  key={alloc.manufacturing_order_id}
                  className={`rounded-lg border px-3 py-2.5 ${
                    alloc.is_current
                      ? 'border-blue-200 bg-blue-50/50'
                      : inProd || prio.warn
                        ? 'border-amber-200 bg-amber-50/30'
                        : 'border-gray-200 bg-white'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2 min-w-0">
                      <span className="text-xs font-semibold text-gray-900 shrink-0">{alloc.mo_number}</span>
                      <StatusBadge status={alloc.mo_status} type="manufacturing" size="sm" />
                      <span className={`text-[10px] px-1.5 py-0.5 rounded font-medium shrink-0 ${prio.color}`}>{prio.label}</span>
                      {alloc.is_current && (
                        <span className="text-[10px] px-1.5 py-0.5 rounded bg-blue-100 text-blue-700 font-medium shrink-0">← This order</span>
                      )}
                    </div>
                    <span className="text-xs font-medium text-gray-900 tabular-nums shrink-0 ml-2">
                      {fmt(alloc.allocated_qty)} {uom}
                    </span>
                  </div>

                  <div className="flex items-center gap-2 text-[10px] text-gray-500 mt-1">
                    <span className="truncate">{alloc.product_name}</span>
                    <span className="text-gray-300">|</span>
                    <span className="truncate">{alloc.customer_name}</span>
                    {dueStr && (
                      <>
                        <span className="text-gray-300">|</span>
                        <span className="flex items-center gap-0.5 shrink-0">
                          <Calendar className="w-2.5 h-2.5" /> {dueStr}
                        </span>
                      </>
                    )}
                  </div>

                  {/* Warnings */}
                  {!alloc.is_current && inProd && (
                    <div className="flex items-center gap-1 text-[10px] text-amber-700 bg-amber-100 rounded px-2 py-0.5 mt-1.5">
                      <ShieldAlert className="w-3 h-3 shrink-0" />
                      In production — transferring may cause delays
                    </div>
                  )}
                  {!alloc.is_current && prio.warn && !inProd && (
                    <div className="flex items-center gap-1 text-[10px] text-amber-700 bg-amber-100 rounded px-2 py-0.5 mt-1.5">
                      <ShieldAlert className="w-3 h-3 shrink-0" />
                      {alloc.priority === 'urgent' ? 'Urgent' : 'High'} priority — transfer with caution
                    </div>
                  )}

                  {/* Transfer controls (only for other MOs when there's a gap) */}
                  {!alloc.is_current && gap > 0 && warehouseId && (
                    <div className="flex items-center justify-end gap-2 mt-2 pt-2 border-t border-gray-100">
                      <span className="text-[10px] text-gray-500 mr-auto">Take from this MO:</span>
                      <input
                        type="number"
                        min={0}
                        max={maxQty}
                        step={uom === 'm' ? 0.01 : 1}
                        value={amt || ''}
                        onChange={e => {
                          const val = Math.min(Number(e.target.value) || 0, maxQty);
                          setTransferAmounts(prev => ({ ...prev, [alloc.manufacturing_order_id]: val }));
                        }}
                        placeholder={fmt(maxQty)}
                        className="w-20 px-2 py-1 text-xs border border-gray-300 rounded-lg text-right focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
                      />
                      <button
                        type="button"
                        onClick={() => handleTransfer(alloc.manufacturing_order_id, alloc.warehouse_id)}
                        disabled={isTransferring || !amt || amt <= 0}
                        className="inline-flex items-center gap-1 px-2.5 py-1 text-[10px] font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                      >
                        {isTransferring ? <Loader2 className="w-3 h-3 animate-spin" /> : <ArrowRightLeft className="w-3 h-3" />}
                        Transfer
                      </button>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Section C — Action suggestion */}
      {gap > 0 && freeStock <= 0 && otherMOs.length === 0 && (
        <div className="flex items-center gap-2 px-3 py-2 rounded-lg bg-amber-50 border border-amber-200 text-xs text-amber-800">
          <ShoppingCart className="w-4 h-4 shrink-0" />
          <span>
            <strong>{sku}</strong> needs {fmt(gap)} {uom} more. No warehouse stock or other MO reservations available — this material needs to be purchased.
          </span>
        </div>
      )}
    </div>
  );
}
