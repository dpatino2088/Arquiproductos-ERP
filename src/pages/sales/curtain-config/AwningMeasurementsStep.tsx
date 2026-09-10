import React from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';
import { Image as ImageIcon } from 'lucide-react';
import AwningSystemSelector from './AwningSystemSelector';
import {
  validateMeasurements,
  awningArmsForLine,
  awningMinLineMm,
  awningTubeDiameter,
  awningMotorNmSuggestion,
  AWNING_MAGNUM_PROJECTION_MM,
} from '../product-config/measurementValidation';

interface AwningMeasurementsStepProps {
  config: CurtainConfiguration;
  onUpdate: (updates: Partial<CurtainConfiguration>) => void;
}

const getImageUrl = (path: string) => {
  const base = (import.meta.env.BASE_URL || '/').replace(/\/$/, '') || '';
  return `${base}${path.startsWith('/') ? path : '/' + path}`;
};

// Wall / Ceiling mounting cards (same visual pattern as the roller Installation cards)
const MOUNTING_OPTIONS = [
  { id: 'wall' as const, name: 'Wall', imagePath: '/images/Wall.png' },
  { id: 'ceiling' as const, name: 'Ceiling', imagePath: '/images/Ceilling.png' },
];

/**
 * Measurements step for the EXTENSIBLE awning (Monobloc).
 * The two driving dimensions are Line (total width including caps) and
 * Projection (frontal extension / salida). There is NO height for this system:
 * the projection is mirrored into height_mm/height_m so the 2D cut engine and
 * fabric consumption work unchanged (fabric length axis = projection).
 */
export default function AwningMeasurementsStep({ config, onUpdate }: AwningMeasurementsStepProps) {
  const [imageLoadErrors, setImageLoadErrors] = React.useState<Set<string>>(new Set());
  const markImageError = React.useCallback((key: string) => {
    setImageLoadErrors((prev) => new Set(prev).add(key));
  }, []);

  const cfg = config as any;
  const lineMm: number = Number(cfg.width_mm) || 0;
  const projectionMm: number = Number(cfg.projection_mm) || Number(cfg.height_mm) || 0;
  const currentMounting = cfg.installationLocation ?? cfg.installation_location;

  const buildMeasurements = (widthMm: number, projMm: number) => ({
    height_mm: projMm || undefined,
    width_total_mm: widthMm || 0,
    panel_count: 1,
    panels: [{ index: 1, width_mm: widthMm || 0 }],
    is_interconnected: false,
  });

  const handleLineUpdate = (value: number) => {
    const width_mm = value || undefined;
    onUpdate({
      width_mm,
      width_m: width_mm ? width_mm / 1000 : null,
      panels: [{ width_mm: width_mm || 0 }],
      measurements: buildMeasurements(width_mm || 0, projectionMm),
    } as any);
  };

  const handleProjectionUpdate = (value: number) => {
    const projection_mm = value || undefined;
    onUpdate({
      projection_mm,
      // Mirror projection into height so the 2D cut engine / persistence work unchanged.
      height_mm: projection_mm,
      height_m: projection_mm ? projection_mm / 1000 : null,
      measurements: buildMeasurements(lineMm, projection_mm || 0),
    } as any);
  };

  const measurementValidation = React.useMemo(
    () =>
      validateMeasurements({
        productType: 'awning',
        width_mm: lineMm,
        projection_mm: projectionMm,
        installationLocation: currentMounting,
      }),
    [lineMm, projectionMm, currentMounting]
  );

  // Live system summary (from the Epsylon fabrication tables)
  const arms = lineMm > 0 ? awningArmsForLine(lineMm) : null;
  const minLineMm = projectionMm > 0 && arms ? awningMinLineMm(projectionMm, arms) : null;
  const tubeDiameter = lineMm > 0 ? awningTubeDiameter(lineMm) : null;
  const motorNm = awningMotorNmSuggestion(lineMm, projectionMm);
  const needsMagnum = projectionMm >= AWNING_MAGNUM_PROJECTION_MM;

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-8">
        {/* AWNING SYSTEM (Extensible / Vertical) */}
        <AwningSystemSelector config={config} onUpdate={onUpdate as any} />

        {/* DIMENSIONS */}
        <div>
          <Label className="text-sm font-medium mb-5 block">DIMENSIONS</Label>
          <div className="space-y-4">
            {/* Row 1: Area, Position, Quantity */}
            <div className="grid grid-cols-4 gap-6">
              <div>
                <Label htmlFor="awning-area" className="text-xs mb-1">Area</Label>
                <Input
                  id="awning-area"
                  type="text"
                  value={config.area || ''}
                  onChange={(e) => onUpdate({ area: e.target.value })}
                  autoComplete="off"
                  data-lpignore="true"
                  data-form-type="other"
                />
              </div>
              <div>
                <Label htmlFor="awning-position" className="text-xs mb-1">Position</Label>
                <Input
                  id="awning-position"
                  type="text"
                  value={config.position !== undefined && config.position !== '' ? String(config.position) : ''}
                  onChange={(e) => onUpdate({ position: e.target.value })}
                  autoComplete="off"
                  data-lpignore="true"
                  data-form-type="other"
                />
              </div>
              <div>
                <Label htmlFor="awning-quantity" className="text-xs mb-1">Quantity</Label>
                <Input
                  id="awning-quantity"
                  type="number"
                  min={1}
                  value={cfg.quantity != null ? String(cfg.quantity) : ''}
                  onChange={(e) => {
                    const raw = e.target.value;
                    if (raw === '') {
                      onUpdate({ quantity: undefined } as any);
                      return;
                    }
                    const n = parseInt(raw, 10);
                    if (!Number.isNaN(n)) onUpdate({ quantity: Math.max(1, n) } as any);
                  }}
                  onBlur={() => {
                    if (cfg.quantity == null || cfg.quantity === '') {
                      onUpdate({ quantity: 1 } as any);
                    }
                  }}
                  placeholder="1"
                  autoComplete="off"
                  data-lpignore="true"
                  data-form-type="other"
                />
              </div>
              <div></div>
            </div>

            {/* Row 2: Line, Projection */}
            <div className="grid grid-cols-4 gap-6">
              <div>
                <Label htmlFor="awning-line" className="text-xs mb-1">Line / Width (mm)</Label>
                <Input
                  id="awning-line"
                  type="number"
                  min="0"
                  value={lineMm || ''}
                  onChange={(e) => handleLineUpdate(parseInt(e.target.value) || 0)}
                  placeholder="4000"
                />
                <p className="text-[11px] text-gray-400 mt-1">Total width including end caps</p>
              </div>
              <div>
                <Label htmlFor="awning-projection" className="text-xs mb-1">Projection (mm)</Label>
                <Input
                  id="awning-projection"
                  type="number"
                  min="0"
                  value={projectionMm || ''}
                  onChange={(e) => handleProjectionUpdate(parseInt(e.target.value) || 0)}
                  placeholder="3000"
                />
                <p className="text-[11px] text-gray-400 mt-1">Frontal extension (1.25 – 4.00 m)</p>
              </div>
              <div></div>
              <div></div>
            </div>
          </div>

          {/* Live system summary from the fabrication tables */}
          {(lineMm > 0 || projectionMm > 0) && (
            <div className="mt-4 rounded-md border border-blue-200 bg-blue-50 p-3">
              <p className="text-sm font-medium text-blue-800 mb-1">System summary</p>
              <ul className="text-sm text-blue-700 space-y-0.5">
                {arms && <li>Arms: {arms}</li>}
                {minLineMm != null && minLineMm > 0 && (
                  <li>Minimum line for this projection: {minLineMm} mm</li>
                )}
                {tubeDiameter && <li>Roller tube: Ø{tubeDiameter}</li>}
                {motorNm != null && <li>Suggested motor torque: {motorNm} Nm (if motorized)</li>}
                {needsMagnum && <li>Magnum kit required (projection ≥ 3.75 m)</li>}
              </ul>
            </div>
          )}

          {/* Hard errors (block progression) */}
          {measurementValidation.errors.length > 0 && (
            <div className="mt-4 rounded-md border border-red-200 bg-red-50 p-3">
              <ul className="text-sm text-red-700 list-disc pl-5 space-y-1">
                {measurementValidation.errors.map((msg, i) => (
                  <li key={i}>{msg}</li>
                ))}
              </ul>
            </div>
          )}

          {/* Soft warnings: factory review (do not block) */}
          {measurementValidation.errors.length === 0 && measurementValidation.warnings.length > 0 && (
            <div className="mt-4 rounded-md border border-amber-200 bg-amber-50 p-3">
              <p className="text-sm font-medium text-amber-800 mb-1">Needs factory review</p>
              <ul className="text-sm text-amber-700 list-disc pl-5 space-y-1">
                {measurementValidation.warnings.map((msg, i) => (
                  <li key={i}>{msg}</li>
                ))}
              </ul>
            </div>
          )}
        </div>

        {/* MOUNTING (Wall / Ceiling) */}
        <div>
          <Label className="text-sm font-medium mb-5 block">MOUNTING</Label>
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
            {MOUNTING_OPTIONS.map((option) => {
              const isSelected = currentMounting === option.id;
              const imgKey = `mounting-${option.id}`;
              return (
                <div
                  key={option.id}
                  onClick={() => onUpdate({ installationLocation: isSelected ? undefined : option.id } as any)}
                  className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer ${
                    isSelected
                      ? 'border-2 border-gray-900 shadow-lg'
                      : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                  }`}
                >
                  <div className="aspect-square bg-white flex items-center justify-center overflow-hidden">
                    {option.imagePath && !imageLoadErrors.has(imgKey) ? (
                      <img
                        src={getImageUrl(option.imagePath)}
                        alt={option.name}
                        className="w-full h-full object-cover"
                        onError={() => markImageError(imgKey)}
                      />
                    ) : (
                      <ImageIcon className="w-16 h-16 text-gray-300" />
                    )}
                  </div>
                  <div className="p-4 bg-gray-100 flex-1">
                    <h3 className="font-semibold text-sm truncate text-center text-gray-900" title={option.name}>
                      {option.name}
                    </h3>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
