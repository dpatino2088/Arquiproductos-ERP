import { useEffect, useState } from 'react';
import { Package, Ruler } from 'lucide-react';
import { supabase } from '../../../../../lib/supabase/client';
import { useOrganizationContext } from '../../../../../context/OrganizationContext';
import Label from '../../../../../components/ui/Label';
import Input from '../../../../../components/ui/Input';

interface FilmSellModeStepProps {
  config: any;
  onUpdate: (updates: Record<string, any>) => void;
}

const MIN_LINEAR_M = 0.3048;
const INCHES_TO_M = 0.0254;
const normalizeLinearLengthMeters = (value: unknown): number => {
  const raw = Number(value);
  if (!Number.isFinite(raw) || raw <= 0) return MIN_LINEAR_M;
  // Backward compatibility: some old snapshots stored this as millimeters.
  const meters = raw > 100 ? raw / 1000 : raw;
  return Math.max(MIN_LINEAR_M, meters);
};

export default function FilmSellModeStep({ config, onUpdate }: FilmSellModeStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const [availableWidths, setAvailableWidths] = useState<number[]>([]);
  const [loading, setLoading] = useState(true);

  const manufacturer: string | null = config.manufacturer ?? null;
  const selectedWidth: number | null = config.film_width ?? null;
  const sellMode: 'roll' | 'linear' = config.sell_mode ?? 'roll';
  const linearLength: number = normalizeLinearLengthMeters(config.linear_length_m);
  const qty: number = config.qty ?? 1;
  const currentArea: string = config.area ?? '';
  const currentPosition: string = config.position ?? '';

  useEffect(() => {
    if (!activeOrganizationId) return;
    let cancelled = false;

    (async () => {
      setLoading(true);
      let query = supabase
        .from('CatalogItems')
        .select('roll_width_m')
        .eq('organization_id', activeOrganizationId)
        .eq('item_role', 'window_film')
        .eq('is_active', true);

      if (manufacturer) query = query.ilike('manufacturer', manufacturer);

      const { data: items } = await query;
      if (cancelled) return;

      const widthSet = new Set<number>();
      for (const item of items ?? []) {
        const wm = Number(item.roll_width_m);
        if (wm > 0) widthSet.add(Math.round(wm / INCHES_TO_M));
      }
      const sorted = Array.from(widthSet).sort((a, b) => a - b);
      setAvailableWidths(sorted);
      setLoading(false);
    })();
    return () => { cancelled = true; };
  }, [activeOrganizationId, manufacturer]);

  const handleWidthSelect = (inches: number) => {
    onUpdate({
      film_width: inches,
      film_collection: null,
      film_variant: null,
      catalog_item_id: null,
      sku: '',
      name: '',
    });
  };

  const handleSellModeChange = (mode: 'roll' | 'linear') => {
    const nextQty = Math.max(1, qty || 1);
    const nextLinearLength = linearLength || MIN_LINEAR_M;
    const rollWidthM = Number(config.roll_width_m) || 0;
    const dealerPerLinearM = Number(config.dealer_per_linear_m) || 0;
    const rollDealerTotal = Number(config.roll_dealer_total) || 0;
    const unitPrice = mode === 'linear'
      ? dealerPerLinearM * nextLinearLength
      : rollDealerTotal;
    const areaM2 = mode === 'linear'
      ? rollWidthM * nextLinearLength
      : (Number(config.roll_area_m2) || 0);
    onUpdate({
      sell_mode: mode,
      qty: nextQty,
      linear_length_m: mode === 'linear' ? nextLinearLength : linearLength,
      unit_price: unitPrice > 0 ? unitPrice : config.unit_price,
      area_m2: areaM2 > 0 ? areaM2 : config.area_m2,
    });
  };

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-8">

        {/* Location */}
        <div>
          <h3 className="text-base font-semibold text-gray-900 mb-4">Location</h3>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label className="text-xs mb-1 block">Area <span className="text-gray-400 font-normal">(optional)</span></Label>
              <Input type="text" placeholder="e.g. Living Room..." value={currentArea}
                onChange={(e) => onUpdate({ area: e.target.value || null })} />
            </div>
            <div>
              <Label className="text-xs mb-1 block">Position <span className="text-gray-400 font-normal">(optional)</span></Label>
              <Input type="text" placeholder="e.g. W.1, W.2..." value={currentPosition}
                onChange={(e) => onUpdate({ position: e.target.value || null })} />
            </div>
          </div>
        </div>

        {/* Roll Width */}
        <div>
          <h3 className="text-base font-semibold text-gray-900 mb-2">Roll Width</h3>
          <p className="text-sm text-gray-500 mb-4">Select the roll width for this film.</p>

          {loading ? (
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
              {[1, 2, 3].map(i => <div key={i} className="aspect-square bg-gray-100 rounded-lg animate-pulse" />)}
            </div>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
              {availableWidths.map((inches) => {
                const isSelected = selectedWidth === inches;
                const widthM = (inches * INCHES_TO_M).toFixed(2);
                return (
                  <div
                    key={inches}
                    onClick={() => handleWidthSelect(inches)}
                    className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer ${
                      isSelected
                        ? 'border-2 border-gray-900 shadow-lg'
                        : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                    }`}
                  >
                    <div className="aspect-square bg-white flex flex-col items-center justify-center overflow-hidden">
                      <span className="text-4xl font-bold text-gray-900">{inches}"</span>
                      <span className="text-sm text-gray-500 mt-1">{widthM} m</span>
                    </div>
                    <div className="p-4 bg-gray-100 flex-1">
                      <h3 className="font-semibold text-sm text-center text-gray-900">{inches} inches</h3>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Sell Mode */}
        <div>
          <h3 className="text-base font-semibold text-gray-900 mb-2">Sell By</h3>
          <p className="text-sm text-gray-500 mb-4">Choose how this film will be sold.</p>

          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            <div
              onClick={() => handleSellModeChange('roll')}
              className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer ${
                sellMode === 'roll'
                  ? 'border-2 border-gray-900 shadow-lg'
                  : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
              }`}
            >
              <div className="aspect-square bg-white flex items-center justify-center overflow-hidden">
                <Package className={`w-16 h-16 ${sellMode === 'roll' ? 'text-gray-900' : 'text-gray-300'}`} />
              </div>
              <div className="p-4 bg-gray-100 flex-1">
                <h3 className="font-semibold text-sm text-center text-gray-900">Full Roll</h3>
              </div>
            </div>

            <div
              onClick={() => handleSellModeChange('linear')}
              className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer ${
                sellMode === 'linear'
                  ? 'border-2 border-gray-900 shadow-lg'
                  : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
              }`}
            >
              <div className="aspect-square bg-white flex items-center justify-center overflow-hidden">
                <Ruler className={`w-16 h-16 ${sellMode === 'linear' ? 'text-gray-900' : 'text-gray-300'}`} />
              </div>
              <div className="p-4 bg-gray-100 flex-1">
                <h3 className="font-semibold text-sm text-center text-gray-900">Linear Meter</h3>
              </div>
            </div>
          </div>
        </div>

        {/* Quantity / Length */}
        <div>
          <h3 className="text-base font-semibold text-gray-900 mb-4">Quantity / Length</h3>
          {sellMode === 'roll' ? (
            <div className="max-w-xs">
              <Label className="text-xs mb-1 block">Number of Rolls</Label>
              <Input type="number" min={1} value={qty}
                onChange={(e) => onUpdate({ qty: Math.max(1, parseInt(e.target.value, 10) || 1) })} />
            </div>
          ) : (
            <div className="grid grid-cols-2 gap-4 max-w-lg">
              <div>
                <Label className="text-xs mb-1 block">Qty (identical pieces)</Label>
                <Input
                  type="number"
                  min={1}
                  value={qty}
                  onChange={(e) => {
                    const nextQty = Math.max(1, parseInt(e.target.value, 10) || 1);
                    onUpdate({ qty: nextQty });
                  }}
                />
              </div>
              <div>
                <Label className="text-xs mb-1 block">Length (meters)</Label>
                <Input
                  type="number"
                  min={MIN_LINEAR_M}
                  step={0.01}
                  value={linearLength}
                  onChange={(e) => {
                    const nextLength = Math.max(MIN_LINEAR_M, parseFloat(e.target.value) || MIN_LINEAR_M);
                    const dealerPerLinearM = Number(config.dealer_per_linear_m) || 0;
                    const rollWidthM = Number(config.roll_width_m) || 0;
                    onUpdate({
                      linear_length_m: nextLength,
                      unit_price: dealerPerLinearM > 0 ? dealerPerLinearM * nextLength : config.unit_price,
                      area_m2: rollWidthM > 0 ? rollWidthM * nextLength : config.area_m2,
                    });
                  }}
                />
              </div>
              <div className="col-span-2">
                <p className="text-xs text-gray-400 mt-1">Enter length in meters (m). Qty applies to identical pieces at full roll width.</p>
              </div>
            </div>
          )}
        </div>

      </div>
    </div>
  );
}
