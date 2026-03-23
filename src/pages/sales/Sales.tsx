import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { usePermissions } from '../../hooks/usePermissions';

export default function Sales() {
  const { clearSubmoduleNav } = useSubmoduleNav();
  const { can, loading } = usePermissions();
  const salesRoutes = [
    { href: '/sales/quotes', allowed: can('sales.quotes.read') },
    { href: '/sales/proposals', allowed: can('sales.proposals.read') },
    { href: '/sales/orders', allowed: can('sales.orders.read') },
  ];
  const firstAllowedRoute = salesRoutes.find((route) => route.allowed)?.href ?? null;
  const canViewSales = !!firstAllowedRoute;

  useEffect(() => {
    if (loading) return;
    if (!canViewSales) {
      router.navigate('/dashboard', false);
      return;
    }
    // Sales component is only rendered for /sales route
    // Submodules are registered by Quotes.tsx and Proposals.tsx
    // Just clear submodules when leaving the sales module
    const currentPath = window.location.pathname;
    if (currentPath === '/sales' || currentPath === '/sales/') {
      router.navigate(firstAllowedRoute!, false);
      return;
    }
    const activeAllowed = salesRoutes.some((route) => route.allowed && currentPath.startsWith(route.href));
    if (!activeAllowed) {
      router.navigate(firstAllowedRoute!, false);
      return;
    }
    
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/sales')) {
        clearSubmoduleNav();
      }
    };
  }, [clearSubmoduleNav, canViewSales, loading, firstAllowedRoute, salesRoutes]);

  return null;
}

