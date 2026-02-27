import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import DealerList from './DealerList';
import DealerProfileForm from './DealerProfileForm';

interface DealerProfileProps {
  basePath?: string;
  moduleLabel?: string;
  skipSubmoduleRegistration?: boolean;
  /** List section title (e.g. "Accounts"). Default "Dealer List". */
  listSectionTitle?: string;
  /** Hide the dealer list top header bar (title + subtitle + Add Dealer). */
  listHideSectionHeader?: boolean;
}

export default function DealerProfile({ basePath = '/settings/dealer-profile', moduleLabel = 'Settings', skipSubmoduleRegistration = false, listSectionTitle = 'Accounts', listHideSectionHeader = false }: DealerProfileProps) {
  const { registerSubmodules } = useSubmoduleNav();
  const currentRoute = router.getCurrentRoute() || window.location.pathname;

  useEffect(() => {
    if (skipSubmoduleRegistration) return;
    registerSubmodules(moduleLabel, [
      { id: 'dealer-list', label: 'Dealer List', href: basePath },
    ]);
  }, [registerSubmodules, moduleLabel, basePath, skipSubmoduleRegistration]);

  if (currentRoute.includes(`${basePath}/new`) || currentRoute.match(new RegExp(`${basePath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}/edit/`))) {
    return <DealerProfileForm basePath={basePath} />;
  }

  return (
    <DealerList
      basePath={basePath}
      moduleLabel={moduleLabel}
      skipSubmoduleRegistration={skipSubmoduleRegistration}
      sectionTitle={listSectionTitle}
      hideSectionHeader={listHideSectionHeader}
    />
  );
}
