import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { router } from '../../lib/router';
import { getFirstAllowedFinancialRoute, getVisibleFinancialGroupTabs } from './financialSubmodules';
import { usePermissions } from '../../hooks/usePermissions';

export default function Financials() {
  const { registerSubmodules } = useSubmoduleNav();
  const { can, loading } = usePermissions();
  const visibleGroupTabs = getVisibleFinancialGroupTabs(can);
  const firstAllowedRoute = getFirstAllowedFinancialRoute(can);
  const canViewFinancials = !!firstAllowedRoute;

  useEffect(() => {
    if (loading) return;
    if (!canViewFinancials) {
      router.navigate('/dashboard');
      return;
    }
    registerSubmodules('Financials', visibleGroupTabs);
    router.navigate(firstAllowedRoute!, false);
  }, [registerSubmodules, canViewFinancials, loading, visibleGroupTabs, firstAllowedRoute]);

  return null;
}

