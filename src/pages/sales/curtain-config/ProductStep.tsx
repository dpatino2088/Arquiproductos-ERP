import { CurtainConfiguration } from '../CurtainConfigurator';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';

interface ProductStepProps {
  config: CurtainConfiguration | ProductConfig;
  onUpdate: (updates: Partial<CurtainConfiguration | ProductConfig>) => void;
}

const PRODUCT_TYPES = [
  { 
    id: 'roller-shade', 
    name: 'Roller Shade',
    maxWidth: 2200,
    maxHeight: 3400,
    variations: 'Manual, Electric',
    additionalInfo: [
      'Equipped with double cleaning brushes',
      'Top model with many extras'
    ]
  },
  { 
    id: 'dual-shade', 
    name: 'Dual Shade',
    maxWidth: 2500,
    maxHeight: 3500,
    variations: 'Manual, Electric',
    additionalInfo: [
      'Dual layer system for enhanced light control',
      'Premium quality materials'
    ]
  },
  { 
    id: 'triple-shade', 
    name: 'Triple Shade',
    maxWidth: 3000,
    maxHeight: 4000,
    variations: 'Manual, Electric',
    additionalInfo: [
      'Three-layer system for maximum flexibility',
      'Advanced motorization options available'
    ]
  },
  { 
    id: 'drapery', 
    name: 'Drapery Wave / Rippel Fold',
    maxWidth: 3500,
    maxHeight: 4500,
    variations: 'Manual, Electric',
    additionalInfo: [
      'Elegant wave fold design',
      'Wide range of fabric options'
    ]
  },
  { 
    id: 'awning', 
    name: 'Awning',
    maxWidth: 4000,
    maxHeight: 5000,
    variations: 'Manual, Electric',
    additionalInfo: [
      'Outdoor protection solution',
      'Weather resistant materials'
    ]
  },
  { 
    id: 'window-film', 
    name: 'Window Films',
    maxWidth: 2000,
    maxHeight: 3000,
    variations: 'Static, Adhesive',
    additionalInfo: [
      'UV protection and privacy',
      'Easy installation'
    ]
  },
  { 
    id: 'accessories', 
    name: 'Accessories',
    maxWidth: 0,
    maxHeight: 0,
    variations: 'Individual Items',
    additionalInfo: [
      'Controls, clutches, supports, and other accessories',
      'Items sold separately from main products'
    ],
    isAccessoriesOnly: true
  },
];

export default function ProductStep({ config, onUpdate }: ProductStepProps) {
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        {/* Product Type */}
        <div className="relative">
          <Label className="text-sm font-medium mb-4 block">PRODUCT TYPE</Label>
          <div className="grid grid-cols-3 gap-4">
            {PRODUCT_TYPES.map((product) => {
              const isSelected = config.productType === product.id;
              return (
                <div key={product.id} className="relative">
                  {/* Product Card */}
                  <button
                    type="button"
                    onClick={() => {
                      // Toggle selection: if selected, deselect; if not selected, select
                      if (isSelected) {
                        // Clicking selected product closes overlay by deselecting
                        onUpdate({ productType: undefined });
                      } else {
                        // Select new product
                        onUpdate({ productType: product.id });
                      }
                    }}
                    className={`w-full p-[5px] border-2 rounded-lg text-left transition-all ${
                      isSelected
                        ? 'border-gray-400 bg-gray-600 text-white'
                        : 'border border-gray-200 bg-gray-100 hover:border-gray-300 hover:shadow-sm'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <span className={`text-sm font-semibold ${isSelected ? 'text-white' : 'text-gray-900'}`}>
                        {product.name}
                      </span>
                      {isSelected ? (
                        <div className="w-5 h-5 bg-green-600 rounded-full flex items-center justify-center ml-3 flex-shrink-0">
                          <span className="text-white text-xs font-bold">✓</span>
                        </div>
                      ) : (
                        <div className="w-5 h-5 rounded-full border-2 border-gray-400 bg-white ml-3 flex-shrink-0"></div>
                      )}
                    </div>
                  </button>
                </div>
              );
            })}
          </div>

          {/* Expandable Details Panel - Overlay above the grid, same size as selected card */}
          {config.productType && (() => {
            const selectedProduct = PRODUCT_TYPES.find(p => p.id === config.productType);
            if (!selectedProduct) return null;

            // Find the selected product's position in the grid
            const selectedIndex = PRODUCT_TYPES.findIndex(p => p.id === config.productType);
            const row = Math.floor(selectedIndex / 3);
            const col = selectedIndex % 3;

            // Calculate position to match the grid card exactly
            // Grid uses: grid-cols-3 gap-4
            // Each card width: calc((100% - 2 * 16px) / 3) = calc(33.333% - 10.67px)
            const gap = 16; // gap-4 = 16px
            const cardWidth = 'calc(33.333% - 10.67px)';
            
            // Calculate left offset to align with card's left edge
            // Grid calculates: each column = (100% - 2*gap) / 3, then adds gaps
            // Col 0: 0
            // Col 1: (100% - 32px) / 3 + 16px = 33.333% - 10.67px + 16px = 33.333% + 5.33px
            // Col 2: 2 * (100% - 32px) / 3 + 32px = 66.666% - 21.33px + 32px = 66.666% + 10.67px
            const leftOffset = col === 0 
              ? '0' 
              : col === 1
              ? 'calc(33.333% + 5.33px)'
              : 'calc(66.666% + 10.67px)';
            
            // Card height: p-[5px] (5px top + 5px bottom) + text content (~20px) = ~30px
            const cardHeight = 30;
            const topOffset = `${56 + row * (cardHeight + gap) + cardHeight}px`; // Label height + rows above + current card height

            return (
              <div 
                className="absolute bg-white border-2 border-gray-300 rounded-lg p-4 shadow-xl z-50"
                style={{
                  top: topOffset,
                  left: leftOffset,
                  width: cardWidth,
                }}
              >
                {/* Details Content */}
                <div className="space-y-3">
                  {/* Max Width x Height */}
                  {!selectedProduct.isAccessoriesOnly && (
                    <>
                  <div>
                    <p className="text-xs text-gray-600 mb-1">Max Width x Height:</p>
                    <p className="text-sm font-bold text-gray-900">
                      {selectedProduct.maxWidth} x {selectedProduct.maxHeight} mm
                    </p>
                  </div>
                  
                  {/* Variations Available */}
                  <div>
                    <p className="text-xs text-gray-600 mb-1">Variations Available:</p>
                    <p className="text-sm font-bold text-gray-900">
                      {selectedProduct.variations}
                    </p>
                  </div>
                    </>
                  )}
                  
                  {selectedProduct.isAccessoriesOnly && (
                    <div>
                      <p className="text-xs text-gray-600 mb-1">Type:</p>
                      <p className="text-sm font-bold text-gray-900">
                        {selectedProduct.variations}
                      </p>
                    </div>
                  )}
                  
                  {/* Divider */}
                  <div className="border-t border-gray-300 pt-3">
                    {/* Additional Information */}
                    <div>
                      <p className="text-xs text-gray-600 mb-2">Additional Information:</p>
                      <ul className="space-y-1">
                        {selectedProduct.additionalInfo.map((info, index) => (
                          <li key={index} className="text-sm font-bold text-gray-900 list-disc list-inside">
                            {info}
                          </li>
                        ))}
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
            );
          })()}
        </div>
      </div>
    </div>
  );
}

