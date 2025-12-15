import { CurtainConfiguration } from '../CurtainConfigurator';
import Label from '../../../components/ui/Label';

interface ReviewStepProps {
  config: CurtainConfiguration;
  onUpdate: (updates: Partial<CurtainConfiguration>) => void;
}

export default function ReviewStep({ config, onUpdate }: ReviewStepProps) {
  const calculateTotal = () => {
    // This is a placeholder - actual calculation should be done server-side
    // based on catalog items and pricing
    let total = 0;
    
    // Add accessories total
    if (config.accessories) {
      total += config.accessories.reduce((sum, acc) => sum + (acc.price * acc.qty), 0);
    }
    
    // Base price calculation would go here
    // For now, return a placeholder
    return total;
  };

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        <div>
          <Label className="text-lg font-semibold mb-4 block">PRODUCT SPECIFICATIONS</Label>
          
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <span className="font-medium text-gray-700">Position:</span>
                <span className="ml-2 text-gray-900">{config.position}</span>
              </div>
              <div>
                <span className="font-medium text-gray-700">Product Type:</span>
                <span className="ml-2 text-gray-900">{config.productType || 'Not selected'}</span>
              </div>
              <div>
                <span className="font-medium text-gray-700">Mounting:</span>
                <span className="ml-2 text-gray-900">{config.mountingCassette || 'Not selected'}</span>
              </div>
              <div>
                <span className="font-medium text-gray-700">Dimensions:</span>
                <span className="ml-2 text-gray-900">
                  {config.width_mm && config.height_mm 
                    ? `${config.width_mm} x ${config.height_mm} mm`
                    : 'Not set'}
                </span>
              </div>
              <div>
                <span className="font-medium text-gray-700">Film Type:</span>
                <span className="ml-2 text-gray-900">{config.filmType || 'Not selected'}</span>
              </div>
              <div>
                <span className="font-medium text-gray-700">Guiding:</span>
                <span className="ml-2 text-gray-900">{config.guidingProfile || 'Not selected'}</span>
              </div>
              <div>
                <span className="font-medium text-gray-700">Fixing:</span>
                <span className="ml-2 text-gray-900">{config.fixingType || 'Not selected'}</span>
              </div>
              <div>
                <span className="font-medium text-gray-700">Accessories:</span>
                <span className="ml-2 text-gray-900">
                  {config.accessories?.length || 0} items
                </span>
              </div>
            </div>
          </div>
        </div>

        <div className="border-t border-gray-200 pt-4">
          <div className="flex justify-between items-center">
            <span className="text-lg font-semibold text-gray-900">Estimated Total:</span>
            <span className="text-2xl font-bold text-primary">
              €{calculateTotal().toFixed(2)}
            </span>
          </div>
          <p className="text-xs text-gray-500 mt-2">
            Final pricing will be calculated when added to quote
          </p>
        </div>
      </div>
    </div>
  );
}



