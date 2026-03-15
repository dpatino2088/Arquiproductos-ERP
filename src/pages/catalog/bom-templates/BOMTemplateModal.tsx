import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Plus, Edit, Trash2, Search, Wrench, Ruler, Package, X, ChevronRight, ChevronDown, ExternalLink } from 'lucide-react';
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
import { useManufacturers } from '../../../hooks/useCatalog';
import { BOM_QTY_TYPES, CONDITION_KEY_OPTIONS, CONDITION_VALUE_OPTIONS, getCascadeLabel, getCascadeOrder } from './types';
import { useBOMTemplateForm } from './useBOMTemplateForm';
import BOMChildrenModal from './BOMChildrenModal';
import type { BOMComponentDraft } from './types';

const HARDWARE_COLORS = ['White', 'Black', 'Silver', 'Bronze', 'Grey'] as const;
const PRODUCT_LINE_OPTIONS = [
  { value: 'wave_drapery', label: 'Wave Drapery' },
  { value: 'ripple_fold', label: 'Ripple Fold' },
  { value: 'pinch_pleat', label: 'Pinch Pleat' },
] as const;
const SYSTEM_SIZE_OPTIONS_DRAPERY = [
  { value: '48mm', label: '48 mm' },
  { value: '54mm', label: '54 mm' },
  { value: '60mm', label: '60 mm' },
  { value: '80mm', label: '80 mm' },
] as const;
const SYSTEM_SIZE_OPTIONS_ROLLER = [
  { value: 'XS', label: 'XS' },
  { value: 'S',  label: 'S'  },
  { value: 'M',  label: 'M'  },
  { value: 'L',  label: 'L'  },
  { value: 'XL', label: 'XL' },
] as const;

const QTY_TYPE_LABELS: Record<string, string> = {
  fixed: 'Fixed',
  per_width: 'Per Width',
  per_height: 'Per Height',
  per_spacing: 'Per Spacing',
  per_joint: 'Per Joint',
};

export interface BOMTemplateModalProps {
  isOpen: boolean;
  editingTemplateId: string | null;
  onClose: () => void;
  onSave: () => void;
  onGoToEngineering?: (templateId: string) => void;
}

export default function BOMTemplateModal({
  isOpen,
  editingTemplateId,
  onClose,
  onSave,
  onGoToEngineering,
}: BOMTemplateModalProps) {
  const form = useBOMTemplateForm(editingTemplateId);
  const { manufacturers } = useManufacturers();
  const autocompleteRef = useRef<HTMLDivElement>(null);
  const [expandedRows, setExpandedRows] = useState<Set<string>>(new Set());
  const [codeManuallyEdited, setCodeManuallyEdited] = useState(() => !!editingTemplateId);

  const selectedPt = form.productTypes.find((pt: any) => pt.id === form.productTypeId);
  const isDrapery = !!(selectedPt && (selectedPt.code === 'drapery' || selectedPt.name?.toLowerCase().includes('drapery')));
  // Drapery templates no longer use system_size at the template level.
  // Glider size is handled via condition_key/condition_value on BOMComponents.
  const needsSystemSize = false;

  const autoCode = React.useMemo(() => {
    const parts: string[] = [];
    const ptName = selectedPt?.code?.toUpperCase() || selectedPt?.name?.toUpperCase().replace(/\s+/g, '_') || '';
    if (ptName) parts.push(ptName);
    if (isDrapery && form.templateProductLine) {
      parts.push(form.templateProductLine.toUpperCase());
    }
    if (form.templateOpeningDirection && form.templateOpeningDirection !== 'all') {
      parts.push(form.templateOpeningDirection.toUpperCase());
    }
    if (form.templateDriveType) parts.push(form.templateDriveType.toUpperCase());
    if (form.templateHardwareColor) parts.push(form.templateHardwareColor.toUpperCase().replace(/\s+/g, '_'));
    if (form.templateDriveSide && form.templateDriveSide !== 'both') {
      parts.push(form.templateDriveSide.toUpperCase());
    }
    if (form.templateInstallationLocation && form.templateInstallationLocation !== 'both') {
      parts.push(form.templateInstallationLocation.toUpperCase());
    }
    if (form.templateManufacturer) {
      const abbr = form.templateManufacturer.substring(0, 3).toUpperCase();
      parts.push(abbr.length >= 2 ? abbr : form.templateManufacturer.toUpperCase());
    }
    if (form.templateSystemSize) {
      parts.push(form.templateSystemSize.toUpperCase().replace(/\s+/g, '_'));
    }
    if (form.templateHeadbox) parts.push('HB');
    return parts.join('_') || '';
  }, [selectedPt, isDrapery, form.templateProductLine, form.templateOpeningDirection, form.templateDriveType, form.templateHardwareColor, form.templateDriveSide, form.templateInstallationLocation, form.templateManufacturer, form.templateSystemSize, form.templateHeadbox]);

  useEffect(() => {
    if (!codeManuallyEdited && autoCode) {
      form.setTemplateCode(autoCode);
      form.setTemplateName(autoCode);
    }
  }, [autoCode, codeManuallyEdited]);

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
    const pp = comp.per_panel ? ' ⧫PP' : '';
    if (comp.qty_type === 'fixed') return `${comp.qty_value ?? '—'}${pp}`;
    if (comp.qty_type === 'per_spacing') {
      const sp = comp.qty_spacing_mm ?? 500;
      const min = comp.qty_min;
      return `Every ${sp}mm${min != null ? ` (min ${min})` : ''}${pp}`;
    }
    if (comp.qty_type === 'per_joint') {
      return `Per Joint ×${comp.qty_value ?? 1}`;
    }
    const label = QTY_TYPE_LABELS[comp.qty_type || 'fixed'] || comp.qty_type || '—';
    const mult = comp.qty_value != null && comp.qty_value !== 1 ? ` x${comp.qty_value}` : '';
    return `${label}${mult}${pp}`;
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
          <div className="flex-1 overflow-y-auto px-6 py-4 space-y-5">

            {/* ── ROW 1: Product Type + Manufacturer ── */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label required>Product Type</Label>
                <SelectShadcn value={form.productTypeId} onValueChange={form.setProductTypeId}>
                  <SelectTrigger><SelectValue placeholder="Select product type" /></SelectTrigger>
                  <SelectContent>
                    {form.productTypes.map((pt) => (
                      <SelectItem key={pt.id} value={pt.id}>{pt.name || pt.code || pt.id}</SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
              </div>
              <div>
                <Label required>Manufacturer</Label>
                <SelectShadcn value={form.templateManufacturer || ''} onValueChange={(v) => form.setTemplateManufacturer(v || null)}>
                  <SelectTrigger><SelectValue placeholder="Select manufacturer" /></SelectTrigger>
                  <SelectContent>
                    {manufacturers.map((m) => (
                      <SelectItem key={m.id} value={m.name}>{m.name}</SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
              </div>
            </div>

            {/* ── ROW 2: Product Line + System Size (Drapery only) ── */}
            {isDrapery && (
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label required>Product Line</Label>
                  <SelectShadcn
                    value={form.templateProductLine || ''}
                    onValueChange={(v) => {
                      form.setTemplateProductLine(v || null);
                      if (v === 'pinch_pleat') form.setTemplateSystemSize(null);
                    }}
                  >
                    <SelectTrigger><SelectValue placeholder="Select product line" /></SelectTrigger>
                    <SelectContent>
                      {PRODUCT_LINE_OPTIONS.map((opt) => (
                        <SelectItem key={opt.value} value={opt.value}>{opt.label}</SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                </div>
                {needsSystemSize ? (
                  <div>
                    <Label>System Size</Label>
                    <SelectShadcn value={form.templateSystemSize || ''} onValueChange={(v) => form.setTemplateSystemSize(v || null)}>
                      <SelectTrigger><SelectValue placeholder="Select system size" /></SelectTrigger>
                      <SelectContent>
                        {SYSTEM_SIZE_OPTIONS_DRAPERY.map((opt) => (
                          <SelectItem key={opt.value} value={opt.value}>{opt.label}</SelectItem>
                        ))}
                      </SelectContent>
                    </SelectShadcn>
                  </div>
                ) : (
                  <div />
                )}
              </div>
            )}

            {/* ── ROW 3: Hardware Color + Drive Type ── */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label required>Hardware Color</Label>
                <SelectShadcn value={form.templateHardwareColor} onValueChange={form.setTemplateHardwareColor}>
                  <SelectTrigger><SelectValue placeholder="Select color" /></SelectTrigger>
                  <SelectContent>
                    {HARDWARE_COLORS.map((c) => (
                      <SelectItem key={c} value={c}>{c}</SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
              </div>
              <div>
                <Label required>Drive Type</Label>
                <SelectShadcn value={form.templateDriveType ?? ''} onValueChange={(v) => form.setTemplateDriveType(v as 'manual' | 'motor')}>
                  <SelectTrigger><SelectValue placeholder="Select drive type" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="manual">Manual</SelectItem>
                    <SelectItem value="motor">Motor</SelectItem>
                  </SelectContent>
                </SelectShadcn>
              </div>
            </div>

            {/* ── ROW 4: Opening Direction + Drive Side ── */}
            {(() => {
              const hasDriveType = !!form.templateDriveType;
              return (
                <div className={`grid gap-4 ${isDrapery ? 'grid-cols-3' : 'grid-cols-2'}`}>
                  {isDrapery && (
                    <div>
                      <Label required>Opening Direction</Label>
                      {!hasDriveType ? (
                        <p className="mt-1.5 text-xs text-gray-400 italic">Select drive type first</p>
                      ) : (
                        <SelectShadcn
                          value={form.templateOpeningDirection ?? ''}
                          onValueChange={(v) => {
                            const val = v as 'left' | 'center' | 'right' | 'all';
                            form.setTemplateOpeningDirection(val);
                            if (val === 'left') form.setTemplateDriveSide('left');
                            else if (val === 'right') form.setTemplateDriveSide('right');
                            else form.setTemplateDriveSide('both');
                          }}
                        >
                          <SelectTrigger><SelectValue placeholder="Select direction" /></SelectTrigger>
                          <SelectContent>
                            <SelectItem value="left">Left</SelectItem>
                            <SelectItem value="center">Center</SelectItem>
                            <SelectItem value="right">Right</SelectItem>
                            <SelectItem value="all">Left and Right</SelectItem>
                          </SelectContent>
                        </SelectShadcn>
                      )}
                    </div>
                  )}
                  <div>
                    <Label required>Drive Side</Label>
                    {!hasDriveType ? (
                      <p className="mt-1.5 text-xs text-gray-400 italic">Select drive type first</p>
                    ) : (
                      <SelectShadcn value={form.templateDriveSide ?? ''} onValueChange={(v) => form.setTemplateDriveSide(v as 'left' | 'right' | 'both')}>
                        <SelectTrigger><SelectValue placeholder="Select side" /></SelectTrigger>
                        <SelectContent>
                          <SelectItem value="left">Left</SelectItem>
                          <SelectItem value="right">Right</SelectItem>
                          <SelectItem value="both">Both (any)</SelectItem>
                        </SelectContent>
                      </SelectShadcn>
                    )}
                  </div>
                  {!isDrapery && <div />}
                </div>
              );
            })()}

            {/* ── ROW 5: System Size (non-drapery) + Installation ── */}
            <div className="grid grid-cols-2 gap-4">
              {!isDrapery && (
                <div>
                  <Label>System Size</Label>
                  <SelectShadcn
                    value={form.templateSystemSize || 'any'}
                    onValueChange={(v) => form.setTemplateSystemSize(v === 'any' ? null : v)}
                  >
                    <SelectTrigger><SelectValue placeholder="Any size" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="any">Any size</SelectItem>
                      {SYSTEM_SIZE_OPTIONS_ROLLER.map((opt) => (
                        <SelectItem key={opt.value} value={opt.value}>{opt.label}</SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                </div>
              )}
              <div>
                <Label>Installation</Label>
                <SelectShadcn
                  value={form.templateInstallationLocation ?? 'any'}
                  onValueChange={(v) => form.setTemplateInstallationLocation(v === 'any' ? null : v as 'ceiling' | 'wall')}
                >
                  <SelectTrigger><SelectValue placeholder="Both (any)" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="any">Both (any)</SelectItem>
                    <SelectItem value="ceiling">Ceiling</SelectItem>
                    <SelectItem value="wall">Wall</SelectItem>
                  </SelectContent>
                </SelectShadcn>
              </div>
              {isDrapery && <div />}
            </div>

            {/* ── ROW 6: Headbox toggle — only for roller / dual-shade / triple ── */}
            {['roller', 'dual-shade', 'triple'].includes(selectedPt?.code ?? '') && (
              <div className="flex items-center gap-3 py-1">
                <label className="flex items-center gap-2.5 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={form.templateHeadbox}
                    onChange={(e) => form.setTemplateHeadbox(e.target.checked)}
                    className="w-4 h-4 text-primary border-gray-300 rounded focus:ring-primary"
                  />
                  <span className="text-sm font-medium text-gray-900">Includes Headbox / Cassette</span>
                </label>
                <p className="text-xs text-gray-400">
                  {form.templateHeadbox ? 'This template requires a headbox. Code will include _HB.' : 'No headbox — template matches products without cassette.'}
                </p>
              </div>
            )}

            {/* ── ROW 7: Auto-generated Code + Name + Description ── */}
            <div className="border-t border-gray-200 pt-4 space-y-3">
              <div>
                <div className="flex items-center justify-between mb-1">
                  <Label htmlFor="template-code">Code *</Label>
                  {!codeManuallyEdited && autoCode && (
                    <span className="text-[10px] text-green-600 font-medium">Auto-generated</span>
                  )}
                </div>
                <Input
                  id="template-code"
                  value={form.templateCode}
                  onChange={(e) => {
                    setCodeManuallyEdited(true);
                    form.setTemplateCode(e.target.value);
                  }}
                  placeholder="TEMPLATE_CODE"
                  className="font-mono text-xs"
                />
                {codeManuallyEdited && autoCode && (
                  <button
                    type="button"
                    onClick={() => { setCodeManuallyEdited(false); form.setTemplateCode(autoCode); form.setTemplateName(autoCode); }}
                    className="text-[10px] text-primary hover:underline mt-0.5"
                  >
                    Reset to auto-generated
                  </button>
                )}
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label htmlFor="template-name">Name *</Label>
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
                    placeholder="Optional description"
                  />
                </div>
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
                              : (v === 'per_spacing' || v === 'per_joint') ? null
                              : (prev.qty_value ?? 1),
                            qty_spacing_mm:
                              v === 'per_spacing' ? (prev.qty_spacing_mm ?? 500)
                              : v === 'per_joint' ? (prev.qty_spacing_mm ?? 4000)
                              : null,
                            qty_min: (v === 'per_spacing' || v === 'per_joint') ? prev.qty_min : null,
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
                          min={form.formData.qty_type === 'fixed' ? 1 : 0.01}
                          step={form.formData.qty_type === 'fixed' ? 1 : 0.01}
                          value={form.formData.qty_value ?? ''}
                          onChange={(e) => {
                            const v = e.target.value;
                            const isFixed = form.formData.qty_type === 'fixed';
                            const n = v === '' ? null : isFixed ? parseInt(v, 10) : parseFloat(v);
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
                  {(form.formData.qty_type === 'per_width' || form.formData.qty_type === 'per_height') && (
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
                  {(form.formData.qty_type === 'per_spacing' || form.formData.qty_type === 'per_joint') && (
                    <div className="grid grid-cols-3 gap-4">
                      <div>
                        <Label>{form.formData.qty_type === 'per_joint' ? 'Max Segment (mm)' : 'Spacing (mm)'}</Label>
                        <Input
                          type="number"
                          min={1}
                          step={1}
                          value={form.formData.qty_spacing_mm ?? (form.formData.qty_type === 'per_joint' ? 4000 : 500)}
                          onChange={(e) => {
                            const n = parseInt(e.target.value, 10) || (form.formData.qty_type === 'per_joint' ? 4000 : 500);
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
                    <div className="flex items-center gap-2">
                      <input
                        type="checkbox"
                        id="per-panel"
                        checked={form.formData.per_panel ?? false}
                        onChange={(e) =>
                          form.setFormData((prev) => ({
                            ...prev,
                            per_panel: e.target.checked,
                          }))
                        }
                        className="rounded border-gray-300"
                      />
                      <Label htmlFor="per-panel" className="mb-0">
                        Per Panel
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
                  {/* Condition (optional) */}
                  <div className="flex items-end gap-2">
                    <div className="flex-1">
                      <Label>Condition</Label>
                      <select
                        value={form.formData.condition_key || ''}
                        onChange={(e) => form.setFormData((prev) => ({ ...prev, condition_key: e.target.value, condition_value: e.target.value ? prev.condition_value : '' }))}
                        className="w-full rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm"
                      >
                        {CONDITION_KEY_OPTIONS.map((o) => (
                          <option key={o.value} value={o.value}>{o.label}</option>
                        ))}
                      </select>
                    </div>
                    {form.formData.condition_key ? (
                      <div className="w-40">
                        <Label>Value</Label>
                        {CONDITION_VALUE_OPTIONS[form.formData.condition_key] ? (
                          <select
                            value={form.formData.condition_value || ''}
                            onChange={(e) => form.setFormData((prev) => ({ ...prev, condition_value: e.target.value }))}
                            className="w-full rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm"
                          >
                            <option value="">— Select —</option>
                            {CONDITION_VALUE_OPTIONS[form.formData.condition_key].map((o) => (
                              <option key={o.value} value={o.value}>{o.label}</option>
                            ))}
                          </select>
                        ) : (
                          <Input
                            value={form.formData.condition_value || ''}
                            onChange={(e) => form.setFormData((prev) => ({ ...prev, condition_value: e.target.value }))}
                            placeholder="Value"
                            className="text-sm"
                          />
                        )}
                      </div>
                    ) : null}
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
                      <th className="text-center px-2 py-2 font-medium">ΔX</th>
                      <th className="text-center px-2 py-2 font-medium">ΔY</th>
                      <th className="text-left px-3 py-2 font-medium">Role</th>
                      <th className="text-left px-3 py-2 font-medium">Depends On</th>
                      <th className="text-left px-3 py-2 font-medium">
                        Children
                      </th>
                      <th className="text-left px-3 py-2 font-medium">Eng.</th>
                      <th className="text-left px-3 py-2 font-medium">Req.</th>
                      <th className="text-left px-3 py-2 font-medium">Condition</th>
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
                            colSpan={13}
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
                                <td className="px-2 py-2 text-center">
                                  {comp.uom === 'ea' ? (
                                    comp.catalog_item?.delta_x_mm != null ? (
                                      <span className="text-xs text-gray-700">{comp.catalog_item.delta_x_mm}</span>
                                    ) : (
                                      <a href={`/catalog/items/edit/${comp.component_item_id}`} target="_blank" rel="noopener noreferrer" className="text-xs text-amber-500 hover:text-amber-700" title="Set in catalog">
                                        <ExternalLink className="h-3 w-3 inline" />
                                      </a>
                                    )
                                  ) : <span className="text-xs text-gray-300">—</span>}
                                </td>
                                <td className="px-2 py-2 text-center">
                                  {comp.uom === 'ea' ? (
                                    comp.catalog_item?.delta_y_mm != null ? (
                                      <span className="text-xs text-gray-700">{comp.catalog_item.delta_y_mm}</span>
                                    ) : (
                                      <a href={`/catalog/items/edit/${comp.component_item_id}`} target="_blank" rel="noopener noreferrer" className="text-xs text-amber-500 hover:text-amber-700" title="Set in catalog">
                                        <ExternalLink className="h-3 w-3 inline" />
                                      </a>
                                    )
                                  ) : <span className="text-xs text-gray-300">—</span>}
                                </td>
                                <td className="px-3 py-2">
                                  <span className="text-gray-700">{getRoleLabel(comp.component_role)}</span>
                                  {getCascadeLabel(comp.component_role) && (
                                    <span className="ml-1.5 text-[10px] text-gray-400">{getCascadeLabel(comp.component_role)?.split(' ')[0]}</span>
                                  )}
                                </td>
                                <td className="px-3 py-2">
                                  {comp.depends_on_role ? (
                                    <span className="inline-flex items-center gap-0.5 text-[10px] px-1.5 py-0.5 bg-blue-50 text-blue-700 rounded font-mono">
                                      ← {getRoleLabel(comp.depends_on_role)}
                                    </span>
                                  ) : comp.uom === 'm' || comp.uom === 'm2' ? (
                                    <span className="text-[10px] text-gray-400">base</span>
                                  ) : (
                                    <span className="text-gray-300">—</span>
                                  )}
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
                                  {comp.is_required !== false ? (
                                    <span className="text-primary font-medium">
                                      Yes
                                    </span>
                                  ) : (
                                    'No'
                                  )}
                                </td>
                                <td className="px-3 py-2 text-xs text-gray-500">
                                  {comp.condition_key ? (
                                    <span>{comp.condition_key} = {comp.condition_value || '—'}</span>
                                  ) : '—'}
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
                                    {editingTemplateId && onGoToEngineering && (
                                      <Tooltip content="Go to Engineering">
                                        <button
                                          type="button"
                                          onClick={() => onGoToEngineering(editingTemplateId)}
                                          className="p-1 rounded hover:bg-gray-200 text-gray-600"
                                        >
                                          <Ruler className="h-3.5 w-3.5" />
                                        </button>
                                      </Tooltip>
                                    )}
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
                                        {getQtyDisplay(child)}
                                      </td>
                                      <td className="px-3 py-1.5 text-gray-500">
                                        {child.uom || 'ea'}
                                      </td>
                                      <td className="px-2 py-1.5 text-center text-gray-300">—</td>
                                      <td className="px-2 py-1.5 text-center text-gray-300">—</td>
                                      <td className="px-3 py-1.5 text-gray-500">
                                        {getRoleLabel(child.component_role)}
                                      </td>
                                      <td className="px-3 py-1.5 text-gray-300">—</td>
                                      <td className="px-3 py-1.5" />
                                      <td className="px-3 py-1.5" />
                                      <td className="px-3 py-1.5 text-gray-500">
                                        {child.is_required !== false
                                          ? 'Yes'
                                          : 'No'}
                                      </td>
                                      <td className="px-3 py-1.5 text-xs text-gray-400">
                                        {child.condition_key ? `${child.condition_key} = ${child.condition_value || '—'}` : '—'}
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
              className="relative px-4 py-2 text-sm font-medium text-white bg-primary rounded hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {form.isSaving ? 'Saving…' : 'Save'}
              {form.childrenHavePendingChanges && !form.isSaving && (
                <span
                  className="absolute -top-1 -right-1 w-2.5 h-2.5 rounded-full bg-amber-400 border border-white"
                  title="Children have unsaved changes"
                />
              )}
            </button>
          </div>
        </div>
      </div>

      {/* Sub-modals */}
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
        hasPendingChanges={form.childrenHavePendingChanges}
        onClose={form.handleCloseChildrenModal}
        onAddChild={form.handleAddChild}
        onDeleteChild={form.handleDeleteChild}
      />
    </TooltipProvider>
  );
}
