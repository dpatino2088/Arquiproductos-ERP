import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { FileText, DollarSign, Building2 } from 'lucide-react';
import { router } from '../../lib/router';

const FINANCIAL_SUBMODULES = [
  { id: 'accounts', label: 'Accounts', href: '/financials/accounts', icon: Building2 },
  { id: 'invoices', label: 'Invoices', href: '/financials/invoices', icon: FileText },
  { id: 'payments', label: 'Payments', href: '/financials/payments', icon: DollarSign },
];

export default function Financials() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Financials', FINANCIAL_SUBMODULES);
    // Default redirect to invoices
    router.navigate('/financials/accounts');
  }, [registerSubmodules]);

  return null;
}

