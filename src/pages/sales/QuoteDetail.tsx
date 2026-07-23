import { useState, useEffect, useMemo, useCallback, useRef } from 'react';
import { supabase, initSessionContext } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useGranularAccess } from '../../hooks/usePermissions';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import StatusBadge from '../../components/shared/StatusBadge';
import TimelineView from '../../components/shared/TimelineView';
import { router } from '../../lib/router';
import { getReturnToFromCurrentQuery, navigateBackContextual, withReturnTo } from '../../lib/navigation/returnTo';
import { formatCurrency, formatDate, formatDateTime } from '../../lib/utils';
import { createProposalFromQuote } from '../../hooks/useProposals';
import { useSOActions } from '../../hooks/useSOActions';
import { useAuth } from '../../hooks/useAuth';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { FileText, ShoppingBag, Edit, ArrowLeft, ShieldCheck, Unlock, Copy, RotateCcw } from 'lucide-react';
import { duplicateQuote } from '../../hooks/useQuotes';
import DuplicateQuoteModal, { type DuplicateQuoteMode } from '../../components/sales/DuplicateQuoteModal';
import { getAppUsersDisplayNames } from '../../lib/appUsersDisplayNames';
import QuoteAttachmentsTab from '../../components/sales/QuoteAttachmentsTab';
import DimensionsStackView from '../../components/DimensionsStackView';
import QuotePerformanceTab from '../../components/sales/QuotePerformanceTab';
import { formatDraperyStyleLabel, formatDraperyTrackDescription } from '../../lib/drapery/labels';

const SALES_SUBMODULES = [
  { id: 'quotes', label: 'Quotes', href: '/sales/quotes', icon: FileText },
  { id: 'proposals', label: 'Proposals', href: '/sales/proposals', icon: FileText },
  { id: 'orders', label: 'Orders', href: '/sales/orders', icon: ShoppingBag },
];

function formatCurrencyDisplay(amount: number | null | undefined): string {
  if (amount == null) return '---';
  return formatCurrency(amount, 'USD');
}

function normalizeLinearMeters(value: number): number {
  if (!Number.isFinite(value) || value <= 0) return 0;
  // Legacy snapshots may persist linear length in mm.
  return value > 100 ? value / 1000 : value;
}

function parseLinearLengthFromText(text: string | null | undefined): number | null {
  if (!text) return null;
  const matches = [...text.matchAll(/(\d+(?:[.,]\d+)?)\s*m\s*linear/gi)];
  if (matches.length === 0) return null;
  const raw = matches[matches.length - 1]?.[1]?.replace(',', '.');
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? n : null;
}

function getWindowFilmMeasurementMm(line: QuoteLine): { widthMm: number; lengthMm: number } | null {
  const snap = (line.config_snapshot ?? {}) as Record<string, any>;
  const widthM = Number(snap.roll_width_m ?? line.width_m ?? 0);
  const isRoll = String(snap.sell_mode ?? '').toLowerCase() === 'roll';

  let lengthM = isRoll
    ? Number(snap.roll_length_m ?? 0)
    : normalizeLinearMeters(Number(snap.linear_length_m ?? line.height_m ?? 0));

  if (!(lengthM > 0)) {
    const parsedFromName = parseLinearLengthFromText(line.name);
    if (parsedFromName) lengthM = parsedFromName;
  }

  if (!(widthM > 0) || !(lengthM > 0)) return null;
  return { widthMm: Math.round(widthM * 1000), lengthMm: Math.round(lengthM * 1000) };
}

function getQuoteIdFromPath(): string | null {
  const match = window.location.pathname.match(/\/sales\/quotes\/([^/]+)/);
  return match ? match[1] : null;
}

interface Quote {
  id: string;
  quote_no: string;
  status: string;
  customer_id: string | null;
  contact_id: string | null;
  dealer_id: string | null;
  organization_id: string;
  description: string | null;
  notes: string | null;
  priority: string | null;
  subtotal: number | null;
  tax_amount: number | null;
  total_amount: number | null;
  expires_at: string | null;
  approved_at: string | null;
  converted_at: string | null;
  created_at: string;
  created_by_user_id: string | null;
  measures_confirmed: boolean;
  measures_confirmed_at: string | null;
  measures_confirmed_by: string | null;
  parent_quote_id?: string | null;
  root_quote_id?: string | null;
  version_no?: number | null;
  is_version?: boolean | null;
}

interface QuoteLine {
  id: string;
  name: string | null;
  sku: string | null;
  product_type: string | null;
  configured_product_id?: string | null;
  custom_category?: string | null;
  width_m: number | null;
  height_m: number | null;
  quantity: number;
  unit_msrp: number | null;
  msrp: number | null;
  unit_dealer_price_snapshot?: number | null;
  dealer_price_total?: number | null;
  config_snapshot?: Record<string, any> | null;
}

interface Proposal {
  id: string;
  proposal_no: string;
  version_no: number;
  status: string;
  sent_at: string | null;
  valid_until: string | null;
  total_amount: number | null;
}

interface SalesOrder {
  id: string;
  sales_order_no: string;
  status: string | null;
  tax_amount: number | null;
  total_amount: number | null;
  expected_delivery_date: string | null;
  completed_at: string | null;
  created_at: string | null;
}

interface SalesOrderFinancialSummary {
  total_paid: number | null;
  invoice_count: number | null;
}

interface ManufacturingOrder {
  id: string;
  manufacturing_order_no: string;
  status: string;
}

interface TimelineEvent {
  id: string;
  action: string;
  description: string;
  user_name?: string | null;
  created_at: string;
  metadata?: Record<string, unknown> | null;
}

const MFG_STATUS_STEPS = [
  { id: 'draft', label: 'Draft' },
  { id: 'confirmed', label: 'Reviewed' },
  { id: 'procurement', label: 'Procurement' },
  { id: 'materials_ready', label: 'Material Ready' },
  { id: 'in_production', label: 'In Production' },
  { id: 'quality_check', label: 'Quality Check' },
  { id: 'ready_for_pickup', label: 'Ready for Pickup' },
  { id: 'delivered', label: 'Delivered' },
] as const;

function normalizeMfgStatus(status: string | null | undefined): string {
  const normalized = (status ?? '').trim().toLowerCase();
  if (normalized === 'in_progress') {
    return 'in_production';
  }
  if (normalized === 'completed') {
    return 'delivered';
  }
  return normalized;
}

export default function QuoteDetail() {
  const quoteId = getQuoteIdFromPath();
  const { activeOrganizationId, loading: orgLoading } = useOrganizationContext();
  const { user } = useAuth();
  const { isPortal, isInternal } = useAccessContext();
  // "Revert to Draft" is allowed for org users with the quotes edit permission
  // (superadmin/admin have it, plus any internal user granted the permission).
  const { canEdit: canEditQuotesPerm } = useGranularAccess('quotes');
  const addNotification = useUIStore((s) => s.addNotification);
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Sales', SALES_SUBMODULES);
  }, [registerSubmodules]);

  const [quote, setQuote] = useState<Quote | null>(null);
  const [lines, setLines] = useState<QuoteLine[]>([]);
  // Server-side totals (subtotal + tax + total) from quote_list_totals — same source
  // of truth as the Quotes list, so list and detail can never disagree.
  const [serverTotals, setServerTotals] = useState<{ subtotal: number; tax: number; total: number } | null>(null);
  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [salesOrder, setSalesOrder] = useState<SalesOrder | null>(null);
  const [salesOrderFinancial, setSalesOrderFinancial] = useState<SalesOrderFinancialSummary | null>(null);
  const [mos, setMos] = useState<ManufacturingOrder[]>([]);
  const [timeline, setTimeline] = useState<TimelineEvent[]>([]);
  const [customerName, setCustomerName] = useState<string | null>(null);
  const [contactName, setContactName] = useState<string | null>(null);
  const [createdByName, setCreatedByName] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState('overview');
  const [acting, setActing] = useState(false);
  const [refreshError, setRefreshError] = useState<string | null>(null);
  const requestIdRef = useRef(0);
  const loadedQuoteIdRef = useRef<string | null>(null);

  const { createSOFromQuote } = useSOActions();
  const [priorityOpen, setPriorityOpen] = useState(false);
  const [duplicateOpen, setDuplicateOpen] = useState(false);
  const [duplicatingLoading, setDuplicatingLoading] = useState(false);
  const [versionSiblings, setVersionSiblings] = useState<Array<{ id: string; quote_no: string; version_no: number; status: string; is_version: boolean | null }>>([]);

  const handlePriorityChange = useCallback(async (newPriority: string) => {
    if (!quote || newPriority === quote.priority) { setPriorityOpen(false); return; }
    const { error: err } = await supabase
      .from('Quotes')
      .update({ priority: newPriority })
      .eq('id', quote.id);
    setPriorityOpen(false);
    if (err) { addNotification({ type: 'error', title: 'Error', message: 'Failed to update priority' }); return; }
    setQuote((prev) => prev ? { ...prev, priority: newPriority } : prev);
  }, [quote, addNotification]);

  const refetch = useCallback(async () => {
    if (!quoteId || !activeOrganizationId) {
      setLoading(false);
      return;
    }
    const myId = ++requestIdRef.current;
    setLoading(true);
    setError(null);
    setRefreshError(null);
    try {
      await initSessionContext();
      const quoteRes = await supabase
        .from('Quotes')
        .select('id, quote_no, status, customer_id, contact_id, dealer_id, organization_id, description, notes, priority, subtotal, tax_amount, total_amount, expires_at, approved_at, converted_at, created_at, created_by_user_id, measures_confirmed, measures_confirmed_at, measures_confirmed_by, parent_quote_id, root_quote_id, version_no, is_version')
        .eq('id', quoteId)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .single();

      if (myId !== requestIdRef.current) return;

      if (quoteRes.error) throw quoteRes.error;
      if (!quoteRes.data) throw new Error('Quote not found');
      setQuote(quoteRes.data as Quote);
      loadedQuoteIdRef.current = quoteId;

      const [linesRes, proposalsRes, soRes, timelineRes, totalsRes] = await Promise.all([
        supabase
          .from('QuoteLines')
          .select('id, name, sku, product_type, configured_product_id, custom_category, width_m, height_m, quantity, unit_msrp, msrp, unit_dealer_price_snapshot, dealer_price_total, config_snapshot')
          .eq('quote_id', quoteId)
          .order('sort_order', { ascending: true })
          .order('created_at', { ascending: true }),
        supabase
          .from('Proposals')
          .select('id, proposal_no, version_no, status, sent_at, valid_until, total_amount')
          .eq('quote_id', quoteId)
          .or('deleted.is.false,deleted.is.null')
          .order('version_no', { ascending: false }),
        supabase
          .from('SalesOrders')
          .select('id, sales_order_no, status, tax_amount, total_amount, expected_delivery_date, completed_at, created_at')
          .eq('quote_id', quoteId)
          .eq('deleted', false)
          .maybeSingle(),
        supabase
          .from('ActivityTimeline')
          .select('id, action, description, user_name, created_at, metadata')
          .eq('entity_type', 'quote')
          .eq('entity_id', quoteId)
          .order('created_at', { ascending: false }),
        supabase.rpc('quote_list_totals', { p_quote_ids: [quoteId] }),
      ]);

      if (myId !== requestIdRef.current) return;

      // Totals from the shared SQL aggregate (subtotal + tax + total). Tolerate RLS
      // failures: fall back to the line-based calc below if the RPC is unavailable.
      if (!totalsRes.error && Array.isArray(totalsRes.data) && totalsRes.data.length > 0) {
        const row = totalsRes.data[0] as any;
        setServerTotals({
          subtotal: Number(row.dealer_subtotal ?? 0),
          tax: Number(row.tax_amount ?? 0),
          total: Number(row.total_amount ?? 0),
        });
      } else {
        setServerTotals(null);
        if (totalsRes.error && import.meta.env.DEV) console.warn('[QuoteDetail] quote_list_totals error:', totalsRes.error);
      }

      // Secondary fetches: tolerar fallos de RLS/dealer para que el detalle siempre muestre el quote
      if (linesRes.error) {
        if (import.meta.env.DEV) console.warn('[QuoteDetail] QuoteLines error:', linesRes.error);
      } else {
        setLines((linesRes.data ?? []) as QuoteLine[]);
      }
      if (proposalsRes.error) {
        if (import.meta.env.DEV) console.warn('[QuoteDetail] Proposals error:', proposalsRes.error);
      } else {
        setProposals((proposalsRes.data ?? []) as Proposal[]);
      }
      let salesOrderIdForCreator: string | null = null;
      if (soRes.error) {
        if (import.meta.env.DEV) console.warn('[QuoteDetail] SalesOrders error:', soRes.error);
        setSalesOrder(null);
        setSalesOrderFinancial(null);
        setMos([]);
      } else {
        const soData = soRes.data as SalesOrder | null;
        salesOrderIdForCreator = soData?.id ?? null;
        setSalesOrder(soData);
        if (soData?.id) {
          const [mosRes, soFinancialRes] = await Promise.all([
            supabase
              .from('ManufacturingOrders')
              .select('id, manufacturing_order_no, status')
              .eq('sales_order_id', soData.id)
              .eq('deleted', false)
              .order('created_at', { ascending: false }),
            supabase
              .from('sales_order_financial_summary')
              .select('total_paid, invoice_count')
              .eq('sales_order_id', soData.id)
              .maybeSingle(),
          ]);
          if (mosRes.error) {
            if (import.meta.env.DEV) console.warn('[QuoteDetail] ManufacturingOrders error:', mosRes.error);
            setMos([]);
          } else {
            setMos((mosRes.data ?? []) as ManufacturingOrder[]);
          }
          setSalesOrderFinancial((soFinancialRes.data as SalesOrderFinancialSummary | null) ?? null);
        } else {
          setSalesOrderFinancial(null);
          setMos([]);
        }
      }
      setTimeline((timelineRes.error ? [] : (timelineRes.data ?? [])) as TimelineEvent[]);

      const q = quoteRes.data as Quote;
      let creatorAuthUserId: string | null = q.created_by_user_id ?? null;
      if (q.customer_id) {
        const custRes = await supabase.from('DirectoryCustomers').select('customer_name').eq('id', q.customer_id).eq('deleted', false).maybeSingle();
        if (myId !== requestIdRef.current) return;
        setCustomerName(custRes.data?.customer_name ?? null);
      } else {
        setCustomerName(null);
      }
      if (q.contact_id) {
        const contRes = await supabase.from('DirectoryContacts').select('contact_name').eq('id', q.contact_id).eq('deleted', false).maybeSingle();
        if (myId !== requestIdRef.current) return;
        setContactName(contRes.data?.contact_name ?? null);
      } else {
        setContactName(null);
      }
      if (salesOrderIdForCreator) {
        const soCreatorRes = await supabase.from('SalesOrders').select('created_by').eq('id', salesOrderIdForCreator).maybeSingle();
        if (myId !== requestIdRef.current) return;
        if (!soCreatorRes.error && soCreatorRes.data?.created_by) {
          creatorAuthUserId = soCreatorRes.data.created_by as string;
        }
      }
      if (creatorAuthUserId) {
        const appUserMap = await getAppUsersDisplayNames([creatorAuthUserId]);
        if (myId !== requestIdRef.current) return;
        setCreatedByName(appUserMap.get(creatorAuthUserId) ?? 'Legacy / Imported');
      } else {
        setCreatedByName(null);
      }
    } catch (e: unknown) {
      if (myId !== requestIdRef.current) return;
      let msg = e instanceof Error ? e.message : 'Failed to load quote';
      const err = e as { code?: string; message?: string };
      if (err?.code === 'PGRST116' || (err?.message && String(err.message).includes('0 rows'))) {
        msg = 'Quote not found or access denied. If viewing as a specific dealer, try selecting "All dealers".';
      }
      if (loadedQuoteIdRef.current === quoteId) {
        setRefreshError(msg);
      } else {
        setError(msg);
        setQuote(null);
      }
    } finally {
      if (myId === requestIdRef.current) {
        setLoading(false);
      }
    }
  }, [quoteId, activeOrganizationId]);

  useEffect(() => {
    loadedQuoteIdRef.current = null;
    refetch();
  }, [refetch]);

  const hasActiveProposal = useMemo(() => {
    return proposals.some((p) => ['draft', 'sent'].includes((p.status || '').toLowerCase()));
  }, [proposals]);

  const handleCreateProposal = useCallback(async () => {
    if (!quoteId || acting) return;
    setActing(true);
    try {
      const result = await createProposalFromQuote(quoteId);
      if ('error' in result) {
        addNotification({ type: 'error', title: 'Error', message: result.error });
        return;
      }
      addNotification({ type: 'success', title: 'Proposal Created', message: 'Proposal created from quote.' });
      router.navigate(withReturnTo(`/sales/proposals/${result.proposalId}`));
    } finally {
      setActing(false);
    }
  }, [quoteId, acting, addNotification]);

  const handleCreateSalesOrder = useCallback(async () => {
    if (!quoteId || !user?.id || acting) return;
    setActing(true);
    try {
      const data = await createSOFromQuote(quoteId, user.id, user.name);
      if (data?.sales_order_id) {
        router.navigate(withReturnTo(`/sales/orders/${data.sales_order_id}`));
      } else {
        refetch();
      }
    } finally {
      setActing(false);
    }
  }, [quoteId, user, createSOFromQuote, refetch, acting]);

  const [showConfirmDialog, setShowConfirmDialog] = useState(false);

  const handleConfirmMeasures = useCallback(async () => {
    if (!quoteId || !user?.id || acting) return;
    setActing(true);
    try {
      const { error } = await supabase.rpc('confirm_quote_measures', {
        p_quote_id: quoteId,
        p_user_id: user.id,
      });
      if (error) throw error;
      addNotification({
        type: 'success',
        title: 'Measures Confirmed',
        message: 'Rectified measures confirmed for production. Quote is now locked.',
      });
      setShowConfirmDialog(false);
      refetch();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to confirm measures';
      addNotification({ type: 'error', title: 'Error', message: msg });
    } finally {
      setActing(false);
    }
  }, [quoteId, user, acting, addNotification, refetch]);

  const handleReopenMeasures = useCallback(async () => {
    if (!quoteId || !user?.id || acting) return;
    setActing(true);
    try {
      const { error } = await supabase.rpc('reopen_quote_measures', {
        p_quote_id: quoteId,
        p_user_id: user.id,
      });
      if (error) throw error;
      addNotification({
        type: 'success',
        title: 'Measures Reopened',
        message: 'Quote unlocked for measurement corrections.',
      });
      refetch();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to reopen measures';
      addNotification({ type: 'error', title: 'Error', message: msg });
    } finally {
      setActing(false);
    }
  }, [quoteId, user, acting, addNotification, refetch]);

  const [showRevertDialog, setShowRevertDialog] = useState(false);

  const handleRevertToDraft = useCallback(async () => {
    if (!quoteId || acting) return;
    setActing(true);
    try {
      const { data, error } = await supabase.rpc('revert_quote_to_draft', {
        p_quote_id: quoteId,
        p_user_id: user?.id ?? null,
        p_user_name: user?.name ?? null,
      });
      if (error) throw error;
      const result = data as { ok?: boolean; message?: string } | null;
      if (result && result.ok === false) {
        throw new Error(result.message || 'Cannot revert this quote to draft.');
      }
      addNotification({
        type: 'success',
        title: 'Reverted to Draft',
        message: 'The quote is back in Draft and its sales order was removed.',
      });
      setShowRevertDialog(false);
      refetch();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to revert quote to draft';
      addNotification({ type: 'error', title: 'Error', message: msg });
    } finally {
      setActing(false);
    }
  }, [quoteId, user, acting, addNotification, refetch]);

  const handleDuplicateConfirm = useCallback(async (mode: DuplicateQuoteMode, recalculate: boolean) => {
    if (!quote) return;
    setDuplicatingLoading(true);
    try {
      const newId = await duplicateQuote(quote.id, mode, recalculate);
      addNotification({
        type: 'success',
        title: mode === 'version' ? 'Versión creada' : 'Cotización duplicada',
        message: mode === 'version'
          ? 'Se creó una nueva versión vinculada al quote original.'
          : 'Se creó una cotización independiente.',
      });
      setDuplicateOpen(false);
      router.navigate(withReturnTo(`/sales/quotes/${newId}/edit`));
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to duplicate quote';
      addNotification({ type: 'error', title: 'Error duplicando', message: msg });
    } finally {
      setDuplicatingLoading(false);
    }
  }, [quote, addNotification]);

  // Load version siblings for the current family (so detail can link to other versions)
  useEffect(() => {
    if (!quote) { setVersionSiblings([]); return; }
    const rootId = quote.root_quote_id ?? quote.id;
    (async () => {
      const { data } = await supabase
        .from('Quotes')
        .select('id, quote_no, version_no, status, is_version')
        .or(`id.eq.${rootId},root_quote_id.eq.${rootId}`)
        .eq('organization_id', quote.organization_id)
        .or('deleted.is.false,deleted.is.null')
        .order('version_no', { ascending: false });
      setVersionSiblings((data ?? []) as any);
    })();
  }, [quote?.id, quote?.root_quote_id, quote?.organization_id]);

  const listPath = '/sales/quotes';
  const queryReturnTo = getReturnToFromCurrentQuery();
  const normalizePath = (path: string | null | undefined) => {
    const trimmed = (path ?? '').split('?')[0].split('#')[0].replace(/\/+$/, '');
    return trimmed || '/';
  };
  const hasRedirectBack =
    !!queryReturnTo && normalizePath(queryReturnTo) !== normalizePath(listPath);
  const onBack = () => router.navigate(listPath);
  const onBackContextual = () =>
    navigateBackContextual(router, {
      queryReturnTo,
      fallback: listPath,
    });

  const status = (quote?.status || '').toLowerCase();
  const measuresConfirmed = quote?.measures_confirmed ?? false;
  // Only made-to-measure / manufactured lines need measures confirmed. A quote that
  // holds only Service / Product / Shipping / catalog lines skips the step entirely.
  const quoteRequiresMeasures = useMemo(
    () =>
      lines.some(
        (l) =>
          (l.configured_product_id != null && (l.product_type ?? '') !== 'catalog') ||
          (l.custom_category ?? '') === 'made_to_measure',
      ),
    [lines],
  );
  const canCreateProposal =
    ['draft', 'approved'].includes(status) && !hasActiveProposal && !measuresConfirmed;
  const canConfirmMeasures =
    status === 'approved' && !measuresConfirmed && !salesOrder && quoteRequiresMeasures;
  const canReopenMeasures =
    measuresConfirmed && status !== 'converted' && !salesOrder;
  // SO can be created once measures are confirmed OR when no line needs measures.
  const canCreateSO =
    status === 'approved' && !salesOrder && (measuresConfirmed || !quoteRequiresMeasures);
  const canEditQuote = !measuresConfirmed && status !== 'converted';
  const canDuplicate = !!quote;
  // Undo a mistaken approval: internal user with quotes permission, approved quote,
  // and nothing downstream (no invoice, no payment, no MO). The RPC re-checks all.
  const hasInvoice = (salesOrderFinancial?.invoice_count ?? 0) > 0;
  const hasPayment = (salesOrderFinancial?.total_paid ?? 0) > 0;
  const hasMO = mos.length > 0;
  const canRevertToDraft =
    isInternal &&
    canEditQuotesPerm &&
    status === 'approved' &&
    !hasInvoice &&
    !hasPayment &&
    !hasMO;
  const currentMfgStepIndex = useMemo(() => {
    if (mos.length === 0) {
      return -1;
    }
    const ranked = mos
      .map((m) => MFG_STATUS_STEPS.findIndex((s) => s.id === normalizeMfgStatus(m.status)))
      .filter((idx) => idx >= 0);
    if (ranked.length === 0) {
      return -1;
    }
    return Math.min(...ranked);
  }, [mos]);

  const actionButtons = useMemo(() => {
    const btns: React.ReactNode[] = [];
    if (hasRedirectBack) {
      btns.push(
        <button
          key="back"
          type="button"
          onClick={onBackContextual}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          <ArrowLeft className="w-4 h-4" />
          Back
        </button>
      );
    }
    if (!isPortal) {
      if (canCreateProposal) {
        btns.push(
          <button
            key="create-proposal"
            type="button"
            onClick={handleCreateProposal}
            disabled={acting}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50"
          >
            Create Proposal
          </button>
        );
      }
      if (canConfirmMeasures) {
        btns.push(
          <button
            key="confirm-measures"
            type="button"
            onClick={() => setShowConfirmDialog(true)}
            disabled={acting}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-emerald-600 rounded-lg hover:bg-emerald-700 disabled:opacity-50"
          >
            <ShieldCheck className="w-4 h-4" />
            Confirm Measures
          </button>
        );
      }
      if (canReopenMeasures) {
        btns.push(
          <button
            key="reopen-measures"
            type="button"
            onClick={handleReopenMeasures}
            disabled={acting}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50"
          >
            <Unlock className="w-4 h-4" />
            Reopen Measures
          </button>
        );
      }
      if (canCreateSO) {
        btns.push(
          <button
            key="create-so"
            type="button"
            onClick={handleCreateSalesOrder}
            disabled={acting}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50"
          >
            Create Sales Order
          </button>
        );
      }
      if (canRevertToDraft) {
        btns.push(
          <button
            key="revert-draft"
            type="button"
            onClick={() => setShowRevertDialog(true)}
            disabled={acting}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-amber-700 bg-white border border-amber-300 rounded-lg hover:bg-amber-50 disabled:opacity-50"
            title="Revert this quote to Draft (only if approved by mistake and nothing is invoiced)"
          >
            <RotateCcw className="w-4 h-4" />
            Revert to Draft
          </button>
        );
      }
    }
    if (canEditQuote) {
      btns.push(
        <button
          key="edit"
          type="button"
          onClick={() => router.navigate(withReturnTo(`/sales/quotes/${quoteId}/edit`))}
          disabled={acting}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50"
          title="Edit Quote"
        >
          <Edit className="w-4 h-4" />
          Edit
        </button>
      );
    }
    if (canDuplicate) {
      btns.push(
        <button
          key="duplicate"
          type="button"
          onClick={() => setDuplicateOpen(true)}
          disabled={acting}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50"
          title="Duplicar / Nueva versión"
        >
          <Copy className="w-4 h-4" />
          Duplicar
        </button>
      );
    }
    if (btns.length === 0) return null;
    return <div className="flex items-center gap-2">{btns}</div>;
  }, [hasRedirectBack, isPortal, quoteId, canCreateProposal, canCreateSO, canConfirmMeasures, canReopenMeasures, canEditQuote, canDuplicate, canRevertToDraft, acting, handleCreateProposal, handleCreateSalesOrder, handleReopenMeasures, onBackContextual]);

  if (!quoteId) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium">Invalid URL</p>
          <p className="text-sm text-red-700">Quote ID is required.</p>
        </div>
        <button onClick={onBack} className="mt-4 px-4 py-2 text-sm text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
          Back to Quotes
        </button>
      </div>
    );
  }

  const isWaitingForOrg = !activeOrganizationId && orgLoading;
  const isFetchingQuote = loading && !quote;

  if (isWaitingForOrg || isFetchingQuote) {
    return (
      <div className="p-6 flex flex-col items-center gap-4">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
        <p className="text-sm text-gray-600">
          {isWaitingForOrg ? 'Loading organization...' : 'Loading quote...'}
        </p>
      </div>
    );
  }

  if (error || !quote) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium">Error</p>
          <p className="text-sm text-red-700">{error || 'Quote not found'}</p>
        </div>
        <button onClick={onBack} className="mt-4 px-4 py-2 text-sm text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
          Back to Quotes
        </button>
      </div>
    );
  }

  const tabs = isPortal
    ? [
        { id: 'overview', label: 'Overview' },
        { id: 'lines', label: 'Lines', count: lines.length },
        { id: 'proposals', label: 'Proposals', count: proposals.length },
        { id: 'attachments', label: 'Attachments' },
        { id: 'timeline', label: 'Timeline' },
      ]
    : [
        { id: 'overview', label: 'Overview' },
        { id: 'lines', label: 'Lines', count: lines.length },
        { id: 'proposals', label: 'Proposals', count: proposals.length },
        { id: 'performance', label: 'Performance' },
        { id: 'attachments', label: 'Attachments' },
        { id: 'timeline', label: 'Timeline' },
      ];

  // Line-based fallback (mirrors the SQL rule dealer>0 ? dealer : msrp) used only
  // if the server totals RPC is unavailable (e.g. RLS for some portal roles).
  const lineSubtotalFallback = lines.length > 0
    ? lines.reduce((s, l) => {
        const dealer = Number(l.dealer_price_total ?? 0);
        return s + (dealer > 0 ? dealer : Number(l.msrp ?? 0));
      }, 0)
    : Number(quote.subtotal ?? 0);
  // Source of truth = server totals (identical to the Quotes list). Tax is always
  // reflected (computed from CostSettings.tax_pct unless the quote is tax-exempt).
  const displaySubtotal = serverTotals ? serverTotals.subtotal : lineSubtotalFallback;
  const displayTax = serverTotals
    ? serverTotals.tax
    : Number(quote.tax_amount ?? salesOrder?.tax_amount ?? 0);
  const displayTotal = serverTotals
    ? serverTotals.total
    : (lines.length > 0
        ? displaySubtotal + displayTax
        : (quote.total_amount ?? (displaySubtotal + displayTax)));

  const hasAnyPayment = (salesOrderFinancial?.total_paid ?? 0) > 0;
  const hasSalesOrder = Boolean(salesOrder);
  const statusForDisplay =
    status === 'approved'
      ? (!hasSalesOrder ? 'approved' : hasAnyPayment ? 'released' : 'confirmed')
      : status;
  const keyStatusCaption =
    status === 'approved'
      ? (!hasSalesOrder ? 'Approved — pending order' : hasAnyPayment ? 'Released — paid' : 'Confirmed — order created')
      : status === 'cancelled' || status === 'canceled'
        ? 'Cancelled'
        : 'Draft';

  const headerStatus = <StatusBadge status={statusForDisplay} type="quote" />;
  const latestProposal = proposals.length > 0 ? proposals[0] : null;

  return (
    <DetailPageLayout
      title={quote.quote_no}
      subtitle="Quote Detail"
      status={headerStatus}
      {...({})}
      tabs={tabs}
      activeTab={activeTab}
      onTabChange={setActiveTab}
      onBack={onBack}
      actions={actionButtons}
      contentClassName="pt-2 pb-6"
    >
      {refreshError && (
        <div className="mb-4 rounded-lg border border-amber-200 bg-amber-50 p-3 flex items-center justify-between gap-3">
          <p className="text-sm text-amber-800">{refreshError}</p>
          <button
            type="button"
            onClick={() => refetch()}
            className="shrink-0 px-3 py-1.5 text-sm font-medium text-amber-800 bg-amber-100 border border-amber-300 rounded-lg hover:bg-amber-200"
          >
            Reintentar
          </button>
        </div>
      )}
      {versionSiblings.length > 1 && (
        <div className="mb-4 rounded-lg border border-blue-200 bg-blue-50 p-3">
          <p className="text-xs font-medium text-blue-900 mb-1.5">Versiones ({versionSiblings.length})</p>
          <div className="flex flex-wrap gap-2">
            {versionSiblings.map((sib) => (
              <button
                key={sib.id}
                type="button"
                onClick={() => router.navigate(withReturnTo(`/sales/quotes/${sib.id}`))}
                className={`inline-flex items-center gap-1 px-2 py-1 text-xs rounded border transition-colors ${
                  sib.id === quote.id
                    ? 'bg-blue-600 text-white border-blue-600'
                    : 'bg-white text-blue-700 border-blue-200 hover:bg-blue-100'
                }`}
              >
                {sib.quote_no}
              </button>
            ))}
          </div>
        </div>
      )}
      {measuresConfirmed && (
        <div className="mb-4 rounded-lg border border-emerald-200 bg-emerald-50 p-3 flex items-center gap-3">
          <ShieldCheck className="w-5 h-5 text-emerald-600 shrink-0" />
          <div className="flex-1">
            <p className="text-sm font-medium text-emerald-800">
              Measures confirmed for production
            </p>
            {quote.measures_confirmed_at && (
              <p className="text-xs text-emerald-600">
                Confirmed on {formatDateTime(quote.measures_confirmed_at)}
              </p>
            )}
          </div>
          {canReopenMeasures && !isPortal && (
            <button
              type="button"
              onClick={handleReopenMeasures}
              disabled={acting}
              className="shrink-0 inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-emerald-700 bg-emerald-100 border border-emerald-300 rounded-lg hover:bg-emerald-200 disabled:opacity-50"
            >
              <Unlock className="w-3.5 h-3.5" />
              Reopen
            </button>
          )}
        </div>
      )}

      {activeTab === 'overview' && (
        <div className="space-y-6">
          {/* Row 1: Quote Details + Financial Summary — same layout as Sales Order Order Details */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Quote Details</h3>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-gray-500">Customer</dt>
                  <dd className="font-medium text-gray-900">{customerName ?? '—'}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Contact</dt>
                  <dd className="text-gray-900">{contactName ?? '—'}</dd>
                </div>
                {!isPortal && (
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Created By</dt>
                    <dd className="text-gray-900">{createdByName ?? '—'}</dd>
                  </div>
                )}
                <div className="flex justify-between items-center">
                  <dt className="text-gray-500">Priority</dt>
                  <dd className="relative">
                    <button
                      type="button"
                      onClick={() => setPriorityOpen((p) => !p)}
                      className="cursor-pointer hover:ring-1 hover:ring-gray-300 rounded-full"
                    >
                      {quote.priority
                        ? <StatusBadge status={quote.priority} type="priority" size="sm" />
                        : <span className="inline-flex px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-500">Set priority</span>}
                    </button>
                    {priorityOpen && (
                      <>
                        <div className="fixed inset-0 z-30" onClick={() => setPriorityOpen(false)} />
                        <div className="absolute right-0 top-7 z-40 bg-white border border-gray-200 rounded-lg shadow-lg py-1 min-w-[100px]">
                          {(['low', 'normal', 'high', 'urgent'] as const).map((p) => (
                            <button
                              key={p}
                              type="button"
                              onClick={() => handlePriorityChange(p)}
                              className={`w-full text-left px-3 py-1.5 text-xs hover:bg-gray-50 flex items-center gap-2 ${quote.priority === p ? 'font-semibold' : ''}`}
                            >
                              <StatusBadge status={p} type="priority" size="sm" />
                            </button>
                          ))}
                        </div>
                      </>
                    )}
                  </dd>
                </div>
                {latestProposal && (
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Proposal</dt>
                    <dd>
                      <button
                        type="button"
                        onClick={() => router.navigate(withReturnTo(`/sales/proposals/${latestProposal.id}`))}
                        className="text-primary hover:underline font-medium"
                      >
                        {latestProposal.proposal_no}
                      </button>
                    </dd>
                  </div>
                )}
                {salesOrder && (
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Sales Order</dt>
                    <dd>
                      <button
                        type="button"
                        onClick={() => router.navigate(withReturnTo(`/sales/orders/${salesOrder.id}`))}
                        className="text-primary hover:underline font-medium"
                      >
                        {salesOrder.sales_order_no}
                      </button>
                    </dd>
                  </div>
                )}
              </dl>
              {(quote.description || quote.notes) && (
                <div className="mt-3 pt-3 border-t border-gray-100">
                  {quote.description && <p className="text-sm text-gray-700 whitespace-pre-wrap">{quote.description}</p>}
                  {quote.notes && (
                    <>
                      <p className="text-xs text-gray-500 font-medium mt-2">Notes</p>
                      <p className="text-sm text-gray-600 whitespace-pre-wrap">{quote.notes}</p>
                    </>
                  )}
                </div>
              )}
            </div>

            <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Financial Summary</h3>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-gray-500">Subtotal</dt>
                  <dd className="font-mono">{formatCurrencyDisplay(displaySubtotal)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Tax</dt>
                  <dd className="font-mono">{formatCurrencyDisplay(displayTax)}</dd>
                </div>
                <div className="flex justify-between border-t pt-2">
                  <dt className="text-gray-500">Total</dt>
                  <dd className="font-semibold">{formatCurrencyDisplay(displayTotal)}</dd>
                </div>
                {salesOrder && (
                  <>
                    <div className="flex justify-between border-t pt-2">
                      <dt className="text-gray-500">SO Total</dt>
                      <dd className="font-mono font-semibold">
                        {formatCurrencyDisplay(salesOrder.total_amount)}
                      </dd>
                    </div>
                  </>
                )}
              </dl>
            </div>
          </div>

          {/* Row 2: Key Date | Delivery Expected | Status | Payment Status — 4 cards, same height */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 items-stretch">
            {/* Card 1: Key Date */}
            <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm flex flex-col">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Key Date</h3>
              <dl className="space-y-2 text-sm">
                <div>
                  <dt className="text-gray-500">Created</dt>
                  <dd className="font-medium text-gray-900 mt-0.5">{formatDate(quote.created_at)}</dd>
                </div>
              </dl>
            </div>
            {/* Card 2: Delivery Expected */}
            <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm flex flex-col">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Delivery Expected</h3>
              <p className="font-medium text-gray-900 mt-0.5">
                {salesOrder?.expected_delivery_date
                  ? formatDate(salesOrder.expected_delivery_date)
                  : '—'}
              </p>
            </div>
            {/* Card 3: Status */}
            <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm flex flex-col">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Status</h3>
              <div className="mt-0.5">
                <StatusBadge status={statusForDisplay} type="quote" size="sm" />
              </div>
              <p className="text-xs text-gray-500 mt-1">{keyStatusCaption}</p>
            </div>
            {/* Card 4: Payment Status */}
            <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm flex flex-col">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Payment Status</h3>
              {salesOrder ? (
                <>
                  <div className="mt-0.5">
                    {(() => {
                      const total = salesOrder.total_amount ?? 0;
                      const paid = salesOrderFinancial?.total_paid ?? 0;
                      const paymentStatus = total <= 0 ? 'pending' : paid <= 0 ? 'pending' : paid >= total ? 'paid' : 'partial';
                      return (
                        <StatusBadge
                          status={paymentStatus}
                          type="payment"
                          size="sm"
                        />
                      );
                    })()}
                  </div>
                  <p className="text-xs text-gray-500 mt-1">
                    {(() => {
                      const total = salesOrder.total_amount ?? 0;
                      const paid = salesOrderFinancial?.total_paid ?? 0;
                      if (total <= 0) return 'No amount';
                      if (paid <= 0) return 'Unpaid';
                      if (paid >= total) return 'Completed';
                      return 'Partial';
                    })()}
                  </p>
                </>
              ) : (
                <p className="font-medium text-gray-500 mt-0.5">—</p>
              )}
            </div>
          </div>

          {/* Row 3: Manufacturing Status */}
          <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
            <h3 className="text-sm font-medium text-gray-500 mb-4">Manufacturing Status</h3>
            {mos.length === 0 ? (
              <p className="text-sm text-gray-500">No manufacturing orders yet.</p>
            ) : (
              <div className="space-y-3">
                <div className="relative px-3">
                  <div className="absolute left-3 right-3 top-2 border-t border-dashed border-gray-300" />
                  <div className="relative flex items-center justify-between">
                    {MFG_STATUS_STEPS.map((step, idx) => {
                      const isReached = currentMfgStepIndex >= 0 && idx <= currentMfgStepIndex;
                      const isCurrent = currentMfgStepIndex === idx;
                      return (
                        <div key={step.id} className="flex flex-col items-center gap-2 w-24">
                          <span
                            className={[
                              'w-4 h-4 rounded-full border-2 bg-white',
                              isReached ? 'border-primary' : 'border-gray-300',
                              isCurrent ? 'ring-2 ring-primary/20' : '',
                            ].join(' ')}
                          />
                          <span className={`text-[11px] text-center ${isCurrent ? 'text-primary font-semibold' : 'text-gray-600'}`}>
                            {step.label}
                          </span>
                        </div>
                      );
                    })}
                  </div>
                </div>
                <p className="text-xs text-gray-500">
                  Current: {currentMfgStepIndex >= 0 ? MFG_STATUS_STEPS[currentMfgStepIndex].label : 'Unknown'}
                </p>
              </div>
            )}
          </div>

          {isPortal && !salesOrder && (
            <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
              <div className="flex items-center gap-2 text-sm text-gray-500">
                <div className="h-2 w-2 rounded-full bg-amber-400" />
                <span>Your order is being processed. A sales order will be created soon.</span>
              </div>
            </div>
          )}
        </div>
      )}

      {activeTab === 'lines' && (
        <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">#</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Name / SKU</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Product Type</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Measurements</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Qty</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Unit Price</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Total</th>
              </tr>
            </thead>
            <tbody>
              {lines.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-gray-500">
                    No lines
                  </td>
                </tr>
              ) : (
                lines.map((line, idx) => {
                  const qty = Number(line.quantity) || 0;
                  const unitPrice = line.unit_dealer_price_snapshot ?? line.unit_msrp ?? (line.dealer_price_total != null && qty > 0 ? Number(line.dealer_price_total) / qty : (line.msrp != null && qty > 0 ? Number(line.msrp) / qty : null));
                  const lineTotal = line.dealer_price_total ?? line.msrp ?? (unitPrice != null ? unitPrice * qty : null);
                  const isFilmLine = (line.product_type ?? '').toLowerCase() === 'window_film';
                  const isDrapery = (line.product_type ?? '').toLowerCase() === 'drapery';
                  const isDraperyTrackOnly =
                    isDrapery && Boolean(line.config_snapshot?.track_only);
                  const draperyProductLine =
                    line.config_snapshot?.product_line ?? line.config_snapshot?.productLine ?? null;
                  const draperyStyleCode =
                    line.config_snapshot?.style_code ?? line.config_snapshot?.styleCode ?? null;
                  const draperyStyleLabel = isDrapery
                    ? formatDraperyStyleLabel({
                        productLine: draperyProductLine,
                        styleCode: draperyStyleCode,
                      })
                    : '';
                  const draperyTrackName = isDraperyTrackOnly
                    ? formatDraperyTrackDescription({
                        productLine: draperyProductLine,
                        styleCode: draperyStyleCode,
                      })
                    : null;
                  const filmMeasurement = isFilmLine ? getWindowFilmMeasurementMm(line) : null;
                  const cs = line.config_snapshot;
                  const dimSource = cs ? {
                    width_m: line.width_m,
                    height_m: line.height_m,
                    width_mm: cs.width_mm,
                    height_mm: cs.height_mm,
                    measurements: cs.measurements,
                    panels: cs.panels,
                  } : {
                    width_m: line.width_m,
                    height_m: line.height_m,
                  };
                  return (
                    <tr key={line.id} className="border-t hover:bg-gray-50">
                      <td className="px-4 py-4">{idx + 1}</td>
                      <td className="px-4 py-4">
                        <div>
                          {draperyTrackName ?? (line.name ?? '—')}
                        </div>
                        {line.sku && <div className="text-xs text-gray-500">{line.sku}</div>}
                        {isDrapery && !isDraperyTrackOnly && draperyStyleLabel && (
                          <div className="text-xs text-gray-500">
                            Style: {draperyStyleLabel}
                          </div>
                        )}
                      </td>
                      <td className="px-4 py-4">
                        {isDraperyTrackOnly ? 'Drapery Track' : (line.product_type ?? '—')}
                      </td>
                      <td className="px-4 py-4">
                        {filmMeasurement ? (
                          <span className="tabular-nums">
                            {filmMeasurement.widthMm} x {filmMeasurement.lengthMm}
                          </span>
                        ) : (
                          <DimensionsStackView source={dimSource} />
                        )}
                      </td>
                      <td className="px-4 py-4 text-right">{qty}</td>
                      <td className="px-4 py-4 text-right font-mono">{formatCurrencyDisplay(unitPrice)}</td>
                      <td className="px-4 py-4 text-right font-mono">{formatCurrencyDisplay(lineTotal)}</td>
                    </tr>
                  );
                })
              )}
            </tbody>
            {lines.length > 0 && (
              <tfoot className="bg-gray-50 border-t">
                <tr>
                  <td colSpan={6} className="px-4 py-4 text-right font-medium text-gray-700">
                    Total
                  </td>
                  <td className="px-4 py-4 text-right font-mono font-semibold">
                    {formatCurrencyDisplay(
                      lines.reduce((s, l) => s + Number(l.dealer_price_total ?? l.msrp ?? 0), 0)
                    )}
                  </td>
                </tr>
              </tfoot>
            )}
          </table>
        </div>
      )}

      {activeTab === 'proposals' && (
        <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
          {proposals.length === 0 ? (
            <div className="px-4 py-8 text-center text-gray-500">No proposals yet</div>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b">
                <tr>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Proposal #</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Version</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Status</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Sent Date</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700">Valid Until</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700">Total</th>
                </tr>
              </thead>
              <tbody>
                {proposals.map((p) => (
                  <tr
                    key={p.id}
                    className="border-t hover:bg-gray-50 cursor-pointer"
                    onClick={() => router.navigate(withReturnTo(`/sales/proposals/${p.id}`))}
                  >
                    <td className="px-4 py-4 font-medium text-primary">{p.proposal_no}</td>
                    <td className="px-4 py-4">{p.version_no}</td>
                    <td className="px-4 py-4">
                      <StatusBadge status={p.status} type="proposal" size="sm" />
                    </td>
                    <td className="px-4 py-4">{formatDate(p.sent_at)}</td>
                    <td className="px-4 py-4">{formatDate(p.valid_until)}</td>
                    <td className="px-4 py-4 text-right font-mono">{formatCurrencyDisplay(p.total_amount)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {activeTab === 'attachments' && (
        <QuoteAttachmentsTab
          quoteId={quote.id}
          organizationId={quote.organization_id}
        />
      )}

      {activeTab === 'performance' && isInternal && (
        <QuotePerformanceTab
          quoteId={quote.id}
          organizationId={quote.organization_id}
          taxAmount={displayTax}
          currency="USD"
        />
      )}

      {activeTab === 'timeline' && (
        <TimelineView events={timeline} loading={loading && timeline.length === 0} emptyMessage="No activity yet" />
      )}

      {showConfirmDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center">
          <div className="absolute inset-0 bg-black/40" onClick={() => setShowConfirmDialog(false)} />
          <div className="relative bg-white rounded-xl shadow-xl max-w-md w-full mx-4 p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="flex items-center justify-center w-10 h-10 rounded-full bg-emerald-100">
                <ShieldCheck className="w-5 h-5 text-emerald-600" />
              </div>
              <h3 className="text-lg font-semibold text-gray-900">Confirm Rectified Measures</h3>
            </div>
            <p className="text-sm text-gray-600 mb-2">
              You are confirming that this quote contains the final rectified measurements for production.
            </p>
            <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 mb-5">
              <p className="text-sm text-amber-800 font-medium">Once confirmed:</p>
              <ul className="text-sm text-amber-700 mt-1 space-y-1 list-disc list-inside">
                <li>The quote will be <strong>locked</strong> and cannot be edited</li>
                <li>You can then create a <strong>Sales Order</strong></li>
                <li>If corrections are needed, you can reopen the measures</li>
              </ul>
            </div>
            <div className="flex justify-end gap-3">
              <button
                type="button"
                onClick={() => setShowConfirmDialog(false)}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleConfirmMeasures}
                disabled={acting}
                className="px-4 py-2 text-sm font-medium text-white bg-emerald-600 rounded-lg hover:bg-emerald-700 disabled:opacity-50"
              >
                {acting ? 'Confirming...' : 'Confirm for Production'}
              </button>
            </div>
          </div>
        </div>
      )}
      {showRevertDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center">
          <div className="absolute inset-0 bg-black/40" onClick={() => setShowRevertDialog(false)} />
          <div className="relative bg-white rounded-xl shadow-xl max-w-md w-full mx-4 p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="flex items-center justify-center w-10 h-10 rounded-full bg-amber-100">
                <RotateCcw className="w-5 h-5 text-amber-600" />
              </div>
              <h3 className="text-lg font-semibold text-gray-900">Revert to Draft</h3>
            </div>
            <p className="text-sm text-gray-600 mb-2">
              Use this only if the quote was approved by mistake. It will be moved back to
              <strong> Draft</strong> so it can be edited again.
            </p>
            <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 mb-5">
              <ul className="text-sm text-amber-700 space-y-1 list-disc list-inside">
                <li>The auto-created <strong>Sales Order will be removed</strong></li>
                <li>Only allowed when there are <strong>no invoices, payments, or manufacturing orders</strong></li>
              </ul>
            </div>
            <div className="flex justify-end gap-3">
              <button
                type="button"
                onClick={() => setShowRevertDialog(false)}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleRevertToDraft}
                disabled={acting}
                className="px-4 py-2 text-sm font-medium text-white bg-amber-600 rounded-lg hover:bg-amber-700 disabled:opacity-50"
              >
                {acting ? 'Reverting...' : 'Revert to Draft'}
              </button>
            </div>
          </div>
        </div>
      )}
      <DuplicateQuoteModal
        isOpen={duplicateOpen}
        onClose={() => !duplicatingLoading && setDuplicateOpen(false)}
        onConfirm={handleDuplicateConfirm}
        sourceQuoteNo={quote.quote_no}
        disableVersion={status === 'converted'}
        versionDisabledReason={
          status === 'converted'
            ? 'Este quote ya tiene Sales Order. Solo se puede crear una copia independiente.'
            : null
        }
        isLoading={duplicatingLoading}
      />
    </DetailPageLayout>
  );
}
