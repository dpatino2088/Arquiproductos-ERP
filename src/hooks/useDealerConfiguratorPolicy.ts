import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase/client';
import { useActingAsContext } from '../context/ActingAsContext';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface DealerConfiguratorPolicy {
  id: string;
  organization_id: string;
  dealer_id: string;
  allowed_product_type_codes: string[];
  allow_variants_catalog: boolean;
  allow_accessories_only: boolean;
  allow_hardware: boolean;
  allow_operating_system: boolean;
  allow_custom_only_proposals: boolean;
  created_at?: string;
  updated_at?: string;
}

export type UseDealerConfiguratorPolicyResult = {
  policy: DealerConfiguratorPolicy | null;
  loading: boolean;
};

/**
 * Loads DealerConfiguratorPolicies for the effective dealer.
 * Priority: overrideDealerId (from Quote) > activeDealerId (acting-as context).
 * - policy null = no dealer or no policy row (no restriction).
 * - allowed_product_type_codes are normalized to lowercase for case-insensitive matching.
 */
export function useDealerConfiguratorPolicy(overrideDealerId?: string | null): UseDealerConfiguratorPolicyResult {
  const { activeDealerId } = useActingAsContext() ?? {};
  const { activeOrganizationId } = useOrganizationContext();
  const effectiveDealerId = overrideDealerId ?? activeDealerId ?? null;
  const [policy, setPolicy] = useState<DealerConfiguratorPolicy | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!effectiveDealerId || !activeOrganizationId) {
      setPolicy(null);
      setLoading(false);
      return;
    }

    setPolicy(null);
    setLoading(true);
    let mounted = true;

    async function loadPolicy() {
      const { data, error } = await supabase
        .from('DealerConfiguratorPolicies')
        .select('*')
        .eq('organization_id', activeOrganizationId)
        .eq('dealer_id', effectiveDealerId)
        .maybeSingle();

      if (!mounted) {
        return;
      }
      if (!error && data) {
        const raw = Array.isArray(data.allowed_product_type_codes) ? data.allowed_product_type_codes : [];
        const normalized = raw.map((x: unknown) => String(x).trim().toLowerCase()).filter(Boolean);
        setPolicy({
          ...data,
          allowed_product_type_codes: normalized,
          allow_custom_only_proposals: data.allow_custom_only_proposals ?? false,
        } as DealerConfiguratorPolicy);
      } else {
        setPolicy(null);
      }
      setLoading(false);
    }

    loadPolicy();
    return () => {
      mounted = false;
    };
  }, [effectiveDealerId, activeOrganizationId]);

  return { policy, loading };
}
