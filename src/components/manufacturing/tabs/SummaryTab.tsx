import { useState } from 'react';
import { useManufacturingOrder, useManufacturingMaterials } from '../../../hooks/useManufacturing';
import { formatCurrency } from '../../../lib/utils';
import { supabase } from '../../../lib/supabase/client';
import { useUIStore } from '../../../stores/ui-store';
import { RefreshCw } from 'lucide-react';
import { normalizeUUID } from '../../../utils/uuid';
import StatusBadge from '../../shared/StatusBadge';

interface SummaryTabProps {
  moId: string;
}

export default function SummaryTab({ moId }: SummaryTabProps) {
  const { manufacturingOrder: mo, loading, refetch } = useManufacturingOrder(moId);
  const { materials, loading: loadingMaterials, refetch: refetchMaterials } = useManufacturingMaterials(moId);
  const [generatingBOM, setGeneratingBOM] = useState(false);
  const addNotification = useUIStore((s) => s.addNotification);

  if (loading) {
    return (
      <div className="p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-4 bg-gray-200 rounded w-1/4" />
          <div className="h-4 bg-gray-200 rounded w-1/2" />
        </div>
      </div>
    );
  }

  if (!mo) {
    return <div className="p-6 text-center text-gray-500">Manufacturing order not found</div>;
  }

  const bomTotals = {
    totalLines: materials.length,
    totalMeters: materials.filter(m => m.uom === 'm').reduce((sum, m) => sum + m.total_qty, 0),
    totalPieces: materials.filter(m => m.uom === 'ea').reduce((sum, m) => sum + m.total_qty, 0),
    totalCost: materials.reduce((sum, m) => sum + m.total_cost_exw, 0),
  };

  const handleGenerateBOM = async () => {
    if (!moId || generatingBOM) return;
    const safeMoId = normalizeUUID(moId);
    if (!safeMoId) {
      addNotification({ type: 'error', title: 'Error', message: 'Invalid manufacturing order ID' });
      return;
    }
    try {
      setGeneratingBOM(true);
      const { error } = await supabase.rpc('generate_bom_for_manufacturing_order', { p_manufacturing_order_id: safeMoId });
      if (error) {
        addNotification({ type: 'error', title: 'Error', message: error.message || 'Failed to generate BOM' });
        return;
      }
      await Promise.all([refetch(), refetchMaterials()]);
      addNotification({ type: 'success', title: 'Success', message: 'BOM generated successfully' });
    } catch (err) {
      addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed to generate BOM' });
    } finally {
      setGeneratingBOM(false);
    }
  };

  const so = mo.SalesOrders;

  return (
    <div className="p-6 space-y-6">
      {/* Status & Priority */}
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <h3 className="text-sm font-semibold text-gray-900 mb-4">Manufacturing Order Status</h3>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="text-xs font-medium text-gray-500">Status</label>
            <div className="mt-1">
              <StatusBadge status={mo.status} type="manufacturing" size="md" />
            </div>
          </div>
          <div>
            <label className="text-xs font-medium text-gray-500">Priority</label>
            <div className="mt-1">
              <StatusBadge status={mo.priority ?? 'normal'} type="priority" size="md" />
            </div>
          </div>
        </div>
      </div>

      {/* Dates */}
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <h3 className="text-sm font-semibold text-gray-900 mb-4">Schedule</h3>
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <label className="text-xs font-medium text-gray-500">Created</label>
            <div className="mt-1 text-gray-900">{new Date(mo.created_at).toLocaleDateString()}</div>
          </div>
          {mo.released_at && (
            <div>
              <label className="text-xs font-medium text-gray-500">Released</label>
              <div className="mt-1 text-gray-900">{new Date(mo.released_at).toLocaleDateString()}</div>
            </div>
          )}
          {mo.production_started_at && (
            <div>
              <label className="text-xs font-medium text-gray-500">Production Started</label>
              <div className="mt-1 text-gray-900">{new Date(mo.production_started_at).toLocaleDateString()}</div>
            </div>
          )}
          {mo.completed_at && (
            <div>
              <label className="text-xs font-medium text-gray-500">Completed</label>
              <div className="mt-1 text-gray-900">{new Date(mo.completed_at).toLocaleDateString()}</div>
            </div>
          )}
          {mo.delivered_at && (
            <div>
              <label className="text-xs font-medium text-gray-500">Delivered</label>
              <div className="mt-1 text-gray-900">{new Date(mo.delivered_at).toLocaleDateString()}</div>
            </div>
          )}
        </div>
      </div>

      {/* Sale Order Info */}
      {so && (
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <h3 className="text-sm font-semibold text-gray-900 mb-4">Sale Order Information</h3>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-gray-500">Sale Order</span>
              <span className="font-medium text-gray-900">{so.sales_order_no}</span>
            </div>
            {so.total_amount != null && (
              <div className="flex justify-between">
                <span className="text-gray-500">Total</span>
                <span className="font-mono font-medium text-gray-900">{formatCurrency(so.total_amount, 'USD')}</span>
              </div>
            )}
          </div>
        </div>
      )}

      {/* BOM Totals */}
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm font-semibold text-gray-900">Manufacturing BOM Summary</h3>
          {mo.status === 'draft' && (
            <button
              onClick={handleGenerateBOM}
              disabled={generatingBOM}
              className="flex items-center gap-2 px-3 py-1.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              <RefreshCw className={`w-4 h-4 ${generatingBOM ? 'animate-spin' : ''}`} />
              {generatingBOM ? 'Generating...' : 'Generate BOM'}
            </button>
          )}
        </div>
        {loadingMaterials || generatingBOM ? (
          <div className="animate-pulse space-y-2">
            <div className="h-4 bg-gray-200 rounded" />
            <div className="h-4 bg-gray-200 rounded" />
          </div>
        ) : (
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-gray-500">Total Material Lines</span>
              <span className="font-medium text-gray-900">{bomTotals.totalLines}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500">Total Meters (m)</span>
              <span className="font-medium text-gray-900">{bomTotals.totalMeters.toFixed(2)} m</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500">Total Pieces (ea)</span>
              <span className="font-medium text-gray-900">{bomTotals.totalPieces.toFixed(0)} ea</span>
            </div>
            <div className="flex justify-between border-t pt-2">
              <span className="font-medium text-gray-700">Total EXW Cost</span>
              <span className="font-semibold font-mono text-gray-900">{formatCurrency(bomTotals.totalCost, 'USD')}</span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
