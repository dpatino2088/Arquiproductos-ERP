import { useEffect, useState, useMemo, useCallback } from 'react';
import { router } from '../../lib/router';

import { useQuotes, approveQuote, waitForSalesOrder, type QuoteListItem } from '../../hooks/useQuotes';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { getSupabaseErrorMessage, isRLSError, safeError } from '../../lib/supabase-error-utils';
import { 
  Search, Plus, Upload, List, Grid3X3, Edit, Trash2, Archive, 
  ShoppingCart, FileText, RefreshCw, Filter,
  SortAsc, SortDesc
} from 'lucide-react';
import { QuoteStatus } from '../../types/catalog';

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
  const { dialogState, showConfirm, closeDialog, setLoading: setDialogLoading, handleConfirm } = useConfirmDialog();

  // Una sola fuente de verdad: filtro por dealer y enriquecimiento en useQuotes
  const { quotes: hookQuotes, loading, error, refetch } = useQuotes();
  const setGlobalLoading = useUIStore((s) => s.setGlobalLoading);

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

  const quotes = hookQuotes;

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
    let result = quotes;

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

    // Status filter
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
  }, [quotes, searchTerm, selectedStatus, sortBy, sortOrder]);

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
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-gray-900">Quotes</h1>
          <p className="text-sm text-gray-500">
            {filteredQuotes.length} cotizaciones
          </p>
        </div>
        <div className="flex items-center gap-3">
          {selectedIds.size > 0 && (
            <button
              onClick={handleDeleteSelected}
              className="flex items-center gap-2 px-3 py-2 border border-red-300 rounded-lg bg-red-50 text-red-700 hover:bg-red-100 text-sm"
            >
              <Trash2 className="w-4 h-4" />
              Eliminar seleccionados ({selectedIds.size})
            </button>
          )}
          <button className="flex items-center gap-2 px-3 py-2 border border-gray-300 rounded-lg bg-white hover:bg-gray-50 text-sm">
            <Upload className="w-4 h-4" />
            Import
          </button>
          <button
            onClick={() => router.navigate('/sales/quotes/new')}
            className="flex items-center gap-2 px-3 py-2 rounded-lg text-white text-sm hover:opacity-90 transition-colors"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            <Plus className="w-4 h-4" />
            Add Quote
          </button>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="mb-4">
        <div className={`bg-white border border-gray-200 py-4 px-4 ${showFilters ? 'rounded-t-lg' : 'rounded-lg'}`}>
          <div className="flex items-center gap-3">
            {/* Search */}
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Buscar por número, cliente o contacto..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            {/* Filter button */}
            <button
              onClick={() => setShowFilters(!showFilters)}
              className={`flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-lg border transition-colors ${
                showFilters || selectedStatus.length > 0
                  ? 'bg-blue-600 text-white border-blue-600'
                  : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
              }`}
            >
              <Filter className="w-4 h-4" />
              Filters
              {selectedStatus.length > 0 && (
                <span className="bg-white text-blue-600 rounded-full px-2 py-0.5 text-xs font-semibold">
                  {selectedStatus.length}
                </span>
              )}
            </button>
            {/* Refresh button */}
            <button
              onClick={() => refetch()}
              className="p-2 border border-gray-200 rounded-lg hover:bg-gray-50"
              title="Actualizar"
            >
              <RefreshCw className="w-4 h-4 text-gray-600" />
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
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="td-checkbox-cell w-10 py-3 px-4 text-left">
                  <input
                    type="checkbox"
                    checked={paginatedQuotes.length > 0 && paginatedQuotes.every((q) => selectedIds.has(q.id))}
                    onChange={toggleSelectAll}
                    className="rounded border-gray-300"
                  />
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs min-w-[100px] whitespace-nowrap">
                  <button onClick={() => handleSort('quote_no')} className="flex items-center gap-1 hover:text-gray-900">
                    Quote
                    {sortBy === 'quote_no' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs">
                  <button onClick={() => handleSort('customer_name')} className="flex items-center gap-1 hover:text-gray-900">
                    Customer
                    {sortBy === 'customer_name' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs">
                  Contact
                </th>
                <th className="text-center py-3 px-6 font-medium text-gray-700 text-xs min-w-[380px] whitespace-nowrap">Description</th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs min-w-[100px] whitespace-nowrap">Created By</th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs min-w-[80px] whitespace-nowrap">
                  <button onClick={() => handleSort('status')} className="flex items-center gap-1 hover:text-gray-900">
                    Status
                    {sortBy === 'status' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs min-w-[90px] whitespace-nowrap">
                  <button onClick={() => handleSort('created_at')} className="flex items-center gap-1 hover:text-gray-900">
                    Date
                    {sortBy === 'created_at' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs min-w-[90px] whitespace-nowrap">
                  <button onClick={() => handleSort('total')} className="flex items-center gap-1 hover:text-gray-900">
                    Total
                    {sortBy === 'total' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-right py-3 px-6 font-medium text-gray-700 text-xs min-w-[100px] whitespace-nowrap">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {paginatedQuotes.length === 0 ? (
                <tr>
                  <td colSpan={10} className="py-12 px-6 text-center">
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
                    <td className="td-checkbox-cell w-10 py-4 px-4" onClick={(e) => e.stopPropagation()}>
                      <input
                        type="checkbox"
                        checked={selectedIds.has(quote.id)}
                        onChange={() => toggleSelect(quote.id)}
                        className="rounded border-gray-300"
                      />
                    </td>
                    <td className="py-4 px-6 text-gray-900 text-sm font-medium whitespace-nowrap">
                      {quote.quote_no}
                    </td>
                    <td className="py-4 px-6 text-gray-700 text-sm">
                      {quote.customer_name}
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap">
                      {(quote.contact_name ?? '').replace(/\s+/g, ' ').trim() || '—'}
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm min-w-[380px] max-w-[380px] truncate text-center" title={quote.description ?? undefined}>
                      {quote.description?.trim() || '—'}
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap">{quote.created_by ?? '—'}</td>
                    <td className="py-4 px-6">
                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusBadgeColor(quote.status)}`}>
                        {quote.status.charAt(0).toUpperCase() + quote.status.slice(1)}
                      </span>
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm">
                      {new Date(quote.created_at).toLocaleDateString()}
                    </td>
                    <td className="py-4 px-6 text-gray-900 text-sm font-medium">
                      {formatCurrency(quote.total)}
                    </td>
                    <td className="py-4 px-6">
                      <div className="flex items-center gap-1 justify-end">
                        {quote.status === 'approved' && (
                          <button 
                            onClick={(e) => handleCreateSaleOrder(quote, e)}
                            className="p-2 hover:bg-blue-50 rounded text-blue-600"
                            title="Crear Orden de Venta"
                          >
                            <ShoppingCart className="w-4 h-4" />
                          </button>
                        )}
                        <button 
                          onClick={(e) => handleEdit(quote, e)}
                          className="p-2 hover:bg-gray-100 rounded text-gray-600"
                          title="Editar"
                        >
                          <Edit className="w-4 h-4" />
                        </button>
                        <button 
                          onClick={(e) => handleDelete(quote, e)}
                          className="p-2 hover:bg-red-50 rounded text-red-600"
                          title="Eliminar"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
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
      <div className="bg-white border border-gray-200 rounded-lg py-4 px-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="text-sm text-gray-700">Show:</span>
            <select
              value={itemsPerPage}
              onChange={(e) => {
                setItemsPerPage(Number(e.target.value));
                setCurrentPage(1);
              }}
              className="px-3 py-1 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
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
