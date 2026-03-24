import { useEffect } from 'react';
import { Home } from 'lucide-react';
import { useSubmoduleNav } from '../hooks/useSubmoduleNav';
import { useCurrentOrgRole } from '../hooks/useCurrentOrgRole';
import CommercialDashboard from './dashboard/CommercialDashboard';
import ProcurementDashboard from './dashboard/ProcurementDashboard';
import ManufacturingDashboard from './dashboard/ManufacturingDashboard';
import FinanceDashboard from './dashboard/FinanceDashboard';

const OPERATOR_ROLES = ['operator', 'operator_admin', 'operator_member'];

export default function ManagementDashboard() {
  const { registerSubmodules } = useSubmoduleNav();
  const { role } = useCurrentOrgRole();

  useEffect(() => {
    registerSubmodules('Management Dashboard', [
      { id: 'dashboard', label: 'Dashboard', href: '/dashboard', icon: Home },
    ]);
  }, [registerSubmodules]);

  useEffect(() => {
    window.scrollTo({ top: 0, behavior: 'smooth' });
    const mainElement = document.querySelector('main[role="main"]');
    if (mainElement) mainElement.scrollTop = 0;
    if (document.activeElement instanceof HTMLElement) document.activeElement.blur();
  }, []);

  if (role === 'procurement') return <ProcurementDashboard />;
  if (role && OPERATOR_ROLES.includes(role)) return <ManufacturingDashboard />;
  if (role === 'finance') return <FinanceDashboard />;

  return <CommercialDashboard />;
}
