import { useEffect } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useActiveDealer } from '../../hooks/useActiveDealer';
import { useAccessContext } from '../../hooks/useAccessContext';
import { buildCatalogScopeKey } from '../../lib/catalogScopeKey';
import { catalogItemsListKey } from '../../lib/queryKeys';
import { warmModuleQueries } from '../../lib/warmModuleQueries';
import { fetchCatalogItemsList } from '../../lib/catalogListFetchers';
import { supabase } from '../../lib/supabase/client';
import { Package, Wrench } from 'lucide-react';
import Items from './Items';
import BOM from './BOM';

export type CatalogTab = 'items' | 'bom';

type Props = {
  activeTab: CatalogTab;
};

/**
 * Catalog module: tabs always mounted (hidden vs visible) so state and cache persist.
 * Warm cache with ensureQueryData for items list on mount and scope change.
 */
export default function CatalogModule({ activeTab }: Props) {
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const queryClient = useQueryClient();
  const { activeOrganizationId } = useOrganizationContext();
  const { activeDealerId, hasHydrated } = useActiveDealer();
  const { userType } = useAccessContext();

  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/catalog')) {
      registerSubmodules('Catalog', [
        { id: 'items', label: 'Items', href: '/catalog/items', icon: Package },
        { id: 'bom', label: 'BOM', href: '/catalog/bom', icon: Wrench },
      ]);
      if (currentPath === '/catalog' || currentPath === '/catalog/') {
        router.navigate('/catalog/items');
      }
    } else {
      clearSubmoduleNav();
    }
    return () => {
      if (!window.location.pathname.startsWith('/catalog')) clearSubmoduleNav();
    };
  }, [registerSubmodules, clearSubmoduleNav]);

  useEffect(() => {
    if (!activeOrganizationId || (userType === 'internal' && !hasHydrated)) return;
    const scopeKey = buildCatalogScopeKey({
      orgId: activeOrganizationId,
      activeDealerId: activeDealerId ?? null,
      userRole: userType,
    });
    const filtersStable = { q: '', categoryId: '', status: 'all', sortKey: 'sku', page: 1, pageSize: 500 };
    warmModuleQueries(queryClient, [
      {
        queryKey: catalogItemsListKey(scopeKey, filtersStable),
        queryFn: () => fetchCatalogItemsList(supabase, { orgId: activeOrganizationId, filters: filtersStable }),
      },
    ]);
  }, [queryClient, activeOrganizationId, activeDealerId, userType, hasHydrated]);

  return (
    <>
      <div hidden={activeTab !== 'items'} aria-hidden={activeTab !== 'items'}>
        <Items />
      </div>
      <div hidden={activeTab !== 'bom'} aria-hidden={activeTab !== 'bom'}>
        <BOM />
      </div>
    </>
  );
}
