import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import DirectoryContacts from './Contacts';
import DirectoryCustomers from './Customers';

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

  useEffect(() => {
    registerSubmodules('Directory', [
      { id: 'contacts', label: 'Contacts', href: '/directory/contacts' },
      { id: 'customers', label: 'Customers', href: '/directory/customers' },
    ]);
  }, [registerSubmodules]);

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
