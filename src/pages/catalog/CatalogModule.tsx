import { useEffect } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useActiveDealer } from '../../hooks/useActiveDealer';
import { useAccessContext } from '../../hooks/useAccessContext';
import { usePermissions } from '../../hooks/usePermissions';
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
  const { can } = usePermissions();
  const canViewItems = can('catalog.items.read') || can('catalog.read') || can('catalog.write');
  const canViewBOM = can('catalog.bom.read') || can('catalog.bom.write') || can('catalog.write');

  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/catalog')) {
      const tabs = [
        ...(canViewItems ? [{ id: 'items', label: 'Items', href: '/catalog/items', icon: Package }] : []),
        ...(canViewBOM ? [{ id: 'bom', label: 'BOM', href: '/catalog/bom', icon: Wrench }] : []),
      ];
      registerSubmodules('Catalog', tabs);
      if (currentPath === '/catalog' || currentPath === '/catalog/') {
        if (canViewItems) router.navigate('/catalog/items');
        else if (canViewBOM) router.navigate('/catalog/bom');
      } else if (currentPath.startsWith('/catalog/bom') && !canViewBOM) {
        if (canViewItems) router.navigate('/catalog/items');
      } else if (currentPath.startsWith('/catalog/items') && !canViewItems) {
        if (canViewBOM) router.navigate('/catalog/bom');
      }
    } else {
      clearSubmoduleNav();
    }
    return () => {
      if (!window.location.pathname.startsWith('/catalog')) clearSubmoduleNav();
    };
  }, [registerSubmodules, clearSubmoduleNav, canViewItems, canViewBOM]);

  useEffect(() => {
    if (!activeOrganizationId || (userType === 'internal' && !hasHydrated)) return;
    const scopeKey = buildCatalogScopeKey({
      orgId: activeOrganizationId,
      activeDealerId: activeDealerId ?? null,
      userRole: userType,
    });
    // Must match Items.tsx catalogListFilters so the warmed cache key is reused.
    const filtersStable = { q: '', categoryId: '', status: 'all', sortKey: 'sku', page: 1, pageSize: 5000 };
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
        {canViewItems ? <Items /> : null}
      </div>
      <div hidden={activeTab !== 'bom' || !canViewBOM} aria-hidden={activeTab !== 'bom' || !canViewBOM}>
        <BOM />
      </div>
    </>
  );
}
