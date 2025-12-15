import { useState } from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';
import { Plus, Minus } from 'lucide-react';

interface AccessoriesStepProps {
  config: CurtainConfiguration;
  onUpdate: (updates: Partial<CurtainConfiguration>) => void;
}

const ACCESSORY_CATEGORIES = [
  {
    id: 'mounting',
    name: 'Mounting Material',
    items: [
      { id: 'clip-f1-wall', name: 'Mounting Clip F1 (Wall)', price: 0.40 },
      { id: 'plates-3mm', name: 'Mounting Plates 3mm, On-/Both-Sided For C1, C2, R1', price: 0.40 },
      { id: 'tabs-a1-d1', name: 'Mounting Tabs A1-D1 (For C1), A2-D2 (For C2)', price: 0.40 },
      { id: 'clip-f1-ceiling', name: 'Mounting Clip F1 (Ceiling)', price: 0.40 },
    ],
  },
  {
    id: 'tapes',
    name: 'Tapes',
    items: [
      { id: 'tape-1', name: 'Tape Type 1', price: 0.20 },
      { id: 'tape-2', name: 'Tape Type 2', price: 0.25 },
    ],
  },
  {
    id: 'spare',
    name: 'Spare And Small Parts, Assembly Accessories',
    items: [
      { id: 'spare-1', name: 'Spare Part 1', price: 0.10 },
    ],
  },
];

export default function AccessoriesStep({ config, onUpdate }: AccessoriesStepProps) {
  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(new Set(['mounting']));

  const toggleCategory = (categoryId: string) => {
    setExpandedCategories(prev => {
      const next = new Set(prev);
      if (next.has(categoryId)) {
        next.delete(categoryId);
      } else {
        next.add(categoryId);
      }
      return next;
    });
  };

  const updateAccessoryQty = (itemId: string, name: string, price: number, delta: number) => {
    if (!itemId || !name) return;
    
    const currentAccessories = config.accessories || [];
    const existingIndex = currentAccessories.findIndex(a => a.id === itemId);
    
    let updated: typeof currentAccessories;
    if (existingIndex >= 0) {
      const existing = currentAccessories[existingIndex];
      if (!existing) {
        updated = currentAccessories;
      } else {
        const newQty = existing.qty + delta;
        if (newQty <= 0) {
          updated = currentAccessories.filter(a => a.id !== itemId);
        } else {
          updated = [...currentAccessories];
          updated[existingIndex] = { ...existing, qty: newQty };
        }
      }
    } else {
      if (delta > 0 && itemId && name) {
        updated = [...currentAccessories, { id: itemId, name, price, qty: delta }];
      } else {
        updated = currentAccessories;
      }
    }
    
    onUpdate({ accessories: updated });
  };

  const getAccessoryQty = (itemId: string) => {
    return config.accessories?.find(a => a.id === itemId)?.qty || 0;
  };

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <Label className="text-sm font-medium mb-4 block">ALL ACCESSORIES</Label>
        <div className="space-y-4">
          {ACCESSORY_CATEGORIES.map((category) => {
            const isExpanded = expandedCategories.has(category.id);
            return (
              <div key={category.id} className="border border-gray-200 rounded-lg">
                <button
                  onClick={() => toggleCategory(category.id)}
                  className="w-full px-4 py-3 flex items-center justify-between hover:bg-gray-50 transition-colors"
                >
                  <span className="text-sm font-medium text-gray-900">{category.name}</span>
                  <span className="text-gray-400">{isExpanded ? '▼' : '▶'}</span>
                </button>
                {isExpanded && (
                  <div className="border-t border-gray-200">
                    <table className="w-full">
                      <thead className="bg-gray-50">
                        <tr>
                          <th className="text-left py-2 px-4 text-xs font-medium text-gray-700">Item Name</th>
                          <th className="text-center py-2 px-4 text-xs font-medium text-gray-700">Quantity</th>
                          <th className="text-right py-2 px-4 text-xs font-medium text-gray-700">Price</th>
                          <th className="text-right py-2 px-4 text-xs font-medium text-gray-700">Total Price</th>
                        </tr>
                      </thead>
                      <tbody>
                        {category.items.map((item) => {
                          const qty = getAccessoryQty(item.id);
                          const isSelected = qty > 0;
                          return (
                            <tr key={item.id} className={isSelected ? 'bg-primary/5' : ''}>
                              <td className="py-2 px-4">
                                <div className="flex items-center gap-2">
                                  <input
                                    type="radio"
                                    checked={isSelected}
                                    onChange={() => {
                                      if (!isSelected) {
                                        updateAccessoryQty(item.id, item.name, item.price, 1);
                                      }
                                    }}
                                    className="w-4 h-4 text-primary"
                                  />
                                  <span className="text-sm text-gray-900">{item.name}</span>
                                </div>
                              </td>
                              <td className="py-2 px-4 text-center">
                                <div className="flex items-center justify-center gap-2">
                                  <button
                                    onClick={() => updateAccessoryQty(item.id, item.name, item.price, -1)}
                                    disabled={qty === 0}
                                    className="p-1 hover:bg-gray-200 rounded disabled:opacity-50"
                                  >
                                    <Minus className="w-3 h-3" />
                                  </button>
                                  <span className="text-sm font-medium w-8">{qty}</span>
                                  <button
                                    onClick={() => updateAccessoryQty(item.id, item.name, item.price, 1)}
                                    className="p-1 hover:bg-gray-200 rounded"
                                  >
                                    <Plus className="w-3 h-3" />
                                  </button>
                                </div>
                              </td>
                              <td className="py-2 px-4 text-right text-sm text-gray-700">
                                €{item.price.toFixed(2)}
                              </td>
                              <td className="py-2 px-4 text-right text-sm font-medium text-gray-900">
                                €{(item.price * qty).toFixed(2)}
                              </td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

