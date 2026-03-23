import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { router } from '../../lib/router';
import { FINANCIAL_GROUP_TABS } from './financialSubmodules';
import { usePermissions } from '../../hooks/usePermissions';

export default function Financials() {
  const { registerSubmodules } = useSubmoduleNav();
  const { can, loading } = usePermissions();
  const canViewFinancials = can('financials.read') || can('financials.write');

  useEffect(() => {
    if (loading) return;
    if (!canViewFinancials) {
      router.navigate('/dashboard');
      return;
    }
    registerSubmodules('Financials', FINANCIAL_GROUP_TABS);
    router.navigate('/financials/accounts');
  }, [registerSubmodules, canViewFinancials, loading]);

  return null;
}

