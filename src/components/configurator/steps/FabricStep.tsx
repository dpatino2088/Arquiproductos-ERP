/**
 * Fabric Step
 * 
 * Step 2.5: Select fabric collection and variant
 * This provides the catalog_item_id for the QuoteLine
 */

import { useState, useRef, useEffect, useMemo } from 'react';
import { RollerBOMConfigState } from '../../../lib/bom/types';
import { useFabricCollections, useFabricVariants } from '../../../hooks/useFabricCatalog';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { useWarehouses } from '../../../hooks/useWarehouses';
import { useInventoryAvailability } from '../../../hooks/useInventoryAvailability';
import { InventoryAvailabilityBadge } from '../../inventory/InventoryAvailabilityBadge';
import Label from '../../ui/Label';
import Input from '../../ui/Input';
import { Image as ImageIcon } from 'lucide-react';

interface FabricStepProps {
  config: RollerBOMConfigState & {
    fabric_catalog_item_id?: string | null;
    collection_name?: string | null;
    collection_id?: string | null;
    variant_id?: string | null;
    variant_name?: string | null;
  };
  onUpdate: (updates: Partial<RollerBOMConfigState>) => void;
}

export default function FabricStep({ config, onUpdate }: FabricStepProps) {
  const [searchTerm, setSearchTerm] = useState('');
  const [showDropdown, setShowDropdown] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Get product type ID from config
  const productTypeId = config.product_type_id ?? undefined;

  // Fetch collections and variants (hooks expect string | undefined, not null)
  const { collections, loading: loadingCollections, error: collectionsError } = useFabricCollections(productTypeId);
  const { variants, loading: loadingVariants, error: variantsError } = useFabricVariants(
    productTypeId,
    config.collection_name ?? ''
  );

  const { activeOrganizationId } = useOrganizationContext();
  const { defaultWarehouse } = useWarehouses(activeOrganizationId);
  const variantCatalogIds = useMemo(() => variants.map((v) => v.id).filter(Boolean), [variants]);
  const { map: availabilityMap } = useInventoryAvailability({
    organizationId: activeOrganizationId ?? null,
    warehouseId: defaultWarehouse?.id ?? null,
    catalogItemIds: variantCatalogIds,
  });

  // collections from useFabricCollections is string[]; map to { id, collection_name } for UI
  const collectionItems = collections.map((name) => ({ id: name, collection_name: name }));
  const filteredCollections = collectionItems.filter((c) =>
    c.collection_name?.toLowerCase().includes(searchTerm.toLowerCase()) ?? false
  );

  // Handle collection change
  const handleCollectionChange = (collection: { collection_name: string; id: string }) => {
    onUpdate({
      collection_name: collection.collection_name,
      collection_id: collection.id,
      variant_id: undefined,
      fabric_catalog_item_id: null,
      fabric_item_id: null,
    } as any);
    setSearchTerm(collection.collection_name);
    setShowDropdown(false);
  };

  // Handle variant selection
  const handleVariantSelect = (variant: any) => {
    onUpdate({
      variant_id: variant.id,
      variant_name: variant.variant_name,
      fabric_catalog_item_id: variant.id,
      fabric_item_id: variant.id,
    } as any);
  };

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setShowDropdown(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold text-gray-900 mb-2">Select Fabric</h3>
        <p className="text-sm text-gray-600">Choose a collection and then select a variant</p>
      </div>

      {/* Collection Search/Dropdown */}
      <div>
        <Label htmlFor="collection-search">Collection</Label>
        <div className="relative" ref={dropdownRef}>
          <Input
            id="collection-search"
            type="text"
            value={searchTerm}
            onChange={(e) => {
              setSearchTerm(e.target.value);
              setShowDropdown(true);
            }}
            onFocus={() => setShowDropdown(true)}
            placeholder="Search collections..."
            className="w-full"
          />
          {showDropdown && filteredCollections.length > 0 && (
            <div className="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg max-h-60 overflow-y-auto">
              {filteredCollections.map((collection) => (
                <button
                  key={collection.id}
                  onClick={() => handleCollectionChange(collection)}
                  className="w-full px-4 py-2 text-left hover:bg-gray-50 transition-colors"
                >
                  {collection.collection_name}
                </button>
              ))}
            </div>
          )}
        </div>
        {loadingCollections && <div className="text-sm text-gray-500 mt-1">Loading collections...</div>}
        {collectionsError && <div className="text-sm text-red-500 mt-1">{collectionsError}</div>}
      </div>

      {/* Variants Grid */}
      {config.collection_name && (
        <div>
          <Label>Variants</Label>
          {loadingVariants ? (
            <div className="text-sm text-gray-500 mt-2">Loading variants...</div>
          ) : variants.length > 0 ? (
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mt-2">
              {(config.variant_id
                ? variants.filter((v) => v.id === config.variant_id)
                : variants
              ).map((variant) => (
                <button
                  key={variant.id}
                  onClick={() => handleVariantSelect(variant)}
                  className={`bg-white border rounded-lg overflow-hidden transition-all ${
                    (config.variant_id ?? undefined) === (variant.id ?? undefined)
                      ? 'border-2 border-primary shadow-lg'
                      : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                  }`}
                >
                  <div className="p-4 flex flex-col items-center justify-center min-h-[120px]">
                    {variant.image_url ? (
                      <img
                        src={variant.image_url}
                        alt={variant.variant_name ?? ''}
                        className="w-16 h-16 object-cover rounded mb-2"
                      />
                    ) : (
                      <ImageIcon className="w-12 h-12 text-gray-400 mb-2" />
                    )}
                    <div className="text-center">
                      <div className="text-sm font-medium text-gray-900">{variant.variant_name}</div>
                      {variant.manufacturer && (
                        <div className="text-xs text-gray-500 mt-1">{variant.manufacturer}</div>
                      )}
                      {defaultWarehouse && (
                        <div className="mt-1.5">
                          <InventoryAvailabilityBadge row={availabilityMap[variant.id]} />
                        </div>
                      )}
                    </div>
                  </div>
                </button>
              ))}
            </div>
          ) : (
            <div className="text-sm text-gray-500 mt-2">
              No variants found for collection "{config.collection_name}"
            </div>
          )}
          {variantsError && <div className="text-sm text-red-500 mt-2">{variantsError}</div>}
        </div>
      )}
    </div>
  );
}
