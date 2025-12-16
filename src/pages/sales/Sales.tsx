import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { ShoppingBag, FileText } from 'lucide-react';

export default function Sales() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Only register Sales submodules if we're actually in the Sales module
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/sales')) {
      registerSubmodules('Sales', [
        { id: 'quotes', label: 'Quotes', href: '/sales/quotes', icon: FileText },
        { id: 'orders', label: 'Orders', href: '/sales/orders', icon: ShoppingBag },
      ]);
      
      // Redirect to quotes by default (as per user request)
      if (currentPath === '/sales' || currentPath === '/sales/') {
        router.navigate('/sales/quotes');
      }
    }
  }, [registerSubmodules]);

  return null;
}

