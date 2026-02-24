import { useEffect, useState, useMemo, useCallback } from 'react';
import { router } from '../../lib/router';

import { useQuotes, approveQuote, waitForSalesOrder, type QuoteListItem } from '../../hooks/useQuotes';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAccessContext } from '../../hooks/useAccessContext';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { getSupabaseErrorMessage, isRLSError, safeError } from '../../lib/supabase-error-utils';
import { 
  Search, Plus, Upload, List, Grid3X3, Edit, Trash2, Archive, RotateCcw,
  ShoppingCart, FileText, RefreshCw, Filter,
  SortAsc, SortDesc, Eye
} from 'lucide-react';
import { QuoteStatus } from '../../types/catalog';
import StatusBadge from '../../components/shared/StatusBadge';
import StatusTabs from '../../components/shared/StatusTabs';

/** Usado en la tabla; mismo shape que useQuotes devuelve (QuoteListItem) */
type EnrichedQuote = QuoteListItem;

const getStatusBadgeColor = (status: QuoteStatus) => {
  switch (status) {
    case 'draft': return 'bg-gray-100 text-gray-700';
    case 'sent': return 'bg-blue-100 text-blue-700';
    case 'approved': return 'bg-green-100 text-green-700';
    case 'rejected': return 'bg-red-100 text-red-700';
    case 'cancelled': return 'bg-orange-100 text-orange-700';
    default: return 'bg-gray-100 text-gray-700';
  }
};

const formatCurrency = (amount: number) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  }).format(amount || 0);
};

export default function Quotes() {
  const { activeOrganizationId } = useOrganizationContext();
  const { isInternal } = useAccessContext();
  const { dialogState, showConfirm, closeDialog, setLoading: setDialogLoading, handleConfirm } = useConfirmDialog();

  // Una sola fuente de verdad: filtro por dealer y enriquecimiento en useQuotes
  const { quotes: hookQuotes, loading, error, refetch } = useQuotes();
  const setGlobalLoading = useUIStore((s) => s.setGlobalLoading);

  const [dealerById, setDealerById] = useState<Record<string, { dealer_name: string; dealer_no?: string | null }>>({});
  useEffect(() => {
    if (!isInternal || hookQuotes.length === 0) {
      setDealerById({});
      return;
    }
    const dealerIds = [...new Set(hookQuotes.map((q) => q.dealer_id).filter(Boolean))] as string[];
    if (dealerIds.length === 0) {
      setDealerById({});
      return;
    }
    (async () => {
      const { data } = await supabase.from('Dealers').select('id, dealer_name, dealer_no').in('id', dealerIds);
      const map: Record<string, { dealer_name: string; dealer_no?: string | null }> = {};
      (data || []).forEach((r: { id: string; dealer_name?: string; dealer_no?: string | null }) => {
        map[r.id] = { dealer_name: r.dealer_name ?? '—', dealer_no: r.dealer_no ?? null };
      });
      setDealerById(map);
    })();
  }, [isInternal, hookQuotes]);

  useEffect(() => {
    setGlobalLoading(loading);
    return () => setGlobalLoading(false);
  }, [loading, setGlobalLoading]);

  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);
  const [sortBy, setSortBy] = useState<'quote_no' | 'status' | 'customer_name' | 'total' | 'created_at'>('created_at');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [selectedStatus, setSelectedStatus] = useState<QuoteStatus[]>([]);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [statusTab, setStatusTab] = useState('all');

  const quotes = hookQuotes;

  const [proposalStatusMap, setProposalStatusMap] = useState<Record<string, string>>({});
  const [soNumberMap, setSONumberMap] = useState<Record<string, { id: string; no: string }>>({});

  useEffect(() => {
    if (!quotes.length || !activeOrganizationId) return;
    const ids = quotes.map(q => q.id);

    supabase
      .from('Proposals')
      .select('quote_id, status')
      .in('quote_id', ids)
      .or('deleted.is.false,deleted.is.null')
      .order('updated_at', { ascending: false })
      .then(({ data }: { data: any }) => {
        if (!data) return;
        const m: Record<string, string> = {};
        data.forEach((p: any) => { if (!m[p.quote_id]) m[p.quote_id] = p.status; });
        setProposalStatusMap(m);
      });

    supabase
      .from('SalesOrders')
      .select('id, quote_id, sales_order_no')
      .in('quote_id', ids)
      .eq('deleted', false)
      .then(({ data }: { data: any }) => {
        if (!data) return;
        const m: Record<string, { id: string; no: string }> = {};
        data.forEach((so: any) => { if (so.quote_id) m[so.quote_id] = { id: so.id, no: so.sales_order_no }; });
        setSONumberMap(m);
      });
  }, [quotes, activeOrganizationId]);

  const nonArchivedQuotes = useMemo(() => quotes.filter((q) => !(q as EnrichedQuote).archived), [quotes]);
  const archivedQuotesCount = useMemo(() => quotes.filter((q) => (q as EnrichedQuote).archived).length, [quotes]);

  const statusTabCounts = useMemo(() => {
    const counts: Record<string, number> = { all: nonArchivedQuotes.length };
    nonArchivedQuotes.forEach((q) => {
      counts[q.status] = (counts[q.status] || 0) + 1;
    });
    return counts;
  }, [nonArchivedQuotes]);

  const quotesStatusTabs = useMemo(
    () => [
      { label: 'All', value: 'all', count: statusTabCounts.all || 0 },
      { label: 'Draft', value: 'draft', count: statusTabCounts.draft || 0 },
      { label: 'Pending Confirmation', value: 'approved', count: statusTabCounts.approved || 0 },
      { label: 'Confirmed', value: 'converted', count: statusTabCounts.converted || 0 },
      { label: 'Cancelled', value: 'cancelled', count: (statusTabCounts.cancelled || 0) + (statusTabCounts.canceled || 0) },
      { label: 'Expired', value: 'expired', count: statusTabCounts.expired || 0 },
      { label: 'Archived', value: 'archived', count: archivedQuotesCount },
    ],
    [statusTabCounts, archivedQuotesCount]
  );

  /** Solo se puede archivar cuando el status es cancelled, rejected o expired */
  const canArchiveQuote = useCallback((q: EnrichedQuote) => {
    const s = (q.status || '').toLowerCase();
    return s === 'cancelled' || s === 'canceled' || s === 'rejected' || s === 'expired';
  }, []);

  /** Returns quote IDs that have at least one (non-deleted) proposal */
  const getQuoteIdsWithProposals = useCallback(async (quoteIds: string[]): Promise<Set<string>> => {
    if (quoteIds.length === 0) return new Set();
    const { data } = await supabase
      .from('Proposals')
      .select('quote_id')
      .in('quote_id', quoteIds)
      .or('deleted.is.false,deleted.is.null');
    const set = new Set<string>();
    (data || []).forEach((r: { quote_id: string }) => set.add(r.quote_id));
    return set;
  }, []);

  // ✅ registerSubmodules se maneja en SalesDirectory.tsx (wrapper)

  // Limpiar selección cuando los IDs ya no están en la lista (p. ej. tras borrar)
  const quoteIds = useMemo(() => new Set(quotes.map((q) => q.id)), [quotes]);
  useEffect(() => {
    setSelectedIds((prev) => {
      let changed = false;
      const next = new Set(prev);
      next.forEach((id) => {
        if (!quoteIds.has(id)) {
          next.delete(id);
          changed = true;
        }
      });
      return changed ? next : prev;
    });
  }, [quoteIds]);

  // === DELETE HANDLER ===
  const handleDelete = async (quote: EnrichedQuote, e: React.MouseEvent) => {
    e.stopPropagation();
    
    if (quote.status === 'approved') {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'No permitido',
        message: 'No se puede eliminar una cotización aprobada.',
      });
      return;
    }

    const idsWithProposals = await getQuoteIdsWithProposals([quote.id]);
    if (idsWithProposals.has(quote.id)) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'No se puede eliminar',
        message: 'Esta cotización tiene propuestas asociadas. Elimine primero las propuestas desde la lista de Proposals.',
      });
      return;
    }

    const confirmed = await showConfirm({
      title: 'Eliminar Cotización',
      message: `¿Eliminar la cotización ${quote.quote_no}?`,
      variant: 'danger',
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
    });

    if (!confirmed) return;

    try {
      setDialogLoading(true);

      const { data, error } = await supabase.rpc('soft_delete_quotes', { p_quote_ids: [quote.id] });
      if (error) throw error;
      if (data !== 1 && data != null) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: 'Cotización no encontrada o sin permiso para eliminar.',
        });
        await refetch();
        return;
      }

      setSelectedIds((prev) => {
        const next = new Set(prev);
        next.delete(quote.id);
        return next;
      });
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Eliminado',
        message: 'Cotización eliminada correctamente',
      });

      await refetch();
    } catch (err) {
      console.error('[Quotes] Delete catch:', safeError(err));
      refetch();
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: getSupabaseErrorMessage(err),
      });
    } finally {
      setDialogLoading(false);
    }
  };

  const handleArchive = useCallback(
    async (quote: EnrichedQuote, e: React.MouseEvent) => {
      e.stopPropagation();
      if (!canArchiveQuote(quote)) return;
      const confirmed = await showConfirm({
        title: 'Archivar cotización',
        message: `¿Archivar ${quote.quote_no}? No se eliminará, solo se ocultará de la lista activa.`,
        variant: 'info',
        confirmText: 'Archivar',
        cancelText: 'Cancelar',
      });
      if (!confirmed) return;
      try {
        setDialogLoading(true);
        const { error: err } = await supabase.from('Quotes').update({ archived: true }).eq('id', quote.id);
        if (err) throw err;
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Archivado',
          message: 'Cotización archivada correctamente.',
        });
        await refetch();
      } catch (err: any) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: getSupabaseErrorMessage(err),
        });
      } finally {
        setDialogLoading(false);
      }
    },
    [showConfirm, setDialogLoading, refetch, canArchiveQuote]
  );

  const handleRestore = useCallback(
    async (quote: EnrichedQuote, e: React.MouseEvent) => {
      e.stopPropagation();
      const confirmed = await showConfirm({
        title: 'Restaurar cotización',
        message: `¿Restaurar ${quote.quote_no}? Volverá a la lista activa.`,
        variant: 'info',
        confirmText: 'Restaurar',
        cancelText: 'Cancelar',
      });
      if (!confirmed) return;
      try {
        setDialogLoading(true);
        const { error: err } = await supabase.from('Quotes').update({ archived: false }).eq('id', quote.id);
        if (err) throw err;
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Restaurado',
          message: 'Cotización restaurada correctamente.',
        });
        await refetch();
      } catch (err: any) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: getSupabaseErrorMessage(err),
        });
      } finally {
        setDialogLoading(false);
      }
    },
    [showConfirm, setDialogLoading, refetch]
  );

  // === BULK DELETE ===
  const handleDeleteSelected = useCallback(async () => {
    const ids = Array.from(selectedIds);
    if (ids.length === 0) return;
    const idsWithProposals = await getQuoteIdsWithProposals(ids);
    if (idsWithProposals.size > 0) {
      const quotesWithProposals = quotes.filter((q) => idsWithProposals.has(q.id));
      const list = quotesWithProposals.map((q) => q.quote_no).join(', ');
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'No se puede eliminar',
        message: `Las siguientes cotizaciones tienen propuestas asociadas. Elimine primero las propuestas desde Proposals: ${list}`,
      });
      return;
    }
    const confirmed = await showConfirm({
      title: 'Eliminar cotizaciones',
      message: `¿Eliminar ${ids.length} cotización(es) seleccionada(s)?`,
      variant: 'danger',
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
    });
    if (!confirmed) return;
    try {
      setDialogLoading(true);
      const { data, error } = await supabase.rpc('soft_delete_quotes', { p_quote_ids: ids });
      if (error) throw error;
      if (data != null && Number(data) < ids.length) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: 'Algunas cotizaciones no se pudieron eliminar (sin permiso).',
        });
      } else {
        setSelectedIds(new Set());
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Eliminado',
          message: `${data ?? ids.length} cotización(es) eliminada(s).`,
        });
      }
      await refetch();
    } catch (err: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: getSupabaseErrorMessage(err),
      });
    } finally {
      setDialogLoading(false);
    }
  }, [selectedIds, getQuoteIdsWithProposals, quotes, showConfirm, refetch, setDialogLoading]);

  // === EDIT HANDLER ===
  const handleEdit = (quote: EnrichedQuote, e: React.MouseEvent) => {
    e.stopPropagation();
    router.navigate(`/sales/quotes/${quote.id}/edit`);
  };

  // === CREATE SALE ORDER HANDLER ===
  const handleCreateSaleOrder = async (quote: EnrichedQuote, e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      if (quote.status !== 'approved') {
        const error = await approveQuote(quote.id, activeOrganizationId!);
        if (error) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Error',
            message: 'No se pudo aprobar la cotización.',
          });
          return;
        }
      }

      const salesOrder = await waitForSalesOrder(quote.id, activeOrganizationId!);
      if (salesOrder) {
        router.navigate(`/sales/orders/${salesOrder.id}`);
      } else {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: 'No se pudo crear la orden de venta.',
        });
      }
    } catch (err) {
      console.error('[Quotes] Create sale order error:', safeError(err));
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Ocurrió un error al crear la orden de venta.',
      });
    }
  };

  // === SORTING ===
  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) {
      setSortOrder(prev => prev === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('asc');
    }
  };

  // === STATUS TOGGLE ===
  const handleStatusToggle = (status: QuoteStatus) => {
    setSelectedStatus(prev => 
      prev.includes(status) 
        ? prev.filter(s => s !== status)
        : [...prev, status]
    );
  };

  // === FILTERED & SORTED QUOTES ===
  const filteredQuotes = useMemo(() => {
    let result: EnrichedQuote[];

    if (statusTab === 'archived') {
      result = quotes.filter((q) => (q as EnrichedQuote).archived).map((q) => q as EnrichedQuote);
    } else {
      result = [...nonArchivedQuotes] as EnrichedQuote[];
      // StatusTabs filter (primary)
      if (statusTab !== 'all') {
        if (statusTab === 'cancelled') {
          result = result.filter((q) => q.status === 'cancelled' || q.status === ('canceled' as any));
        } else {
          result = result.filter((q) => q.status === statusTab);
        }
      }
    }

    // Search filter
    if (searchTerm) {
      const term = searchTerm.toLowerCase();
      result = result.filter(q => 
        q.quote_no?.toLowerCase().includes(term) ||
        q.customer_name?.toLowerCase().includes(term) ||
        q.contact_name?.toLowerCase().includes(term) ||
        q.status?.toLowerCase().includes(term)
      );
    }

    // Legacy status filter (from filter panel)
    if (selectedStatus.length > 0) {
      result = result.filter(q => selectedStatus.includes(q.status));
    }

    // Sort
    result = [...result].sort((a, b) => {
      const factor = sortOrder === 'asc' ? 1 : -1;
      
      if (sortBy === 'created_at') {
        return (new Date(a.created_at).getTime() - new Date(b.created_at).getTime()) * factor;
      }
      if (sortBy === 'total') {
        return (a.total - b.total) * factor;
      }
      
      const aVal = String(a[sortBy] || '').toLowerCase();
      const bVal = String(b[sortBy] || '').toLowerCase();
      return aVal.localeCompare(bVal) * factor;
    });

    return result;
  }, [quotes, nonArchivedQuotes, searchTerm, selectedStatus, sortBy, sortOrder, statusTab]);

  // Pagination
  const totalPages = Math.ceil(filteredQuotes.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedQuotes = filteredQuotes.slice(startIndex, startIndex + itemsPerPage);

  const toggleSelect = useCallback((id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);
  const toggleSelectAll = useCallback(() => {
    const pageIds = paginatedQuotes.map((q) => q.id);
    const allSelected = pageIds.every((id) => selectedIds.has(id));
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (allSelected) pageIds.forEach((id) => next.delete(id));
      else pageIds.forEach((id) => next.add(id));
      return next;
    });
  }, [paginatedQuotes, selectedIds]);

  const statusOptions: QuoteStatus[] = ['draft', 'sent', 'approved', 'rejected', 'cancelled'];

  // === RENDER ===
  // ✅ NUNCA retornar vacío por loading — usar overlay en su lugar (igual que Directory)

  if (error && !loading) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-6">
          <h3 className="text-red-800 font-medium mb-2">Error al cargar cotizaciones</h3>
          <p className="text-red-700 text-sm mb-4">{error}</p>
          <button
            onClick={() => refetch()}
            className="flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 text-sm"
          >
            <RefreshCw className="w-4 h-4" />
            Reintentar
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="py-6 px-6">
      {/* Header: design system — title + subtitle (mb-1); actions ml-auto; same spacing as Proposals/Orders */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Quotes</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Create and manage quotes
          </p>
        </div>
        <div className="flex items-center gap-3 ml-auto">
          {selectedIds.size > 0 && (
            <button
              onClick={handleDeleteSelected}
              className="flex items-center gap-2 px-2 py-1 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 text-sm transition-colors"
            >
              <Trash2 style={{ width: 14, height: 14 }} />
              Eliminar seleccionados ({selectedIds.size})
            </button>
          )}
          <button className="flex items-center gap-2 px-2 py-1 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 text-sm transition-colors">
            <Upload style={{ width: 14, height: 14 }} />
            Import
          </button>
          <button
            onClick={() => router.navigate('/sales/quotes/new')}
            className="flex items-center gap-2 px-2 py-1 rounded text-white text-sm hover:opacity-90 transition-colors"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            <Plus style={{ width: 14, height: 14 }} />
            Add Quote
          </button>
        </div>
      </div>

      <StatusTabs tabs={quotesStatusTabs} activeTab={statusTab} onChange={setStatusTab} />

      {/* Search and Filters — card py-6 px-6; botones px-2 py-1, icon 14px */}
      <div className="mb-4 mt-4">
        <div className={`bg-white border border-gray-200 py-6 px-6 ${showFilters ? 'rounded-t-lg' : 'rounded-lg'}`}>
          <div className="flex items-center gap-3">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Buscar por número, cliente o contacto..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
              />
            </div>
            <button
              onClick={() => setShowFilters(!showFilters)}
              className={`flex items-center gap-2 px-2 py-1 text-sm font-medium rounded border transition-colors ${
                showFilters || selectedStatus.length > 0
                  ? 'bg-blue-600 text-white border-blue-600'
                  : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
              }`}
            >
              <Filter style={{ width: 14, height: 14 }} />
              Filters
              {selectedStatus.length > 0 && (
                <span className="bg-white text-blue-600 rounded-full px-2 py-0.5 text-xs font-semibold">
                  {selectedStatus.length}
                </span>
              )}
            </button>
            <button
              onClick={() => refetch()}
              className="flex items-center justify-center p-2 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 transition-colors"
              title="Actualizar"
            >
              <RefreshCw style={{ width: 14, height: 14 }} />
            </button>
          </div>

          {/* Filters Panel */}
          {showFilters && (
            <div className="mt-4 pt-4 border-t border-gray-200">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-medium text-gray-700">Status</span>
                {selectedStatus.length > 0 && (
                  <button
                    onClick={() => setSelectedStatus([])}
                    className="text-xs text-gray-500 hover:text-gray-700"
                  >
                    Limpiar
                  </button>
                )}
              </div>
              <div className="flex flex-wrap gap-2">
                {statusOptions.map((status) => (
                  <button
                    key={status}
                    onClick={() => handleStatusToggle(status)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                      selectedStatus.includes(status)
                        ? getStatusBadgeColor(status)
                        : 'bg-gray-50 text-gray-700 hover:bg-gray-100'
                    }`}
                  >
                    {status.charAt(0).toUpperCase() + status.slice(1)}
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Table */}
      <div className="relative bg-white border border-gray-200 rounded-lg overflow-hidden mb-4 min-h-[300px]">
        {/* ✅ Overlay de loading — nunca desmontar la tabla */}
        {loading && (
          <div className="absolute inset-0 bg-white/90 z-10 flex items-center justify-center rounded-lg">
            <div className="flex flex-col items-center gap-3">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
              <p className="text-sm text-gray-600 font-medium">Loading...</p>
            </div>
          </div>
        )}
        <div className="table-fit-wrapper quotes-table-wrapper">
          <table className="table-fit">
            <colgroup>
              <col style={{ width: '4%' }} />
              <col style={{ width: '11%' }} />
              <col style={{ width: '9%' }} />
              {isInternal ? (
                <>
                  <col style={{ width: '11%' }} />
                  <col style={{ width: '7%' }} />
                </>
              ) : (
                <col style={{ width: '12%' }} />
              )}
              <col style={{ width: '9%' }} />
              <col style={{ width: '8%' }} />
              <col style={{ width: '7%' }} />
              <col style={{ width: '10%' }} />
              <col style={{ width: '11%' }} />
              <col style={{ width: '9%' }} />
            </colgroup>
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="py-3 px-4 text-center">
                  <input
                    type="checkbox"
                    checked={paginatedQuotes.length > 0 && paginatedQuotes.every((q) => selectedIds.has(q.id))}
                    onChange={toggleSelectAll}
                    className="rounded border-gray-300"
                  />
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs">
                  <button onClick={() => handleSort('quote_no')} className="flex items-center gap-1 hover:text-gray-900">
                    Quote #
                    {sortBy === 'quote_no' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">
                  <button onClick={() => handleSort('status')} className="flex items-center gap-1 hover:text-gray-900 justify-center w-full">
                    Status
                    {sortBy === 'status' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                {isInternal ? (
                  <>
                    <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Dealer</th>
                    <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Dealer No</th>
                  </>
                ) : (
                  <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">
                    <button onClick={() => handleSort('customer_name')} className="flex items-center gap-1 hover:text-gray-900 justify-center w-full">
                      Customer
                      {sortBy === 'customer_name' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                )}
                <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Proposal</th>
                <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">SO #</th>
                <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Priority</th>
                <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">
                  <button onClick={() => handleSort('created_at')} className="flex items-center gap-1 hover:text-gray-900 justify-center w-full">
                    Date
                    {sortBy === 'created_at' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">
                  <button onClick={() => handleSort('total')} className="flex items-center gap-1 hover:text-gray-900 justify-center w-full">
                    Total
                    {sortBy === 'total' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-right py-3 px-4 font-medium text-gray-700 text-xs">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {paginatedQuotes.length === 0 ? (
                <tr>
                  <td colSpan={isInternal ? 11 : 10} className="py-12 px-4 text-center">
                    <div className="flex flex-col items-center">
                      <Search className="w-12 h-12 text-gray-300 mb-4" />
                      <p className="text-gray-600 mb-2">No se encontraron cotizaciones</p>
                      <p className="text-sm text-gray-400">
                        {quotes.length === 0 
                          ? 'Crea tu primera cotización' 
                          : 'Intenta con otros términos de búsqueda'}
                      </p>
                    </div>
                  </td>
                </tr>
              ) : (
                paginatedQuotes.map((quote) => (
                  <tr key={quote.id} className="hover:bg-gray-50">
                    <td className="py-4 px-4 text-center" onClick={(e) => e.stopPropagation()}>
                      <input
                        type="checkbox"
                        checked={selectedIds.has(quote.id)}
                        onChange={() => toggleSelect(quote.id)}
                        className="rounded border-gray-300"
                      />
                    </td>
                    <td className="py-4 px-4 text-gray-900 text-sm font-medium text-left">
                      <button
                        onClick={(e) => { e.stopPropagation(); router.navigate(`/sales/quotes/${quote.id}`); }}
                        className="text-primary hover:underline"
                      >
                        {quote.quote_no}
                      </button>
                    </td>
                    <td className="py-4 px-4 text-center">
                      <StatusBadge status={quote.status} type="quote" size="sm" />
                    </td>
                    {isInternal ? (
                      <>
                        <td className="py-4 px-4 text-gray-700 text-sm text-center"><span className="block truncate">{quote.dealer_id ? (dealerById[quote.dealer_id]?.dealer_name ?? '—') : '—'}</span></td>
                        <td className="py-4 px-4 text-gray-700 text-sm text-center font-mono"><span className="block truncate">{quote.dealer_id ? (dealerById[quote.dealer_id]?.dealer_no ?? '—') : '—'}</span></td>
                      </>
                    ) : (
                      <td className="py-4 px-4 text-gray-700 text-sm text-center"><span className="block truncate">{quote.customer_name ?? '—'}</span></td>
                    )}
                    <td className="py-4 px-4 text-center">
                      {proposalStatusMap[quote.id]
                        ? <StatusBadge status={proposalStatusMap[quote.id]} type="proposal" size="sm" />
                        : <span className="text-gray-400 text-sm">—</span>}
                    </td>
                    <td className="py-4 px-4 text-sm text-center">
                      {soNumberMap[quote.id]
                        ? <button onClick={(e) => { e.stopPropagation(); router.navigate(`/sales/orders/${soNumberMap[quote.id].id}`); }} className="text-primary hover:underline font-medium">{soNumberMap[quote.id].no}</button>
                        : <span className="text-gray-400">—</span>}
                    </td>
                    <td className="py-4 px-4 text-center">
                      {quote.priority && quote.priority.toLowerCase() !== 'normal'
                        ? <StatusBadge status={quote.priority} type="priority" size="sm" />
                        : <span className="text-gray-400 text-sm">—</span>}
                    </td>
                    <td className="py-4 px-4 text-gray-600 text-sm text-center">
                      {new Date(quote.created_at).toLocaleDateString()}
                    </td>
                    <td className="py-4 px-4 text-gray-900 text-sm font-medium text-center">
                      {formatCurrency(quote.total)}
                    </td>
                    <td className="py-4 px-4 text-right" onClick={(e) => e.stopPropagation()}>
                      <div className="flex items-center gap-1 justify-end flex-nowrap">
                        <button
                          type="button"
                          onClick={(e) => { e.stopPropagation(); router.navigate(`/sales/quotes/${quote.id}`); }}
                          className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                          title="View"
                        >
                          <Eye style={{ width: 14, height: 14 }} />
                        </button>
                        {statusTab === 'archived' ? (
                          <>
                            <button
                              type="button"
                              onClick={(e) => handleEdit(quote, e)}
                              className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                              title="Edit"
                            >
                              <Edit style={{ width: 14, height: 14 }} />
                            </button>
                            <button
                              type="button"
                              onClick={(e) => handleRestore(quote, e)}
                              className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                              title="Restore"
                            >
                              <RotateCcw style={{ width: 14, height: 14 }} />
                            </button>
                          </>
                        ) : (
                          <>
                            {quote.status === 'approved' && (
                              <button
                                type="button"
                                onClick={(e) => handleCreateSaleOrder(quote, e)}
                                className="p-1.5 hover:bg-gray-100 rounded transition-colors"
                                style={{ color: 'var(--primary-brand-hex)' }}
                                title="Create Sales Order"
                              >
                                <ShoppingCart style={{ width: 14, height: 14 }} />
                              </button>
                            )}
                            <button
                              type="button"
                              onClick={(e) => handleEdit(quote, e)}
                              className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                              title="Edit"
                            >
                              <Edit style={{ width: 14, height: 14 }} />
                            </button>
                            {canArchiveQuote(quote) && (
                              <button
                                type="button"
                                onClick={(e) => handleArchive(quote, e)}
                                className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                                title="Archive"
                              >
                                <Archive style={{ width: 14, height: 14 }} />
                              </button>
                            )}
                            <button
                              type="button"
                              onClick={(e) => handleDelete(quote, e)}
                              className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                              title="Delete"
                            >
                              <Trash2 style={{ width: 14, height: 14 }} />
                            </button>
                          </>
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

      {/* Pagination — mt-4 = space between table container and footer */}
      <div className="mt-4 bg-white border border-gray-200 rounded-lg py-4 px-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="text-sm text-gray-700">Show:</span>
            <select
              value={itemsPerPage}
              onChange={(e) => {
                setItemsPerPage(Number(e.target.value));
                setCurrentPage(1);
              }}
              className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
            >
              <option value={10}>10</option>
              <option value={25}>25</option>
              <option value={50}>50</option>
              <option value={100}>100</option>
            </select>
            <span className="text-sm text-gray-700">
              Showing {filteredQuotes.length === 0 ? 0 : startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredQuotes.length)} of {filteredQuotes.length}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
              disabled={currentPage === 1}
              className="px-3 py-1 border border-gray-200 rounded-lg text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
            >
              Previous
            </button>
            <span className="text-sm text-gray-700">
              Page {currentPage} of {totalPages || 1}
            </span>
            <button
              onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
              disabled={currentPage >= totalPages}
              className="px-3 py-1 border border-gray-200 rounded-lg text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
            >
              Next
            </button>
          </div>
        </div>
      </div>

      {/* Confirm Dialog */}
      <ConfirmDialog
        isOpen={dialogState.isOpen}
        onClose={closeDialog}
        onConfirm={handleConfirm}
        title={dialogState.title}
        message={dialogState.message}
        variant={dialogState.variant}
        confirmText={dialogState.confirmText}
        cancelText={dialogState.cancelText}
        isLoading={dialogState.isLoading}
      />
    </div>
  );
}
