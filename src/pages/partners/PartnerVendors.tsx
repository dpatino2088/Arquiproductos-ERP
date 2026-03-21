import { useEffect, useState, useMemo } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { router } from '../../lib/router';
import { useDirectoryVendors, type DirectoryVendor } from '../../hooks/useDirectoryVendors';
import { useGranularAccess } from '../../hooks/usePermissions';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import {
  Building, Store, Building2, Plus, Search, Edit, Trash2,
  Filter, SortAsc, SortDesc, ChevronLeft, ChevronRight,
  Mail, Phone, Globe, MapPin, Upload
} from 'lucide-react';

const PARTNERS_SUBMODULES = [
  { id: 'dealers', label: 'Dealers', href: '/partners/dealers', icon: Building },
  { id: 'vendors', label: 'Vendors', href: '/partners/vendors', icon: Store },
  { id: 'manufacturers', label: 'Manufacturers', href: '/partners/manufacturers', icon: Building2 },
];

export default function PartnerVendors() {
  const { registerSubmodules } = useSubmoduleNav();
  const { vendors, isLoading, deleteVendor } = useDirectoryVendors();
  const { canCreate, canDelete } = useGranularAccess('directory');
  const { addNotification } = useUIStore();
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();

  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [sortBy, setSortBy] = useState<'name' | 'email' | 'city'>('name');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');

  useEffect(() => {
    registerSubmodules('Partners', PARTNERS_SUBMODULES);
  }, [registerSubmodules]);

  useEffect(() => { setCurrentPage(1); }, [searchTerm]);

  const filteredVendors = useMemo(() => {
    const q = searchTerm.toLowerCase();
    const filtered = vendors.filter((v) =>
      !searchTerm ||
      v.name?.toLowerCase().includes(q) ||
      v.email?.toLowerCase().includes(q) ||
      v.work_phone?.toLowerCase().includes(q) ||
      v.city?.toLowerCase().includes(q) ||
      v.website?.toLowerCase().includes(q)
    );

    return filtered.sort((a, b) => {
      let aVal = '', bVal = '';
      if (sortBy === 'name') { aVal = (a.name || '').toLowerCase(); bVal = (b.name || '').toLowerCase(); }
      else if (sortBy === 'email') { aVal = (a.email || '').toLowerCase(); bVal = (b.email || '').toLowerCase(); }
      else { aVal = (a.city || '').toLowerCase(); bVal = (b.city || '').toLowerCase(); }
      if (aVal < bVal) return sortOrder === 'asc' ? -1 : 1;
      if (aVal > bVal) return sortOrder === 'asc' ? 1 : -1;
      return 0;
    });
  }, [vendors, searchTerm, sortBy, sortOrder]);

  const totalPages = Math.ceil(filteredVendors.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedVendors = filteredVendors.slice(startIndex, startIndex + itemsPerPage);

  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    else { setSortBy(field); setSortOrder('asc'); }
  };

  const handleDelete = async (vendor: DirectoryVendor) => {
    const confirmed = await showConfirm({
      title: 'Delete Vendor',
      message: `Are you sure you want to delete "${vendor.name}"? This action cannot be undone.`,
      variant: 'danger',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    });
    if (!confirmed) return;
    try {
      setLoading(true);
      await deleteVendor.mutateAsync(vendor.id);
      addNotification({ type: 'success', title: 'Vendor Deleted', message: 'Vendor deleted successfully' });
    } catch (err: any) {
      addNotification({ type: 'error', title: 'Error', message: err.message || 'Failed to delete vendor' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="py-6">
      {/* 1) Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Vendors</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {isLoading ? 'Loading...' : `Manage your ${filteredVendors.length} vendors${filteredVendors.length > itemsPerPage ? ` (Page ${currentPage} of ${totalPages})` : ''}`}
          </p>
        </div>
        <div className="flex items-center gap-3 ml-auto">
          {canCreate && (
            <button
              onClick={() => router.navigate('/partners/vendors/new')}
              className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm hover:opacity-90"
              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            >
              <Plus style={{ width: '14px', height: '14px' }} />
              New Vendor
            </button>
          )}
        </div>
      </div>

      {/* 2) Search & Filters */}
      <div className="mb-4">
        <div className={`bg-white border border-gray-200 py-6 px-6 ${showFilters ? 'rounded-t-lg' : 'rounded-lg'}`}>
          <div className="flex items-center justify-between gap-3">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search vendors by name, email, phone, or city..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
              />
            </div>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setShowFilters(!showFilters)}
                className={`flex items-center gap-2 px-2 py-1 border border-gray-300 rounded transition-colors text-sm ${
                  showFilters ? 'bg-gray-300 text-black' : 'bg-white text-gray-700 hover:bg-gray-50'
                }`}
              >
                <Filter style={{ width: '14px', height: '14px' }} />
                Filters
              </button>
            </div>
          </div>
        </div>

        {showFilters && (
          <div className="bg-white border-l border-r border-b border-gray-200 rounded-b-lg py-6 px-6">
            <div className="flex justify-between items-center">
              <button
                onClick={() => { setSearchTerm(''); setSortBy('name'); setSortOrder('asc'); }}
                className="text-xs text-gray-500 hover:text-gray-700"
              >
                Clear all filters
              </button>
              <div className="flex gap-3 items-center">
                <span className="text-xs text-gray-500">Sort by:</span>
                <button
                  onClick={() => handleSort('name')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${sortBy === 'name' ? 'text-gray-900 font-medium' : 'text-gray-600'}`}
                >
                  Name {sortBy === 'name' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button
                  onClick={() => handleSort('email')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${sortBy === 'email' ? 'text-gray-900 font-medium' : 'text-gray-600'}`}
                >
                  Email {sortBy === 'email' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button
                  onClick={() => handleSort('city')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${sortBy === 'city' ? 'text-gray-900 font-medium' : 'text-gray-600'}`}
                >
                  City {sortBy === 'city' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* 3) Table */}
      <div className="relative min-h-[420px]">
        {isLoading ? (
          <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Name</th>
                  <th className="text-center py-3 px-4 font-medium text-gray-900 text-xs">Email</th>
                  <th className="text-center py-3 px-4 font-medium text-gray-900 text-xs">Phone</th>
                  <th className="text-center py-3 px-4 font-medium text-gray-900 text-xs">City</th>
                  <th className="text-center py-3 px-4 font-medium text-gray-900 text-xs">Website</th>
                  <th className="text-right py-3 px-4 font-medium text-gray-900 text-xs">Actions</th>
                </tr>
              </thead>
              <tbody>
                {Array.from({ length: 6 }).map((_, i) => (
                  <tr key={i} className="border-b border-gray-100">
                    <td className="py-4 px-4"><div className="h-4 bg-gray-200 rounded animate-pulse w-32" /></td>
                    <td className="py-4 px-4 text-center"><div className="h-4 bg-gray-200 rounded animate-pulse w-36 mx-auto" /></td>
                    <td className="py-4 px-4 text-center"><div className="h-4 bg-gray-200 rounded animate-pulse w-28 mx-auto" /></td>
                    <td className="py-4 px-4 text-center"><div className="h-4 bg-gray-200 rounded animate-pulse w-24 mx-auto" /></td>
                    <td className="py-4 px-4 text-center"><div className="h-4 bg-gray-200 rounded animate-pulse w-28 mx-auto" /></td>
                    <td className="py-4 px-4 text-center"><div className="h-4 bg-gray-200 rounded animate-pulse w-16 mx-auto" /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <>
            <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
              <div className="table-fit-wrapper">
                <table className="table-fit">
                  <colgroup>
                    <col style={{ width: '20%' }} />
                    <col style={{ width: '20%' }} />
                    <col style={{ width: '12%' }} />
                    <col style={{ width: '12%' }} />
                    <col style={{ width: '14%' }} />
                    <col style={{ width: '12%' }} />
                    <col style={{ width: '10%' }} />
                  </colgroup>
                  <thead className="bg-gray-50 border-b border-gray-200">
                    <tr>
                      <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                        <button onClick={() => handleSort('name')} className="flex items-center gap-1 hover:text-gray-700">
                          Name {sortBy === 'name' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                        </button>
                      </th>
                      <th className="text-center py-3 px-4 font-medium text-gray-900 text-xs">
                        <button onClick={() => handleSort('email')} className="flex items-center gap-1 hover:text-gray-700 justify-center w-full">
                          Email {sortBy === 'email' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                        </button>
                      </th>
                      <th className="text-center py-3 px-4 font-medium text-gray-900 text-xs">Phone</th>
                      <th className="text-center py-3 px-4 font-medium text-gray-900 text-xs">
                        <button onClick={() => handleSort('city')} className="flex items-center gap-1 hover:text-gray-700 justify-center w-full">
                          City {sortBy === 'city' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                        </button>
                      </th>
                      <th className="text-center py-3 px-4 font-medium text-gray-900 text-xs">Website</th>
                      <th className="text-center py-3 px-4 font-medium text-gray-900 text-xs">Tax Rule</th>
                      <th className="text-right py-3 px-4 font-medium text-gray-900 text-xs">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-200">
                    {filteredVendors.length === 0 ? (
                      <tr>
                        <td colSpan={7} className="py-12 px-4 text-center">
                          <Store className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                          <p className="text-gray-600 mb-2">No vendors found</p>
                          <p className="text-sm text-gray-500">
                            {vendors.length === 0 ? 'Start by adding vendors' : 'Try adjusting your search criteria'}
                          </p>
                        </td>
                      </tr>
                    ) : (
                      paginatedVendors.map((vendor) => (
                        <tr
                          key={vendor.id}
                          className="border-b border-gray-100 hover:bg-gray-50 transition-colors cursor-pointer"
                          onClick={() => router.navigate(`/partners/vendors/edit/${vendor.id}`)}
                        >
                          <td className="py-4 px-4 text-gray-900 text-sm text-left">
                            <span className="block truncate font-medium" title={vendor.name}>{vendor.name}</span>
                          </td>
                          <td className="py-4 px-4 text-gray-700 text-sm text-center">
                            {vendor.email ? (
                              <div className="flex items-center gap-1 min-w-0 justify-center">
                                <Mail className="w-3 h-3 text-gray-400 flex-shrink-0" />
                                <span className="truncate">{vendor.email}</span>
                              </div>
                            ) : <span className="text-gray-400">—</span>}
                          </td>
                          <td className="py-4 px-4 text-gray-700 text-sm text-center">
                            {vendor.work_phone ? (
                              <div className="flex items-center gap-1 min-w-0 justify-center">
                                <Phone className="w-3 h-3 text-gray-400 flex-shrink-0" />
                                <span className="truncate">{vendor.work_phone}</span>
                              </div>
                            ) : <span className="text-gray-400">—</span>}
                          </td>
                          <td className="py-4 px-4 text-gray-700 text-sm text-center">
                            <span className="block truncate">
                              {[vendor.city, vendor.state].filter(Boolean).join(', ') || '—'}
                            </span>
                          </td>
                          <td className="py-4 px-4 text-gray-700 text-sm text-center">
                            {vendor.website ? (
                              <div className="flex items-center gap-1 min-w-0 justify-center">
                                <Globe className="w-3 h-3 text-gray-400 flex-shrink-0" />
                                <span className="truncate">{vendor.website}</span>
                              </div>
                            ) : <span className="text-gray-400">—</span>}
                          </td>
                          <td className="py-4 px-4 text-sm text-center">
                            {vendor.tax_rule === 'tax_exempt' ? (
                              <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-50 text-blue-700">
                                No Tax
                              </span>
                            ) : (
                              <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-50 text-green-700">
                                Taxable
                              </span>
                            )}
                          </td>
                          <td className="py-4 px-4 text-right" onClick={(e) => e.stopPropagation()}>
                            <div className="flex items-center gap-1 justify-end">
                              <button
                                onClick={() => router.navigate(`/partners/vendors/edit/${vendor.id}`)}
                                className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                                title={`Edit ${vendor.name}`}
                              >
                                <Edit className="w-4 h-4" />
                              </button>
                              {canDelete && (
                                <button
                                  onClick={() => handleDelete(vendor)}
                                  className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                                  title={`Delete ${vendor.name}`}
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
            {filteredVendors.length > 0 && (
              <div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <span className="text-xs text-gray-600">Show:</span>
                    <select
                      value={itemsPerPage}
                      onChange={(e) => { setItemsPerPage(Number(e.target.value)); setCurrentPage(1); }}
                      className="border border-gray-200 rounded px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                    >
                      <option value={10}>10</option>
                      <option value={25}>25</option>
                      <option value={50}>50</option>
                      <option value={100}>100</option>
                    </select>
                    <span className="text-xs text-gray-600">
                      Showing {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredVendors.length)} of {filteredVendors.length}
                    </span>
                  </div>

                  {totalPages > 1 && (
                    <div className="flex items-center gap-3">
                      <button
                        onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
                        disabled={currentPage === 1}
                        className={`flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${
                          currentPage === 1 ? 'border-gray-200 text-gray-400 cursor-not-allowed' : 'border-gray-300 text-gray-700 hover:bg-gray-50'
                        }`}
                      >
                        <ChevronLeft className="w-3 h-3" /> Previous
                      </button>
                      <div className="flex items-center gap-1">
                        {Array.from({ length: Math.min(totalPages, 5) }, (_, i) => {
                          let pageNum: number;
                          if (totalPages <= 5) pageNum = i + 1;
                          else if (currentPage <= 3) pageNum = i + 1;
                          else if (currentPage >= totalPages - 2) pageNum = totalPages - 4 + i;
                          else pageNum = currentPage - 2 + i;
                          return (
                            <button
                              key={pageNum}
                              onClick={() => setCurrentPage(pageNum)}
                              className={`w-6 h-6 text-xs rounded transition-colors flex items-center justify-center ${
                                currentPage === pageNum ? 'bg-gray-300 text-black' : 'border border-gray-300 text-gray-700 hover:bg-gray-50'
                              }`}
                            >
                              {pageNum}
                            </button>
                          );
                        })}
                      </div>
                      <button
                        onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
                        disabled={currentPage === totalPages}
                        className={`flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${
                          currentPage === totalPages ? 'border-gray-200 text-gray-400 cursor-not-allowed' : 'border-gray-300 text-gray-700 hover:bg-gray-50'
                        }`}
                      >
                        Next <ChevronRight className="w-3 h-3" />
                      </button>
                    </div>
                  )}
                </div>
              </div>
            )}
          </>
        )}
      </div>

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
