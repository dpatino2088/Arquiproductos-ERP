import { useState, useMemo, useCallback } from 'react';
import { Plus, Trash2, Edit, ChevronDown, ChevronRight, Save } from 'lucide-react';
import { useFabricRules, FabricRule, SystemRule } from '../../hooks/useFabricRules';
import { useProductTypes } from '../../hooks/useProductTypes';
import Label from '../../components/ui/Label';
import Input from '../../components/ui/Input';

const ORIENTATIONS = ['vertical', 'railroaded'] as const;
const WIDTH_SOURCES = ['tube_width', 'bottom_bar_width', 'track_width', 'finished_width_x_fullness', 'finished_width'] as const;
const WIDTH_SOURCE_LABELS: Record<string, string> = {
  tube_width: 'Tube Width (from BOM)',
  bottom_bar_width: 'Bottom Bar Width (from BOM)',
  track_width: 'Track Width (from BOM)',
  finished_width_x_fullness: 'Finished Width x Fullness',
  finished_width: 'Finished Width',
};

const MECHANICAL_SOURCES = new Set(['tube_width', 'bottom_bar_width', 'track_width']);
const isMechanical = (s: string | undefined) => MECHANICAL_SOURCES.has(s || '');
const isDrapery = (s: string | undefined) => s === 'finished_width_x_fullness';

function deriveFromSource(src: string): { formula_code: string; pricing_output_uom: string } {
  if (MECHANICAL_SOURCES.has(src)) return { formula_code: 'ROLLER_DROPS', pricing_output_uom: 'm' };
  if (src === 'finished_width_x_fullness') return { formula_code: 'DRAPERY_PANELS', pricing_output_uom: 'm2' };
  return { formula_code: 'AREA_BASED', pricing_output_uom: 'm2' };
}

const FORMULA_LABELS: Record<string, string> = {
  ROLLER_DROPS: 'Linear (drops)',
  AREA_BASED: 'Area (m\u00B2)',
  DRAPERY_PANELS: 'Panels (fullness)',
};

function inferDefaults(ptName: string): Partial<FabricRule> {
  const n = ptName.toLowerCase();
  if (n.includes('dual'))
    return { fabric_width_source: 'tube_width', formula_code: 'ROLLER_DROPS', pricing_output_uom: 'm', panel_multiplier: 2, tube_wrap_mm: 35, bottom_wrap_mm: 0, safety_margin_mm: 20, waste_pct: 0.15, heatseal_price_per_m: 0, bottom_bar_wrap_pct: 0.08 };
  if (n.includes('triple'))
    return { fabric_width_source: 'tube_width', formula_code: 'ROLLER_DROPS', pricing_output_uom: 'm', panel_multiplier: 3, tube_wrap_mm: 35, bottom_wrap_mm: 0, safety_margin_mm: 20, waste_pct: 0.15, heatseal_price_per_m: 0, bottom_bar_wrap_pct: 0.08 };
  if (n.includes('roller') || n.includes('zip'))
    return { fabric_width_source: 'tube_width', formula_code: 'ROLLER_DROPS', pricing_output_uom: 'm', panel_multiplier: 1, tube_wrap_mm: 35, bottom_wrap_mm: 50, safety_margin_mm: 20, waste_pct: 0.15, heatseal_price_per_m: 5, bottom_bar_wrap_pct: 0.08 };
  if (n.includes('drapery') || n.includes('curtain') || n.includes('wave') || n.includes('ripple') || n.includes('pinch'))
    return { fabric_width_source: 'finished_width_x_fullness', formula_code: 'DRAPERY_PANELS', pricing_output_uom: 'm2', fullness_factor: 2.0, waste_pct: 0.10 };
  return { fabric_width_source: 'finished_width', formula_code: 'AREA_BASED', pricing_output_uom: 'm2', waste_pct: 0.15 };
}

function getEmptyRule(productTypeId: string, ptName: string): Partial<FabricRule> {
  const defaults = inferDefaults(ptName);
  return {
    product_type_id: productTypeId,
    style_code: null,
    display_name: null,
    image_url: null,
    product_line: null,
    formula_code: defaults.formula_code ?? 'ROLLER_DROPS',
    height_multiplier: 1,
    width_multiplier: 1,
    fullness_factor: defaults.fullness_factor ?? 1,
    extra_height_m: 0,
    extra_width_m: 0,
    pricing_output_uom: defaults.pricing_output_uom ?? 'm',
    waste_pct: defaults.waste_pct ?? 0.15,
    round_to_increment: 0.1,
    min_qty: 0,
    top_hem_cm: 0,
    bottom_hem_cm: 0,
    side_hem_cm: 0,
    fabric_orientation: 'vertical',
    fabric_width_source: defaults.fabric_width_source ?? 'finished_width',
    tube_wrap_mm: defaults.tube_wrap_mm ?? 0,
    bottom_wrap_mm: defaults.bottom_wrap_mm ?? 0,
    safety_margin_mm: defaults.safety_margin_mm ?? 0,
    panel_multiplier: defaults.panel_multiplier ?? 1,
    heatseal_price_per_m: defaults.heatseal_price_per_m ?? 0,
    bottom_bar_wrap_pct: defaults.bottom_bar_wrap_pct ?? 0,
    confection_pct: 0,
    is_active: true,
  };
}

export default function FabricRulesSettings() {
  const { rules, systemRules, loading, error, createRule, updateRule, deleteRule, createSystemRule, updateSystemRule, deleteSystemRule } = useFabricRules();
  const { productTypes } = useProductTypes();
  const [expandedTypes, setExpandedTypes] = useState<Set<string>>(new Set());
  const [editingRuleId, setEditingRuleId] = useState<string | null>(null);
  const [editDraft, setEditDraft] = useState<Partial<FabricRule>>({});
  const [addingForType, setAddingForType] = useState<string | null>(null);
  const [newDraft, setNewDraft] = useState<Partial<FabricRule>>({});
  const [expandedSystemRules, setExpandedSystemRules] = useState<Set<string>>(new Set());
  const [newSysKey, setNewSysKey] = useState('');
  const [newSysValue, setNewSysValue] = useState('');
  const [addingSysRuleForId, setAddingSysRuleForId] = useState<string | null>(null);

  const rulesByProductType = useMemo(() => {
    const map = new Map<string, FabricRule[]>();
    rules.forEach(r => {
      const list = map.get(r.product_type_id) || [];
      list.push(r);
      map.set(r.product_type_id, list);
    });
    return map;
  }, [rules]);

  const systemRulesByFabricRule = useMemo(() => {
    const map = new Map<string, SystemRule[]>();
    systemRules.forEach(sr => {
      const key = `${sr.product_type_id}:${sr.style_code || ''}`;
      const list = map.get(key) || [];
      list.push(sr);
      map.set(key, list);
    });
    return map;
  }, [systemRules]);

  const toggleType = useCallback((ptId: string) => {
    setExpandedTypes(prev => {
      const next = new Set(prev);
      if (next.has(ptId)) next.delete(ptId); else next.add(ptId);
      return next;
    });
  }, []);

  const toggleSystemRules = useCallback((ruleId: string) => {
    setExpandedSystemRules(prev => {
      const next = new Set(prev);
      if (next.has(ruleId)) next.delete(ruleId); else next.add(ruleId);
      return next;
    });
  }, []);

  const handleSaveEdit = useCallback(async () => {
    if (!editingRuleId) return;
    await updateRule(editingRuleId, editDraft);
    setEditingRuleId(null);
    setEditDraft({});
  }, [editingRuleId, editDraft, updateRule]);

  const handleSaveNew = useCallback(async () => {
    if (!addingForType) return;
    await createRule({ ...newDraft, product_type_id: addingForType });
    setAddingForType(null);
    setNewDraft({});
  }, [addingForType, newDraft, createRule]);

  const handleAddSystemRule = useCallback(async (fabricRule: FabricRule) => {
    if (!newSysKey.trim() || !newSysValue.trim()) return;
    await createSystemRule({
      product_type_id: fabricRule.product_type_id,
      style_code: fabricRule.style_code,
      rule_key: newSysKey.trim(),
      rule_value: parseFloat(newSysValue) || 0,
      is_active: true,
    });
    setNewSysKey('');
    setNewSysValue('');
    setAddingSysRuleForId(null);
  }, [newSysKey, newSysValue, createSystemRule]);

  const getProductTypeName = (ptId: string) => {
    const pt = productTypes.find(p => p.id === ptId);
    return pt?.name || pt?.code || ptId;
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-16">
        <div className="animate-spin h-6 w-6 border-2 border-gray-300 border-t-gray-600 rounded-full" />
      </div>
    );
  }

  const allProductTypeIds = Array.from(new Set([
    ...productTypes.map(pt => pt.id),
    ...Array.from(rulesByProductType.keys()),
  ]));

  const selectCls = "w-full text-xs border border-gray-300 rounded px-2 py-1.5 bg-white";

  const FABRIC_GROUP_OPTIONS = [
    { value: 'wave', label: 'Wave (Wave Drapery & Ripple Fold)' },
    { value: 'pinch_pleat', label: 'Pinch Pleat' },
  ] as const;

  const isProductTypeDrapery = (name: string) => {
    const n = name.toLowerCase();
    return n.includes('drapery') || n.includes('curtain') || n.includes('wave') || n.includes('ripple') || n.includes('pinch');
  };

  const isProductTypeMechanical = (name: string) => {
    const n = name.toLowerCase();
    return n.includes('roller') || n.includes('dual') || n.includes('triple') || n.includes('zip');
  };

  const renderRuleForm = (draft: Partial<FabricRule>, setDraft: (v: Partial<FabricRule>) => void, ptName: string) => {
    const src = draft.fabric_width_source || 'finished_width';
    const derived = deriveFromSource(src);
    const mechanical = isMechanical(src);
    const drapery = isDrapery(src);
    const wasteDisplay = ((draft.waste_pct ?? 0.15) * 100).toFixed(0);
    const ptIsDrapery = isProductTypeDrapery(ptName);
    const ptIsMechanical = isProductTypeMechanical(ptName);

    const handleSourceChange = (newSource: string) => {
      const d = deriveFromSource(newSource);
      setDraft({ ...draft, fabric_width_source: newSource, formula_code: d.formula_code, pricing_output_uom: d.pricing_output_uom });
    };

    return (
      <div className="space-y-4 p-4 bg-gray-50 border border-gray-200 rounded">
        {/* ── Drapery: Variant identification FIRST (required) ── */}
        {ptIsDrapery && (
          <div className="rounded border border-purple-100 bg-purple-50/40 p-3">
            <div className="text-[11px] font-medium text-purple-600 mb-2">Style Variant</div>
            <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
              <div>
                <Label className="text-xs">Style Code <span className="text-red-400">*</span></Label>
                <Input value={draft.style_code || ''} onChange={e => setDraft({ ...draft, style_code: e.target.value || null })} placeholder="e.g. wave_2.3" className="text-xs" />
              </div>
              <div>
                <Label className="text-xs">Display Name <span className="text-red-400">*</span></Label>
                <Input value={draft.display_name || ''} onChange={e => setDraft({ ...draft, display_name: e.target.value || null })} placeholder="e.g. Wave 2.3" className="text-xs" />
              </div>
              <div>
                <Label className="text-xs">Fabric Group <span className="text-red-400">*</span></Label>
                <select
                  value={(draft as any).fabric_group || ''}
                  onChange={e => setDraft({ ...draft, fabric_group: e.target.value || null } as any)}
                  className={selectCls}
                >
                  <option value="">Select fabric group</option>
                  {FABRIC_GROUP_OPTIONS.map(o => (
                    <option key={o.value} value={o.value}>{o.label}</option>
                  ))}
                </select>
              </div>
            </div>
          </div>
        )}

        {/* ── Row 1: Main config ── */}
        <div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div className="md:col-span-2">
              <Label className="text-xs">Fabric Width Source</Label>
              <select value={src} onChange={e => handleSourceChange(e.target.value)} className={selectCls}>
                {WIDTH_SOURCES.map(s => <option key={s} value={s}>{WIDTH_SOURCE_LABELS[s] || s}</option>)}
              </select>
            </div>
            <div>
              <Label className="text-xs">Orientation</Label>
              <select value={draft.fabric_orientation || 'vertical'} onChange={e => setDraft({ ...draft, fabric_orientation: e.target.value })} className={selectCls}>
                {ORIENTATIONS.map(o => <option key={o} value={o}>{o}</option>)}
              </select>
            </div>
            <div className="flex items-center gap-3 pt-5">
              <span className="text-[10px] font-medium text-gray-400 bg-gray-100 rounded px-2 py-1">{FORMULA_LABELS[derived.formula_code] || derived.formula_code}</span>
              <span className="text-[10px] font-medium text-gray-400 bg-gray-100 rounded px-2 py-1">UOM: {derived.pricing_output_uom}</span>
              <label className="flex items-center gap-1.5 text-xs ml-auto">
                <input type="checkbox" checked={draft.is_active !== false} onChange={e => setDraft({ ...draft, is_active: e.target.checked })} className="rounded border-gray-300" />
                Active
              </label>
            </div>
          </div>
        </div>

        {/* ── Conditional: Mechanical path ── */}
        {mechanical && (
          <div className="rounded border border-blue-100 bg-blue-50/40 p-3">
            <div className="text-[11px] font-medium text-blue-600 mb-2">Height = H x Panels + Wraps + Safety</div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              <div>
                <Label className="text-xs">Panel Multiplier</Label>
                <Input type="number" step={1} min={1} value={draft.panel_multiplier ?? 1} onChange={e => setDraft({ ...draft, panel_multiplier: parseFloat(e.target.value) || 1 })} className="text-xs" />
                <span className="text-[10px] text-gray-400">1=Roller, 2=Dual, 3=Triple</span>
              </div>
              <div>
                <Label className="text-xs">Tube Wrap (mm)</Label>
                <Input type="number" step={1} value={draft.tube_wrap_mm ?? 0} onChange={e => setDraft({ ...draft, tube_wrap_mm: parseFloat(e.target.value) || 0 })} className="text-xs" />
              </div>
              <div>
                <Label className="text-xs">Bottom Wrap (mm)</Label>
                <Input type="number" step={1} value={draft.bottom_wrap_mm ?? 0} onChange={e => setDraft({ ...draft, bottom_wrap_mm: parseFloat(e.target.value) || 0 })} className="text-xs" />
              </div>
              <div>
                <Label className="text-xs">Safety Margin (mm)</Label>
                <Input type="number" step={1} value={draft.safety_margin_mm ?? 0} onChange={e => setDraft({ ...draft, safety_margin_mm: parseFloat(e.target.value) || 0 })} className="text-xs" />
              </div>
            </div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-3 pt-3 border-t border-blue-100">
              <div>
                <Label className="text-xs">Heat Seal Price ($/m)</Label>
                <Input type="number" step={0.5} min={0} value={draft.heatseal_price_per_m ?? 0} onChange={e => setDraft({ ...draft, heatseal_price_per_m: parseFloat(e.target.value) || 0 })} className="text-xs" />
                <span className="text-[10px] text-gray-400">Per linear meter of splice</span>
              </div>
              <div>
                <Label className="text-xs">Bottom Bar Wrap (%)</Label>
                <div className="relative">
                  <Input
                    type="number" step={1} min={0} max={100}
                    value={((draft.bottom_bar_wrap_pct ?? 0) * 100).toFixed(0)}
                    onChange={e => setDraft({ ...draft, bottom_bar_wrap_pct: (parseFloat(e.target.value) || 0) / 100 })}
                    className="text-xs pr-6"
                  />
                  <span className="absolute right-2 top-1/2 -translate-y-1/2 text-xs text-gray-400">%</span>
                </div>
                <span className="text-[10px] text-gray-400">Surcharge when forrado</span>
              </div>
            </div>
          </div>
        )}

        {/* ── Conditional: Drapery path ── */}
        {drapery && (
          <div className="rounded border border-purple-100 bg-purple-50/40 p-3">
            <div className="text-[11px] font-medium text-purple-600 mb-2">Width = Finished x Fullness</div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              <div>
                <Label className="text-xs">Fullness Factor</Label>
                <Input type="number" step={0.1} min={1} value={draft.fullness_factor ?? 1} onChange={e => setDraft({ ...draft, fullness_factor: parseFloat(e.target.value) || 1 })} className="text-xs" />
                <span className="text-[10px] text-gray-400">1.8x, 2.0x, 2.2x, 2.5x</span>
              </div>
              <div>
                <Label className="text-xs">Top Hem (cm)</Label>
                <Input type="number" step={0.5} value={draft.top_hem_cm ?? 0} onChange={e => setDraft({ ...draft, top_hem_cm: parseFloat(e.target.value) || 0 })} className="text-xs" />
              </div>
              <div>
                <Label className="text-xs">Bottom Hem (cm)</Label>
                <Input type="number" step={0.5} value={draft.bottom_hem_cm ?? 0} onChange={e => setDraft({ ...draft, bottom_hem_cm: parseFloat(e.target.value) || 0 })} className="text-xs" />
              </div>
              <div>
                <Label className="text-xs">Side Hem (cm)</Label>
                <Input type="number" step={0.5} value={draft.side_hem_cm ?? 0} onChange={e => setDraft({ ...draft, side_hem_cm: parseFloat(e.target.value) || 0 })} className="text-xs" />
              </div>
            </div>
          </div>
        )}

        {/* ── Waste + Purchasing + Confection ── */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div>
            <Label className="text-xs">Waste (%)</Label>
            <div className="relative">
              <Input
                type="number" step={1} min={0} max={100}
                value={wasteDisplay}
                onChange={e => setDraft({ ...draft, waste_pct: (parseFloat(e.target.value) || 0) / 100 })}
                className="text-xs pr-6"
              />
              <span className="absolute right-2 top-1/2 -translate-y-1/2 text-xs text-gray-400">%</span>
            </div>
          </div>
          <div>
            <Label className="text-xs">Confection (%)</Label>
            <div className="relative">
              <Input
                type="number" step={1} min={0} max={100}
                value={((draft.confection_pct ?? 0) * 100).toFixed(0)}
                onChange={e => setDraft({ ...draft, confection_pct: (parseFloat(e.target.value) || 0) / 100 })}
                className="text-xs pr-6"
              />
              <span className="absolute right-2 top-1/2 -translate-y-1/2 text-xs text-gray-400">%</span>
            </div>
            <span className="text-[10px] text-gray-400">Surcharge on fabric cost</span>
          </div>
          <div>
            <Label className="text-xs">Min Order Qty</Label>
            <Input type="number" step={0.01} value={draft.min_qty ?? 0} onChange={e => setDraft({ ...draft, min_qty: parseFloat(e.target.value) || 0 })} className="text-xs" />
            <span className="text-[10px] text-gray-400">Minimum to order (e.g., 1m)</span>
          </div>
          <div>
            <Label className="text-xs">Round Increment</Label>
            <Input type="number" step={0.01} value={draft.round_to_increment ?? 0.01} onChange={e => setDraft({ ...draft, round_to_increment: parseFloat(e.target.value) || 0.01 })} className="text-xs" />
            <span className="text-[10px] text-gray-400">Round to nearest (e.g., 0.1m)</span>
          </div>
        </div>

        {/* ── Variant identification: only for non-drapery, non-mechanical types ── */}
        {!ptIsDrapery && !ptIsMechanical && (
          <details className="group">
            <summary className="text-[11px] text-gray-400 cursor-pointer hover:text-gray-600">
              Optional: Variant identification (for multiple rules per product type)
            </summary>
            <div className="grid grid-cols-2 md:grid-cols-3 gap-3 mt-2">
              <div>
                <Label className="text-xs text-gray-400">Style Code</Label>
                <Input value={draft.style_code || ''} onChange={e => setDraft({ ...draft, style_code: e.target.value || null })} placeholder="e.g. wave_2.3" className="text-xs" />
              </div>
              <div>
                <Label className="text-xs text-gray-400">Display Name</Label>
                <Input value={draft.display_name || ''} onChange={e => setDraft({ ...draft, display_name: e.target.value || null })} placeholder="e.g. Wave 2.3" className="text-xs" />
              </div>
              <div>
                <Label className="text-xs text-gray-400">Product Line</Label>
                <Input value={draft.product_line || ''} onChange={e => setDraft({ ...draft, product_line: e.target.value || null })} placeholder="e.g. wave" className="text-xs" />
              </div>
            </div>
          </details>
        )}
      </div>
    );
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-gray-900">Fabric & System Rules</h2>
          <p className="text-sm text-gray-500 mt-1">Configure fabric consumption formulas, waste percentages, and system rules per product type.</p>
        </div>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 text-sm rounded p-3">{error}</div>
      )}

      <div className="space-y-4">
        {allProductTypeIds.map(ptId => {
          const ptRules = rulesByProductType.get(ptId) || [];
          const isExpanded = expandedTypes.has(ptId);
          const ptName = getProductTypeName(ptId);

          return (
            <div key={ptId} className="border border-gray-200 rounded-lg overflow-hidden">
              <button
                type="button"
                onClick={() => toggleType(ptId)}
                className="w-full flex items-center justify-between px-4 py-3 bg-gray-50 hover:bg-gray-100 transition-colors"
              >
                <div className="flex items-center gap-2">
                  {isExpanded ? <ChevronDown className="h-4 w-4 text-gray-500" /> : <ChevronRight className="h-4 w-4 text-gray-500" />}
                  <span className="font-medium text-sm text-gray-900">{ptName}</span>
                  <span className="text-xs text-gray-500 bg-gray-200 rounded-full px-2 py-0.5">{ptRules.length} rules</span>
                </div>
              </button>

              {isExpanded && (
                <div className="px-4 py-3 space-y-3">
                  {ptRules.map(rule => {
                    const isEditing = editingRuleId === rule.id;
                    const sysKey = `${rule.product_type_id}:${rule.style_code || ''}`;
                    const linkedSystemRules = systemRulesByFabricRule.get(sysKey) || [];
                    const showSysRules = expandedSystemRules.has(rule.id);

                    return (
                      <div key={rule.id} className="border border-gray-100 rounded p-3 space-y-2">
                        {isEditing ? (
                          <>
                            {renderRuleForm(editDraft, setEditDraft, ptName)}
                            <div className="flex gap-2 mt-2">
                              <button type="button" onClick={handleSaveEdit} className="inline-flex items-center gap-1 text-xs font-medium text-white bg-gray-900 rounded px-3 py-1.5 hover:bg-gray-800">
                                <Save className="h-3 w-3" /> Save
                              </button>
                              <button type="button" onClick={() => { setEditingRuleId(null); setEditDraft({}); }} className="text-xs text-gray-600 px-3 py-1.5 border border-gray-300 rounded hover:bg-gray-50">Cancel</button>
                            </div>
                          </>
                        ) : (
                          <div className="flex items-start justify-between">
                            <div className="text-xs space-y-1">
                              <div className="flex items-center gap-2">
                                <span className="font-semibold text-gray-900">{rule.display_name || rule.style_code || '(default)'}</span>
                                {(rule as any).fabric_group && <span className="bg-purple-50 text-purple-700 rounded px-1.5 py-0.5">{(rule as any).fabric_group}</span>}
                                <span className="bg-blue-50 text-blue-700 rounded px-1.5 py-0.5">{rule.formula_code}</span>
                                {!rule.is_active && <span className="bg-red-50 text-red-600 rounded px-1.5 py-0.5">Inactive</span>}
                              </div>
                              <div className="text-gray-500 flex flex-wrap gap-x-4 gap-y-0.5">
                                <span>Width: {WIDTH_SOURCE_LABELS[rule.fabric_width_source] || rule.fabric_width_source}</span>
                                {isMechanical(rule.fabric_width_source) && (
                                  <>
                                    <span>Panels: {rule.panel_multiplier}x</span>
                                    <span>Wraps: {rule.tube_wrap_mm}/{rule.bottom_wrap_mm} mm</span>
                                    {rule.safety_margin_mm > 0 && <span>Safety: {rule.safety_margin_mm}mm</span>}
                                    {(rule.heatseal_price_per_m ?? 0) > 0 && <span>Heat Seal: ${rule.heatseal_price_per_m}/m</span>}
                                    {(rule.bottom_bar_wrap_pct ?? 0) > 0 && <span>BB Wrap: {(rule.bottom_bar_wrap_pct * 100).toFixed(0)}%</span>}
                                  </>
                                )}
                                {isDrapery(rule.fabric_width_source) && (
                                  <>
                                    <span>Fullness: {rule.fullness_factor}x</span>
                                    <span>Hems T/B/S: {rule.top_hem_cm}/{rule.bottom_hem_cm}/{rule.side_hem_cm} cm</span>
                                  </>
                                )}
                                <span>Waste: {(rule.waste_pct * 100).toFixed(0)}%</span>
                                {(rule.confection_pct ?? 0) > 0 && <span>Confection: {(rule.confection_pct * 100).toFixed(0)}%</span>}
                                <span>UOM: {rule.pricing_output_uom}</span>
                              </div>
                            </div>
                            <div className="flex items-center gap-1">
                              <button type="button" onClick={() => toggleSystemRules(rule.id)} className="p-1 rounded hover:bg-gray-100 text-gray-500 text-xs" title="System Rules">
                                SR ({linkedSystemRules.length})
                              </button>
                              <button type="button" onClick={() => { setEditingRuleId(rule.id); setEditDraft(rule); }} className="p-1 rounded hover:bg-gray-100 text-gray-500">
                                <Edit className="h-3.5 w-3.5" />
                              </button>
                              <button type="button" onClick={async () => { if (confirm('Delete this rule?')) await deleteRule(rule.id); }} className="p-1 rounded hover:bg-red-50 text-red-500">
                                <Trash2 className="h-3.5 w-3.5" />
                              </button>
                            </div>
                          </div>
                        )}

                        {showSysRules && (
                          <div className="mt-2 pl-4 border-l-2 border-gray-200 space-y-2">
                            <div className="text-xs font-medium text-gray-600">System Rules</div>
                            {linkedSystemRules.length === 0 && <p className="text-xs text-gray-400">No system rules.</p>}
                            {linkedSystemRules.map(sr => (
                              <div key={sr.id} className="flex items-center gap-3 text-xs">
                                <span className="font-mono text-gray-700">{sr.rule_key}</span>
                                <span className="text-gray-900 font-medium">{sr.rule_value}</span>
                                <button type="button" onClick={async () => { if (confirm('Delete?')) await deleteSystemRule(sr.id); }} className="p-0.5 rounded hover:bg-red-50 text-red-400">
                                  <Trash2 className="h-3 w-3" />
                                </button>
                              </div>
                            ))}
                            {addingSysRuleForId === rule.id ? (
                              <div className="flex items-end gap-2">
                                <div>
                                  <Label className="text-xs">Key</Label>
                                  <Input value={newSysKey} onChange={e => setNewSysKey(e.target.value)} className="text-xs w-32" placeholder="e.g. carrier_spacing_mm" />
                                </div>
                                <div>
                                  <Label className="text-xs">Value</Label>
                                  <Input type="number" value={newSysValue} onChange={e => setNewSysValue(e.target.value)} className="text-xs w-24" />
                                </div>
                                <button type="button" onClick={() => handleAddSystemRule(rule)} className="text-xs text-white bg-gray-900 rounded px-2 py-1.5 hover:bg-gray-800">Add</button>
                                <button type="button" onClick={() => setAddingSysRuleForId(null)} className="text-xs text-gray-500">Cancel</button>
                              </div>
                            ) : (
                              <button type="button" onClick={() => { setAddingSysRuleForId(rule.id); setNewSysKey(''); setNewSysValue(''); }} className="text-xs text-gray-500 hover:text-gray-700">
                                + Add System Rule
                              </button>
                            )}
                          </div>
                        )}
                      </div>
                    );
                  })}

                  {addingForType === ptId ? (
                    <div className="space-y-2">
                      {renderRuleForm(newDraft, setNewDraft, ptName)}
                      <div className="flex gap-2">
                        <button type="button" onClick={handleSaveNew} className="inline-flex items-center gap-1 text-xs font-medium text-white bg-gray-900 rounded px-3 py-1.5 hover:bg-gray-800">
                          <Save className="h-3 w-3" /> Create Rule
                        </button>
                        <button type="button" onClick={() => { setAddingForType(null); setNewDraft({}); }} className="text-xs text-gray-600 px-3 py-1.5 border border-gray-300 rounded hover:bg-gray-50">Cancel</button>
                      </div>
                    </div>
                  ) : (
                    <button
                      type="button"
                      onClick={() => { setAddingForType(ptId); setNewDraft(getEmptyRule(ptId, ptName)); }}
                      className="inline-flex items-center gap-1 text-xs text-gray-600 hover:text-gray-900 px-2 py-1"
                    >
                      <Plus className="h-3.5 w-3.5" /> Add Rule
                    </button>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
