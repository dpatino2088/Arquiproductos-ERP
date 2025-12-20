import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Package, Wrench } from 'lucide-react';
import BOMTab from './BOMTab';

export default function BOM() {
  const { registerSubmodules } = useSubmoduleNav();

  // Ensure submodules are registered when BOM page loads
  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/catalog')) {
      registerSubmodules('Catalog', [
        { id: 'items', label: 'Items', href: '/catalog/items', icon: Package },
        { id: 'bom', label: 'BOM', href: '/catalog/bom', icon: Wrench },
      ]);
    }
  }, [registerSubmodules]);

  return <BOMTab />;
}

