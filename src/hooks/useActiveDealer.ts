import { useCallback } from 'react';
import { useDealers } from './useDealers';
import { useActingAsDealer } from './useActingAsDealer';

/**
 * Hook for the active dealer scope.
 *
 * Delegates to useActingAsDealer (DB-persisted via current_dealer_id() RPC).
 * No role-based branching — the DB resolver handles org vs dealer users.
 */
export function useActiveDealer() {
  const { dealers, isLoading: dealersLoading } = useDealers();
  const {
    activeDealerId,
    isLoading: actingLoading,
    hasHydrated,
    setActingDealer,
    isSaving,
  } = useActingAsDealer();

  const activeDealer = activeDealerId
    ? dealers.find((d) => d.id === activeDealerId) ?? null
    : null;

  const setActiveDealerId = useCallback(
    (dealerId: string | null) => {
      setActingDealer(dealerId);
    },
    [setActingDealer]
  );

  return {
    activeDealerId,
    activeDealer,
    setActiveDealerId,
    isLoading: dealersLoading || actingLoading,
    hasDealers: dealers.length > 0,
    dealers,
    hasHydrated,
    isSwitching: isSaving,
  };
}
