import { useMemo, useState } from 'react';
import { AlertTriangle, Loader2, RefreshCw, Search } from 'lucide-react';
import { formatCurrency } from '../../lib/utils';
import {
  useListMOMaterialSubstitutes,
  type MOMaterialSubstituteCandidate,
} from '../../hooks/useInventoryAllocations';

export interface ReplaceMaterialTarget {
  catalog_item_id: string;
  sku: string;
  item_name: string;
  uom: string;
  /** Locked BIL / aggregate part role (e.g. tube, fabric) */
  part_role?: string;
  unitCost?: number;
  bomInstanceLineIds?: string[];
}

interface Props {
  moId: string;
  warehouseId: string;
  target: ReplaceMaterialTarget;
  requiredQty: number;
  canViewCosts?: boolean;
  currency?: string;
  isSubstituting: boolean;
  onClose: () => void;
  onConfirm: (candidate: MOMaterialSubstituteCandidate, reason?: string) => Promise<void>;
}

export default function ReplaceMaterialModal({
  moId,
  warehouseId,
  target,
  requiredQty,
  canViewCosts = false,
  currency = 'USD',
  isSubstituting,
  onClose,
  onConfirm,
}: Props) {
  const [search, setSearch] = useState('');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [reason, setReason] = useState('');
  const { candidates, part_roles, slot_hierarchy, loading, error } = useListMOMaterialSubstitutes(
    moId,
    target.catalog_item_id,
    warehouseId,
    true,
    target.part_role,
  );

  const originalUnitCost = target.unitCost ?? 0;
  const fmtQty = (qty: number) => (target.uom === 'm' || target.uom === 'm2' ? qty.toFixed(2) : qty.toFixed(0));

  const lockedRole =
    target.part_role?.trim() ||
    part_roles?.[0] ||
    null;
  const roleHint =
    lockedRole && slot_hierarchy && slot_hierarchy !== 'role' && slot_hierarchy !== lockedRole
      ? `Role: ${lockedRole} · ${slot_hierarchy}`
      : lockedRole
        ? `Role: ${lockedRole}`
        : null;

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return candidates;
    return candidates.filter(
      (c) => c.sku.toLowerCase().includes(q) || c.name.toLowerCase().includes(q),
    );
  }, [candidates, search]);

  const selected = filtered.find((c) => c.catalog_item_id === selectedId) ?? null;
  const enoughStock = selected ? selected.available_qty + 0.0001 >= requiredQty : false;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />
      <div className="relative bg-white rounded-xl shadow-2xl w-full max-w-2xl max-h-[85vh] flex flex-col">
        <div className="px-5 py-4 border-b">
          <h3 className="text-base font-semibold text-gray-900">Replace material</h3>
          {roleHint && (
            <p className="text-xs font-medium text-violet-700 mt-1">{roleHint}</p>
          )}
          <p className="text-sm text-gray-600 mt-1">
            Swap <span className="font-mono font-medium">{target.sku}</span>
            {' '}({target.item_name}) with another SKU that fills the same BOM slot (role, hierarchy, template) and has stock.
            Selling price on the sales order is unchanged.
          </p>
          <p className="text-xs text-gray-500 mt-1">
            Need {fmtQty(requiredQty)} {target.uom}
            {canViewCosts && originalUnitCost > 0 && (
              <> · current unit cost {formatCurrency(originalUnitCost, currency)}</>
            )}
          </p>
        </div>

        <div className="px-5 py-3 border-b">
          <div className="relative">
            <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-400" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search SKU or name…"
              className="w-full pl-8 pr-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-1 focus:ring-primary focus:border-primary"
              autoFocus
            />
          </div>
        </div>

        <div className="flex-1 overflow-y-auto px-5 py-3 min-h-[200px]">
          {loading ? (
            <div className="flex items-center justify-center py-10 text-sm text-gray-400">
              <Loader2 className="w-4 h-4 animate-spin mr-2" /> Loading substitutes…
            </div>
          ) : error ? (
            <div className="flex items-start gap-2 py-6 text-sm text-red-600">
              <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5" />
              {error}
            </div>
          ) : filtered.length === 0 ? (
            <div className="py-10 text-center text-sm text-gray-400">
              No in-stock substitutes with the same role and measure type.
            </div>
          ) : (
            <table className="w-full text-sm">
              <thead>
                <tr className="text-xs text-gray-500 border-b">
                  <th className="w-8 py-2" />
                  <th className="text-left py-2 font-medium">SKU</th>
                  <th className="text-left py-2 font-medium">Item</th>
                  <th className="text-right py-2 font-medium">Available</th>
                  {canViewCosts && <th className="text-right py-2 font-medium">Unit cost</th>}
                  {canViewCosts && <th className="text-right py-2 font-medium">Δ vs original</th>}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filtered.map((c) => {
                  const delta = c.unit_cost - originalUnitCost;
                  const canCover = c.available_qty + 0.0001 >= requiredQty;
                  return (
                    <tr
                      key={c.catalog_item_id}
                      className={`cursor-pointer ${selectedId === c.catalog_item_id ? 'bg-violet-50' : 'hover:bg-gray-50'} ${!canCover ? 'opacity-60' : ''}`}
                      onClick={() => setSelectedId(c.catalog_item_id)}
                    >
                      <td className="py-2 pr-1 text-center">
                        <input
                          type="radio"
                          name="substitute"
                          checked={selectedId === c.catalog_item_id}
                          onChange={() => setSelectedId(c.catalog_item_id)}
                          className="accent-violet-600"
                        />
                      </td>
                      <td className="py-2 font-mono text-xs text-gray-900">{c.sku}</td>
                      <td className="py-2 text-xs text-gray-700 truncate max-w-[220px]" title={c.name}>{c.name}</td>
                      <td className={`py-2 text-right tabular-nums text-xs ${canCover ? 'text-green-700' : 'text-red-600'}`}>
                        {fmtQty(c.available_qty)} {c.uom}
                      </td>
                      {canViewCosts && (
                        <td className="py-2 text-right tabular-nums text-xs">
                          {formatCurrency(c.unit_cost, currency)}
                        </td>
                      )}
                      {canViewCosts && (
                        <td className={`py-2 text-right tabular-nums text-xs font-medium ${delta < -0.0001 ? 'text-green-700' : delta > 0.0001 ? 'text-red-600' : 'text-gray-500'}`}>
                          {delta > 0 ? '+' : ''}{formatCurrency(delta, currency)}
                        </td>
                      )}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>

        <div className="px-5 py-3 border-t space-y-3">
          <input
            type="text"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="Reason (optional)"
            className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg"
          />
          {selected && !enoughStock && (
            <p className="text-xs text-red-600 flex items-center gap-1">
              <AlertTriangle className="w-3.5 h-3.5" />
              Available stock ({fmtQty(selected.available_qty)}) is less than required ({fmtQty(requiredQty)}).
            </p>
          )}
          <div className="flex justify-end gap-2">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubstituting}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200 disabled:opacity-50"
            >
              Cancel
            </button>
            <button
              type="button"
              disabled={!selected || !enoughStock || isSubstituting}
              onClick={() => selected && onConfirm(selected, reason.trim() || undefined)}
              className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-white bg-violet-600 rounded-lg hover:bg-violet-700 disabled:opacity-50"
            >
              {isSubstituting ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <RefreshCw className="w-3.5 h-3.5" />}
              Confirm replace
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
