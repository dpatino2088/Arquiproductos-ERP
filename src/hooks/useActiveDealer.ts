import { useState, useEffect, useCallback } from 'react';
import { useDealers } from './useDealers';
import { useCurrentOrgRole } from './useCurrentOrgRole';
import { useActingAsContext } from '../context/ActingAsContext';

/**
 * Hook para el dealer activo (antes useActiveCompany).
 * - Super Admin: usa ActingAsContext (activeDealerId + localStorage); sin selección no opera.
 * - Resto: primer dealer disponible o estado local.
 */
export function useActiveDealer() {
  const { dealers, isLoading: dealersLoading } = useDealers();
  const { isSuperAdmin } = useCurrentOrgRole();
  const actingAs = useActingAsContext();
  const [localDealerId, setLocalDealerId] = useState<string | null>(null);

  const useActingAs = isSuperAdmin && actingAs?.hasChosenActingAs;
  const activeDealerId = useActingAs ? actingAs.activeDealerId : localDealerId;

  useEffect(() => {
    if (useActingAs) return;
    if (!dealersLoading && dealers.length > 0 && !localDealerId) {
      const first = dealers[0];
      if (first) setLocalDealerId(first.id);
    } else if (dealers.length === 0 && localDealerId) {
      setLocalDealerId(null);
    }
  }, [dealers, dealersLoading, localDealerId, useActingAs]);

  const setActiveDealerId = useCallback(
    (id: string | null) => {
      if (useActingAs && actingAs) {
        const name = id ? dealers.find(d => d.id === id)?.dealer_name ?? 'Dealer' : (actingAs.activeDisplayName || 'Organization');
        actingAs.setActiveDealer(id, name);
      } else {
        setLocalDealerId(id);
      }
    },
    [useActingAs, actingAs, dealers]
  );

  const activeDealer = dealers.find(d => d.id === activeDealerId) || null;

  /** True cuando el contexto ActingAs ya leyó localStorage. Para org users evita fetch con dealer=null antes de hidratar. */
  const hasHydrated = actingAs?.hasHydrated ?? true;

  return {
    activeDealerId,
    activeDealer,
    setActiveDealerId,
    isLoading: dealersLoading,
    hasDealers: dealers.length > 0,
    dealers,
    hasHydrated,
  };
}
