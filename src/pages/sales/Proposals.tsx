import { useEffect, useMemo, useState, useCallback } from 'react';
import { router } from '../../lib/router';

import { useProposalsList } from '../../hooks/useProposals';
import { useUIStore } from '../../stores/ui-store';
import {
  Search,
  RefreshCw,
  Filter,
  SortAsc,
  SortDesc,
  Eye,
  ExternalLink,
  Trash2,
} from 'lucide-react';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { getSupabaseErrorMessage } from '../../lib/supabase-error-utils';

const STATUS_OPTIONS = ['draft', 'sent', 'accepted', 'rejected', 'cancelled'] as const;
type ProposalStatusOption = (typeof STATUS_OPTIONS)[number];

function getStatusBadgeColor(status: string) {
  switch (status) {
    case 'draft':
      return 'bg-gray-100 text-gray-700';
    case 'sent':
      return 'bg-blue-100 text-blue-700';
    case 'accepted':
      return 'bg-green-100 text-green-700';
    case 'rejected':
      return 'bg-red-100 text-red-700';
    case 'cancelled':
      return 'bg-orange-100 text-orange-700';
    default:
      return 'bg-gray-100 text-gray-700';
  }
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString();
}

function formatCurrency(amount: number | null | undefined) {
  if (amount == null) return '—';
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
  }).format(amount);
}

export default function Proposals() {
  const { list, loading, error, refetch, deleteProposal, deleteProposals } = useProposalsList();
  const setGlobalLoading = useUIStore((s) => s.setGlobalLoading);
  const addNotification = useUIStore((s) => s.addNotification);
  const { dialogState, showConfirm, closeDialog, setLoading: setDialogLoading, handleConfirm } = useConfirmDialog();

  useEffect(() => {
    setGlobalLoading(loading);
    return () => setGlobalLoading(false);
  }, [loading, setGlobalLoading]);

  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [selectedStatus, setSelectedStatus] = useState<ProposalStatusOption[]>([]);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);
  const [sortBy, setSortBy] = useState<'proposal_no' | 'status' | 'customer_name' | 'total' | 'updated_at'>('updated_at');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

  const handleSort = useCallback((field: typeof sortBy) => {
    setSortBy(field);
    setSortOrder((prev) => (sortBy === field ? (prev === 'asc' ? 'desc' : 'asc') : 'asc'));
  }, [sortBy]);

  const handleStatusToggle = useCallback((status: ProposalStatusOption) => {
    setSelectedStatus((prev) =>
      prev.includes(status) ? prev.filter((s) => s !== status) : [...prev, status]
    );
  }, []);

  const filteredList = useMemo(() => {
    let result = list;

    if (searchTerm) {
      const term = searchTerm.toLowerCase();
      result = result.filter(
        (p) =>
          (p.proposal_no?.toLowerCase().includes(term) ?? false) ||
          (p.customer_name?.toLowerCase().includes(term) ?? false) ||
          (p.quote_no?.toLowerCase().includes(term) ?? false) ||
          p.status?.toLowerCase().includes(term)
      );
    }

    if (selectedStatus.length > 0) {
      result = result.filter((p) => selectedStatus.includes(p.status as ProposalStatusOption));
    }

    result = [...result].sort((a, b) => {
      const factor = sortOrder === 'asc' ? 1 : -1;
      if (sortBy === 'updated_at') {
        return (new Date(a.updated_at).getTime() - new Date(b.updated_at).getTime()) * factor;
      }
      if (sortBy === 'total') {
        const at = a.total_amount ?? 0;
        const bt = b.total_amount ?? 0;
        return (at - bt) * factor;
      }
      const aVal = String(
        sortBy === 'customer_name' ? a.customer_name : sortBy === 'proposal_no' ? a.proposal_no : a.status
      ).toLowerCase();
      const bVal = String(
        sortBy === 'customer_name' ? b.customer_name : sortBy === 'proposal_no' ? b.proposal_no : b.status
      ).toLowerCase();
      return aVal.localeCompare(bVal) * factor;
    });

    return result;
  }, [list, searchTerm, selectedStatus, sortBy, sortOrder]);

  const totalPages = Math.max(1, Math.ceil(filteredList.length / itemsPerPage));
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedList = filteredList.slice(startIndex, startIndex + itemsPerPage);

  const listIds = useMemo(() => new Set(list.map((p) => p.id)), [list]);
  useEffect(() => {
    setSelectedIds((prev) => {
      let changed = false;
      const next = new Set(prev);
      next.forEach((id) => {
        if (!listIds.has(id)) {
          next.delete(id);
          changed = true;
        }
      });
      return changed ? next : prev;
    });
  }, [listIds]);

  const toggleSelect = useCallback((id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);
  const toggleSelectAll = useCallback(() => {
    const pageIds = paginatedList.map((p) => p.id);
    const allSelected = pageIds.every((id) => selectedIds.has(id));
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (allSelected) pageIds.forEach((id) => next.delete(id));
      else pageIds.forEach((id) => next.add(id));
      return next;
    });
  }, [paginatedList, selectedIds]);
  const handleDeleteOne = useCallback(
    async (p: (typeof paginatedList)[0], e: React.MouseEvent) => {
      e.stopPropagation();
      const confirmed = await showConfirm({
        title: 'Eliminar propuesta',
        message: `¿Eliminar la propuesta ${p.proposal_no || p.id.slice(0, 8)}?`,
        variant: 'danger',
        confirmText: 'Eliminar',
        cancelText: 'Cancelar',
      });
      if (!confirmed) return;
      try {
        setDialogLoading(true);
        await deleteProposal(p.id);
        setSelectedIds((prev) => {
          const next = new Set(prev);
          next.delete(p.id);
          return next;
        });
        addNotification({ type: 'success', title: 'Eliminado', message: 'Propuesta eliminada.' });
      } catch (err: any) {
        addNotification({
          type: 'error',
          title: 'Error',
          message: getSupabaseErrorMessage(err) || 'No se pudo eliminar.',
        });
      } finally {
        setDialogLoading(false);
      }
    },
    [showConfirm, deleteProposal, setDialogLoading, addNotification]
  );
  const handleDeleteSelected = useCallback(async () => {
    const ids = Array.from(selectedIds);
    if (ids.length === 0) return;
    const confirmed = await showConfirm({
      title: 'Eliminar propuestas',
      message: `¿Eliminar ${ids.length} propuesta(s) seleccionada(s)?`,
      variant: 'danger',
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
    });
    if (!confirmed) return;
    try {
      setDialogLoading(true);
      await deleteProposals(ids);
      setSelectedIds(new Set());
      addNotification({ type: 'success', title: 'Eliminado', message: `${ids.length} propuesta(s) eliminada(s).` });
    } catch (err: any) {
      addNotification({
        type: 'error',
        title: 'Error',
        message: getSupabaseErrorMessage(err) || 'No se pudieron eliminar.',
      });
    } finally {
      setDialogLoading(false);
    }
  }, [selectedIds, showConfirm, deleteProposals, setDialogLoading, addNotification]);

  // ✅ registerSubmodules se maneja en SalesDirectory.tsx (wrapper)

  // ✅ NUNCA retornar vacío por loading — usar overlay en su lugar (igual que Directory)
  // if (loading) return <div ... />; ← ELIMINADO: causaba flash

  if (error && !loading) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-6">
          <h3 className="text-red-800 font-medium mb-2">Error al cargar propuestas</h3>
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
      {/* Header: mismo formato que Quotes */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-gray-900">Proposals</h1>
          <p className="text-sm text-gray-500">
            {filteredList.length} {filteredList.length === 1 ? 'propuesta' : 'propuestas'}
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
          <button
            onClick={() => refetch()}
            className="flex items-center gap-2 px-3 py-2 border border-gray-300 rounded-lg bg-white hover:bg-gray-50 text-sm"
            title="Actualizar"
          >
            <RefreshCw className="w-4 h-4" />
            Refresh
          </button>
        </div>
      </div>

      {/* Search and Filters: misma barra que Quotes */}
      <div className="mb-4">
        <div
          className={`bg-white border border-gray-200 py-4 px-4 ${showFilters ? 'rounded-t-lg' : 'rounded-lg'}`}
        >
          <div className="flex items-center gap-3">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Buscar por número, cliente o quote..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
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
            <button
              onClick={() => refetch()}
              className="p-2 border border-gray-200 rounded-lg hover:bg-gray-50"
              title="Actualizar"
            >
              <RefreshCw className="w-4 h-4 text-gray-600" />
            </button>
          </div>

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
                {STATUS_OPTIONS.map((status) => (
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

      {/* Table: mismos estilos que Quotes */}
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
        <div className="table-fit-wrapper">
          <table className="table-fit">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="w-10 py-3 px-4 text-left">
                  <input
                    type="checkbox"
                    checked={paginatedList.length > 0 && paginatedList.every((p) => selectedIds.has(p.id))}
                    onChange={toggleSelectAll}
                    className="rounded border-gray-300"
                  />
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs">
                  <button
                    onClick={() => handleSort('proposal_no')}
                    className="flex items-center gap-1 hover:text-gray-900"
                  >
                    Proposal / Quote
                    {sortBy === 'proposal_no' &&
                      (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs">
                  <button
                    onClick={() => handleSort('status')}
                    className="flex items-center gap-1 hover:text-gray-900"
                  >
                    Status
                    {sortBy === 'status' &&
                      (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs">
                  <button
                    onClick={() => handleSort('customer_name')}
                    className="flex items-center gap-1 hover:text-gray-900"
                  >
                    Customer
                    {sortBy === 'customer_name' &&
                      (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs">
                  <button
                    onClick={() => handleSort('total')}
                    className="flex items-center gap-1 hover:text-gray-900"
                  >
                    Total
                    {sortBy === 'total' &&
                      (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs">
                  <button
                    onClick={() => handleSort('updated_at')}
                    className="flex items-center gap-1 hover:text-gray-900"
                  >
                    Date
                    {sortBy === 'updated_at' &&
                      (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs">Created by</th>
                <th className="text-left py-3 px-6 font-medium text-gray-700 text-xs">Quote created by</th>
                <th className="text-right py-3 px-6 font-medium text-gray-700 text-xs">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {paginatedList.length === 0 ? (
                <tr>
                  <td colSpan={9} className="py-12 px-6 text-center">
                    <div className="flex flex-col items-center">
                      <Search className="w-12 h-12 text-gray-300 mb-4" />
                      <p className="text-gray-600 mb-2">No se encontraron propuestas</p>
                      <p className="text-sm text-gray-400">
                        {list.length === 0
                          ? 'Crea una propuesta desde el detalle de una Quote'
                          : 'Intenta con otros términos de búsqueda o filtros'}
                      </p>
                    </div>
                  </td>
                </tr>
              ) : (
                paginatedList.map((p) => (
                  <tr
                    key={p.id}
                    className="hover:bg-gray-50 cursor-pointer"
                    onClick={() => router.navigate(`/sales/proposals/${p.id}`)}
                  >
                    <td className="w-10 py-4 px-4" onClick={(e) => e.stopPropagation()}>
                      <input
                        type="checkbox"
                        checked={selectedIds.has(p.id)}
                        onChange={() => toggleSelect(p.id)}
                        className="rounded border-gray-300"
                      />
                    </td>
                    <td className="py-4 px-6 text-gray-900 text-sm font-medium">
                      <span className="block">{p.proposal_no || `Proposal ${p.id.slice(0, 8)}`}</span>
                      {p.quote_no && (
                        <span className="text-xs text-gray-500 font-normal">Quote: {p.quote_no}</span>
                      )}
                    </td>
                    <td className="py-4 px-6">
                      <span
                        className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusBadgeColor(p.status)}`}
                      >
                        {p.status.charAt(0).toUpperCase() + p.status.slice(1)}
                      </span>
                    </td>
                    <td className="py-4 px-6 text-gray-700 text-sm">{p.customer_name ?? '—'}</td>
                    <td className="py-4 px-6 text-gray-900 text-sm font-medium">
                      {formatCurrency(p.total_amount)}
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm">{formatDate(p.updated_at)}</td>
                    <td className="py-4 px-6 text-gray-600 text-sm">{p.proposal_created_by ?? '—'}</td>
                    <td className="py-4 px-6 text-gray-600 text-sm">{p.quote_created_by ?? '—'}</td>
                    <td className="py-4 px-6">
                      <div className="flex items-center gap-1 justify-end">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            router.navigate(`/sales/proposals/${p.id}`);
                          }}
                          className="p-2 hover:bg-gray-100 rounded text-gray-600"
                          title="Ver"
                        >
                          <Eye className="w-4 h-4" />
                        </button>
                        {p.quote_id && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              router.navigate(`/sales/quotes/${p.quote_id}/edit`);
                            }}
                            className="p-2 hover:bg-gray-100 rounded text-gray-600"
                            title="Ir a Quote"
                          >
                            <ExternalLink className="w-4 h-4" />
                          </button>
                        )}
                        <button
                          onClick={(e) => handleDeleteOne(p, e)}
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

      {/* Pagination: mismo formato que Quotes */}
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
              Showing{' '}
              {filteredList.length === 0 ? 0 : startIndex + 1}-
              {Math.min(startIndex + itemsPerPage, filteredList.length)} of {filteredList.length}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setCurrentPage((prev) => Math.max(1, prev - 1))}
              disabled={currentPage === 1}
              className="px-3 py-1 border border-gray-200 rounded-lg text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
            >
              Previous
            </button>
            <span className="text-sm text-gray-700">
              Page {currentPage} of {totalPages}
            </span>
            <button
              onClick={() => setCurrentPage((prev) => Math.min(totalPages, prev + 1))}
              disabled={currentPage >= totalPages}
              className="px-3 py-1 border border-gray-200 rounded-lg text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
            >
              Next
            </button>
          </div>
        </div>
      </div>

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
