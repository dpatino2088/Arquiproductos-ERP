/**
 * Operating System Step
 * 
 * Step 4: Configure operating system
 * - Operating system (manual/motor) - affects fingerprint
 * - Motor item selection (cards, only if motor)
 * - Manual drive item selection (cards, only if manual)
 * - Optional: Tube item selection (cards)
 */

import { RollerBOMConfigState } from '../../../lib/bom/types';
import { useRollerCatalogItems } from '../../../hooks/useRollerCatalogItems';
import Label from '../../ui/Label';
import CatalogItemImage from '../../ui/CatalogItemImage';

interface OperatingSystemStepProps {
  config: RollerBOMConfigState;
  onUpdate: (updates: Partial<RollerBOMConfigState>) => void;
  organizationId: string | null;
}

export default function OperatingSystemStep({
  config,
  onUpdate,
  organizationId,
}: OperatingSystemStepProps) {
  // Fetch catalog items using custom hook
  const { items: motorOptions, loading: loadingMotor } = useRollerCatalogItems({
    organizationId,
    role: 'motor',
    color: config.color,
    enabled: config.operating_system === 'motor',
  });
  
  const { items: driveOptions, loading: loadingDrive } = useRollerCatalogItems({
    organizationId,
    role: 'drive',
    color: config.color,
    enabled: config.operating_system === 'manual',
  });
  
  const { items: tubeOptions, loading: loadingTube } = useRollerCatalogItems({
    organizationId,
    role: 'tube',
    color: config.color,
  });
  
  const loading = loadingMotor || loadingDrive || loadingTube;

  // Operating system options
  const operatingSystemOptions: Array<{ value: 'manual' | 'motor'; label: string }> = [
    { value: 'manual', label: 'Manual' },
    { value: 'motor', label: 'Motor' },
  ];

  const handleOperatingSystemChange = (value: 'manual' | 'motor') => {
    const updates: Partial<RollerBOMConfigState> = { operating_system: value };
    
    // Clear selections when switching
    if (value === 'motor') {
      updates.drive_item_id = null;
    } else {
      updates.motor_item_id = null;
    }
    
    onUpdate(updates);
  };

  return (
    <div className="space-y-8">
      <div>
        <h3 className="text-lg font-semibold text-gray-900 mb-2">Operating System</h3>
        <p className="text-sm text-gray-600">
          Select the operating system type and choose the specific components.
        </p>
      </div>

      {/* Operating System Type */}
      <div>
        <Label>Operating System Type</Label>
        <div className="grid grid-cols-2 gap-4 mt-2">
          {operatingSystemOptions.map((option) => (
            <button
              key={option.value}
              onClick={() => handleOperatingSystemChange(option.value)}
              className={`p-4 border rounded-lg text-center transition-all ${
                config.operating_system === option.value
                  ? 'border-2 border-primary shadow-lg bg-primary/5'
                  : 'border-gray-200 hover:shadow-md hover:border-gray-300'
              }`}
            >
              {option.label}
            </button>
          ))}
        </div>
      </div>

      {/* Motor Selection (only if motor) */}
      {config.operating_system === 'motor' && (
        <div>
          <Label>Motor</Label>
          {loading ? (
            <div className="text-sm text-gray-500 mt-2">Loading options...</div>
          ) : (
            <>
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mt-2">
                {motorOptions.map((item) => (
                  <button
                    key={item.id}
                    onClick={() => onUpdate({ motor_item_id: item.id })}
                    className={`bg-white border rounded-lg overflow-hidden transition-all ${
                      config.motor_item_id === item.id
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
              {motorOptions.length === 0 && !loading && (
                <div className="text-sm text-gray-500 mt-2">No motor items found for color "{config.color}"</div>
              )}
            </>
          )}
        </div>
      )}

      {/* Manual Drive Selection (only if manual) */}
      {config.operating_system === 'manual' && (
        <div>
          <Label>Manual Drive / Mechanism</Label>
          {loading ? (
            <div className="text-sm text-gray-500 mt-2">Loading options...</div>
          ) : (
            <>
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mt-2">
                {driveOptions.map((item) => (
                  <button
                    key={item.id}
                    onClick={() => onUpdate({ drive_item_id: item.id })}
                    className={`bg-white border rounded-lg overflow-hidden transition-all ${
                      config.drive_item_id === item.id
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
              {driveOptions.length === 0 && !loading && (
                <div className="text-sm text-gray-500 mt-2">No manual drive items found for color "{config.color}"</div>
              )}
            </>
          )}
        </div>
      )}

      {/* Optional: Tube Selection */}
      <div>
        <Label>Tube (Optional)</Label>
        <p className="text-xs text-gray-500 mb-2">
          Optional: Select a specific tube. If not selected, the template will use its default.
        </p>
        {loading ? (
          <div className="text-sm text-gray-500 mt-2">Loading options...</div>
        ) : (
          <>
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mt-2">
              <button
                onClick={() => onUpdate({ tube_item_id: null })}
                className={`p-4 border rounded-lg text-center transition-all ${
                  config.tube_item_id === null
                    ? 'border-2 border-primary shadow-lg bg-primary/5'
                    : 'border-gray-200 hover:shadow-md hover:border-gray-300'
                }`}
              >
                Use Template Default
              </button>
              {tubeOptions.map((item) => (
                <button
                  key={item.id}
                  onClick={() => onUpdate({ tube_item_id: item.id })}
                  className={`bg-white border rounded-lg overflow-hidden transition-all ${
                    config.tube_item_id === item.id
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
            {tubeOptions.length === 0 && !loading && (
              <div className="text-sm text-gray-500 mt-2">No tube items found for color "{config.color}"</div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
