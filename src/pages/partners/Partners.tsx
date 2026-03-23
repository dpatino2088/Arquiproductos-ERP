import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { router } from '../../lib/router';
import { Building, Store, Building2 } from 'lucide-react';
import { usePermissions } from '../../hooks/usePermissions';

const PARTNERS_SUBMODULES = [
  { id: 'dealers', label: 'Dealers', href: '/partners/dealers', icon: Building },
  { id: 'vendors', label: 'Vendors', href: '/partners/vendors', icon: Store },
  { id: 'manufacturers', label: 'Manufacturers', href: '/partners/manufacturers', icon: Building2 },
];

export default function Partners() {
  const { registerSubmodules } = useSubmoduleNav();
  const { can } = usePermissions();
  const canViewPartners = can('partners.read') || can('settings.read');

  useEffect(() => {
    if (!canViewPartners) {
      router.navigate('/', false);
      return;
    }
    registerSubmodules('Partners', PARTNERS_SUBMODULES);
    router.navigate('/partners/dealers');
  }, [registerSubmodules, canViewPartners]);

  return null;
}
