import { CurtainConfiguration } from '../CurtainConfigurator';
import Label from '../../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../../components/ui/SelectShadcn';
import Input from '../../../components/ui/Input';
import { useOperatingDrives, useManufacturers } from '../../../hooks/useCatalog';

interface OperatingSystemStepProps {
  config: CurtainConfiguration;
  onUpdate: (updates: Partial<CurtainConfiguration>) => void;
}

// Operating Drives por Manufacturer
const OPERATING_DRIVES = [
  // Manual (de Motion)
  { 
    id: 'roller-m', 
    manufacturer: 'motion',
    system: 'manual',
    name: 'ROLLER M', 
    code: 'ROLLER-M',
    imageUrl: '/images/operating-drives/roller-m.jpg'
  },
  { 
    id: 'roller-m-1-1.5', 
    manufacturer: 'motion',
    system: 'manual',
    name: 'ROLLER M 1:1.5', 
    code: 'ROLLER-M-1-1.5',
    imageUrl: '/images/operating-drives/roller-m-1-1.5.jpg'
  },
  { 
    id: 'roller-m-1-3', 
    manufacturer: 'motion',
    system: 'manual',
    name: 'ROLLER M 1:3', 
    code: 'ROLLER-M-1-3',
    imageUrl: '/images/operating-drives/roller-m-1-3.jpg'
  },
  // Lutron (Motorized)
  { 
    id: 'lutron-edu100', 
    manufacturer: 'lutron',
    system: 'motorized',
    name: 'LUTRON-EDU100', 
    code: 'LUTRON-EDU100',
    imageUrl: '/images/operating-drives/lutron-edu100.jpg'
  },
  { 
    id: 'lutron-edu150', 
    manufacturer: 'lutron',
    system: 'motorized',
    name: 'LUTRON-EDU150', 
    code: 'LUTRON-EDU150',
    imageUrl: '/images/operating-drives/lutron-edu150.jpg'
  },
  { 
    id: 'lutron-edu300', 
    manufacturer: 'lutron',
    system: 'motorized',
    name: 'LUTRON-EDU300', 
    code: 'LUTRON-EDU300',
    imageUrl: '/images/operating-drives/lutron-edu300.jpg'
  },
  { 
    id: 'lutron-edu64', 
    manufacturer: 'lutron',
    system: 'motorized',
    name: 'LUTRON-EDU64', 
    code: 'LUTRON-EDU64',
    imageUrl: '/images/operating-drives/lutron-edu64.jpg'
  },
  { 
    id: 'inter-lutron', 
    manufacturer: 'lutron',
    system: 'motorized',
    name: 'INTER. LUTRON', 
    code: 'INTER-LUTRON',
    imageUrl: '/images/operating-drives/inter-lutron.jpg'
  },
  // Motion Motorized
  { 
    id: 'cm-09-qc120-m', 
    manufacturer: 'motion',
    system: 'motorized',
    name: 'CM-09-QC120-M', 
    code: 'CM-09-QC120-M',
    imageUrl: '/images/operating-drives/cm-09-qc120-m.jpg'
  },
  { 
    id: 'cm-10-qc120-m', 
    manufacturer: 'motion',
    system: 'motorized',
    name: 'CM-10-QC120-M', 
    code: 'CM-10-QC120-M',
    imageUrl: '/images/operating-drives/cm-10-qc120-m.jpg'
  },
  { 
    id: 'cm-09-c120-m', 
    manufacturer: 'motion',
    system: 'motorized',
    name: 'CM-09-C120-M', 
    code: 'CM-09-C120-M',
    imageUrl: '/images/operating-drives/cm-09-c120-m.jpg'
  },
  { 
    id: 'cm-09-qc120-l', 
    manufacturer: 'motion',
    system: 'motorized',
    name: 'CM-09-QC120-L', 
    code: 'CM-09-QC120-L',
    imageUrl: '/images/operating-drives/cm-09-qc120-l.jpg'
  },
  { 
    id: 'cm-10-qc120-l', 
    manufacturer: 'motion',
    system: 'motorized',
    name: 'CM-10-QC120-L', 
    code: 'CM-10-QC120-L',
    imageUrl: '/images/operating-drives/cm-10-qc120-l.jpg'
  },
  { 
    id: 'cm-09-c120-l', 
    manufacturer: 'motion',
    system: 'motorized',
    name: 'CM-09-C120-L', 
    code: 'CM-09-C120-L',
    imageUrl: '/images/operating-drives/cm-09-c120-l.jpg'
  },
  { 
    id: 'inter-coulisse-m', 
    manufacturer: 'motion',
    system: 'motorized',
    name: 'INTER. COULISSE-M', 
    code: 'INTER-COULISSE-M',
    imageUrl: '/images/operating-drives/inter-coulisse-m.jpg'
  },
  { 
    id: 'inter-coulisse-l', 
    manufacturer: 'motion',
    system: 'motorized',
    name: 'INTER. COULISSE-L', 
    code: 'INTER-COULISSE-L',
    imageUrl: '/images/operating-drives/inter-coulisse-l.jpg'
  },
  // Vertilux (Motorized)
  { 
    id: 're-lion', 
    manufacturer: 'vertilux',
    system: 'motorized',
    name: 'Re-Lion', 
    code: 'RE-LION',
    imageUrl: '/images/operating-drives/re-lion.jpg'
  },
];

export default function OperatingSystemStep({ config, onUpdate }: OperatingSystemStepProps) {
  // Cargar datos del Catalog
  const { drives: catalogDrives, loading: loadingDrives } = useOperatingDrives();
  const { manufacturers: catalogManufacturers, loading: loadingManufacturers } = useManufacturers();
  
  // Mapear manufacturers del Catalog a formato esperado
  // Normalizar nombres a IDs esperados: 'motion' (Coulisse), 'vertilux', 'lutron'
  const manufacturers = catalogManufacturers.map(m => {
    const nameLower = m.name.toLowerCase();
    let normalizedId: string;
    
    // Mapear nombres conocidos a IDs esperados
    if (nameLower.includes('coulisse') || nameLower.includes('motion')) {
      normalizedId = 'motion';
    } else if (nameLower.includes('vertilux')) {
      normalizedId = 'vertilux';
    } else if (nameLower.includes('lutron')) {
      normalizedId = 'lutron';
    } else {
      // Fallback: usar el nombre normalizado
      normalizedId = m.name.toLowerCase().replace(/\s+/g, '-');
    }
    
    return {
      id: normalizedId,
      name: m.name,
      code: m.code || m.name.substring(0, 3).toUpperCase(),
    };
  });
  
  // Mapear operating drives del Catalog a formato esperado
  const drives = catalogDrives.map(d => {
    // Normalizar manufacturer desde metadata o nombre
    let normalizedManufacturer = d.manufacturer?.toLowerCase() || 'motion';
    if (normalizedManufacturer.includes('coulisse') || normalizedManufacturer.includes('motion')) {
      normalizedManufacturer = 'motion';
    } else if (normalizedManufacturer.includes('vertilux')) {
      normalizedManufacturer = 'vertilux';
    } else if (normalizedManufacturer.includes('lutron')) {
      normalizedManufacturer = 'lutron';
    }
    
    // Normalizar system desde metadata
    let normalizedSystem = d.system?.toLowerCase() || 'manual';
    if (normalizedSystem !== 'manual' && normalizedSystem !== 'motorized') {
      // Intentar inferir desde metadata
      const metadata = d.metadata || {};
      if (metadata.system) {
        normalizedSystem = metadata.system.toLowerCase();
      } else if (metadata.motorized === true || metadata.manual === false) {
        normalizedSystem = 'motorized';
      } else {
        normalizedSystem = 'manual';
      }
    }
    
    return {
      id: d.id,
      manufacturer: normalizedManufacturer,
      system: normalizedSystem,
      name: d.name,
      code: d.code || d.sku,
      imageUrl: d.metadata?.imageUrl || undefined,
    };
  });
  
  // Fallback a datos hardcodeados si no hay datos del Catalog
  const useHardcodedData = catalogDrives.length === 0 && !loadingDrives;
  const finalDrives = useHardcodedData ? OPERATING_DRIVES : drives;
  const finalManufacturers = useHardcodedData ? [
    { id: 'motion', name: 'Coulisse', code: 'COU' },
    { id: 'vertilux', name: 'Vertilux', code: 'VER' },
    { id: 'lutron', name: 'Lutron', code: 'LUT' },
  ] : manufacturers;
  
  // Filtrar operating drives según el manufacturer y system seleccionados
  const filteredDrives = finalDrives.filter(drive => {
    const matchesManufacturer = !config.operatingSystemManufacturer || 
      drive.manufacturer?.toLowerCase() === config.operatingSystemManufacturer?.toLowerCase();
    const matchesSystem = !config.operatingSystem || 
      drive.system?.toLowerCase() === config.operatingSystem?.toLowerCase();
    
    if (import.meta.env.DEV && config.operatingSystem && config.operatingSystemManufacturer) {
      console.log('Filtering drives:', {
        drive: { id: drive.id, name: drive.name, manufacturer: drive.manufacturer, system: drive.system },
        config: { system: config.operatingSystem, manufacturer: config.operatingSystemManufacturer },
        matchesManufacturer,
        matchesSystem,
        passes: matchesManufacturer && matchesSystem
      });
    }
    
    return matchesManufacturer && matchesSystem;
  });
  
  // Verificar si hay un drive manual seleccionado (Manual de Motion)
  const selectedDrive = finalDrives.find((d: any) => d.id === config.operatingSystemVariant);
  const isManualSystem = config.operatingSystem === 'manual' && 
                         config.operatingSystemManufacturer === 'motion' && 
                         selectedDrive?.system === 'manual';
  
  // Determinar opciones de Tube Size según Clutch Size
  const getTubeSizeOptions = () => {
    if (config.clutchSize === 'S') {
      return ['standard', '42mm'];
    } else if (config.clutchSize === 'M') {
      return ['standard', '65mm'];
    } else if (config.clutchSize === 'L') {
      return ['standard', '80mm'];
    }
    return ['standard', '42mm', '65mm', '80mm'];
  };
  
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        {/* System & Manufacturer */}
        <div>
          <Label className="text-sm font-medium mb-4 block">OPERATING SYSTEM</Label>
          
          {/* Field para seleccionar System */}
          <div className="mb-4">
            <Label htmlFor="system" className="text-xs mb-1">System</Label>
            <SelectShadcn
              value={config.operatingSystem || ''}
              onValueChange={(value) => {
                const newSystem = value as 'manual' | 'motorized';
                // Si cambia a manual y el manufacturer actual no es válido, limpiarlo
                if (newSystem === 'manual' && config.operatingSystemManufacturer === 'lutron') {
                  onUpdate({ operatingSystem: newSystem, operatingSystemManufacturer: undefined, operatingSystemVariant: undefined });
                } else {
                  onUpdate({ operatingSystem: newSystem });
                }
              }}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select system" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="manual">Manual</SelectItem>
                <SelectItem value="motorized">Motorized</SelectItem>
              </SelectContent>
            </SelectShadcn>
          </div>
          
          {/* Field para seleccionar Manufacturer */}
          <div className="mb-4">
            <Label htmlFor="manufacturer" className="text-xs mb-1">Manufacturer</Label>
            <SelectShadcn
              value={config.operatingSystemManufacturer || ''}
              onValueChange={(value) => onUpdate({ operatingSystemManufacturer: value as 'motion' | 'lutron' | 'vertilux', operatingSystemVariant: undefined })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select manufacturer" />
              </SelectTrigger>
              <SelectContent>
                {loadingManufacturers ? (
                  <SelectItem value="loading" disabled>Loading manufacturers...</SelectItem>
                ) : finalManufacturers.length === 0 ? (
                  <SelectItem value="no-manufacturers" disabled>No manufacturers available</SelectItem>
                ) : (
                  (() => {
                    // Filtrar manufacturers según el sistema seleccionado
                    let availableManufacturers = finalManufacturers;
                    
                    if (config.operatingSystem === 'manual') {
                      // Para Manual: solo Motion (Coulisse) y Vertilux
                      availableManufacturers = finalManufacturers.filter(
                        mfg => mfg.id === 'motion' || mfg.id === 'vertilux'
                      );
                    } else if (config.operatingSystem === 'motorized') {
                      // Para Motorized: Motion (Coulisse), Vertilux (Re-Lion), Lutron
                      availableManufacturers = finalManufacturers.filter(
                        mfg => mfg.id === 'motion' || mfg.id === 'vertilux' || mfg.id === 'lutron'
                      );
                    }
                    
                    if (availableManufacturers.length === 0) {
                      return <SelectItem value="no-match" disabled>No manufacturers available for selected system</SelectItem>;
                    }
                    
                    return availableManufacturers.map((mfg) => (
                      <SelectItem key={mfg.id} value={mfg.id}>
                        {mfg.name}
                      </SelectItem>
                    ));
                  })()
                )}
              </SelectContent>
            </SelectShadcn>
          </div>
          
          {/* Field para seleccionar Operating Drive - Solo se muestra si hay System y Manufacturer */}
          {config.operatingSystem && config.operatingSystemManufacturer ? (
            <div className="mb-4">
              <Label className="text-xs mb-1 block">Operating Drive</Label>
              {loadingDrives ? (
                <div className="text-center text-gray-500 py-8 border border-gray-200 rounded-lg">
                  <p className="text-sm">Loading operating drives...</p>
                </div>
              ) : filteredDrives.length === 0 ? (
                <div className="text-center text-gray-500 py-8 border border-gray-200 rounded-lg">
                  <p className="text-sm">No operating drives available for selected system and manufacturer</p>
                </div>
              ) : (
                <div className="grid grid-cols-4 gap-6">
                  {filteredDrives.map((drive) => {
                  const isSelected = config.operatingSystemVariant === drive.id;
                  return (
                    <div key={drive.id} className="flex flex-col items-center">
                      <button
                        onClick={() => onUpdate({ operatingSystemVariant: isSelected ? undefined : drive.id })}
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
                          {drive.imageUrl ? (
                            <img
                              src={drive.imageUrl}
                              alt={drive.name}
                              className="w-full h-full object-cover"
                              onError={(e) => {
                                const target = e.target as HTMLImageElement;
                                target.style.display = 'none';
                              }}
                            />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center">
                              <span className="text-xs text-gray-500">{drive.name}</span>
                            </div>
                          )}
                        </div>
                      </button>
                      
                      {/* SKU/Código abajo del card */}
                      <span className={`text-xs block mt-2 font-mono ${isSelected ? 'text-gray-900 font-semibold' : 'text-gray-600'}`}>
                        {drive.code}
                      </span>
                    </div>
                  );
                  })}
                </div>
              )}
            </div>
          ) : config.operatingSystem && !config.operatingSystemManufacturer ? (
            <div className="mb-4">
              <Label className="text-xs mb-1 block">Operating Drive</Label>
              <div className="text-center text-gray-500 py-8 border border-gray-200 rounded-lg">
                <p className="text-sm">Please select a manufacturer to view operating drives</p>
              </div>
            </div>
          ) : null}
          
          {/* Field para seleccionar Side Drive - Solo se muestra si hay Operating Drive seleccionado */}
          {config.operatingSystemVariant && (
            <div className="mb-4">
              <Label htmlFor="sideDrive" className="text-xs mb-1">Side Drive</Label>
              <SelectShadcn
                value={config.operatingSystemSide || ''}
                onValueChange={(value) => onUpdate({ operatingSystemSide: value as 'left' | 'right' })}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select side" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="left">Left</SelectItem>
                  <SelectItem value="right">Right</SelectItem>
                </SelectContent>
              </SelectShadcn>
            </div>
          )}
          
          {/* Campos específicos para Manual - Solo se muestran si System = Manual y hay un drive manual seleccionado */}
          {isManualSystem && (
            <div className="mt-6 space-y-4">
              <Label className="text-sm font-medium mb-4 block">MANUAL CONFIGURATION</Label>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label htmlFor="clutchSize" className="text-xs mb-1">Clutch Size</Label>
                  <SelectShadcn
                    value={config.clutchSize || ''}
                    onValueChange={(value) => onUpdate({ clutchSize: value as 'S' | 'M' | 'L' })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select clutch size" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="S">S</SelectItem>
                      <SelectItem value="M">M</SelectItem>
                      <SelectItem value="L">L</SelectItem>
                    </SelectContent>
                  </SelectShadcn>
                </div>
                
                <div>
                  <Label htmlFor="color" className="text-xs mb-1">Color</Label>
                  <SelectShadcn
                    value={config.operatingSystemColor || ''}
                    onValueChange={(value) => onUpdate({ operatingSystemColor: value as 'white' | 'black' })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select color" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="white">White</SelectItem>
                      <SelectItem value="black">Black</SelectItem>
                    </SelectContent>
                  </SelectShadcn>
                </div>
                
                <div>
                  <Label htmlFor="chainColor" className="text-xs mb-1">Chain Color</Label>
                  <SelectShadcn
                    value={config.chainColor || ''}
                    onValueChange={(value) => onUpdate({ chainColor: value as 'white' | 'black' })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select chain color" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="white">White</SelectItem>
                      <SelectItem value="black">Black</SelectItem>
                    </SelectContent>
                  </SelectShadcn>
                </div>
                
                <div>
                  <Label htmlFor="height" className="text-xs mb-1">Height</Label>
                  <SelectShadcn
                    value={config.operatingSystemHeight || ''}
                    onValueChange={(value) => onUpdate({ operatingSystemHeight: value as 'standard' | 'custom' })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select height" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="standard">Standard</SelectItem>
                      <SelectItem value="custom">Custom Height</SelectItem>
                    </SelectContent>
                  </SelectShadcn>
                </div>
                
                <div>
                  <Label htmlFor="tubeSize" className="text-xs mb-1">Tube Size</Label>
                  <SelectShadcn
                    value={config.tubeSize || ''}
                    onValueChange={(value) => onUpdate({ tubeSize: value as 'standard' | '42mm' | '65mm' | '80mm' })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select tube size" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="standard">Standard</SelectItem>
                      {getTubeSizeOptions().filter(opt => opt !== 'standard').map(opt => (
                        <SelectItem key={opt} value={opt}>Custom {opt}</SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

