import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Wrench, FileText, ClipboardList, Layers, Settings, Factory } from 'lucide-react';

export default function Manufacturing() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Manufacturing', [
      { id: 'production-orders', label: 'Production Orders', href: '/manufacturing/production-orders', icon: FileText },
      { id: 'work-orders', label: 'Work Orders', href: '/manufacturing/work-orders', icon: ClipboardList },
      { id: 'bill-of-materials', label: 'Bill of Materials', href: '/manufacturing/bill-of-materials', icon: Layers },
      { id: 'routing', label: 'Routing', href: '/manufacturing/routing', icon: Settings },
      { id: 'work-centers', label: 'Work Centers', href: '/manufacturing/work-centers', icon: Factory },
    ]);
    
    // Redirect to production orders by default
    router.navigate('/manufacturing/production-orders');
  }, [registerSubmodules]);

  return null;
}

