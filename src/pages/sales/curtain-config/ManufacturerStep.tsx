import React, { useEffect, useState } from 'react';
import { Building2 } from 'lucide-react';
import { supabase } from '../../../lib/supabase/client';
import { useOrganizationContext } from '../../../context/OrganizationContext';

interface Manufacturer {
  name: string;
  logo_url: string | null;
}

interface ManufacturerStepProps {
  config: any;
  onUpdate: (updates: Record<string, any>) => void;
}

export default function ManufacturerStep({ config, onUpdate }: ManufacturerStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const [manufacturers, setManufacturers] = useState<Manufacturer[]>([]);
  const [loading, setLoading] = useState(true);
  const [imageErrors, setImageErrors] = useState<Record<string, boolean>>({});
  const [templatesByMfr, setTemplatesByMfr] = useState<Map<string, string[]>>(new Map());

  const productTypeId = config.productTypeId;
  const selected = config.manufacturer || null;

  useEffect(() => {
    if (!activeOrganizationId || !productTypeId) {
      setManufacturers([]);
      setTemplatesByMfr(new Map());
      setLoading(false);
      return;
    }
    let cancelled = false;
    setLoading(true);

    (async () => {
      const { data: tplData, error: tplErr } = await supabase
        .from('BOMTemplates')
        .select('id, manufacturer')
        .eq('organization_id', activeOrganizationId)
        .eq('product_type_id', productTypeId)
        .eq('is_active', true)
        .eq('deleted', false)
        .not('manufacturer', 'is', null);

      if (cancelled) return;
      if (tplErr || !tplData?.length) {
        setManufacturers([]);
        setTemplatesByMfr(new Map());
        setLoading(false);
        return;
      }

      const mfrToIds = new Map<string, string[]>();
      tplData.forEach((r: any) => {
        const name = (r.manufacturer as string)?.trim();
        if (!name) return;
        if (!mfrToIds.has(name)) mfrToIds.set(name, []);
        mfrToIds.get(name)!.push(r.id);
      });
      setTemplatesByMfr(mfrToIds);

      const uniqueNames = Array.from(mfrToIds.keys()).sort();

      const { data: mfrData } = await supabase
        .from('Manufacturers')
        .select('name, logo_url')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .in('name', uniqueNames);

      if (cancelled) return;

      const mfrMap = new Map<string, string | null>((mfrData || []).map((m: { name: string; logo_url: string | null }) => [m.name, m.logo_url ?? null]));
      const result: Manufacturer[] = uniqueNames.map((name) => ({
        name,
        logo_url: mfrMap.get(name) || null,
      }));

      setManufacturers(result);
      if (result.length === 1 && !selected) {
        const autoName = result[0].name;
        onUpdate({
          manufacturer: autoName,
          productLine: null,
          _manufacturer_filtered_templates: mfrToIds.get(autoName) || null,
        });
      }
      setLoading(false);
    })();

    return () => { cancelled = true; };
  }, [activeOrganizationId, productTypeId]);

  const getImageSrc = (mfr: Manufacturer) => {
    if (mfr.logo_url) return mfr.logo_url;
    return `/images/${mfr.name}.png`;
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-16">
        <div className="animate-spin h-6 w-6 border-2 border-gray-300 border-t-gray-600 rounded-full" />
      </div>
    );
  }

  if (manufacturers.length === 0) {
    return (
      <div className="space-y-4">
        <h2 className="text-lg font-semibold text-gray-900">Manufacturer</h2>
        <p className="text-sm text-gray-500">
          No manufacturers configured for this product type. You can proceed to the next step.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold text-gray-900">Select Manufacturer</h2>
        <p className="text-sm text-gray-500 mt-1">
          Choose the system manufacturer for this product.
        </p>
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
        {manufacturers.map((mfr) => {
          const isSelected = selected === mfr.name;
          const hasImageError = imageErrors[mfr.name];
          return (
            <div
              key={mfr.name}
              onClick={() => onUpdate({
                manufacturer: mfr.name,
                productLine: null,
                _manufacturer_filtered_templates: templatesByMfr.get(mfr.name) || null,
                _hardware_filtered_templates: undefined,
              })}
              className={`bg-white border rounded-lg overflow-hidden transition-all cursor-pointer ${
                isSelected
                  ? 'border-2 border-gray-900 shadow-lg'
                  : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
              }`}
            >
              <div className="aspect-square bg-white flex items-center justify-center overflow-hidden p-4">
                {!hasImageError ? (
                  <img
                    src={getImageSrc(mfr)}
                    alt={mfr.name}
                    className="max-h-full max-w-full object-contain"
                    onError={() => setImageErrors((prev) => ({ ...prev, [mfr.name]: true }))}
                  />
                ) : (
                  <Building2 className="w-16 h-16 text-gray-300" />
                )}
              </div>
              <div className="p-4 bg-gray-100">
                <h3 className={`font-semibold text-sm truncate text-center ${
                  isSelected ? 'text-gray-900' : 'text-gray-900'
                }`}>
                  {mfr.name}
                </h3>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
