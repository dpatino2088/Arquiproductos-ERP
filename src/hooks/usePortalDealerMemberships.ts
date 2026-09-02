import { useQuery } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';

export interface PortalDealerMembership {
  dealer_id: string;
  dealer_name: string;
  role_code: string | null;
  is_active: boolean;
}

const MEMBERSHIPS_KEY = ['portalDealerMemberships'] as const;

async function fetchMemberships(): Promise<PortalDealerMembership[]> {
  const { data, error } = await supabase.rpc('get_my_dealer_memberships');
  if (error) {
    if (import.meta.env.DEV) {
      console.warn('[usePortalDealerMemberships] RPC failed:', error.message);
    }
    return [];
  }
  return (data ?? []) as PortalDealerMembership[];
}

/**
 * Dealer memberships of the logged-in PORTAL user (one row per dealer they belong
 * to). Internal (org) users get an empty list. Used by the header dealer switcher;
 * the actual switch goes through useActingAsDealer.setActingDealer, which the DB
 * now accepts for portal users (restricted to their own memberships).
 */
export function usePortalDealerMemberships(enabled: boolean) {
  const query = useQuery({
    queryKey: MEMBERSHIPS_KEY,
    queryFn: fetchMemberships,
    enabled,
    staleTime: 5 * 60 * 1000,
    refetchOnWindowFocus: false,
    retry: 1,
  });

  return {
    memberships: query.data ?? [],
    isLoading: query.isLoading,
  };
}
