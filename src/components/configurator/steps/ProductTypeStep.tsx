/**
 * Product Type Step
 * 
 * Step 1: Select product type (always 'roller' for this configurator)
 */

import { ProductType } from '../../../hooks/useProductTypes';
import { RollerBOMConfigState } from '../../../lib/bom/types';
import { Image as ImageIcon } from 'lucide-react';

interface ProductTypeStepProps {
  config: RollerBOMConfigState;
  onUpdate: (updates: Partial<RollerBOMConfigState>) => void;
  productTypes: ProductType[];
  loading: boolean;
}

export default function ProductTypeStep({
  config,
  onUpdate,
  productTypes,
  loading,
}: ProductTypeStepProps) {
  // Filter for roller product types
  const rollerTypes = productTypes.filter(
    pt => pt.code === 'roller_shade' || pt.code === 'roller' || pt.name.toLowerCase().includes('roller')
  );

  const handleSelect = (productType: ProductType) => {
    onUpdate({
      product_type_id: productType.id,
      product_type_code: 'roller',
    });
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="text-gray-500">Loading product types...</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold text-gray-900 mb-2">Select Product Type</h3>
        <p className="text-sm text-gray-600">Choose the product type for your configuration</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
        {rollerTypes.map((productType) => {
          const isSelected = config.product_type_id === productType.id;
          
          return (
            <button
              key={productType.id}
              onClick={() => handleSelect(productType)}
              className={`bg-white border rounded-lg overflow-hidden transition-all ${
                isSelected
                  ? 'border-2 border-primary shadow-lg'
                  : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
              }`}
            >
              <div className="p-6 flex flex-col items-center justify-center min-h-[120px]">
                <ImageIcon className="w-12 h-12 text-gray-400 mb-2" />
                <div className="text-center font-medium text-gray-900">
                  {productType.name}
                </div>
              </div>
            </button>
          );
        })}
      </div>

      {rollerTypes.length === 0 && (
        <div className="text-center py-12 text-gray-500">
          No roller product types found. Please create a product type with code 'roller_shade' or 'roller'.
        </div>
      )}
    </div>
  );
}
