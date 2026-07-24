/**
 * Portal Quotes List Component
 * 
 * Displays quotes for portal users with role-based access:
 * - dealer_member: sees only own quotes
 * - dealer_manager: sees all company quotes
 */

import { useEffect, useMemo, useState } from 'react';
import { supabase } from '../../lib/supabase/client';
import { formatDate } from '../../lib/utils';
import { useAuthStore } from '../../stores/auth-store';
import { useUIStore } from '../../stores/ui-store';
import { 
  canCreateQuote, 
  canViewQuote, 
  normalizeRole,
  type CompanyPortalRole,
  type PortalQuote 
} from '../../portal/portalAccess';
import { Plus, FileText, CheckCircle, XCircle, Clock, Copy, ChevronRight, ChevronDown } from 'lucide-react';
import { duplicateQuote } from '../../hooks/useQuotes';
import DuplicateQuoteModal, { type DuplicateQuoteMode } from '../../components/sales/DuplicateQuoteModal';

type PortalQuoteRow = PortalQuote & {
  parent_quote_id?: string | null;
  root_quote_id?: string | null;
  version_no?: number | null;
  is_version?: boolean | null;
};

interface PortalUser {
  id: string;
  dealer_id: string;
  portal_user_role: CompanyPortalRole | null;
}

export default function PortalQuotesList() {
  const { user } = useAuthStore();
  const [quotes, setQuotes] = useState<PortalQuoteRow[]>([]);
  const [portalUser, setPortalUser] = useState<PortalUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const setGlobalLoading = useUIStore((s) => s.setGlobalLoading);
  const addNotification = useUIStore((s) => s.addNotification);
  const [duplicateTarget, setDuplicateTarget] = useState<PortalQuoteRow | null>(null);
  const [duplicatingLoading, setDuplicatingLoading] = useState(false);
  const [expandedGroups, setExpandedGroups] = useState<Set<string>>(new Set());
  const [refreshTick, setRefreshTick] = useState(0);

  useEffect(() => {
    setGlobalLoading(loading);
    return () => setGlobalLoading(false);
  }, [loading, setGlobalLoading]);

  // Load portal user info
  useEffect(() => {
    const loadPortalUser = async () => {
      if (!user?.id) {
        setLoading(false);
        return;
      }

      try {
        const { data, error: userError } = await supabase
          .from('DealerUsers')
          // IMPORTANT: Use 'role' and 'status' columns (matches actual DB schema)
          .select('id, dealer_id, role, status')
          .eq('user_id', user.id)
          .eq('deleted', false)
          .in('status', ['active', 'invited'])
          .maybeSingle();

        if (userError) {
          console.error('[PortalQuotesList] DealerUsers lookup error', {
            message: userError.message,
            details: userError.details,
            hint: userError.hint,
            code: userError.code,
          });
          throw userError;
        }

        if (data) {
          // Use 'role' column (matches actual DB schema)
          const rawRole = data.role;
          setPortalUser({
            id: data.id,
            dealer_id: data.dealer_id,
            portal_user_role: normalizeRole(rawRole || 'member'),
          });
        }
      } catch (err: any) {
        console.error('Error loading portal user:', err);
        setError(err.message || 'Failed to load portal user');
      } finally {
        setLoading(false);
      }
    };

    loadPortalUser();
  }, [user]);

  // Load quotes
  useEffect(() => {
    const loadQuotes = async () => {
      if (!portalUser || !user?.id) {
        setQuotes([]);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        // RLS will automatically filter based on role
        const { data, error: quotesError } = await supabase
          .from('Quotes')
          .select('id, quote_no, status, dealer_id, created_by_user_id, created_at, parent_quote_id, root_quote_id, version_no, is_version')
          .eq('dealer_id', portalUser.dealer_id)
          .eq('deleted', false)
          .order('created_at', { ascending: false });

        if (quotesError) throw quotesError;

        // Filter by role (additional client-side check)
        const filteredQuotes = (data || []).filter((quote: any) =>
          canViewQuote(portalUser.portal_user_role, quote, user?.id)
        ) as PortalQuoteRow[];

        setQuotes(filteredQuotes);
      } catch (err: any) {
        console.error('Error loading quotes:', err);
        setError(err.message || 'Failed to load quotes');
        setQuotes([]);
      } finally {
        setLoading(false);
      }
    };

    loadQuotes();
  }, [portalUser, user, refreshTick]);

  type PortalGroup = { key: string; latest: PortalQuoteRow; older: PortalQuoteRow[] };
  const groupedQuotes: PortalGroup[] = useMemo(() => {
    const map = new Map<string, PortalQuoteRow[]>();
    quotes.forEach((q) => {
      const key = (q.root_quote_id as string | null) ?? q.id;
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(q);
    });
    const groups: PortalGroup[] = [];
    map.forEach((rows, key) => {
      const sorted = [...rows].sort((a, b) => {
        const av = Number(a.version_no ?? 1);
        const bv = Number(b.version_no ?? 1);
        if (av !== bv) return bv - av;
        return new Date(b.created_at || 0).getTime() - new Date(a.created_at || 0).getTime();
      });
      const [latest, ...older] = sorted;
      groups.push({ key, latest, older });
    });
    groups.sort(
      (a, b) => new Date(b.latest.created_at || 0).getTime() - new Date(a.latest.created_at || 0).getTime()
    );
    return groups;
  }, [quotes]);

  const handleDuplicateConfirm = async (mode: DuplicateQuoteMode, recalculate: boolean) => {
    if (!duplicateTarget) return;
    setDuplicatingLoading(true);
    try {
      const newId = await duplicateQuote(duplicateTarget.id, mode, recalculate);
      addNotification({
        type: 'success',
        title: mode === 'version' ? 'Version created' : 'Quote duplicated',
        message:
          mode === 'version'
            ? 'A new version linked to the original quote was created.'
            : 'An independent quote was created.',
      });
      setDuplicateTarget(null);
      setRefreshTick((t) => t + 1);
      window.location.href = `/portal/quotes/${newId}/edit`;
    } catch (err: any) {
      addNotification({
        type: 'error',
        title: 'Error duplicando',
        message: err?.message || 'Failed to duplicate quote',
      });
    } finally {
      setDuplicatingLoading(false);
    }
  };

  const toggleGroup = (key: string) => {
    setExpandedGroups((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'approved':
        return <CheckCircle className="w-4 h-4 text-green-600" />;
      case 'rejected':
        return <XCircle className="w-4 h-4 text-red-600" />;
      case 'sent':
        return <Clock className="w-4 h-4 text-yellow-600" />;
      default:
        return <FileText className="w-4 h-4 text-gray-600" />;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'approved':
        return 'bg-green-50 text-green-700 border-green-200';
      case 'rejected':
        return 'bg-red-50 text-red-700 border-red-200';
      case 'sent':
        return 'bg-yellow-50 text-yellow-700 border-yellow-200';
      default:
        return 'bg-gray-50 text-gray-700 border-gray-200';
    }
  };

  if (loading) return <div className="p-6" />;

  if (error) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error</p>
          <p className="text-sm text-red-700">{error}</p>
        </div>
      </div>
    );
  }

  if (!portalUser) {
    return (
      <div className="p-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800">You are not a portal user or your account is not active.</p>
        </div>
      </div>
    );
  }

  const canCreate = canCreateQuote(portalUser.portal_user_role);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-gray-900 mb-1">Quotes</h1>
          <p className="text-sm text-gray-500">
            {portalUser.portal_user_role === 'dealer_manager'
              ? 'All company quotes'
              : 'Your quotes'}
          </p>
        </div>
        {canCreate && (
          <button
            onClick={() => {
              // Navigate to create quote page
              window.location.href = '/portal/quotes/new';
            }}
            className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-md hover:opacity-90 transition-opacity"
          >
            <Plus className="w-4 h-4" />
            New Quote
          </button>
        )}
      </div>

      {/* Quotes List */}
      {quotes.length === 0 ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <FileText className="w-12 h-12 text-gray-400 mx-auto mb-4" />
          <p className="text-gray-600 mb-2">No quotes found</p>
          <p className="text-sm text-gray-500">
            {canCreate
              ? 'Create your first quote to get started'
              : 'Quotes will appear here once they are created'}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {groupedQuotes.map((group) => {
            const isExpanded = expandedGroups.has(group.key);
            const visibleRows = isExpanded ? [group.latest, ...group.older] : [group.latest];
            return (
              <div key={group.key} className="space-y-3">
                {visibleRows.map((quote, idx) => {
                  const isLatest = idx === 0;
                  return (
                    <div
                      key={quote.id}
                      onClick={() => {
                        window.location.href = `/portal/quotes/${quote.id}`;
                      }}
                      className={`relative bg-white border rounded-lg p-6 hover:shadow-lg transition-shadow cursor-pointer ${
                        isLatest ? 'border-gray-200' : 'border-gray-200 bg-gray-50 ml-6'
                      }`}
                    >
                      <div className="flex items-start justify-between mb-4 gap-3">
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 flex-wrap">
                            <h3 className="text-lg font-semibold text-gray-900">{quote.quote_no}</h3>
                            {Number(quote.version_no ?? 1) > 1 && (
                              <span className="text-[10px] bg-blue-100 text-blue-700 px-1.5 py-0.5 rounded font-semibold">
                                v{Number(quote.version_no)}
                              </span>
                            )}
                            {isLatest && group.older.length > 0 && (
                              <button
                                type="button"
                                onClick={(e) => {
                                  e.stopPropagation();
                                  toggleGroup(group.key);
                                }}
                                className="inline-flex items-center gap-1 text-[10px] text-gray-600 hover:text-gray-900 p-1 rounded"
                                title={`${group.older.length} previous version${group.older.length > 1 ? 's' : ''}`}
                              >
                                {isExpanded ? (
                                  <ChevronDown className="w-3 h-3" />
                                ) : (
                                  <ChevronRight className="w-3 h-3" />
                                )}
                                <span className="inline-block w-2 h-2 rounded-full bg-blue-500" />
                              </button>
                            )}
                          </div>
                          <p className="text-xs text-gray-500 mt-1">
                            {quote.created_at ? formatDate(quote.created_at) : 'N/A'}
                          </p>
                        </div>
                        <div
                          className={`flex items-center gap-1 px-2 py-1 rounded border ${getStatusColor(quote.status)}`}
                        >
                          {getStatusIcon(quote.status)}
                          <span className="text-xs font-medium capitalize">{quote.status}</span>
                        </div>
                      </div>

                      {canCreate && (
                        <div className="flex justify-end" onClick={(e) => e.stopPropagation()}>
                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              setDuplicateTarget(quote);
                            }}
                            className="inline-flex items-center gap-1.5 text-xs font-medium text-gray-600 hover:text-gray-900 px-2 py-1 rounded hover:bg-gray-100"
                          >
                            <Copy className="w-3.5 h-3.5" />
                            Duplicate
                          </button>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            );
          })}
        </div>
      )}

      <DuplicateQuoteModal
        isOpen={!!duplicateTarget}
        onClose={() => !duplicatingLoading && setDuplicateTarget(null)}
        onConfirm={handleDuplicateConfirm}
        sourceQuoteNo={duplicateTarget?.quote_no ?? null}
        disableVersion={duplicateTarget?.status === 'converted'}
        versionDisabledReason={
          duplicateTarget?.status === 'converted'
            ? 'This quote already has a Sales Order. Only an independent copy can be created.'
            : null
        }
        isLoading={duplicatingLoading}
      />
    </div>
  );
}
