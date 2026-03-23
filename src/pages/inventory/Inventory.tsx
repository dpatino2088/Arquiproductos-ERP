import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Package, Warehouse, ShoppingCart, Receipt, ArrowLeftRight, Settings } from 'lucide-react';
import { usePermissions } from '../../hooks/usePermissions';

export default function Inventory() {
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const { can, loading } = usePermissions();
  const inventoryTabs = [
    { id: 'warehouse', label: 'Warehouse', href: '/inventory/warehouse', icon: Warehouse, allowed: can('inventory.warehouse.read') },
    { id: 'purchase-orders', label: 'Purchase Orders', href: '/inventory/purchase-orders', icon: ShoppingCart, allowed: can('inventory.purchase_orders.read') },
    { id: 'receipts', label: 'Receipts', href: '/inventory/receipts', icon: Receipt, allowed: can('inventory.receipts.read') },
    { id: 'transactions', label: 'Transactions', href: '/inventory/transactions', icon: ArrowLeftRight, allowed: can('inventory.transactions.read') },
    { id: 'adjustments', label: 'Adjustments', href: '/inventory/adjustments', icon: Settings, allowed: can('inventory.adjustments.read') },
    { id: 'material-demand', label: 'Material Demand', href: '/inventory/material-demand', icon: Package, allowed: can('inventory.material_demand.read') },
  ];
  const visibleTabs = inventoryTabs.filter((tab) => tab.allowed).map(({ allowed, ...tab }) => tab);
  const canViewInventory = visibleTabs.length > 0;

  useEffect(() => {
    if (loading) return;
    if (!canViewInventory) {
      router.navigate('/dashboard', false);
      return;
    }
    // Only register Inventory submodules if we're actually in the Inventory module
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/inventory')) {
      registerSubmodules('Inventory', visibleTabs);
      
      // Redirect to warehouse by default
      if (currentPath === '/inventory' || currentPath === '/inventory/') {
        router.navigate(visibleTabs[0].href);
        return;
      }
      const activeAllowed = visibleTabs.some((tab) => currentPath.startsWith(tab.href));
      if (!activeAllowed) {
        router.navigate(visibleTabs[0].href);
        return;
      }
    }
    
    // Cleanup: clear submodules when component unmounts or path changes
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/inventory')) {
        // Only clear if we're leaving the Inventory module
        clearSubmoduleNav();
      }
    };
  }, [registerSubmodules, clearSubmoduleNav, canViewInventory, loading, visibleTabs]);

  return null;
}

