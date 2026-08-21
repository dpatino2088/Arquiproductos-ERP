import { useEffect, useMemo, useState, useCallback } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { router } from '../../lib/router';
import { withReturnTo } from '../../lib/navigation/returnTo';

import {
  useProposalsList,
  fetchProposalDetailData,
  createStandaloneProposal,
  createProposalVersion,
  createProposalFromQuote,
  duplicateProposalAsCopy,
  type ProposalListItem,
} from '../../hooks/useProposals';
import DuplicateProposalModal, {
  type DuplicateProposalMode,
} from '../../components/sales/DuplicateProposalModal';
import { useUIStore } from '../../stores/ui-store';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useActiveDealer } from '../../hooks/useActiveDealer';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useGranularAccess } from '../../hooks/usePermissions';
import { useDealerConfiguratorPolicy } from '../../hooks/useDealerConfiguratorPolicy';
import { buildDirectoryScopeKey } from '../../lib/directoryScopeKey';
import { proposalDetailKey } from '../../lib/queryKeys';
import { warmDetailIfNeeded } from '../../lib/zeroLoading';
import { useNearViewportWarm } from '../../hooks/useNearViewportWarm';
import {
  Search,
  RefreshCw,
  SortAsc,
  SortDesc,
  Plus,
  Edit,
  ExternalLink,
  Trash2,
  Archive,
  RotateCcw,
  Copy,
  ChevronRight,
  ChevronDown,
} from 'lucide-react';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { supabase } from '../../lib/supabase/client';
import { getSupabaseErrorMessage } from '../../lib/supabase-error-utils';
import StatusBadge from '../../components/shared/StatusBadge';
import StatusTabs from '../../components/shared/StatusTabs';
import { formatDate } from '../../lib/utils';

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
  const { activeOrganizationId } = useOrganizationContext();
  const { activeDealerId } = useActiveDealer();
  const { userType } = useAccessContext();
  const { canCreate: canCreateProp, canArchive: canArchiveProp, canDelete: canDeleteProp } = useGranularAccess('proposals');
  const { policy: dealerPolicy } = useDealerConfiguratorPolicy();
  const allowStandalone = Boolean(dealerPolicy?.allow_custom_only_proposals);
  const queryClient = useQueryClient();
  const [creatingStandalone, setCreatingStandalone] = useState(false);

  const scopeKey = useMemo(
    () =>
      buildDirectoryScopeKey({
        orgId: activeOrganizationId ?? null,
        activeDealerId: activeDealerId ?? null,
        userRole: userType,
      }),
    [activeOrganizationId, activeDealerId, userType]
  );
  const isScopeReady = !!activeOrganizationId;
  const warmDetail = useCallback(
    (proposalId: string) => {
      if (!isScopeReady || !scopeKey || !proposalId) return;
      warmDetailIfNeeded(
        queryClient,
        {
          queryKey: proposalDetailKey(scopeKey, proposalId),
          queryFn: () => fetchProposalDetailData(proposalId),
          warmId: `${scopeKey}:${proposalId}`,
          enabled: true,
        },
        { cooldownMs: 20_000 }
      );
    },
    [queryClient, scopeKey, isScopeReady]
  );
  const rowRefForViewport = useNearViewportWarm(warmDetail, { rootMargin: '200px' });

  useEffect(() => {
    setGlobalLoading(loading);
    return () => setGlobalLoading(false);
  }, [loading, setGlobalLoading]);

  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(25);
  const [sortBy, setSortBy] = useState<'proposal_no' | 'status' | 'customer_name' | 'total' | 'updated_at'>('updated_at');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [statusTab, setStatusTab] = useState(() => {
    const raw = new URLSearchParams(window.location.search).get('status')?.toLowerCase() ?? 'all';
    if (raw === 'draft' || raw === 'sent' || raw === 'accepted' || raw === 'rejected' || raw === 'expired' || raw === 'cancelled' || raw === 'archived' || raw === 'all') {
      return raw;
    }
    return 'all';
  });

  const nonArchivedList = useMemo(() => list.filter((p) => !p.archived), [list]);
  const archivedCount = useMemo(() => list.filter((p) => p.archived).length, [list]);

  const proposalVersionNo = useCallback((p: { proposal_no?: string | null; version_no?: number | null }) => {
    const fromCol = Number(p.version_no);
    if (Number.isFinite(fromCol) && fromCol > 0) return fromCol;
    const m = (p.proposal_no || '').match(/_V(\d+)$/i);
    return m ? Number(m[1]) : 1;
  }, []);
  const proposalBaseNo = useCallback(
    (p: { proposal_no?: string | null; id: string }) => (p.proposal_no || '').replace(/_V\d+$/i, '') || p.id,
    []
  );

  // Older versions per proposal id (whole PR family, includes archived), to show under a chevron.
  const olderVersionsByRowId = useMemo(() => {
    type Row = (typeof list)[number];
    const byBase = new Map<string, Row[]>();
    list.forEach((p) => {
      const base = proposalBaseNo(p);
      const arr = byBase.get(base) ?? [];
      arr.push(p);
      byBase.set(base, arr);
    });
    const map = new Map<string, Row[]>();
    list.forEach((p) => {
      const base = proposalBaseNo(p);
      const v = proposalVersionNo(p);
      const older = (byBase.get(base) ?? [])
        .filter((x) => x.id !== p.id && proposalVersionNo(x) < v)
        .sort((a, b) => proposalVersionNo(b) - proposalVersionNo(a));
      if (older.length > 0) map.set(p.id, older);
    });
    return map;
  }, [list, proposalBaseNo, proposalVersionNo]);

  const [expandedFamilies, setExpandedFamilies] = useState<Set<string>>(new Set());
  const toggleFamily = useCallback((rowId: string) => {
    setExpandedFamilies((prev) => {
      const next = new Set(prev);
      if (next.has(rowId)) next.delete(rowId);
      else next.add(rowId);
      return next;
    });
  }, []);

  const proposalStatusCounts = useMemo(() => {
    const c: Record<string, number> = { all: 0 };
    nonArchivedList.forEach((p) => {
      c[p.status] = (c[p.status] || 0) + 1;
      // Cancelled (superseded) versions live in their own tab, not in "All".
      if (p.status !== 'cancelled') c.all += 1;
    });
    return c;
  }, [nonArchivedList]);

  const proposalStatusTabs = useMemo(
    () => [
      { label: 'All', value: 'all', count: proposalStatusCounts.all || 0 },
      { label: 'Draft', value: 'draft', count: proposalStatusCounts.draft || 0 },
      { label: 'Sent', value: 'sent', count: proposalStatusCounts.sent || 0 },
      { label: 'Accepted', value: 'accepted', count: proposalStatusCounts.accepted || 0 },
      { label: 'Rejected', value: 'rejected', count: proposalStatusCounts.rejected || 0 },
      { label: 'Expired', value: 'expired', count: proposalStatusCounts.expired || 0 },
      { label: 'Cancelled', value: 'cancelled', count: proposalStatusCounts.cancelled || 0 },
      { label: 'Archived', value: 'archived', count: archivedCount },
    ],
    [proposalStatusCounts, archivedCount]
  );

  const canArchiveProposal = useCallback((p: { status?: string | null }) => {
    const s = (p.status || '').toLowerCase();
    return s === 'cancelled' || s === 'canceled' || s === 'accepted' || s === 'rejected' || s === 'expired' || s === 'completed' || s === 'closed';
  }, []);

  const handleSort = useCallback((field: typeof sortBy) => {
    setSortBy(field);
    setSortOrder((prev) => (sortBy === field ? (prev === 'asc' ? 'desc' : 'asc') : 'asc'));
  }, [sortBy]);

  const filteredList = useMemo(() => {
    let result =
      statusTab === 'archived' ? list.filter((p) => p.archived) : nonArchivedList;

    if (statusTab === 'all') {
      // Cancelled versions are hidden from "All": they have their own tab and
      // still show as older versions under the family chevron.
      result = result.filter((p) => p.status !== 'cancelled');
    } else if (statusTab !== 'archived') {
      result = result.filter((p) => p.status === statusTab);
    }

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
  }, [list, nonArchivedList, searchTerm, sortBy, sortOrder, statusTab]);

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
        title: 'Delete proposal',
        message: `Delete proposal ${p.proposal_no || p.id.slice(0, 8)}?`,
        variant: 'danger',
        confirmText: 'Delete',
        cancelText: 'Cancel',
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
          message: getSupabaseErrorMessage(err) || 'Could not delete.',
        });
      } finally {
        setDialogLoading(false);
      }
    },
    [showConfirm, deleteProposal, setDialogLoading, addNotification]
  );

  const handleArchive = useCallback(
    async (p: (typeof list)[0], e: React.MouseEvent) => {
      e.stopPropagation();
      if (!canArchiveProposal(p)) {
        addNotification({
          type: 'error',
          title: 'Cannot archive',
          message: 'You can only archive a proposal that is cancelled or completed.',
        });
        return;
      }
      const confirmed = await showConfirm({
        title: 'Archive proposal',
        message: `Archive ${p.proposal_no || p.id.slice(0, 8)}? It will not be deleted — only hidden from the active list.`,
        variant: 'info',
        confirmText: 'Archive',
        cancelText: 'Cancel',
      });
      if (!confirmed) return;
      try {
        setDialogLoading(true);
        const { error: err } = await supabase.from('Proposals').update({ archived: true }).eq('id', p.id);
        if (err) throw err;
        addNotification({ type: 'success', title: 'Archived', message: 'Proposal archived successfully.' });
        await refetch();
      } catch (err: any) {
        addNotification({
          type: 'error',
          title: 'Error',
          message: getSupabaseErrorMessage(err) || 'Could not archive.',
        });
      } finally {
        setDialogLoading(false);
      }
    },
    [showConfirm, setDialogLoading, refetch, addNotification, canArchiveProposal]
  );

  const handleRestore = useCallback(
    async (p: (typeof list)[0], e: React.MouseEvent) => {
      e.stopPropagation();
      const confirmed = await showConfirm({
        title: 'Restore proposal',
        message: `Restore ${p.proposal_no || p.id.slice(0, 8)}? It will return to the active list.`,
        variant: 'info',
        confirmText: 'Restore',
        cancelText: 'Cancel',
      });
      if (!confirmed) return;
      try {
        setDialogLoading(true);
        const { error: err } = await supabase.from('Proposals').update({ archived: false }).eq('id', p.id);
        if (err) throw err;
        addNotification({ type: 'success', title: 'Restored', message: 'Proposal restored successfully.' });
        await refetch();
      } catch (err: any) {
        addNotification({
          type: 'error',
          title: 'Error',
          message: getSupabaseErrorMessage(err) || 'Could not restore.',
        });
      } finally {
        setDialogLoading(false);
      }
    },
    [showConfirm, setDialogLoading, refetch, addNotification]
  );

  const renderOlderProposalRow = useCallback((o: (typeof list)[number]) => (
    <tr key={o.id} className="bg-gray-50/60 text-gray-400">
      <td className="py-3 px-3 text-center"><span className="inline-block w-4" /></td>
      <td className="py-3 px-4 text-sm font-medium text-left">
        <div className="flex items-center gap-1.5 min-w-0 pl-4">
          <span className="text-gray-300 text-xs select-none shrink-0">└</span>
          <button
            type="button"
            onClick={(e) => { e.stopPropagation(); router.navigate(withReturnTo(`/sales/proposals/${o.id}`)); }}
            className="text-gray-500 hover:text-gray-700 hover:underline whitespace-nowrap font-mono text-[13px]"
          >
            {o.proposal_no || `Proposal ${o.id.slice(0, 8)}`}
          </button>
          {proposalVersionNo(o) > 1 && (
            <span className="shrink-0 inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-semibold bg-gray-100 text-gray-500 border border-gray-200">
              v{proposalVersionNo(o)}
            </span>
          )}
        </div>
      </td>
      <td className="py-3 px-3 text-center"><span className="opacity-70"><StatusBadge status={o.status} type="proposal" size="sm" /></span></td>
      <td className="py-3 px-4 text-sm text-left text-gray-400" title={o.customer_name ?? ''}><span className="block truncate">{o.customer_name ?? '—'}</span></td>
      <td className="py-3 px-4 text-sm text-left text-gray-400"><span className="block truncate">{o.proposal_created_by ?? '—'}</span></td>
      <td className="py-3 px-4 text-sm text-left text-gray-400"><span className="block truncate">{o.quote_created_by ?? '—'}</span></td>
      <td className="py-3 px-3 text-sm text-center text-gray-400 whitespace-nowrap">{formatDate(o.updated_at)}</td>
      <td className="py-3 px-4 text-sm text-right text-gray-400 whitespace-nowrap tabular-nums">{formatCurrency(o.quote_total_amount)}</td>
      <td className="py-3 px-4 text-sm text-right text-gray-400 whitespace-nowrap tabular-nums">{formatCurrency(o.total_amount)}</td>
      <td className="py-3 px-3 text-right" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center gap-0.5 justify-end flex-nowrap">
          <button
            type="button"
            onClick={(e) => { e.stopPropagation(); router.navigate(withReturnTo(`/sales/proposals/${o.id}`)); }}
            className="p-1.5 hover:bg-gray-100 rounded text-gray-500 transition-colors"
            title="Open"
          >
            <Edit style={{ width: 14, height: 14 }} />
          </button>
          {o.archived && (
            <button
              type="button"
              onClick={(e) => handleRestore(o, e)}
              className="p-1.5 hover:bg-gray-100 rounded text-gray-500 transition-colors"
              title="Restore"
            >
              <RotateCcw style={{ width: 14, height: 14 }} />
            </button>
          )}
        </div>
      </td>
    </tr>
  ), [router, proposalVersionNo, handleRestore]);

  const [duplicatingId, setDuplicatingId] = useState<string | null>(null);
  const [duplicateTarget, setDuplicateTarget] = useState<ProposalListItem | null>(null);
  const [duplicatingLoading, setDuplicatingLoading] = useState(false);

  const openDuplicateModal = useCallback((p: ProposalListItem, e: React.MouseEvent) => {
    e.stopPropagation();
    setDuplicateTarget(p);
  }, []);

  const handleDuplicateConfirm = useCallback(
    async (mode: DuplicateProposalMode) => {
      if (!duplicateTarget) return;
      setDuplicatingLoading(true);
      setDialogLoading(true);
      setDuplicatingId(duplicateTarget.id);
      try {
        if (mode === 'version') {
          const res = await createProposalVersion(duplicateTarget.id);
          if ('error' in res) {
            addNotification({ type: 'error', title: 'Error', message: res.error });
            return;
          }
          addNotification({
            type: 'success',
            title: 'New version created',
            message: res.proposalNo
              ? `Version ${res.proposalNo} is in draft.`
              : 'Version created as draft.',
          });
          setDuplicateTarget(null);
          await refetch();
          router.navigate(withReturnTo(`/sales/proposals/${res.proposalId}`));
          return;
        }

        if (mode === 'copy') {
          const res = await duplicateProposalAsCopy(duplicateTarget.id);
          if ('error' in res) {
            addNotification({ type: 'error', title: 'Error', message: res.error });
            return;
          }
          addNotification({
            type: 'success',
            title: 'New proposal',
            message: res.proposalNo
              ? `Copy created as ${res.proposalNo}.`
              : 'Copy created with a new PR number.',
          });
          setDuplicateTarget(null);
          await refetch();
          router.navigate(withReturnTo(`/sales/proposals/${res.proposalId}`));
          return;
        }

        if (!duplicateTarget.quote_id) {
          addNotification({
            type: 'error',
            title: 'Sin Quote',
            message: 'This proposal has no linked Quote; cannot create from Quote.',
          });
          return;
        }
        const res = await createProposalFromQuote(duplicateTarget.quote_id, {
          forceNewNumber: true,
          actingDealerId: activeDealerId ?? null,
        });
        if ('error' in res) {
          addNotification({ type: 'error', title: 'Error', message: res.error });
          return;
        }
        addNotification({
          type: 'success',
          title: 'New proposal',
          message: 'Proposal created from Quote (new PR number).',
        });
        setDuplicateTarget(null);
        await refetch();
        router.navigate(withReturnTo(`/sales/proposals/${res.proposalId}`));
      } finally {
        setDuplicatingLoading(false);
        setDialogLoading(false);
        setDuplicatingId(null);
      }
    },
    [duplicateTarget, setDialogLoading, addNotification, refetch, activeDealerId]
  );

  const handleDeleteSelected = useCallback(async () => {
    const ids = Array.from(selectedIds);
    if (ids.length === 0) return;
    const confirmed = await showConfirm({
      title: 'Delete proposals',
      message: `Delete ${ids.length} selected proposal(s)?`,
      variant: 'danger',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    });
    if (!confirmed) return;
    try {
      setDialogLoading(true);
      await deleteProposals(ids);
      setSelectedIds(new Set());
      addNotification({ type: 'success', title: 'Deleted', message: `${ids.length} proposal(s) deleted.` });
    } catch (err: any) {
      addNotification({
        type: 'error',
        title: 'Error',
        message: getSupabaseErrorMessage(err) || 'Could not delete.',
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
          <h3 className="text-red-800 font-medium mb-2">Error loading proposals</h3>
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
      {/* Header: design system — title + subtitle (mb-1); actions ml-auto; same spacing as Quotes/Orders */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Proposals</h1>
        </div>
        <div className="flex items-center gap-3 ml-auto">
          {canCreateProp && allowStandalone && (
            <button
              onClick={async () => {
                if (creatingStandalone) return;
                setCreatingStandalone(true);
                try {
                  const result = await createStandaloneProposal({ actingDealerId: activeDealerId ?? null });
                  if ('error' in result) {
                    addNotification({ type: 'error', title: 'Cannot create proposal', message: result.error });
                    return;
                  }
                  router.navigate(withReturnTo(`/sales/proposals/${result.proposalId}`));
                } finally {
                  setCreatingStandalone(false);
                }
              }}
              disabled={creatingStandalone}
              className="flex items-center gap-2 px-3 py-1.5 rounded text-white text-sm transition-colors hover:opacity-90 disabled:opacity-60"
              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              title="Create a standalone proposal (no parent quote)"
            >
              <Plus className="w-4 h-4" />
              {creatingStandalone ? 'Creating…' : 'Create Proposal'}
            </button>
          )}
          {canDeleteProp && selectedIds.size > 0 && (
            <button
              onClick={handleDeleteSelected}
              className="flex items-center gap-2 px-2 py-1 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 text-sm transition-colors"
            >
              <Trash2 style={{ width: 14, height: 14 }} />
              Delete selected ({selectedIds.size})
            </button>
          )}
        </div>
      </div>

      <StatusTabs tabs={proposalStatusTabs} activeTab={statusTab} onChange={setStatusTab} />

      {/* Search and Filters — card py-6 px-6; botones px-2 py-1, icon 14px */}
      <div className="mb-4 mt-4">
        <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
          <div className="flex items-center gap-3">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search by number, customer, or quote..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
              />
            </div>
          </div>
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
        <div className="table-fit-wrapper overflow-x-auto">
          <table className="table-fit w-full min-w-[1480px]" style={{ tableLayout: 'fixed' }}>
            <colgroup>
              <col style={{ width: '44px' }} />
              <col style={{ width: '240px' }} />
              <col style={{ width: '110px' }} />
              <col style={{ width: '200px' }} />
              <col style={{ width: '160px' }} />
              <col style={{ width: '160px' }} />
              <col style={{ width: '110px' }} />
              <col style={{ width: '120px' }} />
              <col style={{ width: '120px' }} />
              <col style={{ width: '156px' }} />
            </colgroup>
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="py-3 px-3 text-center">
                  <input
                    type="checkbox"
                    checked={paginatedList.length > 0 && paginatedList.every((p) => selectedIds.has(p.id))}
                    onChange={toggleSelectAll}
                    className="rounded border-gray-300"
                  />
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs">
                  <button
                    onClick={() => handleSort('proposal_no')}
                    className="flex items-center gap-1 hover:text-gray-900"
                  >
                    Proposal / Quote
                    {sortBy === 'proposal_no' &&
                      (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-center py-3 px-3 font-medium text-gray-700 text-xs">
                  <button
                    onClick={() => handleSort('status')}
                    className="flex items-center gap-1 hover:text-gray-900 justify-center w-full"
                  >
                    Status
                    {sortBy === 'status' &&
                      (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs">
                  <button
                    onClick={() => handleSort('customer_name')}
                    className="flex items-center gap-1 hover:text-gray-900"
                  >
                    Customer
                    {sortBy === 'customer_name' &&
                      (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs">Created by</th>
                <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs">Quote created by</th>
                <th className="text-center py-3 px-3 font-medium text-gray-700 text-xs">
                  <button
                    onClick={() => handleSort('updated_at')}
                    className="flex items-center gap-1 hover:text-gray-900 justify-center w-full"
                  >
                    Updated
                    {sortBy === 'updated_at' &&
                      (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-right py-3 px-4 font-medium text-gray-700 text-xs whitespace-nowrap">Dealer Price</th>
                <th className="text-right py-3 px-4 font-medium text-gray-700 text-xs whitespace-nowrap">
                  <button
                    onClick={() => handleSort('total')}
                    className="flex items-center gap-1 hover:text-gray-900 justify-end w-full"
                  >
                    Total (USD)
                    {sortBy === 'total' &&
                      (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                  </button>
                </th>
                <th className="text-right py-3 px-3 font-medium text-gray-700 text-xs">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {paginatedList.length === 0 ? (
                <tr>
                  <td colSpan={10} className="py-12 px-4 text-center">
                    <div className="flex flex-col items-center">
                      <Search className="w-12 h-12 text-gray-300 mb-4" />
                      <p className="text-gray-600 mb-2">No proposals found</p>
                      <p className="text-sm text-gray-400">
                        {list.length === 0
                          ? 'Create a proposal from a Quote detail page'
                          : 'Try different search terms'}
                      </p>
                    </div>
                  </td>
                </tr>
              ) : (
                paginatedList.flatMap((p) => {
                  const olderRows = statusTab !== 'archived' && expandedFamilies.has(p.id)
                    ? (olderVersionsByRowId.get(p.id) ?? [])
                    : [];
                  return [
                  <tr
                    key={p.id}
                    ref={rowRefForViewport(p.id)}
                    className="hover:bg-gray-50"
                  >
                    <td className="py-3.5 px-3 text-center" onClick={(e) => e.stopPropagation()}>
                      <input
                        type="checkbox"
                        checked={selectedIds.has(p.id)}
                        onChange={() => toggleSelect(p.id)}
                        className="rounded border-gray-300"
                      />
                    </td>
                    <td className="py-3.5 px-4 text-gray-900 text-sm font-medium text-left">
                      <div className="flex items-center gap-1.5 min-w-0">
                        {statusTab !== 'archived' && olderVersionsByRowId.has(p.id) ? (
                          <button
                            type="button"
                            onClick={(e) => { e.stopPropagation(); toggleFamily(p.id); }}
                            className="p-0.5 hover:bg-gray-200 rounded text-gray-500 shrink-0"
                            title={expandedFamilies.has(p.id) ? 'Hide previous versions' : 'Show previous versions'}
                          >
                            {expandedFamilies.has(p.id) ? <ChevronDown className="w-3.5 h-3.5" /> : <ChevronRight className="w-3.5 h-3.5" />}
                          </button>
                        ) : (
                          <span className="w-4 shrink-0" aria-hidden />
                        )}
                        <div className="min-w-0">
                          <div className="flex items-center gap-1.5">
                            <span className="whitespace-nowrap font-mono text-[13px]">
                              {p.proposal_no || `Proposal ${p.id.slice(0, 8)}`}
                            </span>
                            {Number(p.version_no ?? 1) > 1 && (
                              <span className="shrink-0 inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-semibold bg-blue-50 text-blue-700 border border-blue-200">
                                v{Number(p.version_no)}
                              </span>
                            )}
                          </div>
                          {p.quote_no ? (
                            <span className="text-xs text-gray-500 font-normal block whitespace-nowrap mt-0.5">
                              Quote: {p.quote_no}
                            </span>
                          ) : (
                            <span className="text-xs text-gray-400 font-normal block mt-0.5">Standalone</span>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="py-3.5 px-3 text-center">
                      <StatusBadge status={p.status} type="proposal" size="sm" />
                    </td>
                    <td className="py-3.5 px-4 text-gray-700 text-sm text-left" title={p.customer_name ?? ''}><span className="block truncate">{p.customer_name ?? '—'}</span></td>
                    <td className="py-3.5 px-4 text-gray-600 text-sm text-left" title={p.proposal_created_by ?? ''}><span className="block truncate">{p.proposal_created_by ?? '—'}</span></td>
                    <td className="py-3.5 px-4 text-gray-600 text-sm text-left" title={p.quote_created_by ?? ''}><span className="block truncate">{p.quote_created_by ?? '—'}</span></td>
                    <td className="py-3.5 px-3 text-gray-600 text-sm text-center whitespace-nowrap">{formatDate(p.updated_at)}</td>
                    <td className="py-3.5 px-4 text-gray-700 text-sm text-right whitespace-nowrap tabular-nums">
                      {formatCurrency(p.quote_total_amount)}
                    </td>
                    <td className="py-3.5 px-4 text-gray-900 text-sm font-semibold text-right whitespace-nowrap tabular-nums">
                      {formatCurrency(p.total_amount)}
                    </td>
                    <td className="py-3.5 px-3 text-right" onClick={(e) => e.stopPropagation()}>
                      <div className="flex items-center gap-0.5 justify-end flex-nowrap">
                        {statusTab === 'archived' ? (
                          <>
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                router.navigate(withReturnTo(`/sales/proposals/${p.id}`));
                              }}
                              className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                              title="Edit"
                            >
                              <Edit style={{ width: 14, height: 14 }} />
                            </button>
                            <button
                              type="button"
                              onClick={(e) => handleRestore(p, e)}
                              className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                              title="Restore"
                            >
                              <RotateCcw style={{ width: 14, height: 14 }} />
                            </button>
                          </>
                        ) : (
                          <>
                            {p.quote_id && (
                              <button
                                type="button"
                                onClick={(e) => {
                                  e.stopPropagation();
                                  router.navigate(withReturnTo(`/sales/quotes/${p.quote_id}/edit`));
                                }}
                                className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                                title="Go to Quote"
                              >
                                <ExternalLink style={{ width: 14, height: 14 }} />
                              </button>
                            )}
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                router.navigate(withReturnTo(`/sales/proposals/${p.id}`));
                              }}
                              className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                              title="Edit"
                            >
                              <Edit style={{ width: 14, height: 14 }} />
                            </button>
                            {canCreateProp && (
                              <button
                                type="button"
                                onClick={(e) => openDuplicateModal(p, e)}
                                disabled={duplicatingId === p.id}
                                className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                                title="Duplicate proposal"
                              >
                                <Copy style={{ width: 14, height: 14 }} />
                              </button>
                            )}
                            {canArchiveProp && (
                              <button
                                type="button"
                                onClick={(e) => handleArchive(p, e)}
                                className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                                title="Archive"
                              >
                                <Archive style={{ width: 14, height: 14 }} />
                              </button>
                            )}
                            {canDeleteProp && (
                              <button
                                type="button"
                                onClick={(e) => handleDeleteOne(p, e)}
                                className="p-1.5 hover:bg-gray-100 rounded text-gray-600 transition-colors"
                                title="Delete"
                              >
                                <Trash2 style={{ width: 14, height: 14 }} />
                              </button>
                            )}
                          </>
                        )}
                      </div>
                    </td>
                  </tr>,
                  ...olderRows.map((o) => renderOlderProposalRow(o)),
                  ];
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Pagination — mt-4 = space between table container and footer */}
      <div className="mt-4 bg-white border border-gray-200 rounded-lg py-4 px-6">
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

      <DuplicateProposalModal
        isOpen={!!duplicateTarget}
        onClose={() => !duplicatingLoading && setDuplicateTarget(null)}
        onConfirm={handleDuplicateConfirm}
        sourceProposalNo={duplicateTarget?.proposal_no ?? null}
        sourceQuoteNo={duplicateTarget?.quote_no ?? null}
        hasQuote={!!duplicateTarget?.quote_id}
        isLoading={duplicatingLoading}
      />
    </div>
  );
}
