import { useState, useEffect, useMemo } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useServiceClaims, type ClaimStatus } from '../../hooks/useServiceClaims';
import { useAccessContext } from '../../hooks/useAccessContext';
import { router } from '../../lib/router';
import { withReturnTo } from '../../lib/navigation/returnTo';
import { formatDate } from '../../lib/utils';
import StatusBadge from '../../components/shared/StatusBadge';
import StatusTabs from '../../components/shared/StatusTabs';
import { Search, Plus } from 'lucide-react';

const SERVICE_SUBMODULES = [
  { id: 'claims', label: 'Claims', href: '/service/claims' },
];

const STATUS_VALUES: ClaimStatus[] = ['draft', 'under_review', 'approved', 'in_progress', 'resolved', 'closed', 'rejected'];
const STATUS_LABELS: Record<string, string> = {
  draft: 'Draft',
  under_review: 'Under Review',
  approved: 'Approved',
  in_progress: 'In Progress',
  resolved: 'Resolved',
  closed: 'Closed',
  rejected: 'Rejected',
};

const PRIORITY_COLORS: Record<string, string> = {
  low: 'bg-gray-50 text-gray-700',
  medium: 'bg-blue-50 text-blue-700',
  high: 'bg-orange-50 text-orange-700',
  urgent: 'bg-red-50 text-red-700',
};

const TYPE_LABELS: Record<string, string> = {
  defect: 'Defect',
  damage: 'Damage',
  wrong_size: 'Wrong Size',
  wrong_color: 'Wrong Color',
  missing_parts: 'Missing Parts',
  other: 'Other',
};

export default function Claims() {
  const { registerSubmodules } = useSubmoduleNav();
  const { isInternal } = useAccessContext();
  const { claims, loading } = useServiceClaims();

  const [statusTab, setStatusTab] = useState('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 25;

  useEffect(() => {
    registerSubmodules('Service', SERVICE_SUBMODULES);
  }, [registerSubmodules]);

  const statusCounts = useMemo(() => {
    const counts: Record<string, number> = { all: claims.length };
    STATUS_VALUES.forEach((s) => { counts[s] = 0; });
    claims.forEach((c) => { counts[c.status] = (counts[c.status] || 0) + 1; });
    return counts;
  }, [claims]);

  const statusTabs = useMemo(() => [
    { label: 'All', value: 'all', count: statusCounts.all },
    ...STATUS_VALUES.map((s) => ({ label: STATUS_LABELS[s], value: s, count: statusCounts[s] || 0 })),
  ], [statusCounts]);

  const filtered = useMemo(() => {
    let result = claims;
    if (statusTab !== 'all') result = result.filter((c) => c.status === statusTab);
    if (searchTerm.length >= 2) {
      const q = searchTerm.toLowerCase();
      result = result.filter((c) =>
        (c.claim_no ?? '').toLowerCase().includes(q) ||
        (c.SalesOrders?.sales_order_no ?? '').toLowerCase().includes(q) ||
        (c.Dealers?.dealer_name ?? '').toLowerCase().includes(q) ||
        (c.description ?? '').toLowerCase().includes(q)
      );
    }
    return result;
  }, [claims, statusTab, searchTerm]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / itemsPerPage));
  const paginated = filtered.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  useEffect(() => { setCurrentPage(1); }, [statusTab, searchTerm]);

  const colSpan = isInternal ? 8 : 7;

  return (
    <div className="py-6 px-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Service Claims</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Manage your {claims.length} service {claims.length === 1 ? 'claim' : 'claims'}
          </p>
        </div>
        <button
          type="button"
          onClick={() => router.navigate('/service/claims/new')}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
        >
          <Plus className="w-4 h-4" />
          New Claim
        </button>
      </div>

      <StatusTabs tabs={statusTabs} activeTab={statusTab} onChange={setStatusTab} />

      {/* Search */}
      <div className="mb-4 mt-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center justify-between gap-3 flex-wrap">
            <div className="flex-1 relative min-w-[240px]">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search by claim #, SO #, dealer, description..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search claims"
              />
            </div>
          </div>
        </div>
      </div>

      {/* Table */}
      {loading ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <div className="animate-pulse space-y-4">
            <div className="h-4 bg-gray-200 rounded w-1/4 mx-auto"></div>
            <div className="h-4 bg-gray-200 rounded w-1/2 mx-auto"></div>
          </div>
        </div>
      ) : paginated.length === 0 ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <p className="text-gray-500 mb-2">No claims found</p>
          <p className="text-sm text-gray-400">
            {searchTerm
              ? 'Try adjusting your search'
              : 'Create your first claim to get started'}
          </p>
        </div>
      ) : (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="py-3 px-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wide">Claim #</th>
                <th className="py-3 px-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wide">Date</th>
                <th className="py-3 px-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wide">SO #</th>
                {isInternal && <th className="py-3 px-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wide">Dealer</th>}
                <th className="py-3 px-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wide">Type</th>
                <th className="py-3 px-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wide">Priority</th>
                <th className="py-3 px-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wide">Status</th>
                <th className="py-3 px-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wide">Description</th>
              </tr>
            </thead>
            <tbody>
              {paginated.map((c) => (
                <tr
                  key={c.id}
                  onClick={() => router.navigate(withReturnTo(`/service/claims/${c.id}`))}
                  className="border-b border-gray-100 last:border-0 hover:bg-gray-50 cursor-pointer transition-colors"
                >
                  <td className="py-3 px-4 font-medium text-primary">{c.claim_no}</td>
                  <td className="py-3 px-3 text-gray-600 tabular-nums">{formatDate(c.created_at)}</td>
                  <td className="py-3 px-3 text-gray-700">{c.SalesOrders?.sales_order_no ?? '—'}</td>
                  {isInternal && <td className="py-3 px-3 text-gray-700 truncate max-w-[200px]">{c.Dealers?.dealer_name ?? '—'}</td>}
                  <td className="py-3 px-3 text-gray-600">{TYPE_LABELS[c.claim_type] ?? c.claim_type}</td>
                  <td className="py-3 px-3">
                    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${PRIORITY_COLORS[c.priority] ?? 'bg-gray-50 text-gray-700'}`}>
                      {c.priority?.charAt(0).toUpperCase() + c.priority?.slice(1)}
                    </span>
                  </td>
                  <td className="py-3 px-3"><StatusBadge status={c.status} type="claim" /></td>
                  <td className="py-3 px-3 text-gray-500 truncate max-w-xs">{c.description ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>

          {totalPages > 1 && (
            <div className="flex items-center justify-between px-4 py-3 border-t border-gray-200 text-sm text-gray-500">
              <span>Showing {(currentPage - 1) * itemsPerPage + 1}–{Math.min(currentPage * itemsPerPage, filtered.length)} of {filtered.length}</span>
              <div className="flex gap-1">
                <button disabled={currentPage <= 1} onClick={() => setCurrentPage((p) => p - 1)} className="px-2 py-1 rounded border border-gray-200 hover:bg-gray-50 disabled:opacity-40">Prev</button>
                <button disabled={currentPage >= totalPages} onClick={() => setCurrentPage((p) => p + 1)} className="px-2 py-1 rounded border border-gray-200 hover:bg-gray-50 disabled:opacity-40">Next</button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
