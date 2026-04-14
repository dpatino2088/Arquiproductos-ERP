import { useMemo, useCallback } from 'react';
import { X, ChevronRight, Plus, ExternalLink } from 'lucide-react';
import { getRoleLabel } from '../../../lib/bom/roles';
import { getCascadeLabel } from './types';
import type { BOMComponentDraft } from './types';
import {
  Select as SelectShadcn,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../../../components/ui/SelectShadcn';

function openCatalogItem(catalogItemId: string | null | undefined) {
  if (!catalogItemId) return;
  window.open(`/catalog/items/edit/${catalogItemId}?returnTo=/catalog/bom`, '_blank');
}

type DeltaMode = 'subtract' | 'add' | 'info';

function parseRoles(str: string | null | undefined): string[] {
  if (!str) return [];
  return str.split(',').map(s => s.trim()).filter(Boolean);
}
function hasAffects(affectsRole: string | null | undefined, r: string): boolean {
  return parseRoles(affectsRole).includes(r);
}
function addAffects(affectsRole: string | null | undefined, r: string): string {
  const roles = parseRoles(affectsRole);
  if (!roles.includes(r)) roles.push(r);
  return roles.join(',');
}
function removeAffects(affectsRole: string | null | undefined, r: string): string | null {
  const roles = parseRoles(affectsRole).filter(x => x !== r);
  return roles.length > 0 ? roles.join(',') : null;
}

function wouldCreateCycle(
  depGraph: Map<string, string | null>,
  fromRole: string,
  toRole: string,
): boolean {
  const visited = new Set<string>();
  let current: string | null | undefined = toRole;
  while (current) {
    if (current === fromRole) return true;
    if (visited.has(current)) return false;
    visited.add(current);
    current = depGraph.get(current) ?? null;
  }
  return false;
}

export interface BOMEngineeringPopupProps {
  showPopup: boolean;
  editingComponentId: string | null;
  components: BOMComponentDraft[];
  childrenByParent: Record<string, BOMComponentDraft[]>;
  catalogItems: any[];
  isSaving?: boolean;
  onPatchComponent: (id: string, fields: Partial<BOMComponentDraft>) => void;
  onClose: () => void;
  onSave?: () => void;
  onSaveAndClose?: () => void;
}

export default function BOMEngineeringPopup({
  showPopup,
  editingComponentId,
  components,
  childrenByParent,
  catalogItems,
  isSaving,
  onPatchComponent,
  onClose,
  onSave,
  onSaveAndClose,
}: BOMEngineeringPopupProps) {
  const editingComponent = useMemo(
    () => components.find(c => c.id === editingComponentId) ?? null,
    [components, editingComponentId],
  );

  const parentComponents = useMemo(
    () => components.filter(c => !c.parent_component_id),
    [components],
  );

  const allComponents = components;

  // Cuttable roles — only these make sense for "Depends On" cascade
  const cuttableRoles = useMemo(() => {
    const roles = new Set<string>();
    for (const c of parentComponents) {
      if (!c.component_role) continue;
      const item = catalogItems.find((i: any) => i.id === c.component_item_id) || c.catalog_item;
      const mb = (item as any)?.measure_basis;
      if (mb === 'linear' || mb === 'area' || c.uom === 'm' || c.uom === 'm2') {
        roles.add(c.component_role);
      }
    }
    return Array.from(roles);
  }, [parentComponents, catalogItems]);

  // All unique parent roles — for "Affected by" (any component can deduct)
  const allParentRoles = useMemo(() => {
    const roles = new Set<string>();
    for (const c of parentComponents) {
      if (c.component_role) roles.add(c.component_role);
    }
    return Array.from(roles);
  }, [parentComponents]);

  const depGraph = useMemo(() => {
    const graph = new Map<string, string | null>();
    for (const c of parentComponents) {
      if (c.component_role) {
        graph.set(c.component_role, c.depends_on_role || null);
      }
    }
    return graph;
  }, [parentComponents]);

  const isCuttable = useMemo(() => {
    if (!editingComponent) return false;
    const item = catalogItems.find((i: any) => i.id === editingComponent.component_item_id) || editingComponent.catalog_item;
    const mb = (item as any)?.measure_basis;
    return mb === 'linear' || mb === 'area' || editingComponent.uom === 'm' || editingComponent.uom === 'm2';
  }, [editingComponent, catalogItems]);

  const role = editingComponent?.component_role ?? '';
  const isYAxis = editingComponent?.cut_axis === 'height';

  // Reverse lookup: find all components whose affects_role list contains this cuttable's role
  const affectedByComponents = useMemo(() => {
    if (!isCuttable || !role) return [];
    return allComponents.filter(
      c => hasAffects(c.affects_role, role) && c.id !== editingComponent?.id,
    );
  }, [isCuttable, role, allComponents, editingComponent]);

  // All own children (show all, let user configure delta_mode)
  const ownChildren = useMemo(() => {
    if (!editingComponent) return [];
    return childrenByParent[editingComponent.id] ?? [];
  }, [editingComponent, childrenByParent]);

  // Unique roles that affect this cuttable (derived from affects_role, not stored)
  const affectedByRoles = useMemo(() => {
    const roles = new Set<string>();
    for (const c of affectedByComponents) {
      if (c.component_role) roles.add(c.component_role);
    }
    return Array.from(roles);
  }, [affectedByComponents]);

  const cascadeChain = useMemo(() => {
    if (!isCuttable || !editingComponent) return [];
    const chain: Array<{ role: string; label: string }> = [];
    let current = editingComponent.depends_on_role;
    const visited = new Set<string>();
    while (current && !visited.has(current)) {
      visited.add(current);
      chain.unshift({ role: current, label: getRoleLabel(current) || current });
      const parent = parentComponents.find(c => c.component_role === current);
      current = parent?.depends_on_role ?? null;
    }
    chain.unshift({ role: '__base__', label: isYAxis ? 'Height' : 'Width' });
    chain.push({ role, label: getRoleLabel(role) || role });
    return chain;
  }, [isCuttable, editingComponent, role, parentComponents, isYAxis]);

  const baseOptions = useMemo(() => {
    if (!role) return [];
    return [
      { value: '', label: `Curtain ${isYAxis ? 'Height' : 'Width'}` },
      ...cuttableRoles
        .filter(r => r !== role && !wouldCreateCycle(depGraph, role, r))
        .map(r => ({ value: r, label: getRoleLabel(r) || r })),
    ];
  }, [role, isYAxis, cuttableRoles, depGraph]);

  const handleFieldChange = useCallback((field: keyof BOMComponentDraft, value: any) => {
    if (!editingComponentId) return;
    onPatchComponent(editingComponentId, { [field]: value });
  }, [editingComponentId, onPatchComponent]);

  // Add a role: append this cuttable's role to affects_role on all components of that role
  const handleAddAffectingRole = useCallback((newRole: string) => {
    const targets = allComponents.filter(
      c => c.component_role === newRole && !hasAffects(c.affects_role, role),
    );
    for (const t of targets) {
      onPatchComponent(t.id, { affects_role: addAffects(t.affects_role, role) });
    }
    for (const t of targets) {
      const kids = childrenByParent[t.id] ?? [];
      for (const kid of kids) {
        if (!hasAffects(kid.affects_role, role)) {
          const ci = catalogItems.find((i: any) => i.id === kid.component_item_id) || kid.catalog_item;
          const dx = isYAxis ? (ci as any)?.delta_y_mm : (ci as any)?.delta_x_mm;
          if (dx != null && dx !== 0) {
            onPatchComponent(kid.id, { affects_role: addAffects(kid.affects_role, role) });
          }
        }
      }
    }
  }, [role, isYAxis, allComponents, childrenByParent, catalogItems, onPatchComponent]);

  // Remove a role: remove this cuttable's role from affects_role on components of that role
  const handleRemoveAffectingRole = useCallback((roleToRemove: string) => {
    const targets = allComponents.filter(
      c => c.component_role === roleToRemove && hasAffects(c.affects_role, role),
    );
    for (const t of targets) {
      onPatchComponent(t.id, { affects_role: removeAffects(t.affects_role, role) });
    }
    for (const t of targets) {
      const kids = childrenByParent[t.id] ?? [];
      for (const kid of kids) {
        if (hasAffects(kid.affects_role, role)) {
          onPatchComponent(kid.id, { affects_role: removeAffects(kid.affects_role, role) });
        }
      }
    }
  }, [role, allComponents, childrenByParent, onPatchComponent]);

  if (!showPopup || !editingComponent) return null;

  const ci = catalogItems.find((i: any) => i.id === editingComponent.component_item_id) || editingComponent.catalog_item;
  const componentSku = (ci as any)?.sku || '—';
  const componentName = (ci as any)?.name || '';
  const deltaX = (ci as any)?.delta_x_mm;
  const deltaY = (ci as any)?.delta_y_mm;
  const availableRolesToAdd = allParentRoles.filter(r => r !== role && !affectedByRoles.includes(r));

  return (
    <div className="fixed inset-0 bg-black/40 z-[60] flex items-center justify-center p-4">
      <div
        className="bg-white max-w-xl w-full max-h-[80vh] flex flex-col rounded-lg shadow-xl"
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100 shrink-0">
          <div className="min-w-0">
            <p className="text-xs text-gray-500 truncate">
              <span className="text-sm font-semibold text-gray-900 mr-2">Engineering</span>
              <button
                type="button"
                onClick={() => openCatalogItem(editingComponent.component_item_id)}
                className="font-mono text-gray-600 hover:text-primary hover:underline inline-flex items-center gap-0.5"
                title="Open in Catalog (new tab)"
              >
                {componentSku}<ExternalLink className="h-2.5 w-2.5 opacity-40" />
              </button>
              {componentName && <span className="ml-1 text-gray-400">{componentName}</span>}
              <span className="ml-2 px-1.5 py-0.5 bg-gray-100 rounded text-[10px] font-medium text-gray-600">
                {getRoleLabel(role) || role}
              </span>
              {getCascadeLabel(role) && (
                <span className="ml-1 text-[10px] font-mono text-gray-300">{getCascadeLabel(role)?.split(' ')[0]}</span>
              )}
            </p>
          </div>
          <button type="button" onClick={onClose} className="p-1 rounded hover:bg-gray-100 text-gray-400 shrink-0" aria-label="Close">
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-4 py-3 space-y-4">
          {isCuttable ? (
            <>
              {/* Cascade chain */}
              <div className="flex items-center gap-1 text-[10px] text-gray-400">
                {cascadeChain.map((step, i) => (
                  <span key={step.role} className="flex items-center gap-0.5">
                    {i > 0 && <ChevronRight className="h-2.5 w-2.5 text-gray-300" />}
                    <span className={`px-1.5 py-0.5 rounded font-medium ${
                      i === cascadeChain.length - 1 ? 'bg-primary/10 text-primary' : 'text-gray-500'
                    }`}>
                      {step.label}
                    </span>
                  </span>
                ))}
              </div>

              {/* Settings row */}
              <div className="grid grid-cols-3 gap-2">
                <div>
                  <label className="text-[10px] text-gray-400 mb-0.5 block">Base dimension</label>
                  <SelectShadcn
                    value={editingComponent.depends_on_role || '__base__'}
                    onValueChange={v => handleFieldChange('depends_on_role', v === '__base__' ? null : v)}
                  >
                    <SelectTrigger className="h-auto py-1 text-xs w-full">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {baseOptions.map(o => (
                        <SelectItem key={o.value || '__base__'} value={o.value || '__base__'}>{o.label}</SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                </div>
                <div>
                  <label className="text-[10px] text-gray-400 mb-0.5 block">Tolerance (mm)</label>
                  <input
                    type="number"
                    value={editingComponent.cut_delta_mm || 0}
                    onChange={e => handleFieldChange('cut_delta_mm', Number(e.target.value) || 0)}
                    className="w-full text-xs border border-gray-200 rounded px-2 py-1 bg-white font-mono text-right focus:outline-none focus:ring-1 focus:ring-primary/30"
                  />
                </div>
                <div>
                  <label className="text-[10px] text-gray-400 mb-0.5 block">Cut Axis</label>
                  <SelectShadcn
                    value={editingComponent.cut_axis || 'width'}
                    onValueChange={v => handleFieldChange('cut_axis', v)}
                  >
                    <SelectTrigger className="h-auto py-1 text-xs w-full">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="width">Width (X)</SelectItem>
                      <SelectItem value="height">Height (Y)</SelectItem>
                    </SelectContent>
                  </SelectShadcn>
                </div>
              </div>

              {/* Deductions — roles that subtract from this cuttable's dimension */}
              <div>
                <div className="flex items-center gap-1.5 flex-wrap mb-2">
                  <span className="text-[10px] text-gray-400 font-medium mr-0.5">Deductions:</span>
                  {affectedByRoles.map(r => (
                    <span key={r} className="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded text-[10px] font-medium bg-indigo-50 text-indigo-600">
                      {getRoleLabel(r) || r}
                      <button type="button" onClick={() => handleRemoveAffectingRole(r)} className="ml-0.5 text-indigo-300 hover:text-red-400">
                        <X className="h-2.5 w-2.5" />
                      </button>
                    </span>
                  ))}
                  {ownChildren.length > 0 && (
                    <span className="px-1.5 py-0.5 rounded text-[10px] font-medium bg-gray-100 text-gray-500">
                      own children
                    </span>
                  )}
                  {affectedByRoles.length === 0 && ownChildren.length === 0 && (
                    <span className="text-[10px] text-gray-300 italic">none</span>
                  )}
                  {availableRolesToAdd.length > 0 && (
                    <SelectShadcn
                      value=""
                      onValueChange={v => { if (v) handleAddAffectingRole(v); }}
                    >
                      <SelectTrigger className="h-auto py-0.5 px-1.5 text-[10px] text-primary/60 hover:text-primary font-medium border-0 shadow-none w-auto gap-0.5 inline-flex">
                        <Plus className="h-2.5 w-2.5" />
                        <span>add</span>
                      </SelectTrigger>
                      <SelectContent>
                        {availableRolesToAdd.map(r => (
                          <SelectItem key={r} value={r}>{getRoleLabel(r) || r}</SelectItem>
                        ))}
                      </SelectContent>
                    </SelectShadcn>
                  )}
                </div>

                {/* Show deducting components grouped by parent role in cascade order */}
                {(affectedByComponents.length > 0 || ownChildren.length > 0) && (
                  <div className="rounded border border-gray-100 divide-y divide-gray-50 overflow-hidden">
                    {(() => {
                      const externalParents = affectedByComponents.filter(c => !c.parent_component_id);
                      const externalChildren = affectedByComponents.filter(c => !!c.parent_component_id);

                      const getChildrenDelta = (parentId: string) => {
                        const kids = (childrenByParent[parentId] ?? []).filter(
                          k => hasAffects(k.affects_role, role),
                        );
                        let sum = 0;
                        for (const k of kids) {
                          const kCi = catalogItems.find((i: any) => i.id === k.component_item_id) || k.catalog_item;
                          const kd = isYAxis ? (kCi as any)?.delta_y_mm : (kCi as any)?.delta_x_mm;
                          if (kd != null && kd !== 0) sum += kd * (k.qty_value ?? 1);
                        }
                        return sum;
                      };

                      return (
                        <>
                          {/* Editing component itself + own children first */}
                          {ownChildren.length > 0 && (
                            <div>
                              <div className="flex items-center gap-2 px-2.5 py-1.5 border-l-2 border-l-primary bg-primary/5">
                                <button
                                  type="button"
                                  onClick={() => openCatalogItem(editingComponent!.component_item_id)}
                                  className="font-mono text-xs font-semibold text-gray-800 hover:text-primary hover:underline shrink-0"
                                >
                                  {componentSku}
                                </button>
                                <span className="text-[10px] text-gray-400">{getRoleLabel(role) || role}</span>
                                <span className="flex-1" />
                                <span className="text-[10px] text-gray-400">own children</span>
                              </div>
                              {ownChildren.map(ch => {
                                const chCi2 = catalogItems.find((i: any) => i.id === ch.component_item_id) || ch.catalog_item;
                                const dx2 = isYAxis ? (chCi2 as any)?.delta_y_mm : (chCi2 as any)?.delta_x_mm;
                                const chMode2 = (ch.delta_mode || 'subtract') as DeltaMode;
                                const modeColor2 = chMode2 === 'subtract' ? 'bg-red-50 text-red-600'
                                  : chMode2 === 'add' ? 'bg-green-50 text-green-700'
                                    : 'bg-gray-50 text-gray-400';
                                const valColor2 = chMode2 === 'subtract' ? 'text-red-500'
                                  : chMode2 === 'add' ? 'text-green-600' : 'text-gray-300';
                                return (
                                  <div key={ch.id} className="flex items-center gap-2 px-2.5 py-1.5 pl-5 border-l-2 border-l-primary/30">
                                    <span className="text-gray-300 text-[10px] -ml-2">↳</span>
                                    <button type="button" onClick={() => openCatalogItem(ch.component_item_id)} className="font-mono text-xs text-gray-700 hover:text-primary hover:underline shrink-0">
                                      {(chCi2 as any)?.sku || '?'}
                                    </button>
                                    <span className="flex-1" />
                                    <select
                                      value={chMode2}
                                      onChange={e => onPatchComponent(ch.id, { delta_mode: e.target.value as DeltaMode })}
                                      className={`text-[10px] font-medium px-1 py-0.5 rounded border-0 cursor-pointer focus:outline-none w-14 ${modeColor2}`}
                                    >
                                      <option value="subtract">−Sub</option>
                                      <option value="add">+Add</option>
                                      <option value="info">Info</option>
                                    </select>
                                    <span className={`text-xs font-mono font-medium tabular-nums w-14 text-right ${valColor2}`}>
                                      {chMode2 === 'info' ? '' : dx2 != null && dx2 !== 0
                                        ? `${chMode2 === 'subtract' ? '−' : '+'}${dx2}${(ch.qty_value ?? 1) > 1 ? `×${ch.qty_value}` : ''}`
                                        : '—'}
                                    </span>
                                  </div>
                                );
                              })}
                            </div>
                          )}
                          {/* External parents — children summed into parent delta */}
                          {externalParents.map(parent => {
                            const compCi = catalogItems.find((i: any) => i.id === parent.component_item_id) || parent.catalog_item;
                            const parentDx = isYAxis ? (compCi as any)?.delta_y_mm ?? 0 : (compCi as any)?.delta_x_mm ?? 0;
                            const parentQty = parent.qty_value ?? 1;
                            const childrenSum = getChildrenDelta(parent.id);
                            const totalPerUnit = parentDx + childrenSum;
                            const cond = parent.condition_key ? `${parent.condition_key}=${parent.condition_value || '?'}` : null;
                            return (
                              <div
                                key={parent.id}
                                className="flex items-center gap-2 px-2.5 py-1.5 border-l-2 border-l-indigo-300"
                              >
                                <button
                                  type="button"
                                  onClick={() => openCatalogItem(parent.component_item_id)}
                                  className="font-mono text-xs text-gray-700 hover:text-primary hover:underline shrink-0"
                                >
                                  {(compCi as any)?.sku || '?'}
                                </button>
                                <span className="text-[10px] text-gray-400">{getRoleLabel(parent.component_role) || parent.component_role}</span>
                                {cond && (
                                  <span className="text-[9px] px-1 py-px bg-purple-50 text-purple-500 rounded font-mono shrink-0">{cond}</span>
                                )}
                                {childrenSum !== 0 && (
                                  <span className="text-[9px] px-1 py-px bg-gray-100 text-gray-500 rounded font-mono shrink-0">
                                    +children
                                  </span>
                                )}
                                <span className="flex-1" />
                                <span className="text-xs font-mono font-medium tabular-nums text-red-500">
                                  {totalPerUnit !== 0
                                    ? `−${totalPerUnit}${parentQty > 1 ? `×${parentQty}` : ''}`
                                    : <span className="text-gray-300">—</span>}
                                </span>
                              </div>
                            );
                          })}
                        </>
                      );
                    })()}
                  </div>
                )}
              </div>
            </>
          ) : (
            /* ── Unit component view ── */
            <>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-[10px] text-gray-400 mb-0.5 block">Affects (deducts from)</label>
                  <div className="flex items-center gap-1 flex-wrap min-h-[28px] border border-gray-200 rounded px-2 py-1 bg-white">
                    {parseRoles(editingComponent.affects_role).map(r => (
                      <span key={r} className="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded text-[10px] font-medium bg-indigo-50 text-indigo-600">
                        {getRoleLabel(r) || r}
                        <button type="button" onClick={() => handleFieldChange('affects_role', removeAffects(editingComponent.affects_role, r))} className="ml-0.5 text-indigo-300 hover:text-red-400">
                          <X className="h-2.5 w-2.5" />
                        </button>
                      </span>
                    ))}
                    {(() => {
                      const currentRoles = parseRoles(editingComponent.affects_role);
                      const available = allParentRoles.filter(r => r !== role && !currentRoles.includes(r));
                      if (available.length === 0) return null;
                      return (
                        <SelectShadcn value="" onValueChange={v => { if (v) handleFieldChange('affects_role', addAffects(editingComponent.affects_role, v)); }}>
                          <SelectTrigger className="h-auto py-0 px-1 text-[10px] text-primary/60 hover:text-primary font-medium border-0 shadow-none w-auto gap-0.5 inline-flex">
                            <Plus className="h-2.5 w-2.5" /><span>add</span>
                          </SelectTrigger>
                          <SelectContent>
                            {available.map(r => (
                              <SelectItem key={r} value={r}>{getRoleLabel(r) || r}</SelectItem>
                            ))}
                          </SelectContent>
                        </SelectShadcn>
                      );
                    })()}
                    {parseRoles(editingComponent.affects_role).length === 0 && (
                      <span className="text-[10px] text-gray-300 italic">none</span>
                    )}
                  </div>
                </div>
                <div>
                  <label className="text-[10px] text-gray-400 mb-0.5 block">Deduction Mode</label>
                  <SelectShadcn
                    value={editingComponent.delta_mode || 'subtract'}
                    onValueChange={v => handleFieldChange('delta_mode', v as DeltaMode)}
                  >
                    <SelectTrigger className="h-auto py-1 text-xs w-full">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="subtract">− Subtract</SelectItem>
                      <SelectItem value="add">+ Add</SelectItem>
                      <SelectItem value="info">Info (no deduction)</SelectItem>
                    </SelectContent>
                  </SelectShadcn>
                </div>
              </div>

              <div className="flex items-center gap-4 text-[10px] text-gray-500">
                <span>ΔX <span className="font-mono font-medium text-gray-700">{deltaX != null ? `${deltaX} mm` : '—'}</span></span>
                <span>ΔY <span className="font-mono font-medium text-gray-700">{deltaY != null ? `${deltaY} mm` : '—'}</span></span>
                {deltaX == null && deltaY == null && (
                  <button
                    type="button"
                    onClick={() => openCatalogItem(editingComponent.component_item_id)}
                    className="text-amber-500 hover:text-amber-700 inline-flex items-center gap-0.5"
                  >
                    Set in catalog <ExternalLink className="h-2.5 w-2.5" />
                  </button>
                )}
              </div>

              {editingComponent.condition_key && (
                <p className="text-[10px] text-gray-500">
                  Condition: <span className="font-mono px-1 py-0.5 bg-purple-50 text-purple-600 rounded">{editingComponent.condition_key} = {editingComponent.condition_value || '?'}</span>
                </p>
              )}
            </>
          )}
        </div>

        {/* Footer */}
        <div className="px-4 py-2.5 border-t border-gray-100 shrink-0 flex justify-end gap-2">
          <button type="button" onClick={onClose} className="px-3 py-1.5 text-xs text-gray-500 hover:text-gray-700">
            Close
          </button>
          {onSave && (
            <button
              type="button"
              onClick={onSave}
              disabled={isSaving}
              className="px-3 py-1.5 text-xs font-medium text-gray-700 bg-white border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50"
            >
              {isSaving ? 'Saving…' : 'Save'}
            </button>
          )}
          {onSaveAndClose && (
            <button
              type="button"
              onClick={onSaveAndClose}
              disabled={isSaving}
              className="px-3 py-1.5 text-xs font-medium text-white bg-primary rounded hover:opacity-90 disabled:opacity-50"
            >
              Save & Close
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
