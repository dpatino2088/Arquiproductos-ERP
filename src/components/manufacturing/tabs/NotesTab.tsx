import { useState, useEffect } from 'react';
import { useManufacturingOrder, useUpdateManufacturingOrder } from '../../../hooks/useManufacturing';
import { useUIStore } from '../../../stores/ui-store';
import { Save } from 'lucide-react';

interface NotesTabProps {
  moId: string;
}

export default function NotesTab({ moId }: NotesTabProps) {
  const { manufacturingOrder, loading, refetch } = useManufacturingOrder(moId);
  const { updateManufacturingOrder, isUpdating } = useUpdateManufacturingOrder();
  const [notes, setNotes] = useState('');
  const [hasChanges, setHasChanges] = useState(false);

  // Initialize notes from manufacturing order
  useEffect(() => {
    if (manufacturingOrder) {
      setNotes(manufacturingOrder.notes || '');
      setHasChanges(false);
    }
  }, [manufacturingOrder]);

  const handleSave = async () => {
    try {
      await updateManufacturingOrder(moId, { notes: notes || null });
      setHasChanges(false);
      refetch();
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: 'Notes saved successfully',
      });
    } catch (err: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to save notes',
      });
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

  return (
    <div className="p-6">
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-lg font-semibold text-gray-900">Notes</h3>
        <button
          onClick={handleSave}
          disabled={!hasChanges || isUpdating}
          className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white rounded-lg transition-colors hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
          style={{ backgroundColor: 'var(--primary-brand-hex)' }}
        >
          <Save className="w-4 h-4" />
          {isUpdating ? 'Saving...' : 'Save Notes'}
        </button>
      </div>

      <textarea
        value={notes}
        onChange={(e) => {
          setNotes(e.target.value);
          setHasChanges(e.target.value !== (manufacturingOrder.notes || ''));
        }}
        rows={12}
        className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent resize-none"
        placeholder="Add notes, comments, or instructions for this manufacturing order..."
      />

      {hasChanges && (
        <div className="mt-4 text-sm text-gray-500">
          You have unsaved changes. Click "Save Notes" to save them.
        </div>
      )}
    </div>
  );
}
