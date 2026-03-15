/**
 * Cascade Priority
 *
 * Shared constants and helpers for BOM cascade resolution order.
 * Lower numbers resolve first; components with depends_on_role must
 * have a HIGHER priority number than the role they depend on.
 */

import { normalizeRole } from './roles';

export interface CascadePriorityEntry {
  order: number;
  axis: 'x' | 'y' | null;
  defaultDependsOn: string | null;
  label: string;
}

export const CASCADE_PRIORITY: Record<string, CascadePriorityEntry> = {
  headbox:         { order: 10, axis: 'x', defaultDependsOn: null,   label: '① Headbox / Cassette' },
  cassette:        { order: 10, axis: 'x', defaultDependsOn: null,   label: '① Headbox / Cassette' },
  top_rail:        { order: 10, axis: 'x', defaultDependsOn: null,   label: '① Top Rail' },
  tube:            { order: 20, axis: 'x', defaultDependsOn: null,   label: '② Tube' },
  track:           { order: 20, axis: 'x', defaultDependsOn: null,   label: '② Track' },
  bottom_bar:      { order: 30, axis: 'x', defaultDependsOn: 'tube', label: '③ Bottom Bar' },
  hem_weight:      { order: 35, axis: 'x', defaultDependsOn: 'tube', label: '③ Hem Weight' },
  fabric:          { order: 40, axis: null, defaultDependsOn: 'tube', label: '④ Fabric' },
  side_channel:    { order: 50, axis: 'y', defaultDependsOn: null,   label: '⑤ Side Channel' },
  bottom_channel:  { order: 60, axis: 'x', defaultDependsOn: 'bottom_bar', label: '⑥ Bottom Channel' },
  chain:           { order: 70, axis: 'y', defaultDependsOn: null,   label: '⑦ Chain' },
  belt:            { order: 70, axis: 'y', defaultDependsOn: null,   label: '⑦ Belt' },
  brush:           { order: 75, axis: 'y', defaultDependsOn: 'side_channel', label: '⑧ Brush' },
  bracket:         { order: 80, axis: null, defaultDependsOn: null,  label: '⑨ Bracket' },
  end_cap:         { order: 80, axis: null, defaultDependsOn: null,  label: '⑨ End Cap' },
  idler:           { order: 80, axis: null, defaultDependsOn: null,  label: '⑨ Idler' },
  drive:           { order: 85, axis: null, defaultDependsOn: null,  label: '⑩ Drive' },
  motor:           { order: 85, axis: null, defaultDependsOn: null,  label: '⑩ Motor' },
  wand:            { order: 85, axis: null, defaultDependsOn: null,  label: '⑩ Wand' },
  carrier:         { order: 86, axis: null, defaultDependsOn: null,  label: '⑩ Carrier' },
  hook:            { order: 86, axis: null, defaultDependsOn: null,  label: '⑩ Hook' },
  glider:          { order: 86, axis: null, defaultDependsOn: null,  label: '⑩ Glider' },
  mounting_clip:   { order: 86, axis: null, defaultDependsOn: null,  label: '⑩ Mounting Clip' },
  adapter:         { order: 88, axis: null, defaultDependsOn: null,  label: '⑪ Adapter' },
  filler:          { order: 88, axis: null, defaultDependsOn: null,  label: '⑪ Filler' },
  tape:            { order: 88, axis: null, defaultDependsOn: null,  label: '⑪ Tape' },
  consumable:      { order: 90, axis: null, defaultDependsOn: null,  label: '⑫ Consumable' },
  fastener:        { order: 90, axis: null, defaultDependsOn: null,  label: '⑫ Fastener' },
  accessory:       { order: 95, axis: null, defaultDependsOn: null,  label: '⑫ Accessory' },
};

const DEFAULT_CASCADE_ORDER = 99;

export function getCascadeOrder(role: string | null | undefined): number {
  if (!role) return DEFAULT_CASCADE_ORDER;
  const n = normalizeRole(role);
  return n && CASCADE_PRIORITY[n] ? CASCADE_PRIORITY[n].order : DEFAULT_CASCADE_ORDER;
}

export function getCascadeLabel(role: string | null | undefined): string | null {
  if (!role) return null;
  const n = normalizeRole(role);
  return n && CASCADE_PRIORITY[n] ? CASCADE_PRIORITY[n].label : null;
}

export function getCascadeAxis(role: string | null | undefined): 'x' | 'y' | null {
  if (!role) return null;
  const n = normalizeRole(role);
  return n && CASCADE_PRIORITY[n] ? CASCADE_PRIORITY[n].axis : null;
}

export function getDefaultDependsOn(role: string | null | undefined): string | null {
  if (!role) return null;
  const n = normalizeRole(role);
  return n && CASCADE_PRIORITY[n] ? CASCADE_PRIORITY[n].defaultDependsOn : null;
}
