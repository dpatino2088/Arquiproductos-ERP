import { useMemo, useEffect, useState } from 'react';
import { ProductConfig, DraperyConfig } from '../../types';
import Label from '../../../../../components/ui/Label';
import { supabase } from '../../../../../lib/supabase/client';
import { useOrganizationContext } from '../../../../../context/OrganizationContext';
import { Image as ImageIcon } from 'lucide-react';

interface DraperyStyleStepProps {
  config: ProductConfig;
  onUpdate: (updates: Partial<ProductConfig>) => void;
}

interface FabricRuleOption {
  id: string;
  style_code: string;
  display_name: string | null;
  image_url: string | null;
  product_line: string | null;
  fullness_factor: number;
  top_hem_cm: number;
  bottom_hem_cm: number;
  side_hem_cm: number;
  waste_pct: number;
}

const STYLE_IMAGE_PATHS: Record<string, string> = {
  'wave_2.3': '/images/Wave 2.3.png',
  'wave_2.8': '/images/Wave 2.8.png',
  pinch_pleat: '/images/Pinch Pleat.png',
};

export default function DraperyStyleStep({ config, onUpdate }: DraperyStyleStepProps) {
  const draperyConfig = config as DraperyConfig;
  const { activeOrganizationId } = useOrganizationContext();
  const [rules, setRules] = useState<FabricRuleOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [imageErrors, setImageErrors] = useState<Record<string, boolean>>({});

  const productTypeId = draperyConfig.productTypeId;
  const productLine = (config as any).productLine || null;

  useEffect(() => {
    if (!activeOrganizationId || !productTypeId) return;

    let cancelled = false;
    setLoading(true);

    (async () => {
      let query = supabase
        .from('FabricRules')
        .select('id, style_code, display_name, image_url, product_line, fullness_factor, top_hem_cm, bottom_hem_cm, side_hem_cm, waste_pct')
        .eq('organization_id', activeOrganizationId)
        .eq('product_type_id', productTypeId)
        .eq('formula_code', 'DRAPERY_PANELS')
        .eq('is_active', true)
        .order('fullness_factor', { ascending: true });

      if (productLine) {
        query = query.eq('product_line', productLine);
      }

      const { data, error } = await query;

      if (cancelled) return;
      setLoading(false);

      if (error) {
        console.error('[DraperyStyleStep] Failed to load fabric rules:', error);
        return;
      }

      setRules(data ?? []);
    })();

    return () => { cancelled = true; };
  }, [activeOrganizationId, productTypeId, productLine]);

  const selectedStyleCode = draperyConfig.styleCode;

  const ruleCards = useMemo(() => {
    return rules.map((rule) => {
      const name = rule.display_name || rule.style_code.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
      const subtitle = `Fullness ${rule.fullness_factor}x`;
      return { ...rule, name, subtitle };
    });
  }, [rules]);

  if (loading) {
    return (
      <div className="max-w-4xl mx-auto">
        <div className="bg-white rounded-lg border border-gray-200 p-6">
          <Label className="text-sm font-medium mb-4 block">STYLE VARIANT</Label>
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {[1, 2, 3].map((i) => (
              <div key={i} className="animate-pulse border border-gray-200 rounded-lg overflow-hidden">
                <div className="aspect-square bg-gray-100" />
                <div className="p-4 bg-gray-100">
                  <div className="h-4 bg-gray-200 rounded w-3/4 mx-auto" />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  if (ruleCards.length === 0) {
    return (
      <div className="max-w-4xl mx-auto">
        <div className="bg-white rounded-lg border border-gray-200 p-6">
          <Label className="text-sm font-medium mb-4 block">STYLE VARIANT</Label>
          <p className="text-sm text-gray-500 text-center py-8">
            No style variants configured{productLine ? ` for ${productLine.replace(/_/g, ' ')}` : ''}.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <Label className="text-sm font-medium mb-4 block">STYLE VARIANT</Label>

        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {ruleCards.map((card) => {
            const isSelected = selectedStyleCode === card.style_code;
            const imagePath = card.image_url || STYLE_IMAGE_PATHS[card.style_code];
            const hasImageError = imageErrors[card.style_code];

            return (
              <div
                key={card.id}
                onClick={() => {
                  const updates: Partial<DraperyConfig> = {
                    styleCode: isSelected ? undefined : card.style_code as DraperyConfig['styleCode'],
                    fullness: isSelected ? undefined : card.fullness_factor,
                  };
                  onUpdate(updates as Partial<ProductConfig>);
                }}
                className={`bg-white border rounded-lg overflow-hidden transition-all cursor-pointer ${
                  isSelected
                    ? 'border-2 border-gray-900 shadow-lg'
                    : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                }`}
              >
                <div className="aspect-square bg-white flex items-center justify-center overflow-hidden">
                  {imagePath && !hasImageError ? (
                    <img
                      src={imagePath}
                      alt={card.name}
                      className="w-full h-full object-contain"
                      onError={() => setImageErrors((prev) => ({ ...prev, [card.style_code]: true }))}
                    />
                  ) : (
                    <ImageIcon className="w-16 h-16 text-gray-300" />
                  )}
                </div>

                <div className="p-4 bg-gray-100">
                  <h3
                    className="font-semibold text-sm truncate text-center text-gray-900"
                    title={card.name}
                  >
                    {card.name}
                  </h3>
                  <p className="text-xs text-gray-500 text-center mt-1 truncate" title={card.subtitle}>
                    {card.subtitle}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
