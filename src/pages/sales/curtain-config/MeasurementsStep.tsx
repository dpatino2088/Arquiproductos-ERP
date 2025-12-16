import { CurtainConfiguration } from '../CurtainConfigurator';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';

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
  
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        {/* Area and Position */}
        <div>
          <Label className="text-sm font-medium mb-4 block">AREA & POSITION</Label>
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
          </div>
        </div>

        {/* 1. DIMENSIONS - Fields de Medidas */}
        <div>
          <Label className="text-sm font-medium mb-4 block">DIMENSIONS</Label>
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
          </div>
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
                      {/* Checkbox en esquina superior derecha */}
                      <div className="absolute top-2 right-2">
                        {isSelected ? (
                          <div className="w-5 h-5 bg-green-600 rounded-full flex items-center justify-center">
                            <span className="text-white text-xs font-bold">✓</span>
                          </div>
                        ) : (
                          <div className="w-5 h-5 rounded-full border-2 border-gray-400 bg-white"></div>
                        )}
                      </div>
                      
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
                    {/* Checkbox en esquina superior derecha */}
                    <div className="absolute top-2 right-2">
                      {isSelected ? (
                        <div className="w-5 h-5 bg-green-600 rounded-full flex items-center justify-center">
                          <span className="text-white text-xs font-bold">✓</span>
                        </div>
                      ) : (
                        <div className="w-5 h-5 rounded-full border-2 border-gray-400 bg-white"></div>
                      )}
                    </div>
                    
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
                    {/* Checkbox en esquina superior derecha */}
                    <div className="absolute top-2 right-2">
                      {isSelected ? (
                        <div className="w-5 h-5 bg-green-600 rounded-full flex items-center justify-center">
                          <span className="text-white text-xs font-bold">✓</span>
                        </div>
                      ) : (
                        <div className="w-5 h-5 rounded-full border-2 border-gray-400 bg-white"></div>
                      )}
                    </div>
                    
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

