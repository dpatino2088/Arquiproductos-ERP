import { useState } from 'react';
import { useManufacturingOrder, useManufacturingMaterials } from '../../../hooks/useManufacturing';
import { formatCurrency } from '../../../lib/utils';
import { supabase } from '../../../lib/supabase/client';
import { useUIStore } from '../../../stores/ui-store';
import { RefreshCw } from 'lucide-react';

interface SummaryTabProps {
  moId: string;
}

export default function SummaryTab({ moId }: SummaryTabProps) {
  const { manufacturingOrder, loading, refetch } = useManufacturingOrder(moId);
  const { materials, loading: loadingMaterials, refetch: refetchMaterials } = useManufacturingMaterials(
    manufacturingOrder?.sale_order_id || null
  );
  const [generatingBOM, setGeneratingBOM] = useState(false);

  if (loading) {
    return (
      <div className="p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-4 bg-gray-200 rounded w-1/4"></div>
          <div className="h-4 bg-gray-200 rounded w-1/2"></div>
        </div>
      </div>
    );
  }

  if (!manufacturingOrder) {
    return (
      <div className="p-6">
        <div className="text-center text-gray-500">Manufacturing order not found</div>
      </div>
    );
  }

  // Calculate BOM totals
  const bomTotals = {
    totalLines: materials.length,
    totalMeters: materials
      .filter(m => m.uom === 'm')
      .reduce((sum, m) => sum + m.total_qty, 0),
    totalPieces: materials
      .filter(m => m.uom === 'ea')
      .reduce((sum, m) => sum + m.total_qty, 0),
    totalCost: materials.reduce((sum, m) => sum + m.total_cost_exw, 0),
  };

  // Handle Generate BOM
  const handleGenerateBOM = async () => {
    if (!moId || generatingBOM) return;

    try {
      setGeneratingBOM(true);
      
      // Call RPC to generate BOM
      const { data, error } = await supabase.rpc('generate_bom_for_manufacturing_order', {
        p_manufacturing_order_id: moId
      });

      if (error) {
        // Only show error if RPC actually failed
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: error.message || 'Failed to generate BOM',
        });
        return;
      }

      // Refetch both MO and materials to update the display
      await Promise.all([
        refetch(),
        refetchMaterials()
      ]);
      
      // Small delay to allow DB to commit and UI to update
      await new Promise(resolve => setTimeout(resolve, 500));
      
      // Verify BOM was created successfully
      const { data: bomData, error: bomError } = await supabase
        .from('BomInstanceLines')
        .select('id', { count: 'exact', head: true })
        .eq('bom_instance_id', (await supabase
          .from('BomInstances')
          .select('id')
          .eq('sale_order_line_id', (await supabase
            .from('SalesOrderLines')
            .select('id')
            .eq('sale_order_id', manufacturingOrder?.sale_order_id)
            .limit(1)
            .single()).data?.id)
          .limit(1)
          .single()).data?.id)
        .eq('deleted', false);

      // Show success message
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: 'BOM generated successfully',
      });
      
      // Refetch again to get updated status
      await refetch();
      
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

  return (
    <div className="p-6 space-y-6">
      {/* Manufacturing Order Status */}
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Manufacturing Order Status</h3>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="text-sm font-medium text-gray-700">Status</label>
            <div className="mt-1">
              <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${
                manufacturingOrder.status === 'completed' ? 'bg-green-100 text-green-800' :
                manufacturingOrder.status === 'in_production' ? 'bg-yellow-100 text-yellow-800' :
                manufacturingOrder.status === 'planned' ? 'bg-blue-100 text-blue-800' :
                'bg-gray-100 text-gray-800'
              }`}>
                {manufacturingOrder.status === 'draft' 
                  ? 'Material Review' 
                  : manufacturingOrder.status.replace('_', ' ').toUpperCase()}
              </span>
            </div>
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Priority</label>
            <div className="mt-1">
              <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${
                manufacturingOrder.priority === 'urgent' ? 'bg-red-100 text-red-800' :
                manufacturingOrder.priority === 'high' ? 'bg-orange-100 text-orange-800' :
                manufacturingOrder.priority === 'low' ? 'bg-gray-100 text-gray-800' :
                'bg-blue-100 text-blue-800'
              }`}>
                {manufacturingOrder.priority.toUpperCase()}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Dates */}
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Schedule</h3>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="text-sm font-medium text-gray-700">Scheduled Start</label>
            <div className="mt-1 text-sm text-gray-900">
              {manufacturingOrder.scheduled_start_date
                ? new Date(manufacturingOrder.scheduled_start_date).toLocaleDateString()
                : 'Not scheduled'}
            </div>
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Scheduled End</label>
            <div className="mt-1 text-sm text-gray-900">
              {manufacturingOrder.scheduled_end_date
                ? new Date(manufacturingOrder.scheduled_end_date).toLocaleDateString()
                : 'Not scheduled'}
            </div>
          </div>
          {manufacturingOrder.actual_start_date && (
            <div>
              <label className="text-sm font-medium text-gray-700">Actual Start</label>
              <div className="mt-1 text-sm text-gray-900">
                {new Date(manufacturingOrder.actual_start_date).toLocaleDateString()}
              </div>
            </div>
          )}
          {manufacturingOrder.actual_end_date && (
            <div>
              <label className="text-sm font-medium text-gray-700">Actual End</label>
              <div className="mt-1 text-sm text-gray-900">
                {new Date(manufacturingOrder.actual_end_date).toLocaleDateString()}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Sale Order Totals */}
      {manufacturingOrder.SalesOrders && (
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Sale Order Information</h3>
          <div className="space-y-2">
            <div className="flex justify-between">
              <span className="text-sm text-gray-700">Sale Order:</span>
              <span className="text-sm font-medium text-gray-900">
                {manufacturingOrder.SalesOrders.sale_order_no}
              </span>
            </div>
            {manufacturingOrder.SalesOrders.total && (
              <div className="flex justify-between">
                <span className="text-sm text-gray-700">Total:</span>
                <span className="text-sm font-medium text-gray-900">
                  {formatCurrency(manufacturingOrder.SalesOrders.total, manufacturingOrder.SalesOrders.currency || 'USD')}
                </span>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Manufacturing BOM Totals */}
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-gray-900">Manufacturing BOM Summary</h3>
          {manufacturingOrder.status === 'draft' && (
            <button
              onClick={handleGenerateBOM}
              disabled={generatingBOM}
              className="flex items-center gap-2 px-3 py-1.5 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <RefreshCw className={`w-4 h-4 ${generatingBOM ? 'animate-spin' : ''}`} />
              {generatingBOM ? 'Generating...' : 'Generate BOM'}
            </button>
          )}
        </div>
        {loadingMaterials || generatingBOM ? (
          <div className="animate-pulse space-y-2">
            <div className="h-4 bg-gray-200 rounded"></div>
            <div className="h-4 bg-gray-200 rounded"></div>
          </div>
        ) : (
          <div className="space-y-2">
            <div className="flex justify-between">
              <span className="text-sm text-gray-700">Total Material Lines:</span>
              <span className="text-sm font-medium text-gray-900">{bomTotals.totalLines}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-sm text-gray-700">Total Meters (m):</span>
              <span className="text-sm font-medium text-gray-900">
                {bomTotals.totalMeters.toFixed(2)} m
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-sm text-gray-700">Total Pieces (ea):</span>
              <span className="text-sm font-medium text-gray-900">
                {bomTotals.totalPieces.toFixed(0)} ea
              </span>
            </div>
            <div className="flex justify-between border-t border-gray-200 pt-2">
              <span className="text-sm font-medium text-gray-700">Total EXW Cost:</span>
              <span className="text-sm font-semibold text-gray-900">
                {formatCurrency(bomTotals.totalCost, manufacturingOrder.SalesOrders?.currency || 'USD')}
              </span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
