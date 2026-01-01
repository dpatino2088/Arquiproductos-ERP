import { useState, useEffect } from 'react';
import { useManufacturingMaterials } from '../../../hooks/useManufacturing';
import { formatCurrency } from '../../../lib/utils';
import { supabase } from '../../../lib/supabase/client';
import { useUIStore } from '../../../stores/ui-store';
import { RefreshCw } from 'lucide-react';
import type { ManufacturingOrderStatus } from '../../../hooks/useManufacturing';

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
  const { materials, loading, error, refetch } = useManufacturingMaterials(saleOrderId);
  const [showCosts, setShowCosts] = useState(false);
  const [shouldShowError, setShouldShowError] = useState(false);
  const [generatingBOM, setGeneratingBOM] = useState(false);

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

    try {
      setGeneratingBOM(true);
      
      // Call RPC to generate BOM
      const { data, error: rpcError } = await supabase.rpc('generate_bom_for_manufacturing_order', {
        p_manufacturing_order_id: moId
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

      // Small delay to allow DB to commit
      await new Promise(resolve => setTimeout(resolve, 500));
      
      // Refetch materials to update the display
      await refetch();
      
      // Show success message
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: 'BOM generated successfully. Materials are now available.',
      });
      
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

  // Group materials by part_role (or category_code as fallback)
  const groupedMaterials = materials.reduce((acc, material) => {
    const category = material.part_role || material.category_code || 'accessory';
    if (!acc[category]) {
      acc[category] = [];
    }
    acc[category].push(material);
    return acc;
  }, {} as Record<string, typeof materials>);

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
      <div className="mb-4 flex items-center justify-between">
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

      {/* Materials by Category */}
      <div className="space-y-6">
        {sortedCategories.map((category) => {
          const categoryMaterials = groupedMaterials[category];
          const categoryTotal = categoryMaterials.reduce((sum, m) => sum + m.total_cost_exw, 0);

          return (
            <div key={category} className="bg-white border border-gray-200 rounded-lg overflow-hidden">
              {/* Category Header */}
              <div className="bg-gray-50 px-6 py-3 border-b border-gray-200">
                <div className="flex items-center justify-between">
                  <h4 className="text-sm font-semibold text-gray-900">
                    {CATEGORY_LABELS[category] || category}
                  </h4>
                  {showCosts && (
                    <span className="text-sm font-medium text-gray-700">
                      {formatCurrency(categoryTotal, currency)}
                    </span>
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
                          <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Unit Cost</th>
                          <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Total Cost</th>
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
                            <td className="py-3 px-6 text-sm text-gray-700 text-right">
                              {material.unit_cost_exw
                                ? formatCurrency(material.unit_cost_exw, currency)
                                : 'N/A'}
                            </td>
                            <td className="py-3 px-6 text-sm text-gray-900 text-right font-medium">
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

      {/* Grand Total */}
      {showCosts && materials.length > 0 && (
        <div className="mt-6 bg-gray-50 border border-gray-200 rounded-lg p-4">
          <div className="flex justify-between items-center">
            <span className="text-sm font-semibold text-gray-900">Grand Total:</span>
            <span className="text-lg font-bold text-gray-900">
              {formatCurrency(
                materials.reduce((sum, m) => sum + m.total_cost_exw, 0),
                currency
              )}
            </span>
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
