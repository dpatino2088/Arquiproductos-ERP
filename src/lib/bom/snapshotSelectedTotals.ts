type SnapshotItem = {
  kind?: string;
  selected?: boolean;
  line_total?: number | string | null;
  cost_total?: number | string | null;
  children?: SnapshotItem[];
};

type SnapshotTotals = {
  labor_amount?: number | string | null;
  accessories_total?: number | string | null;
  labor_cost?: number | string | null;
  unit_labor_cost?: number | string | null;
  accessories_total_cost?: number | string | null;
};

type SnapshotLike = {
  items?: SnapshotItem[];
  totals?: SnapshotTotals;
};

const toNumber = (value: unknown): number => {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
};

export type SelectedSnapshotTotals = {
  rollMsrp: number;
  bomMsrp: number;
  laborMsrp: number;
  accessoriesMsrp: number;
  totalMsrp: number;
  rollCost: number;
  bomCost: number;
  laborCost: number;
  accessoriesCost: number;
  totalCost: number;
};

/**
 * Computes monetary totals from bom_preview_snapshot counting only selected parents.
 * Children are counted only when their parent is selected.
 */
export function computeSelectedSnapshotTotals(snapshot: SnapshotLike | null | undefined): SelectedSnapshotTotals | null {
  if (!snapshot || !Array.isArray(snapshot.items) || snapshot.items.length === 0) return null;

  let rollMsrp = 0;
  let bomMsrp = 0;
  let rollCost = 0;
  let bomCost = 0;

  snapshot.items.forEach((item) => {
    const kind = String(item.kind || '').toLowerCase();

    if (kind === 'roll') {
      rollMsrp += toNumber(item.line_total);
      rollCost += toNumber(item.cost_total);
      return;
    }

    if (kind !== 'parent') return;
    if (item.selected !== true) return;

    bomMsrp += toNumber(item.line_total);
    bomCost += toNumber(item.cost_total);

    if (Array.isArray(item.children)) {
      item.children.forEach((child) => {
        bomMsrp += toNumber(child.line_total);
        bomCost += toNumber(child.cost_total);
      });
    }
  });

  const laborMsrp = toNumber(snapshot.totals?.labor_amount);
  const accessoriesMsrp = toNumber(snapshot.totals?.accessories_total);
  const laborCost = toNumber(snapshot.totals?.unit_labor_cost ?? snapshot.totals?.labor_cost);
  const accessoriesCost = toNumber(snapshot.totals?.accessories_total_cost);

  return {
    rollMsrp,
    bomMsrp,
    laborMsrp,
    accessoriesMsrp,
    totalMsrp: rollMsrp + bomMsrp + laborMsrp + accessoriesMsrp,
    rollCost,
    bomCost,
    laborCost,
    accessoriesCost,
    totalCost: rollCost + bomCost + laborCost + accessoriesCost,
  };
}
