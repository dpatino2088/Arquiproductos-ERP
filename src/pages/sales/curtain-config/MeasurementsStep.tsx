import React from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';
import { Plus, X, Image as ImageIcon } from 'lucide-react';
import type { Panel } from '../product-config/types';
import { supabase } from '../../../lib/supabase/client';
import { useOrganizationContext } from '../../../context/OrganizationContext';

interface MeasurementsStepProps {
  config: CurtainConfiguration;
  onUpdate: (updates: Partial<CurtainConfiguration>) => void;
}

// Base URL for static images (works with Vite base path in dev and production)
const getImageUrl = (path: string) => {
  const base = (import.meta.env.BASE_URL || '/').replace(/\/$/, '') || '';
  return `${base}${path.startsWith('/') ? path : '/' + path}`;
};

// Definir las opciones con sus imágenes (paths; URLs se construyen en el componente con getImageUrl)
const FABRIC_DROP_OPTIONS = [
  { id: 'normal' as const, name: 'Normal', imagePath: '/images/Normal.png' },
  { id: 'inverted' as const, name: 'Inverted', imagePath: '/images/Inverted.png' },
];

const INSTALLATION_TYPE_OPTIONS = [
  { id: 'inside' as const, name: 'Inside', imagePath: '/images/Inside.png', draperyImagePath: '/images/DR-Inside.png' },
  { id: 'outside' as const, name: 'Outside', imagePath: '/images/Outside.png', draperyImagePath: '/images/DR-Outside.png' },
];

const INSTALLATION_LOCATION_OPTIONS = [
  { id: 'ceiling' as const, name: 'Ceiling', imagePath: '/images/Ceilling.png', draperyImagePath: '/images/DR-Ceiling.png' },
  { id: 'wall' as const, name: 'Wall', imagePath: '/images/Wall.png', draperyImagePath: '/images/DR-Wall.png' },
];

const OPENING_DIRECTION_OPTIONS = [
  { id: 'left' as const, name: 'Left', imagePath: '/images/Opening Left.png' },
  { id: 'center' as const, name: 'Center', imagePath: '/images/Opening Center.png' },
  { id: 'right' as const, name: 'Right', imagePath: '/images/Opening Right.png' },
];

const DRIVE_SIDE_OPTIONS = [
  { id: 'left' as const, name: 'Left', imagePath: '/images/Drive Left.png' },
  { id: 'right' as const, name: 'Right', imagePath: '/images/Drive Right.png' },
];

export default function MeasurementsStep({ config, onUpdate }: MeasurementsStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const [imageLoadErrors, setImageLoadErrors] = React.useState<Set<string>>(new Set());
  const markImageError = React.useCallback((key: string) => {
    setImageLoadErrors((prev) => new Set(prev).add(key));
  }, []);

  const productType = (config as any).productType;
  const isTripleShade = productType === 'triple-shade';
  const isDrapery = productType === 'drapery';
  const hideFabricDrop = isTripleShade || isDrapery;

  // Support legacy snapshot keys (snake_case) so Edit always shows previous selection.
  const currentFabricDrop = (config as any).fabricDrop ?? (config as any).fabric_drop;
  const currentInstallationType = (config as any).installationType ?? (config as any).installation_type;
  const currentInstallationLocation = (config as any).installationLocation ?? (config as any).installation_location;
  const currentOpeningDirection = (config as any).openingDirection ?? (config as any).opening_direction;
  const currentDriveSide = (config as any).driveSide ?? (config as any).drive_side;

  const productTypeId = (config as any).product_type_id || (config as any).productTypeId;

  // Filter BOMTemplates by opening_direction + drive_side for drapery
  React.useEffect(() => {
    if (!isDrapery || !activeOrganizationId || !productTypeId) return;
    if (!currentOpeningDirection) return;

    let cancelled = false;
    (async () => {
      let query = supabase
        .from('BOMTemplates')
        .select('id')
        .eq('organization_id', activeOrganizationId)
        .eq('product_type_id', productTypeId)
        .eq('is_active', true)
        .eq('archived', false);

      // opening_direction: match NULL (applies to all) or exact value
      query = query.or(`opening_direction.is.null,opening_direction.eq.${currentOpeningDirection}`);

      if (currentDriveSide) {
        query = query.or(`drive_side.is.null,drive_side.eq.${currentDriveSide}`);
      }

      const { data, error } = await query;
      if (cancelled) return;

      if (error) {
        console.error('[MeasurementsStep] Failed to filter templates by opening/drive:', error);
        return;
      }

      const templateIds = (data || []).map((t: { id: string }) => t.id);
      if (templateIds.length > 0) {
        onUpdate({ _hardware_filtered_templates: templateIds } as any);
      }
    })();

    return () => { cancelled = true; };
  }, [isDrapery, activeOrganizationId, productTypeId, currentOpeningDirection, currentDriveSide]);

  // Products that support multiple panels (interconnected curtains)
  const supportsPanels = ['roller-shade', 'dual-shade', 'triple-shade'].includes(productType);

  // measurements: { height_mm, width_total_mm, panel_count, panels: [{ index, width_mm }], is_interconnected }
  const getPanelsFromConfig = (): Panel[] => {
    const panels = (config as any).panels;
    if (panels && Array.isArray(panels) && panels.length > 0) {
      return panels.map((p: any) => ({ width_mm: p.width_mm || 0 }));
    }
    return [{ width_mm: config.width_mm || 0 }];
  };

  const panelCountFromConfig = Math.min(3, Math.max(1, (config as any).measurements?.panel_count ?? (config as any).panels?.length ?? 1));
  const [panelCount, setPanelCount] = React.useState<1 | 2 | 3>(panelCountFromConfig as 1 | 2 | 3);
  const [panels, setPanels] = React.useState<Panel[]>(() => {
    const fromConfig = getPanelsFromConfig();
    const count = panelCountFromConfig;
    if (fromConfig.length === count) return fromConfig;
    const next: Panel[] = [];
    for (let i = 0; i < count; i++) next.push({ width_mm: fromConfig[i]?.width_mm ?? 0 });
    return next;
  });

  const buildMeasurements = (heightMm: number | undefined, panelsList: Panel[]) => {
    const height_mm = heightMm ?? config.height_mm ?? 0;
    const width_total_mm = panelsList.reduce((sum, p) => sum + (p.width_mm || 0), 0);
    const panel_count = panelsList.length;
    return {
      height_mm: height_mm || undefined,
      width_total_mm,
      panel_count,
      panels: panelsList.map((p, i) => ({ index: i + 1, width_mm: p.width_mm || 0 })),
      is_interconnected: panel_count > 1,
    };
  };

  const pushMeasurementsAndPanels = (heightMm: number | undefined, newPanels: Panel[], clearTemplates = false) => {
    const measurements = buildMeasurements(heightMm, newPanels);
    // ✅ FIX: Para multi-panel, width_mm debe ser la suma total, no solo el primer panel
    const totalWidthMm = newPanels.reduce((sum, p) => sum + (p.width_mm || 0), 0);
    const updates: Record<string, unknown> = {
      panels: newPanels,
      measurements,
      width_mm: totalWidthMm || undefined,
      width_m: totalWidthMm ? totalWidthMm / 1000 : null,
    };
    if (clearTemplates) updates._hardware_filtered_templates = undefined;
    console.log('[MeasurementsStep] pushMeasurementsAndPanels', { 
      panelCount: newPanels.length, 
      panelWidths: newPanels.map(p => p.width_mm),
      totalWidthMm,
      width_m: updates.width_m 
    });
    onUpdate(updates as any);
  };

  const prevMeasurementsRef = React.useRef<{ panel_count?: number } | null>(null);
  React.useEffect(() => {
    const meas = (config as any).measurements;
    const fromConfig = getPanelsFromConfig();
    const count = meas?.panel_count ?? (config as any).panels?.length ?? 1;
    const safeCount = Math.min(3, Math.max(1, count)) as 1 | 2 | 3;
    if (prevMeasurementsRef.current?.panel_count === safeCount && fromConfig.length === safeCount) return;
    prevMeasurementsRef.current = meas || { panel_count: safeCount };
    setPanelCount(safeCount);
    const next: Panel[] = [];
    for (let i = 0; i < safeCount; i++) next.push({ width_mm: fromConfig[i]?.width_mm ?? 0 });
    setPanels(next);
  }, [(config as any).panels, (config as any).measurements?.panel_count]);

  const handleAddPanel = () => {
    if (panels.length < 3) {
      const newPanels = [...panels, { width_mm: 0 }];
      setPanels(newPanels);
      setPanelCount(newPanels.length as 1 | 2 | 3);
      pushMeasurementsAndPanels(config.height_mm, newPanels);
    }
  };

  const handleRemovePanel = (index: number) => {
    if (panels.length > 1) {
      const newPanels = panels.filter((_, i) => i !== index);
      setPanels(newPanels);
      setPanelCount(newPanels.length as 1 | 2 | 3);
      pushMeasurementsAndPanels(config.height_mm, newPanels, true);
    }
  };

  const handlePanelWidthUpdate = (index: number, value: number) => {
    const newPanels = [...panels];
    newPanels[index] = { width_mm: value || 0 };
    setPanels(newPanels);
    pushMeasurementsAndPanels(config.height_mm, newPanels);
  };

  const handleHeightUpdate = (value: number) => {
    const height_m = value ? value / 1000 : null;
    onUpdate({
      height_mm: value || undefined,
      height_m: height_m,
    } as any);
    const measurements = buildMeasurements(value, panels);
    onUpdate({ measurements } as any);
  };
  
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-8">
        {/* DIMENSIONS */}
        <div>
          <Label className="text-sm font-medium mb-5 block">DIMENSIONS</Label>
          {supportsPanels ? (
            // Multi-panel view
            <div className="space-y-4">
              {/* Row 1: Area, Position, Quantity */}
              <div className="grid grid-cols-4 gap-6">
                <div>
                  <Label htmlFor="area" className="text-xs mb-1">Area</Label>
                  <Input
                    id="area"
                    type="text"
                    value={config.area || ''}
                    onChange={(e) => onUpdate({ area: e.target.value })}
                    placeholder=""
                    autoComplete="off"
                    data-lpignore="true"
                    data-form-type="other"
                  />
                </div>
                <div>
                  <Label htmlFor="position" className="text-xs mb-1">Position</Label>
                  <Input
                    id="position"
                    type="text"
                    value={config.position !== undefined && config.position !== '' ? String(config.position) : ''}
                    onChange={(e) => onUpdate({ position: e.target.value })}
                    placeholder=""
                    autoComplete="off"
                    data-lpignore="true"
                    data-form-type="other"
                  />
                </div>
                <div>
                  <Label htmlFor="quantity" className="text-xs mb-1">Quantity</Label>
                  <Input
                    id="quantity"
                    type="number"
                    min={1}
                    value={(config as any).quantity != null ? String((config as any).quantity) : ''}
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
                      if ((config as any).quantity == null || (config as any).quantity === '') {
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
              
              {/* Row 2: Width Panel 1, Height, Add Panel button */}
              <div className="grid grid-cols-4 gap-6">
                <div>
                  <Label htmlFor="panel-0-width" className="text-xs mb-1">Width (mm)</Label>
                  <Input
                    id="panel-0-width"
                    type="number"
                    min="0"
                    value={panels[0]?.width_mm || ''}
                    onChange={(e) => handlePanelWidthUpdate(0, parseInt(e.target.value) || 0)}
                    placeholder="400"
                  />
                </div>
                <div>
                  <Label htmlFor="height_mm" className="text-xs mb-1">
                    Height (mm)
                    {panels.length > 1 && (
                      <span className="text-gray-400 ml-1">(all panels)</span>
                    )}
                  </Label>
                  <Input
                    id="height_mm"
                    type="number"
                    min="0"
                    value={config.height_mm || ''}
                    onChange={(e) => handleHeightUpdate(parseInt(e.target.value) || 0)}
                    placeholder="700"
                  />
                </div>
                <div className="flex items-end">
                  {panels.length < 3 && (
                    <button
                      type="button"
                      onClick={handleAddPanel}
                      className="flex items-center gap-1 px-3 py-1 text-xs bg-gray-100 border border-gray-200 text-gray-700 rounded hover:bg-gray-200 hover:border-gray-300 transition-colors w-1/2 justify-center h-[32px]"
                      title="Add panel (up to 3 panels)"
                    >
                      + ADD
                    </button>
                  )}
                </div>
                <div></div> {/* Empty space to maintain grid-cols-4 */}
              </div>
              
              {/* Additional panels - Width Panel 2, Width Panel 3 */}
              {panels.length > 1 && (
                <div className="space-y-2">
                  {panels.slice(1).map((panel, index) => {
                    const actualIndex = index + 1;
                    return (
                      <div key={actualIndex} className="grid grid-cols-4 gap-6">
                        <div>
                          <Label htmlFor={`panel-${actualIndex}-width`} className="text-xs mb-1">
                            Width Panel {actualIndex + 1} (mm)
                          </Label>
                          <div className="flex items-center gap-1">
                            <Input
                              id={`panel-${actualIndex}-width`}
                              type="number"
                              min="0"
                              value={panel.width_mm || ''}
                              onChange={(e) => handlePanelWidthUpdate(actualIndex, parseInt(e.target.value) || 0)}
                              placeholder="400"
                              className="flex-1"
                            />
                            <button
                              type="button"
                              onClick={() => handleRemovePanel(actualIndex)}
                              className="p-1 text-red-500 hover:bg-red-50 rounded transition-colors flex-shrink-0"
                              title="Remove panel"
                            >
                              <X className="w-4 h-4" />
                            </button>
                          </div>
                        </div>
                        <div></div> {/* Empty space */}
                        <div></div> {/* Empty space */}
                        <div></div> {/* Empty space */}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          ) : (
            // Legacy single panel view for other product types
            <div className="space-y-4">
              {/* Row 1: Area, Position, Quantity */}
              <div className="grid grid-cols-4 gap-6">
                <div>
                  <Label htmlFor="area-single" className="text-xs mb-1">Area</Label>
                  <Input
                    id="area-single"
                    type="text"
                    value={config.area || ''}
                    onChange={(e) => onUpdate({ area: e.target.value })}
                    placeholder=""
                    autoComplete="off"
                    data-lpignore="true"
                    data-form-type="other"
                  />
                </div>
                <div>
                  <Label htmlFor="position-single" className="text-xs mb-1">Position</Label>
                  <Input
                    id="position-single"
                    type="text"
                    value={config.position !== undefined && config.position !== '' ? String(config.position) : ''}
                    onChange={(e) => onUpdate({ position: e.target.value })}
                    placeholder=""
                    autoComplete="off"
                    data-lpignore="true"
                    data-form-type="other"
                  />
                </div>
                <div>
                  <Label htmlFor="quantity" className="text-xs mb-1">Quantity</Label>
                  <Input
                    id="quantity-single"
                    type="number"
                    min={1}
                    value={(config as any).quantity != null ? String((config as any).quantity) : ''}
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
                      if ((config as any).quantity == null || (config as any).quantity === '') {
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
              
              {/* Row 2: Width, Height */}
              <div className="grid grid-cols-4 gap-6">
                <div>
                  <Label htmlFor="width_mm" className="text-xs mb-1">Width (mm)</Label>
                  <Input
                    id="width_mm"
                    type="number"
                    min="0"
                    value={config.width_mm || ''}
                    onChange={(e) => {
                      const width_mm = parseInt(e.target.value) || undefined;
                      const width_m = width_mm ? width_mm / 1000 : null;
                      onUpdate({ width_mm, width_m } as any);
                    }}
                    placeholder="400"
                  />
                </div>
                <div>
                  <Label htmlFor="height_mm" className="text-xs mb-1">Height (mm)</Label>
                  <Input
                    id="height_mm"
                    type="number"
                    min="0"
                    value={config.height_mm || ''}
                    onChange={(e) => {
                      const height_mm = parseInt(e.target.value) || undefined;
                      const height_m = height_mm ? height_mm / 1000 : null;
                      onUpdate({ height_mm, height_m } as any);
                    }}
                    placeholder="700"
                  />
                </div>
                <div></div> {/* Empty space */}
                <div></div> {/* Empty space */}
              </div>
            </div>
          )}
        </div>

        {/* 2. FABRIC DROP - Drop de la tela Normal e Invertida (Hidden for Triple Shade and Drapery) */}
        {!hideFabricDrop && (
          <div>
            <Label className="text-sm font-medium mb-5 block">FABRIC DROP</Label>
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
              {FABRIC_DROP_OPTIONS.map((option) => {
                const isSelected = currentFabricDrop === option.id;
                return (
                  <div
                    key={option.id}
                    onClick={() => onUpdate({ fabricDrop: isSelected ? undefined : option.id })}
                    className={`bg-white border rounded-lg overflow-hidden transition-all cursor-pointer ${
                      isSelected
                        ? 'border-2 border-gray-900 shadow-lg'
                        : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                    }`}
                  >
                    {/* Image */}
                    <div className="aspect-square bg-white flex items-center justify-center overflow-hidden">
                      {option.imagePath && !imageLoadErrors.has(option.id) ? (
                        <img
                          src={getImageUrl(option.imagePath)}
                          alt={option.name}
                          className="w-full h-full object-cover"
                          onError={() => markImageError(option.id)}
                        />
                      ) : (
                        <ImageIcon className="w-16 h-16 text-gray-300" />
                      )}
                    </div>
                    
                    {/* Card Content */}
                    <div className="p-4 bg-gray-100">
                      {/* Option Name */}
                      <h3 className={`font-semibold text-sm truncate text-center ${
                        isSelected ? 'text-gray-900 font-semibold' : 'text-gray-900'
                      }`} title={option.name}>
                        {option.name}
                      </h3>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* 3. INSTALLATION TYPE & LOCATION - En una sola línea */}
        <div>
          <Label className="text-sm font-medium mb-5 block">INSTALLATION TYPE & LOCATION</Label>
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
            {/* Installation Type Options */}
            {INSTALLATION_TYPE_OPTIONS.map((option) => {
              const isSelected = currentInstallationType === option.id;
              const imgPath = isDrapery ? option.draperyImagePath : option.imagePath;
              const imgKey = `install-type-${option.id}`;
              return (
                <div
                  key={option.id}
                  onClick={() => onUpdate({ installationType: isSelected ? undefined : option.id })}
                  className={`bg-white border rounded-lg overflow-hidden transition-all cursor-pointer ${
                    isSelected
                      ? 'border-2 border-gray-900 shadow-lg'
                      : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                  }`}
                >
                  <div className="aspect-square bg-white flex items-center justify-center overflow-hidden">
                    {imgPath && !imageLoadErrors.has(imgKey) ? (
                      <img
                        src={getImageUrl(imgPath)}
                        alt={option.name}
                        className="w-full h-full object-cover"
                        onError={() => markImageError(imgKey)}
                      />
                    ) : (
                      <ImageIcon className="w-16 h-16 text-gray-300" />
                    )}
                  </div>
                  <div className="p-4 bg-gray-100">
                    <h3 className={`font-semibold text-sm truncate text-center ${
                      isSelected ? 'text-gray-900 font-semibold' : 'text-gray-900'
                    }`} title={option.name}>
                      {option.name}
                    </h3>
                  </div>
                </div>
              );
            })}
            
            {/* Installation Location Options */}
            {INSTALLATION_LOCATION_OPTIONS.map((option) => {
              const isSelected = currentInstallationLocation === option.id;
              const imgPath = isDrapery ? option.draperyImagePath : option.imagePath;
              const imgKey = `install-loc-${option.id}`;
              return (
                <div
                  key={option.id}
                  onClick={() => onUpdate({ installationLocation: isSelected ? undefined : option.id })}
                  className={`bg-white border rounded-lg overflow-hidden transition-all cursor-pointer ${
                    isSelected
                      ? 'border-2 border-gray-900 shadow-lg'
                      : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                  }`}
                >
                  <div className="aspect-square bg-white flex items-center justify-center overflow-hidden">
                    {imgPath && !imageLoadErrors.has(imgKey) ? (
                      <img
                        src={getImageUrl(imgPath)}
                        alt={option.name}
                        className="w-full h-full object-cover"
                        onError={() => markImageError(imgKey)}
                      />
                    ) : (
                      <ImageIcon className="w-16 h-16 text-gray-300" />
                    )}
                  </div>
                  <div className="p-4 bg-gray-100">
                    <h3 className={`font-semibold text-sm truncate text-center ${
                      isSelected ? 'text-gray-900 font-semibold' : 'text-gray-900'
                    }`} title={option.name}>
                      {option.name}
                    </h3>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* 4. OPENING DIRECTION — Drapery only */}
        {isDrapery && (
          <div>
            <Label className="text-sm font-medium mb-5 block">OPENING DIRECTION</Label>
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
              {OPENING_DIRECTION_OPTIONS.map((option) => {
                const isSelected = currentOpeningDirection === option.id;
                return (
                  <div
                    key={option.id}
                    onClick={() => {
                      const updates: Record<string, unknown> = {
                        openingDirection: isSelected ? undefined : option.id,
                      };
                      if (isSelected) {
                        updates.driveSide = undefined;
                      } else if (option.id === 'center') {
                        updates.driveSide = undefined;
                      } else {
                        updates.driveSide = option.id;
                      }
                      onUpdate(updates as any);
                    }}
                    className={`bg-white border rounded-lg overflow-hidden transition-all cursor-pointer ${
                      isSelected
                        ? 'border-2 border-gray-900 shadow-lg'
                        : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                    }`}
                  >
                    <div className="aspect-square bg-white flex items-center justify-center overflow-hidden">
                      {option.imagePath && !imageLoadErrors.has(`opening-${option.id}`) ? (
                        <img
                          src={getImageUrl(option.imagePath)}
                          alt={option.name}
                          className="w-full h-full object-cover"
                          onError={() => markImageError(`opening-${option.id}`)}
                        />
                      ) : (
                        <ImageIcon className="w-16 h-16 text-gray-300" />
                      )}
                    </div>
                    <div className="p-4 bg-gray-100">
                      <h3
                        className={`font-semibold text-sm truncate text-center ${
                          isSelected ? 'text-gray-900' : 'text-gray-900'
                        }`}
                        title={option.name}
                      >
                        {option.name}
                      </h3>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* 5. DRIVE SIDE — Drapery only, visible when Opening = Center */}
        {isDrapery && currentOpeningDirection === 'center' && (
          <div>
            <Label className="text-sm font-medium mb-5 block">DRIVE SIDE</Label>
            <p className="text-xs text-gray-500 mb-3">
              With center opening, select which side the drive mechanism goes.
            </p>
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
              {DRIVE_SIDE_OPTIONS.map((option) => {
                const isSelected = currentDriveSide === option.id;
                return (
                  <div
                    key={option.id}
                    onClick={() => {
                      onUpdate({ driveSide: isSelected ? undefined : option.id } as any);
                    }}
                    className={`bg-white border rounded-lg overflow-hidden transition-all cursor-pointer ${
                      isSelected
                        ? 'border-2 border-gray-900 shadow-lg'
                        : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                    }`}
                  >
                    <div className="aspect-square bg-white flex items-center justify-center overflow-hidden">
                      {option.imagePath && !imageLoadErrors.has(`drive-${option.id}`) ? (
                        <img
                          src={getImageUrl(option.imagePath)}
                          alt={option.name}
                          className="w-full h-full object-cover"
                          onError={() => markImageError(`drive-${option.id}`)}
                        />
                      ) : (
                        <ImageIcon className="w-16 h-16 text-gray-300" />
                      )}
                    </div>
                    <div className="p-4 bg-gray-100">
                      <h3
                        className={`font-semibold text-sm truncate text-center ${
                          isSelected ? 'text-gray-900' : 'text-gray-900'
                        }`}
                        title={option.name}
                      >
                        {option.name}
                      </h3>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* 6. TRACK SPLIT — Drapery only */}
        {isDrapery && (() => {
          const totalWidthMm = config.width_mm || 0;
          const isOver4m = totalWidthMm > 4000;
          const currentForce = (config as any).forceTrackJoin ?? (config as any).force_track_join ?? false;

          if (isOver4m) {
            const joints = Math.max(0, Math.ceil(totalWidthMm / 4000) - 1);
            return (
              <div className="bg-amber-50 border border-amber-200 rounded-lg p-4">
                <Label className="text-sm font-medium mb-1 block">TRACK JOINT</Label>
                <p className="text-sm text-amber-800">
                  Width exceeds 4m — the track will be split into {joints + 1} pieces with {joints} joint{joints > 1 ? 's' : ''} (automatic).
                </p>
              </div>
            );
          }

          if (totalWidthMm > 0) {
            return (
              <div className="bg-white border border-gray-200 rounded-lg p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <Label className="text-sm font-medium mb-1 block">SPLIT TRACK (OPTIONAL)</Label>
                    <p className="text-xs text-gray-500">
                      Width is under 4m. You can optionally split the track into 2 pieces with a joint.
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => onUpdate({ forceTrackJoin: !currentForce } as any)}
                    className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out ${
                      currentForce ? 'bg-gray-900' : 'bg-gray-200'
                    }`}
                    role="switch"
                    aria-checked={currentForce}
                  >
                    <span
                      className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                        currentForce ? 'translate-x-5' : 'translate-x-0'
                      }`}
                    />
                  </button>
                </div>
              </div>
            );
          }

          return null;
        })()}
      </div>
    </div>
  );
}

