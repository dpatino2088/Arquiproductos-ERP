import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';

export default function Sales() {
  const { clearSubmoduleNav } = useSubmoduleNav();

  useEffect(() => {
    // Sales component is only rendered for /sales route
    // Submodules are registered by Quotes.tsx and QuoteApproved.tsx
    // Just clear submodules when leaving the sales module
    const currentPath = window.location.pathname;
    if (currentPath === '/sales' || currentPath === '/sales/') {
      // Redirect to quotes by default
      router.navigate('/sales/quotes', false);
    }
    
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/sales')) {
        clearSubmoduleNav();
      }
    };
  }, [clearSubmoduleNav]);

  return null;
}

