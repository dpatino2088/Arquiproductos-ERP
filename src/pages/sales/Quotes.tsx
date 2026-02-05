import { useEffect, useState, useMemo, useCallback } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { approveQuote, waitForSalesOrder } from '../../hooks/useQuotes';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useActiveCompany } from '../../hooks/useActiveCompany';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { getSupabaseErrorMessage, isRLSError, safeError } from '../../lib/supabase-error-utils';
import { 
  Search, Plus, Upload, List, Grid3X3, Edit, Trash2, Archive, 
  ShoppingCart, FileText, CheckCircle, RefreshCw, Filter,
  SortAsc, SortDesc
} from 'lucide-react';
import { QuoteStatus } from '../../types/catalog';

interface EnrichedQuote {
  id: string;
  quote_no: string;
  status: QuoteStatus;
  customer_id: string | null;
  customer_name: string;
  contact_id: string | null;
  contact_name: string;
  total: number;
  created_at: string;
  organization_id: string;
  company_id: string | null;
}

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
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { activeCompanyId } = useActiveCompany();
  const { dialogState, showConfirm, closeDialog, setLoading: setDialogLoading, handleConfirm } = useConfirmDialog();
  
  const [quotes, setQuotes] = useState<EnrichedQuote[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);
  const [sortBy, setSortBy] = useState<'quote_no' | 'status' | 'customer_name' | 'total' | 'created_at'>('created_at');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [selectedStatus, setSelectedStatus] = useState<QuoteStatus[]>([]);

  // === FETCH QUOTES CON ENRIQUECIMIENTO ===
  const fetchQuotes = useCallback(async () => {
    if (!activeOrganizationId) {
      setLoading(false);
      setQuotes([]);
      setError('No hay organización activa');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      // 1. Query base de Quotes
      const { data: quotesData, error: quotesError } = await supabase
        .from('Quotes')
        .select('id, quote_no, status, organization_id, company_id, customer_id, contact_id, created_at')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('created_at', { ascending: false })
        .limit(500);

      if (quotesError) {
        console.error('[Quotes] Query error:', safeError(quotesError));
        setError(getSupabaseErrorMessage(quotesError));
        setQuotes([]);
        return;
      }

      if (!quotesData || quotesData.length === 0) {
        setQuotes([]);
        return;
      }

      // 2. Obtener IDs únicos para enriquecimiento
      const customerIds = [...new Set(quotesData.map((q: { customer_id?: string }) => q.customer_id).filter(Boolean))];
      const contactIds = [...new Set(quotesData.map((q: { contact_id?: string }) => q.contact_id).filter(Boolean))];
      const quoteIds = quotesData.map((q: { id: string }) => q.id);

      // 3. Cargar datos relacionados en paralelo
      const [customersRes, contactsRes, linesRes] = await Promise.all([
        // Customers
        customerIds.length > 0 
          ? supabase.from('DirectoryCustomers').select('id, customer_name').in('id', customerIds)
          : Promise.resolve({ data: [] }),
        // Contacts
        contactIds.length > 0 
          ? supabase.from('DirectoryContacts').select('id, first_name, last_name').in('id', contactIds)
          : Promise.resolve({ data: [] }),
        // Quote Lines (para calcular totales)
        // v7 schema does NOT have line_total; use msrp snapshot (line total) instead.
        supabase.from('QuoteLines').select('quote_id, msrp, roll_msrp_snapshot, bom_msrp_snapshot').in('quote_id', quoteIds)
      ]);

      // 4. Crear mapas para búsqueda rápida
      const customersMap = new Map<string, string>();
      customersRes.data?.forEach((c: { id: string; customer_name?: string }) => {
        customersMap.set(c.id, c.customer_name || 'Sin nombre');
      });

      const contactsMap = new Map<string, string>();
      contactsRes.data?.forEach((c: { id: string; first_name?: string; last_name?: string }) => {
        const fullName = [c.first_name, c.last_name].filter(Boolean).join(' ') || 'Sin nombre';
        contactsMap.set(c.id, fullName);
      });

      const totalsMap = new Map<string, number>();
      linesRes.data?.forEach((l: { quote_id: string; msrp?: number; roll_msrp_snapshot?: number; bom_msrp_snapshot?: number }) => {
        const current = totalsMap.get(l.quote_id) || 0;
        const lineTotal = Number(l.msrp ?? ((l.roll_msrp_snapshot || 0) + (l.bom_msrp_snapshot || 0)));
        totalsMap.set(l.quote_id, current + lineTotal);
      });

      // 5. Enriquecer quotes
      const enrichedQuotes: EnrichedQuote[] = quotesData.map((q: { id: string; quote_no?: string; status?: string; customer_id?: string; contact_id?: string; created_at?: string; organization_id?: string; company_id?: string }) => ({
        id: q.id,
        quote_no: q.quote_no || 'N/A',
        status: q.status || 'draft',
        customer_id: q.customer_id,
        customer_name: q.customer_id ? (customersMap.get(q.customer_id) || 'Cliente no encontrado') : 'Consumidor Final',
        contact_id: q.contact_id,
        contact_name: q.contact_id ? (contactsMap.get(q.contact_id) || 'Contacto no encontrado') : '-',
        total: totalsMap.get(q.id) || 0,
        created_at: q.created_at,
        organization_id: q.organization_id,
        company_id: q.company_id,
      }));

      console.log('[Quotes] Loaded', enrichedQuotes.length, 'quotes with enrichment');
      setQuotes(enrichedQuotes);

    } catch (err: any) {
      console.error('[Quotes] Error:', safeError(err));
      setError(err?.message || 'Error desconocido');
      setQuotes([]);
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId]);

  // Load on mount
  useEffect(() => {
    fetchQuotes();
  }, [fetchQuotes]);

  // Register submodules
  useEffect(() => {
    registerSubmodules('Quotes', [
      { id: 'quotes', label: 'Quotes', href: '/sales/quotes', icon: FileText },
      { id: 'quote-approved', label: 'Quote Approved', href: '/sales/quotes/approved', icon: CheckCircle },
    ]);
    return () => clearSubmoduleNav();
  }, [registerSubmodules, clearSubmoduleNav]);

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
      
      // Optimistic update
      setQuotes(prev => prev.filter(q => q.id !== quote.id));

      const { error } = await supabase
        .from('Quotes')
        .update({ deleted: true })
        .eq('id', quote.id);

      if (error) {
        console.error('[Quotes] Delete error:', safeError(error));
        await fetchQuotes(); // Rollback
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: getSupabaseErrorMessage(error),
        });
        return;
      }

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Eliminado',
        message: 'Cotización eliminada correctamente',
      });
      
      // Refetch to sync
      await fetchQuotes();

    } catch (err) {
      console.error('[Quotes] Delete catch:', safeError(err));
      await fetchQuotes();
    } finally {
      setDialogLoading(false);
    }
  };

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

  const statusOptions: QuoteStatus[] = ['draft', 'sent', 'approved', 'rejected', 'cancelled'];

  // === RENDER ===
  
  if (loading) {
    return (
      <div className="py-6 px-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">Cargando cotizaciones...</p>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-6">
          <h3 className="text-red-800 font-medium mb-2">Error al cargar cotizaciones</h3>
          <p className="text-red-700 text-sm mb-4">{error}</p>
          <button
            onClick={() => fetchQuotes()}
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
          <button className="flex items-center gap-2 px-3 py-2 border border-gray-300 rounded-lg bg-white hover:bg-gray-50 text-sm">
            <Upload className="w-4 h-4" />
            Import
          </button>
          <button
            onClick={() => router.navigate('/sales/quotes/new')}
            className="flex items-center gap-2 px-3 py-2 rounded-lg text-white text-sm bg-blue-600 hover:bg-blue-700"
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
              onClick={() => fetchQuotes()}
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
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs uppercase">
                  <button onClick={() => handleSort('quote_no')} className="flex items-center gap-1 hover:text-gray-900">
                    Quote No
                    {sortBy === 'quote_no' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs uppercase">
                  <button onClick={() => handleSort('status')} className="flex items-center gap-1 hover:text-gray-900">
                    Status
                    {sortBy === 'status' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs uppercase">
                  <button onClick={() => handleSort('customer_name')} className="flex items-center gap-1 hover:text-gray-900">
                    Customer
                    {sortBy === 'customer_name' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs uppercase">
                  Contact
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs uppercase">
                  <button onClick={() => handleSort('total')} className="flex items-center gap-1 hover:text-gray-900">
                    Total
                    {sortBy === 'total' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs uppercase">
                  <button onClick={() => handleSort('created_at')} className="flex items-center gap-1 hover:text-gray-900">
                    Date
                    {sortBy === 'created_at' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-right py-3 px-6 font-medium text-gray-700 text-xs uppercase">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {paginatedQuotes.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-12 px-6 text-center">
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
                    <td className="py-4 px-6 text-gray-900 text-sm font-medium">
                      {quote.quote_no}
                    </td>
                    <td className="py-4 px-6">
                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusBadgeColor(quote.status)}`}>
                        {quote.status.charAt(0).toUpperCase() + quote.status.slice(1)}
                      </span>
                    </td>
                    <td className="py-4 px-6 text-gray-700 text-sm">
                      {quote.customer_name}
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm">
                      {quote.contact_name}
                    </td>
                    <td className="py-4 px-6 text-gray-900 text-sm font-medium">
                      {formatCurrency(quote.total)}
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm">
                      {new Date(quote.created_at).toLocaleDateString()}
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
