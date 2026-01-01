import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Package, Wrench, CheckCircle } from 'lucide-react';

export default function Catalog() {
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();

  useEffect(() => {
    // Register Catalog submodules whenever we're in the Catalog module
    const currentPath = window.location.pathname;
    
    if (currentPath.startsWith('/catalog')) {
      // Register Catalog sub-modules
      registerSubmodules('Catalog', [
        { id: 'items', label: 'Items', href: '/catalog/items', icon: Package },
        { id: 'bom', label: 'BOM', href: '/catalog/bom', icon: Wrench },
        { id: 'bom-readiness', label: 'BOM Readiness', href: '/catalog/bom-readiness', icon: CheckCircle },
      ]);
      
      // Only redirect to items if we're at the base /catalog route
      if (currentPath === '/catalog' || currentPath === '/catalog/') {
        router.navigate('/catalog/items');
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
  }, [registerSubmodules, clearSubmoduleNav]);

  return null;
}

