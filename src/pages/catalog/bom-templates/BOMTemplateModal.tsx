import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Plus, Edit, Trash2, Search, Wrench, Settings, Package, X, ChevronRight, ChevronDown } from 'lucide-react';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';
import {
  Select as SelectShadcn,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../../../components/ui/SelectShadcn';
import { Tooltip, TooltipProvider } from '../../../components/ui/Tooltip';
import { getRoleLabel, getAllRoleOptions } from '../../../lib/bom/roles';
import { BOM_QTY_TYPES } from './types';
import { useBOMTemplateForm } from './useBOMTemplateForm';
import BOMEngineeringModal from './BOMEngineeringModal';
import BOMChildrenModal from './BOMChildrenModal';
import type { BOMComponentDraft } from './types';

const HARDWARE_COLORS = ['White', 'Black', 'Silver', 'Bronze', 'Grey'] as const;
const PANEL_COUNT_OPTIONS = [
  { value: 1, label: '1 paño' },
  { value: 2, label: '2 paños' },
  { value: 3, label: '3 paños' },
] as const;

const QTY_TYPE_LABELS: Record<string, string> = {
  fixed: 'Fixed',
  per_width: 'Per Width',
  per_height: 'Per Height',
  per_area: 'Per Area',
  per_spacing: 'Per Spacing',
};

export interface BOMTemplateModalProps {
  isOpen: boolean;
  editingTemplateId: string | null;
  onClose: () => void;
  onSave: () => void;
}

export default function BOMTemplateModal({
  isOpen,
  editingTemplateId,
  onClose,
  onSave,
}: BOMTemplateModalProps) {
  const form = useBOMTemplateForm(editingTemplateId);
  const autocompleteRef = useRef<HTMLDivElement>(null);
  const [expandedRows, setExpandedRows] = useState<Set<string>>(new Set());

  const toggleExpand = useCallback((id: string) => {
    setExpandedRows(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  }, []);

  const handleRequestClose = useCallback(() => {
    if (form.isDirty && !window.confirm('You have unsaved changes. Discard?')) return;
    onClose();
  }, [form.isDirty, onClose]);

  const handleSaveClick = useCallback(async () => {
    const ok = await form.handleSave();
    if (ok) onSave();
  }, [form.handleSave, onSave]);

  // Keyboard nav for autocomplete
  useEffect(() => {
    if (!form.showComponentDropdown || form.flatFilteredItems.length === 0) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        form.setHighlightedIndex((i) =>
          i < form.flatFilteredItems.length - 1 ? i + 1 : i
        );
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        form.setHighlightedIndex((i) => (i > 0 ? i - 1 : 0));
      } else if (e.key === 'Enter') {
        e.preventDefault();
        const item = form.flatFilteredItems[form.highlightedIndex];
        if (item) form.handleSelectComponent(item.id);
      } else if (e.key === 'Escape') {
        form.setShowComponentDropdown(false);
        form.setHighlightedIndex(-1);
      }
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [
    form.showComponentDropdown,
    form.flatFilteredItems,
    form.highlightedIndex,
    form.handleSelectComponent,
    form.setHighlightedIndex,
    form.setShowComponentDropdown,
  ]);

  if (!isOpen) return null;

  const getItemDisplay = (comp: BOMComponentDraft) => {
    const item =
      form.catalogItems.find((i) => i.id === comp.component_item_id) ||
      comp.catalog_item;
    const sku = item?.sku || '—';
    const name = item?.name || (item as any)?.item_name || '—';
    return { sku, name };
  };

  const getQtyDisplay = (comp: BOMComponentDraft) => {
    if (comp.qty_type === 'fixed') return String(comp.qty_value ?? '—');
    if (comp.qty_type === 'per_spacing') {
      const sp = comp.qty_spacing_mm ?? 500;
      const min = comp.qty_min;
      return `Every ${sp}mm${min != null ? ` (min ${min})` : ''}`;
    }
    const label = QTY_TYPE_LABELS[comp.qty_type || 'fixed'] || comp.qty_type || '—';
    const mult = comp.qty_value != null && comp.qty_value !== 1 ? ` x${comp.qty_value}` : '';
    return `${label}${mult}`;
  };

  // Group flatFilteredItems by category for dropdown
  const groupedAutocompleteItems = form.flatFilteredItems.reduce<
    Record<string, typeof form.flatFilteredItems>
  >((acc, item) => {
    const cat = item.category || 'Uncategorized';
    if (!acc[cat]) acc[cat] = [];
    acc[cat].push(item);
    return acc;
  }, {});

  return (
    <TooltipProvider>
      <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
        <div
          className="bg-white max-w-6xl w-full h-full max-h-[90vh] flex flex-col rounded shadow-xl"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 shrink-0">
            <h2 className="text-lg font-semibold text-gray-900">
              {editingTemplateId ? 'Edit BOM Template' : 'Add New BOM Template'}
            </h2>
            <button
              type="button"
              onClick={handleRequestClose}
              className="p-1.5 rounded hover:bg-gray-100 text-gray-500 hover:text-gray-700"
              aria-label="Close"
            >
              <X className="h-5 w-5" />
            </button>
          </div>

          {/* Body */}
          <div className="flex-1 overflow-y-auto px-6 py-4 space-y-6">
            {/* Product Type */}
            <div>
              <Label htmlFor="product-type">Product Type</Label>
              <SelectShadcn
                value={form.productTypeId}
                onValueChange={form.setProductTypeId}
              >
                <SelectTrigger id="product-type">
                  <SelectValue placeholder="Select product type" />
                </SelectTrigger>
                <SelectContent>
                  {form.productTypes.map((pt) => (
                    <SelectItem key={pt.id} value={pt.id}>
                      {pt.name || pt.code || pt.id}
                    </SelectItem>
                  ))}
                </SelectContent>
              </SelectShadcn>
            </div>

            {/* Code */}
            <div>
              <Label htmlFor="template-code">Code</Label>
              <Input
                id="template-code"
                value={form.templateCode}
                onChange={(e) => form.setTemplateCode(e.target.value)}
                placeholder="TEMPLATE_CODE"
              />
            </div>

            {/* Name + Description */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="template-name">Name</Label>
                <Input
                  id="template-name"
                  value={form.templateName}
                  onChange={(e) => form.setTemplateName(e.target.value)}
                  placeholder="Template name"
                />
              </div>
              <div>
                <Label htmlFor="template-description">Description</Label>
                <Input
                  id="template-description"
                  value={form.templateDescription}
                  onChange={(e) => form.setTemplateDescription(e.target.value)}
                  placeholder="Description"
                />
              </div>
            </div>

            {/* Hardware Color + Panel Count */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="hardware-color" required>
                  Hardware Color
                </Label>
                <SelectShadcn
                  value={form.templateHardwareColor}
                  onValueChange={form.setTemplateHardwareColor}
                >
                  <SelectTrigger id="hardware-color">
                    <SelectValue placeholder="Select color" />
                  </SelectTrigger>
                  <SelectContent>
                    {HARDWARE_COLORS.map((c) => (
                      <SelectItem key={c} value={c}>
                        {c}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
              </div>
              <div>
                <Label htmlFor="panel-count" required>
                  Panel Count
                </Label>
                <SelectShadcn
                  value={String(form.templatePanelCount)}
                  onValueChange={(v) =>
                    form.setTemplatePanelCount(Number(v) as 1 | 2 | 3)
                  }
                >
                  <SelectTrigger id="panel-count">
                    <SelectValue placeholder="Select" />
                  </SelectTrigger>
                  <SelectContent>
                    {PANEL_COUNT_OPTIONS.map((o) => (
                      <SelectItem key={o.value} value={String(o.value)}>
                        {o.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
              </div>
            </div>

            {/* Components section */}
            <div>
              <div className="flex items-center justify-between mb-3">
                <h3 className="text-sm font-semibold text-gray-900">
                  Components
                </h3>
                <button
                  type="button"
                  onClick={() => {
                    form.resetForm();
                    form.setShowAddComponentForm(true);
                  }}
                  className="inline-flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-medium text-white bg-primary rounded hover:opacity-90"
                >
                  <Plus className="h-3.5 w-3.5" />
                  Add Component
                </button>
              </div>

              {/* Add/Edit Component form */}
              {form.showAddComponentForm && (
                <div className="mb-4 p-4 border border-gray-200 rounded bg-gray-50/50 space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <Label>Category filter</Label>
                      <SelectShadcn
                        value={form.selectedCategoryFilter || '__all__'}
                        onValueChange={(value) =>
                          form.setSelectedCategoryFilter(
                            value === '__all__' ? '' : value
                          )
                        }
                      >
                        <SelectTrigger>
                          <SelectValue placeholder="All categories" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="__all__">All categories</SelectItem>
                          {form.categories.map((c) => (
                            <SelectItem key={c.id} value={c.id}>
                              {c.name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </SelectShadcn>
                    </div>
                    <div className="relative" ref={autocompleteRef}>
                      <Label>Component (SKU)</Label>
                      <div className="relative">
                        <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-gray-400" />
                        <Input
                          value={form.componentSearchTerm}
                          onChange={(e) => {
                            form.setComponentSearchTerm(e.target.value);
                            form.setShowComponentDropdown(true);
                            form.setHighlightedIndex(0);
                          }}
                          onFocus={() => {
                            form.setShowComponentDropdown(true);
                            if (form.flatFilteredItems.length)
                              form.setHighlightedIndex(0);
                          }}
                          placeholder="Search by SKU or name..."
                          className="pl-8"
                        />
                        {form.showComponentDropdown &&
                          form.flatFilteredItems.length > 0 && (
                            <div className="absolute top-full left-0 right-0 mt-1 max-h-48 overflow-y-auto border border-gray-200 bg-white rounded shadow-lg z-10">
                              {Object.entries(groupedAutocompleteItems).map(
                                ([cat, items]) => (
                                  <div key={cat}>
                                    <div className="px-2 py-1 text-xs font-medium text-gray-500 bg-gray-50 sticky top-0">
                                      {cat}
                                    </div>
                                    {items.map((item, idx) => {
                                      const globalIdx =
                                        form.flatFilteredItems.indexOf(item);
                                      const isHighlighted =
                                        globalIdx === form.highlightedIndex;
                                      return (
                                        <button
                                          key={item.id}
                                          type="button"
                                          className={`w-full text-left px-3 py-2 text-xs hover:bg-gray-100 ${
                                            isHighlighted ? 'bg-gray-100' : ''
                                          }`}
                                          onMouseEnter={() =>
                                            form.setHighlightedIndex(globalIdx)
                                          }
                                          onClick={() =>
                                            form.handleSelectComponent(item.id)
                                          }
                                        >
                                          {item.sku} - {item.name}
                                        </button>
                                      );
                                    })}
                                  </div>
                                )
                              )}
                            </div>
                          )}
                      </div>
                    </div>
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <Label>Role</Label>
                      <SelectShadcn
                        value={form.formData.component_role || 'none'}
                        onValueChange={(v) =>
                          form.setFormData((prev) => ({
                            ...prev,
                            component_role: v === 'none' ? '' : v,
                          }))
                        }
                      >
                        <SelectTrigger>
                          <SelectValue placeholder="Select role" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="none">— None —</SelectItem>
                          {getAllRoleOptions().map((opt) => (
                            <SelectItem key={opt.value} value={opt.value}>
                              {opt.label}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </SelectShadcn>
                    </div>
                    <div>
                      <Label>Qty Type</Label>
                      <SelectShadcn
                        value={form.formData.qty_type || 'fixed'}
                        onValueChange={(v) =>
                          form.setFormData((prev) => ({
                            ...prev,
                            qty_type: v as any,
                            qty_value:
                              v === 'fixed' ? (prev.qty_value ?? 1)
                              : v === 'per_spacing' ? null
                              : (prev.qty_value ?? 1),
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
                  {form.formData.qty_type === 'fixed' && (
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <Label>Qty Value</Label>
                        <Input
                          type="number"
                          min={0.01}
                          step={0.01}
                          value={form.formData.qty_value ?? ''}
                          onChange={(e) => {
                            const v = e.target.value;
                            const n =
                              v === '' ? null : parseFloat(v);
                            form.setFormData((prev) => ({
                              ...prev,
                              qty_value: n,
                            }));
                          }}
                        />
                      </div>
                      <div>
                        <Label>UOM</Label>
                        <Input
                          value={form.formData.uom}
                          readOnly
                          className="bg-gray-50"
                        />
                      </div>
                    </div>
                  )}
                  {(form.formData.qty_type === 'per_width' || form.formData.qty_type === 'per_height' || form.formData.qty_type === 'per_area') && (
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <Label>Multiplier</Label>
                        <Input
                          type="number"
                          min={0.01}
                          step={0.01}
                          value={form.formData.qty_value ?? ''}
                          onChange={(e) => {
                            const v = e.target.value;
                            const n = v === '' ? null : parseFloat(v);
                            form.setFormData((prev) => ({
                              ...prev,
                              qty_value: n,
                            }));
                          }}
                        />
                      </div>
                      <div>
                        <Label>UOM</Label>
                        <Input
                          value={form.formData.uom}
                          readOnly
                          className="bg-gray-50"
                        />
                      </div>
                    </div>
                  )}
                  {form.formData.qty_type === 'per_spacing' && (
                    <div className="grid grid-cols-3 gap-4">
                      <div>
                        <Label>Spacing (mm)</Label>
                        <Input
                          type="number"
                          min={1}
                          step={1}
                          value={form.formData.qty_spacing_mm ?? 500}
                          onChange={(e) => {
                            const n = parseInt(e.target.value, 10) || 500;
                            form.setFormData((prev) => ({
                              ...prev,
                              qty_spacing_mm: n,
                            }));
                          }}
                        />
                      </div>
                      <div>
                        <Label>Min Qty</Label>
                        <Input
                          type="number"
                          min={0}
                          step={1}
                          value={form.formData.qty_min ?? ''}
                          placeholder="No min"
                          onChange={(e) => {
                            const v = e.target.value;
                            const n = v === '' ? null : parseInt(v, 10);
                            form.setFormData((prev) => ({
                              ...prev,
                              qty_min: n,
                            }));
                          }}
                        />
                      </div>
                      <div>
                        <Label>UOM</Label>
                        <Input
                          value={form.formData.uom}
                          readOnly
                          className="bg-gray-50"
                        />
                      </div>
                    </div>
                  )}
                  <div className="flex items-center gap-4">
                    <div className="flex items-center gap-2">
                      <input
                        type="checkbox"
                        id="is-required"
                        checked={form.formData.is_required ?? true}
                        onChange={(e) =>
                          form.setFormData((prev) => ({
                            ...prev,
                            is_required: e.target.checked,
                          }))
                        }
                        className="rounded border-gray-300"
                      />
                      <Label htmlFor="is-required" className="mb-0">
                        Required
                      </Label>
                    </div>
                    <div>
                      <Label>Order</Label>
                      <Input
                        type="number"
                        min={0}
                        value={form.formData.sequence_order}
                        onChange={(e) =>
                          form.setFormData((prev) => ({
                            ...prev,
                            sequence_order: parseInt(
                              e.target.value,
                              10
                            ) || 0,
                          }))
                        }
                        className="w-20"
                      />
                    </div>
                  </div>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() =>
                        form.editingComponentId
                          ? form.handleUpdateComponent()
                          : form.handleAddComponent()
                      }
                      className="px-3 py-1.5 text-xs font-medium text-white bg-primary rounded hover:opacity-90"
                    >
                      {form.editingComponentId ? 'Update' : 'Add'}
                    </button>
                    <button
                      type="button"
                      onClick={form.resetForm}
                      className="px-3 py-1.5 text-xs font-medium text-gray-700 bg-white border border-gray-300 rounded hover:bg-gray-50"
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              )}

              {/* Components table grouped by category */}
              <div className="border border-gray-200 rounded overflow-hidden">
                <table className="w-full text-xs">
                  <thead>
                    <tr className="bg-gray-50 border-b border-gray-200">
                      <th className="w-8 px-1 py-2" />
                      <th className="text-left px-3 py-2 font-medium">
                        SKU / Name
                      </th>
                      <th className="text-left px-3 py-2 font-medium">Qty</th>
                      <th className="text-left px-3 py-2 font-medium">UOM</th>
                      <th className="text-left px-3 py-2 font-medium">Role</th>
                      <th className="text-left px-3 py-2 font-medium">
                        Children
                      </th>
                      <th className="text-left px-3 py-2 font-medium">Eng.</th>
                      <th className="text-left px-3 py-2 font-medium">Order</th>
                      <th className="text-left px-3 py-2 font-medium">Req.</th>
                      <th className="text-right px-3 py-2 font-medium">
                        Actions
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {form.componentsByCategory.map((group) => (
                      <React.Fragment key={group.category_id}>
                        <tr
                          key={`h-${group.category_id}`}
                          className="bg-gray-100 font-medium text-gray-700"
                        >
                          <td
                            colSpan={10}
                            className="px-3 py-1.5"
                          >
                            {group.category_name}
                          </td>
                        </tr>
                        {group.components.map((comp) => {
                          const { sku, name } = getItemDisplay(comp);
                          const children =
                            form.childrenByParent[comp.id] ?? [];
                          const childCount = children.length;
                          const hasEngineering = !!comp.cut_axis;
                          const isExpanded = expandedRows.has(comp.id);
                          return (
                            <React.Fragment key={comp.id}>
                              <tr className="border-t border-gray-100 hover:bg-gray-50/50">
                                <td className="px-1 py-2 text-center">
                                  {childCount > 0 ? (
                                    <button
                                      type="button"
                                      onClick={() => toggleExpand(comp.id)}
                                      className="p-0.5 rounded hover:bg-gray-200 text-gray-500"
                                    >
                                      {isExpanded ? (
                                        <ChevronDown className="h-3.5 w-3.5" />
                                      ) : (
                                        <ChevronRight className="h-3.5 w-3.5" />
                                      )}
                                    </button>
                                  ) : (
                                    <span className="inline-block w-3.5" />
                                  )}
                                </td>
                                <td className="px-3 py-2">
                                  <span className="font-mono text-gray-700">
                                    {sku}
                                  </span>
                                  <span className="text-gray-500 ml-1">
                                    {name}
                                  </span>
                                </td>
                                <td className="px-3 py-2">
                                  {getQtyDisplay(comp)}
                                </td>
                                <td className="px-3 py-2">{comp.uom || 'ea'}</td>
                                <td className="px-3 py-2">
                                  {getRoleLabel(comp.component_role)}
                                </td>
                                <td className="px-3 py-2">{childCount}</td>
                                <td className="px-3 py-2">
                                  {hasEngineering ? (
                                    <Wrench className="h-3.5 w-3.5 text-primary" />
                                  ) : (
                                    '—'
                                  )}
                                </td>
                                <td className="px-3 py-2">
                                  {comp.sort_order ?? comp.sequence_order ?? 0}
                                </td>
                                <td className="px-3 py-2">
                                  {comp.is_required !== false ? (
                                    <span className="text-primary font-medium">
                                      Yes
                                    </span>
                                  ) : (
                                    'No'
                                  )}
                                </td>
                                <td className="px-3 py-2 text-right">
                                  <div className="flex items-center justify-end gap-1">
                                    <Tooltip content="Edit">
                                      <button
                                        type="button"
                                        onClick={() =>
                                          form.handleEditComponent(comp)
                                        }
                                        className="p-1 rounded hover:bg-gray-200 text-gray-600"
                                      >
                                        <Edit className="h-3.5 w-3.5" />
                                      </button>
                                    </Tooltip>
                                    <Tooltip content="Engineering">
                                      <button
                                        type="button"
                                        onClick={() =>
                                          form.handleOpenEngineeringModal(
                                            comp.id
                                          )
                                        }
                                        className="p-1 rounded hover:bg-gray-200 text-gray-600"
                                      >
                                        <Settings className="h-3.5 w-3.5" />
                                      </button>
                                    </Tooltip>
                                    <Tooltip content="Children">
                                      <button
                                        type="button"
                                        onClick={() =>
                                          form.handleOpenChildrenModal(comp.id)
                                        }
                                        className="p-1 rounded hover:bg-gray-200 text-gray-600"
                                      >
                                        <Package className="h-3.5 w-3.5" />
                                      </button>
                                    </Tooltip>
                                    <Tooltip content="Delete">
                                      <button
                                        type="button"
                                        onClick={() =>
                                          form.handleDeleteComponent(comp)
                                        }
                                        className="p-1 rounded hover:bg-red-50 text-red-600"
                                      >
                                        <Trash2 className="h-3.5 w-3.5" />
                                      </button>
                                    </Tooltip>
                                  </div>
                                </td>
                              </tr>
                              {isExpanded &&
                                children.map((child) => {
                                  const childItem =
                                    form.catalogItems.find(
                                      (i) => i.id === child.component_item_id
                                    ) || child.catalog_item;
                                  const childSku =
                                    childItem?.sku || '—';
                                  const childName =
                                    childItem?.name ||
                                    (childItem as any)?.item_name ||
                                    '—';
                                  return (
                                    <tr
                                      key={child.id}
                                      className="border-t border-gray-50 bg-blue-50/30"
                                    >
                                      <td className="px-1 py-1.5" />
                                      <td className="px-3 py-1.5 pl-8">
                                        <span className="text-gray-400 mr-1.5">↳</span>
                                        <span className="font-mono text-gray-600">
                                          {childSku}
                                        </span>
                                        <span className="text-gray-400 ml-1">
                                          {childName}
                                        </span>
                                      </td>
                                      <td className="px-3 py-1.5 text-gray-500">
                                        {child.qty_value ?? 1}
                                      </td>
                                      <td className="px-3 py-1.5 text-gray-500">
                                        {child.uom || 'ea'}
                                      </td>
                                      <td className="px-3 py-1.5 text-gray-500">
                                        {getRoleLabel(child.component_role)}
                                      </td>
                                      <td className="px-3 py-1.5" />
                                      <td className="px-3 py-1.5" />
                                      <td className="px-3 py-1.5 text-gray-500">
                                        {child.sort_order ?? 0}
                                      </td>
                                      <td className="px-3 py-1.5 text-gray-500">
                                        {child.is_required !== false
                                          ? 'Yes'
                                          : 'No'}
                                      </td>
                                      <td className="px-3 py-1.5" />
                                    </tr>
                                  );
                                })}
                            </React.Fragment>
                          );
                        })}
                      </React.Fragment>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          {/* Footer */}
          <div className="flex justify-end gap-2 px-6 py-4 border-t border-gray-200 shrink-0">
            <button
              type="button"
              onClick={handleRequestClose}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleSaveClick}
              disabled={
                form.isSaving || form.displayComponents.length === 0
              }
              className="px-4 py-2 text-sm font-medium text-white bg-primary rounded hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {form.isSaving ? 'Saving…' : 'Save'}
            </button>
          </div>
        </div>
      </div>

      {/* Sub-modals */}
      <BOMEngineeringModal
        showEngineeringModal={form.showEngineeringModal}
        engineeringData={form.engineeringData}
        setEngineeringData={form.setEngineeringData}
        onSave={form.handleSaveEngineeringRules}
        onClose={form.handleCloseEngineeringModal}
      />
      <BOMChildrenModal
        showChildrenModal={form.showChildrenModal}
        editingParentComponentId={form.editingParentComponentId}
        childComponents={form.childComponents}
        setChildComponents={form.setChildComponents}
        showAddChildForm={form.showAddChildForm}
        setShowAddChildForm={form.setShowAddChildForm}
        editingChildId={form.editingChildId}
        setEditingChildId={form.setEditingChildId}
        childFormData={form.childFormData}
        setChildFormData={form.setChildFormData}
        childSearchTerm={form.childSearchTerm}
        setChildSearchTerm={form.setChildSearchTerm}
        showChildDropdown={form.showChildDropdown}
        setShowChildDropdown={form.setShowChildDropdown}
        catalogItems={form.catalogItems}
        categories={form.categories}
        parentComponentRole={form.editingParentComponentRole}
        onClose={form.handleCloseChildrenModal}
        onAddChild={form.handleAddChild}
        onDeleteChild={form.handleDeleteChild}
      />
    </TooltipProvider>
  );
}
