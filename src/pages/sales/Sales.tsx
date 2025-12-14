import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { ShoppingBag, FileText } from 'lucide-react';

export default function Sales() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Sales', [
      { id: 'quotes', label: 'Quotes', href: '/sales/quotes', icon: FileText },
      { id: 'orders', label: 'Orders', href: '/sales/orders', icon: ShoppingBag },
    ]);
    
    // Redirect to quotes by default (as per user request)
    const currentPath = window.location.pathname;
    if (currentPath === '/sales') {
      router.navigate('/sales/quotes');
    }
  }, [registerSubmodules]);

  return null;
}

