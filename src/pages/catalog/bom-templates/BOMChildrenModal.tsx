import { useMemo, useCallback } from 'react';
import { X, Plus, Trash2, Search, Pencil } from 'lucide-react';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';
import {
  Select as SelectShadcn,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../../../components/ui/SelectShadcn';
import CatalogItemImage from '../../../components/ui/CatalogItemImage';
import { getRoleLabel, getChildRoleOptions } from '../../../lib/bom/roles';
import { BOM_QTY_TYPES, INITIAL_CHILD_FORM_DATA, CONDITION_KEY_OPTIONS, CONDITION_VALUE_OPTIONS } from './types';
import type { BOMComponentDraft, BOMQtyType, ChildFormData } from './types';

const QTY_TYPE_LABELS: Record<string, string> = {
  fixed: 'Fixed',
  per_width: 'Per Width',
  per_height: 'Per Height',
  per_spacing: 'Per Spacing',
  per_joint: 'Per Joint',
};

export interface BOMChildrenModalProps {
  showChildrenModal: boolean;
  editingParentComponentId: string | null;
  childComponents: BOMComponentDraft[];
  setChildComponents: (v: BOMComponentDraft[] | ((prev: BOMComponentDraft[]) => BOMComponentDraft[])) => void;
  showAddChildForm: boolean;
  setShowAddChildForm: (v: boolean) => void;
  editingChildId: string | null;
  setEditingChildId: (v: string | null) => void;
  childFormData: ChildFormData;
  setChildFormData: (v: ChildFormData | ((prev: ChildFormData) => ChildFormData)) => void;
  childSearchTerm: string;
  setChildSearchTerm: (v: string) => void;
  showChildDropdown: boolean;
  setShowChildDropdown: (v: boolean) => void;
  catalogItems: any[];
  categories: any[];
  parentComponentRole?: string | null;
  /** True when there are local changes (adds, updates, deletes) not yet committed to DB */
  hasPendingChanges?: boolean;
  onClose: () => void;
  onAddChild: () => void;
  onDeleteChild: (childId: string) => void;
}

export default function BOMChildrenModal({
  showChildrenModal,
  editingParentComponentId,
  childComponents,
  showAddChildForm,
  setShowAddChildForm,
  editingChildId,
  setEditingChildId,
  childFormData,
  setChildFormData,
  childSearchTerm,
  setChildSearchTerm,
  showChildDropdown,
  setShowChildDropdown,
  catalogItems,
  categories,
  parentComponentRole,
  hasPendingChanges,
  onClose,
  onAddChild,
  onDeleteChild,
}: BOMChildrenModalProps) {
  const flatFilteredChildItems = useMemo(() => {
    const searchTerm = childSearchTerm.trim().toLowerCase();
    return catalogItems.filter((item) => {
      const alreadyUsed = childComponents.some(
        (c) => c.component_item_id === item.id && c.id !== editingChildId
      );
      if (alreadyUsed) return false;
      if (!searchTerm) return true;
      const sku = (item.sku || '').toLowerCase();
      const name = (item.name || item.item_name || '').toLowerCase();
      return sku.includes(searchTerm) || name.includes(searchTerm);
    });
  }, [catalogItems, childSearchTerm, childComponents, editingChildId]);

  const selectedChildItem = useMemo(
    () => catalogItems.find((i) => i.id === childFormData.child_item_id) || null,
    [catalogItems, childFormData.child_item_id]
  );

  const handleSelectChildItem = useCallback(
    (itemId: string) => {
      const item = catalogItems.find((i) => i.id === itemId);
      if (!item) return;
      setChildFormData((prev) => ({
        ...prev,
        child_item_id: itemId,
        uom: item.uom || item.unit_of_measure || 'ea',
      }));
      setChildSearchTerm(`${item.sku || ''} - ${item.name || item.item_name || ''}`);
      setShowChildDropdown(false);
    },
    [catalogItems, setChildFormData, setChildSearchTerm, setShowChildDropdown]
  );

  const handleEditChild = useCallback(
    (child: BOMComponentDraft) => {
      const item = catalogItems.find((i) => i.id === child.component_item_id);
      const display = item
        ? `${item.sku || ''} - ${item.name || item.item_name || ''}`
        : child.catalog_item
          ? `${child.catalog_item.sku || ''} - ${child.catalog_item.name || ''}`
          : '';
      setEditingChildId(child.id);
      setChildSearchTerm(display);
      setChildFormData({
        child_item_id: child.component_item_id || '',
        child_role: child.component_role || '',
        qty_type: (child.qty_type || 'fixed') as BOMQtyType,
        qty: child.qty_value || 1,
        qty_spacing_mm: child.qty_spacing_mm ?? null,
        qty_min: child.qty_min ?? null,
        uom: child.uom || 'ea',
        required: child.is_required !== false,
        per_panel: child.per_panel === true,
        condition_key: child.condition_key || '',
        condition_value: child.condition_value || '',
        notes: '',
      });
      setShowAddChildForm(true);
      setShowChildDropdown(false);
    },
    [catalogItems, setEditingChildId, setChildSearchTerm, setChildFormData, setShowAddChildForm, setShowChildDropdown]
  );

  const handleCancelForm = useCallback(() => {
    setShowAddChildForm(false);
    setEditingChildId(null);
    setChildFormData({ ...INITIAL_CHILD_FORM_DATA });
    setChildSearchTerm('');
    setShowChildDropdown(false);
  }, [setShowAddChildForm, setEditingChildId, setChildFormData, setChildSearchTerm, setShowChildDropdown]);

  if (!showChildrenModal) return null;

  const getItemDisplay = (comp: BOMComponentDraft) => {
    const item = catalogItems.find((i) => i.id === comp.component_item_id) || comp.catalog_item;
    return {
      sku: item?.sku || '—',
      name: item?.name || (item as any)?.item_name || '—',
    };
  };

  return (
    <div className="fixed inset-0 bg-black/50 z-[60] flex items-center justify-center p-4">
      <div
        className="bg-white max-w-3xl w-full max-h-[80vh] flex flex-col rounded shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-4 py-3 border-b border-gray-200 shrink-0">
          <h3 className="text-sm font-semibold text-gray-900">Child Components</h3>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded hover:bg-gray-100 text-gray-500"
            aria-label="Close"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        {hasPendingChanges && (
          <div className="px-4 py-2 bg-amber-50 border-b border-amber-200 flex items-center gap-2 shrink-0">
            <span className="inline-block w-2 h-2 rounded-full bg-amber-500 shrink-0" />
            <p className="text-xs text-amber-700 font-medium">
              Changes pending — close this panel and click <strong>Save</strong> on the template to commit.
            </p>
          </div>
        )}
        <div className="flex-1 overflow-y-auto px-4 py-3 space-y-4">
          <div className="flex justify-end">
            <button
              type="button"
              onClick={() => {
                handleCancelForm();
                setShowAddChildForm(true);
                setChildFormData({ ...INITIAL_CHILD_FORM_DATA, qty: 1, required: true });
              }}
              className="inline-flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-medium text-white bg-primary rounded hover:opacity-90"
            >
              <Plus className="h-3.5 w-3.5" />
              Add Child
            </button>
          </div>

          {showAddChildForm && (
            <div className="p-4 border border-gray-200 rounded bg-gray-50/50 space-y-3">
              <div className="relative">
                <Label>Child Item (SKU)</Label>
                <div className="relative">
                  <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-gray-400" />
                  <Input
                    value={childSearchTerm}
                    onChange={(e) => {
                      setChildSearchTerm(e.target.value);
                      setShowChildDropdown(true);
                    }}
                    onFocus={() => setShowChildDropdown(true)}
                    placeholder="Search by SKU or name..."
                    className="pl-8"
                  />
                  {showChildDropdown && flatFilteredChildItems.length > 0 && (
                    <div className="absolute top-full left-0 right-0 mt-1 max-h-40 overflow-y-auto border border-gray-200 bg-white rounded shadow-lg z-10">
                      {flatFilteredChildItems.map((item) => (
                        <button
                          key={item.id}
                          type="button"
                          className="w-full text-left px-3 py-2 text-xs hover:bg-gray-100"
                          onClick={() => handleSelectChildItem(item.id)}
                        >
                          <div className="flex items-center gap-2">
                            <CatalogItemImage
                              src={item.image_url}
                              alt={item.name || item.item_name || item.sku || 'Item'}
                              size="xs"
                              objectFit="contain"
                            />
                            <div className="min-w-0">
                              <div className="font-mono text-[11px] text-gray-900 truncate">{item.sku || 'N/A'}</div>
                              <div className="text-gray-500 truncate">{item.name || item.item_name || 'Unnamed'}</div>
                            </div>
                          </div>
                        </button>
                      ))}
                    </div>
                  )}
                </div>
                {selectedChildItem && (
                  <div className="mt-2 rounded-md border border-gray-200 bg-white px-2 py-2">
                    <div className="flex items-center gap-2">
                      <CatalogItemImage
                        src={selectedChildItem.image_url}
                        alt={selectedChildItem.name || selectedChildItem.item_name || selectedChildItem.sku || 'Selected item'}
                        size="sm"
                        objectFit="contain"
                      />
                      <div className="min-w-0">
                        <div className="font-mono text-[11px] text-gray-900 truncate">{selectedChildItem.sku || 'N/A'}</div>
                        <div className="text-[11px] text-gray-600 truncate">{selectedChildItem.name || selectedChildItem.item_name || 'Unnamed'}</div>
                      </div>
                    </div>
                  </div>
                )}
              </div>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div>
                  <Label>Role</Label>
                  <SelectShadcn
                    value={childFormData.child_role || 'none'}
                    onValueChange={(v) =>
                      setChildFormData((prev) => ({
                        ...prev,
                        child_role: v === 'none' ? '' : v,
                      }))
                    }
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select role" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="none">— None —</SelectItem>
                      {getChildRoleOptions(parentComponentRole).map((opt) => (
                        <SelectItem key={opt.value} value={opt.value}>
                          {opt.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                </div>
                <div>
                  <Label>Consumption</Label>
                  <SelectShadcn
                    value={childFormData.qty_type || 'fixed'}
                    onValueChange={(v) =>
                      setChildFormData((prev) => ({
                        ...prev,
                        qty_type: v as BOMQtyType,
                        qty:
                          Number.isFinite(prev.qty) && prev.qty > 0
                            ? prev.qty
                            : 1,
                        qty_spacing_mm: v === 'per_spacing' ? (prev.qty_spacing_mm ?? 500) : null,
                        qty_min: v === 'per_spacing' ? prev.qty_min : null,
                      }))
                    }
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {BOM_QTY_TYPES.map((t) => (
                        <SelectItem key={t} value={t}>
                          {QTY_TYPE_LABELS[t] || t}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                </div>
              </div>
              {childFormData.qty_type === 'per_spacing' ? (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div>
                    <Label>Spacing (mm)</Label>
                    <Input
                      type="number"
                      min={1}
                      step={1}
                      value={childFormData.qty_spacing_mm ?? 500}
                      onChange={(e) =>
                        setChildFormData((prev) => ({
                          ...prev,
                          qty_spacing_mm: parseInt(e.target.value, 10) || 500,
                        }))
                      }
                    />
                  </div>
                  <div>
                    <Label>Min Qty</Label>
                    <Input
                      type="number"
                      min={0}
                      step={1}
                      value={childFormData.qty_min ?? ''}
                      placeholder="No min"
                      onChange={(e) => {
                        const v = e.target.value;
                        setChildFormData((prev) => ({
                          ...prev,
                          qty_min: v === '' ? null : parseInt(v, 10),
                        }));
                      }}
                    />
                  </div>
                </div>
              ) : (
                <div>
                  <Label>
                    {childFormData.qty_type === 'fixed' ? 'Quantity' : 'Multiplier'}
                  </Label>
                  <Input
                    type="number"
                    min={childFormData.qty_type === 'fixed' ? 1 : 0.01}
                    step={childFormData.qty_type === 'fixed' ? 1 : 0.01}
                    value={Number.isFinite(childFormData.qty) ? childFormData.qty : ''}
                    onChange={(e) =>
                      setChildFormData((prev) => {
                        const isFixed = prev.qty_type === 'fixed';
                        const val = e.target.value === ''
                          ? Number.NaN
                          : isFixed ? parseInt(e.target.value, 10) : parseFloat(e.target.value);
                        return { ...prev, qty: val };
                      })
                    }
                  />
                </div>
              )}
              <div className="flex items-center gap-4">
                <div className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    id="child-required"
                    checked={childFormData.required}
                    onChange={(e) =>
                      setChildFormData((prev) => ({
                        ...prev,
                        required: e.target.checked,
                      }))
                    }
                    className="rounded border-gray-300"
                  />
                  <Label htmlFor="child-required" className="mb-0">
                    Required
                  </Label>
                </div>
                <div className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    id="child-per-panel"
                    checked={childFormData.per_panel ?? false}
                    onChange={(e) =>
                      setChildFormData((prev) => ({
                        ...prev,
                        per_panel: e.target.checked,
                      }))
                    }
                    className="rounded border-gray-300"
                  />
                  <Label htmlFor="child-per-panel" className="mb-0">
                    Per Panel
                  </Label>
                </div>
              </div>
              <div className="flex items-end gap-2">
                <div className="flex-1">
                  <Label>Condition</Label>
                  <select
                    value={childFormData.condition_key || ''}
                    onChange={(e) => setChildFormData((prev) => ({ ...prev, condition_key: e.target.value, condition_value: e.target.value ? prev.condition_value : '' }))}
                    className="w-full rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm"
                  >
                    {CONDITION_KEY_OPTIONS.map((o) => (
                      <option key={o.value} value={o.value}>{o.label}</option>
                    ))}
                  </select>
                </div>
                {childFormData.condition_key ? (
                  <div className="w-full md:w-40">
                    <Label>Value</Label>
                    {CONDITION_VALUE_OPTIONS[childFormData.condition_key] ? (
                      <select
                        value={childFormData.condition_value || ''}
                        onChange={(e) => setChildFormData((prev) => ({ ...prev, condition_value: e.target.value }))}
                        className="w-full rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm"
                      >
                        <option value="">-- Select --</option>
                        {CONDITION_VALUE_OPTIONS[childFormData.condition_key].map((o) => (
                          <option key={o.value} value={o.value}>{o.label}</option>
                        ))}
                      </select>
                    ) : (
                      <Input
                        value={childFormData.condition_value || ''}
                        onChange={(e) => setChildFormData((prev) => ({ ...prev, condition_value: e.target.value }))}
                        placeholder={childFormData.condition_key === 'motor_item_id' ? 'e.g. EDU-100' : 'Value'}
                        className="text-sm"
                      />
                    )}
                  </div>
                ) : null}
              </div>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={onAddChild}
                  className="px-3 py-1.5 text-xs font-medium text-white bg-primary rounded hover:opacity-90"
                >
                  {editingChildId ? 'Update' : 'Add'}
                </button>
                <button
                  type="button"
                  onClick={handleCancelForm}
                  className="px-3 py-1.5 text-xs font-medium text-gray-700 bg-white border border-gray-300 rounded hover:bg-gray-50"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}

          <div className="border border-gray-200 rounded overflow-hidden">
            <table className="w-full table-fixed text-xs">
              <thead>
                <tr className="bg-gray-50 border-b border-gray-200">
                  <th className="text-left px-3 py-2 font-medium w-[44%]">SKU / Name</th>
                  <th className="text-left px-3 py-2 font-medium w-[16%]">Role</th>
                  <th className="text-left px-3 py-2 font-medium w-[22%]">Consumption</th>
                  <th className="text-center px-3 py-2 font-medium w-[8%]">×Panel</th>
                  <th className="text-right px-3 py-2 font-medium w-[10%]">Actions</th>
                </tr>
              </thead>
              <tbody>
                {childComponents.map((child) => {
                  const { sku, name } = getItemDisplay(child);
                  const consumptionDisplay = child.qty_type === 'per_spacing'
                    ? `Every ${child.qty_spacing_mm ?? 500}mm${child.qty_min != null ? ` (min ${child.qty_min})` : ''}`
                    : child.qty_type === 'fixed'
                      ? String(child.qty_value ?? 1)
                      : `${QTY_TYPE_LABELS[child.qty_type || 'fixed'] || child.qty_type}${child.qty_value != null && child.qty_value !== 1 ? ` x${child.qty_value}` : ''}`;
                  return (
                    <tr
                      key={child.id}
                      className="border-t border-gray-100 hover:bg-gray-50/50 cursor-pointer"
                      onClick={() => handleEditChild(child)}
                    >
                      <td className="px-3 py-2">
                        <div className="flex items-center gap-2">
                          <CatalogItemImage
                            src={(catalogItems.find((i) => i.id === child.component_item_id) || child.catalog_item)?.image_url}
                            alt={name}
                            size="xs"
                            objectFit="contain"
                          />
                          <div className="min-w-0">
                            <div className="font-mono truncate">{sku}</div>
                            <div className="text-gray-500 truncate">{name}</div>
                          </div>
                        </div>
                      </td>
                      <td className="px-3 py-2">{getRoleLabel(child.component_role)}</td>
                      <td className="px-3 py-2">
                        <span
                          className="block whitespace-normal break-words leading-tight"
                          style={{
                            display: '-webkit-box',
                            WebkitLineClamp: 2,
                            WebkitBoxOrient: 'vertical',
                            overflow: 'hidden',
                          }}
                        >
                          {consumptionDisplay}
                        </span>
                      </td>
                      <td className="px-3 py-2 text-center">
                        {child.per_panel ? (
                          <span className="inline-block w-4 h-4 rounded-full bg-gray-700" title="Per Panel" />
                        ) : (
                          <span className="text-gray-300">—</span>
                        )}
                      </td>
                      <td className="px-3 py-2 text-right" onClick={(e) => e.stopPropagation()}>
                        <div className="inline-flex items-center gap-0.5">
                          <button
                            type="button"
                            onClick={() => handleEditChild(child)}
                            className="p-1 rounded hover:bg-gray-100 text-gray-500 hover:text-gray-700"
                            aria-label="Edit"
                          >
                            <Pencil className="h-3.5 w-3.5" />
                          </button>
                          <button
                            type="button"
                            onClick={() => onDeleteChild(child.id)}
                            className="p-1 rounded hover:bg-red-50 text-red-600"
                            aria-label="Delete"
                          >
                            <Trash2 className="h-3.5 w-3.5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}
