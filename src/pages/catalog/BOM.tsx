import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Package, Wrench, CheckCircle } from 'lucide-react';
import BOMTemplates from './BOMTemplates';

export default function BOM() {
  const { registerSubmodules } = useSubmoduleNav();

  // Ensure submodules are registered when BOM page loads
  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/catalog')) {
      registerSubmodules('Catalog', [
        { id: 'items', label: 'Items', href: '/catalog/items', icon: Package },
        { id: 'bom', label: 'BOM', href: '/catalog/bom', icon: Wrench },
        { id: 'bom-readiness', label: 'BOM Readiness', href: '/catalog/bom-readiness', icon: CheckCircle },
      ]);
    }
  }, [registerSubmodules]);

  return <BOMTemplates />;
}

