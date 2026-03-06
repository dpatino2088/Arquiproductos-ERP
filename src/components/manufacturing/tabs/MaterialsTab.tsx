import { useState, useEffect, useMemo, useCallback } from 'react';
import { useManufacturingMaterials } from '../../../hooks/useManufacturing';
import { formatCurrency } from '../../../lib/utils';
import type { ManufacturingOrderStatus } from '../../../hooks/useManufacturing';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { useWarehouses } from '../../../hooks/useWarehouses';
import { useInventoryAvailability } from '../../../hooks/useInventoryAvailability';
import { InventoryAvailabilityBadge } from '../../inventory/InventoryAvailabilityBadge';
import { useMOAllocations, useAllocateToMO, useReleaseMOAllocation } from '../../../hooks/useInventoryAllocations';
import { useUIStore } from '../../../stores/ui-store';
import { Package, XCircle, Loader2 } from 'lucide-react';

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

  const handleAllocateAll = useCallback(async () => {
    if (!activeOrganizationId || !defaultWarehouse) return;
    const items = aggregatedBySku
      .filter(m => {
        const alreadyAllocated = allocationMap.get(m.catalog_item_id) ?? 0;
        return m.totalQty - alreadyAllocated > 0;
      })
      .map(m => ({
        catalog_item_id: m.catalog_item_id,
        qty: m.totalQty - (allocationMap.get(m.catalog_item_id) ?? 0),
      }));
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
          <div className="table-fit-wrapper">
            <table className="table-fit">
              <thead className="bg-gray-50 border-b border-gray-200">
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

      {/* Inventory Allocation */}
      {materials.length > 0 && ['draft', 'planned', 'in_production'].includes(moStatus) && (
        <div className="mt-6 bg-white border border-gray-200 rounded-lg overflow-hidden">
          <div className="bg-gray-50 px-4 py-3 border-b flex items-center justify-between">
            <h4 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
              <Package className="w-4 h-4" />
              Inventory Allocation
              {allocations.length > 0 && (
                <span className="text-xs font-normal text-gray-500">({allocations.length} item{allocations.length > 1 ? 's' : ''} allocated)</span>
              )}
            </h4>
            <div className="flex items-center gap-2">
              {allocations.length > 0 && (
                <button
                  type="button"
                  onClick={handleReleaseAll}
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
          {allocLoading ? (
            <div className="px-4 py-6 text-center text-gray-400 text-sm">Loading allocations...</div>
          ) : allocations.length === 0 ? (
            <div className="px-4 py-6 text-center text-gray-400 text-sm">No inventory allocated to this MO yet. Click "Allocate Available" to reserve warehouse stock.</div>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b">
                <tr>
                  <th className="px-4 py-2 text-left font-medium text-gray-700 text-xs">SKU</th>
                  <th className="px-4 py-2 text-left font-medium text-gray-700 text-xs">Item</th>
                  <th className="px-4 py-2 text-right font-medium text-gray-700 text-xs">Required</th>
                  <th className="px-4 py-2 text-right font-medium text-gray-700 text-xs">Allocated</th>
                  <th className="px-4 py-2 text-right font-medium text-gray-700 text-xs">Gap</th>
                  <th className="px-4 py-2 text-center font-medium text-gray-700 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {aggregatedBySku.map(agg => {
                  const allocated = allocationMap.get(agg.catalog_item_id) ?? 0;
                  const gap = agg.totalQty - allocated;
                  return (
                    <tr key={agg.catalog_item_id} className="hover:bg-gray-50">
                      <td className="px-4 py-2 font-mono text-gray-900">{agg.sku}</td>
                      <td className="px-4 py-2 text-gray-700">{agg.item_name}</td>
                      <td className="px-4 py-2 text-right tabular-nums">{agg.uom === 'm' ? agg.totalQty.toFixed(2) : agg.totalQty.toFixed(0)}</td>
                      <td className="px-4 py-2 text-right tabular-nums font-medium text-green-700">
                        {allocated > 0 ? (agg.uom === 'm' ? allocated.toFixed(2) : allocated.toFixed(0)) : '—'}
                      </td>
                      <td className={`px-4 py-2 text-right tabular-nums font-medium ${gap > 0 ? 'text-red-600' : 'text-green-600'}`}>
                        {gap > 0 ? `-${agg.uom === 'm' ? gap.toFixed(2) : gap.toFixed(0)}` : 'OK'}
                      </td>
                      <td className="px-4 py-2 text-center">
                        {allocated > 0 && (
                          <button
                            type="button"
                            onClick={() => handleReleaseItem(agg.catalog_item_id)}
                            disabled={isReleasing}
                            className="text-xs text-red-600 hover:text-red-800 disabled:opacity-50"
                            title="Release allocation"
                          >
                            Unassign
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
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

    </div>
  );
}
