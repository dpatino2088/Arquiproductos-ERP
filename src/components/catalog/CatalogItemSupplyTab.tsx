import { useEffect, useState } from 'react';
import Label from '../ui/Label';
import Input from '../ui/Input';
import Button from '../ui/Button';
import {
  Select as SelectShadcn,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../ui/SelectShadcn';
import {
  fetchCatalogItemSupply,
  SupplyOrigin,
  SupplyType,
  upsertCatalogItemSupply,
} from '../../services/catalogItemSupply';

type LeadTimeUnit = 'days' | 'weeks' | 'months';

function toDays(value: number, unit: LeadTimeUnit) {
  if (unit === 'weeks') return value * 7;
  if (unit === 'months') return value * 30;
  return value;
}

function fromDays(days: number, unit: LeadTimeUnit) {
  if (unit === 'weeks') return Math.round(days / 7);
  if (unit === 'months') return Math.round(days / 30);
  return days;
}

function inferUnit(minDays: number, maxDays: number): LeadTimeUnit {
  const isMonths = minDays % 30 === 0 && maxDays % 30 === 0;
  if (isMonths) return 'months';
  const isWeeks = minDays % 7 === 0 && maxDays % 7 === 0;
  if (isWeeks) return 'weeks';
  return 'days';
}

type Props = {
  catalogItemId: string;
  organizationId: string;
  readOnly?: boolean;
};

export function CatalogItemSupplyTab({ catalogItemId, organizationId, readOnly = false }: Props) {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [supplyType, setSupplyType] = useState<SupplyType>('stock');
  const [supplyOrigin, setSupplyOrigin] = useState<SupplyOrigin>('local');
  const [unit, setUnit] = useState<LeadTimeUnit>('days');
  const [minVal, setMinVal] = useState(7);
  const [maxVal, setMaxVal] = useState(8);
  const [notes, setNotes] = useState('');

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    setError(null);

    fetchCatalogItemSupply(catalogItemId, organizationId)
      .then((data) => {
        if (!mounted) return;
        if (data) {
          setSupplyType(data.supply_type);
          setSupplyOrigin(data.supply_origin);
          setNotes(data.notes ?? '');

          const u = inferUnit(data.lead_time_min_days, data.lead_time_max_days);
          setUnit(u);
          setMinVal(fromDays(data.lead_time_min_days, u));
          setMaxVal(fromDays(data.lead_time_max_days, u));
        }
      })
      .catch((err) => {
        if (!mounted) return;
        setError(err?.message || 'Failed to load supply info');
      })
      .finally(() => {
        if (!mounted) return;
        setLoading(false);
      });

    return () => {
      mounted = false;
    };
  }, [catalogItemId, organizationId]);

  async function handleSave() {
    setError(null);

    const minDays = toDays(minVal, unit);
    const maxDays = toDays(maxVal, unit);

    if (minDays < 0 || maxDays < 0) {
      setError('Lead time days must be >= 0');
      return;
    }
    if (minDays > maxDays) {
      setError('Min days must be <= Max days');
      return;
    }

    setSaving(true);
    try {
      await upsertCatalogItemSupply({
        catalog_item_id: catalogItemId,
        organization_id: organizationId,
        supply_type: supplyType,
        supply_origin: supplyOrigin,
        lead_time_min_days: minDays,
        lead_time_max_days: maxDays,
        notes: notes.trim() ? notes.trim() : null,
      });
    } catch (err: any) {
      setError(err?.message || 'Failed to save supply info');
      return;
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <div className="text-sm text-gray-500">Loading supply info…</div>;

  return (
    <div className="space-y-4 max-w-2xl">
      {error && (
        <div className="p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {error}
        </div>
      )}

      <div className="grid grid-cols-12 gap-4">
        <div className="col-span-6">
          <Label className="text-xs">Supply Type</Label>
          <SelectShadcn
            value={supplyType}
            onValueChange={(value) => setSupplyType(value as SupplyType)}
            disabled={readOnly}
          >
            <SelectTrigger className="h-auto py-1 text-xs w-full">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="stock">Stock</SelectItem>
              <SelectItem value="order">To order</SelectItem>
            </SelectContent>
          </SelectShadcn>
        </div>

        <div className="col-span-6">
          <Label className="text-xs">Origin</Label>
          <SelectShadcn
            value={supplyOrigin}
            onValueChange={(value) => setSupplyOrigin(value as SupplyOrigin)}
            disabled={readOnly}
          >
            <SelectTrigger className="h-auto py-1 text-xs w-full">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="local">Local</SelectItem>
              <SelectItem value="import">Import</SelectItem>
            </SelectContent>
          </SelectShadcn>
        </div>

        <div className="col-span-3">
          <Label className="text-xs">Lead time unit</Label>
          <SelectShadcn
            value={unit}
            onValueChange={(value) => {
              const next = value as LeadTimeUnit;
              const currentMinDays = toDays(minVal, unit);
              const currentMaxDays = toDays(maxVal, unit);
              setUnit(next);
              setMinVal(fromDays(currentMinDays, next));
              setMaxVal(fromDays(currentMaxDays, next));
            }}
            disabled={readOnly}
          >
            <SelectTrigger className="h-auto py-1 text-xs w-full">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="days">Days</SelectItem>
              <SelectItem value="weeks">Weeks</SelectItem>
              <SelectItem value="months">Months</SelectItem>
            </SelectContent>
          </SelectShadcn>
        </div>

        <div className="col-span-3">
          <Label className="text-xs">Min</Label>
          <Input
            type="number"
            min="0"
            step="1"
            value={minVal}
            onChange={(e) => setMinVal(Number(e.target.value))}
            className="py-1 text-xs w-full"
            disabled={readOnly}
          />
        </div>

        <div className="col-span-3">
          <Label className="text-xs">Max</Label>
          <Input
            type="number"
            min="0"
            step="1"
            value={maxVal}
            onChange={(e) => setMaxVal(Number(e.target.value))}
            className="py-1 text-xs w-full"
            disabled={readOnly}
          />
        </div>

        <div className="col-span-12 text-xs text-gray-500">
          Lead time: {minVal}–{maxVal} {unit}
        </div>

        <div className="col-span-12">
          <Label className="text-xs">Notes</Label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            className="w-full border border-gray-300 rounded px-3 py-2 text-xs"
            rows={4}
            disabled={readOnly}
          />
        </div>
      </div>

      <div className="flex justify-end">
        <Button
          variant="primary"
          size="sm"
          loading={saving}
          disabled={readOnly || saving}
          onClick={handleSave}
        >
          Save Supply
        </Button>
      </div>
    </div>
  );
}

