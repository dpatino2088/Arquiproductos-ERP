import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Package, Wrench } from 'lucide-react';
import { usePermissions } from '../../hooks/usePermissions';

export default function Catalog() {
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const { can, loading } = usePermissions();
  const canViewItems = can('catalog.items.read') || can('catalog.read') || can('catalog.write');
  const canViewBOM = can('catalog.bom.read') || can('catalog.bom.write') || can('catalog.write');
  const canViewCatalog = canViewItems || canViewBOM;

  useEffect(() => {
    if (loading) return;
    if (!canViewCatalog) {
      router.navigate('/dashboard', false);
      return;
    }
    // Register Catalog submodules whenever we're in the Catalog module
    const currentPath = window.location.pathname;
    
    if (currentPath.startsWith('/catalog')) {
      const catalogTabs = [
        ...(canViewItems ? [{ id: 'items', label: 'Items', href: '/catalog/items', icon: Package }] : []),
        ...(canViewBOM ? [{ id: 'bom', label: 'BOM', href: '/catalog/bom', icon: Wrench }] : []),
      ];
      // Register Catalog sub-modules
      registerSubmodules('Catalog', catalogTabs);
      
      // Only redirect to items if we're at the base /catalog route
      if (currentPath === '/catalog' || currentPath === '/catalog/') {
        if (canViewItems) router.navigate('/catalog/items');
        else if (canViewBOM) router.navigate('/catalog/bom');
      } else if (currentPath.startsWith('/catalog/bom') && !canViewBOM) {
        if (canViewItems) router.navigate('/catalog/items');
        else router.navigate('/dashboard');
      } else if (currentPath.startsWith('/catalog/items') && !canViewItems) {
        if (canViewBOM) router.navigate('/catalog/bom');
        else router.navigate('/dashboard');
      }
    } else {
      // Clear submodules when leaving Catalog module
      clearSubmoduleNav();
    }

    // Cleanup: clear submodules when component unmounts or path changes
    return () => {
      const newPath = window.location.pathname;
      if (!newPath.startsWith('/catalog')) {
        clearSubmoduleNav();
      }
    };
  }, [registerSubmodules, clearSubmoduleNav, canViewCatalog, canViewItems, canViewBOM, loading]);

  return null;
}

