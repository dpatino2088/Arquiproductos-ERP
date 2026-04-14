import { useState } from 'react';
import { useManufacturingOrder, useTransitionMOStatus, ManufacturingOrderStatus } from '../../../hooks/useManufacturing';
import { useAuth } from '../../../hooks/useAuth';
import { useUIStore } from '../../../stores/ui-store';
import { useConfirmDialog } from '../../../hooks/useConfirmDialog';
import ConfirmDialog from '../../ui/ConfirmDialog';
import { CheckCircle, Circle, Clock, XCircle } from 'lucide-react';

interface ProductionStepsTabProps {
  moId: string;
}

const STATUS_STEPS: ManufacturingOrderStatus[] = ['draft', 'confirmed', 'procurement', 'materials_ready', 'in_production', 'quality_check', 'ready_for_pickup', 'delivered'];

const STATUS_LABELS: Record<string, string> = {
  draft: 'Draft',
  confirmed: 'Reviewed',
  procurement: 'Procurement',
  materials_ready: 'Material Ready',
  in_production: 'In Production',
  quality_check: 'Quality Check',
  ready_for_pickup: 'Ready for Pickup',
  delivered: 'Delivered',
  cancelled: 'Cancelled',
};

export default function ProductionStepsTab({ moId }: ProductionStepsTabProps) {
  const { manufacturingOrder: mo, loading, refetch } = useManufacturingOrder(moId);
  const { transitionStatus, isTransitioning } = useTransitionMOStatus();
  const { user } = useAuth();
  const { dialogState, showConfirm, closeDialog, handleConfirm } = useConfirmDialog();
  const [updatingStatus, setUpdatingStatus] = useState<string | null>(null);
  const addNotification = useUIStore((s) => s.addNotification);

  const handleStatusChange = async (newStatus: ManufacturingOrderStatus) => {
    if (!mo || !user?.id) return;

    const confirmed = await showConfirm({
      title: 'Change Status',
      message: `Move this MO to "${STATUS_LABELS[newStatus]}"?`,
      variant: 'info',
      confirmText: 'Change Status',
      cancelText: 'Cancel',
    });
    if (!confirmed) return;

    try {
      setUpdatingStatus(newStatus);
      await transitionStatus(moId, newStatus, user.id, user.name);
      addNotification({ type: 'success', title: 'Status Updated', message: `Moved to ${STATUS_LABELS[newStatus]}` });
      refetch();
    } catch (err: unknown) {
      addNotification({ type: 'error', title: 'Error', message: err instanceof Error ? err.message : 'Failed to update status' });
    } finally {
      setUpdatingStatus(null);
    }
  };

  if (loading) {
    return (
      <div>
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-gray-200 rounded" />
          <div className="h-32 bg-gray-200 rounded" />
        </div>
      </div>
    );
  }

  if (!mo) {
    return <div className="p-6 text-center text-gray-500">Manufacturing order not found</div>;
  }

  const currentStatus = mo.status;
  const currentIdx = STATUS_STEPS.indexOf(currentStatus);
  const isCancelled = currentStatus === 'cancelled';
  return (
    <div>
      <h3 className="text-lg font-semibold text-gray-900 mb-6">Production Workflow</h3>

      {isCancelled ? (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 flex items-center gap-3">
          <XCircle className="w-6 h-6 text-red-600 shrink-0" />
          <p className="text-sm text-red-800 font-medium">This manufacturing order has been cancelled.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {STATUS_STEPS.map((step, idx) => {
            const isCompleted = idx < currentIdx;
            const isCurrent = idx === currentIdx;
            const canAdvance = idx === currentIdx + 1;

            return (
              <div
                key={step}
                className={`flex items-center gap-4 p-4 rounded-lg border ${
                  isCurrent ? 'bg-blue-50 border-blue-200' :
                  isCompleted ? 'bg-green-50 border-green-200' :
                  'bg-gray-50 border-gray-200'
                }`}
              >
                <div className="shrink-0">
                  {isCompleted ? <CheckCircle className="w-6 h-6 text-green-600" /> :
                   isCurrent ? <Clock className="w-6 h-6 text-blue-600" /> :
                   <Circle className="w-6 h-6 text-gray-400" />}
                </div>
                <div className="flex-1">
                  <div className="font-medium text-gray-900">{STATUS_LABELS[step]}</div>
                  {isCurrent && step === 'draft' && (
                    <div className="text-xs text-gray-500 mt-0.5">Review materials before planning.</div>
                  )}
                </div>
                {canAdvance && (
                  <div className="flex flex-col items-end gap-1">
                    <button
                      type="button"
                      onClick={() => handleStatusChange(step)}
                      disabled={isTransitioning}
                      className="px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                    >
                      {isTransitioning && updatingStatus === step ? 'Updating...' : `Advance`}
                    </button>
                  </div>
                )}
                {isCurrent && (
                  <span className="px-3 py-1 text-xs font-medium text-blue-800 bg-blue-100 rounded-full">Current</span>
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
