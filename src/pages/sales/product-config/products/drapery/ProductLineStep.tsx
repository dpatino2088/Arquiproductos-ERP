import React, { useEffect, useState } from 'react';
import { Layers } from 'lucide-react';
import { supabase } from '../../../../../lib/supabase/client';
import { useOrganizationContext } from '../../../../../context/OrganizationContext';

interface ProductLineStepProps {
  config: any;
  onUpdate: (updates: Record<string, any>) => void;
}

const DISPLAY_NAMES: Record<string, string> = {
  ripple_fold: 'Ripple Fold',
  wave: 'Wave',
  pinch_pleat: 'Pinch Pleat',
};

export default function ProductLineStep({ config, onUpdate }: ProductLineStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const [productLines, setProductLines] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [imageErrors, setImageErrors] = useState<Record<string, boolean>>({});

  const productTypeId = config.productTypeId;
  const manufacturer = config.manufacturer;
  const selected = config.productLine || null;

  useEffect(() => {
    if (!activeOrganizationId || !productTypeId) {
      setProductLines([]);
      setLoading(false);
      return;
    }

    let cancelled = false;
    setLoading(true);

    let query = supabase
      .from('BOMTemplates')
      .select('product_line')
      .eq('organization_id', activeOrganizationId)
      .eq('product_type_id', productTypeId)
      .eq('is_active', true)
      .eq('deleted', false)
      .not('product_line', 'is', null);

    if (manufacturer) {
      query = query.or(`manufacturer.eq.${manufacturer},manufacturer.is.null`);
    }

    query.then(({ data, error }: { data: unknown; error: { message: string } | null }) => {
      if (cancelled) return;
      if (error) {
        console.warn('ProductLineStep: Error fetching product lines', error.message);
        setProductLines([]);
      } else {
        const rows = Array.isArray(data) ? data : [];
        const unique = (Array.from(
          new Set(rows.map((r: { product_line?: string }) => (r.product_line ?? '')?.trim()).filter(Boolean))
        ).sort() as string[]);
        setProductLines(unique);
        if (unique.length === 1 && !selected) {
          onUpdate({ productLine: unique[0] });
        }
      }
      setLoading(false);
    });

    return () => { cancelled = true; };
  }, [activeOrganizationId, productTypeId, manufacturer]);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-16">
        <div className="animate-spin h-6 w-6 border-2 border-gray-300 border-t-gray-600 rounded-full" />
      </div>
    );
  }

  if (productLines.length === 0) {
    return (
      <div className="space-y-4">
        <h2 className="text-lg font-semibold text-gray-900">Product Line</h2>
        <p className="text-sm text-gray-500">
          No product lines configured for this manufacturer. You can proceed to the next step.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold text-gray-900">Select Product Line</h2>
        <p className="text-sm text-gray-500 mt-1">
          Choose the product line for your drapery system.
        </p>
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
        {productLines.map((line) => {
          const isSelected = selected === line;
          const displayName = DISPLAY_NAMES[line] || line.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
          const hasImageError = imageErrors[line];
          const imagePath = `/images/${displayName}.png`;
          return (
            <div
              key={line}
              onClick={() => onUpdate({ productLine: line, styleCode: undefined })}
              className={`bg-white border rounded-lg overflow-hidden transition-all cursor-pointer ${
                isSelected
                  ? 'border-2 border-gray-900 shadow-lg'
                  : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
              }`}
            >
              <div className="aspect-square bg-white flex items-center justify-center overflow-hidden p-4">
                {!hasImageError ? (
                  <img
                    src={imagePath}
                    alt={displayName}
                    className="max-h-full max-w-full object-contain"
                    onError={() => setImageErrors((prev) => ({ ...prev, [line]: true }))}
                  />
                ) : (
                  <Layers className="w-16 h-16 text-gray-300" />
                )}
              </div>
              <div className="p-4 bg-gray-100">
                <h3 className="font-semibold text-sm truncate text-center text-gray-900">
                  {displayName}
                </h3>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
