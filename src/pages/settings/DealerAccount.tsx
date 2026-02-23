/**
 * Dealer Account - Portal area for Dealer Manager only.
 * Tabs: Dealer Users | Terms & Conditions.
 * Only Dealer Manager can access; Dealer Member has no access (menu hidden).
 * Proposals are already scoped by dealer_id (RLS + useProposals).
 */

import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useOrganizationContext } from '../../context/OrganizationContext';
import DealerUsers from './DealerUsers';
import DealerTermsTab from './DealerTermsTab';

export default function DealerAccount() {
  const { registerSubmodules } = useSubmoduleNav();
  const { userType, portalRole, portalDealerId } = useAccessContext();
  const { activeOrganizationId } = useOrganizationContext();
  const currentRoute = router.getCurrentRoute() || window.location.pathname;
  const isTermsRoute = currentRoute.includes('/settings/dealer-account/terms');
  const isDealerManager = portalRole === 'dealer_manager';

  // Solo Dealer Manager puede acceder; Member se redirige
  if (userType === 'portal' && !isDealerManager) {
    return (
      <div className="py-6 px-6">
        <div className="bg-amber-50 border border-amber-200 rounded-lg p-4">
          <p className="text-sm text-amber-800 font-medium">Access restricted</p>
          <p className="text-sm text-amber-700 mt-1">Only Dealer Managers can access Dealer Account settings.</p>
          <button
            type="button"
            onClick={() => router.navigate('/')}
            className="mt-2 text-sm text-amber-700 underline"
          >
            Go to dashboard
          </button>
        </div>
      </div>
    );
  }

  useEffect(() => {
    const tabs: { id: string; label: string; href: string }[] = [
      { id: 'dealer-users', label: 'Dealer Users', href: '/settings/dealer-account' },
    ];
    if (isDealerManager) {
      tabs.push({ id: 'terms', label: 'Terms & Conditions', href: '/settings/dealer-account/terms' });
    }
    registerSubmodules('Dealer Account', tabs);
  }, [registerSubmodules, isDealerManager]);

  // Terms tab: only for Dealer Manager, need dealer ID
  if (isTermsRoute) {
    if (!isDealerManager) {
      return (
        <div className="py-6 px-6">
          <div className="bg-amber-50 border border-amber-200 rounded-lg p-4">
            <p className="text-sm text-amber-800">Only Dealer Managers can manage Terms & Conditions.</p>
            <button
              type="button"
              onClick={() => router.navigate('/settings/dealer-account')}
              className="mt-2 text-sm text-amber-700 underline"
            >
              Back to Dealer Users
            </button>
          </div>
        </div>
      );
    }
    if (!portalDealerId || !activeOrganizationId) {
      return (
        <div className="py-6 px-6">
          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
            <p className="text-sm text-yellow-800">Dealer context is required. Please contact your administrator.</p>
          </div>
        </div>
      );
    }
    return (
      <div className="py-6 px-6">
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <DealerTermsTab dealerId={portalDealerId} mode="dealerSelf" />
        </div>
      </div>
    );
  }

  return <DealerUsers />;
}
