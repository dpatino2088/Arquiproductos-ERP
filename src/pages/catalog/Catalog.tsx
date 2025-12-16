import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Book, Package, Building2, FolderTree, Palette } from 'lucide-react';

export default function Catalog() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Only register Catalog submodules if we're actually in the Catalog module
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/catalog')) {
      registerSubmodules('Catalog', [
        { id: 'items', label: 'Items', href: '/catalog/items', icon: Package },
        { id: 'manufacturers', label: 'Manufacturers', href: '/catalog/manufacturers', icon: Building2 },
        { id: 'categories', label: 'Categories', href: '/catalog/categories', icon: FolderTree },
        { id: 'collections', label: 'Collections', href: '/catalog/collections', icon: Book },
        { id: 'variants', label: 'Variants', href: '/catalog/variants', icon: Palette },
      ]);
      
      // Only redirect to items if we're at the base /catalog route
      if (currentPath === '/catalog' || currentPath === '/catalog/') {
        router.navigate('/catalog/items');
      }
    }
  }, [registerSubmodules]);

  return null;
}

