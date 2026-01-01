import { useEffect } from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';

interface HardwareStepProps {
  config: CurtainConfiguration | ProductConfig;
  onUpdate: (updates: Partial<CurtainConfiguration | ProductConfig>) => void;
}

// Hardware Color options
const HARDWARE_COLOR_OPTIONS = [
  { id: 'white' as const, name: 'White' },
  { id: 'black' as const, name: 'Black' },
  { id: 'silver' as const, name: 'Silver' },
  { id: 'bronze' as const, name: 'Bronze' },
];

// Bottom Bar Finish options
const BOTTOM_BAR_FINISH_OPTIONS = [
  { id: 'white' as const, name: 'White' },
  { id: 'black' as const, name: 'Black' },
  { id: 'wrapped' as const, name: 'Wrapped' },
];


// Cassette Shape options - Order: None | Round | Square | L-Shape
const CASSETTE_SHAPE_OPTIONS = [
  { id: 'none' as const, name: 'None' },
  { id: 'round' as const, name: 'Round' },
  { id: 'square' as const, name: 'Square' },
  { id: 'L' as const, name: 'L-Shape' },
];

// Side Channel Type options (only shown when Side Channel = YES)
const SIDE_CHANNEL_TYPE_OPTIONS = [
  { id: 'side_only' as const, name: 'Side Channel only' },
  { id: 'side_and_bottom' as const, name: 'Side Channel + Bottom Channel' },
];

export default function HardwareStep({ config, onUpdate }: HardwareStepProps) {
  // Initialize default values if they don't exist
  useEffect(() => {
    const updates: Partial<ProductConfig> = {};
    let hasUpdates = false;
    
    // Set default hardware_color if not present
    if (!(config as any).hardwareColor && !(config as any).hardware_color && !((config as any).operatingSystemColor)) {
      (updates as any).hardwareColor = 'white';
      (updates as any).hardware_color = 'white';
      (updates as any).operatingSystemColor = 'white';
      hasUpdates = true;
    }
    
    // Set default bottom_bar_finish if not present
    if (!(config as any).bottom_bar_finish) {
      (updates as any).bottom_bar_finish = 'white';
      hasUpdates = true;
    }
    
    // Set default cassette_shape if not present
    if (!(config as any).cassette_shape) {
      (updates as any).cassette_shape = 'none';
      hasUpdates = true;
    }
    
    // Set default side_channel to NO (optional feature)
    if ((config as any).side_channel === undefined && (config as any).side_channel === null) {
      (updates as any).side_channel = false;
      (updates as any).side_channel_type = null;
      hasUpdates = true;
    }
    
    if (hasUpdates) {
      onUpdate(updates);
    }
  }, []); // Only run once on mount

  // Get current selections
  const hardwareColor = (config as any).hardwareColor || (config as any).hardware_color || ((config as any).operatingSystemColor) || 'white';
  const bottomBarFinish = (config as any).bottom_bar_finish || 'white';
  const cassetteShape = (config as any).cassette_shape || 'none';
  const sideChannel = (config as any).side_channel || false;
  const sideChannelType = (config as any).side_channel_type || null;
  
  // Validation: if side_channel is true, side_channel_type must be set
  const sideChannelError = sideChannel && !sideChannelType;
  
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        {/* Hardware Color - Cards */}
        <div>
          <Label className="text-sm font-medium mb-4 block">HARDWARE COLOR</Label>
          <div className="grid grid-cols-4 gap-6">
            {HARDWARE_COLOR_OPTIONS.map((option) => {
              const isSelected = hardwareColor === option.id;
              return (
                <div key={option.id} className="flex flex-col items-center">
                  <button
                    onClick={() => onUpdate({ 
                      hardwareColor: option.id,
                      hardware_color: option.id,
                      operatingSystemColor: option.id
                    } as any)}
                    className={`w-full aspect-square rounded-lg transition-all relative flex items-center justify-center ${
                      isSelected
                        ? 'border-2 border-gray-400 bg-gray-600'
                        : 'border border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm'
                    }`}
                    style={{ padding: '2px' }}
                  >
                    <div 
                      className="w-full h-full rounded overflow-hidden border border-gray-200 bg-gray-100" 
                      style={{ width: '95%', height: '95%' }}
                    >
                      {/* TODO: Add image from Supabase storage */}
                    </div>
                  </button>
                  <span className={`text-sm font-semibold block mt-2 ${isSelected ? 'text-gray-900' : 'text-gray-900'}`}>
                    {option.name}
                  </span>
                </div>
              );
            })}
          </div>
        </div>

        {/* Bottom Bar Finish - Cards */}
        <div>
          <Label className="text-sm font-medium mb-4 block">BOTTOM BAR FINISH</Label>
          <div className="grid grid-cols-4 gap-6">
            {BOTTOM_BAR_FINISH_OPTIONS.map((option) => {
              const isSelected = bottomBarFinish === option.id;
              return (
                <div key={option.id} className="flex flex-col items-center">
                  <button
                    onClick={() => {
                      const updates: any = { bottom_bar_finish: option.id };
                      // Keep backward compatibility
                      if (option.id === 'wrapped') {
                        updates.bottom_rail_type = 'wrapped';
                      } else {
                        updates.bottom_rail_type = 'standard';
                      }
                      onUpdate(updates);
                    }}
                    className={`w-full aspect-square rounded-lg transition-all relative flex items-center justify-center ${
                      isSelected
                        ? 'border-2 border-gray-400 bg-gray-600'
                        : 'border border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm'
                    }`}
                    style={{ padding: '2px' }}
                  >
                    <div className="w-full h-full rounded overflow-hidden border border-gray-200 bg-gray-100" style={{ width: '95%', height: '95%' }}>
                    </div>
                  </button>
                  <span className={`text-sm font-semibold block mt-2 ${isSelected ? 'text-gray-900' : 'text-gray-900'}`}>
                    {option.name}
                  </span>
                </div>
              );
            })}
          </div>
        </div>

        {/* Cassette Shape - Cards */}
        <div>
          <Label className="text-sm font-medium mb-4 block">CASSETTE SHAPE</Label>
          <div className="grid grid-cols-4 gap-6">
            {CASSETTE_SHAPE_OPTIONS.map((option) => {
              const isSelected = cassetteShape === option.id;
              return (
                <div key={option.id} className="flex flex-col items-center">
                  <button
                    onClick={() => {
                      const updates: any = { cassette_shape: option.id };
                      // Keep backward compatibility
                      updates.cassette = option.id !== 'none';
                      if (option.id !== 'none') {
                        updates.cassette_type = 'standard';
                      }
                      onUpdate(updates);
                    }}
                    className={`w-full aspect-square rounded-lg transition-all relative flex items-center justify-center ${
                      isSelected
                        ? 'border-2 border-gray-400 bg-gray-600'
                        : 'border border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm'
                    }`}
                    style={{ padding: '2px' }}
                  >
                    <div className="w-full h-full rounded overflow-hidden border border-gray-200 bg-gray-100" style={{ width: '95%', height: '95%' }}>
                    </div>
                  </button>
                  <span className={`text-sm font-semibold block mt-2 ${isSelected ? 'text-gray-900' : 'text-gray-900'}`}>
                    {option.name}
                  </span>
                </div>
              );
            })}
          </div>
        </div>

        {/* Side Channel - STEP 1: Enable/Disable (Checkbox) */}
        <div>
          <div className="flex items-center gap-3 mb-4">
            <Label htmlFor="side_channel_checkbox" className="text-sm font-medium cursor-pointer">
              SIDE CHANNEL
              {sideChannel && !sideChannelType && (
                <span className="text-red-500 ml-1">* Required</span>
              )}
            </Label>
            <input
              type="checkbox"
              id="side_channel_checkbox"
              checked={sideChannel}
              onChange={(e) => {
                const checked = e.target.checked; // Always boolean from checkbox
                onUpdate({
                  side_channel: checked, // Explicitly boolean, never string
                  side_channel_type: checked ? (sideChannelType || 'side_only') : null
                } as any);
              }}
              className="w-5 h-5 text-gray-600 border-gray-300 rounded focus:ring-gray-500"
            />
          </div>
          {sideChannelError && (
            <p className="text-xs text-red-500 mt-1">
              Side Channel Type is required when Side Channel is enabled.
            </p>
          )}
        </div>

        {/* Side Channel Type - STEP 2: Type (only shown if Side Channel = YES) */}
        {sideChannel && (
          <div>
            <Label className="text-sm font-medium mb-4 block">
              SIDE CHANNEL TYPE
              {!sideChannelType && (
                <span className="text-red-500 ml-1">* Required</span>
              )}
            </Label>
            <div className="grid grid-cols-4 gap-6">
              {SIDE_CHANNEL_TYPE_OPTIONS.map((option) => {
                const isSelected = sideChannelType === option.id;
                return (
                  <div key={option.id} className="flex flex-col items-center">
                    <button
                      onClick={() => {
                        onUpdate({ 
                          side_channel_type: option.id,
                          side_channel: true // Keep enabled
                        });
                      }}
                      className={`w-full aspect-square rounded-lg transition-all relative flex items-center justify-center ${
                        isSelected
                          ? 'border-2 border-gray-400 bg-gray-600'
                          : 'border border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm'
                      }`}
                      style={{ padding: '2px' }}
                    >
                      <div className="w-full h-full rounded overflow-hidden border border-gray-200 bg-gray-100" style={{ width: '95%', height: '95%' }}>
                      </div>
                    </button>
                    <span className={`text-sm font-semibold block mt-2 text-center ${isSelected ? 'text-gray-900' : 'text-gray-900'}`}>
                      {option.name}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

