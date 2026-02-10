import { useEffect } from 'react';
import { useCurrentOrgRole } from '../hooks/useCurrentOrgRole';
import { useActingAsContext } from '../context/ActingAsContext';
import { useDealers } from '../hooks/useDealers';
import { router } from '../lib/router';

/**
 * When user is Super Admin:
 * - If they have not chosen "Acting as", redirect to /select-acting-dealer.
 * - If they chose a dealer that no longer exists (deleted / permissions), clear and redirect again.
 */
export function SuperAdminActingGate({ children }: { children: React.ReactNode }) {
  const { isSuperAdmin } = useCurrentOrgRole();
  const actingAs = useActingAsContext();
  const { dealers, isLoading: dealersLoading } = useDealers();

  useEffect(() => {
    if (!isSuperAdmin || !actingAs) return;
    const path = router.getCurrentRoute() || window.location.pathname;
    if (path === '/select-acting-dealer') return;

    if (!actingAs.hasChosenActingAs) {
      router.navigate('/select-acting-dealer', true);
      return;
    }

    if (actingAs.activeDealerId != null && !dealersLoading) {
      const dealerStillExists = dealers.some((d) => d.id === actingAs.activeDealerId);
      if (!dealerStillExists) {
        actingAs.clearActingAs();
        router.navigate('/select-acting-dealer', true);
      }
    }
  }, [isSuperAdmin, actingAs?.hasChosenActingAs, actingAs?.activeDealerId, dealers, dealersLoading]);

  return <>{children}</>;
}
