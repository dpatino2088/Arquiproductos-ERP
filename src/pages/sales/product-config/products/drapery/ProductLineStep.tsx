import React, { useEffect, useState, useMemo } from 'react';
import { Layers, Image as ImageIcon, Ruler } from 'lucide-react';
import { supabase } from '../../../../../lib/supabase/client';
import { useOrganizationContext } from '../../../../../context/OrganizationContext';
import Label from '../../../../../components/ui/Label';

interface ProductLineStepProps {
  config: any;
  onUpdate: (updates: Record<string, any>) => void;
}

interface FabricRuleOption {
  id: string;
  style_code: string;
  display_name: string | null;
  image_url: string | null;
  fabric_group: string | null;
  fullness_factor: number;
}

const DISPLAY_NAMES: Record<string, string> = {
  wave_drapery: 'Wave Drapery',
  ripple_fold: 'Ripple Fold',
  pinch_pleat: 'Pinch Pleat',
};

const FABRIC_GROUP_MAP: Record<string, string> = {
  wave_drapery: 'wave',
  ripple_fold: 'wave',
  pinch_pleat: 'pinch_pleat',
};

const PRODUCT_LINE_IMAGE_PATHS: Record<string, string> = {
  wave_drapery: '/images/Wave_Drapery.png',
  ripple_fold: '/images/Ripple_Fold.png',
  pinch_pleat: '/images/Pinch_Pleat.png',
};

const STYLE_IMAGE_PATHS: Record<string, string> = {
  'wave_2.0': '/images/DR_2.0.png',
  'wave_2.3': '/images/DR_2.3.png',
  'wave_2.8': '/images/DR_2.8.png',
  pinch_pleat: '/images/Drapery.png',
};

const SYSTEM_SIZE_IMAGE_PATHS: Record<string, string> = {
  '48mm': '/images/DR_48mm.png',
  '54mm': '/images/DR_54mm.png',
  '60mm': '/images/DR_60mm.png',
  '80mm': '/images/DR_80mm.png',
};

const SYSTEM_SIZE_LABELS: Record<string, string> = {
  '48mm': '48 mm',
  '54mm': '54 mm',
  '60mm': '60 mm',
  '80mm': '80 mm',
};

const PRODUCT_LINES_WITH_SYSTEM_SIZE = new Set(['wave_drapery', 'ripple_fold']);

export default function ProductLineStep({ config, onUpdate }: ProductLineStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const [productLines, setProductLines] = useState<string[]>([]);
  const [styleRules, setStyleRules] = useState<FabricRuleOption[]>([]);
  const [availableSystemSizes, setAvailableSystemSizes] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [imageErrors, setImageErrors] = useState<Record<string, boolean>>({});

  const productTypeId = config.productTypeId;
  const manufacturer = config.manufacturer;
  const selectedLine = config.productLine || config.product_line || null;
  const selectedStyleCode = config.styleCode || config.style_code || null;
  const selectedSystemSize = config.systemSize || config.system_size || null;

  const fabricGroup = selectedLine ? FABRIC_GROUP_MAP[selectedLine] ?? null : null;
  const requiresSystemSize = !!selectedLine && PRODUCT_LINES_WITH_SYSTEM_SIZE.has(selectedLine);

  // 1. Fetch available product lines from BOMTemplates
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
        if (unique.length === 1 && !selectedLine) {
          onUpdate({ productLine: unique[0] });
        }
      }
      setLoading(false);
    });

    return () => { cancelled = true; };
  }, [activeOrganizationId, productTypeId, manufacturer]);

  // 2. When product line is selected, fetch style rules (by fabric_group) + system sizes
  useEffect(() => {
    if (!activeOrganizationId || !productTypeId || !selectedLine) {
      setStyleRules([]);
      setAvailableSystemSizes([]);
      return;
    }

    const group = FABRIC_GROUP_MAP[selectedLine];
    if (!group) {
      setStyleRules([]);
      setAvailableSystemSizes([]);
      return;
    }

    let cancelled = false;

    (async () => {
      const rulesQuery = supabase
        .from('FabricRules')
        .select('id, style_code, display_name, image_url, fabric_group, fullness_factor')
        .eq('organization_id', activeOrganizationId)
        .eq('product_type_id', productTypeId)
        .eq('formula_code', 'DRAPERY_PANELS')
        .eq('is_active', true)
        .eq('fabric_group', group)
        .order('fullness_factor', { ascending: true });

      // Query 1: template-level system_size (roller products store it here)
      const tplSizesQuery = supabase
        .from('BOMTemplates')
        .select('system_size')
        .eq('product_type_id', productTypeId)
        .eq('is_active', true)
        .eq('deleted', false)
        .eq('product_line', selectedLine)
        .not('system_size', 'is', null)
        .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`);

      // Query 2: component-level condition_value (drapery stores system_size here via glider conditions)
      const tplIdsQuery = supabase
        .from('BOMTemplates')
        .select('id')
        .eq('product_type_id', productTypeId)
        .eq('is_active', true)
        .eq('deleted', false)
        .eq('product_line', selectedLine)
        .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`);

      const [rulesResult, tplSizesResult, tplIdsResult] = await Promise.all([rulesQuery, tplSizesQuery, tplIdsQuery]);

      if (cancelled) return;

      if (rulesResult.error) {
        console.error('[ProductLineStep] Failed to load style rules:', rulesResult.error);
        setStyleRules([]);
      } else {
        const rules = rulesResult.data ?? [];
        setStyleRules(rules);
        if (rules.length === 1 && !selectedStyleCode) {
          onUpdate({
            styleCode: rules[0].style_code,
            fullness: rules[0].fullness_factor,
          });
        }
      }

      // Merge system_size from both template-level and component-level sources
      let allSizes = new Set<string>();

      if (!tplSizesResult.error) {
        for (const r of (tplSizesResult.data ?? []) as { system_size?: string }[]) {
          const v = (r.system_size ?? '').trim();
          if (v) allSizes.add(v);
        }
      }

      // If no template-level sizes, check component conditions
      if (allSizes.size === 0 && !tplIdsResult.error) {
        const tIds = ((tplIdsResult.data ?? []) as { id: string }[]).map(t => t.id);
        if (tIds.length > 0) {
          const { data: condData } = await supabase
            .from('BOMComponents')
            .select('condition_value')
            .eq('organization_id', activeOrganizationId)
            .eq('condition_key', 'system_size')
            .eq('deleted', false)
            .eq('archived', false)
            .in('bom_template_id', tIds)
            .not('condition_value', 'is', null);

          if (!cancelled && condData) {
            for (const r of condData as { condition_value?: string }[]) {
              const v = (r.condition_value ?? '').trim();
              if (v) allSizes.add(v);
            }
          }
        }
      }

      if (cancelled) return;

      const unique = Array.from(allSizes).sort() as string[];
      setAvailableSystemSizes(unique);
      if (unique.length === 1 && !selectedSystemSize) {
        onUpdate({ systemSize: unique[0] });
      }
    })();

    return () => { cancelled = true; };
  }, [activeOrganizationId, productTypeId, selectedLine]);

  const styleCards = useMemo(() => {
    return styleRules.map((rule) => {
      const name = rule.display_name || rule.style_code.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
      const subtitle = `Fullness ${rule.fullness_factor}x`;
      return { ...rule, name, subtitle };
    });
  }, [styleRules]);

  const showWaveSizeSection = styleCards.length > 1;

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
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Section 1: Product Line */}
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <Label className="text-sm font-medium mb-4 block">PRODUCT LINE</Label>
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
          {productLines.map((line) => {
            const isSelected = selectedLine === line;
            const displayName = DISPLAY_NAMES[line] || line.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
            const hasImageError = imageErrors[line];
            const imagePath = PRODUCT_LINE_IMAGE_PATHS[line] || `/images/${displayName}.png`;
            return (
              <div
                key={line}
                onClick={() => {
                  if (isSelected) return;
                  onUpdate({ productLine: line, styleCode: undefined, systemSize: undefined });
                }}
                className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer ${
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
                <div className="p-4 bg-gray-100 flex-1">
                  <h3 className="font-semibold text-sm truncate text-center text-gray-900">
                    {displayName}
                  </h3>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Section 2: Wave Size — only when product line has multiple style variants */}
      {selectedLine && showWaveSizeSection && (
        <div className="bg-white rounded-lg border border-gray-200 p-6">
          <Label className="text-sm font-medium mb-4 block">WAVE SIZE</Label>
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {styleCards.map((card) => {
              const isSelected = selectedStyleCode === card.style_code;
              const imagePath = card.image_url || STYLE_IMAGE_PATHS[card.style_code];
              const hasImageError = imageErrors[`style_${card.style_code}`];

              return (
                <div
                  key={card.id}
                  onClick={() => {
                    onUpdate({
                      styleCode: isSelected ? undefined : card.style_code,
                      fullness: isSelected ? undefined : card.fullness_factor,
                    });
                  }}
                  className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer ${
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
                        onError={() => setImageErrors((prev) => ({ ...prev, [`style_${card.style_code}`]: true }))}
                      />
                    ) : (
                      <ImageIcon className="w-16 h-16 text-gray-300" />
                    )}
                  </div>
                  <div className="p-4 bg-gray-100 flex-1">
                    <h3 className="font-semibold text-sm truncate text-center text-gray-900" title={card.name}>
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
      )}

      {/* Section 3: System Size — only for Wave Drapery / Ripple Fold */}
      {selectedLine && requiresSystemSize && availableSystemSizes.length > 0 && (
        <div className="bg-white rounded-lg border border-gray-200 p-6">
          <Label className="text-sm font-medium mb-4 block">SYSTEM SIZE</Label>
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {availableSystemSizes.map((size) => {
              const isSelected = selectedSystemSize === size;
              const imagePath = SYSTEM_SIZE_IMAGE_PATHS[size];
              const hasImageError = imageErrors[`size_${size}`];
              const label = SYSTEM_SIZE_LABELS[size] || size;

              return (
                <div
                  key={size}
                  onClick={() => {
                    onUpdate({ systemSize: isSelected ? undefined : size });
                  }}
                  className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer ${
                    isSelected
                      ? 'border-2 border-gray-900 shadow-lg'
                      : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                  }`}
                >
                  <div className="aspect-square bg-white flex items-center justify-center overflow-hidden">
                    {imagePath && !hasImageError ? (
                      <img
                        src={imagePath}
                        alt={label}
                        className="w-full h-full object-contain"
                        onError={() => setImageErrors((prev) => ({ ...prev, [`size_${size}`]: true }))}
                      />
                    ) : (
                      <Ruler className="w-16 h-16 text-gray-300" />
                    )}
                  </div>
                  <div className="p-4 bg-gray-100 flex-1">
                    <h3 className="font-semibold text-sm truncate text-center text-gray-900">
                      {label}
                    </h3>
                    <p className="text-xs text-gray-500 text-center mt-1">
                      Track profile
                    </p>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
