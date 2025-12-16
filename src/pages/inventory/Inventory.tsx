import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Package, Warehouse, ShoppingCart, Receipt, ArrowLeftRight, Settings } from 'lucide-react';

export default function Inventory() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Only register Inventory submodules if we're actually in the Inventory module
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/inventory')) {
      registerSubmodules('Inventory', [
        { id: 'warehouse', label: 'Warehouse', href: '/inventory/warehouse', icon: Warehouse },
        { id: 'purchase-orders', label: 'Purchase Orders', href: '/inventory/purchase-orders', icon: ShoppingCart },
        { id: 'receipts', label: 'Receipts', href: '/inventory/receipts', icon: Receipt },
        { id: 'transactions', label: 'Transactions', href: '/inventory/transactions', icon: ArrowLeftRight },
        { id: 'adjustments', label: 'Adjustments', href: '/inventory/adjustments', icon: Settings },
      ]);
      
      // Redirect to warehouse by default
      if (currentPath === '/inventory' || currentPath === '/inventory/') {
        router.navigate('/inventory/warehouse');
      }
    }
  }, [registerSubmodules]);

  return null;
}

