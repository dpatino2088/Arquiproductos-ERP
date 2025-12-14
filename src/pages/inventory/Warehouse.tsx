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
  Warehouse as WarehouseIcon
} from 'lucide-react';

interface WarehouseItem {
  id: string;
  manufacturer: string;
  sku: string;
  itemName: string;
  quantity: number;
}

// Function to get quantity badge color
const getQuantityBadgeColor = (quantity: number) => {
  if (quantity === 0) {
    return 'bg-red-50 text-red-700';
  } else if (quantity < 10) {
    return 'bg-yellow-50 text-yellow-700';
  } else {
    return 'bg-green-50 text-green-700';
  }
};

export default function Warehouse() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [sortBy, setSortBy] = useState<'manufacturer' | 'sku' | 'itemName' | 'quantity'>('manufacturer');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedManufacturer, setSelectedManufacturer] = useState<string[]>([]);
  const [selectedStockLevel, setSelectedStockLevel] = useState<string[]>([]);

  useEffect(() => {
    registerSubmodules('Inventory', [
      { id: 'warehouse', label: 'Warehouse', href: '/inventory/warehouse' },
      { id: 'purchase-orders', label: 'Purchase Orders', href: '/inventory/purchase-orders' },
      { id: 'receipts', label: 'Receipts', href: '/inventory/receipts' },
      { id: 'transactions', label: 'Transactions', href: '/inventory/transactions' },
      { id: 'adjustments', label: 'Adjustments', href: '/inventory/adjustments' },
    ]);
  }, [registerSubmodules]);

  // Mock data - Replace with actual data fetching
  const warehouseData: WarehouseItem[] = useMemo(() => [
    {
      id: '1',
      manufacturer: 'Coulisse',
      sku: 'COU-BLD-001',
      itemName: 'Premium Roller Blinds - White',
      quantity: 45,
    },
    {
      id: '2',
      manufacturer: 'Coulisse',
      sku: 'COU-VEN-123',
      itemName: 'Venetian Blind Slats - Silver',
      quantity: 156,
    },
    {
      id: '3',
      manufacturer: 'Coulisse',
      sku: 'COU-ZIP-445',
      itemName: 'Zip Screen System - Charcoal',
      quantity: 3,
    },
    {
      id: '4',
      manufacturer: 'Coulisse',
      sku: 'COU-CAS-890',
      itemName: 'Cassette Roller Blind - Black',
      quantity: 0,
    },
    {
      id: '5',
      manufacturer: 'Coulisse',
      sku: 'COU-DAY-345',
      itemName: 'Day & Night Roller Blind',
      quantity: 10,
    },
    {
      id: '6',
      manufacturer: 'Coulisse',
      sku: 'COU-PLI-678',
      itemName: 'Pleated Blind System - Ivory',
      quantity: 36,
    },
    {
      id: '7',
      manufacturer: 'Coulisse',
      sku: 'COU-TRA-789',
      itemName: 'Traverse Rod System - Bronze',
      quantity: 2,
    },
    {
      id: '8',
      manufacturer: 'Hunter Douglas',
      sku: 'HD-SIL-456',
      itemName: 'Silhouette Window Shadings',
      quantity: 23,
    },
    {
      id: '9',
      manufacturer: 'Hunter Douglas',
      sku: 'HD-DUE-234',
      itemName: 'Duette Honeycomb Shades - Cream',
      quantity: 67,
    },
    {
      id: '10',
      manufacturer: 'Hunter Douglas',
      sku: 'HD-LUM-678',
      itemName: 'Luminette Privacy Sheers',
      quantity: 41,
    },
  ], []);

  // Filter and sort warehouse items
  const filteredItems = useMemo(() => {
    const filtered = warehouseData.filter(item => {
      // Search filter
      const searchLower = searchTerm.toLowerCase();
      const matchesSearch = !searchTerm || (
        item.manufacturer.toLowerCase().includes(searchLower) ||
        item.sku.toLowerCase().includes(searchLower) ||
        item.itemName.toLowerCase().includes(searchLower)
      );

      // Manufacturer filter
      const matchesManufacturer = selectedManufacturer.length === 0 || selectedManufacturer.includes(item.manufacturer);

      // Stock level filter
      const stockLevel = item.quantity === 0 ? 'Out of Stock' : item.quantity < 10 ? 'Low Stock' : 'In Stock';
      const matchesStockLevel = selectedStockLevel.length === 0 || selectedStockLevel.includes(stockLevel);

      return matchesSearch && matchesManufacturer && matchesStockLevel;
    });

    // Apply sorting
    return filtered.sort((a, b) => {
      let aValue: string | number;
      let bValue: string | number;

      switch (sortBy) {
        case 'manufacturer':
          aValue = a.manufacturer.toLowerCase();
          bValue = b.manufacturer.toLowerCase();
          break;
        case 'sku':
          aValue = a.sku.toLowerCase();
          bValue = b.sku.toLowerCase();
          break;
        case 'itemName':
          aValue = a.itemName.toLowerCase();
          bValue = b.itemName.toLowerCase();
          break;
        case 'quantity':
          aValue = a.quantity;
          bValue = b.quantity;
          break;
        default:
          aValue = a.manufacturer.toLowerCase();
          bValue = b.manufacturer.toLowerCase();
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
  }, [searchTerm, warehouseData, sortBy, sortOrder, selectedManufacturer, selectedStockLevel]);

  // Pagination calculations
  const totalPages = Math.ceil(filteredItems.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedItems = filteredItems.slice(startIndex, startIndex + itemsPerPage);

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

  // Handle filter toggles
  const handleManufacturerToggle = (manufacturer: string) => {
    setSelectedManufacturer(prev => 
      prev.includes(manufacturer) 
        ? prev.filter(m => m !== manufacturer)
        : [...prev, manufacturer]
    );
  };

  const handleStockLevelToggle = (stockLevel: string) => {
    setSelectedStockLevel(prev => 
      prev.includes(stockLevel) 
        ? prev.filter(s => s !== stockLevel)
        : [...prev, stockLevel]
    );
  };

  // Clear all filters
  const clearAllFilters = () => {
    setSelectedManufacturer([]);
    setSelectedStockLevel([]);
    setSearchTerm('');
  };

  // Get unique filter options
  const manufacturerOptions = Array.from(new Set(warehouseData.map(item => item.manufacturer).filter(Boolean)));
  const stockLevelOptions = ['In Stock', 'Low Stock', 'Out of Stock'];

  const totalActiveFilters = selectedManufacturer.length + selectedStockLevel.length;

  return (
    <div className="py-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-title font-semibold text-foreground mb-1">Warehouse</h1>
          <p className="text-small text-muted-foreground">Manage warehouse locations and capacity</p>
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
            onClick={() => router.navigate('/inventory/warehouse/new')}
          >
            <Plus className="w-4 h-4" />
            Add New Warehouse
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
                placeholder="Search warehouse items by manufacturer, SKU, or item name..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
              />
            </div>
            <button
              onClick={() => setShowFilters(!showFilters)}
              className={`flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-lg border transition-colors ${
                showFilters || totalActiveFilters > 0
                  ? 'bg-primary text-white border-primary'
                  : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
              }`}
            >
              <Filter className="w-4 h-4" />
              Filters
              {totalActiveFilters > 0 && (
                <span className="bg-white text-primary rounded-full px-2 py-0.5 text-xs font-semibold">
                  {totalActiveFilters}
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
              <div className="grid grid-cols-2 gap-4 mb-4">
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
                        onClick={() => handleManufacturerToggle(manufacturer)}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={selectedManufacturer.includes(manufacturer)}
                          readOnly
                          className="w-4 h-4"
                        />
                        <span className="text-sm text-gray-700">{manufacturer}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Stock Level Filter */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Stock Level</span>
                    {selectedStockLevel.length > 0 && (
                      <button
                        onClick={() => setSelectedStockLevel([])}
                        className="text-xs text-gray-500 hover:text-gray-700 whitespace-nowrap"
                      >
                        Clear ({selectedStockLevel.length})
                      </button>
                    )}
                  </div>
                  <div className="max-h-40 overflow-y-auto">
                    {stockLevelOptions.map((stockLevel) => (
                      <div
                        key={stockLevel}
                        onClick={() => handleStockLevelToggle(stockLevel)}
                        className="px-3 py-2 hover:bg-gray-50 cursor-pointer flex items-center gap-2"
                      >
                        <input
                          type="checkbox"
                          checked={selectedStockLevel.includes(stockLevel)}
                          readOnly
                          className="w-4 h-4"
                        />
                        <span className="text-sm text-gray-700">{stockLevel}</span>
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

      {/* Table View */}
      {viewMode === 'table' && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('manufacturer')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Manufacturer
                      {sortBy === 'manufacturer' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('sku')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      SKU
                      {sortBy === 'sku' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('itemName')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Item Name
                      {sortBy === 'itemName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('quantity')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Quantity
                      {sortBy === 'quantity' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredItems.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="py-12 px-6 text-center">
                      <div className="flex flex-col items-center">
                        <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mb-4">
                          <Search className="w-6 h-6 text-gray-400" />
                        </div>
                        <p className="text-gray-600 mb-2">No warehouse items found</p>
                        <p className="text-sm text-gray-500">
                          {warehouseData.length === 0 
                            ? 'Start by adding warehouse items'
                            : 'Try adjusting your search criteria'}
                        </p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  paginatedItems.map((item) => (
                    <tr 
                      key={item.id} 
                      className="border-b border-gray-100 hover:bg-gray-50 transition-colors"
                    >
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {item.manufacturer}
                      </td>
                      <td className="py-4 px-6 text-gray-900 text-sm font-medium">
                        {item.sku}
                      </td>
                      <td className="py-4 px-6 text-gray-700 text-sm">
                        {item.itemName}
                      </td>
                      <td className="py-4 px-6">
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${getQuantityBadgeColor(item.quantity)}`}>
                          {item.quantity} units
                        </span>
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
              Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredItems.length)} of {filteredItems.length}
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

