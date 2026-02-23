import React, { createContext, useContext, useCallback } from 'react';
import { useOrganizationContext } from './OrganizationContext';
import { useActingAsDealer } from '../hooks/useActingAsDealer';
import { useDealers } from '../hooks/useDealers';

export type ActiveDealerType = 'internal' | 'external';

type ActingAsContextValue = {
  activeDealerId: string | null;
  activeDisplayName: string;
  activeDealerType: ActiveDealerType;
  hasChosenActingAs: boolean;
  hasHydrated: boolean;
  isSwitching: boolean;
  setActiveDealer: (dealerId: string | null, displayName: string) => void;
  clearActingAs: () => void;
};

const ActingAsContext = createContext<ActingAsContextValue | null>(null);

/**
 * Thin wrapper around useActingAsDealer (DB-persisted).
 * Keeps the same interface so existing consumers don't break.
 */
export function ActingAsProvider({ children }: { children: React.ReactNode }) {
  const { activeOrganization } = useOrganizationContext();
  const { dealers } = useDealers();
  const {
    activeDealerId,
    hasHydrated,
    setActingDealer,
    clearActingDealer,
    isSaving,
  } = useActingAsDealer();

  const activeDealer = activeDealerId
    ? dealers.find((d) => d.id === activeDealerId) ?? null
    : null;

  const setActiveDealer = useCallback(
    (_dealerId: string | null, _displayName: string) => {
      setActingDealer(_dealerId);
    },
    [setActingDealer]
  );

  const clearActingAs = useCallback(() => {
    clearActingDealer();
  }, [clearActingDealer]);

  const value: ActingAsContextValue = {
    activeDealerId,
    activeDisplayName: activeDealer?.dealer_name || activeOrganization?.name || 'Organization',
    activeDealerType: activeDealerId ? 'external' : 'internal',
    hasChosenActingAs: activeDealerId != null,
    hasHydrated,
    isSwitching: isSaving,
    setActiveDealer,
    clearActingAs,
  };

  return <ActingAsContext.Provider value={value}>{children}</ActingAsContext.Provider>;
}

export function useActingAsContext(): ActingAsContextValue | null {
  return useContext(ActingAsContext);
}
