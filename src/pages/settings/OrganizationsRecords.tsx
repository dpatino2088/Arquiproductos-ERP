import React, { useState, useMemo, useEffect } from 'react';
import { useOrganizations, Organization } from '../../hooks/useOrganizations';
import { Building2, Mail, MapPin, Calendar } from 'lucide-react';

interface OrganizationsRecordsProps {
  onSelectOrganization: (org: Organization) => void;
  selectedOrganizationId?: string;
  onRefetchReady?: (refetch: () => Promise<void>) => void;
}

export default function OrganizationsRecords({ onSelectOrganization, selectedOrganizationId, onRefetchReady }: OrganizationsRecordsProps) {
  const { organizations, isLoading, error, refetch } = useOrganizations();
  
  // Expose refetch function to parent
  useEffect(() => {
    if (onRefetchReady && refetch) {
      onRefetchReady(refetch);
    }
  }, [onRefetchReady, refetch]);
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);

  // Filter organizations based on search term
  const filteredOrganizations = useMemo(() => {
    if (!searchTerm.trim()) return organizations;
    
    const search = searchTerm.toLowerCase();
    return organizations.filter(org => 
      org.name?.toLowerCase().includes(search) ||
      org.legal_name?.toLowerCase().includes(search) ||
      org.main_email?.toLowerCase().includes(search) ||
      org.country?.toLowerCase().includes(search) ||
      org.tier?.toLowerCase().includes(search) ||
      org.status?.toLowerCase().includes(search)
    );
  }, [organizations, searchTerm]);

  // Pagination calculations
  const totalPages = Math.ceil(filteredOrganizations.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedOrganizations = filteredOrganizations.slice(startIndex, startIndex + itemsPerPage);

  // Format date
  const formatDate = (dateString: string | null | undefined) => {
    if (!dateString) return 'N/A';
    try {
      return new Date(dateString).toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric'
      });
    } catch {
      return 'N/A';
    }
  };

  // Get status badge
  const getStatusBadge = (status: string | null | undefined) => {
    switch (status) {
      case 'active':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-green-50 text-green-700">
            Active
          </span>
        );
      case 'trialing':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-blue-50 text-blue-700">
            Trialing
          </span>
        );
      case 'suspended':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-red-50 text-red-700">
            Suspended
          </span>
        );
      default:
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-gray-50 text-gray-700">
            {status || 'N/A'}
          </span>
        );
    }
  };

  // Get tier badge
  const getTierBadge = (tier: string | null | undefined) => {
    const defaultColors = { bg: 'bg-gray-50', text: 'text-gray-700' };
    const tierColors: Record<string, { bg: string; text: string }> = {
      free: defaultColors,
      starter: { bg: 'bg-blue-50', text: 'text-blue-700' },
      pro: { bg: 'bg-purple-50', text: 'text-purple-700' },
      enterprise: { bg: 'bg-green-50', text: 'text-green-700' },
    };
    
    const tierKey = tier || 'free';
    const colors = tierColors[tierKey] ?? defaultColors;
    return (
      <span className={`px-1.5 py-0.5 rounded-full text-xs font-medium capitalize ${colors.bg} ${colors.text}`}>
        {tier || 'Free'}
      </span>
    );
  };

  if (isLoading) {
    return (
      <div className="p-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">Loading organizations...</p>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <p className="text-sm text-red-600 mb-2">Error loading organizations: {error}</p>
            <button 
              onClick={() => window.location.reload()} 
              className="px-4 py-2 bg-primary text-white rounded hover:opacity-90"
            >
              Retry
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Organization Records</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {`${filteredOrganizations.length} organization${filteredOrganizations.length !== 1 ? 's' : ''}${filteredOrganizations.length > itemsPerPage ? ` (Page ${currentPage} of ${totalPages})` : ''}`}
          </p>
        </div>
      </div>

      {/* Search Bar */}
      <div className="mb-4">
        <div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
          <div className="flex items-center gap-3">
            <input
              type="text"
              placeholder="Search organizations by name, email, country, tier, or status..."
              value={searchTerm}
              onChange={(e) => {
                setSearchTerm(e.target.value);
                setCurrentPage(1);
              }}
              className="flex-1 px-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
              aria-label="Search organizations"
            />
          </div>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-gray-50 border-b border-gray-200">
                <th className="px-4 py-3 text-left text-xs font-semibold text-gray-700 uppercase tracking-wider">
                  Organization Name
                </th>
                <th className="px-4 py-3 text-left text-xs font-semibold text-gray-700 uppercase tracking-wider">
                  Legal Name
                </th>
                <th className="px-4 py-3 text-left text-xs font-semibold text-gray-700 uppercase tracking-wider">
                  Country
                </th>
                <th className="px-4 py-3 text-left text-xs font-semibold text-gray-700 uppercase tracking-wider">
                  Tier
                </th>
                <th className="px-4 py-3 text-left text-xs font-semibold text-gray-700 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-4 py-3 text-left text-xs font-semibold text-gray-700 uppercase tracking-wider">
                  Main Email
                </th>
                <th className="px-4 py-3 text-left text-xs font-semibold text-gray-700 uppercase tracking-wider">
                  Created At
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {paginatedOrganizations.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-12 text-center">
                    <Building2 className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                    <p className="text-sm text-gray-600">No organizations found</p>
                    {searchTerm && (
                      <p className="text-xs text-gray-500 mt-1">
                        Try adjusting your search terms
                      </p>
                    )}
                  </td>
                </tr>
              ) : (
                paginatedOrganizations.map((org) => (
                  <tr
                    key={org.id}
                    onClick={() => onSelectOrganization(org)}
                    className={`hover:bg-gray-50 cursor-pointer transition-colors ${
                      selectedOrganizationId === org.id ? 'bg-primary/5' : ''
                    }`}
                  >
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 bg-primary/10 rounded-lg flex items-center justify-center flex-shrink-0">
                          <Building2 
                            className="w-4 h-4"
                            style={{ color: 'var(--primary-brand-hex)' }}
                          />
                        </div>
                        <div>
                          <div className="text-sm font-medium text-gray-900">{org.name || 'N/A'}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="text-sm text-gray-700">{org.legal_name || 'N/A'}</div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1 text-sm text-gray-700">
                        <MapPin className="w-3 h-3 text-gray-400" />
                        {org.country || 'N/A'}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      {getTierBadge(org.tier)}
                    </td>
                    <td className="px-4 py-3">
                      {getStatusBadge(org.status)}
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1 text-sm text-gray-700">
                        <Mail className="w-3 h-3 text-gray-400" />
                        {org.main_email || 'N/A'}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1 text-sm text-gray-700">
                        <Calendar className="w-3 h-3 text-gray-400" />
                        {formatDate(org.created_at)}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="px-4 py-3 border-t border-gray-200 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="text-xs text-gray-700">Rows per page:</span>
              <select
                value={itemsPerPage}
                onChange={(e) => {
                  setItemsPerPage(Number(e.target.value));
                  setCurrentPage(1);
                }}
                className="px-2 py-1 border border-gray-200 rounded text-xs"
              >
                <option value={10}>10</option>
                <option value={25}>25</option>
                <option value={50}>50</option>
                <option value={100}>100</option>
              </select>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-xs text-gray-700">
                {startIndex + 1}-{Math.min(startIndex + itemsPerPage, filteredOrganizations.length)} of {filteredOrganizations.length}
              </span>
              <button
                onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                disabled={currentPage === 1}
                className="px-2 py-1 border border-gray-200 rounded text-xs disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
              >
                Previous
              </button>
              <button
                onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
                disabled={currentPage === totalPages}
                className="px-2 py-1 border border-gray-200 rounded text-xs disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
              >
                Next
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

