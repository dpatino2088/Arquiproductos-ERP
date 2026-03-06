import React, { useState, useMemo, useCallback, useEffect, forwardRef, useImperativeHandle } from 'react';
import { Plus, X, ExternalLink } from 'lucide-react';
import { Select as SelectShadcn, SelectTrigger, SelectValue, SelectContent, SelectItem } from '../../../components/ui/SelectShadcn';
import { getRoleLabel } from '../../../lib/bom/roles';
import { router } from '../../../lib/router';
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
  onSaveAll: (changes: Array<{ componentId: string; role: string | null }>) => Promise<void>;
  onPendingChange?: (hasChanges: boolean, saving: boolean) => void;
}

function getRawDelta(row: EngineeringRow, axis: string | null): number | null {
  return axis === 'height' ? row.delta_y_mm : row.delta_x_mm;
}

function getEffectiveDelta(row: EngineeringRow, axis: string | null): number {
  const raw = getRawDelta(row, axis);
  if (raw == null) return 0;
  return raw * (row.qty_value ?? 1);
}

function sumGroupDelta(
  parent: EngineeringRow,
  children: EngineeringRow[],
  axis: string | null,
): number {
  const pd = getEffectiveDelta(parent, axis);
  const cd = children.reduce((s, c) => s + getEffectiveDelta(c, axis), 0);
  return pd + cd;
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
  const [localOverrides, setLocalOverrides] = useState<Record<string, string | null>>({});

  useEffect(() => {
    setLocalOverrides({});
  }, [parentRows]);

  const effectiveRows = useMemo(() => {
    return parentRows.map((r) => {
      if (r.id in localOverrides) {
        return { ...r, affects_role: localOverrides[r.id] };
      }
      return r;
    });
  }, [parentRows, localOverrides]);

  const hasChanges = Object.keys(localOverrides).length > 0;

  const cuttableTargets = useMemo(
    () => effectiveRows.filter((r) => r.measure_basis === 'linear' || r.measure_basis === 'area'),
    [effectiveRows],
  );

  const cuttableRoles = useMemo(
    () => new Set(cuttableTargets.map((t) => t.component_role).filter(Boolean)),
    [cuttableTargets],
  );

  const affectingByRole = useMemo(() => {
    const map: Record<string, EngineeringRow[]> = {};
    for (const r of effectiveRows) {
      if (r.affects_role) {
        if (!map[r.affects_role]) map[r.affects_role] = [];
        map[r.affects_role].push(r);
      }
    }
    return map;
  }, [effectiveRows]);

  const unassigned = useMemo(
    () =>
      effectiveRows.filter(
        (c) => !c.affects_role && !cuttableRoles.has(c.component_role ?? ''),
      ),
    [effectiveRows, cuttableRoles],
  );

  const toggleTarget = useCallback((id: string) => {
    setCollapsedTargets((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  const handleAdd = useCallback((targetRole: string, componentId: string) => {
    setLocalOverrides((prev) => ({ ...prev, [componentId]: targetRole }));
    setAddingTo(null);
  }, []);

  const handleRemove = useCallback((componentId: string) => {
    setLocalOverrides((prev) => ({ ...prev, [componentId]: null }));
  }, []);

  const handleSave = useCallback(async () => {
    const changes = Object.entries(localOverrides).map(([componentId, role]) => ({
      componentId,
      role,
    }));
    if (changes.length === 0) return;
    setSaving(true);
    try {
      await onSaveAll(changes);
    } finally {
      setSaving(false);
    }
  }, [localOverrides, onSaveAll]);

  const handleDiscard = useCallback(() => {
    setLocalOverrides({});
  }, []);

  useImperativeHandle(ref, () => ({
    hasChanges,
    saving,
    save: handleSave,
    discard: handleDiscard,
  }), [hasChanges, saving, handleSave, handleDiscard]);

  useEffect(() => {
    onPendingChange?.(hasChanges, saving);
  }, [hasChanges, saving, onPendingChange]);

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
          const affecting = affectingByRole[role] ?? [];
          const deltaKey = target.cut_axis === 'height' ? 'y' : 'x';
          const axisLabel = target.cut_axis === 'height' ? 'H' : 'W';

          const ownChildren = childrenByParent[target.id] ?? [];
          const ownChildrenTotal = ownChildren.reduce((s, c) => s + getEffectiveDelta(c, target.cut_axis), 0);

          let affectingTotal = 0;
          const groupData = affecting.map((comp) => {
            const children = childrenByParent[comp.id] ?? [];
            const groupTotal = sumGroupDelta(comp, children, target.cut_axis);
            affectingTotal += groupTotal;
            return { comp, children, groupTotal };
          });

          const grandTotal = ownChildrenTotal + affectingTotal;

          const alreadyAffectingThisTarget = new Set(affecting.map((a) => a.id));
          const available = effectiveRows.filter(
            (c) => c.id !== target.id && !alreadyAffectingThisTarget.has(c.id),
          );

          const totalItems = ownChildren.length + affecting.length;

          return (
            <div key={target.id} className="border border-gray-200 rounded-lg bg-white overflow-hidden">
              <button
                type="button"
                onClick={() => toggleTarget(target.id)}
                className="w-full flex items-center gap-3 px-4 py-2.5 hover:bg-gray-50/50 text-left"
              >
                <span className="text-gray-400 text-xs w-3 text-center">
                  {isExpanded ? '▼' : '▶'}
                </span>
                <div className="flex-1 min-w-0">
                  <span className="font-semibold text-sm text-gray-900">
                    {getRoleLabel(role) || role || 'Unknown'}
                  </span>
                  <span className="text-xs text-gray-400 ml-2">
                    {target.component_sku}
                  </span>
                  {target.cut_axis && (
                    <span className="text-xs text-gray-400 ml-1">· Cut {axisLabel}</span>
                  )}
                </div>
                <span className="text-right tabular-nums flex-shrink-0">
                  <span className="text-xs text-gray-400">Total: </span>
                  <span className="font-mono text-sm font-semibold text-gray-800">
                    {grandTotal !== 0 ? `−${Math.abs(grandTotal)} mm` : '0 mm'}
                  </span>
                </span>
              </button>

              {isExpanded && (
                <div className="border-t border-gray-100">
                  {totalItems === 0 ? (
                    <p className="text-xs text-gray-400 px-4 py-3">
                      No components assigned.
                    </p>
                  ) : (
                    <table className="w-full text-xs">
                      <thead>
                        <tr className="border-b border-gray-100 text-gray-400">
                          <th className="text-left py-1.5 px-4 font-medium">Component</th>
                          <th className="text-left py-1.5 font-medium">Role</th>
                          <th className="text-center py-1.5 font-medium w-10">Qty</th>
                          <th className="text-center py-1.5 font-medium w-16 text-gray-600">{deltaKey === 'x' ? 'ΔX' : 'ΔY'}</th>
                          <th className="text-center py-1.5 font-medium w-16 text-gray-600">Total</th>
                          <th className="w-14 py-1.5" />
                        </tr>
                      </thead>
                      <tbody>
                        {/* Own children */}
                        {ownChildren.map((child) => {
                          const qty = child.qty_value ?? 1;
                          const raw = getRawDelta(child, target.cut_axis);
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
                                <span className={`font-mono ${raw != null ? 'text-gray-600' : 'text-gray-200'}`}>{raw != null ? `${raw}` : '—'}</span>
                              </td>
                              <td className="py-1 text-center">
                                <span className={`font-mono font-medium ${eff != null ? 'text-red-500' : 'text-gray-200'}`}>{eff != null ? `−${Math.abs(eff)}` : '—'}</span>
                              </td>
                              <td className="py-1 text-right pr-3">
                                <button type="button" onClick={() => navigateToItem(child.component_item_id)} className="p-0.5 rounded text-gray-300 hover:text-primary opacity-0 group-hover:opacity-100 transition-opacity" title="Edit in catalog">
                                  <ExternalLink className="h-3 w-3" />
                                </button>
                              </td>
                            </tr>
                          );
                        })}

                        {/* Affecting components + their children */}
                        {groupData.map(({ comp, children }) => {
                          const qty = comp.qty_value ?? 1;
                          const raw = getRawDelta(comp, target.cut_axis);
                          const eff = raw != null ? raw * qty : null;
                          const isModified = comp.id in localOverrides;
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
                                  <span className={`font-mono ${raw != null ? 'text-gray-600' : 'text-gray-200'}`}>{raw != null ? `${raw}` : '—'}</span>
                                </td>
                                <td className="py-1.5 text-center">
                                  <span className={`font-mono font-medium ${eff != null ? 'text-red-500' : 'text-gray-200'}`}>{eff != null ? `−${Math.abs(eff)}` : '—'}</span>
                                </td>
                                <td className="py-1.5 text-right pr-3">
                                  <div className="inline-flex items-center gap-0.5">
                                    <button type="button" onClick={() => navigateToItem(comp.component_item_id)} className="p-0.5 rounded text-gray-300 hover:text-primary" title="Edit in catalog">
                                      <ExternalLink className="h-3 w-3" />
                                    </button>
                                    <button type="button" onClick={() => handleRemove(comp.id)} className="p-0.5 rounded opacity-0 group-hover:opacity-100 text-gray-300 hover:text-red-500 transition-opacity" title="Remove">
                                      <X className="h-3 w-3" />
                                    </button>
                                  </div>
                                </td>
                              </tr>
                              {children.map((child) => {
                                const cqty = child.qty_value ?? 1;
                                const craw = getRawDelta(child, target.cut_axis);
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
                                      <span className={`font-mono ${craw != null ? 'text-gray-500' : 'text-gray-200'}`}>{craw != null ? `${craw}` : '—'}</span>
                                    </td>
                                    <td className="py-1 text-center">
                                      <span className={`font-mono font-medium ${ceff != null ? 'text-red-400' : 'text-gray-200'}`}>{ceff != null ? `−${Math.abs(ceff)}` : '—'}</span>
                                    </td>
                                    <td className="py-1 text-right pr-3">
                                      <button type="button" onClick={() => navigateToItem(child.component_item_id)} className="p-0.5 rounded text-gray-300 hover:text-primary opacity-0 group-hover:opacity-100 transition-opacity" title="Edit in catalog">
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

                  {/* Formula — single line */}
                  {grandTotal !== 0 && (
                    <div className="px-4 py-2 bg-gray-50/50 border-t border-gray-100 text-xs font-mono text-gray-500">
                      {getRoleLabel(role)} = Curtain {target.cut_axis === 'height' ? 'Height' : 'Width'} <span className="text-red-500">− {Math.abs(grandTotal)}</span> mm
                    </div>
                  )}

                  {/* Add component */}
                  {available.length > 0 && (
                    <div className="px-4 py-2 border-t border-gray-100">
                      {addingTo === role ? (
                        <div className="flex items-center gap-2">
                          <SelectShadcn
                            value=""
                            onValueChange={(val) => { if (val) handleAdd(role, val); }}
                          >
                            <SelectTrigger className="h-auto py-1 text-xs flex-1">
                              <SelectValue placeholder="Select component…" />
                            </SelectTrigger>
                            <SelectContent>
                              {available.map((c) => (
                                <SelectItem key={c.id} value={c.id}>
                                  {c.component_sku} — {c.component_name} ({getRoleLabel(c.component_role ?? '')})
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </SelectShadcn>
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

        {/* Unassigned — minimal */}
        {unassigned.length > 0 && (
          <div className="px-1 pt-2">
            <p className="text-xs text-gray-400 mb-1.5">Unassigned ({unassigned.length})</p>
            <div className="flex flex-wrap gap-1.5">
              {unassigned.map((c) => (
                <span key={c.id} className="text-xs font-mono text-gray-500 bg-gray-50 border border-gray-200 rounded px-2 py-0.5">
                  {c.component_sku}
                </span>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
});

export default EngineeringCutBreakdown;
