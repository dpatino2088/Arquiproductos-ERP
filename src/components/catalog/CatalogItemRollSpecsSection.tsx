import { useEffect, useMemo, useRef, useState } from 'react';
import Label from '../ui/Label';
import Input from '../ui/Input';
import {
  Select as SelectShadcn,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../ui/SelectShadcn';
import {
  fetchCatalogItemRollSpecs,
  upsertCatalogItemRollSpecs,
} from '../../services/catalogItemRollSpecs';

type Props = {
  catalogItemId: string;
  organizationId: string;
  readOnly?: boolean;
};

function parseOptionalNumber(raw: string): { value: number | null; error: string | null } {
  const trimmed = raw.trim();
  if (trimmed === '') return { value: null, error: null };
  const n = Number(trimmed);
  if (Number.isNaN(n)) return { value: null, error: 'Must be a number' };
  return { value: n, error: null };
}

function roundTo(value: number, decimals: number) {
  const p = 10 ** decimals;
  return Math.round(value * p) / p;
}

export function CatalogItemRollSpecsSection({ catalogItemId, organizationId, readOnly = false }: Props) {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const dirtyRef = useRef(false);
  const saveTimerRef = useRef<number | null>(null);

  const [canRotate, setCanRotate] = useState(false);
  const [isWeldable, setIsWeldable] = useState(false);
  const [rawMaterial, setRawMaterial] = useState('');
  const [openness, setOpenness] = useState('');
  const [weightG, setWeightG] = useState('');
  const [notes, setNotes] = useState('');

  const [opennessError, setOpennessError] = useState<string | null>(null);
  const [weightGError, setWeightGError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    setError(null);
    dirtyRef.current = false;

    fetchCatalogItemRollSpecs(catalogItemId)
      .then((data) => {
        if (!mounted) return;
        if (!data) return;

        setCanRotate(!!data.can_rotate);
        setIsWeldable(!!data.is_weldable);
        setRawMaterial(data.raw_material ?? '');

        const opennessNum = data.openness_factor_pct as any;
        setOpenness(opennessNum == null ? '' : String(opennessNum));

        const gNum = data.weight_g_m2 as any;
        setWeightG(gNum == null ? '' : String(gNum));

        setNotes(data.notes ?? '');
      })
      .catch((err) => {
        if (!mounted) return;
        setError(err?.message || 'Failed to load roll specs');
      })
      .finally(() => {
        if (!mounted) return;
        setLoading(false);
      });

    return () => {
      mounted = false;
    };
  }, [catalogItemId]);

  // Auto-save on user edits (button removed by request).
  useEffect(() => {
    if (loading || readOnly) return;
    if (!dirtyRef.current) return;

    if (saveTimerRef.current) {
      window.clearTimeout(saveTimerRef.current);
    }

    saveTimerRef.current = window.setTimeout(async () => {
      setError(null);
      const { opennessValue, weightGValue, ok } = validateAll();
      if (!ok) return;

      const computedKg = weightGValue == null ? null : roundTo(weightGValue / 1000, 3);

      setSaving(true);
      try {
        await upsertCatalogItemRollSpecs({
          catalog_item_id: catalogItemId,
          organization_id: organizationId,
          can_rotate: canRotate,
          is_weldable: isWeldable,
          raw_material: rawMaterial.trim() ? rawMaterial.trim() : null,
          openness_factor_pct: opennessValue,
          weight_g_m2: weightGValue,
          weight_kg_m2: computedKg,
          notes: notes.trim() ? notes.trim() : null,
        });
        dirtyRef.current = false;
      } catch (err: any) {
        setError(err?.message || 'Failed to save specs');
      } finally {
        setSaving(false);
      }
    }, 500);

    return () => {
      if (saveTimerRef.current) {
        window.clearTimeout(saveTimerRef.current);
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [canRotate, isWeldable, rawMaterial, openness, weightG, notes, loading, readOnly, catalogItemId, organizationId]);

  const leadHints = useMemo(() => {
    return {
      rawMaterial: 'e.g., PVC',
      openness: '0–100',
    };
  }, []);

  function validateAll(): {
    opennessValue: number | null;
    weightGValue: number | null;
    ok: boolean;
  } {
    setOpennessError(null);
    setWeightGError(null);

    const o = parseOptionalNumber(openness);
    const g = parseOptionalNumber(weightG);

    let ok = true;

    if (o.error) {
      setOpennessError(o.error);
      ok = false;
    } else if (o.value != null && (o.value < 0 || o.value > 100)) {
      setOpennessError('Openness factor must be between 0 and 100');
      ok = false;
    }

    if (g.error) {
      setWeightGError(g.error);
      ok = false;
    } else if (g.value != null && g.value < 0) {
      setWeightGError('Weight must be ≥ 0');
      ok = false;
    }

    return { opennessValue: o.value, weightGValue: g.value, ok };
  }

  function onChangeWeightG(nextRaw: string) {
    dirtyRef.current = true;
    setWeightG(nextRaw);
    setWeightGError(null);
  }

  if (loading) return <div className="text-sm text-gray-500">Loading specs…</div>;

  return (
    <div className="space-y-4">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h3 className="text-sm font-semibold">Specs</h3>
          <p className="text-xs text-gray-500 mt-1">Roll-specific technical specifications.</p>
        </div>
        {saving && <p className="text-xs text-gray-500 mt-1">Saving…</p>}
      </div>

      {error && (
        <div className="p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {error}
        </div>
      )}

      <div className="grid grid-cols-12 gap-4">
        <div className="col-span-6">
          <Label className="text-xs">Can rotate</Label>
          <SelectShadcn
            value={canRotate ? 'yes' : 'no'}
            onValueChange={(v) => {
              dirtyRef.current = true;
              setCanRotate(v === 'yes');
            }}
            disabled={readOnly}
          >
            <SelectTrigger className="h-auto py-1 text-xs w-full">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="yes">Yes</SelectItem>
              <SelectItem value="no">No</SelectItem>
            </SelectContent>
          </SelectShadcn>
        </div>

        <div className="col-span-6">
          <Label className="text-xs">Weldable</Label>
          <SelectShadcn
            value={isWeldable ? 'yes' : 'no'}
            onValueChange={(v) => {
              dirtyRef.current = true;
              setIsWeldable(v === 'yes');
            }}
            disabled={readOnly}
          >
            <SelectTrigger className="h-auto py-1 text-xs w-full">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="yes">Yes</SelectItem>
              <SelectItem value="no">No</SelectItem>
            </SelectContent>
          </SelectShadcn>
        </div>

        <div className="col-span-6">
          <Label className="text-xs">Raw material</Label>
          <Input
            value={rawMaterial}
            onChange={(e) => {
              dirtyRef.current = true;
              setRawMaterial(e.target.value);
            }}
            className="py-1 text-xs w-full"
            placeholder={leadHints.rawMaterial}
            disabled={readOnly}
          />
        </div>

        <div className="col-span-6">
          <Label className="text-xs">Openness factor (%)</Label>
          <Input
            type="number"
            step="0.001"
            min="0"
            max="100"
            value={openness}
            onChange={(e) => {
              dirtyRef.current = true;
              setOpenness(e.target.value);
              setOpennessError(null);
            }}
            className="py-1 text-xs w-full"
            placeholder={leadHints.openness}
            disabled={readOnly}
          />
          {opennessError && <p className="text-xs text-red-600 mt-1">{opennessError}</p>}
        </div>

        <div className="col-span-6">
          <Label className="text-xs">Weight (g/m²)</Label>
          <Input
            type="number"
            step="0.001"
            min="0"
            value={weightG}
            onChange={(e) => onChangeWeightG(e.target.value)}
            className="py-1 text-xs w-full"
            disabled={readOnly}
          />
          {weightGError && <p className="text-xs text-red-600 mt-1">{weightGError}</p>}
        </div>

        <div className="col-span-12">
          <Label className="text-xs">Notes</Label>
          <textarea
            value={notes}
            onChange={(e) => {
              dirtyRef.current = true;
              setNotes(e.target.value);
            }}
            className="w-full border border-gray-300 rounded px-3 py-2 text-xs"
            rows={4}
            disabled={readOnly}
          />
        </div>
      </div>
    </div>
  );
}

