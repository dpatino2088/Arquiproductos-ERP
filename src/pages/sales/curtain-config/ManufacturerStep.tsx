import React, { useEffect, useState } from 'react';
import { Building2 } from 'lucide-react';
import { supabase } from '../../../lib/supabase/client';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { useConfiguratorPolicy } from '../../../context/ConfiguratorPolicyContext';
import { prefetchImageUrls } from '../../../lib/imagePrefetch';

interface Manufacturer {
  name: string;
  logo_url: string | null;
}

interface ManufacturerStepProps {
  config: any;
  onUpdate: (updates: Record<string, any>) => void;
}

const IMAGE_EXTENSIONS = new Set([
  'png', 'jpg', 'jpeg', 'webp', 'gif', 'svg', 'avif', 'bmp',
]);

function isSupportedImageAsset(url: string): boolean {
  const trimmed = url.trim();
  if (!trimmed) return false;
  // No extension -> allow (some storage URLs omit extension in pathname)
  if (!/[./]/.test(trimmed)) return true;
  try {
    const parsed = /^https?:\/\//i.test(trimmed)
      ? new URL(trimmed)
      : new URL(trimmed.startsWith('/') ? `https://local${trimmed}` : `https://local/${trimmed}`);
    const path = parsed.pathname.toLowerCase();
    const match = path.match(/\.([a-z0-9]+)$/i);
    if (!match) return true;
    return IMAGE_EXTENSIONS.has(match[1]);
  } catch {
    const bare = trimmed.split('?')[0].split('#')[0].toLowerCase();
    const match = bare.match(/\.([a-z0-9]+)$/i);
    if (!match) return true;
    return IMAGE_EXTENSIONS.has(match[1]);
  }
}

export default function ManufacturerStep({ config, onUpdate }: ManufacturerStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const { policy } = useConfiguratorPolicy();
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

      // Per-dealer restriction: only show allowed manufacturers (empty list = no restriction).
      const allowedNames = Array.isArray(policy?.allowed_manufacturer_names) ? policy!.allowed_manufacturer_names : [];
      const allowedSet = new Set(allowedNames.map((n) => String(n).trim().toLowerCase()).filter(Boolean));
      const uniqueNames = Array.from(mfrToIds.keys())
        .filter((name) => allowedSet.size === 0 || allowedSet.has(String(name).trim().toLowerCase()))
        .sort();

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
      } else if (selected && !config._manufacturer_filtered_templates) {
        const ids = mfrToIds.get(selected);
        if (ids) onUpdate({ _manufacturer_filtered_templates: ids });
      }
      setLoading(false);
    })();

    return () => { cancelled = true; };
  }, [activeOrganizationId, productTypeId, (policy?.allowed_manufacturer_names || []).join('|')]);

  const getImageSrc = (mfr: Manufacturer) => {
    const fallback = `/images/${mfr.name}.png`;
    const raw = mfr.logo_url?.trim();
    if (!raw) return fallback;
    if (!isSupportedImageAsset(raw)) return fallback;

    if (/^https?:\/\//i.test(raw)) return raw;
    if (raw.startsWith('/images/') || raw.startsWith('images/')) return raw.startsWith('/') ? raw : `/${raw}`;
    if (raw.startsWith('/assets/') || raw.startsWith('assets/')) return raw.startsWith('/') ? raw : `/${raw}`;

    const { data } = supabase.storage.from('catalog-images').getPublicUrl(raw.replace(/^\/+/, ''));
    return data.publicUrl || fallback;
  };

  useEffect(() => {
    if (manufacturers.length === 0) return;
    prefetchImageUrls(manufacturers.map((mfr) => getImageSrc(mfr)), 8);
  }, [manufacturers]);

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
                    loading="eager"
                    decoding="sync"
                    onError={() => setImageErrors((prev) => ({ ...prev, [mfr.name]: true }))}
                  />
                ) : (
                  <Building2 className="w-16 h-16 text-gray-300" />
                )}
              </div>
              <div className="p-4 bg-gray-100 flex-1">
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
