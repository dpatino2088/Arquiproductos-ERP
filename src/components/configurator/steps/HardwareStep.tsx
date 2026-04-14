/**
 * Hardware Step
 * 
 * Step 3: Configure hardware options
 * - Headbox type (none/cassette) - affects fingerprint
 * - System size (s/m/l/xl) - affects fingerprint, but forced to 'm' if cassette
 * - Color - affects fingerprint
 * - Bottom bar selection (cards)
 * - Bottom bar wrapped (checkbox)
 * - Side channel mode (none/side_only/side_plus_bottom) - affects fingerprint
 * - Side channel item selection (cards)
 * - Bottom channel item selection (cards, only if side_plus_bottom)
 * - Headbox item selection (cards, only if cassette)
 */

import { useEffect } from 'react';
import { RollerBOMConfigState } from '../../../lib/bom/types';
import { useRollerCatalogItems } from '../../../hooks/useRollerCatalogItems';
import Label from '../../ui/Label';
import CatalogItemImage from '../../ui/CatalogItemImage';

interface HardwareStepProps {
  config: RollerBOMConfigState;
  onUpdate: (updates: Partial<RollerBOMConfigState>) => void;
  organizationId: string | null;
}

export default function HardwareStep({ config, onUpdate, organizationId }: HardwareStepProps) {
  // Fetch catalog items using custom hook
  const { items: headboxOptions, loading: loadingHeadbox } = useRollerCatalogItems({
    organizationId,
    role: 'headbox',
    color: config.color,
    enabled: config.headbox_type === 'cassette',
  });
  
  const { items: bottomBarOptions, loading: loadingBottomBar } = useRollerCatalogItems({
    organizationId,
    role: 'bottom_bar',
    color: config.color,
  });
  
  const { items: sideChannelOptions, loading: loadingSideChannel } = useRollerCatalogItems({
    organizationId,
    role: 'side_channel',
    color: config.color,
    enabled: config.side_channel_mode !== 'none',
  });
  
  const { items: bottomChannelOptions, loading: loadingBottomChannel } = useRollerCatalogItems({
    organizationId,
    role: 'bottom_channel',
    color: config.color,
    enabled: config.side_channel_mode === 'side_plus_bottom',
  });
  
  const loading = loadingHeadbox || loadingBottomBar || loadingSideChannel || loadingBottomChannel;

  // System size options
  const systemSizeOptions: Array<{ value: 's' | 'm' | 'l' | 'xl'; label: string }> = [
    { value: 's', label: 'Small (S)' },
    { value: 'm', label: 'Medium (M)' },
    { value: 'l', label: 'Large (L)' },
    { value: 'xl', label: 'Extra Large (XL)' },
  ];

  // Color options
  const colorOptions = ['white', 'black', 'silver', 'bronze', 'grey'];

  // Headbox type options
  const headboxTypeOptions: Array<{ value: 'none' | 'cassette'; label: string }> = [
    { value: 'none', label: 'None' },
    { value: 'cassette', label: 'Cassette' },
  ];

  // Side channel mode options
  const sideChannelModeOptions: Array<{ value: 'none' | 'side_only' | 'side_plus_bottom'; label: string }> = [
    { value: 'none', label: 'None' },
    { value: 'side_only', label: 'Side Channel Only' },
    { value: 'side_plus_bottom', label: 'Side + Bottom Channel' },
  ];


  // Enforce rule: If cassette, system_size must be 'm'
  useEffect(() => {
    if (config.headbox_type === 'cassette' && config.system_size !== 'm') {
      onUpdate({ system_size: 'm' });
    }
  }, [config.headbox_type, config.system_size, onUpdate]);

  // Enforce rule: If side_plus_bottom, ensure side_channel_item_id is set
  useEffect(() => {
    if (config.side_channel_mode === 'side_plus_bottom' && config.bottom_channel_item_id && !config.side_channel_item_id) {
      // This will be handled by user selection, but we can show a warning
    }
  }, [config.side_channel_mode, config.bottom_channel_item_id, config.side_channel_item_id]);

  const handleHeadboxTypeChange = (value: 'none' | 'cassette') => {
    const updates: Partial<RollerBOMConfigState> = { headbox_type: value };
    
    if (value === 'cassette') {
      updates.system_size = 'm'; // Force system_size to 'm' for cassette
    }
    
    if (value === 'none') {
      updates.headbox_item_id = null; // Clear headbox selection
    }
    
    onUpdate(updates);
  };

  const handleSideChannelModeChange = (value: 'none' | 'side_only' | 'side_plus_bottom') => {
    const updates: Partial<RollerBOMConfigState> = { side_channel_mode: value };
    
    if (value === 'none') {
      updates.side_channel_item_id = null;
      updates.bottom_channel_item_id = null;
    } else if (value === 'side_only') {
      updates.bottom_channel_item_id = null;
    }
    // If side_plus_bottom, keep both selections
    
    onUpdate(updates);
  };

  return (
    <div className="space-y-8">
      <div>
        <h3 className="text-lg font-semibold text-gray-900 mb-2">Hardware Configuration</h3>
        <p className="text-sm text-gray-600">
          Configure hardware options that affect the BOM template selection.
        </p>
      </div>

      {/* Headbox Type */}
      <div>
        <Label>Headbox Type</Label>
        <div className="grid grid-cols-2 gap-4 mt-2">
          {headboxTypeOptions.map((option) => (
            <button
              key={option.value}
              onClick={() => handleHeadboxTypeChange(option.value)}
              className={`p-4 border rounded-lg text-center transition-all ${
                config.headbox_type === option.value
                  ? 'border-2 border-primary shadow-lg bg-primary/5'
                  : 'border-gray-200 hover:shadow-md hover:border-gray-300'
              }`}
            >
              {option.label}
            </button>
          ))}
        </div>
      </div>

      {/* Headbox Item Selection (only if cassette) */}
      {config.headbox_type === 'cassette' && (
        <div>
          <Label>Headbox Item</Label>
          {loading ? (
            <div className="text-sm text-gray-500 mt-2">Loading options...</div>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mt-2">
              {headboxOptions.map((item) => (
                <button
                  key={item.id}
                  onClick={() => onUpdate({ headbox_item_id: item.id })}
                  className={`bg-white border rounded-lg overflow-hidden transition-all ${
                    config.headbox_item_id === item.id
                      ? 'border-2 border-primary shadow-lg'
                      : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                  }`}
                >
                  <div className="p-4 flex flex-col items-center justify-center min-h-[100px]">
                    <CatalogItemImage src={item.image_url} alt={item.name} size="md" objectFit="contain" className="mb-2" />
                    <div className="text-center">
                      <div className="text-sm font-medium text-gray-900">{item.name}</div>
                      <div className="text-xs text-gray-500 mt-1">{item.sku}</div>
                    </div>
                  </div>
                </button>
              ))}
            </div>
          )}
          {headboxOptions.length === 0 && !loading && (
            <div className="text-sm text-gray-500 mt-2">No headbox items found for color "{config.color}"</div>
          )}
        </div>
      )}

      {/* System Size */}
      <div>
        <Label>System Size</Label>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-2">
          {systemSizeOptions.map((option) => {
            const isDisabled = config.headbox_type === 'cassette' && option.value !== 'm';
            
            return (
              <button
                key={option.value}
                onClick={() => !isDisabled && onUpdate({ system_size: option.value })}
                disabled={isDisabled}
                className={`p-4 border rounded-lg text-center transition-all ${
                  config.system_size === option.value
                    ? 'border-2 border-primary shadow-lg bg-primary/5'
                    : isDisabled
                    ? 'border-gray-100 bg-gray-50 text-gray-400 cursor-not-allowed'
                    : 'border-gray-200 hover:shadow-md hover:border-gray-300'
                }`}
              >
                {option.label}
                {isDisabled && <div className="text-xs text-gray-400 mt-1">(Not available with cassette)</div>}
              </button>
            );
          })}
        </div>
      </div>

      {/* Color */}
      <div>
        <Label>Hardware Color</Label>
        <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mt-2">
          {colorOptions.map((color) => (
            <button
              key={color}
              onClick={() => onUpdate({ color })}
              className={`p-4 border rounded-lg text-center capitalize transition-all ${
                config.color === color
                  ? 'border-2 border-primary shadow-lg bg-primary/5'
                  : 'border-gray-200 hover:shadow-md hover:border-gray-300'
              }`}
            >
              {color}
            </button>
          ))}
        </div>
      </div>

      {/* Bottom Bar Selection */}
      <div>
        <Label>Bottom Bar</Label>
        {loading ? (
          <div className="text-sm text-gray-500 mt-2">Loading options...</div>
        ) : (
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mt-2">
            {bottomBarOptions.map((item) => (
              <button
                key={item.id}
                onClick={() => onUpdate({ bottom_bar_item_id: item.id })}
                className={`bg-white border rounded-lg overflow-hidden transition-all ${
                  config.bottom_bar_item_id === item.id
                    ? 'border-2 border-primary shadow-lg'
                    : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                }`}
              >
                <div className="p-4 flex flex-col items-center justify-center min-h-[100px]">
                  <CatalogItemImage src={item.image_url} alt={item.name} size="md" objectFit="contain" className="mb-2" />
                  <div className="text-center">
                    <div className="text-sm font-medium text-gray-900">{item.name}</div>
                    <div className="text-xs text-gray-500 mt-1">{item.sku}</div>
                  </div>
                </div>
              </button>
            ))}
          </div>
        )}
        {bottomBarOptions.length === 0 && !loading && (
          <div className="text-sm text-gray-500 mt-2">No bottom bar items found for color "{config.color}"</div>
        )}
      </div>

      {/* Bottom Bar Wrapped */}
      <div>
        <label className="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            checked={config.bottom_bar_wrapped}
            onChange={(e) => onUpdate({ bottom_bar_wrapped: e.target.checked })}
            className="w-4 h-4 text-primary border-gray-300 rounded focus:ring-primary"
          />
          <span className="text-sm font-medium text-gray-900">Bottom Bar Wrapped</span>
        </label>
        <p className="text-xs text-gray-500 mt-1 ml-6">
          Adds wrapping cost (stored in metadata, not in SKU selection)
        </p>
      </div>

      {/* Side Channel Mode */}
      <div>
        <Label>Side Channel Configuration</Label>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mt-2">
          {sideChannelModeOptions.map((option) => (
            <button
              key={option.value}
              onClick={() => handleSideChannelModeChange(option.value)}
              className={`p-4 border rounded-lg text-center transition-all ${
                config.side_channel_mode === option.value
                  ? 'border-2 border-primary shadow-lg bg-primary/5'
                  : 'border-gray-200 hover:shadow-md hover:border-gray-300'
              }`}
            >
              {option.label}
            </button>
          ))}
        </div>
      </div>

      {/* Side Channel Item Selection (if not none) */}
      {config.side_channel_mode !== 'none' && (
        <div>
          <Label>Side Channel Item</Label>
          {loading ? (
            <div className="text-sm text-gray-500 mt-2">Loading options...</div>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mt-2">
              {sideChannelOptions.map((item) => (
                <button
                  key={item.id}
                  onClick={() => onUpdate({ side_channel_item_id: item.id })}
                  className={`bg-white border rounded-lg overflow-hidden transition-all ${
                    config.side_channel_item_id === item.id
                      ? 'border-2 border-primary shadow-lg'
                      : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                  }`}
                >
                  <div className="p-4 flex flex-col items-center justify-center min-h-[100px]">
                    <CatalogItemImage src={item.image_url} alt={item.name} size="md" objectFit="contain" className="mb-2" />
                    <div className="text-center">
                      <div className="text-sm font-medium text-gray-900">{item.name}</div>
                      <div className="text-xs text-gray-500 mt-1">{item.sku}</div>
                    </div>
                  </div>
                </button>
              ))}
            </div>
          )}
          {sideChannelOptions.length === 0 && !loading && (
            <div className="text-sm text-gray-500 mt-2">No side channel items found for color "{config.color}"</div>
          )}
        </div>
      )}

      {/* Bottom Channel Item Selection (only if side_plus_bottom) */}
      {config.side_channel_mode === 'side_plus_bottom' && (
        <div>
          <Label>Bottom Channel Item</Label>
          {loading ? (
            <div className="text-sm text-gray-500 mt-2">Loading options...</div>
          ) : (
            <>
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mt-2">
                {bottomChannelOptions.map((item) => (
                  <button
                    key={item.id}
                    onClick={() => {
                      // Ensure side_channel_item_id is set if not already
                      const updates: Partial<RollerBOMConfigState> = { bottom_channel_item_id: item.id };
                      if (!config.side_channel_item_id && sideChannelOptions.length > 0) {
                        updates.side_channel_item_id = sideChannelOptions[0].id;
                      }
                      onUpdate(updates);
                    }}
                    className={`bg-white border rounded-lg overflow-hidden transition-all ${
                      config.bottom_channel_item_id === item.id
                        ? 'border-2 border-primary shadow-lg'
                        : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                    }`}
                  >
                    <div className="p-4 flex flex-col items-center justify-center min-h-[100px]">
                      <CatalogItemImage src={item.image_url} alt={item.name} size="md" objectFit="contain" className="mb-2" />
                      <div className="text-center">
                        <div className="text-sm font-medium text-gray-900">{item.name}</div>
                        <div className="text-xs text-gray-500 mt-1">{item.sku}</div>
                      </div>
                    </div>
                  </button>
                ))}
              </div>
              {bottomChannelOptions.length === 0 && !loading && (
                <div className="text-sm text-gray-500 mt-2">No bottom channel items found for color "{config.color}"</div>
              )}
            </>
          )}
        </div>
      )}
    </div>
  );
}
