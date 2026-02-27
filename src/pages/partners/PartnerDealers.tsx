import { useEffect, useState, useRef } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { router } from '../../lib/router';
import { Building, Store, Building2, Plus } from 'lucide-react';
import DealerProfile from '../settings/DealerProfile';
import DealerUsers, { type DealerUsersRef } from '../settings/DealerUsers';
import StatusTabs from '../../components/shared/StatusTabs';
import PartnerDealerUserForm from './PartnerDealerUserForm';

const PARTNERS_SUBMODULES = [
  { id: 'dealers', label: 'Dealers', href: '/partners/dealers', icon: Building },
  { id: 'vendors', label: 'Vendors', href: '/partners/vendors', icon: Store },
  { id: 'manufacturers', label: 'Manufacturers', href: '/partners/manufacturers', icon: Building2 },
];

const DEALER_TABS = [
  { label: 'Dealers', value: 'dealers', count: 0 },
  { label: 'Dealer Users', value: 'dealer-users', count: 0 },
];

export default function PartnerDealers() {
  const { registerSubmodules } = useSubmoduleNav();
  const [activeTab, setActiveTab] = useState('dealers');
  const [currentRoute, setCurrentRoute] = useState(() => router.getCurrentRoute() || window.location.pathname);
  const dealerUsersRef = useRef<DealerUsersRef>(null);

  useEffect(() => {
    registerSubmodules('Partners', PARTNERS_SUBMODULES);
  }, [registerSubmodules]);

  useEffect(() => {
    const update = () => setCurrentRoute(router.getCurrentRoute() || window.location.pathname);
    const remove = router.addListener(update);
    return () => {
      remove();
    };
  }, []);

  const isDealerFormRoute = currentRoute.includes('/partners/dealers/new') ||
    currentRoute.includes('/partners/dealers/edit/');

  const isDealerUserFormRoute = currentRoute.includes('/partners/dealer-users/new') ||
    currentRoute.includes('/partners/dealer-users/edit/');

  if (isDealerFormRoute) {
    return <DealerProfile basePath="/partners/dealers" moduleLabel="Partners" skipSubmoduleRegistration />;
  }

  if (isDealerUserFormRoute) {
    const editMatch = currentRoute.match(/\/partners\/dealer-users\/edit\/([^/]+)/);
    const dealerUserId = editMatch?.[1] ?? null;
    return <PartnerDealerUserForm dealerUserId={dealerUserId} />;
  }

  return (
    <div className="py-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Dealers</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Manage dealer accounts and their users
          </p>
        </div>
        {activeTab === 'dealers' && (
          <button
            onClick={() => router.navigate('/partners/dealers/new')}
            className="flex items-center gap-2 px-2 py-1 rounded text-white text-sm hover:opacity-90"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            <Plus style={{ width: '14px', height: '14px' }} />
            Add Dealer
          </button>
        )}
        {activeTab === 'dealer-users' && (
          <button
            onClick={() => router.navigate('/partners/dealer-users/new')}
            className="flex items-center gap-2 px-2 py-1 rounded text-white text-sm hover:opacity-90"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            <Plus style={{ width: '14px', height: '14px' }} />
            Add Dealer User
          </button>
        )}
      </div>

      <StatusTabs tabs={DEALER_TABS} activeTab={activeTab} onChange={setActiveTab} />

      <div style={{ display: activeTab === 'dealers' ? undefined : 'none' }}>
        <DealerProfile
          basePath="/partners/dealers"
          moduleLabel="Partners"
          skipSubmoduleRegistration
          listSectionTitle="Accounts"
          listHideSectionHeader
        />
      </div>
      <div style={{ display: activeTab === 'dealer-users' ? undefined : 'none' }}>
        <DealerUsers ref={dealerUsersRef} hideSectionHeader useInlineEdit />
      </div>
    </div>
  );
}
