import { useState } from 'react';
import { useManufacturingOrder, useUpdateManufacturingOrder, useManufacturingMaterials, ManufacturingOrderStatus } from '../../../hooks/useManufacturing';
import { useUIStore } from '../../../stores/ui-store';
import { useConfirmDialog } from '../../../hooks/useConfirmDialog';
import ConfirmDialog from '../../ui/ConfirmDialog';
import { CheckCircle, Circle, Clock } from 'lucide-react';
import { supabase } from '../../../lib/supabase/client';
import { useOrganizationContext } from '../../../context/OrganizationContext';

interface ProductionStepsTabProps {
  moId: string;
}

const STATUS_STEPS: ManufacturingOrderStatus[] = ['draft', 'planned', 'in_production', 'completed'];

const STATUS_LABELS: Record<ManufacturingOrderStatus, string> = {
  draft: 'Draft',
  planned: 'Planned',
  in_production: 'In Production',
  completed: 'Completed',
  cancelled: 'Cancelled',
};

export default function ProductionStepsTab({ moId }: ProductionStepsTabProps) {
  const { manufacturingOrder, loading, refetch } = useManufacturingOrder(moId);
  const { materials } = useManufacturingMaterials(manufacturingOrder?.sale_order_id || null);
  const { updateManufacturingOrder, isUpdating } = useUpdateManufacturingOrder();
  const { dialogState, showConfirm, closeDialog, handleConfirm } = useConfirmDialog();
  const [updatingStatus, setUpdatingStatus] = useState<ManufacturingOrderStatus | null>(null);
  const { activeOrganizationId } = useOrganizationContext();
  
  // Calculate BOM totals for validation
  const bomTotals = {
    totalLines: materials.length,
  };

  const handleStatusChange = async (newStatus: ManufacturingOrderStatus) => {
    if (!manufacturingOrder) return;

    // 🛡️ Guard Rail: Validate status transitions according to business rules
    // DRAFT → PLANNED: Requires valid BOM (BomInstanceLines > 0)
    if (newStatus === 'planned') {
      try {
        // Get SalesOrderLines for this ManufacturingOrder
        const { data: saleOrderLines, error: solError } = await supabase
          .from('SalesOrderLines')
          .select('id')
          .eq('sale_order_id', manufacturingOrder.sale_order_id)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        if (solError) throw solError;

        if (!saleOrderLines || saleOrderLines.length === 0) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Cannot Advance to Planned',
            message: 'No Sales Order Lines found. Cannot advance to Planned status.',
          });
          return;
        }

        const saleOrderLineIds = saleOrderLines.map(sol => sol.id);

        // Get BomInstances for these SalesOrderLines
        const { data: bomInstances, error: biError } = await supabase
          .from('BomInstances')
          .select('id')
          .in('sale_order_line_id', saleOrderLineIds)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        if (biError) throw biError;

        if (!bomInstances || bomInstances.length === 0) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Cannot Advance to Planned',
            message: 'No BOM instances found. Please generate BOM first.',
          });
          return;
        }

        const bomInstanceIds = bomInstances.map(bi => bi.id);

        // Check if BomInstanceLines exist
        const { data: bomLines, error: bilError } = await supabase
          .from('BomInstanceLines')
          .select('id')
          .in('bom_instance_id', bomInstanceIds)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .limit(1);

        if (bilError) throw bilError;

        if (!bomLines || bomLines.length === 0) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Cannot Advance to Planned',
            message: 'BOM has no lines. Cannot advance to Planned without valid BOM. Please generate BOM first.',
          });
          return;
        }
      } catch (err: any) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: err.message || 'Failed to verify BOM before advancing to Planned',
        });
        return;
      }
    }

    // 🛡️ Guard Rail: Check if BOM has lines before starting production
    if (newStatus === 'in_production') {
      try {
        // Get SalesOrderLines for this ManufacturingOrder
        const { data: saleOrderLines, error: solError } = await supabase
          .from('SalesOrderLines')
          .select('id')
          .eq('sale_order_id', manufacturingOrder.sale_order_id)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        if (solError) throw solError;

        if (!saleOrderLines || saleOrderLines.length === 0) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Cannot Start Production',
            message: 'No Sales Order Lines found for this Manufacturing Order',
          });
          return;
        }

        const saleOrderLineIds = saleOrderLines.map(sol => sol.id);

        // Get BomInstances for these SalesOrderLines
        const { data: bomInstances, error: biError } = await supabase
          .from('BomInstances')
          .select('id')
          .in('sale_order_line_id', saleOrderLineIds)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        if (biError) throw biError;

        if (!bomInstances || bomInstances.length === 0) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Cannot Start Production',
            message: 'No BOM instances found. Please generate BOM first.',
          });
          return;
        }

        const bomInstanceIds = bomInstances.map(bi => bi.id);

        // Check if BomInstanceLines exist
        const { data: bomLines, error: bilError } = await supabase
          .from('BomInstanceLines')
          .select('id')
          .in('bom_instance_id', bomInstanceIds)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .limit(1); // Only need to check if any exist

        if (bilError) throw bilError;

        if (!bomLines || bomLines.length === 0) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Cannot Start Production',
            message: 'BOM has no lines. Cannot start production without materials list. Please generate BOM components first.',
          });
          return;
        }
      } catch (err: any) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: err.message || 'Failed to verify BOM before starting production',
        });
        return;
      }
    }

    const confirmed = await showConfirm({
      title: 'Change Manufacturing Order Status',
      message: `Are you sure you want to change the status to "${STATUS_LABELS[newStatus]}"?`,
      variant: 'info',
      confirmText: 'Change Status',
      cancelText: 'Cancel',
    });

    if (!confirmed) return;

    try {
      setUpdatingStatus(newStatus);
      const updateData: any = { status: newStatus };

      // Set actual dates when status changes
      if (newStatus === 'in_production' && !manufacturingOrder.actual_start_date) {
        updateData.actual_start_date = new Date().toISOString().split('T')[0];
      }
      if (newStatus === 'completed' && !manufacturingOrder.actual_end_date) {
        updateData.actual_end_date = new Date().toISOString().split('T')[0];
      }

      // Optional: Store status change timestamp in metadata (minimal)
      // Do NOT invent complex history tracking

      await updateManufacturingOrder(moId, updateData);

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: `Status changed to ${STATUS_LABELS[newStatus]}`,
      });

      refetch();
    } catch (err: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to update status',
      });
    } finally {
      setUpdatingStatus(null);
    }
  };

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

  if (!manufacturingOrder) {
    return (
      <div className="p-6">
        <div className="text-center text-gray-500">Manufacturing order not found</div>
      </div>
    );
  }

  const currentStatusIndex = STATUS_STEPS.indexOf(manufacturingOrder.status);
  const isCancelled = manufacturingOrder.status === 'cancelled';
  
  // Helper function to check if advance is disabled
  const getAdvanceDisabled = (status: ManufacturingOrderStatus, currentStatus: ManufacturingOrderStatus) => {
    // DRAFT → PLANNED: Requires BOM with lines
    if (status === 'planned' && currentStatus === 'draft') {
      return bomTotals.totalLines === 0;
    }
    // PLANNED → IN_PRODUCTION: Requires BOM with lines
    if (status === 'in_production' && currentStatus === 'planned') {
      return bomTotals.totalLines === 0;
    }
    return false;
  };
  
  const getDisableReason = (status: ManufacturingOrderStatus, currentStatus: ManufacturingOrderStatus) => {
    if (status === 'planned' && currentStatus === 'draft' && bomTotals.totalLines === 0) {
      return 'Generate BOM first';
    }
    if (status === 'in_production' && currentStatus === 'planned' && bomTotals.totalLines === 0) {
      return 'BOM must have materials';
    }
    return '';
  };

  return (
    <div className="p-6">
      <h3 className="text-lg font-semibold text-gray-900 mb-6">Production Workflow</h3>

      {isCancelled ? (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium">This manufacturing order has been cancelled.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {STATUS_STEPS.map((status, index) => {
            const isCompleted = index < currentStatusIndex;
            const isCurrent = index === currentStatusIndex;
            const isPending = index > currentStatusIndex;
            const canAdvance = index === currentStatusIndex + 1;
            
            // Business rule validation: disable advance if rules not met
            const isAdvanceDisabled = canAdvance ? getAdvanceDisabled(status, manufacturingOrder.status) : false;
            const disableReason = canAdvance ? getDisableReason(status, manufacturingOrder.status) : '';

            return (
              <div
                key={status}
                className={`flex items-center gap-4 p-4 rounded-lg border ${
                  isCurrent
                    ? 'bg-blue-50 border-blue-200'
                    : isCompleted
                    ? 'bg-green-50 border-green-200'
                    : 'bg-gray-50 border-gray-200'
                }`}
              >
                <div className="flex-shrink-0">
                  {isCompleted ? (
                    <CheckCircle className="w-6 h-6 text-green-600" />
                  ) : isCurrent ? (
                    <Clock className="w-6 h-6 text-blue-600" />
                  ) : (
                    <Circle className="w-6 h-6 text-gray-400" />
                  )}
                </div>
                <div className="flex-1">
                  <div className="font-medium text-gray-900">{STATUS_LABELS[status]}</div>
                  {isCurrent && manufacturingOrder.metadata?.status_history && (
                    <div className="text-xs text-gray-500 mt-1">
                      Started: {new Date(manufacturingOrder.created_at).toLocaleString()}
                    </div>
                  )}
                </div>
                {canAdvance && (
                  <div className="flex flex-col items-end gap-1">
                    <button
                      onClick={() => handleStatusChange(status)}
                      disabled={isUpdating || updatingStatus === status || isAdvanceDisabled}
                      className="px-4 py-2 text-sm font-medium text-white rounded-lg transition-colors hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
                      style={{ backgroundColor: 'var(--primary-brand-hex)' }}
                      title={isAdvanceDisabled ? disableReason : ''}
                    >
                      {isUpdating && updatingStatus === status ? 'Updating...' : 'Advance to this step'}
                    </button>
                    {isAdvanceDisabled && disableReason && (
                      <span className="text-xs text-red-600">{disableReason}</span>
                    )}
                  </div>
                )}
                {isCurrent && (
                  <span className="px-3 py-1 text-xs font-medium text-blue-800 bg-blue-100 rounded-full">
                    Current
                  </span>
                )}
              </div>
            );
          })}
        </div>
      )}


      <ConfirmDialog
        isOpen={dialogState.isOpen}
        onClose={closeDialog}
        onConfirm={handleConfirm}
        title={dialogState.title}
        message={dialogState.message}
        confirmText={dialogState.confirmText}
        cancelText={dialogState.cancelText}
        variant={dialogState.variant}
        isLoading={dialogState.isLoading}
      />
    </div>
  );
}
