import { useState } from 'react';
import { useCutList } from '../../../hooks/useManufacturing';
import { supabase } from '../../../lib/supabase/client';
import { useUIStore } from '../../../stores/ui-store';
import { RefreshCw } from 'lucide-react';
import type { ManufacturingOrderStatus } from '../../../hooks/useManufacturing';

interface CutListTabProps {
  moId: string;
  moStatus: ManufacturingOrderStatus;
}

export default function CutListTab({ moId, moStatus }: CutListTabProps) {
  const { cutJob, cutJobLines, loading, error, refetch } = useCutList(moId);
  const [generatingCutList, setGeneratingCutList] = useState(false);

  // Handle Generate Cut List
  const handleGenerateCutList = async () => {
    if (!moId || generatingCutList) return;

    try {
      setGeneratingCutList(true);
      
      // Call RPC to generate cut list
      const { data, error: rpcError } = await supabase.rpc('generate_cut_list_for_manufacturing_order', {
        p_manufacturing_order_id: moId
      });

      if (rpcError) {
        // Only show error if RPC actually failed
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: rpcError.message || 'Failed to generate cut list',
        });
        return;
      }

      // Small delay to allow DB to commit
      await new Promise(resolve => setTimeout(resolve, 500));
      
      // Refetch cut list to update the display
      await refetch();
      
      // Show success message
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: 'Cut list generated successfully.',
      });
      
    } catch (err) {
      // Only show error if it's a real error
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err instanceof Error ? err.message : 'Failed to generate cut list',
      });
    } finally {
      setGeneratingCutList(false);
    }
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-gray-200 rounded w-1/4"></div>
          <div className="h-32 bg-gray-200 rounded"></div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error loading cut list</p>
          <p className="text-sm text-red-700">{error}</p>
        </div>
      </div>
    );
  }

  // Group cut lines by part_role
  const groupedLines = cutJobLines.reduce((acc, line) => {
    const role = line.part_role || 'other';
    if (!acc[role]) {
      acc[role] = [];
    }
    acc[role].push(line);
    return acc;
  }, {} as Record<string, typeof cutJobLines>);

  const sortedRoles = Object.keys(groupedLines).sort();

  return (
    <div className="p-6">
      {/* Header with Generate Button */}
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-lg font-semibold text-gray-900">Cut List</h3>
        {moStatus === 'planned' && (
          <button
            onClick={handleGenerateCutList}
            disabled={generatingCutList}
            className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <RefreshCw className={`w-4 h-4 ${generatingCutList ? 'animate-spin' : ''}`} />
            {generatingCutList ? 'Generating...' : 'Generate Cut List'}
          </button>
        )}
      </div>

      {/* Status Banner */}
      {moStatus !== 'planned' && (
        <div className="mb-4 bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800">
            Cut list can only be generated when Manufacturing Order status is <strong>Planned</strong>.
            Current status: <strong>{moStatus.toUpperCase()}</strong>
          </p>
        </div>
      )}

      {/* No Cut List Generated */}
      {!cutJob && moStatus === 'planned' && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-6 text-center">
          <p className="text-sm text-blue-800 mb-4">
            No cut list has been generated yet. Click "Generate Cut List" to create one.
          </p>
        </div>
      )}

      {/* Cut List Table */}
      {cutJob && cutJobLines.length > 0 && (
        <div className="space-y-6">
          {sortedRoles.map((role) => {
            const roleLines = groupedLines[role];
            
            return (
              <div key={role} className="bg-white border border-gray-200 rounded-lg overflow-hidden">
                {/* Role Header */}
                <div className="bg-gray-50 px-6 py-3 border-b border-gray-200">
                  <h4 className="text-sm font-semibold text-gray-900">
                    {role.charAt(0).toUpperCase() + role.slice(1).replace('_', ' ')}
                  </h4>
                </div>

                {/* Cut Lines Table */}
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead className="bg-gray-50 border-b border-gray-200">
                      <tr>
                        <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">SKU</th>
                        <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Role</th>
                        <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Qty</th>
                        <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Cut Length (mm)</th>
                        <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Cut Width (mm)</th>
                        <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Cut Height (mm)</th>
                        <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">UoM</th>
                        <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Notes</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-200">
                      {roleLines.map((line) => (
                        <tr key={line.id} className="hover:bg-gray-50">
                          <td className="py-3 px-6 text-sm text-gray-900 font-mono">
                            {line.resolved_sku || 'N/A'}
                          </td>
                          <td className="py-3 px-6 text-sm text-gray-700">
                            {line.part_role || 'N/A'}
                          </td>
                          <td className="py-3 px-6 text-sm text-gray-900 text-right font-medium">
                            {line.uom === 'm'
                              ? line.qty.toFixed(2)
                              : line.qty.toFixed(0)}
                          </td>
                          <td className="py-3 px-6 text-sm text-gray-700 text-right">
                            {line.cut_length_mm !== null && line.cut_length_mm !== undefined
                              ? line.cut_length_mm.toLocaleString()
                              : '—'}
                          </td>
                          <td className="py-3 px-6 text-sm text-gray-700 text-right">
                            {line.cut_width_mm !== null && line.cut_width_mm !== undefined
                              ? line.cut_width_mm.toLocaleString()
                              : '—'}
                          </td>
                          <td className="py-3 px-6 text-sm text-gray-700 text-right">
                            {line.cut_height_mm !== null && line.cut_height_mm !== undefined
                              ? line.cut_height_mm.toLocaleString()
                              : '—'}
                          </td>
                          <td className="py-3 px-6 text-sm text-gray-700 text-right">
                            {line.uom}
                          </td>
                          <td className="py-3 px-6 text-sm text-gray-600 max-w-xs truncate" title={line.notes || undefined}>
                            {line.notes || '—'}
                          </td>
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

      {/* Empty State (if cut list exists but has no lines) */}
      {cutJob && cutJobLines.length === 0 && (
        <div className="bg-gray-50 border border-gray-200 rounded-lg p-6 text-center">
          <p className="text-sm text-gray-600">
            Cut list exists but has no lines. Regenerate the cut list to populate it.
          </p>
        </div>
      )}

      {/* Loading state for cut list generation */}
      {generatingCutList && (
        <div className="mt-4 bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div className="flex items-center gap-2">
            <RefreshCw className="w-4 h-4 animate-spin text-blue-600" />
            <p className="text-sm text-blue-800">Generating cut list... Please wait.</p>
          </div>
        </div>
      )}
    </div>
  );
}






