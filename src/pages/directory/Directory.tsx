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
  const canViewDirectory = can('directory.read') || can('directory.write');

  useEffect(() => {
    if (loading) return;
    if (!canViewDirectory) {
      router.navigate('/dashboard', false);
      return;
    }
    registerSubmodules('Directory', [
      { id: 'customers', label: 'Customers', href: '/directory/customers' },
      { id: 'contacts', label: 'Contacts', href: '/directory/contacts' },
    ]);
  }, [registerSubmodules, canViewDirectory, loading]);

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
