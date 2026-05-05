import { useEffect, useState, useMemo, useCallback } from 'react';
import { router } from '../../lib/router';
import { withReturnTo } from '../../lib/navigation/returnTo';

import { useQuotes, duplicateQuote, type QuoteListItem } from '../../hooks/useQuotes';
import DuplicateQuoteModal, { type DuplicateQuoteMode } from '../../components/sales/DuplicateQuoteModal';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useGranularAccess } from '../../hooks/usePermissions';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { getSupabaseErrorMessage, isRLSError, safeError } from '../../lib/supabase-error-utils';
import { formatDate } from '../../lib/utils';
import { 
  Search, Plus, List, Grid3X3, Edit, Trash2, Archive, RotateCcw,
  FileText, RefreshCw,
  SortAsc, SortDesc, Copy, ChevronRight, ChevronDown
} from 'lucide-react';
import { QuoteStatus } from '../../types/catalog';
import StatusBadge from '../../components/shared/StatusBadge';
import StatusTabs from '../../components/shared/StatusTabs';

/** Usado en la tabla; mismo shape que useQuotes devuelve (QuoteListItem) */
type EnrichedQuote = QuoteListItem;

const formatCurrency = (amount: number) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  }).format(amount || 0);
};

export default function Quotes() {
  const { activeOrganizationId } = useOrganizationContext();
  const { isInternal } = useAccessContext();
  const { canCreate: canCreateQuote, canArchive: canArchiveQuote, canDelete: canDeleteQuote } = useGranularAccess('quotes');
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
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);
  const [sortBy, setSortBy] = useState<'quote_no' | 'status' | 'customer_name' | 'total' | 'created_at'>('created_at');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [statusTab, setStatusTab] = useState(() => {
    const raw = new URLSearchParams(window.location.search).get('status')?.toLowerCase() ?? 'all';
    if (raw === 'draft' || raw === 'approved' || raw === 'cancelled' || raw === 'archived' || raw === 'all') {
      return raw;
    }
    return 'all';
  });
  const [expandedGroups, setExpandedGroups] = useState<Set<string>>(new Set());
  const [duplicateTarget, setDuplicateTarget] = useState<EnrichedQuote | null>(null);
  const [duplicatingLoading, setDuplicatingLoading] = useState(false);

  const quotes = hookQuotes;
  const getStatusForDisplay = useCallback((quote: EnrichedQuote) => {
    const raw = (quote.status || '').toLowerCase();
    if (raw === 'superseded') {
      // Legacy rows that were auto-marked as superseded should keep a neutral editable status in UI.
      return 'draft';
    }
    if (raw === 'approved') {
      if (!quote.sale_order_id) return 'approved';
      return quote.has_payment ? 'released' : 'ordered';
    }
    return raw;
  }, []);

  const [proposalByQuoteMap, setProposalByQuoteMap] = useState<Record<string, { id: string; no: string }>>({});
  const [soNumberMap, setSONumberMap] = useState<Record<string, { id: string; no: string; status: string }>>({});

  useEffect(() => {
    if (!quotes.length || !activeOrganizationId) return;
    const ids = quotes.map(q => q.id);

    supabase
      .from('Proposals')
      .select('id, quote_id, proposal_no')
      .in('quote_id', ids)
      .or('deleted.is.false,deleted.is.null')
      .order('updated_at', { ascending: false })
      .then(({ data }: { data: any }) => {
        if (!data) return;
        const m: Record<string, { id: string; no: string }> = {};
        data.forEach((p: any) => {
          if (p.quote_id && !m[p.quote_id]) {
            m[p.quote_id] = { id: p.id, no: p.proposal_no ?? p.id?.slice(0, 8) ?? '—' };
          }
        });
        setProposalByQuoteMap(m);
      });

    supabase
      .from('SalesOrders')
      .select('id, quote_id, sales_order_no, status')
      .in('quote_id', ids)
      .or('deleted.is.false,deleted.is.null')
      .then(({ data }: { data: any }) => {
        if (!data) return;
        const m: Record<string, { id: string; no: string; status: string }> = {};
        data.forEach((so: any) => { if (so.quote_id) m[so.quote_id] = { id: so.id, no: so.sales_order_no, status: so.status ?? 'open' }; });
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
      { label: 'Approved', value: 'approved', count: statusTabCounts.approved || 0 },
      { label: 'Cancelled', value: 'cancelled', count: (statusTabCounts.cancelled || 0) + (statusTabCounts.canceled || 0) },
      { label: 'Archived', value: 'archived', count: archivedQuotesCount },
    ],
    [statusTabCounts, archivedQuotesCount]
  );

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
    [showConfirm, setDialogLoading, refetch]
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
    router.navigate(withReturnTo(`/sales/quotes/${quote.id}/edit`));
  };

  // === DUPLICATE HANDLER ===
  const openDuplicateModal = (quote: EnrichedQuote, e: React.MouseEvent) => {
    e.stopPropagation();
    setDuplicateTarget(quote);
  };

  const handleDuplicateConfirm = useCallback(
    async (mode: DuplicateQuoteMode, recalculate: boolean) => {
      if (!duplicateTarget) return;
      setDuplicatingLoading(true);
      try {
        const newId = await duplicateQuote(duplicateTarget.id, mode, recalculate);
        useUIStore.getState().addNotification({
          type: 'success',
          title: mode === 'version' ? 'Versión creada' : 'Cotización duplicada',
          message:
            mode === 'version'
              ? 'Se creó una nueva versión vinculada al quote original.'
              : 'Se creó una cotización independiente.',
        });
        setDuplicateTarget(null);
        await refetch();
        router.navigate(withReturnTo(`/sales/quotes/${newId}/edit`));
      } catch (err: any) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error duplicando',
          message: getSupabaseErrorMessage(err),
        });
      } finally {
        setDuplicatingLoading(false);
      }
    },
    [duplicateTarget, refetch]
  );

  const toggleGroup = (rootId: string) => {
    setExpandedGroups((prev) => {
      const next = new Set(prev);
      if (next.has(rootId)) next.delete(rootId);
      else next.add(rootId);
      return next;
    });
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
          result = result.filter((q) => q.status === 'canceled' || q.status === ('cancelled' as any));
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
  }, [quotes, nonArchivedQuotes, searchTerm, sortBy, sortOrder, statusTab]);

  // Group quotes by root_quote_id (versioning family). Latest version displayed;
  // older versions collapsed behind a chevron.
  type QuoteGroup = { key: string; latest: EnrichedQuote; older: EnrichedQuote[] };
  const groupedQuotes: QuoteGroup[] = useMemo(() => {
    const groupMap = new Map<string, EnrichedQuote[]>();
    const idToQuote = new Map<string, EnrichedQuote>();
    filteredQuotes.forEach((q) => {
      idToQuote.set(q.id, q);
      const key = (q.root_quote_id as string | null) ?? q.id;
      if (!groupMap.has(key)) groupMap.set(key, []);
      groupMap.get(key)!.push(q);
    });

    const groups: QuoteGroup[] = [];
    groupMap.forEach((rows, key) => {
      const sorted = [...rows].sort((a, b) => {
        const av = Number(a.version_no ?? 1);
        const bv = Number(b.version_no ?? 1);
        if (av !== bv) return bv - av;
        return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
      });
      const [latest, ...older] = sorted;
      groups.push({ key, latest, older });
    });

    // Sort groups using the same sortBy/sortOrder applied to the latest row.
    const factor = sortOrder === 'asc' ? 1 : -1;
    groups.sort((a, b) => {
      if (sortBy === 'created_at') {
        return (new Date(a.latest.created_at).getTime() - new Date(b.latest.created_at).getTime()) * factor;
      }
      if (sortBy === 'total') {
        return (a.latest.total - b.latest.total) * factor;
      }
      const aVal = String((a.latest as any)[sortBy] || '').toLowerCase();
      const bVal = String((b.latest as any)[sortBy] || '').toLowerCase();
      return aVal.localeCompare(bVal) * factor;
    });

    return groups;
  }, [filteredQuotes, sortBy, sortOrder]);

  // Pagination (by groups, not by individual rows)
  const totalPages = Math.ceil(groupedQuotes.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedGroups = groupedQuotes.slice(startIndex, startIndex + itemsPerPage);
  const paginatedQuotes = paginatedGroups.map((g) => g.latest);

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
          <h1 className="text-xl font-semibold text-foreground">Quotes</h1>
        </div>
        <div className="flex items-center gap-3 ml-auto">
          {canDeleteQuote && selectedIds.size > 0 && (
            <button
              onClick={handleDeleteSelected}
              className="flex items-center gap-2 px-2 py-1 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 text-sm transition-colors"
            >
              <Trash2 style={{ width: 14, height: 14 }} />
              Eliminar seleccionados ({selectedIds.size})
            </button>
          )}
          {canCreateQuote && (
            <button
              onClick={() => router.navigate('/sales/quotes/new')}
              className="flex items-center gap-2 px-2 py-1 rounded text-white text-sm hover:opacity-90 transition-colors"
              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            >
              <Plus style={{ width: 14, height: 14 }} />
              Add Quote
            </button>
          )}
        </div>
      </div>

      <StatusTabs tabs={quotesStatusTabs} activeTab={statusTab} onChange={setStatusTab} />

      {/* Search and Filters — card py-6 px-6; botones px-2 py-1, icon 14px */}
      <div className="mb-4 mt-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
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
          </div>
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
        <div className="table-fit-wrapper quotes-table-wrapper overflow-x-auto">
          <table className="table-fit w-full min-w-[1360px]">
            <colgroup>
              <col style={{ width: '44px' }} />
              <col style={{ width: '120px' }} />
              <col style={{ width: '110px' }} />
              {isInternal ? (
                <>
                  <col style={{ width: '200px' }} />
                  <col style={{ width: '160px' }} />
                  <col style={{ width: '90px' }} />
                </>
              ) : (
                <col style={{ width: '180px' }} />
              )}
              <col style={{ width: '110px' }} />
              <col style={{ width: '140px' }} />
              <col style={{ width: '110px' }} />
              <col style={{ width: '110px' }} />
              <col style={{ width: '140px' }} />
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
                <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">
                  <button onClick={() => handleSort('quote_no')} className="flex items-center gap-1 hover:text-gray-900 justify-center w-full">
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
                    <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs">
                      <button onClick={() => handleSort('customer_name')} className="flex items-center gap-1 hover:text-gray-900">
                        Customer
                        {sortBy === 'customer_name' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                      </button>
                    </th>
                    <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs">Dealer</th>
                    <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Dealer No</th>
                  </>
                ) : (
                  <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs">
                    <button onClick={() => handleSort('customer_name')} className="flex items-center gap-1 hover:text-gray-900">
                      Customer
                      {sortBy === 'customer_name' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                )}
                <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">Proposal</th>
                <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs">SO #</th>
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
                  <td colSpan={isInternal ? 11 : 9} className="py-12 px-4 text-center">
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
                paginatedGroups.flatMap((group) => {
                  const isExpanded = expandedGroups.has(group.key);
                  const rows: React.ReactNode[] = [];
                  const renderQuoteRow = (quote: EnrichedQuote, opts: { isOlder?: boolean } = {}) => (
                  <tr key={quote.id} className={`${opts.isOlder ? 'bg-gray-50/60 text-gray-400' : 'hover:bg-gray-50'}`}>
                    <td className="py-3 px-4 text-center" onClick={(e) => e.stopPropagation()}>
                      {opts.isOlder ? (
                        <span className="inline-block w-4" />
                      ) : (
                        <input
                          type="checkbox"
                          checked={selectedIds.has(quote.id)}
                          onChange={() => toggleSelect(quote.id)}
                          className="rounded border-gray-300"
                        />
                      )}
                    </td>
                    <td className={`py-3 px-4 text-sm font-medium text-center whitespace-nowrap ${opts.isOlder ? 'pl-6' : ''}`}>
                      <div className="flex items-center gap-2 justify-center">
                        {!opts.isOlder && group.older.length > 0 ? (
                          <button
                            type="button"
                            onClick={(e) => { e.stopPropagation(); toggleGroup(group.key); }}
                            className="p-0.5 hover:bg-gray-200 rounded text-gray-500"
                            title={isExpanded ? 'Ocultar versiones anteriores' : 'Mostrar versiones anteriores'}
                          >
                            {isExpanded ? <ChevronDown className="w-3.5 h-3.5" /> : <ChevronRight className="w-3.5 h-3.5" />}
                          </button>
                        ) : opts.isOlder ? (
                          <span className="text-gray-300 text-xs select-none">└</span>
                        ) : (
                          <span className="w-3.5 h-3.5 inline-block" />
                        )}
                        <button
                          onClick={(e) => { e.stopPropagation(); router.navigate(withReturnTo(`/sales/quotes/${quote.id}`)); }}
                          className={opts.isOlder ? 'text-gray-400 hover:text-gray-600 hover:underline' : 'text-primary hover:underline'}
                        >
                          {quote.quote_no}
                        </button>
                        {opts.isOlder && Number(quote.version_no ?? 1) > 1 && (
                          <span className="text-[10px] text-gray-400">
                            v{Number(quote.version_no)}
                          </span>
                        )}
                        {!opts.isOlder && group.older.length > 0 && !isExpanded && (
                          <span
                            className="inline-block w-2 h-2 rounded-full bg-blue-500"
                            title={`${group.older.length} versión${group.older.length > 1 ? 'es' : ''} anterior${group.older.length > 1 ? 'es' : ''}`}
                          />
                        )}
                      </div>
                    </td>
                    <td className="py-3 px-4 text-center">
                      <span className={opts.isOlder ? 'opacity-60' : ''}>
                        <StatusBadge status={getStatusForDisplay(quote)} type="quote" size="sm" />
                      </span>
                    </td>
                    {isInternal ? (
                      <>
                        <td className={`py-3 px-4 text-sm text-left ${opts.isOlder ? 'text-gray-400' : 'text-gray-700'}`} title={quote.customer_name ?? ''}><span className="block truncate">{quote.customer_name ?? '—'}</span></td>
                        <td className={`py-3 px-4 text-sm text-left ${opts.isOlder ? 'text-gray-400' : 'text-gray-700'}`} title={quote.dealer_id ? (dealerById[quote.dealer_id]?.dealer_name ?? '') : ''}><span className="block truncate">{quote.dealer_id ? (dealerById[quote.dealer_id]?.dealer_name ?? '—') : '—'}</span></td>
                        <td className={`py-3 px-4 text-sm text-center font-mono ${opts.isOlder ? 'text-gray-400' : 'text-gray-700'}`}><span className="block truncate">{quote.dealer_id ? (dealerById[quote.dealer_id]?.dealer_no ?? '—') : '—'}</span></td>
                      </>
                    ) : (
                      <td className={`py-3 px-4 text-sm text-left ${opts.isOlder ? 'text-gray-400' : 'text-gray-700'}`} title={quote.customer_name ?? ''}><span className="block truncate">{quote.customer_name ?? '—'}</span></td>
                    )}
                    <td className="py-3 px-4 text-center">
                      {proposalByQuoteMap[quote.id]
                        ? (
                          <button
                            onClick={(e) => { e.stopPropagation(); router.navigate(withReturnTo(`/sales/proposals/${proposalByQuoteMap[quote.id].id}`)); }}
                            className={opts.isOlder ? 'text-gray-400 hover:text-gray-600 hover:underline text-sm' : 'text-primary hover:underline font-medium'}
                          >
                            {proposalByQuoteMap[quote.id].no}
                          </button>
                        )
                        : <span className="text-gray-400 text-sm">—</span>}
                    </td>
                    <td className="py-3 px-4 text-sm text-center">
                      {soNumberMap[quote.id]
                        ? (
                          <button
                            onClick={(e) => { e.stopPropagation(); router.navigate(withReturnTo(`/sales/orders/${soNumberMap[quote.id].id}`)); }}
                            className={opts.isOlder ? 'text-gray-400 hover:text-gray-600 hover:underline text-sm whitespace-nowrap' : 'text-primary hover:underline font-medium text-sm whitespace-nowrap'}
                          >
                            {soNumberMap[quote.id].no}
                          </button>
                        )
                        : <span className="text-gray-400">—</span>}
                    </td>
                    <td className={`py-3 px-4 text-sm text-center ${opts.isOlder ? 'text-gray-400' : 'text-gray-600'}`}>
                      {formatDate(quote.created_at)}
                    </td>
                    <td className={`py-3 px-4 text-sm font-medium text-center ${opts.isOlder ? 'text-gray-400' : 'text-gray-900'}`}>
                      {formatCurrency(quote.total)}
                    </td>
                    <td className="py-3 px-4 text-right" onClick={(e) => e.stopPropagation()}>
                      {opts.isOlder ? (
                        <div className="flex items-center gap-1 justify-end flex-nowrap">
                          <span className="inline-block w-7" aria-hidden />
                        </div>
                      ) : (
                        <div className="flex items-center gap-1 justify-end flex-nowrap">
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
                              <button
                                type="button"
                                onClick={(e) => handleEdit(quote, e)}
                                className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                                title="Edit"
                              >
                                <Edit style={{ width: 14, height: 14 }} />
                              </button>
                              {canCreateQuote && (
                                <button
                                  type="button"
                                  onClick={(e) => openDuplicateModal(quote, e)}
                                  className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                                  title="Duplicar / Nueva versión"
                                >
                                  <Copy style={{ width: 14, height: 14 }} />
                                </button>
                              )}
                              {canArchiveQuote && (
                                <button
                                  type="button"
                                  onClick={(e) => handleArchive(quote, e)}
                                  className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                                  title="Archive"
                                >
                                  <Archive style={{ width: 14, height: 14 }} />
                                </button>
                              )}
                              {canDeleteQuote && (
                                <button
                                  type="button"
                                  onClick={(e) => handleDelete(quote, e)}
                                  className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                                  title="Delete"
                                >
                                  <Trash2 style={{ width: 14, height: 14 }} />
                                </button>
                              )}
                            </>
                          )}
                        </div>
                      )}
                    </td>
                  </tr>
                  );
                  rows.push(renderQuoteRow(group.latest));
                  if (isExpanded) {
                    group.older.forEach((older) => rows.push(renderQuoteRow(older, { isOlder: true })));
                  }
                  return rows;
                })
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
              className="px-3 py-1 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
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

      <DuplicateQuoteModal
        isOpen={!!duplicateTarget}
        onClose={() => !duplicatingLoading && setDuplicateTarget(null)}
        onConfirm={handleDuplicateConfirm}
        sourceQuoteNo={duplicateTarget?.quote_no ?? null}
        disableVersion={duplicateTarget?.status === 'converted'}
        versionDisabledReason={
          duplicateTarget?.status === 'converted'
            ? 'Este quote ya tiene Sales Order. Solo se puede crear una copia independiente.'
            : null
        }
        isLoading={duplicatingLoading}
      />
    </div>
  );
}
