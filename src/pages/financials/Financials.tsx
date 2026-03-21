import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { router } from '../../lib/router';
import { FINANCIAL_GROUP_TABS } from './financialSubmodules';

export default function Financials() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Financials', FINANCIAL_GROUP_TABS);
    router.navigate('/financials/accounts');
  }, [registerSubmodules]);

  return null;
}

