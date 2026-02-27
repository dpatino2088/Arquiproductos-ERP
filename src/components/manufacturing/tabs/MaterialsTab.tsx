import { useState, useEffect, useMemo } from 'react';
import { useManufacturingMaterials } from '../../../hooks/useManufacturing';
import { formatCurrency } from '../../../lib/utils';
import type { ManufacturingOrderStatus } from '../../../hooks/useManufacturing';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { useWarehouses } from '../../../hooks/useWarehouses';
import { useInventoryAvailability } from '../../../hooks/useInventoryAvailability';
import { InventoryAvailabilityBadge } from '../../inventory/InventoryAvailabilityBadge';

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

export default function MaterialsTab({ moId, saleOrderId: _saleOrderId, moStatus, currency = 'USD', onBOMGenerated: _onBOMGenerated }: MaterialsTabProps) {
  const { materials, bomTotals, loading, error, hasBomInstances, hasBomLines, debugCounts } = useManufacturingMaterials(moId);
  const [showCosts, setShowCosts] = useState(false);
  const [shouldShowError, setShouldShowError] = useState(false);

  const { activeOrganizationId } = useOrganizationContext();
  const { defaultWarehouse } = useWarehouses(activeOrganizationId);
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
    <div className="p-6">
      {/* Status Banner */}
      {moStatus === 'draft' && (
        <div className="mb-4 bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div className="flex items-center gap-2">
            <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
              Material Review
            </span>
            <p className="text-sm text-blue-800">
              Materials are auto-generated from the Sales Order during MO creation.
            </p>
          </div>
        </div>
      )}

      {moStatus === 'planned' && (
        <div className="mb-4 bg-green-50 border border-green-200 rounded-lg p-4">
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
            Planned
          </span>
          <p className="text-sm text-green-800 mt-2">
            BOM is ready for production. All materials have been calculated and validated.
          </p>
        </div>
      )}

      {/* Controls */}
      <div className="mb-4 space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-semibold text-gray-900">Manufacturing BOM / Material List</h3>
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

      {/* Materials by Category */}
      <div className="space-y-6">
        {sortedCategories.map((category) => {
          const categoryMaterials = groupedMaterials[category];
          if (!categoryMaterials || categoryMaterials.length === 0) return null;
          
          const categoryTotal = categoryMaterials.reduce((sum, m) => sum + m.total_cost_exw, 0);
          const categoryTotalMSRP = categoryMaterials.reduce((sum, m) => sum + (m.total_msrp || 0), 0);

          return (
            <div key={category} className="bg-white border border-gray-200 rounded-lg overflow-hidden">
              {/* Category Header */}
              <div className="bg-gray-50 px-6 py-3 border-b border-gray-200">
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

              {/* Materials Table */}
              <div className="table-fit-wrapper">
                <table className="table-fit">
                  <thead className="bg-gray-50 border-b border-gray-200">
                    <tr>
                      <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">SKU</th>
                      <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Description</th>
                      <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Role</th>
                      <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Qty</th>
                      <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">UoM</th>
                      <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Cut L (mm)</th>
                      <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Cut W (mm)</th>
                      <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Cut H (mm)</th>
                      <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Notes</th>
                      <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Availability</th>
                      {showCosts && (
                        <>
                          <th className="text-right py-3 px-6 font-medium text-blue-900 text-xs">Unit MSRP (PVP)</th>
                          <th className="text-right py-3 px-6 font-medium text-blue-900 text-xs">Total MSRP (PVP)</th>
                          <th className="text-right py-3 px-6 font-medium text-gray-500 text-xs">Unit Cost</th>
                          <th className="text-right py-3 px-6 font-medium text-gray-500 text-xs">Total Cost</th>
                        </>
                      )}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-200">
                    {categoryMaterials.map((material) => (
                      <tr key={material.bom_instance_line_id} className="hover:bg-gray-50">
                        <td className="py-3 px-6 text-sm text-gray-900 font-mono">
                          {material.sku || 'N/A'}
                        </td>
                        <td className="py-3 px-6 text-sm text-gray-700">
                          {material.item_name || 'N/A'}
                        </td>
                        <td className="py-3 px-6 text-sm text-gray-700">
                          {material.part_role || 'N/A'}
                        </td>
                        <td className="py-3 px-6 text-sm text-gray-900 text-right font-medium">
                          {material.uom === 'm'
                            ? material.qty.toFixed(2)
                            : material.qty.toFixed(0)}
                        </td>
                        <td className="py-3 px-6 text-sm text-gray-700 text-right">
                          {material.uom}
                        </td>
                        <td className="py-3 px-6 text-sm text-gray-700 text-right">
                          {material.cut_length_mm !== null && material.cut_length_mm !== undefined
                            ? material.cut_length_mm.toLocaleString()
                            : '—'}
                        </td>
                        <td className="py-3 px-6 text-sm text-gray-700 text-right">
                          {material.cut_width_mm !== null && material.cut_width_mm !== undefined
                            ? material.cut_width_mm.toLocaleString()
                            : '—'}
                        </td>
                        <td className="py-3 px-6 text-sm text-gray-700 text-right">
                          {material.cut_height_mm !== null && material.cut_height_mm !== undefined
                            ? material.cut_height_mm.toLocaleString()
                            : '—'}
                        </td>
                        <td className="py-3 px-6 text-sm text-gray-600 max-w-xs truncate" title={material.calc_notes || undefined}>
                          {material.calc_notes || '—'}
                        </td>
                        <td className="py-3 px-6 text-sm">
                          <InventoryAvailabilityBadge row={availabilityMap[material.catalog_item_id]} />
                        </td>
                        {showCosts && (
                          <>
                            <td className="py-3 px-6 text-sm text-blue-700 text-right font-medium">
                              {material.unit_msrp
                                ? formatCurrency(material.unit_msrp, currency)
                                : 'N/A'}
                            </td>
                            <td className="py-3 px-6 text-sm text-blue-900 text-right font-bold">
                              {material.total_msrp
                                ? formatCurrency(material.total_msrp, currency)
                                : 'N/A'}
                            </td>
                            <td className="py-3 px-6 text-sm text-gray-500 text-right text-xs">
                              {material.unit_cost_exw
                                ? formatCurrency(material.unit_cost_exw, currency)
                                : 'N/A'}
                            </td>
                            <td className="py-3 px-6 text-sm text-gray-500 text-right text-xs">
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

      {/* Grand Total / Summary */}
      {/* ✅ FIX: Show summary even if showCosts is false, but always show if materials exist */}
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
