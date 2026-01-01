import { useMemo, useEffect, useState } from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../../components/ui/SelectShadcn';
import { useBOMComponents } from '../../../hooks/useBOM';
import { useBOMTemplates } from '../../../hooks/useBOMTemplates';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { supabase } from '../../../lib/supabase/client';

interface OperatingSystemStepProps {
  config: CurtainConfiguration | ProductConfig;
  onUpdate: (updates: Partial<CurtainConfiguration | ProductConfig>) => void;
}

// Drive options (Motor SKUs from your list)
const DRIVE_SKUS = [
  'CM-06',
  'CM-06-E-R',
  'CM-07',
  'CM-08',
  'CM-08-E',
  'CM-09-C120',
  'CM-09-MC120',
  'CM-09-QC120',
  'CM-09-QMC120',
  'CM-10-QC120',
  'CM-10-QMC120',
];

// Tube Type options - RTU-42, RTU-50, RTU-65, RTU-80
const TUBE_TYPE_OPTIONS = [
  { id: 'RTU-42' as const, name: 'RTU-42', maxWidth_m: 3.00 },
  { id: 'RTU-50' as const, name: 'RTU-50', maxWidth_m: 3.50 },
  { id: 'RTU-65' as const, name: 'RTU-65', maxWidth_m: 4.00 },
  { id: 'RTU-80' as const, name: 'RTU-80', maxWidth_m: 5.00 },
];

// Calculate recommended tube type based on width (in meters)
// Rule: You can use a tube with MORE capacity but never one with LESS
// RTU-42: up to 3.00 m, RTU-50: up to 3.50 m, RTU-65: up to 4.00 m, RTU-80: up to 5.00 m
function calculateRecommendedTubeType(width_mm: number | undefined): 'RTU-42' | 'RTU-50' | 'RTU-65' | 'RTU-80' {
  if (!width_mm) return 'RTU-42'; // Default
  
  const width_m = width_mm / 1000; // Convert mm to meters
  
  // Rules based on max width in meters:
  // RTU-42: up to 3.00 m (3000 mm)
  // RTU-50: up to 3.50 m (3500 mm)
  // RTU-65: up to 4.00 m (4000 mm)
  // RTU-80: up to 5.00 m (5000 mm)
  if (width_m <= 3.00) return 'RTU-42';
  if (width_m <= 3.50) return 'RTU-50';
  if (width_m <= 4.00) return 'RTU-65';
  return 'RTU-80';
}

// Check if a tube type is valid for the given width
// Rule: Tube must have capacity >= width (can use more, never less)
function isValidTubeForWidth(tubeType: 'RTU-42' | 'RTU-50' | 'RTU-65' | 'RTU-80', width_mm: number | undefined): boolean {
  if (!width_mm) return true; // Allow any if no width
  
  const width_m = width_mm / 1000;
  const tubeOption = TUBE_TYPE_OPTIONS.find(t => t.id === tubeType);
  
  if (!tubeOption) return false;
  
  // Tube is valid if its max capacity is >= width
  return tubeOption.maxWidth_m >= width_m;
}

export default function OperatingSystemStep({ config, onUpdate }: OperatingSystemStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const productTypeId = (config as any).productTypeId;
  const [motorDescriptions, setMotorDescriptions] = useState<Record<string, string>>({});
  
  // Fetch motor descriptions from CatalogItems
  useEffect(() => {
    const fetchMotorDescriptions = async () => {
      if (!activeOrganizationId) return;
      
      try {
        const { data, error } = await supabase
          .from('CatalogItems')
          .select('sku, item_name, description')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .in('sku', DRIVE_SKUS);
        
        if (!error && data) {
          const descriptions: Record<string, string> = {};
          data.forEach((item: any) => {
            descriptions[item.sku] = item.description || item.item_name || '';
          });
          setMotorDescriptions(descriptions);
        }
      } catch (err) {
        console.error('Error fetching motor descriptions:', err);
      }
    };
    
    fetchMotorDescriptions();
  }, [activeOrganizationId]);
  
  // Create drive options with descriptions
  const driveOptions = useMemo(() => {
    return DRIVE_SKUS.map(sku => ({
      id: sku as any,
      name: sku,
      description: motorDescriptions[sku] || '',
    }));
  }, [motorDescriptions]);
  
  // Initialize default values if they don't exist (except operation_type - no default)
  useEffect(() => {
    const updates: Partial<ProductConfig> = {};
    let hasUpdates = false;
    
    // Do NOT set default operation_type - let user select
    
    // Set default operating_system_variant if not present
    if (!(config as any).operating_system_variant) {
      // Default to standard_m if not set
      (updates as any).operating_system_variant = 'standard_m';
      hasUpdates = true;
    }
    
    // Set default tube_type based on operating_system_variant if not manually set
    const operatingSystemVariant = (config as any).operating_system_variant || 'standard_m';
    const tubeTypeManual = (config as any).tube_type_manual;
    
    if (!(config as any).tube_type && !tubeTypeManual) {
      // Default based on operating_system_variant
      if (operatingSystemVariant === 'standard_m') {
        (updates as any).tube_type = 'RTU-42';
      } else if (operatingSystemVariant === 'standard_l') {
        (updates as any).tube_type = 'RTU-65';
      } else {
        // Fallback: calculate from width
        const width_mm = (config as any).width_mm || (config as any).panels?.[0]?.width_mm;
        const recommendedTube = calculateRecommendedTubeType(width_mm);
        (updates as any).tube_type = recommendedTube;
      }
      hasUpdates = true;
    }
    
    // Don't set default motor_family - let user select from cards
    
    if (hasUpdates) {
      onUpdate(updates);
    }
  }, []); // Only run once on mount
  
  // Auto-update tube type when operating_system_variant changes (if not manually set)
  useEffect(() => {
    const operatingSystemVariant = (config as any).operating_system_variant;
    const tubeTypeManual = (config as any).tube_type_manual;
    const currentTubeType = (config as any).tube_type;
    
    // Only auto-update if not manually set
    if (operatingSystemVariant && !tubeTypeManual) {
      let defaultTube: 'RTU-42' | 'RTU-65' | undefined;
      if (operatingSystemVariant === 'standard_m') {
        defaultTube = 'RTU-42';
      } else if (operatingSystemVariant === 'standard_l') {
        defaultTube = 'RTU-65';
      }
      
      if (defaultTube && currentTubeType !== defaultTube) {
        onUpdate({ tube_type: defaultTube } as any);
      }
    }
  }, [(config as any).operating_system_variant, (config as any).tube_type_manual]);
  
  // Auto-update tube type when width or cassette changes (if not manually set)
  useEffect(() => {
    const width_mm = (config as any).width_mm || (config as any).panels?.[0]?.width_mm;
    const currentTubeType = (config as any).tube_type;
    const cassetteShape = (config as any).cassette_shape || 'none';
    const hasCassette = cassetteShape !== 'none';
    // Only round and square cassette require RTU-42; L_shape is flexible
    const requiresRTU42 = hasCassette && (cassetteShape === 'round' || cassetteShape === 'square');
    const tubeTypeManual = (config as any).tube_type_manual;
    
    // If round/square cassette is selected, tube must be RTU-42 (always enforce this)
    if (requiresRTU42 && currentTubeType !== 'RTU-42') {
      onUpdate({ tube_type: 'RTU-42', tube_type_manual: false } as any); // Reset manual flag when forced
      return;
    }
    
    // Only auto-update if not manually set
    if (width_mm && !tubeTypeManual && !requiresRTU42) {
      // Normal recommendation based on width
      const recommendedTube = calculateRecommendedTubeType(width_mm);
      if (currentTubeType !== recommendedTube && isValidTubeForWidth(recommendedTube, width_mm)) {
        onUpdate({ tube_type: recommendedTube });
      }
    }
    
    // If manually set but tube doesn't have enough capacity, force update
    if (width_mm && currentTubeType && !isValidTubeForWidth(currentTubeType as any, width_mm) && !requiresRTU42) {
      const recommendedTube = calculateRecommendedTubeType(width_mm);
      onUpdate({ tube_type: recommendedTube, tube_type_manual: false } as any);
    }
  }, [(config as any).width_mm, (config as any).panels, (config as any).cassette_shape, (config as any).tube_type, (config as any).tube_type_manual]);
  
  // Load BOM Templates for this product type
  const { templates: bomTemplates, loading: loadingBOMTemplates } = useBOMTemplates(productTypeId || undefined);
  
  // Get current selections
  const operationType = (config as any).operation_type || (config as any).drive_type || undefined;
  const isMotor = operationType === 'motor';
  const motorFamily = (config as any).motor_family || undefined;
  const operatingSystemVariant = (config as any).operating_system_variant || 'standard_m';
  const tubeType = (config as any).tube_type || 'RTU-42';
  const tubeTypeManual = (config as any).tube_type_manual;
  const cassetteShape = (config as any).cassette_shape || 'none';
  const hasCassette = cassetteShape !== 'none';
  // Only round and square cassette require RTU-42; L_shape is flexible (allows RTU-42, RTU-50, RTU-65, RTU-80)
  const requiresRTU42 = hasCassette && (cassetteShape === 'round' || cassetteShape === 'square');
  
  // Calculate recommended tube type from width
  const width_mm = (config as any).width_mm || (config as any).panels?.[0]?.width_mm;
  const recommendedTubeType = useMemo(() => {
    // If round/square cassette is selected, only RTU-42 is valid
    if (requiresRTU42) return 'RTU-42';
    return calculateRecommendedTubeType(width_mm);
  }, [width_mm, requiresRTU42]);
  const isTubeAutoSelected = !tubeTypeManual;
  
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        {/* Operating System Variant - Dropdown */}
        <div>
          <Label className="text-sm font-medium mb-4 block">OPERATING SYSTEM VARIANT</Label>
          <div className="mb-4">
            <Label htmlFor="operating_system_variant" className="text-xs mb-1">Operating System Variant</Label>
            <SelectShadcn
              value={operatingSystemVariant || ''}
              onValueChange={(value) => {
                if (!value) {
                  onUpdate({ operating_system_variant: undefined } as any);
                  return;
                }
                const variant = value as 'standard_m' | 'standard_l';
                const updates: any = { operating_system_variant: variant };
                
                // Set default tube_type based on variant (only if not manually set)
                if (!tubeTypeManual) {
                  if (variant === 'standard_m') {
                    updates.tube_type = 'RTU-42';
                  } else if (variant === 'standard_l') {
                    updates.tube_type = 'RTU-65';
                  }
                }
                
                onUpdate(updates);
              }}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select operating system variant" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="standard_m">Standard M</SelectItem>
                <SelectItem value="standard_l">Standard L</SelectItem>
              </SelectContent>
            </SelectShadcn>
            <p className="text-xs text-gray-500 mt-1">
              Determines default tube type (M → RTU-42, L → RTU-65). Can be overridden below.
            </p>
          </div>
        </div>

        {/* Operation Type - Dropdown (as before) */}
        <div>
          <Label className="text-sm font-medium mb-4 block">OPERATION TYPE</Label>
          <div className="mb-4">
            <Label htmlFor="operation_type" className="text-xs mb-1">Operation Type</Label>
            <SelectShadcn
              value={operationType || ''}
              onValueChange={(value) => {
                if (!value) {
                  // Clear selection
                  onUpdate({ 
                    operation_type: undefined,
                    drive_type: undefined,
                    operatingSystem: undefined,
                    motor_family: undefined
                  });
                  return;
                }
                const opType = value as 'manual' | 'motor';
                const updates: any = { 
                  operation_type: opType,
                  drive_type: opType,
                  operatingSystem: opType === 'manual' ? 'manual' : 'motorized'
                };
                // Clear motor_family if switching to manual
                if (opType === 'manual') {
                  updates.motor_family = undefined;
                }
                // Don't set default motor_family - let user select from cards
                onUpdate(updates);
              }}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select operation type" />
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
        </div>

        {/* Drive (Motor Family) - Only show if Motor selected - Cards */}
        {isMotor && (
          <div>
            <Label className="text-sm font-medium mb-4 block">DRIVE</Label>
            {motorFamily ? (
              // Show only selected drive card
              <div className="grid grid-cols-4 gap-6">
                {driveOptions
                  .filter(option => option.id === motorFamily)
                  .map((option) => {
                    return (
                      <div key={option.id} className="flex flex-col items-center">
                        <button
                          onClick={() => onUpdate({ motor_family: undefined })}
                          className="w-full aspect-square rounded-lg transition-all relative flex items-center justify-center border-2 border-gray-400 bg-gray-600"
                          style={{ padding: '2px' }}
                        >
                          <div className="w-full h-full rounded overflow-hidden border border-gray-200 bg-gray-100" style={{ width: '95%', height: '95%' }}>
                            {/* TODO: Add image from Supabase storage */}
                          </div>
                        </button>
                        <div className="text-center mt-2">
                          <span className="text-sm font-semibold block text-gray-900">
                            {option.name}
                          </span>
                          {option.description && (
                            <span className="text-xs text-gray-500 block mt-0.5 line-clamp-2">{option.description}</span>
                          )}
                        </div>
                        <button
                          onClick={() => onUpdate({ motor_family: undefined })}
                          className="mt-2 text-xs text-gray-500 hover:text-gray-700 underline"
                        >
                          Change drive
                        </button>
                      </div>
                    );
                  })}
              </div>
            ) : (
              // Show all drive options
              <div className="grid grid-cols-4 gap-6">
                {driveOptions.map((option) => {
                  return (
                    <div key={option.id} className="flex flex-col items-center">
                      <button
                        onClick={() => onUpdate({ motor_family: option.id })}
                        className="w-full aspect-square rounded-lg transition-all relative flex items-center justify-center border border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm"
                        style={{ padding: '2px' }}
                      >
                        <div className="w-full h-full rounded overflow-hidden border border-gray-200 bg-gray-100" style={{ width: '95%', height: '95%' }}>
                          {/* TODO: Add image from Supabase storage */}
                        </div>
                      </button>
                      <div className="text-center mt-2">
                        <span className="text-sm font-semibold block text-gray-900">
                          {option.name}
                        </span>
                        {option.description && (
                          <span className="text-xs text-gray-500 block mt-0.5 line-clamp-2">{option.description}</span>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}

        {/* Tube Type - Cards with auto-selection (only RTU-42, RTU-65, RTU-80) */}
        <div>
          <Label className="text-sm font-medium mb-4 block">
            TUBE TYPE
            {isTubeAutoSelected && width_mm && (
              <span className="text-xs font-normal text-gray-500 ml-2">
                (Auto-selected based on width: {recommendedTubeType})
              </span>
            )}
            {requiresRTU42 && (
              <span className="text-xs font-normal text-orange-600 ml-2">
                (RTU-42 required for {cassetteShape} cassette)
              </span>
            )}
            {hasCassette && !requiresRTU42 && (
              <span className="text-xs font-normal text-blue-600 ml-2">
                (L-Shape cassette: flexible tube sizes available)
              </span>
            )}
          </Label>
          <div className="grid grid-cols-4 gap-6">
            {TUBE_TYPE_OPTIONS.map((option) => {
              const isSelected = tubeType === option.id;
              const isRecommended = option.id === recommendedTubeType && isTubeAutoSelected;
              // Only round/square cassette require RTU-42; L_shape allows all sizes
              const isDisabled = requiresRTU42 && option.id !== 'RTU-42';
              // Check if tube has enough capacity for width
              const isValidForWidth = isValidTubeForWidth(option.id, width_mm);
              const isDisabledByCapacity = !isValidForWidth;
              
              return (
                <div key={option.id} className="flex flex-col items-center">
                  <button
                    onClick={() => {
                      if (isDisabled || isDisabledByCapacity) return;
                      onUpdate({ 
                        tube_type: option.id,
                        tube_type_manual: true // Mark as manually selected to prevent auto-update
                      } as any);
                    }}
                    disabled={isDisabled || isDisabledByCapacity}
                    className={`w-full aspect-square rounded-lg transition-all relative flex items-center justify-center ${
                      isDisabled || isDisabledByCapacity
                        ? 'border border-gray-200 bg-gray-50 opacity-50 cursor-not-allowed'
                        : isSelected
                        ? 'border-2 border-gray-400 bg-gray-600'
                        : isRecommended
                        ? 'border-2 border-blue-400 bg-blue-50'
                        : 'border border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm'
                    }`}
                    style={{ padding: '2px' }}
                  >
                    <div className={`w-full h-full rounded overflow-hidden border ${
                      isDisabled || isDisabledByCapacity
                        ? 'border-gray-200 bg-gray-100'
                        : isSelected 
                        ? 'border-gray-200 bg-gray-100' 
                        : isRecommended 
                        ? 'border-blue-200 bg-blue-50'
                        : 'border-gray-200 bg-gray-100'
                    }`} style={{ width: '95%', height: '95%' }}>
                      {/* TODO: Add image from Supabase storage */}
                    </div>
                  </button>
                  <div className="text-center">
                    <span className={`text-sm font-semibold block mt-2 ${
                      isDisabled || isDisabledByCapacity
                        ? 'text-gray-400'
                        : isSelected 
                        ? 'text-gray-900' 
                        : isRecommended 
                        ? 'text-blue-700' 
                        : 'text-gray-900'
                    }`}>
                      {option.name}
                    </span>
                    <span className="text-xs text-gray-500 block mt-0.5">
                      Max: {option.maxWidth_m}m
                    </span>
                    {isDisabled && (
                      <span className="text-xs text-orange-600 block mt-0.5">{cassetteShape} cassette requires RTU-42</span>
                    )}
                    {isDisabledByCapacity && !isDisabled && (
                      <span className="text-xs text-red-600 block mt-0.5">Insufficient capacity</span>
                    )}
                    {isRecommended && !isSelected && !isDisabled && !isDisabledByCapacity && (
                      <span className="text-xs text-blue-600 block mt-0.5">Recommended</span>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
          {isTubeAutoSelected && width_mm && !requiresRTU42 && (
            <p className="text-xs text-gray-500 mt-2">
              Tube type is automatically selected based on width ({width_mm}mm = {(width_mm / 1000).toFixed(2)}m). You can use a tube with more capacity, but never one with less. Click a card to override.
            </p>
          )}
          {requiresRTU42 && (
            <p className="text-xs text-orange-600 mt-2">
              {cassetteShape.charAt(0).toUpperCase() + cassetteShape.slice(1)} cassette requires RTU-42 tube type. Only RTU-42 is available for this cassette type.
            </p>
          )}
          {hasCassette && !requiresRTU42 && (
            <p className="text-xs text-blue-600 mt-2">
              L-Shape cassette allows flexible tube sizes (RTU-42, RTU-65, RTU-80) based on your width requirements.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
