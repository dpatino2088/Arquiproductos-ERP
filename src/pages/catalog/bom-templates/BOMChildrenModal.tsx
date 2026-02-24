import { useMemo, useCallback } from 'react';
import { X, Plus, Edit, Trash2, Search } from 'lucide-react';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';
import {
  Select as SelectShadcn,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../../../components/ui/SelectShadcn';
import { VALID_CHILD_ROLES, getRoleLabel } from '../../../lib/bom/roles';
import { INITIAL_CHILD_FORM_DATA } from './types';
import type { BOMComponentDraft, ChildFormData } from './types';

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
        qty: child.qty_value || 1,
        uom: child.uom || 'ea',
        required: child.is_required !== false,
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
        className="bg-white max-w-lg w-full max-h-[80vh] flex flex-col rounded shadow-xl"
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
                          {item.sku || 'N/A'} - {item.name || item.item_name || 'Unnamed'}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              </div>
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
                    {VALID_CHILD_ROLES.map((role) => (
                      <SelectItem key={role} value={role}>
                        {getRoleLabel(role)}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
              </div>
              <div>
                <Label>Quantity</Label>
                <Input
                  type="number"
                  min={0.01}
                  step={0.01}
                  value={childFormData.qty}
                  onChange={(e) =>
                    setChildFormData((prev) => ({
                      ...prev,
                      qty: parseFloat(e.target.value) || 1,
                    }))
                  }
                />
              </div>
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
            <table className="w-full text-xs">
              <thead>
                <tr className="bg-gray-50 border-b border-gray-200">
                  <th className="text-left px-3 py-2 font-medium">SKU / Name</th>
                  <th className="text-left px-3 py-2 font-medium">Role</th>
                  <th className="text-left px-3 py-2 font-medium">Qty</th>
                  <th className="text-right px-3 py-2 font-medium">Actions</th>
                </tr>
              </thead>
              <tbody>
                {childComponents.map((child) => {
                  const { sku, name } = getItemDisplay(child);
                  return (
                    <tr key={child.id} className="border-t border-gray-100 hover:bg-gray-50/50">
                      <td className="px-3 py-2">
                        <span className="font-mono">{sku}</span>
                        <span className="text-gray-500 ml-1">{name}</span>
                      </td>
                      <td className="px-3 py-2">{getRoleLabel(child.component_role)}</td>
                      <td className="px-3 py-2">{child.qty_value ?? '—'}</td>
                      <td className="px-3 py-2 text-right">
                        <button
                          type="button"
                          onClick={() => handleEditChild(child)}
                          className="p-1 rounded hover:bg-gray-200 text-gray-600"
                        >
                          <Edit className="h-3.5 w-3.5" />
                        </button>
                        <button
                          type="button"
                          onClick={() => onDeleteChild(child.id)}
                          className="p-1 rounded hover:bg-red-50 text-red-600 ml-1"
                        >
                          <Trash2 className="h-3.5 w-3.5" />
                        </button>
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
