import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { router } from '../../lib/router';
import { getFirstAllowedFinancialRoute, getVisibleFinancialGroupTabs, getVisiblePortalFinancialSubTabs } from './financialSubmodules';
import { usePermissions } from '../../hooks/usePermissions';
import { useAccessContext } from '../../hooks/useAccessContext';
import { getFinancialBasePath, isMyFinancialsPath } from './myFinancialsRoute';

export default function Financials() {
  const { registerSubmodules } = useSubmoduleNav();
  const { can, loading } = usePermissions();
  const { isPortal, portalRole } = useAccessContext();
  const pathname = window.location.pathname;
  const myFinancialsMode = isMyFinancialsPath(pathname);
  const viewerMode = isPortal || myFinancialsMode;
  const basePath = getFinancialBasePath(pathname);
  const visibleGroupTabs = getVisibleFinancialGroupTabs(can);
  const firstAllowedRoute = getFirstAllowedFinancialRoute(can);
  const portalSubTabs = getVisiblePortalFinancialSubTabs(can, portalRole, basePath);
  const canViewFinancials = viewerMode ? !!portalSubTabs[0] : !!firstAllowedRoute;

  useEffect(() => {
    if (loading) return;
    if (!canViewFinancials) {
      router.navigate('/dashboard');
      return;
    }
    if (viewerMode) {
      registerSubmodules('Financials', portalSubTabs.map((tab) => ({ id: tab.id, label: tab.label, href: tab.href })));
      router.navigate(portalSubTabs[0].href, false);
      return;
    }
    registerSubmodules('Financials', visibleGroupTabs);
    router.navigate(firstAllowedRoute!, false);
  }, [
    registerSubmodules,
    canViewFinancials,
    loading,
    visibleGroupTabs,
    firstAllowedRoute,
    viewerMode,
    basePath,
    portalSubTabs,
  ]);

  return null;
}

