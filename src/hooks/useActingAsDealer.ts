import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase, initSessionContext } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

const ACTING_DEALER_KEY = ['actingAsDealer'] as const;

async function fetchCurrentDealerId(): Promise<string | null> {
  const { data, error } = await supabase.rpc('get_current_dealer_id');
  if (error) {
    if (import.meta.env.DEV) {
      console.warn('[useActingAsDealer] get_current_dealer_id RPC failed:', error.message,
        '— Run the migration 20260224_004_acting_as_session_variable.sql in Supabase SQL Editor');
    }
    return null;
  }
  return (data as string | null) ?? null;
}

async function callSetActingDealer(dealerId: string | null): Promise<string | null> {
  if (import.meta.env.DEV) {
    console.log('[useActingAsDealer] set_acting_dealer →', dealerId);
  }
  const { data, error } = await supabase.rpc('set_acting_dealer', {
    p_dealer_id: dealerId,
  });
  if (error) {
    console.error('[useActingAsDealer] set_acting_dealer FAILED:', error.message);
    throw error;
  }
  const row = Array.isArray(data) ? data[0] : data;
  const result = row?.active_dealer_id ?? dealerId;
  if (import.meta.env.DEV) {
    console.log('[useActingAsDealer] set_acting_dealer OK → active_dealer_id =', result);
  }
  return result;
}

/**
 * Single source of truth for the effective dealer in the current session.
 *
 * - Dealer users: returns their fixed dealer_id (from AppUsers).
 * - Org users (SuperAdmin/Admin): returns AppUserPreferences.active_dealer_id.
 *
 * `setActingDealer(id)` persists the choice to DB via RPC and invalidates
 * all React Query caches so every dealer-scoped query refetches.
 */
const LAST_ACTIVE_ORG_KEY = 'last_active_org_id';
const LAST_ACTIVE_DEALER_KEY = 'last_active_dealer_id';

export function useActingAsDealer() {
  const queryClient = useQueryClient();
  const { activeOrganizationId } = useOrganizationContext();

  const query = useQuery({
    queryKey: ACTING_DEALER_KEY,
    queryFn: fetchCurrentDealerId,
    staleTime: Infinity,
    gcTime: Infinity,
    refetchOnWindowFocus: false,
    retry: 1,
  });

  const mutation = useMutation({
    mutationFn: callSetActingDealer,
    onSuccess: (activeDealerId) => {
      queryClient.setQueryData(ACTING_DEALER_KEY, activeDealerId);
      if (typeof window !== 'undefined' && activeOrganizationId) {
        try {
          window.localStorage.setItem(LAST_ACTIVE_ORG_KEY, activeOrganizationId);
          window.localStorage.setItem(LAST_ACTIVE_DEALER_KEY, activeDealerId ?? '');
        } catch {
          // ignore storage errors
        }
      }
      void initSessionContext();
      queryClient.invalidateQueries({ queryKey: ['directory'] });
      queryClient.invalidateQueries({ queryKey: ['sales'] });
      queryClient.invalidateQueries({ queryKey: ['catalog'] });
      queryClient.invalidateQueries({ queryKey: ['settings'] });
    },
  });

  return {
    activeDealerId: query.data ?? null,
    isLoading: query.isLoading,
    hasHydrated: !query.isLoading,
    setActingDealer: (dealerId: string | null) => mutation.mutate(dealerId),
    clearActingDealer: () => mutation.mutate(null),
    isSaving: mutation.isPending,
  };
}
