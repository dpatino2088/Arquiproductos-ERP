import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';

export default function Manufacturing() {
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();

  useEffect(() => {
    const currentPath = window.location.pathname;
    
    if (currentPath.startsWith('/manufacturing')) {
      // Register submodules without clearing first (let individual components handle it)
      // This ensures tabs are visible when navigating directly to sub-routes
      registerSubmodules('Manufacturing', [
        { id: 'order-list', label: 'Order List', href: '/manufacturing/order-list' },
        { id: 'manufacturing-orders', label: 'Manufacturing Orders', href: '/manufacturing/manufacturing-orders' },
        { id: 'material', label: 'Material', href: '/manufacturing/material' },
      ]);
      
      // Redirect to Order List (first tab) when entering Manufacturing module
      if (currentPath === '/manufacturing' || currentPath === '/manufacturing/') {
        router.navigate('/manufacturing/order-list');
      }
    }
    
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/manufacturing')) {
        clearSubmoduleNav();
      }
    };
  }, [registerSubmodules, clearSubmoduleNav]);

  return null;
}
