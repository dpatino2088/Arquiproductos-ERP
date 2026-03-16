import React, { useState, useMemo, useCallback, useEffect, forwardRef, useImperativeHandle } from 'react';
import { Plus, X, ExternalLink, Minus } from 'lucide-react';
import { getRoleLabel } from '../../../lib/bom/roles';
import { router } from '../../../lib/router';
import { getCascadeOrder, getCascadeLabel } from './types';
import type { EngineeringRow } from './BOMEngineeringTab';

export interface CutBreakdownHandle {
  hasChanges: boolean;
  saving: boolean;
  save: () => Promise<void>;
  discard: () => void;
}

const BOM_RETURN_TO = '/catalog/bom';

function navigateToItem(itemId: string | null | undefined) {
  if (!itemId) return;
  router.navigate(`/catalog/items/edit/${itemId}?returnTo=${encodeURIComponent(BOM_RETURN_TO)}`);
}

interface CutBreakdownProps {
  parentRows: EngineeringRow[];
  childrenByParent: Record<string, EngineeringRow[]>;
  onSaveAll: (changes: Array<{ componentId: string; updates: Record<string, any> }>) => Promise<void>;
  onPendingChange?: (hasChanges: boolean, saving: boolean) => void;
}

type DeltaMode = 'subtract' | 'add' | 'info';

interface LocalChange {
  depends_on_role?: string | null;
  cut_delta_mm?: number;
  affects_role?: string | null;
  delta_mode?: DeltaMode;
}

function getRawDelta(row: EngineeringRow, axis: string | null): number | null {
  return axis === 'height' ? row.delta_y_mm : row.delta_x_mm;
}

const EngineeringCutBreakdown = forwardRef<CutBreakdownHandle, CutBreakdownProps>(function EngineeringCutBreakdown({
  parentRows,
  childrenByParent,
  onSaveAll,
  onPendingChange,
}, ref) {
  const [collapsedTargets, setCollapsedTargets] = useState<Set<string>>(new Set());
  const [addingTo, setAddingTo] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [localChanges, setLocalChanges] = useState<Record<string, LocalChange>>({});

  useEffect(() => { setLocalChanges({}); }, [parentRows]);

  const getEffective = useCallback((row: EngineeringRow, field: keyof LocalChange) => {
    const change = localChanges[row.id];
    if (change && field in change) return change[field];
    return (row as any)[field];
  }, [localChanges]);

  const setChange = useCallback((id: string, field: keyof LocalChange, value: any) => {
    setLocalChanges(prev => ({
      ...prev,
      [id]: { ...prev[id], [field]: value },
    }));
  }, []);

  const hasChanges = Object.keys(localChanges).length > 0;

  const cuttableTargets = useMemo(
    () => parentRows
      .filter((r) => r.measure_basis === 'linear' || r.measure_basis === 'area')
      .sort((a, b) => getCascadeOrder(a.component_role) - getCascadeOrder(b.component_role)),
    [parentRows],
  );

  const cuttableRoles = useMemo(
    () => cuttableTargets.map(t => t.component_role).filter(Boolean) as string[],
    [cuttableTargets],
  );

  const unitComponents = useMemo(
    () => parentRows.filter(r => r.measure_basis !== 'linear' && r.measure_basis !== 'area'),
    [parentRows],
  );

  const affectingByRole = useMemo(() => {
    const map: Record<string, EngineeringRow[]> = {};
    for (const r of parentRows) {
      const ar = getEffective(r, 'affects_role') as string | null;
      if (ar) {
        if (!map[ar]) map[ar] = [];
        map[ar].push(r);
      }
    }
    return map;
  }, [parentRows, getEffective]);

  const resolvedCuts = useMemo(() => {
    const resolved = new Map<string, number>();
    for (const target of cuttableTargets) {
      const role = target.component_role ?? '';
      const depRole = getEffective(target, 'depends_on_role') as string | null;
      const tolerance = Number(getEffective(target, 'cut_delta_mm') ?? 0);
      const isYAxis = target.cut_axis === 'height';

      let baseValue: number;
      if (depRole && resolved.has(depRole)) {
        baseValue = resolved.get(depRole)!;
      } else {
        baseValue = 0;
      }

      const affecting = affectingByRole[role] ?? [];
      const ownChildren = childrenByParent[target.id] ?? [];

      let subtractTotal = 0;
      for (const comp of affecting) {
        const mode = (getEffective(comp, 'delta_mode') ?? 'subtract') as DeltaMode;
        if (mode !== 'subtract') continue;
        const raw = getRawDelta(comp, isYAxis ? 'height' : null);
        if (raw != null) subtractTotal += raw * (comp.qty_value ?? 1);
        const children = childrenByParent[comp.id] ?? [];
        for (const ch of children) {
          const craw = getRawDelta(ch, isYAxis ? 'height' : null);
          if (craw != null) subtractTotal += craw * (ch.qty_value ?? 1);
        }
      }

      for (const ch of ownChildren) {
        const craw = getRawDelta(ch, isYAxis ? 'height' : null);
        if (craw != null) subtractTotal += craw * (ch.qty_value ?? 1);
      }

      resolved.set(role, baseValue + tolerance - subtractTotal);
    }
    return resolved;
  }, [cuttableTargets, affectingByRole, childrenByParent, getEffective]);

  const toggleTarget = useCallback((id: string) => {
    setCollapsedTargets(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  }, []);

  const handleAddAffecting = useCallback((targetRole: string, componentId: string) => {
    setChange(componentId, 'affects_role', targetRole);
    setAddingTo(null);
  }, [setChange]);

  const handleRemoveAffecting = useCallback((componentId: string) => {
    setChange(componentId, 'affects_role', null);
  }, [setChange]);

  const handleSave = useCallback(async () => {
    const changes: Array<{ componentId: string; updates: Record<string, any> }> = [];
    for (const [id, change] of Object.entries(localChanges)) {
      const updates: Record<string, any> = {};
      if ('depends_on_role' in change) updates.depends_on_role = change.depends_on_role || null;
      if ('cut_delta_mm' in change) updates.cut_delta_mm = change.cut_delta_mm ?? 0;
      if ('affects_role' in change) updates.affects_role = change.affects_role || null;
      if ('delta_mode' in change) updates.delta_mode = change.delta_mode || 'subtract';
      if (Object.keys(updates).length > 0) changes.push({ componentId: id, updates });
    }
    if (changes.length === 0) return;
    setSaving(true);
    try { await onSaveAll(changes); } finally { setSaving(false); }
  }, [localChanges, onSaveAll]);

  const handleDiscard = useCallback(() => { setLocalChanges({}); }, []);

  useImperativeHandle(ref, () => ({
    hasChanges, saving, save: handleSave, discard: handleDiscard,
  }), [hasChanges, saving, handleSave, handleDiscard]);

  useEffect(() => { onPendingChange?.(hasChanges, saving); }, [hasChanges, saving, onPendingChange]);

  if (cuttableTargets.length === 0) {
    return (
      <div className="flex items-center justify-center p-12 text-gray-400 h-full">
        <p className="text-sm">No cuttable components in this template.</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full">
      <div className="p-4 space-y-3 overflow-y-auto flex-1">
        {cuttableTargets.map((target) => {
          const role = target.component_role ?? '';
          const isExpanded = !collapsedTargets.has(target.id);
          const isYAxis = target.cut_axis === 'height';
          const deltaKey = isYAxis ? 'ΔY' : 'ΔX';

          const depRole = getEffective(target, 'depends_on_role') as string | null;
          const tolerance = Number(getEffective(target, 'cut_delta_mm') ?? 0);

          const affecting = affectingByRole[role] ?? [];
          const ownChildren = childrenByParent[target.id] ?? [];

          let subtractTotal = 0;
          let addTotal = 0;
          const groupData: Array<{ comp: EngineeringRow; children: EngineeringRow[]; mode: DeltaMode; groupDelta: number }> = [];

          for (const comp of affecting) {
            const mode = (getEffective(comp, 'delta_mode') ?? 'subtract') as DeltaMode;
            const children = childrenByParent[comp.id] ?? [];
            let groupDelta = 0;
            const raw = getRawDelta(comp, isYAxis ? 'height' : null);
            if (raw != null) groupDelta += raw * (comp.qty_value ?? 1);
            for (const ch of children) {
              const cr = getRawDelta(ch, isYAxis ? 'height' : null);
              if (cr != null) groupDelta += cr * (ch.qty_value ?? 1);
            }
            if (mode === 'subtract') subtractTotal += groupDelta;
            else if (mode === 'add') addTotal += groupDelta;
            groupData.push({ comp, children, mode, groupDelta });
          }

          let ownChildrenDelta = 0;
          for (const ch of ownChildren) {
            const cr = getRawDelta(ch, isYAxis ? 'height' : null);
            if (cr != null) ownChildrenDelta += cr * (ch.qty_value ?? 1);
          }
          subtractTotal += ownChildrenDelta;

          const baseLabel = depRole ? `${getRoleLabel(depRole)}.cut` : `Curtain ${isYAxis ? 'Height' : 'Width'}`;
          const cutResult = tolerance - subtractTotal;
          const assemblyTotal = cutResult + addTotal;

          const available = unitComponents.filter(
            c => {
              const ar = getEffective(c, 'affects_role') as string | null;
              return !ar || ar === role ? c.id !== target.id && !affecting.some(a => a.id === c.id) : false;
            }
          ).filter(c => {
            const ar = getEffective(c, 'affects_role') as string | null;
            return !ar;
          });

          const baseOptions = [
            { value: '', label: `Curtain ${isYAxis ? 'Height' : 'Width'}` },
            ...cuttableRoles
              .filter(r => r !== role && getCascadeOrder(r) < getCascadeOrder(role))
              .map(r => ({ value: r, label: `${getRoleLabel(r)}.cut` })),
          ];

          return (
            <div key={target.id} className="border border-gray-200 rounded-lg bg-white overflow-hidden">
              {/* Header */}
              <button
                type="button"
                onClick={() => toggleTarget(target.id)}
                className="w-full flex items-center gap-3 px-4 py-2.5 hover:bg-gray-50/50 text-left"
              >
                <span className="text-gray-400 text-xs w-3 text-center">{isExpanded ? '▼' : '▶'}</span>
                <div className="flex-1 min-w-0">
                  {getCascadeLabel(role) && (
                    <span className="text-[10px] font-mono text-gray-400 mr-2">{getCascadeLabel(role)?.split(' ')[0]}</span>
                  )}
                  <span className="font-semibold text-sm text-gray-900">{getRoleLabel(role) || role}</span>
                  <span className="text-xs text-gray-400 ml-2">{target.component_sku}</span>
                  {depRole && (
                    <span className="ml-2 text-[10px] px-1.5 py-0.5 bg-blue-50 text-blue-600 rounded font-mono">
                      ← {getRoleLabel(depRole)}
                    </span>
                  )}
                </div>
                <span className="text-right tabular-nums flex-shrink-0">
                  <span className="text-xs text-gray-400">Cut: </span>
                  <span className="font-mono text-sm font-semibold text-gray-800">
                    {cutResult >= 0 ? '+' : ''}{cutResult} mm
                  </span>
                </span>
              </button>

              {isExpanded && (
                <div className="border-t border-gray-100">
                  {/* Base + Tolerance controls */}
                  <div className="px-4 py-2.5 bg-gray-50/60 border-b border-gray-100 flex items-center gap-4 flex-wrap">
                    <div className="flex items-center gap-2">
                      <label className="text-xs font-medium text-gray-500 whitespace-nowrap">Base:</label>
                      <select
                        value={depRole || ''}
                        onChange={e => setChange(target.id, 'depends_on_role', e.target.value || null)}
                        className="text-xs border border-gray-200 rounded px-2 py-1 bg-white focus:outline-none focus:ring-1 focus:ring-primary/30 min-w-[160px]"
                      >
                        {baseOptions.map(o => (
                          <option key={o.value} value={o.value}>{o.label}</option>
                        ))}
                      </select>
                    </div>
                    <div className="flex items-center gap-2">
                      <label className="text-xs font-medium text-gray-500 whitespace-nowrap">Tolerance:</label>
                      <input
                        type="number"
                        value={tolerance}
                        onChange={e => setChange(target.id, 'cut_delta_mm', Number(e.target.value) || 0)}
                        className="text-xs border border-gray-200 rounded px-2 py-1 bg-white w-20 text-right font-mono focus:outline-none focus:ring-1 focus:ring-primary/30"
                      />
                      <span className="text-xs text-gray-400">mm</span>
                    </div>
                  </div>

                  {/* Table of affecting components */}
                  {(ownChildren.length > 0 || affecting.length > 0) && (
                    <table className="w-full text-xs">
                      <thead>
                        <tr className="border-b border-gray-100 text-gray-400">
                          <th className="text-left py-1.5 px-4 font-medium">Component</th>
                          <th className="text-left py-1.5 font-medium">Role</th>
                          <th className="text-center py-1.5 font-medium w-10">Qty</th>
                          <th className="text-center py-1.5 font-medium w-14 text-gray-600">{deltaKey}</th>
                          <th className="text-center py-1.5 font-medium w-20">Mode</th>
                          <th className="text-center py-1.5 font-medium w-16 text-gray-600">Total</th>
                          <th className="w-14 py-1.5" />
                        </tr>
                      </thead>
                      <tbody>
                        {ownChildren.map(child => {
                          const qty = child.qty_value ?? 1;
                          const raw = getRawDelta(child, isYAxis ? 'height' : null);
                          const eff = raw != null ? raw * qty : null;
                          return (
                            <tr key={child.id} className="border-b border-gray-50 group hover:bg-gray-50/50">
                              <td className="py-1 pl-10 pr-4">
                                <span className="text-gray-300 mr-1">↳</span>
                                <span className="font-mono text-gray-600">{child.component_sku}</span>
                                <span className="text-gray-400 ml-1">{child.component_name}</span>
                              </td>
                              <td className="py-1 text-gray-400">{getRoleLabel(child.component_role ?? '')}</td>
                              <td className="py-1 text-center font-mono text-gray-500">{qty}</td>
                              <td className="py-1 text-center">
                                <span className="font-mono text-gray-600">{raw != null ? `${raw}` : '—'}</span>
                              </td>
                              <td className="py-1 text-center">
                                <span className="text-[10px] px-1.5 py-0.5 rounded bg-red-50 text-red-600">− Sub</span>
                              </td>
                              <td className="py-1 text-center">
                                <span className={`font-mono font-medium ${eff != null ? 'text-red-500' : 'text-gray-200'}`}>
                                  {eff != null ? `−${Math.abs(eff)}` : '—'}
                                </span>
                              </td>
                              <td className="py-1 text-right pr-3">
                                <button type="button" onClick={() => navigateToItem(child.component_item_id)} className="p-0.5 rounded text-gray-300 hover:text-primary opacity-0 group-hover:opacity-100 transition-opacity" title="View in catalog">
                                  <ExternalLink className="h-3 w-3" />
                                </button>
                              </td>
                            </tr>
                          );
                        })}

                        {groupData.map(({ comp, children, mode, groupDelta }) => {
                          const qty = comp.qty_value ?? 1;
                          const raw = getRawDelta(comp, isYAxis ? 'height' : null);
                          const eff = raw != null ? raw * qty : null;
                          const isModified = comp.id in localChanges;
                          const modeColor = mode === 'subtract' ? 'bg-red-50 text-red-600' : mode === 'add' ? 'bg-green-50 text-green-700' : 'bg-gray-100 text-gray-500';
                          const modeLabel = mode === 'subtract' ? '− Sub' : mode === 'add' ? '+ Add' : 'Info';
                          const totalColor = mode === 'subtract' ? 'text-red-500' : mode === 'add' ? 'text-green-600' : 'text-gray-400';
                          const totalPrefix = mode === 'subtract' ? '−' : mode === 'add' ? '+' : '';
                          return (
                            <React.Fragment key={comp.id}>
                              <tr className={`border-b border-gray-50 group hover:bg-gray-50/50 ${isModified ? 'bg-amber-50/40' : ''}`}>
                                <td className="py-1.5 px-4">
                                  <span className="font-mono text-gray-700">{comp.component_sku}</span>
                                  <span className="text-gray-400 ml-1">{comp.component_name}</span>
                                </td>
                                <td className="py-1.5 text-gray-500">{getRoleLabel(comp.component_role ?? '')}</td>
                                <td className="py-1.5 text-center font-mono text-gray-500">{qty}</td>
                                <td className="py-1.5 text-center">
                                  <span className="font-mono text-gray-600">{raw != null ? `${raw}` : '—'}</span>
                                </td>
                                <td className="py-1.5 text-center">
                                  <select
                                    value={mode}
                                    onChange={e => setChange(comp.id, 'delta_mode', e.target.value as DeltaMode)}
                                    className={`text-[10px] font-medium px-1.5 py-0.5 rounded border-0 cursor-pointer focus:outline-none ${modeColor}`}
                                  >
                                    <option value="subtract">− Subtract</option>
                                    <option value="add">+ Add</option>
                                    <option value="info">Info</option>
                                  </select>
                                </td>
                                <td className="py-1.5 text-center">
                                  <span className={`font-mono font-medium ${totalColor}`}>
                                    {groupDelta !== 0 ? `${totalPrefix}${Math.abs(groupDelta)}` : '—'}
                                  </span>
                                </td>
                                <td className="py-1.5 text-right pr-3">
                                  <div className="inline-flex items-center gap-0.5">
                                    <button type="button" onClick={() => navigateToItem(comp.component_item_id)} className="p-0.5 rounded text-gray-300 hover:text-primary" title="View in catalog">
                                      <ExternalLink className="h-3 w-3" />
                                    </button>
                                    <button type="button" onClick={() => handleRemoveAffecting(comp.id)} className="p-0.5 rounded opacity-0 group-hover:opacity-100 text-gray-300 hover:text-red-500 transition-opacity" title="Remove">
                                      <X className="h-3 w-3" />
                                    </button>
                                  </div>
                                </td>
                              </tr>
                              {children.map(child => {
                                const cqty = child.qty_value ?? 1;
                                const craw = getRawDelta(child, isYAxis ? 'height' : null);
                                const ceff = craw != null ? craw * cqty : null;
                                return (
                                  <tr key={child.id} className="border-b border-gray-50 group hover:bg-gray-50/50">
                                    <td className="py-1 px-4 pl-10">
                                      <span className="text-gray-300 mr-1">↳</span>
                                      <span className="font-mono text-gray-500">{child.component_sku}</span>
                                      <span className="text-gray-400 ml-1">{child.component_name}</span>
                                    </td>
                                    <td className="py-1 text-gray-400">{getRoleLabel(child.component_role ?? '')}</td>
                                    <td className="py-1 text-center font-mono text-gray-400">{cqty}</td>
                                    <td className="py-1 text-center">
                                      <span className="font-mono text-gray-500">{craw != null ? `${craw}` : '—'}</span>
                                    </td>
                                    <td className="py-1 text-center">
                                      <span className={`text-[10px] px-1.5 py-0.5 rounded ${modeColor}`}>{modeLabel}</span>
                                    </td>
                                    <td className="py-1 text-center">
                                      <span className={`font-mono font-medium ${mode === 'subtract' ? 'text-red-400' : mode === 'add' ? 'text-green-500' : 'text-gray-300'}`}>
                                        {ceff != null ? `${totalPrefix}${Math.abs(ceff)}` : '—'}
                                      </span>
                                    </td>
                                    <td className="py-1 text-right pr-3">
                                      <button type="button" onClick={() => navigateToItem(child.component_item_id)} className="p-0.5 rounded text-gray-300 hover:text-primary opacity-0 group-hover:opacity-100 transition-opacity" title="View in catalog">
                                        <ExternalLink className="h-3 w-3" />
                                      </button>
                                    </td>
                                  </tr>
                                );
                              })}
                            </React.Fragment>
                          );
                        })}
                      </tbody>
                    </table>
                  )}

                  {/* Formula line */}
                  <div className="px-4 py-2 bg-gray-50/50 border-t border-gray-100 text-xs font-mono text-gray-500 space-y-0.5">
                    <div>
                      <span className="text-gray-700 font-semibold">{getRoleLabel(role)} Cut</span>
                      {' = '}
                      <span className="text-blue-600">{baseLabel}</span>
                      {tolerance !== 0 && (
                        <span className="text-orange-500"> {tolerance > 0 ? '+' : '−'} {Math.abs(tolerance)}</span>
                      )}
                      {subtractTotal !== 0 && (
                        <span className="text-red-500"> − {Math.abs(subtractTotal)}</span>
                      )}
                      <span className="text-gray-400"> = </span>
                      <span className="text-gray-800 font-semibold">{baseLabel} {cutResult >= 0 ? '+' : ''}{cutResult} mm</span>
                    </div>
                    {addTotal !== 0 && (
                      <div className="text-gray-400">
                        <span className="text-gray-600">Assembly</span>
                        {' = Cut '}
                        <span className="text-green-600">+ {addTotal}</span>
                        <span className="text-gray-400"> = </span>
                        <span className="text-gray-700">{baseLabel} {assemblyTotal >= 0 ? '+' : ''}{assemblyTotal} mm</span>
                        <span className="text-gray-400 ml-1">(informativo)</span>
                      </div>
                    )}
                  </div>

                  {/* Add component */}
                  {available.length > 0 && (
                    <div className="px-4 py-2 border-t border-gray-100">
                      {addingTo === role ? (
                        <div className="flex items-center gap-2">
                          <select
                            value=""
                            onChange={e => { if (e.target.value) handleAddAffecting(role, e.target.value); }}
                            className="text-xs border border-gray-200 rounded px-2 py-1 bg-white flex-1 focus:outline-none focus:ring-1 focus:ring-primary/30"
                          >
                            <option value="">Select component…</option>
                            {available.map(c => (
                              <option key={c.id} value={c.id}>
                                {c.component_sku} — {c.component_name} ({getRoleLabel(c.component_role ?? '')})
                              </option>
                            ))}
                          </select>
                          <button type="button" onClick={() => setAddingTo(null)} className="text-xs text-gray-400 hover:text-gray-600">Cancel</button>
                        </div>
                      ) : (
                        <button type="button" onClick={() => setAddingTo(role)} className="inline-flex items-center gap-1 text-xs text-primary hover:text-primary/80">
                          <Plus className="h-3 w-3" />
                          Add component
                        </button>
                      )}
                    </div>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
});

export default EngineeringCutBreakdown;
