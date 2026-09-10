import { useEffect, useState } from 'react';
import Label from '../../../components/ui/Label';
import { Image as ImageIcon } from 'lucide-react';
import { supabase } from '../../../lib/supabase/client';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { useConfiguratorPolicy } from '../../../context/ConfiguratorPolicyContext';

interface AwningSystemSelectorProps {
  config: any;
  onUpdate: (updates: any) => void;
}

const getImageUrl = (path: string) => {
  const base = (import.meta.env.BASE_URL || '/').replace(/\/$/, '') || '';
  return `${base}${path.startsWith('/') ? path : '/' + path}`;
};

const SYSTEMS = [
  {
    uiCode: 'awning',
    dbCode: 'awning',
    name: 'Retractable Awning',
    description: 'Folding arm system for terraces, patios and outdoor areas',
    imagePaths: ['/images/Awning Retractable.png', '/images/Awning.png'],
  },
  {
    uiCode: 'awning-vertical',
    dbCode: 'awning_vertical',
    name: 'Vertical Awning',
    description: 'Vertical drop screen for terraces and windows',
    imagePaths: ['/images/Awning Vertical.png', '/images/Awning.png'],
  },
] as const;

/**
 * Awning system sub-selection shown INSIDE the Measurements step.
 * Switching system swaps the product type (awning ↔ awning-vertical) via a
 * special update key handled by ProductConfigurator, keeping the user on the
 * same step and preserving neutral context (manufacturer, width, etc.).
 */
export default function AwningSystemSelector({ config, onUpdate }: AwningSystemSelectorProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const { policy } = useConfiguratorPolicy();
  const [typeIdsByCode, setTypeIdsByCode] = useState<Record<string, string>>({});
  const [imageIndexes, setImageIndexes] = useState<Record<string, number>>({});
  const [imageErrors, setImageErrors] = useState<Record<string, boolean>>({});

  useEffect(() => {
    if (!activeOrganizationId) return;
    let cancelled = false;
    (async () => {
      const { data, error } = await supabase
        .from('ProductTypes')
        .select('id, code')
        .eq('organization_id', activeOrganizationId)
        .in('code', ['awning', 'awning_vertical']);
      if (!cancelled && !error && data) {
        const map: Record<string, string> = {};
        data.forEach((row: any) => {
          if (row.code) map[row.code] = row.id;
        });
        setTypeIdsByCode(map);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [activeOrganizationId]);

  // The awning family is exposed as ONE product card: if the dealer policy allows
  // 'awning', both systems (extensible + vertical) are available in the selector.
  const policyCodes = (policy?.allowed_product_type_codes ?? []).map((c: string) => c.toLowerCase());
  const verticalAllowed =
    !policy || policyCodes.includes('awning_vertical') || policyCodes.includes('awning');

  const systems = SYSTEMS.filter((s) => s.uiCode !== 'awning-vertical' || verticalAllowed);
  if (systems.length <= 1) return null;

  const currentUiCode = config?.productType === 'awning-vertical' ? 'awning-vertical' : 'awning';

  return (
    <div>
      <Label className="text-sm font-medium mb-1 block">AWNING SYSTEM</Label>
      <p className="text-xs text-gray-500 mb-4">
        Switching the system updates the measurements below.
      </p>
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
        {systems.map((system) => {
          const isSelected = currentUiCode === system.uiCode;
          const targetTypeId = typeIdsByCode[system.dbCode];
          const disabled = !isSelected && !targetTypeId;
          const imgIndex = imageIndexes[system.uiCode] ?? 0;
          const hasImage = !imageErrors[system.uiCode] && imgIndex < system.imagePaths.length;
          return (
            <div
              key={system.uiCode}
              onClick={() => {
                if (isSelected || !targetTypeId) return;
                onUpdate({
                  _awning_system_switch: {
                    productType: system.uiCode,
                    productTypeId: targetTypeId,
                  },
                });
              }}
              className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all ${
                isSelected
                  ? 'border-2 border-gray-900 shadow-lg cursor-pointer'
                  : disabled
                  ? 'border-gray-200 opacity-60 cursor-not-allowed'
                  : 'border-gray-200 hover:shadow-lg hover:border-gray-300 cursor-pointer'
              }`}
            >
              <div className="aspect-square bg-white flex items-center justify-center overflow-hidden">
                {hasImage ? (
                  <img
                    src={getImageUrl(system.imagePaths[imgIndex])}
                    alt={system.name}
                    className="w-full h-full object-contain"
                    onError={() => {
                      if (imgIndex + 1 < system.imagePaths.length) {
                        setImageIndexes((prev) => ({ ...prev, [system.uiCode]: imgIndex + 1 }));
                      } else {
                        setImageErrors((prev) => ({ ...prev, [system.uiCode]: true }));
                      }
                    }}
                  />
                ) : (
                  <ImageIcon className="w-16 h-16 text-gray-300" />
                )}
              </div>
              <div className="p-4 bg-gray-100 flex-1">
                <h3 className="font-semibold text-sm truncate text-center text-gray-900" title={system.name}>
                  {system.name}
                </h3>
                <p className="text-[11px] text-gray-500 text-center mt-1">{system.description}</p>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
