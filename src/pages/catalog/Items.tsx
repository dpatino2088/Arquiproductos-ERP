import { useEffect, useState, useMemo, useCallback, useRef } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { router } from '../../lib/router';
import {
  CATALOG_ITEMS_LIST_STATE_KEY,
  CATALOG_ITEMS_RESTORE_ON_BACK_KEY,
  setCatalogItemsReturnTo,
  getReturnToFromCurrentQuery,
  navigateBackContextual,
  setCatalogItemsRestoreOnBack,
  withReturnTo,
} from '../../lib/navigation/returnTo';
import type { ManufacturersRef } from './Manufacturers';
import type { CategoriesRef } from './Categories';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useCatalogItems, useDeleteCatalogItem, useCatalogCategories } from '../../hooks/useCatalog';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useActiveDealer } from '../../hooks/useActiveDealer';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useGranularAccess, usePermissions } from '../../hooks/usePermissions';
import { buildCatalogScopeKey } from '../../lib/catalogScopeKey';
import { catalogItemDetailKey } from '../../lib/queryKeys';
import { fetchCatalogItemDetail } from '../../lib/catalogListFetchers';
import { warmDetailIfNeeded } from '../../lib/zeroLoading';
import { useNearViewportWarm } from '../../hooks/useNearViewportWarm';
import { useWarehouses } from '../../hooks/useWarehouses';
import { useInventoryAvailability } from '../../hooks/useInventoryAvailability';
import { useAuthSession } from '../../hooks/useAuthSession';
import { InventoryAvailabilityBadge } from '../../components/inventory/InventoryAvailabilityBadge';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import ImportCatalog from './ImportCatalog';
import Manufacturers from './Manufacturers';
import Categories from './Categories';
import Collections from './Collections';
import { 
  Search, 
  Filter,
  X,
  Plus,
  Upload,
  SortAsc,
  SortDesc,
  Edit,
  Copy,
  Eye,
  Trash2,
  Archive,
  ArrowLeft,
  User,
  Image as ImageIcon,
  Package,
  Wrench,
} from 'lucide-react';
import ImageModal from '../../components/ui/ImageModal';

interface Item {
  id: string;
  sku: string;
  itemName: string;
  description?: string;
  item_type?: string;
  measure_basis?: string;
  uom?: string;
  is_fabric?: boolean;
  unit_price?: number;
  msrp?: number;
  msrpUnitLabel?: string;
  updated_at?: string;
  active?: boolean;
  discontinued?: boolean;
  manufacturer?: string;
  category?: string;
  categoryId?: string;
  family?: string;
  image?: string;
}

interface CatalogItemsListStateSnapshot {
  searchTerm: string;
  showFilters: boolean;
  currentPage: number;
  itemsPerPage: number;
  sortBy: 'manufacturer' | 'sku' | 'itemName' | 'category' | 'measure_basis' | 'unit_price' | 'active' | 'family';
  sortOrder: 'asc' | 'desc';
  selectedManufacturer: string[];
  selectedCategory: string[];
  selectedSubcategory: string[];
  selectedFamily: string[];
  selectedMeasureBasis: string[];
  selectedActive: string[];
  selectedProductType: string[];
  selectedStock: string[];
  scrollY: number;
}

function getErrorMessage(error: unknown): string {
  if (!error) return 'Error desconocido';
  if (error instanceof Error) return error.message;
  if (typeof error === 'object') {
    const err = error as { message?: string; details?: string; hint?: string; code?: string };
    const parts = [err.message, err.details, err.hint].filter(Boolean);
    if (parts.length > 0) return parts.join(' | ');
    if (err.code) return `Database error (${err.code})`;
  }
  return String(error);
}

function isTemplateLinkedDeleteWarning(error: unknown): boolean {
  const msg = getErrorMessage(error);
  return msg.includes('WARNING_TEMPLATE_LINKED');
}

function cleanTemplateLinkedWarningMessage(error: unknown): string {
  return getErrorMessage(error).replace('WARNING_TEMPLATE_LINKED:', '').trim();
}

function splitCsvParam(value: string | null): string[] {
  if (!value) return [];
  return value
    .split(',')
    .map((v) => decodeURIComponent(v).trim())
    .filter(Boolean);
}

function hasCatalogListParams(params: URLSearchParams): boolean {
  return (
    params.has('q') ||
    params.has('manufacturer') ||
    params.has('category') ||
    params.has('subcategory') ||
    params.has('family') ||
    params.has('measureBasis') ||
    params.has('active') ||
    params.has('productType') ||
    params.has('stock') ||
    params.has('page') ||
    params.has('pageSize') ||
    params.has('sortBy') ||
    params.has('sortOrder') ||
    params.has('filtersOpen')
  );
}

function hasCatalogRestoreSignal(params: URLSearchParams): boolean {
  try {
    return (
      params.get('restoreList') === '1' ||
      window.sessionStorage.getItem(CATALOG_ITEMS_RESTORE_ON_BACK_KEY) === '1'
    );
  } catch {
    return params.get('restoreList') === '1';
  }
}

export default function Items() {
  const { registerSubmodules } = useSubmoduleNav();
  const { can } = usePermissions();
  const canViewBOM = can('catalog.bom.read') || can('catalog.bom.write') || can('catalog.write');
  const { canCreate: canCreateCat, canArchive: canArchiveCat, canDelete: canDeleteCat } = useGranularAccess('catalog');
  const { items, loading, loadingMore, error, refetch } = useCatalogItems({ includeInactive: true });
  const { categories: catalogCategories } = useCatalogCategories();
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();
  const setGlobalLoading = useUIStore((s) => s.setGlobalLoading);

  useEffect(() => {
    setGlobalLoading(loading);
    return () => setGlobalLoading(false);
  }, [loading, setGlobalLoading]);

  const [activeTab, setActiveTab] = useState<'items' | 'manufacturer' | 'categories' | 'collection'>('items');

  // Register Catalog submodules when Items component mounts
  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/catalog')) {
      registerSubmodules('Catalog', [
        { id: 'items', label: 'Items', href: '/catalog/items', icon: Package },
        ...(canViewBOM ? [{ id: 'bom', label: 'BOM', href: '/catalog/bom', icon: Wrench }] : []),
      ]);
    }
  }, [registerSubmodules, canViewBOM]);
  const { activeOrganizationId } = useOrganizationContext();
  const { userId, loading: authLoading } = useAuthSession();
  const { activeDealerId } = useActiveDealer();
  const { userType } = useAccessContext();
  const queryClient = useQueryClient();
  const scopeKey = useMemo(
    () =>
      buildCatalogScopeKey({
        orgId: activeOrganizationId ?? null,
        activeDealerId: activeDealerId ?? null,
        userRole: userType,
      }),
    [activeOrganizationId, activeDealerId, userType]
  );
  const warmDetail = useCallback(
    (itemId: string) => {
      if (!scopeKey || !activeOrganizationId || !itemId) return;
      warmDetailIfNeeded(
        queryClient,
        {
          queryKey: catalogItemDetailKey(scopeKey, itemId),
          queryFn: () =>
            fetchCatalogItemDetail(supabase, { orgId: activeOrganizationId, itemId }),
          warmId: `${scopeKey}:${itemId}`,
          enabled: true,
        },
        { cooldownMs: 20_000 }
      );
    },
    [queryClient, scopeKey, activeOrganizationId]
  );
  const rowRefForViewport = useNearViewportWarm(warmDetail, { rootMargin: '200px' });

  // Fetch ProductTypes + CatalogItemProductTypes for filtering
  useEffect(() => {
    if (!activeOrganizationId) return;
    let cancelled = false;
    (async () => {
      const [{ data: ptRows, error: ptError }, { data: ciptRows, error: ciptError }] = await Promise.all([
        supabase
          .from('ProductTypes')
          .select('id, name, code')
          .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
          .order('sort_order', { ascending: true, nullsFirst: false })
          .order('name', { ascending: true }),
        supabase
          .from('CatalogItemProductTypes')
          .select('catalog_item_id, product_type_id')
          .eq('organization_id', activeOrganizationId),
      ]);
      if (cancelled) return;
      if (ptError || ciptError) {
        setProductTypeMap({});
        setProductTypeLabels([]);
        return;
      }
      const ptLabelMap: Record<string, string> = {};
      (ptRows ?? []).forEach((pt: any) => { ptLabelMap[pt.id] = pt.name || pt.code; });
      const itemPtMap: Record<string, string[]> = {};
      (ciptRows ?? []).forEach((r: any) => {
        const label = ptLabelMap[r.product_type_id];
        if (!label) return;
        if (!itemPtMap[r.catalog_item_id]) itemPtMap[r.catalog_item_id] = [];
        if (!itemPtMap[r.catalog_item_id].includes(label)) itemPtMap[r.catalog_item_id].push(label);
      });
      setProductTypeMap(itemPtMap);
      setProductTypeLabels([...new Set(Object.values(ptLabelMap))].sort());
    })();
    return () => { cancelled = true; };
  }, [activeOrganizationId]);

  const { defaultWarehouse } = useWarehouses(activeOrganizationId);
  // Defer catalogItemIds until after pagination to avoid re-fetching on every progressive batch
  const [deferredCatalogItemIds, setDeferredCatalogItemIds] = useState<string[]>([]);
  const { map: availabilityMap, loading: availabilityLoading } = useInventoryAvailability({
    organizationId: activeOrganizationId ?? null,
    warehouseId: defaultWarehouse?.id ?? null,
    catalogItemIds: deferredCatalogItemIds,
  });
  const { deleteItem, deleteItems, isDeleting } = useDeleteCatalogItem();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);
  const [sortBy, setSortBy] = useState<'manufacturer' | 'sku' | 'itemName' | 'category' | 'measure_basis' | 'unit_price' | 'active' | 'family'>('sku');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedManufacturer, setSelectedManufacturer] = useState<string[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<string[]>([]);
  const [selectedSubcategory, setSelectedSubcategory] = useState<string[]>([]);
  const [selectedFamily, setSelectedFamily] = useState<string[]>([]);
  const [selectedMeasureBasis, setSelectedMeasureBasis] = useState<string[]>([]);
  const [selectedActive, setSelectedActive] = useState<string[]>([]);
  const [selectedProductType, setSelectedProductType] = useState<string[]>([]);
  const [selectedStock, setSelectedStock] = useState<string[]>([]);
  const [productTypeMap, setProductTypeMap] = useState<Record<string, string[]>>({});
  const [productTypeLabels, setProductTypeLabels] = useState<string[]>([]);
  const [selectedItemIds, setSelectedItemIds] = useState<string[]>([]);
  const [showImportModal, setShowImportModal] = useState(false);
  const [showMoveCategoryModal, setShowMoveCategoryModal] = useState(false);
  const [bulkParentCategoryId, setBulkParentCategoryId] = useState('');
  const [bulkTargetSubcategoryId, setBulkTargetSubcategoryId] = useState('');
  const [isBulkMoving, setIsBulkMoving] = useState(false);
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const isRestoringListStateRef = useRef(false);
  const hasHydratedDbStateRef = useRef(false);
  const persistDbTimerRef = useRef<number | null>(null);
  const lastDbStatePayloadRef = useRef<string>('');
  const manufacturerRef = useRef<ManufacturersRef>(null);
  const categoriesRef = useRef<CategoriesRef>(null);
  const [routeSearch, setRouteSearch] = useState(window.location.search);
  const [categoryFilterFromQuery, setCategoryFilterFromQuery] = useState(false);

  useEffect(() => {
    const unsubscribe = router.addListener(() => {
      setRouteSearch(window.location.search);
    });
    return () => {
      unsubscribe();
    };
  }, []);

  useEffect(() => {
    try {
      const params = new URLSearchParams(routeSearch);
      const restoreFromQuery = params.get('restoreList') === '1';
      const shouldRestore = hasCatalogRestoreSignal(params);
      if (!shouldRestore) return;
      // Guardrail: contextual restore must never fall back to DB hydration.
      // We either restore from snapshot or land on clean list state.
      hasHydratedDbStateRef.current = true;
      // Always refetch items when returning after Save & Close so the list shows saved data
      refetch();
      const raw = window.sessionStorage.getItem(CATALOG_ITEMS_LIST_STATE_KEY);
      window.sessionStorage.removeItem(CATALOG_ITEMS_RESTORE_ON_BACK_KEY);
      if (!raw) {
        if (restoreFromQuery) {
          router.navigate('/catalog/items', false);
        }
        return;
      }

      const snapshot = JSON.parse(raw) as Partial<CatalogItemsListStateSnapshot>;
      isRestoringListStateRef.current = true;
      setSearchTerm(snapshot.searchTerm ?? '');
      setShowFilters(Boolean(snapshot.showFilters));
      setCurrentPage(Math.max(1, Number(snapshot.currentPage ?? 1)));
      setItemsPerPage(Math.max(1, Number(snapshot.itemsPerPage ?? 25)));
      setSortBy((snapshot.sortBy as CatalogItemsListStateSnapshot['sortBy']) ?? 'sku');
      setSortOrder((snapshot.sortOrder as 'asc' | 'desc') ?? 'asc');
      setSelectedManufacturer(Array.isArray(snapshot.selectedManufacturer) ? snapshot.selectedManufacturer : []);
      setSelectedCategory(Array.isArray(snapshot.selectedCategory) ? snapshot.selectedCategory : []);
      setSelectedSubcategory(Array.isArray(snapshot.selectedSubcategory) ? snapshot.selectedSubcategory : []);
      setSelectedFamily(Array.isArray(snapshot.selectedFamily) ? snapshot.selectedFamily : []);
      setSelectedMeasureBasis(Array.isArray(snapshot.selectedMeasureBasis) ? snapshot.selectedMeasureBasis : []);
      setSelectedActive(Array.isArray(snapshot.selectedActive) ? snapshot.selectedActive : []);
      setSelectedProductType(Array.isArray(snapshot.selectedProductType) ? snapshot.selectedProductType : []);
      setSelectedStock(Array.isArray(snapshot.selectedStock) ? snapshot.selectedStock : []);

      const scrollY = Number(snapshot.scrollY ?? 0);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          window.scrollTo({ top: Number.isFinite(scrollY) ? Math.max(0, scrollY) : 0, behavior: 'auto' });
          if (restoreFromQuery) {
            window.history.replaceState({}, '', '/catalog/items');
          }
          isRestoringListStateRef.current = false;
        });
      });
    } catch {
      isRestoringListStateRef.current = false;
    }
  }, [routeSearch, refetch]);

  useEffect(() => {
    if (authLoading || !userId) return;
    if (hasHydratedDbStateRef.current) return;

    const params = new URLSearchParams(routeSearch);
    if (hasCatalogRestoreSignal(params)) return;
    if (hasCatalogListParams(params)) return;

    hasHydratedDbStateRef.current = true;
    let cancelled = false;
    (async () => {
      const { data, error } = await supabase.rpc('get_catalog_items_list_state');
      if (cancelled || error || !data || typeof data !== 'object' || Array.isArray(data)) return;

      const snapshot = data as Partial<CatalogItemsListStateSnapshot>;
      isRestoringListStateRef.current = true;
      setSearchTerm(snapshot.searchTerm ?? '');
      setShowFilters(Boolean(snapshot.showFilters));
      setCurrentPage(Math.max(1, Number(snapshot.currentPage ?? 1)));
      setItemsPerPage(Math.max(1, Number(snapshot.itemsPerPage ?? 25)));
      setSortBy((snapshot.sortBy as CatalogItemsListStateSnapshot['sortBy']) ?? 'sku');
      setSortOrder((snapshot.sortOrder as 'asc' | 'desc') ?? 'asc');
      setSelectedManufacturer(Array.isArray(snapshot.selectedManufacturer) ? snapshot.selectedManufacturer : []);
      setSelectedCategory(Array.isArray(snapshot.selectedCategory) ? snapshot.selectedCategory : []);
      setSelectedSubcategory(Array.isArray(snapshot.selectedSubcategory) ? snapshot.selectedSubcategory : []);
      setSelectedFamily(Array.isArray(snapshot.selectedFamily) ? snapshot.selectedFamily : []);
      setSelectedMeasureBasis(Array.isArray(snapshot.selectedMeasureBasis) ? snapshot.selectedMeasureBasis : []);
      setSelectedActive(Array.isArray(snapshot.selectedActive) ? snapshot.selectedActive : []);
      setSelectedProductType(Array.isArray(snapshot.selectedProductType) ? snapshot.selectedProductType : []);
      setSelectedStock(Array.isArray(snapshot.selectedStock) ? snapshot.selectedStock : []);
      requestAnimationFrame(() => {
        isRestoringListStateRef.current = false;
      });
    })();

    return () => {
      cancelled = true;
    };
  }, [authLoading, userId, routeSearch]);
  const queryReturnTo = useMemo(() => getReturnToFromCurrentQuery(), [routeSearch]);
  const hasContextualLinkBack = useMemo(() => {
    const params = new URLSearchParams(routeSearch);
    const hasReturnTo = !!params.get('returnTo');
    const hasCategoryId = !!params.get('category_id');
    try {
      const hasStoredContext = !!window.sessionStorage.getItem('catalogItemsBackContext');
      return hasReturnTo || hasCategoryId || hasStoredContext;
    } catch {
      return hasReturnTo || hasCategoryId;
    }
  }, [routeSearch]);
  const hasActiveFilters = useMemo(
    () =>
      searchTerm.trim().length > 0 ||
      selectedManufacturer.length > 0 ||
      selectedCategory.length > 0 ||
      selectedSubcategory.length > 0 ||
      selectedFamily.length > 0 ||
      selectedMeasureBasis.length > 0 ||
      selectedActive.length > 0 ||
      selectedProductType.length > 0 ||
      selectedStock.length > 0,
    [
      searchTerm,
      selectedManufacturer,
      selectedCategory,
      selectedSubcategory,
      selectedFamily,
      selectedMeasureBasis,
      selectedActive,
      selectedProductType,
      selectedStock,
    ]
  );
  const categoryIdFromQuery = useMemo(() => {
    const params = new URLSearchParams(routeSearch);
    return params.get('category_id');
  }, [routeSearch]);
  const hasContextualBack = activeTab === 'items' && (hasContextualLinkBack || hasActiveFilters);
  const handleContextualBack = useCallback(() => {
    const currentReturnTo = getReturnToFromCurrentQuery();
    if (currentReturnTo) {
      navigateBackContextual(router, {
        queryReturnTo: currentReturnTo,
        fallback: '/catalog/items',
      });
      return;
    }
    if (hasActiveFilters) {
      setSearchTerm('');
      setSelectedManufacturer([]);
      setSelectedCategory([]);
      setSelectedSubcategory([]);
      setSelectedFamily([]);
      setSelectedMeasureBasis([]);
      setSelectedActive([]);
      setSelectedProductType([]);
      setSelectedStock([]);
      setShowFilters(false);
      setCurrentPage(1);
      setSortBy('sku');
      setSortOrder('asc');
      setCategoryFilterFromQuery(false);
      try {
        window.sessionStorage.removeItem(CATALOG_ITEMS_LIST_STATE_KEY);
        window.sessionStorage.removeItem(CATALOG_ITEMS_RESTORE_ON_BACK_KEY);
      } catch {
        // no-op
      }
      router.navigate('/catalog/items', false);
      return;
    }
    // If filter came from Categories tab (same route), return to that tab.
    // Clear query context to avoid re-enabling Back on next render.
    router.navigate('/catalog/items', false);
    setSelectedCategory([]);
    setCategoryFilterFromQuery(false);
    try {
      window.sessionStorage.removeItem('catalogItemsBackContext');
    } catch {
      // no-op
    }
    setActiveTab('categories');
  }, [hasActiveFilters]);

  // Format date to DD/MM/YY format
  const formatDate = (dateString?: string | null): string => {
    if (!dateString) return 'N/A';
    try {
      const date = new Date(dateString);
      const day = String(date.getDate()).padStart(2, '0');
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const year = String(date.getFullYear()).slice(-2);
      return `${day}/${month}/${year}`;
    } catch {
      return 'N/A';
    }
  };

  // Create a map of category_id -> category name
  const categoryMap = useMemo(() => {
    const map = new Map<string, string>();
    catalogCategories.forEach(cat => {
      map.set(cat.id, cat.name);
    });
    return map;
  }, [catalogCategories]);

  // Transform catalog items to display format
  const itemsData: Item[] = useMemo(() => {
    if (!items || items.length === 0) return [];
    
    // ✅ OPTIMIZACIÓN: Filtrar items que no tengan los campos mínimos necesarios
    // Solo procesar items que tengan al menos id y sku
    const validItems = items.filter(item => item && item.id && (item.sku || item.name));
    
    return validItems.map(item => {
      // Get category name from category_id
      const categoryName = item.category_id 
        ? (categoryMap.get(item.category_id) || 'Not specified')
        : (item.metadata?.category || 'Not specified');
      
      // Get MSRP: use the value from CatalogItem (which already has msrp from CatalogItemsMSRP)
      // Accept any numeric value (including 0, though 0 will display as $0.00)
      let msrpValue: number | undefined = undefined;
      if (item.msrp != null && item.msrp !== undefined) {
        const numValue = typeof item.msrp === 'number' ? item.msrp : Number(item.msrp);
        if (!isNaN(numValue)) {
          msrpValue = numValue;
        }
      }

      // Normalize MSRP for display (list should show normalized unit, not raw yd/ft)
      const rawUom = (item.unit_of_measure || item.uom || 'ea').toString();
      const rawUomLower = rawUom.toLowerCase();
      const pricingMode = ((item as any).roll_pricing_mode || null) as string | null;
      const widthM = (() => {
        const v = (item as any).roll_width_m ?? (item as any).roll_width ?? null;
        const n = v != null ? Number(v) : null;
        return n != null && !isNaN(n) ? n : null;
      })();
      const toPerMeter = (price: number, uom: string): number | null => {
        const u = (uom || '').toLowerCase();
        if (u === 'm' || u === 'meter' || u === 'meters') return price;
        if (u === 'yd' || u === 'yard' || u === 'yards') return price / 0.9144;
        if (u === 'ft' || u === 'foot' || u === 'feet') return price / 0.3048;
        return null;
      };
      let msrpDisplay = msrpValue;
      let msrpUnitLabel = '';
      if (msrpValue != null) {
        // Default to showing per meter for linear rolls/items
        const perM = toPerMeter(msrpValue, rawUomLower);
        if (pricingMode === 'per_square_meter' || item.measure_basis === 'area') {
          if (perM != null && widthM != null && widthM > 0) {
            msrpDisplay = perM / widthM;
            msrpUnitLabel = '/m²';
          } else if (perM != null) {
            msrpDisplay = perM;
            msrpUnitLabel = '/m';
          } else {
            msrpDisplay = msrpValue;
            msrpUnitLabel = `/${rawUomLower}`;
          }
        } else if (pricingMode === 'per_linear_meter' || item.measure_basis === 'linear') {
          if (perM != null) {
            msrpDisplay = perM;
            msrpUnitLabel = '/m';
          } else {
            msrpDisplay = msrpValue;
            msrpUnitLabel = `/${rawUomLower}`;
          }
        } else {
          // Unit items (or per_unit pricing) show MSRP per ea
          msrpDisplay = msrpValue;
          // Normalize unit label: pack/set/box/case → ea
          const isPackType = ['pack', 'set', 'box', 'case', 'bag', 'piece', 'pcs', 'pc'].includes(rawUomLower);
          msrpUnitLabel = isPackType ? '/ea' : `/${rawUomLower}`;
        }
      }
      
      // ✅ OPTIMIZACIÓN: Asegurar que active esté siempre definido antes de renderizar
      // Si no está disponible, usar true como default (ya que solo cargamos items activos)
      const activeStatus = item.active !== undefined && item.active !== null 
        ? Boolean(item.active)
        : (item.is_active !== undefined && item.is_active !== null
          ? Boolean(item.is_active)
          : true); // Default a true ya que solo cargamos items con is_active=true
      
      // ✅ OPTIMIZACIÓN: Asegurar que todos los campos visibles tengan valores por defecto antes de renderizar
      return {
        id: item.id || '',
        sku: item.sku || 'N/A',
        itemName: item.name || item.item_name || 'N/A',
        description: item.description || undefined,
        item_type: undefined, // item_type column removed from DB - using category instead
        measure_basis: item.measure_basis || 'N/A',
        uom: item.uom || item.unit_of_measure || 'N/A',
        is_fabric: item.is_fabric || false,
        unit_price: item.unit_price || 0,
        // MSRP displayed normalized (per m or per m² when applicable)
        msrp: msrpDisplay !== undefined ? msrpDisplay : 0,
        msrpUnitLabel,
        updated_at: (item as any).updated_at || item.created_at || undefined,
        active: activeStatus, // ✅ Siempre definido antes de renderizar
        discontinued: item.discontinued || false,
        manufacturer: item.manufacturer || item.metadata?.manufacturer || 'Not specified',
        category: categoryName || 'N/A',
        categoryId: item.category_id || undefined,
        family: item.metadata?.family || 'Not specified',
        image: item.image_url || item.metadata?.image || null,
      };
    });
  }, [items, categoryMap]);

  // Read category_id from URL params and filter (reactive to route query changes)
  useEffect(() => {
    const urlParams = new URLSearchParams(routeSearch);
    const categoryIdParam = urlParams.get('category_id');
    
    if (categoryIdParam) {
      // Find the category name from the map
      const categoryName = categoryMap.get(categoryIdParam);
      if (categoryName) {
        setActiveTab('items');
        setSelectedCategory([categoryName]);
        setCategoryFilterFromQuery(true);
      }
    } else if (categoryFilterFromQuery && !hasContextualLinkBack) {
      // Clear only query-driven filter; keep user-manual filters intact.
      setSelectedCategory([]);
      setCategoryFilterFromQuery(false);
    }
  }, [categoryMap, routeSearch, categoryFilterFromQuery, hasContextualLinkBack]);

  // ✅ OPTIMIZACIÓN: Solo usar items que tengan todos los campos básicos cargados
  // Filtrar items incompletos para evitar mostrar campos vacíos
  const displayItems = useMemo(() => {
    return itemsData.filter(item => {
      // Asegurar que tenga al menos id, sku o name
      return item && item.id && (item.sku || item.itemName);
    });
  }, [itemsData]);

  // Filter and sort items (excluding stock filter, which depends on availability map)
  const preStockFilteredItems = useMemo(() => {
    const filtered = displayItems.filter(item => {
      // Search filter - FLEXIBLE (supports SKU with/without hyphens, collection, variant, color)
      const searchLower = searchTerm.toLowerCase().trim();
      const searchNormalized = searchLower.replace(/[-\s]/g, ''); // Remove hyphens and spaces
      
      const matchesSearch = !searchTerm || (() => {
        // Normalize SKU for flexible matching (SCR-3001 = SCR3001 = "SCR 3001")
        const skuNormalized = (item.sku || '').toLowerCase().replace(/[-\s]/g, '');
        
        // Get additional fields from original item data
        const itemData = items?.find(i => i.id === item.id);
        const collectionName = ((itemData as any)?.collection_name || '').toLowerCase();
        const variantName = ((itemData as any)?.variant_name || '').toLowerCase();
        const color = ((itemData as any)?.color || '').toLowerCase();
        
        return (
          // SKU: exact + normalized matching
          (item.sku || '').toLowerCase().includes(searchLower) ||
          skuNormalized.includes(searchNormalized) ||
          // Name
          (item.itemName || '').toLowerCase().includes(searchLower) ||
          // Description
          (item.description || '').toLowerCase().includes(searchLower) ||
          // Collection, Variant, Color
          collectionName.includes(searchLower) ||
          variantName.includes(searchLower) ||
          color.includes(searchLower) ||
          // Measure basis, UOM
          (item.measure_basis || '').toLowerCase().includes(searchLower) ||
          (item.uom || '').toLowerCase().includes(searchLower) ||
          // Manufacturer, Category, Family
          (item.manufacturer || '').toLowerCase().includes(searchLower) ||
          (item.category || '').toLowerCase().includes(searchLower) ||
          (item.family || '').toLowerCase().includes(searchLower)
        );
      })();

      // Manufacturer filter
      const matchesManufacturer = selectedManufacturer.length === 0 || (item.manufacturer && selectedManufacturer.includes(item.manufacturer));

      // Category filter
      const matchesCategory = selectedCategory.length === 0 || (item.category && selectedCategory.includes(item.category));

      // Sub Category filter (by category_id to avoid label collisions)
      const matchesSubcategory = selectedSubcategory.length === 0 || (item.categoryId && selectedSubcategory.includes(item.categoryId));

      // Family filter
      const matchesFamily = selectedFamily.length === 0 || (item.family && selectedFamily.includes(item.family));

      // Measure Basis filter
      const matchesMeasureBasis = selectedMeasureBasis.length === 0 || (item.measure_basis && selectedMeasureBasis.includes(item.measure_basis));

      // Active filter
      const matchesActive = selectedActive.length === 0 || (item.active !== undefined && selectedActive.includes(item.active ? 'Active' : 'Inactive'));

      // Product Type filter
      const matchesProductType = selectedProductType.length === 0 || (productTypeMap[item.id] && productTypeMap[item.id].some(pt => selectedProductType.includes(pt)));

      return matchesSearch && matchesManufacturer && matchesCategory && matchesSubcategory && matchesFamily && matchesMeasureBasis && matchesActive && matchesProductType;
    });

    // Apply sorting
    return filtered.sort((a, b) => {
      let aValue: string;
      let bValue: string;

      switch (sortBy) {
        case 'manufacturer':
          aValue = (a.manufacturer || '').toLowerCase();
          bValue = (b.manufacturer || '').toLowerCase();
          break;
        case 'sku':
          aValue = (a.sku || '').toLowerCase();
          bValue = (b.sku || '').toLowerCase();
          break;
        case 'itemName':
          aValue = (a.itemName || '').toLowerCase();
          bValue = (b.itemName || '').toLowerCase();
          break;
        case 'category':
          aValue = (a.category || '').toLowerCase();
          bValue = (b.category || '').toLowerCase();
          break;
        case 'family':
          aValue = (a.family || '').toLowerCase();
          bValue = (b.family || '').toLowerCase();
          break;
        case 'measure_basis':
          aValue = (a.measure_basis || '').toLowerCase();
          bValue = (b.measure_basis || '').toLowerCase();
          break;
        case 'unit_price':
          aValue = String(a.unit_price || 0);
          bValue = String(b.unit_price || 0);
          break;
        case 'active':
          aValue = String(a.active ? 1 : 0);
          bValue = String(b.active ? 1 : 0);
          break;
        default:
          aValue = (a.sku || '').toLowerCase();
          bValue = (b.sku || '').toLowerCase();
      }

      // For numeric fields, compare as numbers
      if (sortBy === 'unit_price' || sortBy === 'active') {
        const aNum = parseFloat(aValue);
        const bNum = parseFloat(bValue);
        if (aNum < bNum) return sortOrder === 'asc' ? -1 : 1;
        if (aNum > bNum) return sortOrder === 'asc' ? 1 : -1;
        return 0;
      }
      
      // For string fields, compare as strings
      if (aValue < bValue) return sortOrder === 'asc' ? -1 : 1;
      if (aValue > bValue) return sortOrder === 'asc' ? 1 : -1;
      return 0;
    });
  }, [searchTerm, itemsData, items, sortBy, sortOrder, selectedManufacturer, selectedCategory, selectedSubcategory, selectedFamily, selectedMeasureBasis, selectedActive, selectedProductType, productTypeMap]);

  const filteredItems = useMemo(() => {
    if (selectedStock.length === 0) return preStockFilteredItems;
    if (availabilityLoading && deferredCatalogItemIds.length > 0) return preStockFilteredItems;
    return preStockFilteredItems.filter((item) => {
      const status = availabilityMap[item.id]?.availability ?? 'OUT_OF_STOCK';
      const inStock = status === 'IN_STOCK';
      const outOfStock = status === 'OUT_OF_STOCK';
      return (selectedStock.includes('In Stock') && inStock) || (selectedStock.includes('Out of Stock') && outOfStock);
    });
  }, [preStockFilteredItems, selectedStock, availabilityMap, availabilityLoading, deferredCatalogItemIds.length]);

  // Pagination calculations
  const totalPages = Math.ceil(filteredItems.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedItems = filteredItems.slice(startIndex, startIndex + itemsPerPage);

  // Fetch availability for current page normally; when stock filter is active, fetch for all pre-stock filtered items
  useEffect(() => {
    const ids = (selectedStock.length > 0 ? preStockFilteredItems : paginatedItems).map((i) => i.id).filter(Boolean);
    setDeferredCatalogItemIds((prev) => {
      const key = ids.join(',');
      const prevKey = prev.join(',');
      return key === prevKey ? prev : ids;
    });
  }, [paginatedItems, preStockFilteredItems, selectedStock]);

  const selectedItemsCount = selectedItemIds.length;
  const allPageSelected = paginatedItems.length > 0 && paginatedItems.every((item) => selectedItemIds.includes(item.id));

  const parentCatalogCategories = useMemo(
    () => catalogCategories.filter((cat: any) => cat.is_group && !cat.parent_id),
    [catalogCategories]
  );
  const subcategoriesByParent = useMemo(
    () =>
      bulkParentCategoryId
        ? catalogCategories.filter((cat: any) => !cat.is_group && cat.parent_id === bulkParentCategoryId)
        : [],
    [catalogCategories, bulkParentCategoryId]
  );

  // Reset to first page when search changes (except when restoring list state)
  useEffect(() => {
    if (isRestoringListStateRef.current) return;
    setCurrentPage(1);
  }, [searchTerm]);

  const saveListStateSnapshot = useCallback(() => {
    const snapshot: CatalogItemsListStateSnapshot = {
      searchTerm,
      showFilters,
      currentPage,
      itemsPerPage,
      sortBy,
      sortOrder,
      selectedManufacturer,
      selectedCategory,
      selectedSubcategory,
      selectedFamily,
      selectedMeasureBasis,
      selectedActive,
      selectedProductType,
      selectedStock,
      scrollY: window.scrollY || 0,
    };
    try {
      window.sessionStorage.setItem(CATALOG_ITEMS_LIST_STATE_KEY, JSON.stringify(snapshot));
    } catch {
      // no-op
    }
  }, [
    searchTerm,
    showFilters,
    currentPage,
    itemsPerPage,
    sortBy,
    sortOrder,
    selectedManufacturer,
    selectedCategory,
    selectedSubcategory,
    selectedFamily,
    selectedMeasureBasis,
    selectedActive,
    selectedProductType,
    selectedStock,
  ]);

  const buildCatalogItemsReturnTo = useCallback(() => {
    const params = new URLSearchParams();
    if (searchTerm.trim()) params.set('q', searchTerm.trim());
    if (selectedManufacturer.length > 0) params.set('manufacturer', selectedManufacturer.map(encodeURIComponent).join(','));
    if (selectedCategory.length > 0) params.set('category', selectedCategory.map(encodeURIComponent).join(','));
    if (selectedSubcategory.length > 0) params.set('subcategory', selectedSubcategory.map(encodeURIComponent).join(','));
    if (selectedFamily.length > 0) params.set('family', selectedFamily.map(encodeURIComponent).join(','));
    if (selectedMeasureBasis.length > 0) params.set('measureBasis', selectedMeasureBasis.map(encodeURIComponent).join(','));
    if (selectedActive.length > 0) params.set('active', selectedActive.map(encodeURIComponent).join(','));
    if (selectedProductType.length > 0) params.set('productType', selectedProductType.map(encodeURIComponent).join(','));
    if (selectedStock.length > 0) params.set('stock', selectedStock.map(encodeURIComponent).join(','));
    if (currentPage > 1) params.set('page', String(currentPage));
    if (itemsPerPage !== 25) params.set('pageSize', String(itemsPerPage));
    if (sortBy !== 'sku') params.set('sortBy', sortBy);
    if (sortOrder !== 'asc') params.set('sortOrder', sortOrder);
    if (showFilters) params.set('filtersOpen', '1');
    const qs = params.toString();
    return qs ? `/catalog/items?${qs}` : '/catalog/items';
  }, [
    searchTerm,
    selectedManufacturer,
    selectedCategory,
    selectedSubcategory,
    selectedFamily,
    selectedMeasureBasis,
    selectedActive,
    selectedProductType,
    selectedStock,
    currentPage,
    itemsPerPage,
    sortBy,
    sortOrder,
    showFilters,
  ]);

  // Keep a fresh list snapshot in sessionStorage so Back restores exact latest list state.
  useEffect(() => {
    if (isRestoringListStateRef.current) return;
    saveListStateSnapshot();
  }, [saveListStateSnapshot]);

  useEffect(() => {
    if (authLoading || !userId) return;
    if (isRestoringListStateRef.current) return;

    const payload = {
      searchTerm,
      showFilters,
      currentPage,
      itemsPerPage,
      sortBy,
      sortOrder,
      selectedManufacturer,
      selectedCategory,
      selectedSubcategory,
      selectedFamily,
      selectedMeasureBasis,
      selectedActive,
      selectedProductType,
      selectedStock,
    };
    const serialized = JSON.stringify(payload);
    if (serialized === lastDbStatePayloadRef.current) return;

    if (persistDbTimerRef.current) {
      window.clearTimeout(persistDbTimerRef.current);
    }
    persistDbTimerRef.current = window.setTimeout(() => {
      void supabase.rpc('set_catalog_items_list_state', { p_state: payload });
      lastDbStatePayloadRef.current = serialized;
      persistDbTimerRef.current = null;
    }, 500);

    return () => {
      if (persistDbTimerRef.current) {
        window.clearTimeout(persistDbTimerRef.current);
        persistDbTimerRef.current = null;
      }
    };
  }, [
    authLoading,
    userId,
    searchTerm,
    showFilters,
    currentPage,
    itemsPerPage,
    sortBy,
    sortOrder,
    selectedManufacturer,
    selectedCategory,
    selectedSubcategory,
    selectedFamily,
    selectedMeasureBasis,
    selectedActive,
    selectedProductType,
    selectedStock,
  ]);

  useEffect(() => {
    const params = new URLSearchParams(routeSearch);
    if (hasCatalogRestoreSignal(params)) return;
    const hasRichListParams = hasCatalogListParams(params);
    if (!hasRichListParams) return;

    isRestoringListStateRef.current = true;
    setSearchTerm(params.get('q') ?? '');
    setSelectedManufacturer(splitCsvParam(params.get('manufacturer')));
    setSelectedCategory(splitCsvParam(params.get('category')));
    setSelectedSubcategory(splitCsvParam(params.get('subcategory')));
    setSelectedFamily(splitCsvParam(params.get('family')));
    setSelectedMeasureBasis(splitCsvParam(params.get('measureBasis')));
    setSelectedActive(splitCsvParam(params.get('active')));
    setSelectedProductType(splitCsvParam(params.get('productType')));
    setSelectedStock(splitCsvParam(params.get('stock')));

    const nextPage = Math.max(1, Number(params.get('page') ?? 1));
    const nextPageSize = Math.max(1, Number(params.get('pageSize') ?? 25));
    const nextSortBy = params.get('sortBy');
    const nextSortOrder = params.get('sortOrder');
    setCurrentPage(Number.isFinite(nextPage) ? nextPage : 1);
    setItemsPerPage(Number.isFinite(nextPageSize) ? nextPageSize : 25);
    if (nextSortBy && ['manufacturer', 'sku', 'itemName', 'category', 'measure_basis', 'unit_price', 'active', 'family'].includes(nextSortBy)) {
      setSortBy(nextSortBy as typeof sortBy);
    }
    if (nextSortOrder === 'asc' || nextSortOrder === 'desc') {
      setSortOrder(nextSortOrder);
    }
    setShowFilters(params.get('filtersOpen') === '1');

    requestAnimationFrame(() => {
      isRestoringListStateRef.current = false;
    });
  }, [routeSearch]);

  // Handle sorting
  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('asc');
    }
  };

  // Handle filter toggles
  const handleManufacturerToggle = (manufacturer: string) => {
    setSelectedManufacturer(prev => 
      prev.includes(manufacturer) 
        ? prev.filter(m => m !== manufacturer)
        : [...prev, manufacturer]
    );
  };

  const handleCategoryToggle = (category: string) => {
    setSelectedCategory(prev => 
      prev.includes(category) 
        ? prev.filter(c => c !== category)
        : [...prev, category]
    );
  };

  const handleSubcategoryToggle = (subcategoryId: string) => {
    setSelectedSubcategory((prev) =>
      prev.includes(subcategoryId)
        ? prev.filter((id) => id !== subcategoryId)
        : [...prev, subcategoryId]
    );
  };

  const handleFamilyToggle = (family: string) => {
    setSelectedFamily(prev => 
      prev.includes(family) 
        ? prev.filter(f => f !== family)
        : [...prev, family]
    );
  };

  // Clear all filters
  const clearAllFilters = () => {
    setSelectedManufacturer([]);
    setSelectedCategory([]);
    setSelectedSubcategory([]);
    setSelectedFamily([]);
    setSelectedMeasureBasis([]);
    setSelectedActive([]);
    setSelectedProductType([]);
    setSelectedStock([]);
    setSearchTerm('');
  };

  const handleGoToCatalogBase = useCallback(() => {
    setActiveTab('items');
    setSearchTerm('');
    setSelectedManufacturer([]);
    setSelectedCategory([]);
    setSelectedSubcategory([]);
    setSelectedFamily([]);
    setSelectedMeasureBasis([]);
    setSelectedActive([]);
    setSelectedProductType([]);
    setSelectedStock([]);
    setShowFilters(false);
    setCurrentPage(1);
    setSortBy('sku');
    setSortOrder('asc');
    setCategoryFilterFromQuery(false);
    setCatalogItemsReturnTo(null);
    try {
      window.sessionStorage.removeItem('catalogItemsBackContext');
      window.sessionStorage.removeItem(CATALOG_ITEMS_LIST_STATE_KEY);
      window.sessionStorage.removeItem(CATALOG_ITEMS_RESTORE_ON_BACK_KEY);
    } catch {
      // no-op
    }
    router.navigate('/catalog/items', false);
  }, []);

  const toggleSelectItem = (itemId: string) => {
    setSelectedItemIds((prev) => (prev.includes(itemId) ? prev.filter((id) => id !== itemId) : [...prev, itemId]));
  };

  const toggleSelectAllPage = () => {
    setSelectedItemIds((prev) => {
      if (allPageSelected) {
        const pageIds = new Set(paginatedItems.map((item) => item.id));
        return prev.filter((id) => !pageIds.has(id));
      }
      const next = new Set(prev);
      paginatedItems.forEach((item) => next.add(item.id));
      return Array.from(next);
    });
  };

  const openMoveCategoryModal = () => {
    setBulkParentCategoryId('');
    setBulkTargetSubcategoryId('');
    setShowMoveCategoryModal(true);
  };

  const closeMoveCategoryModal = () => {
    setShowMoveCategoryModal(false);
    setBulkParentCategoryId('');
    setBulkTargetSubcategoryId('');
  };

  const handleBulkMoveCategory = async () => {
    if (!activeOrganizationId || selectedItemIds.length === 0 || !bulkTargetSubcategoryId) return;
    try {
      setIsBulkMoving(true);
      const { error } = await supabase
        .from('CatalogItems')
        .update({ category_id: bulkTargetSubcategoryId, updated_at: new Date().toISOString() })
        .eq('organization_id', activeOrganizationId)
        .in('id', selectedItemIds);
      if (error) throw new Error(error.message || 'Failed to move selected items');

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Category updated',
        message: `${selectedItemIds.length} item(s) moved successfully.`,
      });
      setSelectedItemIds([]);
      closeMoveCategoryModal();
      refetch();
    } catch (error) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Move failed',
        message: error instanceof Error ? error.message : 'Unknown error while moving items.',
      });
    } finally {
      setIsBulkMoving(false);
    }
  };

  // Handlers for actions
  const handleEditItem = (item: Item, e?: React.MouseEvent) => {
    e?.stopPropagation();
    saveListStateSnapshot();
    setCatalogItemsRestoreOnBack(true);
    const returnTo = buildCatalogItemsReturnTo();
    setCatalogItemsReturnTo(returnTo);
    try {
      window.sessionStorage.setItem(`catalogItemReturnTo:${item.id}`, returnTo);
    } catch {
      // no-op
    }
    router.navigate(withReturnTo(`/catalog/items/edit/${item.id}`, returnTo));
  };

  const handleArchiveItem = async (item: Item, e: React.MouseEvent) => {
    e.stopPropagation();
    
    const confirmed = await showConfirm({
      title: 'Archivar Item',
      message: `¿Estás seguro de que deseas archivar "${item.itemName}"?`,
      variant: 'warning',
      confirmText: 'Archivar',
      cancelText: 'Cancelar',
    });

    if (!confirmed) return;

    try {
      if (!activeOrganizationId) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error al archivar',
          message: 'No hay organización seleccionada',
        });
        return;
      }
      
      setLoading(true);
      
      // ✅ FIX: CatalogItems no tiene columna 'archived', usar 'is_active: false' en su lugar
      const { error } = await supabase
        .from('CatalogItems')
        .update({ is_active: false })
        .eq('id', item.id)
        .eq('organization_id', activeOrganizationId);

      if (error) {
        console.error('❌ Error archiving item:', error);
        throw error;
      }

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Item archivado',
        message: 'El item ha sido archivado correctamente.',
      });
      
      refetch();
    } catch (error) {
      console.error('❌ Error in handleArchiveItem:', error);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error al archivar',
        message: error instanceof Error ? error.message : 'Error desconocido',
      });
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteItem = async (item: Item, e: React.MouseEvent) => {
    e.stopPropagation();
    
    const confirmed = await showConfirm({
      title: 'Eliminar Item',
      message: `¿Estás seguro de que deseas eliminar "${item.itemName}"? Esta acción no se puede deshacer.`,
      variant: 'danger',
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
    });

    if (!confirmed) return;

    try {
      setLoading(true);
      await deleteItem(item.id);
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Item eliminado',
        message: 'El item ha sido eliminado correctamente.',
      });
      refetch();
        } catch (error) {
      const isWarning = isTemplateLinkedDeleteWarning(error);
      useUIStore.getState().addNotification({
        type: isWarning ? 'warning' : 'error',
        title: isWarning ? 'No se puede eliminar' : 'Error al eliminar',
        message: isWarning ? cleanTemplateLinkedWarningMessage(error) : getErrorMessage(error),
      });
    } finally {
      setLoading(false);
    }
  };

  const [isDuplicating, setIsDuplicating] = useState(false);
  const handleDuplicateItem = async (item: Item, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!activeOrganizationId) return;
    setIsDuplicating(true);
    try {
      const { data: original, error: fetchErr } = await supabase
        .from('CatalogItems')
        .select('*')
        .eq('id', item.id)
        .eq('organization_id', activeOrganizationId)
        .single();
      if (fetchErr || !original) throw fetchErr || new Error('Item not found');

      const { id, created_at, updated_at, ...rest } = original;
      const newSku = `${original.sku}-Copy`;
      const newName = original.name ? `${original.name} (Copy)` : newSku;

      const { data: inserted, error: insertErr } = await supabase
        .from('CatalogItems')
        .insert({ ...rest, sku: newSku, name: newName })
        .select('id, sku, name, category_id, cost_exw, manufacturer_id, item_role, measure_basis')
        .single();
      if (insertErr) {
        if (insertErr.code === '23505') throw new Error(`SKU "${newSku}" already exists.`);
        throw insertErr;
      }
      if (!inserted) throw new Error('Insert returned no data');

      // Verify critical fields were copied correctly
      if (inserted.category_id !== original.category_id) {
        console.warn('⚠️ Duplicate: category_id mismatch', { original: original.category_id, copy: inserted.category_id });
      }
      if (String(inserted.cost_exw) !== String(original.cost_exw)) {
        console.warn('⚠️ Duplicate: cost_exw mismatch', { original: original.cost_exw, copy: inserted.cost_exw });
      }

      const warnings: string[] = [];

      // Copy supply info
      try {
        const { data: supplyData } = await supabase
          .from('CatalogItemSupply')
          .select('*')
          .eq('catalog_item_id', id)
          .eq('organization_id', activeOrganizationId)
          .maybeSingle();
        if (supplyData) {
          const { created_at: _sca, updated_at: _sua, ...supplyRest } = supplyData;
          const { error: supplyErr } = await supabase.from('CatalogItemSupply').upsert({
            ...supplyRest,
            catalog_item_id: inserted.id,
          });
          if (supplyErr) {
            console.warn('⚠️ Supply copy failed:', supplyErr.message);
            warnings.push('Supply info');
          }
        }
      } catch (supplyEx: any) {
        console.warn('⚠️ Supply copy exception:', supplyEx?.message);
        warnings.push('Supply info');
      }

      // Copy product type associations
      try {
        const { data: ptRows } = await supabase
          .from('CatalogItemProductTypes')
          .select('product_type_id')
          .eq('catalog_item_id', id)
          .eq('organization_id', activeOrganizationId);
        if (ptRows && ptRows.length > 0) {
          const ptInserts = ptRows.map((row: any) => ({
            organization_id: activeOrganizationId,
            catalog_item_id: inserted.id,
            product_type_id: row.product_type_id,
          }));
          const { error: ptErr } = await supabase.from('CatalogItemProductTypes').insert(ptInserts);
          if (ptErr) {
            console.warn('⚠️ ProductTypes copy failed:', ptErr.message);
            warnings.push('Product Types');
          }
        }
      } catch (ptEx: any) {
        console.warn('⚠️ ProductTypes copy exception:', ptEx?.message);
        warnings.push('Product Types');
      }

      // Compute MSRP for the new item
      try {
        await supabase.rpc('msrp_compute_for_item', { p_item_id: inserted.id });
      } catch {
        warnings.push('MSRP');
      }

      // Clear any stale session for the new item
      try {
        window.sessionStorage.removeItem(`catalogItemEdit:${inserted.id}`);
      } catch {
        // no-op
      }

      if (warnings.length > 0) {
        useUIStore.getState().addNotification({
          type: 'warning',
          title: 'Item duplicado con advertencias',
          message: `Se creó "${newSku}" pero no se pudieron copiar: ${warnings.join(', ')}.`,
        });
      } else {
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Item duplicado',
          message: `Se creó "${newSku}" correctamente.`,
        });
      }
      refetch();

      const returnTo = getReturnToFromCurrentQuery() ?? '/catalog/items';
      router.navigate(withReturnTo(`/catalog/items/edit/${inserted.id}`, returnTo));
    } catch (err: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error al duplicar',
        message: err?.message || 'No se pudo duplicar el item.',
      });
    } finally {
      setIsDuplicating(false);
    }
  };

  const handleBulkDeleteItems = async () => {
    if (selectedItemIds.length === 0) return;

    const confirmed = await showConfirm({
      title: 'Eliminar items seleccionados',
      message: `¿Estás seguro de que deseas eliminar ${selectedItemIds.length} item(s)? Esta acción no se puede deshacer.`,
      variant: 'danger',
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
    });
    if (!confirmed) return;

    try {
      setLoading(true);
      await deleteItems(selectedItemIds);
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Items eliminados',
        message: `${selectedItemIds.length} item(s) eliminados correctamente.`,
      });
      setSelectedItemIds([]);
      refetch();
    } catch (error) {
      const isWarning = isTemplateLinkedDeleteWarning(error);
      useUIStore.getState().addNotification({
        type: isWarning ? 'warning' : 'error',
        title: isWarning ? 'No se pueden eliminar los seleccionados' : 'Error al eliminar',
        message: isWarning ? cleanTemplateLinkedWarningMessage(error) : getErrorMessage(error),
      });
    } finally {
      setLoading(false);
    }
  };

  // Get unique filter options
  const manufacturerOptions = Array.from(new Set(displayItems.map(item => item.manufacturer).filter(Boolean)));
  const categoryOptions = Array.from(new Set(displayItems.map(item => item.category).filter(Boolean)));
  const subcategoryOptions = useMemo(() => {
    const byId = new Map(catalogCategories.map((cat) => [cat.id, cat]));
    return catalogCategories
      .filter((cat) => !cat.is_group && Boolean(cat.parent_id))
      .map((cat) => {
        const parentName = cat.parent_id ? (byId.get(cat.parent_id)?.name || 'Not specified') : 'Not specified';
        return {
          id: cat.id,
          label: `${parentName} > ${cat.name}`,
        };
      })
      .sort((a, b) => a.label.localeCompare(b.label));
  }, [catalogCategories]);
  const familyOptions = Array.from(new Set(displayItems.map(item => item.family).filter(Boolean)));
  // Category options already handled by selectedCategory
  const measureBasisOptions = Array.from(new Set(displayItems.map(item => item.measure_basis).filter(Boolean)));
  const activeOptions = ['Active', 'Inactive'];
  const stockOptions = ['In Stock', 'Out of Stock'];

  const totalActiveFilters = selectedManufacturer.length + selectedCategory.length + selectedSubcategory.length + selectedFamily.length + 
                             selectedMeasureBasis.length + selectedActive.length + selectedProductType.length + selectedStock.length;

  if (loading) return <div className="py-6 px-6" />;

  if (error) {
    return (
      <div className="py-6 px-6">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-title font-semibold text-foreground">Catalog Items</h1>
          </div>
        </div>
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-red-800">Error loading items: {error}</p>
          <button
            onClick={() => refetch()}
            className="mt-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="py-6 px-6">
      {/* Header — title + contextual actions per tab (same as Quotes/Sales) */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <h1 className="text-title font-semibold text-foreground">Catalog Items</h1>
        </div>
        <div className="flex items-center gap-3 ml-auto">
          {activeTab === 'items' && (
            <>
              <button
                onClick={() => setShowImportModal(true)}
                className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
              >
                <Upload className="w-4 h-4" />
                Import
              </button>
              {hasContextualBack && (
                <button
                  type="button"
                  onClick={handleContextualBack}
                  className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
                  title="Back"
                >
                  <ArrowLeft className="w-4 h-4" />
                  Back
                </button>
              )}
              {canCreateCat && (
                <button
                  className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
                  onClick={() => {
                    saveListStateSnapshot();
                    setCatalogItemsRestoreOnBack(true);
                    const returnTo = buildCatalogItemsReturnTo();
                    setCatalogItemsReturnTo(returnTo);
                    router.navigate(withReturnTo('/catalog/items/new', returnTo));
                  }}
                >
                  <Plus className="w-4 h-4" />
                  Add New
                </button>
              )}
            </>
          )}
          {activeTab === 'manufacturer' && (
            <button
              onClick={() => manufacturerRef.current?.openNewModal()}
              className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
              title="Add new manufacturer"
            >
              <Plus className="w-4 h-4" />
              Add New
            </button>
          )}
          {activeTab === 'categories' && (
            <>
              <button
                onClick={() => categoriesRef.current?.openNewParent()}
                className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
                title="Add parent group"
              >
                <Plus className="w-4 h-4" />
                Add New
              </button>
              <button
                onClick={() => categoriesRef.current?.openNew()}
                className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
                title="Add category"
              >
                <Plus className="w-4 h-4" />
                Add New
              </button>
            </>
          )}
          {activeTab === 'collection' && (
            <button
              onClick={() => {
                saveListStateSnapshot();
                setCatalogItemsRestoreOnBack(true);
                const returnTo = buildCatalogItemsReturnTo();
                setCatalogItemsReturnTo(returnTo);
                router.navigate(withReturnTo('/catalog/items/new?is_fabric=true', returnTo));
              }}
              className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              title="Add new collection"
            >
              <Plus className="w-4 h-4" />
              Add New
            </button>
          )}
        </div>
      </div>

      {/* Internal Tabs - same style as StatusTabs (Sales): white card, border-r dividers */}
      <div className="overflow-x-auto border border-gray-200 rounded-lg mb-4 bg-white">
        <nav className="flex min-w-0" role="tablist">
          <button
            onClick={() => setActiveTab('items')}
            className={`flex shrink-0 items-center gap-1.5 px-4 transition-colors whitespace-nowrap border-r ${
              activeTab === 'items' ? 'bg-white font-semibold' : 'font-normal hover:bg-white/50'
            }`}
            style={{
              fontSize: '12px',
              padding: '0 16px',
              height: '40px',
              color: '#1c1f26',
              borderColor: 'var(--gray-250)',
              borderBottom: activeTab === 'items' ? '2px solid var(--sidebar-base)' : '2px solid transparent',
            }}
          >
            Products
          </button>
          <button
            onClick={() => setActiveTab('manufacturer')}
            className={`flex shrink-0 items-center gap-1.5 px-4 transition-colors whitespace-nowrap border-r ${
              activeTab === 'manufacturer' ? 'bg-white font-semibold' : 'font-normal hover:bg-white/50'
            }`}
            style={{
              fontSize: '12px',
              padding: '0 16px',
              height: '40px',
              color: '#1c1f26',
              borderColor: 'var(--gray-250)',
              borderBottom: activeTab === 'manufacturer' ? '2px solid var(--sidebar-base)' : '2px solid transparent',
            }}
          >
            Manufacturers
          </button>
          <button
            onClick={() => setActiveTab('categories')}
            className={`flex shrink-0 items-center gap-1.5 px-4 transition-colors whitespace-nowrap border-r ${
              activeTab === 'categories' ? 'bg-white font-semibold' : 'font-normal hover:bg-white/50'
            }`}
            style={{
              fontSize: '12px',
              padding: '0 16px',
              height: '40px',
              color: '#1c1f26',
              borderColor: 'var(--gray-250)',
              borderBottom: activeTab === 'categories' ? '2px solid var(--sidebar-base)' : '2px solid transparent',
            }}
          >
            Categories
          </button>
          <button
            onClick={() => setActiveTab('collection')}
            className={`flex shrink-0 items-center gap-1.5 px-4 transition-colors whitespace-nowrap border-r ${
              activeTab === 'collection' ? 'bg-white font-semibold' : 'font-normal hover:bg-white/50'
            }`}
            style={{
              fontSize: '12px',
              padding: '0 16px',
              height: '40px',
              color: '#1c1f26',
              borderColor: 'var(--gray-250)',
              borderBottom: activeTab === 'collection' ? '2px solid var(--sidebar-base)' : '2px solid transparent',
            }}
          >
            Collection
          </button>
        </nav>
      </div>

      {/* Tab Content — mt-4 below Status bar (same as Quotes/Sales) */}
      {activeTab === 'items' && (
        <>
      {/* Search and Filters — Standard View A sizing */}
      <div className="mb-4 mt-4">
        <div className={`bg-white border border-gray-200 py-6 px-6 ${showFilters ? 'rounded-t-lg' : 'rounded-lg'}`}>
          <div className="flex items-center gap-3">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search by SKU, name, collection, variant, color, description, manufacturer..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
              />
            </div>
            <button
              type="button"
              onClick={() => setShowFilters(!showFilters)}
              className={`flex items-center gap-2 px-2 py-1 text-sm font-medium rounded border transition-colors ${
                showFilters || totalActiveFilters > 0
                  ? 'bg-primary text-white border-primary'
                  : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
              }`}
              title={showFilters ? 'Hide filters' : 'Show filters'}
              aria-expanded={showFilters}
            >
              <Filter style={{ width: 14, height: 14 }} />
              Filters
              {totalActiveFilters > 0 && (
                <span className="bg-white text-primary rounded-full px-2 py-0.5 text-xs font-semibold">
                  {totalActiveFilters}
                </span>
              )}
            </button>
          </div>

          {/* Filters Dropdown */}
          {showFilters && (
            <div className="mt-4 pt-4 border-t border-gray-200">
              <div className="grid grid-cols-3 gap-4 mb-4">
                {/* Measure Basis Filter */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Measure Basis</span>
                    {selectedMeasureBasis.length > 0 && (
                      <button
                        onClick={() => setSelectedMeasureBasis([])}
                        className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                      >
                        Clear ({selectedMeasureBasis.length})
                      </button>
                    )}
                  </div>
                  <div className="max-h-40 overflow-y-auto">
                    {measureBasisOptions.map((measureBasis) => (
                      <div
                        key={measureBasis}
                        onClick={() => {
                          if (!measureBasis) return;
                          setSelectedMeasureBasis(prev => 
                            prev.includes(measureBasis) 
                              ? prev.filter((m: string) => m !== measureBasis)
                              : [...prev, measureBasis]
                          );
                        }}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={measureBasis ? selectedMeasureBasis.includes(measureBasis) : false}
                          readOnly
                          className="w-4 h-4"
                        />
                        <span className="text-sm text-gray-700">{measureBasis}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Active Status Filter */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Status</span>
                    {selectedActive.length > 0 && (
                      <button
                        onClick={() => setSelectedActive([])}
                        className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                      >
                        Clear ({selectedActive.length})
                      </button>
                    )}
                  </div>
                  <div className="max-h-40 overflow-y-auto">
                    {activeOptions.map((status) => (
                      <div
                        key={status}
                        onClick={() => {
                          setSelectedActive(prev => 
                            prev.includes(status) 
                              ? prev.filter(s => s !== status)
                              : [...prev, status]
                          );
                        }}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={selectedActive.includes(status)}
                          readOnly
                          className="w-4 h-4"
                        />
                        <span className="text-sm text-gray-700">{status}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Inventory Stock Filter */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Inventory</span>
                    {selectedStock.length > 0 && (
                      <button
                        onClick={() => setSelectedStock([])}
                        className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                      >
                        Clear ({selectedStock.length})
                      </button>
                    )}
                  </div>
                  <div className="max-h-40 overflow-y-auto">
                    {stockOptions.map((status) => (
                      <div
                        key={status}
                        onClick={() => {
                          setSelectedStock((prev) =>
                            prev.includes(status)
                              ? prev.filter((s) => s !== status)
                              : [...prev, status]
                          );
                        }}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={selectedStock.includes(status)}
                          readOnly
                          className="w-4 h-4"
                        />
                        <span className="text-sm text-gray-700">{status}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Manufacturer Filter */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Manufacturer</span>
                    {selectedManufacturer.length > 0 && (
                      <button
                        onClick={() => setSelectedManufacturer([])}
                        className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                      >
                        Clear ({selectedManufacturer.length})
                      </button>
                    )}
                  </div>
                  <div className="max-h-40 overflow-y-auto">
                    {manufacturerOptions.map((manufacturer) => (
                      <div
                        key={manufacturer}
                        onClick={() => handleManufacturerToggle(manufacturer || '')}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={manufacturer ? selectedManufacturer.includes(manufacturer) : false}
                          readOnly
                          className="w-4 h-4"
                        />
                        <span className="text-sm text-gray-700">{manufacturer}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Product Type Filter */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Product Type</span>
                    {selectedProductType.length > 0 && (
                      <button
                        onClick={() => setSelectedProductType([])}
                        className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                      >
                        Clear ({selectedProductType.length})
                      </button>
                    )}
                  </div>
                  <div className="max-h-40 overflow-y-auto">
                    {productTypeLabels.map((pt) => (
                      <div
                        key={pt}
                        onClick={() => {
                          setSelectedProductType(prev =>
                            prev.includes(pt)
                              ? prev.filter(p => p !== pt)
                              : [...prev, pt]
                          );
                        }}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={selectedProductType.includes(pt)}
                          readOnly
                          className="w-4 h-4"
                        />
                        <span className="text-sm text-gray-700">{pt}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Category Filter */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Category</span>
                    {selectedCategory.length > 0 && (
                      <button
                        onClick={() => setSelectedCategory([])}
                        className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                      >
                        Clear ({selectedCategory.length})
                      </button>
                    )}
                  </div>
                  <div className="max-h-40 overflow-y-auto">
                    {categoryOptions.map((category) => (
                      <div
                        key={category}
                        onClick={() => handleCategoryToggle(category || '')}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={category ? selectedCategory.includes(category) : false}
                          readOnly
                          className="w-4 h-4"
                        />
                        <span className="text-sm text-gray-700">{category}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Family Filter */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Family</span>
                    {selectedFamily.length > 0 && (
                      <button
                        onClick={() => setSelectedFamily([])}
                        className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                      >
                        Clear ({selectedFamily.length})
                      </button>
                    )}
                  </div>
                  <div className="max-h-40 overflow-y-auto">
                    {familyOptions.map((family) => (
                      <div
                        key={family}
                        onClick={() => handleFamilyToggle(family || '')}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={family ? selectedFamily.includes(family) : false}
                          readOnly
                          className="w-4 h-4"
                        />
                        <span className="text-sm text-gray-700">{family}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Sub Category Filter */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Sub Category</span>
                    {selectedSubcategory.length > 0 && (
                      <button
                        onClick={() => setSelectedSubcategory([])}
                        className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                      >
                        Clear ({selectedSubcategory.length})
                      </button>
                    )}
                  </div>
                  <div className="max-h-40 overflow-y-auto">
                    {subcategoryOptions.map((subcategory) => (
                      <div
                        key={subcategory.id}
                        onClick={() => handleSubcategoryToggle(subcategory.id)}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={selectedSubcategory.includes(subcategory.id)}
                          readOnly
                          className="w-4 h-4"
                        />
                        <span className="text-sm text-gray-700">{subcategory.label}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
              <div className="flex justify-between items-center">
                <button 
                  onClick={clearAllFilters}
                  className="text-xs text-gray-500 hover:text-gray-700"
                >
                  Clear all filters
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Bulk actions */}
      {selectedItemsCount > 0 && (
        <div className="bg-primary/5 border border-primary/20 rounded-lg px-4 py-3 mb-3 flex items-center justify-between">
          <span className="text-sm text-gray-800">{selectedItemsCount} item(s) selected</span>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setSelectedItemIds([])}
              className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded hover:bg-gray-50"
            >
              Clear selection
            </button>
            <button
              onClick={openMoveCategoryModal}
              className="px-3 py-1.5 text-sm font-medium text-white bg-primary rounded hover:bg-primary/90"
            >
              Move category
            </button>
            {canDeleteCat && (
              <button
                onClick={handleBulkDeleteItems}
                disabled={isDeleting}
                className="px-3 py-1.5 text-sm font-medium text-white bg-red-600 rounded hover:bg-red-700 disabled:opacity-50"
              >
                Delete selected
              </button>
            )}
          </div>
        </div>
      )}

      {/* Table View */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
          <div className="table-fit-wrapper">
            <table className="table-fit">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs w-10">
                    <input
                      type="checkbox"
                      checked={allPageSelected}
                      onChange={toggleSelectAllPage}
                      aria-label="Select all items on this page"
                    />
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs w-16">Image</th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('sku')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      SKU
                      {sortBy === 'sku' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('itemName')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Name
                      {sortBy === 'itemName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-center py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('category')}
                      className="flex items-center gap-1 hover:text-gray-700 mx-auto"
                    >
                      Category
                      {sortBy === 'category' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-center py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('measure_basis')}
                      className="flex items-center gap-1 hover:text-gray-700 mx-auto"
                    >
                      Measure Basis
                      {sortBy === 'measure_basis' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-center py-3 px-4 font-medium text-gray-900 text-xs">MSRP</th>
                  <th className="text-center py-3 px-4 font-medium text-gray-900 text-xs">Last Updated</th>
                  <th className="text-center py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('active')}
                      className="flex items-center gap-1 hover:text-gray-700 mx-auto"
                    >
                      Status
                      {sortBy === 'active' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-center py-3 px-4 font-medium text-gray-900 text-xs">Availability</th>
                  <th className="text-right py-3 px-4 font-medium text-gray-900 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredItems.length === 0 ? (
                  <tr>
                    <td colSpan={11} className="py-12 px-6 text-center">
                      <div className="flex flex-col items-center">
                        <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mb-4">
                          <Search className="w-6 h-6 text-gray-400" />
                        </div>
                        <p className="text-gray-600 mb-2">No items found</p>
                        <p className="text-sm text-gray-500">
                          {displayItems.length === 0 
                            ? 'Start by adding items'
                            : 'Try adjusting your search criteria'}
                        </p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  paginatedItems.map((item) => (
                    <tr
                      key={item.id}
                      ref={rowRefForViewport(item.id)}
                      tabIndex={0}
                      role="row"
                      onMouseEnter={() => warmDetail(item.id)}
                      onFocus={() => warmDetail(item.id)}
                      className="border-b border-gray-100 hover:bg-gray-50 transition-colors"
                    >
                      <td className="py-3 px-4">
                        <input
                          type="checkbox"
                          checked={selectedItemIds.includes(item.id)}
                          onChange={() => toggleSelectItem(item.id)}
                          onClick={(e) => e.stopPropagation()}
                          aria-label={`Select ${item.itemName}`}
                        />
                      </td>
                      <td className="py-3 px-4">
                        {item.image ? (
                          <div 
                            className="w-10 h-10 rounded border border-gray-200 overflow-hidden cursor-pointer hover:opacity-80 transition-opacity"
                            onClick={() => setSelectedImage(item.image || null)}
                          >
                            <img 
                              src={item.image} 
                              alt={item.itemName || 'Item image'} 
                              className="w-full h-full object-cover"
                              loading="lazy"
                              decoding="async"
                              onError={(e) => {
                                if (import.meta.env.DEV) {
                                  console.error('Image load error for item:', item.sku, 'URL:', item.image);
                                }
                                (e.target as HTMLImageElement).style.display = 'none';
                              }}
                              onLoad={() => {
                                if (import.meta.env.DEV) {
                                  console.log('✅ Image loaded successfully for item:', item.sku);
                                }
                              }}
                            />
                          </div>
                        ) : (
                          <div className="w-10 h-10 rounded border border-gray-200 bg-gray-50 flex items-center justify-center">
                            <ImageIcon className="w-4 h-4 text-gray-400" />
                          </div>
                        )}
                      </td>
                      {/* ✅ OPTIMIZACIÓN: Todos los campos tienen valores por defecto para evitar mostrar vacíos */}
                      <td className="py-3 px-4 text-gray-900 text-xs font-medium">
                        {item.sku || 'N/A'}
                      </td>
                      <td className="py-3 px-4 text-gray-700 text-xs">
                        {item.itemName || 'N/A'}
                      </td>
                      <td className="py-3 px-4 text-center text-gray-700 text-xs">
                        <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800">
                          {item.category || 'N/A'}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-center text-gray-700 text-xs">
                        {item.measure_basis || 'N/A'}
                      </td>
                      <td className="py-3 px-4 text-center text-gray-700 text-xs">
                        {item.msrp != null && item.msrp !== undefined && !isNaN(item.msrp)
                          ? `$${item.msrp.toFixed(2)}${item.msrpUnitLabel || ''}`
                          : '$0.00'}
                      </td>
                      <td className="py-3 px-4 text-center text-gray-700 text-xs">
                        {item.updated_at ? formatDate(item.updated_at) : 'N/A'}
                      </td>
                      <td className="py-3 px-4 text-center text-gray-700 text-xs">
                        {/* ✅ OPTIMIZACIÓN: Asegurar que active esté definido antes de renderizar */}
                        {item.active !== undefined && item.active !== null ? (
                          <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                            item.active 
                              ? 'bg-green-100 text-green-800' 
                              : 'bg-red-100 text-red-800'
                          }`}>
                            {item.active ? 'Active' : 'Inactive'}
                          </span>
                        ) : (
                          <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
                            Active
                          </span>
                        )}
                      </td>
                      <td className="py-3 px-4 text-center">
                        <InventoryAvailabilityBadge row={availabilityMap[item.id]} />
                      </td>
                      <td className="py-3 px-4" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center gap-1 justify-end">
                          <button 
                            onClick={(e) => handleEditItem(item, e)}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            aria-label={`Edit ${item.itemName}`}
                            title={`Edit ${item.itemName}`}
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button
                            onClick={(e) => handleDuplicateItem(item, e)}
                            disabled={isDuplicating}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                            aria-label={`Duplicate ${item.itemName}`}
                            title={`Duplicate ${item.itemName}`}
                          >
                            <Copy className="w-4 h-4" />
                          </button>
                          {canArchiveCat && (
                            <button 
                              onClick={(e) => handleArchiveItem(item, e)}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                              aria-label={`Archive ${item.itemName}`}
                              title={`Archive ${item.itemName}`}
                            >
                              <Archive className="w-4 h-4" />
                            </button>
                          )}
                          {canDeleteCat && (
                            <button 
                              onClick={(e) => handleDeleteItem(item, e)}
                              disabled={isDeleting}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                              aria-label={`Delete ${item.itemName}`}
                              title={`Delete ${item.itemName}`}
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
      </div>

      {/* Pagination */}
      <div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="text-sm text-gray-700">Show:</span>
            <select
              value={itemsPerPage}
              onChange={(e) => {
                setItemsPerPage(Number(e.target.value));
                setCurrentPage(1);
              }}
              className="px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
            >
              <option value={10}>10</option>
              <option value={25}>25</option>
              <option value={50}>50</option>
              <option value={100}>100</option>
            </select>
            <span className="text-sm text-gray-700">
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredItems.length)} of {filteredItems.length}
              {loadingMore && (
                <span className="ml-2 text-xs text-gray-500">
                  <span className="inline-block animate-spin rounded-full h-3 w-3 border-b-2 border-primary mr-1"></span>
                  Loading more items...
                </span>
              )}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
              disabled={currentPage === 1}
              className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              Previous
            </button>
            <span className="text-sm text-gray-700">
              Page {currentPage} of {totalPages || 1}
            </span>
            <button
              onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
              disabled={currentPage >= totalPages}
              className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              Next
            </button>
          </div>
        </div>
      </div>

      {/* Move category modal */}
      {showMoveCategoryModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Move selected items</h3>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Category <span className="text-red-500">*</span>
                </label>
                <select
                  value={bulkParentCategoryId}
                  onChange={(e) => {
                    setBulkParentCategoryId(e.target.value);
                    setBulkTargetSubcategoryId('');
                  }}
                  className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                >
                  <option value="">Select category</option>
                  {parentCatalogCategories.map((cat: any) => (
                    <option key={cat.id} value={cat.id}>
                      {cat.name}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Subcategory <span className="text-red-500">*</span>
                </label>
                <select
                  value={bulkTargetSubcategoryId}
                  onChange={(e) => setBulkTargetSubcategoryId(e.target.value)}
                  disabled={!bulkParentCategoryId}
                  className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent disabled:bg-gray-100"
                >
                  <option value="">{bulkParentCategoryId ? 'Select subcategory' : 'Select category first'}</option>
                  {subcategoriesByParent.map((sub: any) => (
                    <option key={sub.id} value={sub.id}>
                      {sub.name}
                    </option>
                  ))}
                </select>
              </div>
              <p className="text-xs text-gray-500">{selectedItemsCount} item(s) will be moved.</p>
            </div>
            <div className="flex justify-end gap-2 mt-6">
              <button
                onClick={closeMoveCategoryModal}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={handleBulkMoveCategory}
                disabled={!bulkTargetSubcategoryId || isBulkMoving}
                className="px-4 py-2 text-sm font-medium text-white bg-primary rounded hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isBulkMoving ? 'Moving...' : 'Move'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Import Modal */}
      <ImportCatalog
        isOpen={showImportModal}
        onClose={() => setShowImportModal(false)}
        onImportComplete={() => {
          setShowImportModal(false);
          refetch();
        }}
      />
        </>
      )}

      {activeTab === 'manufacturer' && (
        <div className="mt-4">
          <Manufacturers ref={manufacturerRef} />
        </div>
      )}
      {activeTab === 'categories' && (
        <div className="mt-4">
          <Categories ref={categoriesRef} itemsForCounts={items} />
        </div>
      )}
      {activeTab === 'collection' && (
        <div className="mt-4">
          <Collections />
        </div>
      )}

      {/* Confirm Dialog */}
      <ConfirmDialog
        isOpen={dialogState.isOpen}
        onClose={closeDialog}
        onConfirm={handleConfirm}
        title={dialogState.title}
        message={dialogState.message}
        confirmText={dialogState.confirmText}
        cancelText={dialogState.cancelText}
        variant={dialogState.variant}
        isLoading={dialogState.isLoading}
      />

      {/* Image Modal */}
      {selectedImage && (
        <ImageModal 
          imageUrl={selectedImage} 
          alt="Item image"
          onClose={() => setSelectedImage(null)} 
        />
      )}
    </div>
  );
}

