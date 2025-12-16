import { useEffect, useState, useMemo } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { 
  Search, 
  Filter,
  Plus,
  Upload,
  List,
  Grid3X3,
  SortAsc,
  SortDesc,
  Edit,
  Copy,
  Trash2,
  User
} from 'lucide-react';

interface OrderItem {
  id: string;
  orderId: string;
  status: 'Pending' | 'Processing' | 'Shipped' | 'Delivered' | 'Completed';
  customerName: string;
  quoteName: string;
  totalExTax: number;
  totalIncTax: number;
}

// Function to get status badge color
const getStatusBadgeColor = (status: string) => {
  switch (status) {
    case 'Pending':
      return 'bg-yellow-50 text-yellow-700';
    case 'Processing':
      return 'bg-blue-50 text-blue-700';
    case 'Shipped':
      return 'bg-purple-50 text-purple-700';
    case 'Delivered':
      return 'bg-green-50 text-green-700';
    case 'Completed':
      return 'bg-teal-50 text-teal-700';
    default:
      return 'bg-gray-50 text-gray-700';
  }
};

// Format currency
const formatCurrency = (amount: number) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
};

export default function Orders() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState<'orderId' | 'status' | 'customerName' | 'quoteName' | 'totalExTax' | 'totalIncTax'>('orderId');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedStatus, setSelectedStatus] = useState<string[]>([]);

  useEffect(() => {
    // Only register Sales submodules if we're actually in the Sales module
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/sales')) {
      registerSubmodules('Sales', [
        { id: 'quotes', label: 'Quotes', href: '/sales/quotes' },
        { id: 'orders', label: 'Orders', href: '/sales/orders' },
      ]);
    }
  }, [registerSubmodules]);

  // Mock data - Replace with actual data fetching
  const ordersData: OrderItem[] = useMemo(() => [
    {
      id: '1',
      orderId: '000001',
      status: 'Pending',
      customerName: 'Acme Corporation',
      quoteName: 'Office Renovation Order',
      totalExTax: 15250.00,
      totalIncTax: 16775.00,
    },
    {
      id: '2',
      orderId: '000002',
      status: 'Processing',
      customerName: 'BuildTech Solutions',
      quoteName: 'Warehouse Blinds Order',
      totalExTax: 8900.50,
      totalIncTax: 9790.55,
    },
    {
      id: '3',
      orderId: '000003',
      status: 'Shipped',
      customerName: 'Metro Design Studio',
      quoteName: 'Residential Window Treatments Order',
      totalExTax: 4275.25,
      totalIncTax: 4702.78,
    },
    {
      id: '4',
      orderId: '000004',
      status: 'Delivered',
      customerName: 'Coastal Properties',
      quoteName: 'Hotel Room Curtains Order',
      totalExTax: 22100.00,
      totalIncTax: 24310.00,
    },
    {
      id: '5',
      orderId: '000006',
      status: 'Completed',
      customerName: 'Corporate Plaza',
      quoteName: 'Office Building Shade Solutions',
      totalExTax: 18900.00,
      totalIncTax: 20790.00,
    },
  ], []);

  // Filter and sort orders
  const filteredOrders = useMemo(() => {
    const filtered = ordersData.filter(order => {
      // Search filter
      const searchLower = searchTerm.toLowerCase();
      const matchesSearch = !searchTerm || (
        order.orderId.toLowerCase().includes(searchLower) ||
        order.customerName.toLowerCase().includes(searchLower) ||
        order.quoteName.toLowerCase().includes(searchLower) ||
        order.status.toLowerCase().includes(searchLower)
      );

      // Status filter
      const matchesStatus = selectedStatus.length === 0 || selectedStatus.includes(order.status);

      return matchesSearch && matchesStatus;
    });

    // Apply sorting
    return filtered.sort((a, b) => {
      let aValue: string | number;
      let bValue: string | number;

      switch (sortBy) {
        case 'orderId':
          aValue = a.orderId;
          bValue = b.orderId;
          break;
        case 'status':
          aValue = a.status;
          bValue = b.status;
          break;
        case 'customerName':
          aValue = a.customerName.toLowerCase();
          bValue = b.customerName.toLowerCase();
          break;
        case 'quoteName':
          aValue = a.quoteName.toLowerCase();
          bValue = b.quoteName.toLowerCase();
          break;
        case 'totalExTax':
          aValue = a.totalExTax;
          bValue = b.totalExTax;
          break;
        case 'totalIncTax':
          aValue = a.totalIncTax;
          bValue = b.totalIncTax;
          break;
        default:
          aValue = a.orderId;
          bValue = b.orderId;
      }

      if (typeof aValue === 'number' && typeof bValue === 'number') {
        return sortOrder === 'asc' ? aValue - bValue : bValue - aValue;
      } else {
        const strA = String(aValue);
        const strB = String(bValue);
        if (strA < strB) return sortOrder === 'asc' ? -1 : 1;
        if (strA > strB) return sortOrder === 'asc' ? 1 : -1;
        return 0;
      }
    });
  }, [searchTerm, ordersData, sortBy, sortOrder, selectedStatus]);

  // Pagination calculations
  const totalPages = Math.ceil(filteredOrders.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedOrders = filteredOrders.slice(startIndex, startIndex + itemsPerPage);

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

  // Handle status toggle
  const handleStatusToggle = (status: string) => {
    setSelectedStatus(prev => 
      prev.includes(status) 
        ? prev.filter(s => s !== status)
        : [...prev, status]
    );
  };

  // Clear all filters
  const clearAllFilters = () => {
    setSelectedStatus([]);
    setSearchTerm('');
  };

  const statusOptions = ['Pending', 'Processing', 'Shipped', 'Delivered', 'Completed'];

  return (
    <div className="py-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-title font-semibold text-foreground mb-1">Orders</h1>
          <p className="text-small text-muted-foreground">Manage quotes and orders for your customers</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
          >
            <Upload className="w-4 h-4" />
            Import
          </button>
          <button
            className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
            onClick={() => router.navigate('/sales/orders/new')}
          >
            <Plus className="w-4 h-4" />
            Add New Orders
          </button>
        </div>
      </div>

      {/* Search Bar */}
      <div className="mb-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center gap-4">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search orders by customer name, order name, or status..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
              />
            </div>
            <button
              onClick={() => setShowFilters(!showFilters)}
              className={`flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-lg border transition-colors ${
                showFilters || selectedStatus.length > 0
                  ? 'bg-primary text-white border-primary'
                  : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
              }`}
            >
              <Filter className="w-4 h-4" />
              Filters
              {selectedStatus.length > 0 && (
                <span className="bg-white text-primary rounded-full px-2 py-0.5 text-xs font-semibold">
                  {selectedStatus.length}
                </span>
              )}
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

          {/* Filters Dropdown */}
          {showFilters && (
            <div className="mt-4 pt-4 border-t border-gray-200">
              <div className="mb-4">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm font-medium text-gray-700">Status</span>
                  {selectedStatus.length > 0 && (
                    <button
                      onClick={() => setSelectedStatus([])}
                      className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                    >
                      Clear ({selectedStatus.length})
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
                      {status}
                    </button>
                  ))}
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

      {/* Table View */}
      {viewMode === 'table' && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('orderId')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      ID
                      {sortBy === 'orderId' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('status')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Status
                      {sortBy === 'status' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Customer Name</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Quote Name</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('totalExTax')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Total Ex Tax
                      {sortBy === 'totalExTax' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('totalIncTax')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Total Inc Tax
                      {sortBy === 'totalIncTax' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredOrders.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="py-12 px-6 text-center">
                      <div className="flex flex-col items-center">
                        <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mb-4">
                          <Search className="w-6 h-6 text-gray-400" />
                        </div>
                        <p className="text-gray-600 mb-2">No orders found</p>
                        <p className="text-sm text-gray-500">
                          {ordersData.length === 0 
                            ? 'Start by adding orders'
                            : 'Try adjusting your search criteria'}
                        </p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  paginatedOrders.map((order) => (
                    <tr 
                      key={order.id} 
                      className="border-b border-gray-100 hover:bg-gray-50 transition-colors"
                    >
                      <td className="py-4 px-6 text-gray-900 text-sm font-medium">
                        {order.orderId}
                      </td>
                      <td className="py-4 px-6">
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusBadgeColor(order.status)}`}>
                          {order.status}
                        </span>
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {order.customerName}
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {order.quoteName}
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {formatCurrency(order.totalExTax)}
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {formatCurrency(order.totalIncTax)}
                      </td>
                      <td className="py-4 px-6" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center gap-1 justify-end">
                          <button className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600">
                            <Edit className="w-4 h-4" />
                          </button>
                          <button className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600">
                            <Copy className="w-4 h-4" />
                          </button>
                          <button className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50">
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
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredOrders.length)} of {filteredOrders.length}
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
    </div>
  );
}

