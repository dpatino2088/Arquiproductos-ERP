import { useEffect, useMemo, useState } from 'react';
import { router } from '../../lib/router';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useActiveDealer } from '../../hooks/useActiveDealer';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useCatalogItemDetail } from '../../hooks/useCatalogItemDetail';
import { useCatalogCategories } from '../../hooks/useCatalog';
import { buildCatalogScopeKey } from '../../lib/catalogScopeKey';
import { getCatalogItemsReturnTo, getReturnToFromCurrentQuery, navigateBackContextual, resolveReturnTo, setCatalogItemsRestoreOnBack, setCatalogItemsReturnTo, withCatalogItemsRestore, withReturnTo } from '../../lib/navigation/returnTo';
import { ArrowLeft, Edit } from 'lucide-react';

interface CatalogItemDetailProps {
  itemId?: string;
}

function fmtCurrency(value?: number | null): string {
  if (value == null || Number.isNaN(Number(value))) return '-';
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(Number(value));
}

export default function CatalogItemDetail({ itemId: propItemId }: CatalogItemDetailProps) {
  const [itemId, setItemId] = useState<string | null>(propItemId ?? null);
  const [routeSearch, setRouteSearch] = useState<string>(window.location.search);
  const { activeOrganizationId } = useOrganizationContext();
  const { activeDealerId } = useActiveDealer();
  const { userType } = useAccessContext();
  const { categories } = useCatalogCategories();
  const returnToFromQuery = useMemo(() => getReturnToFromCurrentQuery(), [routeSearch]);
  const returnToFromStorage = useMemo(
    () => (itemId ? sessionStorage.getItem(`catalogItemReturnTo:${itemId}`) : null) ?? getCatalogItemsReturnTo(),
    [itemId]
  );
  const returnTo = useMemo(
    () =>
      resolveReturnTo({
        queryReturnTo: returnToFromQuery,
        storageReturnTo: returnToFromStorage,
        fallback: '/catalog/items',
      }),
    [returnToFromQuery, returnToFromStorage]
  );

  const scopeKey = useMemo(
    () =>
      buildCatalogScopeKey({
        orgId: activeOrganizationId ?? null,
        activeDealerId: activeDealerId ?? null,
        userRole: userType,
      }),
    [activeOrganizationId, activeDealerId, userType]
  );

  useEffect(() => {
    if (itemId) return;
    const path = window.location.pathname;
    const match = path.match(/\/catalog\/items\/([^/]+)/);
    if (match?.[1] && match[1] !== 'new' && match[1] !== 'edit') {
      setItemId(match[1]);
      sessionStorage.setItem('currentCatalogItemId', match[1]);
    }
  }, [itemId]);

  useEffect(() => {
    const syncSearch = () => setRouteSearch(window.location.search);
    const unsubscribe = router.addListener(syncSearch);
    window.addEventListener('popstate', syncSearch);
    return () => {
      unsubscribe();
      window.removeEventListener('popstate', syncSearch);
    };
  }, []);

  useEffect(() => {
    if (!itemId) return;
    if (returnToFromQuery) {
      sessionStorage.setItem(`catalogItemReturnTo:${itemId}`, returnToFromQuery);
    }
  }, [itemId, returnToFromQuery]);

  useEffect(() => {
    if (!returnTo.startsWith('/catalog/items')) return;
    setCatalogItemsReturnTo(returnTo);
  }, [returnTo]);

  const { data: item, isLoading, error } = useCatalogItemDetail(scopeKey, itemId, {
    orgId: activeOrganizationId ?? null,
  });

  const categoryName = useMemo(() => {
    if (!item?.category_id) return '-';
    return categories.find((c) => c.id === item.category_id)?.name ?? '-';
  }, [categories, item?.category_id]);

  if (!itemId) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-700">Catalog item ID is required.</p>
        </div>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="py-6 px-6">
        <div className="animate-pulse space-y-3">
          <div className="h-6 bg-gray-100 rounded w-1/3" />
          <div className="h-24 bg-gray-100 rounded" />
          <div className="h-24 bg-gray-100 rounded" />
        </div>
      </div>
    );
  }

  if (!item || error) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-700">Item not found.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="py-6 px-6">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div>
            <h1 className="text-xl font-semibold text-foreground">{item.name || item.sku}</h1>
            <p className="text-xs text-gray-500">Catalog item detail</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => {
              setCatalogItemsRestoreOnBack(true);
              const target = resolveReturnTo({
                queryReturnTo: returnToFromQuery,
                storageReturnTo: returnToFromStorage,
                fallback: '/catalog/items',
              });
              if (target.startsWith('/catalog/items')) {
                router.navigate(withCatalogItemsRestore(target));
                return;
              }
              navigateBackContextual(router, {
                queryReturnTo: returnToFromQuery,
                storageReturnTo: returnToFromStorage,
                fallback: '/catalog/items',
              });
            }}
            className="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50"
            aria-label="Close item detail"
          >
            <ArrowLeft className="w-4 h-4" />
            Back
          </button>
          <button
            type="button"
            onClick={() => router.navigate(withReturnTo(`/catalog/items/edit/${item.id}`, returnTo))}
            className="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90"
          >
            <Edit className="w-4 h-4" />
            Edit
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="rounded-lg border border-gray-200 bg-white p-5">
          <h2 className="text-sm font-semibold text-gray-900 mb-3">General</h2>
          <dl className="space-y-2 text-sm">
            <div className="flex justify-between"><dt className="text-gray-500">SKU</dt><dd className="font-medium">{item.sku || '-'}</dd></div>
            <div className="flex justify-between"><dt className="text-gray-500">Name</dt><dd className="font-medium">{item.name || '-'}</dd></div>
            <div className="flex justify-between"><dt className="text-gray-500">Category</dt><dd>{categoryName}</dd></div>
            <div className="flex justify-between"><dt className="text-gray-500">Measure Basis</dt><dd>{item.measure_basis || '-'}</dd></div>
            <div className="flex justify-between"><dt className="text-gray-500">Unit</dt><dd>{item.unit_of_measure || '-'}</dd></div>
            <div className="flex justify-between"><dt className="text-gray-500">Status</dt><dd>{item.is_active ? 'Active' : 'Inactive'}</dd></div>
          </dl>
        </div>

        <div className="rounded-lg border border-gray-200 bg-white p-5">
          <h2 className="text-sm font-semibold text-gray-900 mb-3">Pricing</h2>
          <dl className="space-y-2 text-sm">
            <div className="flex justify-between"><dt className="text-gray-500">Cost EXW</dt><dd>{fmtCurrency(item.cost_exw)}</dd></div>
            <div className="flex justify-between"><dt className="text-gray-500">MSRP</dt><dd>{fmtCurrency(item.msrp)}</dd></div>
          </dl>
        </div>
      </div>

      {(item.collection_name || item.variant_name || item.roll_type || item.roll_width || item.roll_width_m) && (
        <div className="rounded-lg border border-gray-200 bg-white p-5 mt-6">
          <h2 className="text-sm font-semibold text-gray-900 mb-3">Roll Details</h2>
          <dl className="grid grid-cols-1 md:grid-cols-2 gap-2 text-sm">
            <div className="flex justify-between"><dt className="text-gray-500">Collection</dt><dd>{item.collection_name || '-'}</dd></div>
            <div className="flex justify-between"><dt className="text-gray-500">Variant</dt><dd>{item.variant_name || '-'}</dd></div>
            <div className="flex justify-between"><dt className="text-gray-500">Roll Type</dt><dd>{item.roll_type || '-'}</dd></div>
            <div className="flex justify-between"><dt className="text-gray-500">Roll Width</dt><dd>{item.roll_width ?? item.roll_width_m ?? '-'}</dd></div>
          </dl>
        </div>
      )}
    </div>
  );
}

