import { useState } from 'react';
import { useDealerTiers, type DealerTier } from '../../hooks/useDealerTiers';
import Input from '../../components/ui/Input';
import { Save, Loader2 } from 'lucide-react';
import { useUIStore } from '../../stores/ui-store';

export default function DealerTiersSettings() {
  const { tiers, isLoading, error, updateTierDiscount } = useDealerTiers();
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editValue, setEditValue] = useState<string>('');

  const handleStartEdit = (tier: DealerTier) => {
    setEditingId(tier.id);
    setEditValue(String(tier.discount_pct));
  };

  const handleSave = async (id: string) => {
    const num = parseFloat(editValue);
    if (Number.isNaN(num) || num < 0 || num > 100) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Invalid discount',
        message: 'Discount must be between 0 and 100.',
      });
      return;
    }
    setEditingId(null);
    try {
      await updateTierDiscount(id, num);
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Saved',
        message: 'Discount percentage updated.',
      });
    } catch (e: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: e?.message ?? 'Failed to update.',
      });
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-8">
        <Loader2 className="w-8 h-8 animate-spin text-gray-400" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-lg bg-red-50 border border-red-200 text-red-800 p-4">
        {error}
      </div>
    );
  }

  return (
    <div>
      <div className="mb-4">
        <h3 className="text-sm font-semibold text-gray-900">Dealer Tiers</h3>
      </div>
      <div className="grid grid-cols-2 gap-3">
        {tiers.map((tier) => (
          <div
            key={tier.id}
            className="col-span-1 col-start-1 flex items-center gap-4 p-4 bg-white border border-gray-200 rounded-lg"
          >
            <div className="flex-1">
              <span className="font-medium text-gray-900">{tier.name}</span>
              <span className="text-gray-500 ml-2 text-sm">({tier.code})</span>
            </div>
            <div className="flex items-center gap-2">
              {editingId === tier.id ? (
                <>
                  <div className="w-24">
                    <Input
                      type="number"
                      min={0}
                      max={100}
                      step={0.01}
                      value={editValue}
                      onChange={(e) => setEditValue(e.target.value)}
                      className="text-right"
                    />
                  </div>
                  <span className="text-gray-500">%</span>
                  <button
                    type="button"
                    onClick={() => handleSave(tier.id)}
                    className="p-2 text-primary hover:bg-primary/10 rounded-md"
                    title="Save"
                  >
                    <Save className="w-4 h-4" />
                  </button>
                  <button
                    type="button"
                    onClick={() => { setEditingId(null); setEditValue(''); }}
                    className="p-2 text-gray-500 hover:bg-gray-100 rounded-md"
                  >
                    Cancel
                  </button>
                </>
              ) : (
                <>
                  <div className="w-20 text-right shrink-0 mr-6">
                    <span className="text-gray-700 font-medium whitespace-nowrap">{tier.discount_pct}%</span>
                  </div>
                  <button
                    type="button"
                    onClick={() => handleStartEdit(tier)}
                    className="text-sm text-primary hover:underline"
                  >
                    Edit
                  </button>
                </>
              )}
            </div>
          </div>
        ))}
      </div>

      {tiers.length === 0 && (
        <p className="text-gray-500 text-sm">No tiers found. Run the DealerTiers seed migration for your organization.</p>
      )}
    </div>
  );
}
