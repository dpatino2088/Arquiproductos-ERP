import { useMemo, useEffect } from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../../components/ui/SelectShadcn';
import { useBOMComponents } from '../../../hooks/useBOM';
import { useBOMTemplates } from '../../../hooks/useBOMTemplates';
import { useOrganizationContext } from '../../../context/OrganizationContext';

interface OperatingSystemStepProps {
  config: CurtainConfiguration | ProductConfig;
  onUpdate: (updates: Partial<CurtainConfiguration | ProductConfig>) => void;
}

export default function OperatingSystemStep({ config, onUpdate }: OperatingSystemStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const productTypeId = (config as any).productTypeId;
  
  // Initialize default values if they don't exist
  useEffect(() => {
    const updates: Partial<ProductConfig> = {};
    let hasUpdates = false;
    
    // Set default drive_type if not present
    if (!(config as any).drive_type && !config.operatingSystem) {
      updates.drive_type = 'motor';
      updates.operatingSystem = 'motorized';
      hasUpdates = true;
    }
    
    // Set default hardware_color if not present
    if (!(config as any).hardwareColor && !(config as any).hardware_color && !config.operatingSystemColor) {
      updates.hardwareColor = 'white';
      updates.hardware_color = 'white';
      updates.operatingSystemColor = 'white';
      hasUpdates = true;
    }
    
    // Set default bottom_rail_type if not present
    if (!(config as any).bottom_rail_type && !(config as any).bottomBar) {
      updates.bottom_rail_type = 'standard';
      updates.bottomBar = 'standard';
      hasUpdates = true;
    }
    
    if (hasUpdates) {
      onUpdate(updates);
    }
  }, []); // Only run once on mount
  
  // Load BOM Templates for this product type
  const { templates: bomTemplates, loading: loadingBOMTemplates } = useBOMTemplates(productTypeId || undefined);
  
  // Find BOM Template matching product type and color
  const currentBOMTemplate = useMemo(() => {
    if (!bomTemplates.length || !productTypeId) {
      return null;
    }
    
    // Get color from hardwareColor or operatingSystemColor (default to white)
    const hardwareColor = (config as any).hardwareColor || (config as any).hardware_color || config.operatingSystemColor || 'white';
    const colorName = hardwareColor === 'white' ? 'White' : hardwareColor === 'black' ? 'Black' : 'White';
    
    // Find template by name pattern: "{ProductType} - {Color}"
    const template = bomTemplates.find(t => {
      if (!t.name) return false;
      const nameUpper = t.name.toUpperCase();
      return nameUpper.includes(colorName.toUpperCase());
    });
    
    // If no template found by color, use the first template for this product type
    return template || bomTemplates[0] || null;
  }, [bomTemplates, productTypeId, config.operatingSystemColor, (config as any).hardwareColor, (config as any).hardware_color]);
  
  // Load BOM Components for the selected template
  const { components: bomComponents, loading: loadingBOMComponents } = useBOMComponents(
    currentBOMTemplate?.id || null
  );
  
  // Color options
  const colorOptions = [
    { value: 'white', label: 'White' },
    { value: 'black', label: 'Black' },
    { value: 'silver', label: 'Silver' },
    { value: 'bronze', label: 'Bronze' },
  ];
  
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        {/* Block Configuration Section */}
        <div>
          <Label className="text-sm font-medium mb-4 block">BLOCK CONFIGURATION</Label>
          
          {/* Drive Type */}
          <div className="mb-4">
            <Label htmlFor="drive_type" className="text-xs mb-1">Drive Type</Label>
            <SelectShadcn
              value={(config as any).drive_type || 
                     ((config as any).operatingSystem === 'manual' ? 'manual' : 'motor') || 
                     'motor'}
              onValueChange={(value) => {
                const driveType = value as 'manual' | 'motor';
                onUpdate({ 
                  drive_type: driveType,
                  operatingSystem: driveType === 'manual' ? 'manual' : 'motorized'
                });
              }}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select drive type" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="motor">Motor</SelectItem>
                <SelectItem value="manual">Manual</SelectItem>
              </SelectContent>
            </SelectShadcn>
            <p className="text-xs text-gray-500 mt-1">
              Determines which drive block components are included in the BOM
            </p>
          </div>
          
          {/* Hardware Color (applies to all colored components) */}
          <div className="mb-4">
            <Label htmlFor="hardwareColor" className="text-xs mb-1">Hardware Color</Label>
            <SelectShadcn
              value={(config as any).hardwareColor || (config as any).hardware_color || config.operatingSystemColor || 'white'}
              onValueChange={(value) => onUpdate({ 
                hardwareColor: value,
                hardware_color: value,
                operatingSystemColor: value 
              })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select hardware color" />
              </SelectTrigger>
              <SelectContent>
                {colorOptions.map(opt => (
                  <SelectItem key={opt.value} value={opt.value}>
                    {opt.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
            <p className="text-xs text-gray-500 mt-1">
              Applies to brackets, bottom rail, cassette, and other colored components
            </p>
          </div>
          
          {/* Bottom Rail Type */}
          <div className="mb-4">
            <Label htmlFor="bottom_rail_type" className="text-xs mb-1">Bottom Rail Type</Label>
            <SelectShadcn
              value={(config as any).bottom_rail_type || (config as any).bottomBar || 'standard'}
              onValueChange={(value) => {
                const bottomRailType = value === 'none' ? 'standard' : value;
                onUpdate({ 
                  bottom_rail_type: bottomRailType as 'standard' | 'wrapped',
                  bottomBar: value === 'none' ? 'none' : bottomRailType
                });
              }}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select bottom rail type" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="standard">Standard</SelectItem>
                <SelectItem value="wrapped">Wrapped</SelectItem>
              </SelectContent>
            </SelectShadcn>
            <p className="text-xs text-gray-500 mt-1">
              Determines which bottom rail profile is included in the BOM
            </p>
          </div>
          
          {/* Cassette */}
          <div className="mb-4">
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="cassette"
                checked={(config as any).cassette || false}
                onChange={(e) => {
                  const checked = e.target.checked;
                  onUpdate({ 
                    cassette: checked,
                    cassette_type: checked ? ((config as any).cassette_type || 'standard') : undefined
                  });
                }}
                className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary"
              />
              <Label htmlFor="cassette" className="text-xs mb-0 cursor-pointer">
                Include Cassette
              </Label>
            </div>
            {(config as any).cassette && (
              <div className="ml-6 mt-2">
                <Label htmlFor="cassette_type" className="text-xs mb-1">Cassette Type</Label>
                <SelectShadcn
                  value={(config as any).cassette_type || 'standard'}
                  onValueChange={(value) => onUpdate({ cassette_type: value as 'standard' | 'recessed' | 'surface' })}
                >
                  <SelectTrigger className="h-8 text-xs">
                    <SelectValue placeholder="Select cassette type" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="standard">Standard</SelectItem>
                    <SelectItem value="recessed">Recessed</SelectItem>
                    <SelectItem value="surface">Surface Mount</SelectItem>
                  </SelectContent>
                </SelectShadcn>
                <p className="text-xs text-gray-500 mt-1">
                  Determines which cassette profile is included in the BOM
                </p>
              </div>
            )}
            <p className="text-xs text-gray-500 mt-1 ml-6">
              Includes cassette profile and end caps in the BOM
            </p>
          </div>
          
          {/* Side Channel */}
          <div className="mb-4">
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="side_channel"
                checked={(config as any).side_channel || false}
                onChange={(e) => {
                  const checked = e.target.checked;
                  onUpdate({ 
                    side_channel: checked,
                    side_channel_type: checked ? ((config as any).side_channel_type || 'both') : undefined
                  });
                }}
                className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary"
              />
              <Label htmlFor="side_channel" className="text-xs mb-0 cursor-pointer">
                Include Side Channel
              </Label>
            </div>
            {(config as any).side_channel && (
              <div className="ml-6 mt-2">
                <Label htmlFor="side_channel_type" className="text-xs mb-1">Side Channel Position</Label>
                <SelectShadcn
                  value={(config as any).side_channel_type || 'both'}
                  onValueChange={(value) => onUpdate({ side_channel_type: value as 'left' | 'right' | 'both' })}
                >
                  <SelectTrigger className="h-8 text-xs">
                    <SelectValue placeholder="Select side channel position" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="left">Left Side</SelectItem>
                    <SelectItem value="right">Right Side</SelectItem>
                    <SelectItem value="both">Both Sides</SelectItem>
                  </SelectContent>
                </SelectShadcn>
                <p className="text-xs text-gray-500 mt-1">
                  Determines which side channel profiles are included in the BOM
                </p>
              </div>
            )}
            <p className="text-xs text-gray-500 mt-1 ml-6">
              Includes side channel profiles and required accessories in the BOM
            </p>
          </div>
        </div>
        
        {/* BOM Components Summary (Optional - only show if BOMTemplate exists) */}
        {currentBOMTemplate && bomComponents.length > 0 && (
          <div className="border-t border-gray-200 pt-6 mt-6">
            <Label className="text-sm font-medium mb-4 block">BOM COMPONENTS PREVIEW</Label>
            <div className="bg-gray-50 p-4 rounded-lg">
              <div className="text-xs text-gray-600 space-y-1">
                <div className="flex justify-between">
                  <span>Template:</span>
                  <span className="font-medium">{currentBOMTemplate.name}</span>
                </div>
                <div className="flex justify-between">
                  <span>Components:</span>
                  <span className="font-medium">{bomComponents.length}</span>
                </div>
                <div className="text-xs text-gray-500 mt-2">
                  Components will be generated based on your selections above
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
