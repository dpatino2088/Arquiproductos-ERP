import React, { useState, useMemo, useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useCompanies, type Company } from '../../hooks/useCompanies';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useUIStore } from '../../stores/ui-store';
import { Building, Plus, Edit, Archive, Search, Filter, List, Grid3X3 } from 'lucide-react';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { supabase } from '../../lib/supabase/client';

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

export default function DealerList() {
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const { isSuperAdmin, isOwner, isAdmin, loading: roleLoading } = useCurrentOrgRole();
  const { addNotification } = useUIStore();
  const { dialogState, showConfirm, closeDialog, handleConfirm } = useConfirmDialog();
  
  const { companies, isLoading, error, fetchCompanies, archiveCompany } = useCompanies();
  
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [viewMode, setViewMode] = useState<'table' | 'grid'>('table');
  const [archivingId, setArchivingId] = useState<string | null>(null);

  const canManageCompanies = isSuperAdmin || isOwner || isAdmin;

  // Register tabs for Dealer Profile module (similar to Directory)
  useEffect(() => {
    registerSubmodules('Settings', [
      { id: 'dealer-list', label: 'Dealer List', href: '/settings/dealer-profile' },
      { id: 'dealer-user', label: 'Dealer User', href: '/settings/dealer-profile/user' },
    ]);
  }, [registerSubmodules]);

  const filteredCompanies = useMemo(() => {
    if (!searchTerm) return companies;
    const search = searchTerm.toLowerCase();
    return companies.filter(company => 
      (company.company_name?.toLowerCase() || '').includes(search) ||
      (company.company_email?.toLowerCase() || '').includes(search) ||
      (company.company_no?.toLowerCase() || '').includes(search)
    );
  }, [companies, searchTerm]);

  const handleEdit = (company: Company) => {
    router.navigate(`/settings/dealer-profile/edit/${company.id}`);
  };

  const handleDelete = async (company: Company) => {
    const confirmed = await showConfirm({
      title: 'Archive Dealer',
      message: `Are you sure you want to archive "${company.company_name}"? This action can be undone.`,
      variant: 'warning',
      confirmText: 'Archive',
      cancelText: 'Cancel',
    });

    if (!confirmed) return;

    try {
      setArchivingId(company.id);
      await archiveCompany(company.id);
      addNotification({
        type: 'success',
        title: 'Dealer archived',
        message: `Dealer ${company.company_no || company.company_name} has been archived.`,
      });
      await fetchCompanies();
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
    <div className="py-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Dealer List</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Manage dealers in your organization ({filteredCompanies.length} total)
          </p>
        </div>
        <div className="flex items-center gap-3">
          {canManageCompanies && !roleLoading && (
            <button
              onClick={() => router.navigate('/settings/dealer-profile/new')}
              className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90"
              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            >
              <Plus className="w-4 h-4 inline mr-1" />
              Add Dealer
            </button>
          )}
        </div>
      </div>

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
        <div className="overflow-x-auto">
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
          ) : companies.length === 0 ? (
            <div className="text-center py-12 px-6">
              <Building className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600 mb-2">No dealers found</p>
              <p className="text-sm text-gray-500">
                {canManageCompanies 
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
                  {canManageCompanies && !roleLoading && (
                    <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
                  )}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredCompanies.map((company) => (
                  <tr key={company.id} className="hover:bg-gray-50 transition-colors cursor-pointer" onClick={() => handleEdit(company)}>
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap font-mono">
                      {company.company_no || '-'}
                    </td>
                    <td className="py-4 px-6 text-gray-900 text-sm whitespace-nowrap">
                      <span className="font-medium">{company.company_name}</span>
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap truncate">
                      {company.company_email || '-'}
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap">
                      {company.company_phone || '-'}
                    </td>
                    <td className="py-4 px-6 whitespace-nowrap">
                      <StatusBadge status={company.status} deleted={company.deleted} />
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap">
                      {company.created_at 
                        ? new Date(company.created_at).toLocaleDateString()
                        : '-'}
                    </td>
                    {canManageCompanies && !roleLoading && (
                      <td className="py-4 px-6" onClick={(e) => e.stopPropagation()}>
                        <div className="flex items-center gap-2 justify-end">
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              handleEdit(company);
                            }}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            title="Edit dealer"
                            disabled={company.deleted}
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          {!company.deleted && (
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleDelete(company);
                              }}
                              disabled={archivingId === company.id}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600 disabled:opacity-50"
                              title="Archive dealer"
                            >
                              <Archive className="w-4 h-4" />
                            </button>
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
        loading={dialogState.loading}
      />
    </div>
  );
}
