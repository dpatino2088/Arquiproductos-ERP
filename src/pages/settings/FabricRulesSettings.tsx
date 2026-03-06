import { useState, useMemo, useCallback } from 'react';
import { Plus, Trash2, Edit, ChevronDown, ChevronRight, Save, X } from 'lucide-react';
import { useFabricRules, FabricRule, SystemRule } from '../../hooks/useFabricRules';
import { useProductTypes } from '../../hooks/useProductTypes';
import Label from '../../components/ui/Label';
import Input from '../../components/ui/Input';

const FORMULA_CODES = ['ROLLER_DROPS', 'AREA_BASED', 'DRAPERY_PANELS'] as const;
const PRICING_UOMS = ['m', 'm2'] as const;
const ORIENTATIONS = ['vertical', 'railroaded'] as const;

function getEmptyRule(productTypeId: string): Partial<FabricRule> {
  return {
    product_type_id: productTypeId,
    style_code: null,
    display_name: null,
    image_url: null,
    product_line: null,
    formula_code: 'ROLLER_DROPS',
    height_multiplier: 1,
    width_multiplier: 1,
    fullness_factor: 1,
    extra_height_m: 0,
    extra_width_m: 0,
    pricing_output_uom: 'm',
    waste_pct: 0.15,
    round_to_increment: 0.01,
    min_qty: 0,
    top_hem_cm: 0,
    bottom_hem_cm: 0,
    side_hem_cm: 0,
    fabric_orientation: 'vertical',
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

  const renderRuleForm = (draft: Partial<FabricRule>, setDraft: (v: Partial<FabricRule>) => void) => (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-3 p-4 bg-gray-50 border border-gray-200 rounded">
      <div>
        <Label className="text-xs">Style Code</Label>
        <Input value={draft.style_code || ''} onChange={e => setDraft({ ...draft, style_code: e.target.value || null })} placeholder="e.g. wave_2.3" className="text-xs" />
      </div>
      <div>
        <Label className="text-xs">Display Name</Label>
        <Input value={draft.display_name || ''} onChange={e => setDraft({ ...draft, display_name: e.target.value || null })} placeholder="e.g. Wave 2.3" className="text-xs" />
      </div>
      <div>
        <Label className="text-xs">Product Line</Label>
        <Input value={draft.product_line || ''} onChange={e => setDraft({ ...draft, product_line: e.target.value || null })} placeholder="e.g. wave" className="text-xs" />
      </div>
      <div>
        <Label className="text-xs">Formula Code</Label>
        <select value={draft.formula_code || 'ROLLER_DROPS'} onChange={e => setDraft({ ...draft, formula_code: e.target.value })} className="w-full text-xs border border-gray-300 rounded px-2 py-1.5">
          {FORMULA_CODES.map(f => <option key={f} value={f}>{f}</option>)}
        </select>
      </div>
      <div>
        <Label className="text-xs">Fullness Factor</Label>
        <Input type="number" step={0.1} value={draft.fullness_factor ?? 1} onChange={e => setDraft({ ...draft, fullness_factor: parseFloat(e.target.value) || 1 })} className="text-xs" />
      </div>
      <div>
        <Label className="text-xs">Height Multiplier</Label>
        <Input type="number" step={0.1} value={draft.height_multiplier ?? 1} onChange={e => setDraft({ ...draft, height_multiplier: parseFloat(e.target.value) || 1 })} className="text-xs" />
      </div>
      <div>
        <Label className="text-xs">Width Multiplier</Label>
        <Input type="number" step={0.1} value={draft.width_multiplier ?? 1} onChange={e => setDraft({ ...draft, width_multiplier: parseFloat(e.target.value) || 1 })} className="text-xs" />
      </div>
      <div>
        <Label className="text-xs">Waste %</Label>
        <Input type="number" step={0.01} value={draft.waste_pct ?? 0.15} onChange={e => setDraft({ ...draft, waste_pct: parseFloat(e.target.value) || 0 })} className="text-xs" />
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
      <div>
        <Label className="text-xs">Pricing UOM</Label>
        <select value={draft.pricing_output_uom || 'm'} onChange={e => setDraft({ ...draft, pricing_output_uom: e.target.value })} className="w-full text-xs border border-gray-300 rounded px-2 py-1.5">
          {PRICING_UOMS.map(u => <option key={u} value={u}>{u}</option>)}
        </select>
      </div>
      <div>
        <Label className="text-xs">Orientation</Label>
        <select value={draft.fabric_orientation || 'vertical'} onChange={e => setDraft({ ...draft, fabric_orientation: e.target.value })} className="w-full text-xs border border-gray-300 rounded px-2 py-1.5">
          {ORIENTATIONS.map(o => <option key={o} value={o}>{o}</option>)}
        </select>
      </div>
      <div>
        <Label className="text-xs">Min Qty</Label>
        <Input type="number" step={0.01} value={draft.min_qty ?? 0} onChange={e => setDraft({ ...draft, min_qty: parseFloat(e.target.value) || 0 })} className="text-xs" />
      </div>
      <div>
        <Label className="text-xs">Round To</Label>
        <Input type="number" step={0.01} value={draft.round_to_increment ?? 0.01} onChange={e => setDraft({ ...draft, round_to_increment: parseFloat(e.target.value) || 0.01 })} className="text-xs" />
      </div>
      <div className="flex items-end gap-1">
        <label className="flex items-center gap-1.5 text-xs">
          <input type="checkbox" checked={draft.is_active !== false} onChange={e => setDraft({ ...draft, is_active: e.target.checked })} className="rounded border-gray-300" />
          Active
        </label>
      </div>
    </div>
  );

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
                            {renderRuleForm(editDraft, setEditDraft)}
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
                                {rule.product_line && <span className="bg-gray-100 text-gray-600 rounded px-1.5 py-0.5">{rule.product_line}</span>}
                                <span className="bg-blue-50 text-blue-700 rounded px-1.5 py-0.5">{rule.formula_code}</span>
                                {!rule.is_active && <span className="bg-red-50 text-red-600 rounded px-1.5 py-0.5">Inactive</span>}
                              </div>
                              <div className="text-gray-500 flex flex-wrap gap-x-4 gap-y-0.5">
                                <span>Fullness: {rule.fullness_factor}x</span>
                                <span>Waste: {(rule.waste_pct * 100).toFixed(0)}%</span>
                                <span>H×: {rule.height_multiplier}</span>
                                <span>W×: {rule.width_multiplier}</span>
                                <span>Hem T/B/S: {rule.top_hem_cm}/{rule.bottom_hem_cm}/{rule.side_hem_cm} cm</span>
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
                      {renderRuleForm(newDraft, setNewDraft)}
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
                      onClick={() => { setAddingForType(ptId); setNewDraft(getEmptyRule(ptId)); }}
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
