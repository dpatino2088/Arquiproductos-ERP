import { useEffect, useState } from 'react';
import { Building2 } from 'lucide-react';
import { supabase } from '../../../../../lib/supabase/client';
import { useOrganizationContext } from '../../../../../context/OrganizationContext';

interface Manufacturer {
  name: string;
  logo_url: string | null;
}

interface FilmManufacturerStepProps {
  config: any;
  onUpdate: (updates: Record<string, any>) => void;
}

export default function FilmManufacturerStep({ config, onUpdate }: FilmManufacturerStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const [manufacturers, setManufacturers] = useState<Manufacturer[]>([]);
  const [loading, setLoading] = useState(true);
  const [imageErrors, setImageErrors] = useState<Record<string, boolean>>({});

  const selected: string | null = config.manufacturer || null;

  useEffect(() => {
    if (!activeOrganizationId) return;
    let cancelled = false;

    (async () => {
      setLoading(true);

      const { data: items } = await supabase
        .from('CatalogItems')
        .select('manufacturer')
        .eq('organization_id', activeOrganizationId)
        .eq('item_role', 'window_film')
        .eq('is_active', true)
        .not('manufacturer', 'is', null);

      if (cancelled) return;

      const allNames = (items ?? []).map((i: any) => String(i.manufacturer)).filter(Boolean);
      const uniqueNames = Array.from(new Set<string>(allNames)).sort();

      if (uniqueNames.length === 0) {
        setManufacturers([]);
        setLoading(false);
        return;
      }

      const { data: mfrRows } = await supabase
        .from('Manufacturers')
        .select('name, logo_url')
        .in('name', uniqueNames);

      const mfrMap = new Map((mfrRows ?? []).map((m: any) => [m.name, m.logo_url]));

      if (!cancelled) {
        setManufacturers(uniqueNames.map((name: string) => ({
          name,
          logo_url: (mfrMap.get(name) as string | null) ?? null,
        })));
        setLoading(false);

        if (uniqueNames.length === 1 && !selected) {
          onUpdate({ manufacturer: uniqueNames[0] });
        }
      }
    })();
    return () => { cancelled = true; };
  }, [activeOrganizationId]);

  const getImageSrc = (mfr: Manufacturer) => {
    if (mfr.logo_url) return mfr.logo_url;
    return `/images/${mfr.name}.png`;
  };

  if (loading) {
    return (
      <div className="max-w-4xl mx-auto">
        <div className="bg-white rounded-lg border border-gray-200 p-6">
          <div className="animate-pulse space-y-4">
            <div className="h-6 bg-gray-200 rounded w-48" />
            <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
              {[1, 2].map(i => <div key={i} className="aspect-square bg-gray-100 rounded-lg" />)}
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <h3 className="text-base font-semibold text-gray-900 mb-2">Select Manufacturer</h3>
        <p className="text-sm text-gray-500 mb-6">Choose the film manufacturer for this product.</p>

        {manufacturers.length === 0 ? (
          <p className="text-sm text-gray-500 text-center py-8">No manufacturers found for Window Film.</p>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
            {manufacturers.map((mfr) => {
              const isSelected = selected === mfr.name;
              const hasImageError = imageErrors[mfr.name];
              return (
                <div
                  key={mfr.name}
                  onClick={() => onUpdate({
                    manufacturer: mfr.name,
                    catalog_item_id: null,
                    name: '',
                    sku: '',
                  })}
                  className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer ${
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
                        onError={() => setImageErrors(prev => ({ ...prev, [mfr.name]: true }))}
                      />
                    ) : (
                      <Building2 className="w-16 h-16 text-gray-300" />
                    )}
                  </div>
                  <div className="p-4 bg-gray-100 flex-1">
                    <h3 className="font-semibold text-sm truncate text-center text-gray-900">
                      {mfr.name}
                    </h3>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
