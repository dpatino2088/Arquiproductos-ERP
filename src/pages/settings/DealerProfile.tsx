import { useEffect, useState } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import DealerList from './DealerList';
import DealerProfileForm from './DealerProfileForm';
import DealerUser from './DealerUser';

export default function DealerProfile() {
  const { registerSubmodules, tabs: submoduleTabs } = useSubmoduleNav();
  const currentRoute = router.getCurrentRoute() || window.location.pathname;
  const [activeTab, setActiveTab] = useState<'list' | 'user'>('list');

  // Register tabs for Dealer Profile module (similar to Directory)
  useEffect(() => {
    registerSubmodules('Settings', [
      { id: 'dealer-list', label: 'Dealer List', href: '/settings/dealer-profile' },
      { id: 'dealer-user', label: 'Dealer User', href: '/settings/dealer-profile/user' },
    ]);
  }, [registerSubmodules]);

  // Determine active tab from route
  useEffect(() => {
    if (currentRoute.includes('/settings/dealer-profile/user')) {
      setActiveTab('user');
    } else {
      setActiveTab('list');
    }
  }, [currentRoute]);

  // Determine what to render based on route
  // If it's a new/edit form, show DealerProfileForm (no tabs shown)
  if (currentRoute.includes('/settings/dealer-profile/new') || currentRoute.match(/\/settings\/dealer-profile\/edit\//)) {
    return <DealerProfileForm />;
  }

  // Render tabs and content
  return (
    <div>
      {/* Tabs Bar - Similar to Directory */}
      <div 
        className="border-b mb-4"
        style={{
          height: '2.625rem',
          backgroundColor: 'var(--gray-100)',
          borderColor: 'var(--gray-250)'
        }}
      >
        <div className="flex items-stretch h-full" role="tablist">
          <button
            onClick={() => router.navigate('/settings/dealer-profile')}
            className={`transition-colors flex items-center justify-start border-r ${
              activeTab === 'list'
                ? 'bg-white font-semibold'
                : 'hover:bg-white/50 font-normal'
            }`}
            style={{
              fontSize: '12px',
              padding: '0 48px',
              height: '100%',
              minWidth: '140px',
              width: 'auto',
              color: 'var(--graphite-black-hex)',
              borderColor: 'var(--gray-250)',
              borderBottom: activeTab === 'list' ? '2px solid var(--tab-active-underline)' : 'none'
            }}
            role="tab"
            aria-selected={activeTab === 'list'}
          >
            Dealer List
          </button>
          <button
            onClick={() => router.navigate('/settings/dealer-profile/user')}
            className={`transition-colors flex items-center justify-start ${
              activeTab === 'user'
                ? 'bg-white font-semibold'
                : 'hover:bg-white/50 font-normal'
            }`}
            style={{
              fontSize: '12px',
              padding: '0 48px',
              height: '100%',
              minWidth: '140px',
              width: 'auto',
              color: 'var(--graphite-black-hex)',
              borderBottom: activeTab === 'user' ? '2px solid var(--tab-active-underline)' : 'none'
            }}
            role="tab"
            aria-selected={activeTab === 'user'}
          >
            Dealer User
          </button>
        </div>
      </div>

      {/* Content based on active tab */}
      {activeTab === 'user' ? <DealerUser /> : <DealerList />}
    </div>
  );
}
