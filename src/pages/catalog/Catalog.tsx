import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Book, Package } from 'lucide-react';

export default function Catalog() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Catalog', [
      { id: 'items', label: 'Items', href: '/catalog/items', icon: Package },
      { id: 'collections', label: 'Collections', href: '/catalog/collections', icon: Book },
    ]);
    
    // Redirect to items by default
    router.navigate('/catalog/items');
  }, [registerSubmodules]);

  return null;
}

