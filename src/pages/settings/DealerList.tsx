import React, { useState, useMemo, useEffect } from 'react';
import { router } from '../../lib/router';
import { formatDate } from '../../lib/utils';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useDealers, type Dealer } from '../../hooks/useDealers';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useUIStore } from '../../stores/ui-store';
import { Building, Plus, Edit, Trash2, Search, Filter, List, Grid3X3, Eye } from 'lucide-react';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { supabase } from '../../lib/supabase/client';
import { withReturnTo } from '../../lib/navigation/returnTo';

interface StatusBadgeProps {
  status: string;
  deleted?: boolean;
}

function StatusBadge({ status, deleted = false }: StatusBadgeProps) {
  if (deleted) {
    return (
      <span className="px-2 py-1 rounded text-xs font-medium bg-gray-100 text-gray-600 border border-gray-300">
        Archived
      </span>
    );
  }

  const normalizedStatus = (status || '').toLowerCase().trim();
  
  const statusColors: Record<string, { bg: string; text: string; border: string; label: string }> = {
    active: { 
      bg: 'bg-green-50', 
      text: 'text-green-700', 
      border: 'border border-green-200',
      label: 'Active'
    },
    disabled: { 
      bg: 'bg-gray-50', 
      text: 'text-gray-700', 
      border: 'border border-gray-200',
      label: 'Disabled'
    }
  };

  const colors = statusColors[normalizedStatus] || statusColors.disabled;

  return (
    <span className={`px-2 py-1 rounded text-xs font-medium ${colors.bg} ${colors.text} ${colors.border}`}>
      {colors.label}
    </span>
  );
}

interface DealerListProps {
  basePath?: string;
  moduleLabel?: string;
  skipSubmoduleRegistration?: boolean;
  /** Section title (e.g. "Accounts"). Default "Dealer List". */
  sectionTitle?: string;
  /** When true, hide the top header bar (title + subtitle + Add Dealer). Content is search + table only. */
  hideSectionHeader?: boolean;
}

export default function DealerList({ basePath = '/settings/dealer-profile', moduleLabel = 'Settings', skipSubmoduleRegistration = false, sectionTitle = 'Accounts', hideSectionHeader = false }: DealerListProps) {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { isSuperAdmin, isOwner, isAdmin, isMember, loading: roleLoading } = useCurrentOrgRole();
  const { addNotification } = useUIStore();
  const { dialogState, showConfirm, closeDialog, handleConfirm } = useConfirmDialog();
  
  const { dealers, isLoading, error, fetchDealers, archiveDealer } = useDealers();
  
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [archivingId, setArchivingId] = useState<string | null>(null);

  const canManageDealers = isSuperAdmin || isOwner || isAdmin || isMember;

  useEffect(() => {
    if (skipSubmoduleRegistration) return;
    registerSubmodules(moduleLabel, [
      { id: 'dealer-list', label: sectionTitle, href: basePath },
    ]);
  }, [registerSubmodules, moduleLabel, basePath, skipSubmoduleRegistration, sectionTitle]);

  const filteredDealers = useMemo(() => {
    if (!searchTerm) return dealers;
    const search = searchTerm.toLowerCase();
    return dealers.filter(dealer =>
      (dealer.dealer_name?.toLowerCase() || '').includes(search) ||
      (dealer.dealer_email?.toLowerCase() || '').includes(search) ||
      (dealer.dealer_no?.toLowerCase() || '').includes(search)
    );
  }, [dealers, searchTerm]);

  const handleEdit = (dealer: Dealer) => {
    router.navigate(`${basePath}/edit/${dealer.id}`);
  };

  const handleViewDetail = (dealer: Dealer) => {
    if (basePath === '/partners/dealers') {
      router.navigate(withReturnTo(`/financials/accounts/${dealer.id}`, '/partners/dealers'));
      return;
    }
    handleEdit(dealer);
  };

  const handleDelete = async (dealer: Dealer) => {
    const confirmed = await showConfirm({
      title: 'Archive Dealer',
      message: `Are you sure you want to archive "${dealer.dealer_name}"? This action can be undone.`,
      variant: 'warning',
      confirmText: 'Archive',
      cancelText: 'Cancel',
    });

    if (!confirmed) return;

    try {
      setArchivingId(dealer.id);
      await archiveDealer(dealer.id);
      addNotification({
        type: 'success',
        title: 'Dealer archived',
        message: `Dealer ${dealer.dealer_no || dealer.dealer_name} has been archived.`,
      });
      await fetchDealers();
    } catch (err: any) {
      addNotification({
        type: 'error',
        title: 'Error archiving dealer',
        message: err?.message || 'Failed to archive dealer.',
      });
    } finally {
      setArchivingId(null);
    }
  };

  if (!activeOrganizationId) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800">Please select an organization to view dealers.</p>
        </div>
      </div>
    );
  }

  if (roleLoading) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="text-center py-8">
          <div className="text-sm text-gray-500">Loading permissions...</div>
        </div>
      </div>
    );
  }

  return (
    <div className={hideSectionHeader ? '' : 'py-6'}>
      {!hideSectionHeader && (
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-xl font-semibold text-foreground mb-1">{sectionTitle}</h1>
            <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
              Manage dealers in your organization ({filteredDealers.length} total)
            </p>
          </div>
          <div className="flex items-center gap-3">
            {canManageDealers && !roleLoading && (
              <button
                onClick={() => router.navigate(`${basePath}/new`)}
                className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                <Plus className="w-4 h-4 inline mr-1" />
                Add Dealer
              </button>
            )}
          </div>
        </div>
      )}

      {/* Search and Filters */}
      <div className="mb-4">
        <div className={`bg-white border border-gray-200 py-6 px-6 ${
          showFilters ? 'rounded-t-lg' : 'rounded-lg'
        }`}>
          <div className="flex items-center justify-between gap-3">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search dealers by name, email, number..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search dealers"
              />
            </div>
            
            <div className="flex items-center gap-2">
              <button
                onClick={() => setShowFilters(!showFilters)}
                className={`flex items-center gap-2 px-2 py-1 border border-gray-300 rounded transition-colors text-sm ${
                  showFilters ? 'bg-gray-300 text-black' : 'bg-white text-gray-700 hover:bg-gray-50'
                }`}
              >
                <Filter style={{ width: '14px', height: '14px' }} />
                Filters
              </button>

              <div className="flex border border-gray-200 rounded overflow-hidden">
                <button
                  onClick={() => setViewMode('table')}
                  className={`p-1.5 transition-colors ${
                    viewMode === 'table'
                      ? 'bg-gray-300 text-black'
                      : 'bg-white text-gray-600 hover:bg-gray-50'
                  }`}
                >
                  <List className="w-4 h-4" />
                </button>
                <button
                  onClick={() => setViewMode('grid')}
                  className={`p-1.5 transition-colors ${
                    viewMode === 'grid'
                      ? 'bg-gray-300 text-black'
                      : 'bg-white text-gray-600 hover:bg-gray-50'
                  }`}
                >
                  <Grid3X3 className="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>

        {showFilters && (
          <div className="bg-white border-l border-r border-b border-gray-200 rounded-b-lg py-6 px-6">
            <p className="text-sm text-gray-500">Additional filters will be available here.</p>
          </div>
        )}
      </div>

      {/* Table */}
      <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
        <div className="table-fit-wrapper">
          {isLoading ? (
            <div className="text-center py-12 px-6">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
              <p className="text-sm text-gray-600">Loading dealers...</p>
            </div>
          ) : error ? (
            <div className="py-6 px-6">
              <div className="bg-red-50 border border-red-200 rounded-lg p-4">
                <p className="text-sm text-red-800">Error loading dealers: {error}</p>
              </div>
            </div>
          ) : dealers.length === 0 ? (
            <div className="text-center py-12 px-6">
              <Building className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600 mb-2">No dealers found</p>
              <p className="text-sm text-gray-500">
                {canManageDealers 
                  ? 'Start by adding dealers to your organization'
                  : 'Dealers will appear here once they are created.'}
              </p>
            </div>
          ) : (
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Dealer Number</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Dealer Name</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Email</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Phone</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Status</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Date Added</th>
                  {(basePath === '/partners/dealers' || canManageDealers) && !roleLoading && (
                    <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
                  )}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredDealers.map((dealer) => (
                  <tr key={dealer.id} className="hover:bg-gray-50 transition-colors">
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap font-mono">
                      {dealer.dealer_no || '-'}
                    </td>
                    <td className="py-4 px-6 text-gray-900 text-sm whitespace-nowrap">
                      <span className="font-medium">{dealer.dealer_name}</span>
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap truncate">
                      {dealer.dealer_email || '-'}
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap">
                      {dealer.dealer_phone || '-'}
                    </td>
                    <td className="py-4 px-6 whitespace-nowrap">
                      <StatusBadge status={dealer.status} deleted={dealer.deleted} />
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap">
                      {dealer.created_at 
                        ? formatDate(dealer.created_at)
                        : '-'}
                    </td>
                    {(basePath === '/partners/dealers' || canManageDealers) && !roleLoading && (
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-2 justify-end">
                          {basePath === '/partners/dealers' && (
                            <button
                              type="button"
                              onClick={() => handleViewDetail(dealer)}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                              title="Ver cuenta financiera"
                              disabled={dealer.deleted}
                            >
                              <Eye className="w-4 h-4" />
                            </button>
                          )}
                          {canManageDealers && (
                            <>
                              <button
                                type="button"
                                onClick={() => handleEdit(dealer)}
                                className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                                title="Editar dealer"
                                disabled={dealer.deleted}
                              >
                                <Edit className="w-4 h-4" />
                              </button>
                              {!dealer.deleted && (
                                <button
                                  type="button"
                                  onClick={async () => {
                                    await handleDelete(dealer);
                                  }}
                                  disabled={archivingId === dealer.id}
                                  className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                                  title="Eliminar (archivar) dealer"
                                >
                                  <Trash2 className="w-4 h-4" />
                                </button>
                              )}
                            </>
                          )}
                        </div>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          )}
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
