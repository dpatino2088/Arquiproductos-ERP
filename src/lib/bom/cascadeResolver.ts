/**
 * Cascade Resolver
 *
 * Resolves BOM component cut dimensions in topological (cascade) order.
 * Components with depends_on_role take their base measurement from the
 * already-resolved cut of the referenced role, not from the raw product
 * width/height.
 */

export interface CascadeComponent {
  id: string;
  role: string;
  depends_on_role: string | null;
  affects_role: string | null;
  cut_delta_mm: number;
  cut_delta_scope: string | null; // 'per_side' | 'per_item' | null
  qty: number;
  measure_basis: string | null; // 'linear' | 'area' | 'unit'
  is_roll: boolean;
  cut_axis: string | null; // 'width' | 'height' | 'length' | null
  cascade_order: number;
  catalog_delta_x_mm: number | null;
  catalog_delta_y_mm: number | null;
}

export interface CascadeInput {
  width_mm: number;
  height_mm: number;
  components: CascadeComponent[];
}

export interface ResolvedCut {
  role: string;
  component_id: string;
  base_source: string; // 'width_mm' | 'height_mm' | role name
  base_value_mm: number;
  deltas: Array<{
    source_role: string;
    source_id: string;
    delta_mm: number;
    scope: string | null;
    description: string;
  }>;
  resolved_mm: number;
}

export interface CascadeResult {
  resolved: Map<string, ResolvedCut>;
  order: string[]; // roles in resolution order
}

export function resolveCascade(input: CascadeInput): CascadeResult {
  const { width_mm, height_mm, components } = input;

  const cuttable = components
    .filter(c => c.measure_basis === 'linear' || c.measure_basis === 'area')
    .sort((a, b) => a.cascade_order - b.cascade_order);

  const units = components.filter(
    c => c.measure_basis !== 'linear' && c.measure_basis !== 'area',
  );

  const resolved = new Map<string, ResolvedCut>();
  const order: string[] = [];

  // Build affects_role index: which unit items affect which cuttable roles
  // affects_role may be comma-separated (e.g. "tube,side_channel")
  const affectingByRole = new Map<string, CascadeComponent[]>();
  for (const u of units) {
    if (u.affects_role) {
      const roles = u.affects_role.split(',').map(s => s.trim()).filter(Boolean);
      for (const r of roles) {
        if (!affectingByRole.has(r)) affectingByRole.set(r, []);
        affectingByRole.get(r)!.push(u);
      }
    }
  }

  for (const comp of cuttable) {
    const role = comp.role;
    const isYAxis = comp.cut_axis === 'height' || role === 'side_channel' || role === 'brush' || role === 'chain' || role === 'belt';

    let baseSource: string;
    let baseValue: number;

    if (comp.depends_on_role && resolved.has(comp.depends_on_role)) {
      baseSource = comp.depends_on_role;
      baseValue = resolved.get(comp.depends_on_role)!.resolved_mm;
    } else {
      baseSource = isYAxis ? 'height_mm' : 'width_mm';
      baseValue = isYAxis ? height_mm : width_mm;
    }

    const deltas: ResolvedCut['deltas'] = [];

    // Own cut_delta_mm (from BOMComponent engineering rule)
    if (comp.cut_delta_mm !== 0) {
      let d = comp.cut_delta_mm;
      if (comp.cut_delta_scope === 'per_side') d *= 2;
      deltas.push({
        source_role: role,
        source_id: comp.id,
        delta_mm: d,
        scope: comp.cut_delta_scope,
        description: `own delta${comp.cut_delta_scope === 'per_side' ? ' (×2 per_side)' : ''}`,
      });
    }

    // Deltas from unit items that affect this role
    const affecting = affectingByRole.get(role) ?? [];
    for (const a of affecting) {
      const rawDelta = isYAxis
        ? (a.catalog_delta_y_mm ?? 0)
        : (a.catalog_delta_x_mm ?? 0);
      if (rawDelta === 0) continue;

      let totalDelta: number;
      let desc: string;
      if (a.cut_delta_scope === 'per_side') {
        totalDelta = rawDelta * 2;
        desc = `${a.role} ΔX=${rawDelta} ×2 (per_side)`;
      } else if (a.cut_delta_scope === 'per_item') {
        totalDelta = rawDelta * a.qty;
        desc = `${a.role} ΔX=${rawDelta} ×${a.qty} (per_item)`;
      } else {
        totalDelta = rawDelta * a.qty;
        desc = `${a.role} ΔX=${rawDelta} ×${a.qty}`;
      }

      deltas.push({
        source_role: a.role,
        source_id: a.id,
        delta_mm: totalDelta,
        scope: a.cut_delta_scope,
        description: desc,
      });
    }

    const totalDelta = deltas.reduce((s, d) => s + d.delta_mm, 0);
    const resolvedMm = baseValue + totalDelta;

    const cut: ResolvedCut = {
      role,
      component_id: comp.id,
      base_source: baseSource,
      base_value_mm: baseValue,
      deltas,
      resolved_mm: Math.max(0, resolvedMm),
    };

    resolved.set(role, cut);
    order.push(role);
  }

  return { resolved, order };
}
