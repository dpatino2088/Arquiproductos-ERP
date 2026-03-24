import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useActiveDealer } from '../../hooks/useActiveDealer';
import DealerAccountDetail from './DealerAccountDetail';
import { isMyFinancialsPath } from './myFinancialsRoute';

export default function FinancialStatement() {
  const { isPortal, portalDealerId } = useAccessContext();
  const { activeDealerId } = useActiveDealer();
  const pathname = window.location.pathname;
  const myFinancialsMode = isMyFinancialsPath(pathname);
  const viewerMode = isPortal || myFinancialsMode;
  const dealerId = portalDealerId ?? activeDealerId ?? null;

  useEffect(() => {
    // Avoid render-time navigate loops and keep Financial Statement in canonical routes.
    if (!viewerMode) {
      router.navigate('/financials/accounts', false);
      return;
    }
    if (!myFinancialsMode) {
      router.navigate('/my-financials/statement', false);
    }
  }, [viewerMode, myFinancialsMode]);

  if (!viewerMode || !myFinancialsMode) return null;

  if (!dealerId) {
    return (
      <div className="p-6">
        <div className="rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-700">
          Select a dealer first to open `My Financials` statement.
        </div>
      </div>
    );
  }

  return <DealerAccountDetail dealerIdOverride={dealerId} />;
}
