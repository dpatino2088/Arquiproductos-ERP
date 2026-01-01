import { useState, useEffect } from 'react';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import { supabase } from '../../../lib/supabase/client';
import { useOrganizationContext } from '../../../context/OrganizationContext';

interface ReviewStepProps {
  config: ProductConfig;
  onUpdate: (updates: Partial<ProductConfig>) => void;
  quoteId?: string; // Optional quote ID (kept for compatibility)
}

export default function ReviewStep({ config, onUpdate }: ReviewStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const [fabricData, setFabricData] = useState<{
    sku?: string;
    collection_name?: string;
    variant_name?: string;
  } | null>(null);
  const [loadingFabric, setLoadingFabric] = useState(false);

  // Get variant ID from config (supports different product types)
  const getVariantId = () => {
    if ('variantId' in config && config.variantId) {
      return config.variantId;
    }
    if ('fabric' in config && config.fabric?.variantId) {
      return config.fabric.variantId;
    }
    if ('frontFabric' in config && config.frontFabric?.variantId) {
      return config.frontFabric.variantId;
    }
    return null;
  };

  // Load fabric data from CatalogItems
  useEffect(() => {
    const loadFabricData = async () => {
      const variantId = getVariantId();
      if (!variantId || !activeOrganizationId) {
        setFabricData(null);
        return;
      }

      try {
        setLoadingFabric(true);
        const { data: catalogItem, error } = await supabase
          .from('CatalogItems')
          .select('sku, collection_name, variant_name')
          .eq('id', variantId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .maybeSingle();

        if (error) {
          console.error('Error loading fabric data:', error);
          setFabricData(null);
          return;
        }

        if (catalogItem) {
          setFabricData({
            sku: catalogItem.sku || undefined,
            collection_name: catalogItem.collection_name || undefined,
            variant_name: catalogItem.variant_name || undefined,
          });
        } else {
          setFabricData(null);
        }
      } catch (err) {
        console.error('Error loading fabric data:', err);
        setFabricData(null);
      } finally {
        setLoadingFabric(false);
      }
    };

    loadFabricData();
  }, [config, activeOrganizationId]);

  // Get dimensions display
  const getDimensionsDisplay = () => {
    const width_mm = (config as any).width_mm;
    const height_mm = (config as any).height_mm;
    if (width_mm && height_mm) {
      return `${width_mm.toFixed(0)} x ${height_mm.toFixed(0)} mm`;
    }
    return 'Not set';
  };

  const dimensionsDisplay = getDimensionsDisplay();
  const hasFabricData = fabricData && (fabricData.sku || fabricData.collection_name || fabricData.variant_name);

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        <div>
          <Label className="text-lg font-semibold mb-4 block">CONFIGURED PRODUCT</Label>
          
          <div className="space-y-4">
            {/* Fabric Technical Data Section */}
            {hasFabricData && (
              <div className="mb-4 pb-4 border-b border-gray-200">
                <h3 className="text-sm font-semibold text-gray-700 mb-3">FABRIC TECHNICAL DATA</h3>
                <div className="grid grid-cols-2 gap-4 text-sm">
                  {fabricData.sku && (
                    <div>
                      <span className="font-medium text-gray-700">SKU:</span>
                      <span className="ml-2 text-gray-900">{fabricData.sku}</span>
                    </div>
                  )}
                  {fabricData.collection_name && (
                    <div>
                      <span className="font-medium text-gray-700">Collection:</span>
                      <span className="ml-2 text-gray-900">{fabricData.collection_name}</span>
                    </div>
                  )}
                  {fabricData.variant_name && (
                    <div>
                      <span className="font-medium text-gray-700">Variant:</span>
                      <span className="ml-2 text-gray-900">{fabricData.variant_name}</span>
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Product Specifications Section */}
            <div>
              <h3 className="text-sm font-semibold text-gray-700 mb-3">PRODUCT SPECIFICATIONS</h3>
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="font-medium text-gray-700">Position:</span>
                  <span className="ml-2 text-gray-900">{config.position || 'Not selected'}</span>
                </div>
                <div>
                  <span className="font-medium text-gray-700">Product Type:</span>
                  <span className="ml-2 text-gray-900">{config.productType || 'Not selected'}</span>
                </div>
                <div>
                  <span className="font-medium text-gray-700">Mounting:</span>
                  <span className="ml-2 text-gray-900">{(config as any).mountingCassette || (config as any).mountingType || 'Not selected'}</span>
                </div>
                <div>
                  <span className="font-medium text-gray-700">Dimensions:</span>
                  <span className="ml-2 text-gray-900">{dimensionsDisplay}</span>
                </div>
                <div>
                  <span className="font-medium text-gray-700">Film Type:</span>
                  <span className="ml-2 text-gray-900">{(config as any).filmType || 'Not selected'}</span>
                </div>
                <div>
                  <span className="font-medium text-gray-700">Guiding:</span>
                  <span className="ml-2 text-gray-900">{(config as any).guidingProfile || 'Not selected'}</span>
                </div>
                <div>
                  <span className="font-medium text-gray-700">Fixing:</span>
                  <span className="ml-2 text-gray-900">{(config as any).fixingType || 'Not selected'}</span>
                </div>
                <div>
                  <span className="font-medium text-gray-700">Accessories:</span>
                  <span className="ml-2 text-gray-900">
                    {config.accessories?.length || 0} items
                  </span>
                </div>
                {(config as any).drive_type || (config as any).operatingSystem ? (
                  <div>
                    <span className="font-medium text-gray-700">Drive Type:</span>
                    <span className="ml-2 text-gray-900">{(config as any).drive_type || (config as any).operatingSystem || 'Not selected'}</span>
                  </div>
                ) : null}
                {(config as any).hardware_color || (config as any).hardwareColor ? (
                  <div>
                    <span className="font-medium text-gray-700">Hardware Color:</span>
                    <span className="ml-2 text-gray-900">{(config as any).hardware_color || (config as any).hardwareColor || 'Not selected'}</span>
                  </div>
                ) : null}
                {(config as any).bottom_rail_type ? (
                  <div>
                    <span className="font-medium text-gray-700">Bottom Rail Type:</span>
                    <span className="ml-2 text-gray-900">{(config as any).bottom_rail_type || 'Not selected'}</span>
                  </div>
                ) : null}
                {(config as any).cassette !== undefined ? (
                  <div>
                    <span className="font-medium text-gray-700">Cassette:</span>
                    <span className="ml-2 text-gray-900">{(config as any).cassette ? 'Yes' : 'No'}</span>
                  </div>
                ) : null}
                {(config as any).side_channel !== undefined ? (
                  <div>
                    <span className="font-medium text-gray-700">Side Channel:</span>
                    <span className="ml-2 text-gray-900">{(config as any).side_channel ? 'Yes' : 'No'}</span>
                    {(config as any).side_channel && (config as any).side_channel_type ? (
                      <div className="mt-1">
                        <span className="font-medium text-gray-700">Side Channel Type:</span>
                        <span className="ml-2 text-gray-900">{(config as any).side_channel_type}</span>
                      </div>
                    ) : null}
                  </div>
                ) : null}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
