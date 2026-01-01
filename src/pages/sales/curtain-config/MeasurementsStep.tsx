import React from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';
import { Plus, X } from 'lucide-react';
import type { Panel } from '../product-config/types';

interface MeasurementsStepProps {
  config: CurtainConfiguration;
  onUpdate: (updates: Partial<CurtainConfiguration>) => void;
}

// Definir las opciones con sus imágenes
const FABRIC_DROP_OPTIONS = [
  {
    id: 'normal' as const,
    name: 'Normal',
    imageUrl: '/images/fabric-drop-normal.jpg', // Actualizar con la ruta correcta
  },
  {
    id: 'inverted' as const,
    name: 'Inverted',
    imageUrl: '/images/fabric-drop-inverted.jpg', // Actualizar con la ruta correcta
  }
];

const INSTALLATION_TYPE_OPTIONS = [
  {
    id: 'inside' as const,
    name: 'Inside',
    imageUrl: '/images/installation-inside.jpg', // Actualizar con la ruta correcta
  },
  {
    id: 'outside' as const,
    name: 'Outside',
    imageUrl: '/images/installation-outside.jpg', // Actualizar con la ruta correcta
  }
];

const INSTALLATION_LOCATION_OPTIONS = [
  {
    id: 'ceiling' as const,
    name: 'Ceiling',
    imageUrl: '/images/installation-ceiling.jpg', // Actualizar con la ruta correcta
  },
  {
    id: 'wall' as const,
    name: 'Wall',
    imageUrl: '/images/installation-wall.jpg', // Actualizar con la ruta correcta
  }
];

export default function MeasurementsStep({ config, onUpdate }: MeasurementsStepProps) {
  // Check if product type is Triple Shade (no Fabric Drop for Triple Shade)
  const isTripleShade = (config as any).productType === 'triple-shade';
  const productType = (config as any).productType;
  
  // Products that support multiple panels (interconnected curtains)
  const supportsPanels = ['roller-shade', 'dual-shade', 'triple-shade'].includes(productType);
  
  // Initialize panels array - panels only store width_mm, height_mm is global
  const getPanels = (): Panel[] => {
    const panels = (config as any).panels;
    if (panels && Array.isArray(panels) && panels.length > 0) {
      // Ensure panels only have width_mm (remove height_mm if present)
      return panels.map(p => ({ width_mm: p.width_mm || 0 }));
    }
    // Legacy: create single panel from width_mm (height_mm is stored separately)
    return [
      {
        width_mm: config.width_mm || 0,
      }
    ];
  };
  
  const [panels, setPanels] = React.useState<Panel[]>(getPanels());
  
  // Sync panels when config changes externally
  React.useEffect(() => {
    const newPanels = getPanels();
    setPanels(newPanels);
  }, [config.width_mm, (config as any).panels]);
  
  const handleAddPanel = () => {
    if (panels.length < 3) {
      // New panel only needs width (height is global)
      const newPanels = [...panels, { width_mm: 0 }];
      setPanels(newPanels);
      onUpdate({ panels: newPanels } as any);
    }
  };
  
  const handleRemovePanel = (index: number) => {
    if (panels.length > 1) {
      const newPanels = panels.filter((_, i) => i !== index);
      setPanels(newPanels);
      onUpdate({ panels: newPanels } as any);
    }
  };
  
  const handlePanelWidthUpdate = (index: number, value: number) => {
    const newPanels = [...panels];
    newPanels[index] = { width_mm: value || 0 };
    setPanels(newPanels);
    onUpdate({ panels: newPanels } as any);
    
    // Also update legacy width_mm for backward compatibility (use first panel)
    if (index === 0 && newPanels[0]) {
      onUpdate({
        width_mm: newPanels[0].width_mm || undefined,
      });
    }
  };
  
  // Handle global height update (applies to all panels)
  const handleHeightUpdate = (value: number) => {
    onUpdate({ height_mm: value || undefined });
  };
  
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        {/* DIMENSIONS */}
        <div>
          <Label className="text-sm font-medium mb-4 block">DIMENSIONS</Label>
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
                  />
                </div>
                <div>
                  <Label htmlFor="position" className="text-xs mb-1">Position</Label>
                  <Input
                    id="position"
                    type="text"
                    value={config.position || ''}
                    onChange={(e) => onUpdate({ position: e.target.value })}
                    placeholder=""
                  />
                </div>
                <div>
                  <Label htmlFor="quantity" className="text-xs mb-1">Quantity</Label>
                  <Input
                    id="quantity"
                    type="number"
                    min="1"
                    value={(config as any).quantity || ''}
                    onChange={(e) => onUpdate({ quantity: parseInt(e.target.value) || 1 } as any)}
                    placeholder="1"
                  />
                </div>
                <div></div> {/* Empty space to maintain grid-cols-4 */}
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
                  <Label htmlFor="area" className="text-xs mb-1">Area</Label>
                  <Input
                    id="area"
                    type="text"
                    value={config.area || ''}
                    onChange={(e) => onUpdate({ area: e.target.value })}
                    placeholder=""
                  />
                </div>
                <div>
                  <Label htmlFor="position" className="text-xs mb-1">Position</Label>
                  <Input
                    id="position"
                    type="text"
                    value={config.position || ''}
                    onChange={(e) => onUpdate({ position: e.target.value })}
                    placeholder=""
                  />
                </div>
                <div>
                  <Label htmlFor="quantity" className="text-xs mb-1">Quantity</Label>
                  <Input
                    id="quantity"
                    type="number"
                    min="1"
                    value={(config as any).quantity || ''}
                    onChange={(e) => onUpdate({ quantity: parseInt(e.target.value) || 1 } as any)}
                    placeholder="1"
                  />
                </div>
                <div></div> {/* Empty space to maintain grid-cols-4 */}
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
                    onChange={(e) => onUpdate({ width_mm: parseInt(e.target.value) || undefined })}
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
                    onChange={(e) => onUpdate({ height_mm: parseInt(e.target.value) || undefined })}
                    placeholder="700"
                  />
                </div>
                <div></div> {/* Empty space */}
                <div></div> {/* Empty space */}
              </div>
            </div>
          )}
        </div>

        {/* 2. FABRIC DROP - Drop de la tela Normal e Invertida (Hidden for Triple Shade) */}
        {!isTripleShade && (
          <div>
            <Label className="text-sm font-medium mb-4 block">FABRIC DROP</Label>
            <div className="grid grid-cols-4 gap-6">
              {FABRIC_DROP_OPTIONS.map((option) => {
                const isSelected = config.fabricDrop === option.id;
                return (
                  <div key={option.id} className="flex flex-col items-center">
                    <button
                      onClick={() => onUpdate({ fabricDrop: isSelected ? undefined : option.id })}
                      className={`w-full aspect-square rounded-lg transition-all relative flex items-center justify-center ${
                        isSelected
                          ? 'border-2 border-gray-400 bg-gray-600'
                          : 'border border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm'
                      }`}
                      style={{ padding: '2px' }}
                    >
                      {/* Imagen - 5% más chica que el card (95% del tamaño) respetando padding de 2px */}
                      <div className="rounded overflow-hidden border border-gray-200 bg-gray-100" style={{ width: '95%', height: '95%' }}>
                        {/* TODO: Add image from Supabase storage */}
                      </div>
                    </button>
                    
                    {/* Nombre abajo del card */}
                    <span className={`text-sm font-semibold block mt-2 ${isSelected ? 'text-gray-900' : 'text-gray-900'}`}>
                      {option.name}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* 3. INSTALLATION TYPE & LOCATION - En una sola línea */}
        <div>
          <Label className="text-sm font-medium mb-4 block">INSTALLATION TYPE & LOCATION</Label>
          <div className="grid grid-cols-4 gap-6">
            {/* Installation Type Options */}
            {INSTALLATION_TYPE_OPTIONS.map((option) => {
              const isSelected = config.installationType === option.id;
              return (
                <div key={option.id} className="flex flex-col items-center">
                  <button
                    onClick={() => onUpdate({ installationType: isSelected ? undefined : option.id })}
                    className={`w-full aspect-square rounded-lg transition-all relative flex items-center justify-center ${
                      isSelected
                        ? 'border-2 border-gray-400 bg-gray-600'
                        : 'border border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm'
                    }`}
                    style={{ padding: '2px' }}
                  >
                    {/* Imagen - 5% más chica que el card (95% del tamaño) respetando padding de 2px */}
                    <div className="rounded overflow-hidden border border-gray-200 bg-gray-100" style={{ width: '95%', height: '95%' }}>
                      {option.imageUrl ? (
                        <img
                          src={option.imageUrl}
                          alt={option.name}
                          className="w-full h-full object-cover"
                          onError={(e) => {
                            const target = e.target as HTMLImageElement;
                            target.style.display = 'none';
                          }}
                        />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center">
                          <span className="text-xs text-gray-500">{option.name}</span>
                        </div>
                      )}
                    </div>
                  </button>
                  
                  {/* Nombre abajo del card */}
                  <span className={`text-sm font-semibold block mt-2 ${isSelected ? 'text-gray-900' : 'text-gray-900'}`}>
                    {option.name}
                  </span>
                </div>
              );
            })}
            
            {/* Installation Location Options */}
            {INSTALLATION_LOCATION_OPTIONS.map((option) => {
              const isSelected = config.installationLocation === option.id;
              return (
                <div key={option.id} className="flex flex-col items-center">
                  <button
                    onClick={() => onUpdate({ installationLocation: isSelected ? undefined : option.id })}
                    className={`w-full aspect-square rounded-lg transition-all relative flex items-center justify-center ${
                      isSelected
                        ? 'border-2 border-gray-400 bg-gray-600'
                        : 'border border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm'
                    }`}
                    style={{ padding: '2px' }}
                  >
                    {/* Imagen - 5% más chica que el card (95% del tamaño) respetando padding de 2px */}
                    <div className="rounded overflow-hidden border border-gray-200 bg-gray-100" style={{ width: '95%', height: '95%' }}>
                      {option.imageUrl ? (
                        <img
                          src={option.imageUrl}
                          alt={option.name}
                          className="w-full h-full object-cover"
                          onError={(e) => {
                            const target = e.target as HTMLImageElement;
                            target.style.display = 'none';
                          }}
                        />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center">
                          <span className="text-xs text-gray-500">{option.name}</span>
                        </div>
                      )}
                    </div>
                  </button>
                  
                  {/* Nombre abajo del card */}
                  <span className={`text-sm font-semibold block mt-2 ${isSelected ? 'text-gray-900' : 'text-gray-900'}`}>
                    {option.name}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}

