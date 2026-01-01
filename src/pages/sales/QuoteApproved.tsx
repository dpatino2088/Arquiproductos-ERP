import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useApprovedQuotesWithProgress } from '../../hooks/useQuotes';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { 
  Search, 
  Filter,
  List,
  Grid3X3,
  SortAsc,
  SortDesc,
  Eye,
  CheckCircle
} from 'lucide-react';
import { QuoteStatus } from '../../types/catalog';

type SaleOrderStatus = 'Draft' | 'Confirmed' | 'Scheduled for Production' | 'In Production' | 'Ready for Delivery' | 'Delivered' | 'Cancelled';

interface QuoteApprovedItem {
  id: string;
  quoteNo: string;
  status: QuoteStatus;
  customerName: string;
  subtotal: number;
  tax: number;
  total: number;
  currency: string;
  createdAt: string;
  saleOrderNo: string | null;
  saleOrderStatus: SaleOrderStatus | null;
  manufacturingOrderNo: string | null;
  manufacturingStatus: string | null;
}

// Function to get sale order status badge color and label
const getSaleOrderStatusBadge = (status: SaleOrderStatus | null) => {
  if (!status) {
    return { color: 'bg-gray-50 text-gray-700', label: 'No Sales Order' };
  }
  
  switch (status) {
    case 'Draft':
      return { color: 'bg-gray-50 text-gray-700', label: 'Draft' };
    case 'Confirmed':
      return { color: 'bg-blue-50 text-blue-700', label: 'Confirmed' };
    case 'Scheduled for Production':
      return { color: 'bg-yellow-50 text-yellow-700', label: 'Scheduled for Production' };
    case 'In Production':
      return { color: 'bg-orange-50 text-orange-700', label: 'In Production' };
    case 'Ready for Delivery':
      return { color: 'bg-purple-50 text-purple-700', label: 'Ready for Delivery' };
    case 'Delivered':
      return { color: 'bg-green-50 text-green-700', label: 'Delivered' };
    case 'Cancelled':
      return { color: 'bg-red-50 text-red-700', label: 'Cancelled' };
    default:
      return { color: 'bg-gray-50 text-gray-700', label: status };
  }
};

// Format currency
const formatCurrency = (amount: number, currency: string = 'USD') => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
};

export default function QuoteApproved() {
  const { clearSubmoduleNav } = useSubmoduleNav();
  const { quotes, loading, error, refetch } = useApprovedQuotesWithProgress();
  const { activeOrganizationId } = useOrganizationContext();
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState<'quoteNo' | 'customerName' | 'total' | 'createdAt' | 'saleOrderNo' | 'saleOrderStatus'>('quoteNo');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');

  useEffect(() => {
    // Quote Approved is a submodule of Quotes
    // Don't clear submodules here, let Quotes.tsx handle registration
    // Just ensure we're in the right path
    const currentPath = window.location.pathname;
    if (!currentPath.startsWith('/sales/quotes')) {
      clearSubmoduleNav();
    }
    
    // Cleanup: clear submodules when component unmounts or path changes
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/sales/quotes')) {
        clearSubmoduleNav();
      }
    };
  }, [clearSubmoduleNav]);

  // Transform quotes to display format - ONLY APPROVED QUOTES with SaleOrder progress
  const quotesData: QuoteApprovedItem[] = useMemo(() => {
    if (!quotes) return [];
    return quotes.map(quote => {
      // Calculate total from QuoteLines (sum of all line_total)
      const quoteLines = (quote as any).QuoteLines || [];
      const linesTotal = quoteLines
        .filter((line: any) => !line.deleted)
        .reduce((sum: number, line: any) => sum + (line.line_total || 0), 0);
      
      // Use calculated total from lines (sum of all line_total), or fallback to quote.totals
      const calculatedTotal = linesTotal > 0 ? linesTotal : (quote.totals?.total || 0);
      
      // Get SaleOrder data (if exists)
      const saleOrders = (quote as any).SaleOrders || [];
      const saleOrder = Array.isArray(saleOrders) && saleOrders.length > 0 ? saleOrders[0] : null;
      
      // Debug logging
      if (import.meta.env.DEV) {
        console.log(`🔍 QuoteApproved: Processing quote ${(quote as any).quote_no || quote.id}:`, {
          saleOrdersArray: saleOrders,
          saleOrdersLength: saleOrders.length,
          saleOrder: saleOrder,
          saleOrderNo: saleOrder?.sale_order_no || 'NOT FOUND',
          saleOrderStatus: saleOrder?.status || 'NOT FOUND'
        });
      }
      
      // Get SaleOrder data - use convenience fields from hook if available, otherwise extract from SaleOrders array
      const saleOrderNo = (quote as any).saleOrderNo || saleOrder?.sale_order_no || null;
      const saleOrderStatus: SaleOrderStatus | null = (quote as any).saleOrderStatus || (saleOrder?.status as SaleOrderStatus | null) || null;
      
      // ManufacturingOrders will be fetched separately if needed (removed from query to avoid relationship error)
      const manufacturingOrderNo = null;
      const manufacturingStatus = null;
      
      return {
        id: quote.id,
        quoteNo: (quote as any).quote_no || 'N/A',
        status: quote.status,
        customerName: (quote as any).DirectoryCustomers?.customer_name || 'N/A',
        subtotal: calculatedTotal,
        tax: 0,
        total: calculatedTotal,
        currency: quote.currency || 'USD',
        createdAt: quote.created_at,
        saleOrderNo: saleOrderNo,
        saleOrderStatus: saleOrderStatus,
        manufacturingOrderNo,
        manufacturingStatus,
      };
    });
  }, [quotes]);

  // Filter and sort quotes
  const filteredQuotes = useMemo(() => {
    const filtered = quotesData.filter(quote => {
      // Search filter
      const searchLower = searchTerm.toLowerCase();
      const matchesSearch = !searchTerm || (
        quote.quoteNo.toLowerCase().includes(searchLower) ||
        quote.customerName.toLowerCase().includes(searchLower)
      );

      return matchesSearch;
    });

      // Sort
    return filtered.sort((a, b) => {
      let aValue: any = a[sortBy];
      let bValue: any = b[sortBy];

      if (sortBy === 'createdAt') {
        aValue = new Date(a.createdAt);
        bValue = new Date(b.createdAt);
        return sortOrder === 'asc' ? aValue - bValue : bValue - aValue;
      } else if (sortBy === 'total') {
        return sortOrder === 'asc' ? aValue - bValue : bValue - aValue;
      } else if (sortBy === 'saleOrderStatus') {
        // Sort by sale order status order
        const statusOrder: Record<SaleOrderStatus, number> = {
          'Draft': 1,
          'Confirmed': 2,
          'Scheduled for Production': 3,
          'In Production': 4,
          'Ready for Delivery': 5,
          'Delivered': 6,
          'Cancelled': 7,
        };
        const aOrder = aValue ? statusOrder[aValue as SaleOrderStatus] || 0 : 0;
        const bOrder = bValue ? statusOrder[bValue as SaleOrderStatus] || 0 : 0;
        return sortOrder === 'asc' ? aOrder - bOrder : bOrder - aOrder;
      } else {
        const strA = String(aValue || '').toLowerCase();
        const strB = String(bValue || '').toLowerCase();
        if (strA < strB) return sortOrder === 'asc' ? -1 : 1;
        if (strA > strB) return sortOrder === 'asc' ? 1 : -1;
        return 0;
      }
    });
  }, [searchTerm, quotesData, sortBy, sortOrder]);

  // Pagination calculations
  const totalPages = Math.ceil(filteredQuotes.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedQuotes = filteredQuotes.slice(startIndex, startIndex + itemsPerPage);

  // Reset to first page when search changes
  useMemo(() => {
    setCurrentPage(1);
  }, [searchTerm]);

  // Handle sorting
  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('asc');
    }
  };

  // Handlers for actions
  const handleViewQuote = (quote: QuoteApprovedItem, e?: React.MouseEvent) => {
    e?.stopPropagation();
    router.navigate(`/sales/quotes/edit/${quote.id}`);
  };

  const handleQuoteNoClick = (quote: QuoteApprovedItem, e: React.MouseEvent) => {
    e.stopPropagation();
    router.navigate(`/sales/quotes/edit/${quote.id}`);
  };

  // Show loading state
  if (loading) {
    return (
      <div className="py-6 px-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">Loading approved quotes...</p>
          </div>
        </div>
      </div>
    );
  }

  // Show error state
  if (error) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error loading approved quotes</p>
          <p className="text-sm text-red-700">{error}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="py-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Quote Approved</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {`Track your ${filteredQuotes.length} approved quotes${filteredQuotes.length > itemsPerPage ? ` (Page ${currentPage} of ${totalPages})` : ''}`}
          </p>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="mb-4">
        <div className={`bg-white border border-gray-200 py-6 px-6 ${
          showFilters ? 'rounded-t-lg' : 'rounded-lg'
        }`}>
          <div className="flex items-center justify-between gap-3">
            {/* Search Bar */}
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search by quote # or customer..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
              />
            </div>
            <button
              onClick={() => setShowFilters(!showFilters)}
              className={`flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-lg border transition-colors ${
                showFilters
                  ? 'bg-primary text-white border-primary'
                  : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
              }`}
            >
              <Filter className="w-4 h-4" />
              Filters
            </button>
            <div className="flex items-center gap-1 border border-gray-200 rounded-lg overflow-hidden">
              <button
                onClick={() => setViewMode('table')}
                className={`p-2 transition-colors ${
                  viewMode === 'table'
                    ? 'bg-primary text-white'
                    : 'bg-white text-gray-600 hover:bg-gray-50'
                }`}
              >
                <List className="w-4 h-4" />
              </button>
              <button
                onClick={() => setViewMode('grid')}
                className={`p-2 transition-colors ${
                  viewMode === 'grid'
                    ? 'bg-primary text-white'
                    : 'bg-white text-gray-600 hover:bg-gray-50'
                }`}
              >
                <Grid3X3 className="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Table View */}
      {viewMode === 'table' && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('quoteNo')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Quote #
                      {sortBy === 'quoteNo' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('customerName')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Customer
                      {sortBy === 'customerName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('createdAt')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Approved Date
                      {sortBy === 'createdAt' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('total')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Total
                      {sortBy === 'total' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('saleOrderNo')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Sales Order #
                      {sortBy === 'saleOrderNo' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('saleOrderStatus')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Order Progress
                      {sortBy === 'saleOrderStatus' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredQuotes.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="py-12 px-6 text-center">
                      <div className="flex flex-col items-center">
                        <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mb-4">
                          <CheckCircle className="w-6 h-6 text-gray-400" />
                        </div>
                        <p className="text-gray-600 mb-2">No approved quotes found</p>
                        <p className="text-sm text-gray-500">
                          {quotesData.length === 0 
                            ? 'Approved quotes will appear here when customers approve quotes'
                            : 'Try adjusting your search criteria'}
                        </p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  paginatedQuotes.map((quote) => {
                    const statusBadge = getSaleOrderStatusBadge(quote.saleOrderStatus);
                    return (
                      <tr 
                        key={quote.id} 
                        className="border-b border-gray-100 hover:bg-gray-50 transition-colors"
                      >
                        <td className="py-4 px-6">
                          <button
                            onClick={(e) => handleQuoteNoClick(quote, e)}
                            className="text-gray-900 text-sm font-medium hover:text-primary hover:underline"
                          >
                            {quote.quoteNo}
                          </button>
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {quote.customerName}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {new Date(quote.createdAt).toLocaleDateString()}
                        </td>
                        <td className="py-4 px-6 text-gray-900 text-sm font-medium">
                          {formatCurrency(quote.total, quote.currency)}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {quote.saleOrderNo || '—'}
                        </td>
                        <td className="py-4 px-6">
                          <div className="flex flex-col gap-1">
                            <span className={`px-2 py-1 rounded-full text-xs font-medium ${statusBadge.color}`}>
                              {statusBadge.label}
                            </span>
                            {quote.manufacturingOrderNo && quote.manufacturingStatus && (
                              <span className="text-xs text-gray-500">
                                MO: {quote.manufacturingOrderNo} ({quote.manufacturingStatus})
                              </span>
                            )}
                          </div>
                        </td>
                        <td className="py-4 px-6" onClick={(e) => e.stopPropagation()}>
                          <div className="flex items-center gap-1 justify-end">
                            <button 
                              onClick={(e) => handleViewQuote(quote, e)}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                              aria-label={`View ${quote.quoteNo}`}
                              title={`View ${quote.quoteNo}`}
                            >
                              <Eye className="w-4 h-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

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
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredQuotes.length)} of {filteredQuotes.length}
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
    </div>
  );
}

