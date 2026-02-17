import React, { createContext, useContext, useState, useCallback, useEffect } from 'react';
import { useOrganizationContext } from './OrganizationContext';

const STORAGE_KEY = 'adaptio_acting_as';

export type ActiveDealerType = 'internal' | 'external';

type Stored = {
  organizationId: string;
  dealerId: string | null;
  displayName: string;
  dealerType?: ActiveDealerType;
};

function loadStored(orgId: string | null): Stored | null {
  if (!orgId) return null;
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Stored;
    if (parsed.organizationId !== orgId) return null;
    if (!parsed.dealerType) parsed.dealerType = parsed.dealerId == null ? 'internal' : 'external';
    return parsed;
  } catch {
    return null;
  }
}

function saveStored(orgId: string, dealerId: string | null, displayName: string, dealerType: ActiveDealerType) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({
      organizationId: orgId,
      dealerId,
      displayName,
      dealerType,
    }));
  } catch {
    // ignore
  }
}

type ActingAsContextValue = {
  /** null = acting as organization (e.g. Pertexco), uuid = acting as that Dealer */
  activeDealerId: string | null;
  /** Display name: organization name or dealer name */
  activeDisplayName: string;
  /** internal = org, external = dealer. For pricing rules, features, UI. */
  activeDealerType: ActiveDealerType;
  /** True if user has made a selection for the current org (stored in localStorage) */
  hasChosenActingAs: boolean;
  /** True after first run of useEffect (localStorage read). Evita fetch con activeDealerId=null antes de hidratar. */
  hasHydrated: boolean;
  /** ✅ Estándar #10: True durante cambio de dealer (SuperAdmin switching) */
  isSwitching: boolean;
  setActiveDealer: (dealerId: string | null, displayName: string) => void;
  clearActingAs: () => void;
};

const ActingAsContext = createContext<ActingAsContextValue | null>(null);

export function ActingAsProvider({ children }: { children: React.ReactNode }) {
  const { activeOrganizationId, activeOrganization } = useOrganizationContext();
  const [activeDealerId, setActiveDealerIdState] = useState<string | null>(null);
  const [activeDisplayName, setActiveDisplayName] = useState<string>('');
  const [activeDealerType, setActiveDealerTypeState] = useState<ActiveDealerType>('internal');
  const [hasChosenActingAs, setHasChosenActingAs] = useState(false);
  const [hasHydrated, setHasHydrated] = useState(false);
  // ✅ Estándar #10: Estado "switching" durante cambio de dealer
  const [isSwitching, setIsSwitching] = useState(false);

  useEffect(() => {
    const stored = loadStored(activeOrganizationId ?? null);
    if (stored) {
      setActiveDealerIdState(stored.dealerId);
      setActiveDisplayName(stored.displayName || (stored.dealerId ? 'Dealer' : 'Organization'));
      setActiveDealerTypeState(stored.dealerType ?? (stored.dealerId == null ? 'internal' : 'external'));
      setHasChosenActingAs(true);
    } else {
      setActiveDealerIdState(null);
      setActiveDisplayName(activeOrganization?.name || '');
      setActiveDealerTypeState('internal');
      setHasChosenActingAs(false);
    }
    setHasHydrated(true);
    // ✅ Hidratar no es switching
    setIsSwitching(false);
  }, [activeOrganizationId, activeOrganization?.name]);

  const setActiveDealer = useCallback(
    (dealerId: string | null, displayName: string) => {
      if (!activeOrganizationId) return;
      
      // ✅ Estándar #10: Marcar switching ANTES de cambiar dealer
      setIsSwitching(true);
      
      const dealerType: ActiveDealerType = dealerId == null ? 'internal' : 'external';
      setActiveDealerIdState(dealerId);
      setActiveDisplayName(displayName);
      setActiveDealerTypeState(dealerType);
      setHasChosenActingAs(true);
      saveStored(activeOrganizationId, dealerId, displayName, dealerType);
      
      // ✅ Desmarcar switching después de un breve delay (permite que hooks reaccionen)
      setTimeout(() => setIsSwitching(false), 100);
    },
    [activeOrganizationId]
  );

  const clearActingAs = useCallback(() => {
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch {
      // ignore
    }
    setActiveDealerIdState(null);
    setActiveDisplayName(activeOrganization?.name || '');
    setActiveDealerTypeState('internal');
    setHasChosenActingAs(false);
  }, [activeOrganization?.name]);

  const value: ActingAsContextValue = {
    activeDealerId,
    activeDisplayName: activeDisplayName || activeOrganization?.name || 'Organization',
    activeDealerType,
    hasChosenActingAs,
    hasHydrated,
    isSwitching,
    setActiveDealer,
    clearActingAs,
  };

  return <ActingAsContext.Provider value={value}>{children}</ActingAsContext.Provider>;
}

export function useActingAsContext(): ActingAsContextValue | null {
  return useContext(ActingAsContext);
}
