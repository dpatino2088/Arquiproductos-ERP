import { useState, useEffect } from 'react';
import { useManufacturingMaterials } from '../../../hooks/useManufacturing';
import { formatCurrency } from '../../../lib/utils';
import { supabase } from '../../../lib/supabase/client';
import { useUIStore } from '../../../stores/ui-store';
import { RefreshCw, ChevronDown, ChevronUp, BarChart3 } from 'lucide-react';
import type { ManufacturingOrderStatus } from '../../../hooks/useManufacturing';
import BOMMonitoringDashboard from './BOMMonitoringDashboard';
import { useBOMMonitoring } from '../../../hooks/useBOMMonitoring';
import { normalizeUUID } from '../../../utils/uuid';

interface MaterialsTabProps {
  moId: string;
  saleOrderId: string | null;
  moStatus: ManufacturingOrderStatus;
  currency?: string;
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

export default function MaterialsTab({ moId, saleOrderId, moStatus, currency = 'USD' }: MaterialsTabProps) {
  const { materials, bomTotals, loading, error, refetch, hasBomInstances, hasBomLines, debugCounts } = useManufacturingMaterials(moId);
  const { refetch: refetchMonitoring } = useBOMMonitoring(saleOrderId);
  const [showCosts, setShowCosts] = useState(false);
  const [shouldShowError, setShouldShowError] = useState(false);
  const [generatingBOM, setGeneratingBOM] = useState(false);
  const [showMonitoring, setShowMonitoring] = useState(false);

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

  // Handle Generate BOM
  const handleGenerateBOM = async () => {
    if (!moId || generatingBOM) return;

    // Normalize UUID before RPC calls
    const safeMoId = normalizeUUID(moId);
    if (!safeMoId) {
      if (import.meta.env.DEV) {
        console.warn('⚠️ RPC aborted: invalid UUID', moId);
      }
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Invalid manufacturing order ID',
      });
      return;
    }

    try {
      setGeneratingBOM(true);
      
      // Step 1: Reset (soft-delete) existing BOMs
      const { data: resetData, error: resetError } = await supabase.rpc('reset_bom_for_manufacturing_order', {
        p_manufacturing_order_id: safeMoId
      });
      
      if (resetError) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: resetError.message || 'Failed to reset BOM',
        });
        return;
      }
      
      // Step 2: Generate new BOM
      const { data, error: rpcError } = await supabase.rpc('generate_bom_for_manufacturing_order', {
        p_manufacturing_order_id: safeMoId
      });

      if (rpcError) {
        // Only show error if RPC actually failed
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: rpcError.message || 'Failed to generate BOM',
        });
        return;
      }

      // Parse response (new format with counts and warnings)
      const ok = data?.ok ?? false;
      const errors = data?.errors ?? [];
      const warnings = data?.warnings ?? [];
      const results = data?.results ?? [];
      
      // Use new counts from response
      const moLinesProcessed = data?.mo_lines_processed ?? 0;
      const bomInstancesCreated = data?.bom_instances_created ?? results.length;
      const bomLinesCreated = data?.bom_instance_lines_created ?? results.reduce((sum: number, r: any) => sum + (r.created_lines || 0), 0);
      
      // Log detailed response
      if (import.meta.env.DEV) {
        console.log('📊 BOM Generation Result:', {
          ok,
          moLinesProcessed,
          bomInstancesCreated,
          bomLinesCreated,
          warnings: warnings.length,
          errors: errors.length,
        });
      }
      
      if (!ok || errors.length > 0) {
        const errorMsg = errors.length > 0 
          ? `Errors: ${errors.slice(0, 3).join(', ')}`
          : 'Unknown error occurred';
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'BOM Generation Failed',
          message: `${errorMsg}. BomInstances: ${bomInstancesCreated}, Lines: ${bomLinesCreated}`,
        });
      } else if (warnings.length > 0) {
        useUIStore.getState().addNotification({
          type: 'warning',
          title: 'BOM Generated with Warnings',
          message: `BOM generated: ${bomInstancesCreated} instance(s), ${bomLinesCreated} line(s). Warnings: ${warnings.slice(0, 2).join('; ')}`,
        });
      } else if (bomLinesCreated === 0) {
        useUIStore.getState().addNotification({
          type: 'warning',
          title: 'BOM Generated',
          message: `BOM generated but 0 lines created. BomInstances: ${bomInstancesCreated}. Check component mappings and BOM template configuration.`,
        });
      } else {
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Success',
          message: `BOM generated successfully: ${bomInstancesCreated} instance(s), ${bomLinesCreated} line(s) created.`,
        });
      }
      
      // Show detailed warnings in console for debugging
      if (warnings.length > 0 && import.meta.env.DEV) {
        console.warn('⚠️ BOM Generation Warnings:', warnings);
      }
      
      // Small delay to allow DB to commit
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Refetch materials to update the display (with retry)
      let retries = 0;
      const maxRetries = 3;
      while (retries < maxRetries) {
        await refetch();
        
        // Check if materials are now available
        if (materials.length > 0) {
          break;
        }
        
        retries++;
        if (retries < maxRetries) {
          await new Promise(resolve => setTimeout(resolve, 500 * retries));
        }
      }
      
      // ✅ FIX: Refetch monitoring dashboard to show new BOM instance
      // Always refresh monitor after BOM generation (regardless of linesCreated)
      // Small delay to ensure new BOM instance is committed
      await new Promise(resolve => setTimeout(resolve, 500));
      await refetchMonitoring();
      
      if (materials.length === 0 && bomLinesCreated > 0 && !loading) {
        useUIStore.getState().addNotification({
          type: 'warning',
          title: 'Materials Not Visible',
          message: 'BOM lines were created but not visible. This may be a permissions issue. Please refresh the page.',
        });
      }
      
      // Note: MO status will be updated by backend to 'planned' if BOM lines > 0
      // The parent component (ManufacturingOrderDetail) will automatically refetch
      // the MO when the tab is re-rendered or when user navigates
      
    } catch (err) {
      // Only show error if it's a real error
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err instanceof Error ? err.message : 'Failed to generate BOM',
      });
    } finally {
      setGeneratingBOM(false);
    }
  };

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
      console.log('[DEBUG] Materials displayed', {
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
                No se crearon BomInstances para este Manufacturing Order
              </h3>
              <p className="text-sm text-yellow-700 mb-3">
                No hay BomInstances asociados a este MO. Ejecuta "Generate BOM" o revisa que el MO tenga ManufacturingOrderLines y BOM Templates configurados.
              </p>
              <div className="text-xs text-yellow-600 space-y-1">
                <p>• Debug: BomInstances = {debugCounts.bomInstances}, BomInstanceLines = {debugCounts.bomLines}</p>
                <p>• Verifica que el MO tenga SalesOrderLines asociados</p>
                <p>• Verifica que exista un BOM Template activo para el product_type de cada línea</p>
              </div>
            </div>
          </div>
        </div>
        <button
          onClick={handleGenerateBOM}
          disabled={generatingBOM}
          className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {generatingBOM ? 'Generating...' : 'Generate BOM'}
        </button>
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
                BomInstances creados pero 0 líneas generadas
              </h3>
              <p className="text-sm text-orange-700 mb-3">
                Se crearon {debugCounts.bomInstances} BomInstance(s) pero no se generaron BomInstanceLines. Revisa BomTemplateComponents y reglas de auto-select.
              </p>
              <div className="text-xs text-orange-600 space-y-1">
                <p>• Debug: BomInstances = {debugCounts.bomInstances}, BomInstanceLines = {debugCounts.bomLines}</p>
                <p>• Verifica que el BOM Template tenga componentes (BomTemplateComponents) con component_item_id no NULL</p>
                <p>• Verifica que los CatalogItems referenciados existan y estén activos</p>
                <p>• Revisa los logs de la RPC para ver warnings específicos</p>
              </div>
            </div>
          </div>
        </div>
        <button
          onClick={handleGenerateBOM}
          disabled={generatingBOM}
          className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {generatingBOM ? 'Regenerating...' : 'Regenerate BOM'}
        </button>
      </div>
    );
  }

  if (materials.length === 0) {
    return (
      <div className="p-6">
        {/* Status Banner */}
        {moStatus === 'draft' && (
          <div className="mb-4 bg-blue-50 border border-blue-200 rounded-lg p-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                  Material Review
                </span>
                <p className="text-sm text-blue-800">
                  BOM needs to be generated before production can begin.
                </p>
              </div>
              <button
                onClick={handleGenerateBOM}
                disabled={generatingBOM}
                className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <RefreshCw className={`w-4 h-4 ${generatingBOM ? 'animate-spin' : ''}`} />
                {generatingBOM ? 'Generating...' : 'Generate BOM'}
              </button>
            </div>
          </div>
        )}
        
        <div className="text-center text-gray-500 py-12">
          <p className="mb-2">No frozen BOM materials found for this Sale Order yet.</p>
          {moStatus !== 'draft' && (
            <p className="text-xs mt-2 text-gray-400">Click "Generate BOM" button above to create materials list.</p>
          )}
        </div>
        
        {/* Loading state for BOM generation */}
        {generatingBOM && (
          <div className="mt-4 bg-blue-50 border border-blue-200 rounded-lg p-4">
            <div className="flex items-center gap-2">
              <RefreshCw className="w-4 h-4 animate-spin text-blue-600" />
              <p className="text-sm text-blue-800">Generating BOM... Please wait.</p>
            </div>
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Status Banner */}
      {moStatus === 'draft' && (
        <div className="mb-4 bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                Material Review
              </span>
              <p className="text-sm text-blue-800">
                BOM needs to be generated before production can begin.
              </p>
            </div>
            <button
              onClick={handleGenerateBOM}
              disabled={generatingBOM}
              className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <RefreshCw className={`w-4 h-4 ${generatingBOM ? 'animate-spin' : ''}`} />
              {generatingBOM ? 'Generating...' : 'Generate BOM'}
            </button>
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
        
        {/* Monitoring Dashboard Toggle */}
        <button
          onClick={() => setShowMonitoring(!showMonitoring)}
          className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors w-full justify-between"
        >
          <div className="flex items-center gap-2">
            <BarChart3 className="w-4 h-4" />
            <span>BOM Health Monitoring Dashboard</span>
          </div>
          {showMonitoring ? (
            <ChevronUp className="w-4 h-4" />
          ) : (
            <ChevronDown className="w-4 h-4" />
          )}
        </button>
      </div>

      {/* Monitoring Dashboard */}
      {showMonitoring && (
        <div className="mb-6 border border-gray-200 rounded-lg overflow-hidden">
          <BOMMonitoringDashboard saleOrderId={saleOrderId} currency={currency} />
        </div>
      )}

      {/* Materials by Category */}
      <div className="space-y-6">
        {sortedCategories.map((category) => {
          const categoryMaterials = groupedMaterials[category];
          if (!categoryMaterials || categoryMaterials.length === 0) return null;
          
          const categoryTotal = categoryMaterials.reduce((sum, m) => sum + m.total_cost_exw, 0);
          const categoryTotalMSRP = categoryMaterials.reduce((sum, m) => sum + (m.total_msrp_sale_out || 0), 0);

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
              <div className="overflow-x-auto">
                <table className="w-full">
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
                        {showCosts && (
                          <>
                            <td className="py-3 px-6 text-sm text-blue-700 text-right font-medium">
                              {material.unit_msrp_sale_out
                                ? formatCurrency(material.unit_msrp_sale_out, currency)
                                : 'N/A'}
                            </td>
                            <td className="py-3 px-6 text-sm text-blue-900 text-right font-bold">
                              {material.total_msrp_sale_out
                                ? formatCurrency(material.total_msrp_sale_out, currency)
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
                      bomTotals.totalMSRPWithLabor || materials.reduce((sum, m) => sum + (m.total_msrp_sale_out || 0), 0),
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

      {/* Loading state for BOM generation */}
      {generatingBOM && (
        <div className="mt-4 bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div className="flex items-center gap-2">
            <RefreshCw className="w-4 h-4 animate-spin text-blue-600" />
            <p className="text-sm text-blue-800">Generating BOM... Please wait.</p>
          </div>
        </div>
      )}
    </div>
  );
}
