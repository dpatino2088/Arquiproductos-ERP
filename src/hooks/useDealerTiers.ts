import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface DealerTier {
  id: string;
  organization_id: string;
  code: string;
  name: string;
  discount_pct: number;
  sort_order: number;
  active: boolean;
  created_at?: string;
  updated_at?: string;
}

export function useDealerTiers() {
  const { activeOrganizationId } = useOrganizationContext();
  const [tiers, setTiers] = useState<DealerTier[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchTiers = useCallback(async () => {
    if (!activeOrganizationId) {
      setTiers([]);
      setIsLoading(false);
      return;
    }
    try {
      setIsLoading(true);
      setError(null);
      const { data, error: qErr } = await supabase
        .from('DealerTiers')
        .select('id, organization_id, code, name, discount_pct, sort_order, active, created_at, updated_at')
        .eq('organization_id', activeOrganizationId)
        .order('sort_order', { ascending: true });

      if (qErr) throw qErr;
      setTiers((data || []).map((row: any) => ({
        id: row.id,
        organization_id: row.organization_id,
        code: row.code,
        name: row.name,
        discount_pct: Number(row.discount_pct),
        sort_order: row.sort_order ?? 0,
        active: row.active ?? true,
        created_at: row.created_at,
        updated_at: row.updated_at,
      })));
    } catch (err: any) {
      setError(err?.message ?? 'Error loading tiers');
      setTiers([]);
    } finally {
      setIsLoading(false);
    }
  }, [activeOrganizationId]);

  const updateTierDiscount = useCallback(async (id: string, discount_pct: number): Promise<void> => {
    if (!activeOrganizationId) throw new Error('No active organization');
    const { error: updateErr } = await supabase
      .from('DealerTiers')
      .update({ discount_pct, updated_at: new Date().toISOString() })
      .eq('id', id)
      .eq('organization_id', activeOrganizationId);
    if (updateErr) throw updateErr;
    await fetchTiers();
  }, [activeOrganizationId, fetchTiers]);

  useEffect(() => {
    fetchTiers();
  }, [fetchTiers]);

  return { tiers, isLoading, error, refetch: fetchTiers, updateTierDiscount };
}
