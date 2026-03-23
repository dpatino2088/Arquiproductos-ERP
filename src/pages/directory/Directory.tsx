import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import DirectoryContacts from './Contacts';
import DirectoryCustomers from './Customers';
import { usePermissions } from '../../hooks/usePermissions';
import { router } from '../../lib/router';

export type DirectoryTab = 'contacts' | 'customers';

type Props = {
  activeTab: DirectoryTab;
};

/**
 * Directory module wrapper: renders both Contacts and Customers so tabs never unmount.
 * Eliminates flash when switching between Contacts and Customers — same layout, persistent data.
 */
export default function Directory({ activeTab }: Props) {
  const { registerSubmodules } = useSubmoduleNav();
  const { can, loading } = usePermissions();
  const canViewCustomers = can('directory.customers.read');
  const canViewContacts = can('directory.contacts.read');
  const visibleTabs = [
    canViewCustomers ? { id: 'customers', label: 'Customers', href: '/directory/customers' } : null,
    canViewContacts ? { id: 'contacts', label: 'Contacts', href: '/directory/contacts' } : null,
  ].filter(Boolean) as Array<{ id: string; label: string; href: string }>;
  const canViewDirectory = visibleTabs.length > 0;

  useEffect(() => {
    if (loading) return;
    if (!canViewDirectory) {
      router.navigate('/dashboard', false);
      return;
    }
    registerSubmodules('Directory', visibleTabs);
    const currentPath = window.location.pathname;
    const activePath = activeTab === 'customers' ? '/directory/customers' : '/directory/contacts';
    if (
      currentPath === '/directory' ||
      currentPath === '/directory/' ||
      !visibleTabs.some((tab) => tab.href === activePath)
    ) {
      router.navigate(visibleTabs[0].href, false);
    }
  }, [registerSubmodules, canViewDirectory, visibleTabs, loading, activeTab]);

  // Sin key en los paneles: evita remount al cambiar tab (culpable #1 del "segundo load").
  return (
    <>
      <div style={{ display: activeTab === 'contacts' ? undefined : 'none' }}>
        <DirectoryContacts />
      </div>
      <div style={{ display: activeTab === 'customers' ? undefined : 'none' }}>
        <DirectoryCustomers />
      </div>
    </>
  );
}
