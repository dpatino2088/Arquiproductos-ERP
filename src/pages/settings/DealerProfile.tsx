import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import DealerList from './DealerList';
import DealerProfileForm from './DealerProfileForm';

export default function DealerProfile() {
  const { registerSubmodules } = useSubmoduleNav();
  const currentRoute = router.getCurrentRoute() || window.location.pathname;

  // Single submodule: Dealer List (user management is inside Dealer Detail)
  useEffect(() => {
    registerSubmodules('Settings', [
      { id: 'dealer-list', label: 'Dealer List', href: '/settings/dealer-profile' },
    ]);
  }, [registerSubmodules]);

  // New or edit dealer: show form. Otherwise show list (no tabs).
  if (currentRoute.includes('/settings/dealer-profile/new') || currentRoute.match(/\/settings\/dealer-profile\/edit\//)) {
    return <DealerProfileForm />;
  }

  return <DealerList />;
}
