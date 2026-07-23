/**
 * Proposal detail: editable header, lines (from_quote + custom), totals, PDF download.
 * Uses V2 schema: ProposalLines have override_mode, qty, fixed_line_total.
 * PDF: same header as Quote, simplified table without measurements.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { router } from '../../lib/router';
import { getReturnToFromCurrentQuery, navigateBackContextual, withReturnTo } from '../../lib/navigation/returnTo';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { getSupabaseErrorMessage, isRLSError } from '../../lib/supabase-error-utils';
import { useProposalDetail, createProposalVersion } from '../../hooks/useProposals';
import type { Proposal, ProposalLine, ProposalCustomCategory, ProposalLineAddOn, ProposalLineAddOnPricingMode } from '../../types/proposals';
import { generateProposalPDF, type ProposalPDFLine } from '../../lib/pdf/generateProposalPDF';
import { generateMeasurementFormPDF, type MeasurementFormLine } from '../../lib/pdf/generateMeasurementFormPDF';
import { formatDimensionsForProposalPDF } from '../../lib/formatDimensions';
import { formatDraperyStyleLabel, formatDraperyTrackDescription } from '../../lib/drapery/labels';
import { getLogoPathFromUrl } from '../../lib/dealerLogo';
import { useResolvedStorageUrl } from '../../hooks/useResolvedStorageUrl';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import { ChevronDown, ChevronRight, GripVertical, Plus, AlertTriangle, Printer, Eye, ArrowLeft, Download, Trash2, ExternalLink, Lock, Ruler, X, Pencil } from 'lucide-react';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import StatusBadge from '../../components/shared/StatusBadge';
import TimelineView from '../../components/shared/TimelineView';
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
} from '@dnd-kit/core';
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { Tooltip } from '../../components/ui/Tooltip';
import DocumentTermsSection from '../../components/sales/DocumentTermsSection';
import { resolveDefaultTermsTemplateId, fetchTermsTemplateById } from '../../lib/terms';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuth } from '../../hooks/useAuth';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useProductTypes } from '../../hooks/useProductTypes';
import { useDirectoryCustomers } from '../../hooks/useDirectoryCustomers';
import { getAppUsersDisplayNames } from '../../lib/appUsersDisplayNames';
import ProposalProfitabilityTab from '../../components/sales/ProposalProfitabilityTab';

const PROPOSAL_STATUS_OPTIONS: { value: Proposal['status']; label: string }[] = [
  { value: 'draft', label: 'Draft' },
  { value: 'sent', label: 'Sent' },
  { value: 'accepted', label: 'Accepted' },
  { value: 'rejected', label: 'Rejected' },
  { value: 'cancelled', label: 'Cancelled' },
];

const CUSTOM_CATEGORIES: { value: ProposalCustomCategory; label: string }[] = [
  { value: 'service', label: 'Service' },
  { value: 'product', label: 'Product' },
  { value: 'shipping', label: 'Shipping' },
  { value: 'made_to_measure', label: 'Made-to-measure' },
  { value: 'installation', label: 'Installation' },
  { value: 'delivery', label: 'Delivery' },
  { value: 'other', label: 'Other' },
];

const MADE_TO_MEASURE_CATEGORY: ProposalCustomCategory = 'made_to_measure';

/** Modal draft for Custom Item — same field layout as Quote Custom Item. */
type CustomItemModalDraft = {
  id: string;
  name: string;
  qty: string;
  unit_cost: string;
  markup_pct: string;
  unit_price: string;
  category: ProposalCustomCategory;
  area: string;
  position: string;
  width_mm: string;
  height_mm: string;
  product_type_id: string;
  drive: string;
};

function customLinePriceFromCostMarkup(cost: string, markup: string): string {
  const c = Number(cost);
  const m = Number(markup);
  if (!Number.isFinite(c) || c <= 0) return '';
  const pct = Number.isFinite(m) ? m : 0;
  return String(Math.round(c * (1 + pct / 100) * 100) / 100);
}

/** Wrapper for sortable table row - applies useSortable, passes handleProps to renderFirstCell */
function SortableRow({
  id,
  renderFirstCell,
  children,
}: {
  id: string;
  renderFirstCell: (handleProps: { attributes: Record<string, unknown>; listeners: Record<string, unknown> }) => React.ReactNode;
  children: React.ReactNode;
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id });
  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };
  return (
    <tr ref={setNodeRef} style={style} className={isDragging ? 'opacity-60 bg-gray-100' : ''}>
      {renderFirstCell({ attributes: attributes as unknown as Record<string, unknown>, listeners: (listeners ?? {}) as unknown as Record<string, unknown> })}
      {children}
    </tr>
  );
}

function formatCurrency(amount: number, currency = 'USD') {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: currency || 'USD' }).format(amount || 0);
}

/** Default "Valid until" = created_at + 30 days (YYYY-MM-DD). Used when proposal.valid_until is null. */
function defaultValidUntilFromCreatedAt(createdAt: string): string {
  const d = new Date(createdAt);
  if (Number.isNaN(d.getTime())) return '';
  d.setDate(d.getDate() + 30);
  return d.toISOString().slice(0, 10);
}

function normalizeAddressText(address: string | null | undefined): string {
  if (!address) return '';
  const seen = new Set<string>();
  const parts = address
    .split(',')
    .map((p) => p.trim())
    .filter(Boolean)
    .filter((p) => {
      const key = p.toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  return parts.join(', ');
}

function composeAddress(parts: Array<string | null | undefined>): string | null {
  const joined = parts
    .map((p) => (p ?? '').trim())
    .filter(Boolean)
    .join(', ');
  const normalized = normalizeAddressText(joined);
  return normalized || null;
}

/** Compute base amount (line total) for a quote line: unit_msrp * quantity when both exist, else msrp as line total */
function getQuoteLineBase(ql: { quantity: number; msrp: number | null; unit_msrp: number | null }): number {
  const qty = Number(ql.quantity) || 0;
  if (qty > 0 && ql.unit_msrp != null) return ql.unit_msrp * qty;
  if (ql.msrp != null && ql.msrp > 0) return ql.msrp;
  return 0;
}

/** Compute line total for a proposal line: base from QuoteLine/snapshot, apply line_adjustment_pct */
function computeLineTotal(
  line: ProposalLine,
  quoteLineInfo: { quantity: number; msrp: number | null; unit_msrp: number | null } | undefined,
  _proposalStatus?: string
): number {
  if (line.line_type === 'custom') {
    const qty = Number(line.qty) || 0;
    const up = Number(line.unit_price) || 0;
    // line_adjustment_pct carries the per-line fee/discount (incl. a cascaded Global Fee %),
    // applied on the immutable base (qty × unit_price) so it never compounds.
    const adj = Number(line.line_adjustment_pct) || 0;
    return qty * up * (1 + adj / 100);
  }
  if (line.line_type === 'from_quote') {
    let base = 0;
    if (line.quote_line_snapshot && (line.quote_line_snapshot as { base_line_msrp?: number }).base_line_msrp != null) {
      base = (line.quote_line_snapshot as { base_line_msrp: number }).base_line_msrp;
    } else if (quoteLineInfo) {
      base = getQuoteLineBase(quoteLineInfo);
    }
    const adj = Number(line.line_adjustment_pct) || 0;
    return base * (1 + adj / 100);
  }
  return 0;
}

function getProposalLineQty(
  line: ProposalLine,
  quoteLineInfo: { quantity: number; msrp: number | null; unit_msrp: number | null } | undefined
): number {
  if (line.line_type === 'custom') return Math.max(0, Number(line.qty) || 0);
  const snapshotQty = Number((line.quote_line_snapshot as { qty?: number } | null)?.qty);
  if (snapshotQty > 0) return snapshotQty;
  const quoteQty = Number(quoteLineInfo?.quantity);
  if (quoteQty > 0) return quoteQty;
  const lineQty = Number(line.qty);
  if (lineQty > 0) return lineQty;
  return 1;
}

function getDraperyTrackDescription(params: {
  productTypeName?: string | null;
  trackOnly?: boolean | null;
  productLine?: string | null;
  styleCode?: string | null;
}): string | null {
  const isDrapery = /drapery/i.test(params.productTypeName ?? '');
  if (!isDrapery || !params.trackOnly) return null;
  return formatDraperyTrackDescription({
    productLine: params.productLine,
    styleCode: params.styleCode,
  });
}

function readDraperyProductLine(
  snap: { product_line?: string; productLine?: string } | null | undefined,
  config: { product_line?: string; productLine?: string } | null | undefined
): string | null {
  return (
    snap?.product_line ??
    snap?.productLine ??
    config?.product_line ??
    config?.productLine ??
    null
  );
}

/** A config item id counts as "selected" when it is a real UUID (not empty / 'NONE'). */
function isMeaningfulConfigId(v: unknown): boolean {
  return typeof v === 'string' && v.trim().length > 10 && v.trim().toUpperCase() !== 'NONE';
}

/**
 * Detects a headbox / cassette selection from a frozen snapshot or a live config_snapshot.
 * A headbox is present when cassette = true, a real headbox_item_id exists, or a headbox_sku is set.
 */
function detectHeadbox(src: unknown): boolean {
  if (!src || typeof src !== 'object') return false;
  const o = src as Record<string, unknown>;
  if (o.cassette === true || o.cassette === 'true') return true;
  if (isMeaningfulConfigId(o.headbox_item_id)) return true;
  const sku = o.headbox_sku;
  if (typeof sku === 'string' && sku.trim().length > 0) return true;
  return false;
}

function getProposalIdFromPath(): string | null {
  const path = window.location.pathname;
  const m = path.match(/\/sales\/proposals\/([^/]+)/);
  return m ? m[1] : null;
}

interface ProposalDetailProps {
  proposalIdOverride?: string | null;
}

export default function ProposalDetail({ proposalIdOverride }: ProposalDetailProps = {}) {
  const proposalId = proposalIdOverride ?? getProposalIdFromPath();
  const { proposal, lines, addonsMap, quoteLinesMap, configuredProductsMap, quote, customer, contact, dealerLogoUrl, loading, error, refetch, setCanWrite, canWrite } =
    useProposalDetail(proposalId);

  const [expandedLineId, setExpandedLineId] = useState<string | null>(null);
  const [draftLines, setDraftLines] = useState<ProposalLine[]>([]);
  const [draftAddonsMap, setDraftAddonsMap] = useState<Map<string, ProposalLineAddOn[]>>(new Map());
  const [installationFieldDraft, setInstallationFieldDraft] = useState<Record<string, { cost?: string; markup?: string }>>({});
  const [removedCustomLineIds, setRemovedCustomLineIds] = useState<string[]>([]);
  const [linesDirty, setLinesDirty] = useState(false);
  const [addonsDirty, setAddonsDirty] = useState(false);
  /** Custom Item modal draft (Quote-style popup). Null when closed. */
  const [customModalDraft, setCustomModalDraft] = useState<CustomItemModalDraft | null>(null);
  const lastLinesRef = useRef<ProposalLine[]>([]);
  const lastAddonsMapRef = useRef<Map<string, ProposalLineAddOn[]>>(new Map());
  useEffect(() => {
    if (!proposal || loading) return;
    if (!linesDirty && !addonsDirty) {
      lastLinesRef.current = lines;
      lastAddonsMapRef.current = addonsMap;
      setDraftLines([...lines]);
      // Exclude installation addons with sale_amount <= 1 so initial state is checkbox unchecked
      setDraftAddonsMap(
        new Map(
          Array.from(addonsMap.entries()).map(([k, v]) => [
            k,
            v.filter((a) => !(a.addon_type === 'installation' && (Number(a.sale_amount) || 0) <= 1)),
          ])
        )
      );
      setInstallationFieldDraft({});
      setRemovedCustomLineIds([]);
    }
  }, [proposal, loading, lines, addonsMap, linesDirty, addonsDirty]);
  const displayLines = draftLines;
  const displayAddonsMap = draftAddonsMap;
  type AddonDraft = { cost_amount: number; markup_pct: number; sale_amount: number; pricing_mode: ProposalLineAddOnPricingMode; taxable: boolean };
  const [addonDraft, setAddonDraft] = useState<Record<string, AddonDraft>>({});
  const addonDraftRef = useRef<Record<string, AddonDraft>>({});
  addonDraftRef.current = addonDraft;

  const [saving, setSaving] = useState(false);
  const saveInFlightRef = useRef(false);
  const [headerDirty, setHeaderDirty] = useState(false);
  const [printDropdownOpen, setPrintDropdownOpen] = useState(false);
  const [activeTab, setActiveTab] = useState('overview');
  const [timeline, setTimeline] = useState<{ id: string; action: string; description: string; user_name?: string | null; created_at: string; metadata?: Record<string, unknown> | null }[]>([]);
  const printDropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!printDropdownOpen) return;
    const handleClickOutside = (e: MouseEvent) => {
      if (printDropdownRef.current && !printDropdownRef.current.contains(e.target as Node)) {
        setPrintDropdownOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [printDropdownOpen]);

  const { activeOrganizationId } = useOrganizationContext();
  const { user: authUser } = useAuth();
  const { userType, portalRole, loading: accessLoading } = useAccessContext();
  const { productTypes } = useProductTypes();
  const productTypeNameByCodeOrId = useMemo(() => {
    const byId = new Map<string, string>();
    const byCode = new Map<string, string>();
    productTypes.forEach((pt) => {
      if (pt.name) byId.set(pt.id, pt.name);
      if (pt.code) byCode.set(pt.code.trim().toLowerCase(), pt.name || pt.code);
    });
    return { byId, byCode };
  }, [productTypes]);
  const stateResolved = !loading && !!proposal && !accessLoading;

  const refetchTimeline = useCallback(() => {
    if (!proposalId) return;
    supabase
      .from('ActivityTimeline')
      .select('id, action, description, user_name, created_at, metadata')
      .eq('entity_type', 'proposal')
      .eq('entity_id', proposalId)
      .order('created_at', { ascending: false })
      .then((res: { data: unknown }) => setTimeline((res.data ?? []) as { id: string; action: string; description: string; user_name?: string | null; created_at: string; metadata?: Record<string, unknown> | null }[]));
  }, [proposalId]);

  useEffect(() => {
    refetchTimeline();
  }, [refetchTimeline]);

  // Downstream guard: an accepted proposal may have generated a Sales Order
  // (linked by proposal_id, or by the source quote_id via create_sales_order_from_quote).
  // If one exists, reverting to draft is blocked to avoid orphaning production data.
  const [hasDownstreamSO, setHasDownstreamSO] = useState(false);
  useEffect(() => {
    if (!proposalId) { setHasDownstreamSO(false); return; }
    let cancelled = false;
    (async () => {
      const orFilter = proposal?.quote_id
        ? `proposal_id.eq.${proposalId},quote_id.eq.${proposal.quote_id}`
        : `proposal_id.eq.${proposalId}`;
      const { data } = await supabase
        .from('SalesOrders')
        .select('id')
        .eq('deleted', false)
        .or(orFilter)
        .limit(1);
      if (!cancelled) setHasDownstreamSO((data ?? []).length > 0);
    })();
    return () => { cancelled = true; };
  }, [proposalId, proposal?.quote_id]);

  const [creatingVersion, setCreatingVersion] = useState(false);
  const [headerForm, setHeaderForm] = useState<{
    proposal_no: string;
    status: Proposal['status'];
    description: string;
    notes: string;
    terms_title: string;
    terms_content: string;
    valid_until: string;
    global_discount_pct: string;
    global_fee_amount: string;
    global_installation_discount_pct: string;
    global_installation_fee_pct: string;
    exempt_tax: boolean;
    /** Empty string represents "no customer". */
    customer_id: string;
    /** Empty string represents "no contact". */
    contact_id: string;
  }>({
    proposal_no: '',
    status: 'draft',
    description: '',
    notes: '',
    terms_title: '',
    terms_content: '',
    valid_until: '',
    global_discount_pct: '0',
    global_fee_amount: '0',
    global_installation_discount_pct: '0',
    global_installation_fee_pct: '0',
    exempt_tax: false,
    customer_id: '',
    contact_id: '',
  });
  // Customers for the picker (filtered by org/dealer scope, same as Quote).
  const { customers: directoryCustomers } = useDirectoryCustomers({ organizationId: activeOrganizationId });
  // Contacts filtered by selected customer (loaded on customer change).
  const [proposalContacts, setProposalContacts] = useState<{ id: string; contact_name: string }[]>([]);

  const [showAdjSubtotal, setShowAdjSubtotal] = useState(false);
  const [showAdjTotal, setShowAdjTotal] = useState(false);
  const [targetSubtotalInput, setTargetSubtotalInput] = useState('');
  const [targetTotalInput, setTargetTotalInput] = useState('');
  // Always-latest live totals, so saveHeader (defined before the `totals` useMemo) can freeze the
  // committed snapshot at send time without a TDZ/stale-closure problem.
  const totalsRef = useRef<{
    totalProduct: number;
    discountAmount: number;
    installationNet: number;
    subtotal: number;
    taxAmount: number;
    total: number;
  } | null>(null);

  const resolvedLogoUrl = useResolvedStorageUrl(dealerLogoUrl ?? null);
  const [logoError, setLogoError] = useState(false);
  const showLogo = Boolean(resolvedLogoUrl) && !logoError;
  const handleLogoError = useCallback(() => {
    if (import.meta.env.DEV) console.error('Dealer logo failed to load', resolvedLogoUrl);
    setLogoError(true);
  }, [resolvedLogoUrl]);
  useEffect(() => {
    if (!resolvedLogoUrl) setLogoError(false);
  }, [resolvedLogoUrl]);

  useEffect(() => {
    if (!proposal) return;
    setHeaderForm({
      proposal_no: proposal.proposal_no ?? '',
      status: proposal.status,
      description: proposal.description ?? '',
      notes: proposal.notes ?? '',
      terms_title: proposal.terms_title ?? '',
      terms_content: proposal.terms_content ?? '',
      valid_until: proposal.valid_until ? proposal.valid_until.slice(0, 10) : defaultValidUntilFromCreatedAt(proposal.created_at),
      global_discount_pct: proposal.global_discount_pct != null ? String(proposal.global_discount_pct) : '0',
      global_fee_amount: proposal.global_fee_amount != null ? String(proposal.global_fee_amount) : '0',
      global_installation_discount_pct: proposal.global_installation_discount_pct != null ? String(proposal.global_installation_discount_pct) : '0',
      global_installation_fee_pct: proposal.global_installation_fee_pct != null ? String(proposal.global_installation_fee_pct) : '0',
      exempt_tax: proposal.exempt_tax ?? false,
      customer_id: proposal.customer_id ?? '',
      contact_id: proposal.contact_id ?? '',
    });
  }, [proposal]);

  // Load contacts for the currently selected customer (mirrors QuoteNew pattern).
  useEffect(() => {
    const customerId = headerForm.customer_id;
    if (!customerId || !activeOrganizationId) {
      setProposalContacts([]);
      return;
    }
    let cancelled = false;
    (async () => {
      const { data, error } = await supabase
        .from('DirectoryContacts')
        .select('id, contact_name')
        .eq('customer_id', customerId)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('contact_name');
      if (cancelled) return;
      if (error) {
        setProposalContacts([]);
        return;
      }
      setProposalContacts(
        (data ?? []).map((row: { id: string; contact_name: string | null }) => ({
          id: row.id,
          contact_name: row.contact_name ?? '',
        }))
      );
    })();
    return () => { cancelled = true; };
  }, [headerForm.customer_id, activeOrganizationId]);

  // If the selected contact does not belong to the new customer, clear it.
  useEffect(() => {
    if (!headerForm.contact_id) return;
    if (proposalContacts.length === 0) return;
    const stillValid = proposalContacts.some((c) => c.id === headerForm.contact_id);
    if (!stillValid) {
      setHeaderForm((f) => ({ ...f, contact_id: '' }));
      setHeaderDirty(true);
    }
  }, [proposalContacts, headerForm.contact_id]);

  // Load Terms from default template when proposal has no terms_content
  useEffect(() => {
    if (!proposal || !activeOrganizationId || !proposal.dealer_id) return;
    const hasTerms = proposal.terms_content != null && String(proposal.terms_content).trim() !== '';
    if (hasTerms) return;
    let mounted = true;
    (async () => {
      try {
        const templateId = await resolveDefaultTermsTemplateId(activeOrganizationId, proposal.dealer_id, 'proposal');
        if (!mounted || !templateId) return;
        const template = await fetchTermsTemplateById(templateId);
        if (!mounted || !template) return;
        setHeaderForm((f) => ({
          ...f,
          terms_title: template.title ?? 'Terms and Conditions',
          terms_content: template.content ?? '',
        }));
      } catch {
        // Silently ignore; user can use Reset button later
      }
    })();
    return () => { mounted = false; };
  }, [proposal, activeOrganizationId]);

  const saveHeader = useCallback(async (): Promise<boolean> => {
    if (!proposal || !headerDirty || saving || !canWrite) return false;
    setSaving(true);
    try {
      const parsePct = (v: string) => { const n = parseFloat(v); return Number.isNaN(n) ? 0 : n; };
      const nextCustomerId = headerForm.customer_id ? headerForm.customer_id : null;
      const nextContactId = headerForm.contact_id ? headerForm.contact_id : null;
      const customerChanged = (proposal.customer_id ?? null) !== nextCustomerId;
      const contactChanged = (proposal.contact_id ?? null) !== nextContactId;
      const payload: Record<string, unknown> = {
        proposal_no: headerForm.proposal_no || null,
        status: headerForm.status,
        description: headerForm.description?.trim() || null,
        notes: headerForm.notes?.trim() || null,
        terms_title: headerForm.terms_title?.trim() || null,
        terms_content: headerForm.terms_content ?? null,
        valid_until: headerForm.valid_until || null,
        global_discount_pct: parsePct(headerForm.global_discount_pct),
        global_fee_amount: parsePct(headerForm.global_fee_amount),
        global_installation_discount_pct: parsePct(headerForm.global_installation_discount_pct),
        global_installation_fee_pct: parsePct(headerForm.global_installation_fee_pct),
        exempt_tax: headerForm.exempt_tax,
        customer_id: nextCustomerId,
        contact_id: nextContactId,
      };
      const prevStatus = proposal.status;
      const nextStatus = headerForm.status;
      const wasFrozen = prevStatus === 'sent' || prevStatus === 'accepted';
      const nowFrozen = nextStatus === 'sent' || nextStatus === 'accepted';
      const liveTotals = totalsRef.current;
      if (nowFrozen && !wasFrozen && liveTotals) {
        // Commit the totals snapshot at exactly the live value the user is sending. From here the
        // proposal is locked and every surface (detail/list/PDF) reads these frozen columns.
        payload.total_product_amount = liveTotals.totalProduct;
        payload.discount_amount = liveTotals.discountAmount;
        payload.installation_amount = liveTotals.installationNet;
        payload.subtotal_amount = liveTotals.subtotal; // taxable base
        payload.tax_amount = liveTotals.taxAmount;
        payload.total_amount = liveTotals.total;
      }
      const hasSnapshot =
        !!proposal.customer_snapshot_name ||
        !!proposal.contact_snapshot_name ||
        !!proposal.customer_snapshot_address;
      if (nowFrozen && (!wasFrozen || !hasSnapshot)) {
        // Use the form values (latest in-memory) instead of stale proposal fields.
        let customerIdToUse = nextCustomerId;
        let contactIdToUse = nextContactId;
        if ((!customerIdToUse || !contactIdToUse) && proposal.quote_id) {
          const { data: quoteRow } = await supabase
            .from('Quotes')
            .select('customer_id, contact_id')
            .eq('id', proposal.quote_id)
            .eq('deleted', false)
            .maybeSingle();
          if (quoteRow) {
            if (!customerIdToUse) customerIdToUse = (quoteRow as any).customer_id ?? null;
            if (!contactIdToUse) contactIdToUse = (quoteRow as any).contact_id ?? null;
          }
        }
        if (customerIdToUse) {
          const { data: custData } = await supabase
            .from('DirectoryCustomers')
            .select('customer_name, street_address_line_1, street_address_line_2, city, state, zip_code, country, customer_email, customer_phone, alt_phone')
            .eq('id', customerIdToUse)
            .eq('organization_id', proposal.organization_id)
            .maybeSingle();
          if (custData) {
            const c = custData as any;
            const cityStateZip = [c.city, c.state, c.zip_code]
              .map((p: string | null | undefined) => (p ?? '').trim())
              .filter(Boolean)
              .join(', ');
            payload.customer_snapshot_name = c.customer_name ?? null;
            payload.customer_snapshot_address = composeAddress([
              c.street_address_line_1,
              c.street_address_line_2,
              cityStateZip,
              c.country,
            ]);
            payload.customer_snapshot_email = c.customer_email ?? null;
            payload.customer_snapshot_phone = c.customer_phone ?? c.alt_phone ?? null;
          }
        }
        if (contactIdToUse) {
          const { data: contData } = await supabase
            .from('DirectoryContacts')
            .select('contact_name, contact_email')
            .eq('id', contactIdToUse)
            .eq('organization_id', proposal.organization_id)
            .maybeSingle();
          if (contData) {
            const ct = contData as any;
            payload.contact_snapshot_name = ct.contact_name ?? null;
            payload.contact_snapshot_email = ct.contact_email ?? null;
          }
        }
      }
      const { error: e } = await supabase.from('Proposals').update(payload).eq('id', proposal.id);
      if (e) {
        if (isRLSError(e)) {
          setCanWrite(false);
          useUIStore.getState().addNotification({ type: 'error', title: 'No permission', message: "You don't have permission to edit." });
        } else {
          useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: getSupabaseErrorMessage(e) });
        }
        return false;
      }
      // Bidirectional sync: when the proposal has a parent Quote, propagate the
      // customer/contact changes to the Quote so both sides stay aligned.
      if ((customerChanged || contactChanged) && proposal.quote_id) {
        const quotePayload: Record<string, unknown> = {};
        if (customerChanged) {
          quotePayload.customer_id = nextCustomerId;
          // If the customer changed, drop the contact on the Quote too — it may
          // belong to the previous customer.
          quotePayload.contact_id = nextContactId;
        } else if (contactChanged) {
          quotePayload.contact_id = nextContactId;
        }
        const { error: qe } = await supabase
          .from('Quotes')
          .update(quotePayload)
          .eq('id', proposal.quote_id);
        if (qe) {
          // Don't fail the whole save: log a non-blocking warning so the user
          // knows the Quote wasn't updated (RLS, soft-deleted, etc).
          useUIStore.getState().addNotification({
            type: 'warning',
            title: 'Customer not synced to Quote',
            message: getSupabaseErrorMessage(qe),
          });
        }
      }
      setHeaderDirty(false);
      return true;
    } finally {
      setSaving(false);
    }
  }, [proposal, headerForm, headerDirty, saving, canWrite, setCanWrite]);

  const setStatus = useCallback(
    (status: Proposal['status']) => {
      if (!proposal || !canWrite) return;
      setHeaderForm((f) => ({ ...f, status }));
      setHeaderDirty(true);
    },
    [proposal, canWrite]
  );

  const handleSave = useCallback(async () => {
    if (!proposal || !canWrite) return;
    if (saveInFlightRef.current) return;
    if (!headerDirty && !linesDirty && !addonsDirty && removedCustomLineIds.length === 0) {
      return;
    }
    saveInFlightRef.current = true;
    setSaving(true);
    try {
      let ok = true;
      if (headerDirty) {
        const saved = await saveHeader();
        if (!saved) ok = false;
      }
      const tempToNewId = new Map<string, string>();
      if (ok && linesDirty) {
        for (const line of draftLines) {
          if (line.id.startsWith('temp-')) {
            const hasMarkup = line.markup_pct != null && !Number.isNaN(line.markup_pct);
            const overrideMode = hasMarkup ? 'markup_pct' : 'inherit';
            const isMtm = line.custom_category === MADE_TO_MEASURE_CATEGORY;
            const insertPayload: Record<string, unknown> = {
              organization_id: proposal.organization_id,
              dealer_id: proposal.dealer_id,
              proposal_id: proposal.id,
              line_type: 'custom',
              override_mode: overrideMode,
              custom_category: line.custom_category ?? 'service',
              area: line.area?.trim() || null,
              position: line.position?.trim() || null,
              description: line.description ?? 'New line',
              qty: line.qty ?? 1,
              unit_cost: line.unit_cost ?? null,
              unit_price: line.unit_price ?? 0,
              width_m: isMtm && line.width_m != null ? line.width_m : null,
              height_m: isMtm && line.height_m != null ? line.height_m : null,
              product_type_id: isMtm ? (line.product_type_id ?? null) : null,
              drive_type: isMtm ? (line.drive_type ?? null) : null,
              sort_order: draftLines.indexOf(line),
            };
            if (overrideMode === 'markup_pct') {
              insertPayload.markup_pct = Math.max(0, Math.min(100, Number(line.markup_pct)));
            }
            const { data: inserted, error: e } = await supabase
              .from('ProposalLines')
              .insert(insertPayload)
              .select('id')
              .single();
            if (e || !inserted?.id) {
              useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: getSupabaseErrorMessage(e as any) || 'Failed to add line' });
              ok = false;
            } else tempToNewId.set(line.id, inserted.id);
          } else {
            const hasMarkup = line.markup_pct != null && !Number.isNaN(line.markup_pct);
            const overrideMode = hasMarkup ? 'markup_pct' : 'inherit';
            const isMtm = line.custom_category === MADE_TO_MEASURE_CATEGORY;
            const updatePayload: Record<string, unknown> = {
              override_mode: overrideMode,
              line_adjustment_pct: line.line_adjustment_pct,
              area: line.area?.trim() || null,
              position: line.position?.trim() || null,
              description: line.description,
              qty: line.qty,
              unit_cost: line.unit_cost ?? null,
              unit_price: line.unit_price,
              custom_category: line.custom_category,
              width_m: isMtm && line.width_m != null ? line.width_m : null,
              height_m: isMtm && line.height_m != null ? line.height_m : null,
              product_type_id: isMtm ? (line.product_type_id ?? null) : null,
              drive_type: isMtm ? (line.drive_type ?? null) : null,
              sort_order: draftLines.indexOf(line),
            };
            if (overrideMode === 'markup_pct') {
              updatePayload.markup_pct = Math.max(0, Math.min(100, Number(line.markup_pct)));
            } else {
              updatePayload.markup_pct = null;
            }
            const { error: e } = await supabase.from('ProposalLines').update(updatePayload).eq('id', line.id);
            if (e && isRLSError(e)) setCanWrite(false);
            if (e) {
              useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: getSupabaseErrorMessage(e) });
              ok = false;
            }
          }
        }
      }
      if (ok && removedCustomLineIds.length > 0) {
        const { error: addonsDeleteError } = await supabase
          .from('ProposalLineAddOns')
          .update({ deleted: true })
          .in('proposal_line_id', removedCustomLineIds)
          .eq('proposal_id', proposal.id);
        if (addonsDeleteError && isRLSError(addonsDeleteError)) setCanWrite(false);
        if (addonsDeleteError) {
          useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: getSupabaseErrorMessage(addonsDeleteError) });
          ok = false;
        }

        if (ok) {
          const { error: linesDeleteError } = await supabase
            .from('ProposalLines')
            .update({ deleted: true })
            .in('id', removedCustomLineIds)
            .eq('proposal_id', proposal.id)
            .eq('line_type', 'custom');
          if (linesDeleteError && isRLSError(linesDeleteError)) setCanWrite(false);
          if (linesDeleteError) {
            useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: getSupabaseErrorMessage(linesDeleteError) });
            ok = false;
          }
        }
      }
      if (ok && addonsDirty) {
        for (const [lineId, addons] of draftAddonsMap) {
          const resolvedLineId = tempToNewId.get(lineId) ?? lineId;
          for (const addon of addons) {
            const payload = {
              organization_id: proposal.organization_id,
              dealer_id: proposal.dealer_id,
              proposal_id: proposal.id,
              proposal_line_id: resolvedLineId,
              addon_type: addon.addon_type ?? 'installation',
              cost_amount: addon.cost_amount ?? 0,
              pricing_mode: addon.pricing_mode ?? 'markup_pct',
              markup_pct: addon.pricing_mode === 'markup_pct' ? (addon.markup_pct ?? 100) : null,
              sale_amount: addon.sale_amount ?? 0,
              taxable: addon.taxable ?? true,
              sort_order: 0,
              deleted: false,
            };
            if (addon.id && !addon.id.startsWith('temp-')) {
              const { error: e } = await supabase.from('ProposalLineAddOns').update(payload).eq('id', addon.id);
              if (e) ok = false;
            } else {
              // If adding installation and server already has one (e.g. with sale_amount <= 1), update it to avoid duplicate
              const existingInstallation =
                addon.addon_type === 'installation'
                  ? (addonsMap.get(resolvedLineId) || []).find((a) => a.addon_type === 'installation')
                  : null;
              if (existingInstallation) {
                const { error: e } = await supabase.from('ProposalLineAddOns').update(payload).eq('id', existingInstallation.id);
                if (e) ok = false;
              } else {
                const { error: e } = await supabase.from('ProposalLineAddOns').insert(payload);
                if (e) ok = false;
              }
            }
          }
        }
        const serverAddonIds = new Set<string>();
        addonsMap.forEach((arr) =>
          arr.forEach((a) => {
            // Don't delete installation addons with sale_amount <= 1 (they're hidden in UI, not removed by user)
            if (a.addon_type === 'installation' && (Number(a.sale_amount) || 0) <= 1) return;
            serverAddonIds.add(a.id);
          })
        );
        draftAddonsMap.forEach((arr) => arr.forEach((a) => { if (a.id && !a.id.startsWith('temp-')) serverAddonIds.delete(a.id); }));
        for (const id of serverAddonIds) {
          await supabase.from('ProposalLineAddOns').update({ deleted: true }).eq('id', id);
        }
      }
      if (ok) {
        setHeaderDirty(false);
        setLinesDirty(false);
        setAddonsDirty(false);
        setRemovedCustomLineIds([]);
        await refetch();
        const action = headerDirty ? 'status_changed' : 'updated';
        const description = headerDirty
          ? `Status changed to ${headerForm.status}`
          : 'Proposal updated';
        const { error: timelineErr } = await supabase.from('ActivityTimeline').insert({
          organization_id: proposal.organization_id,
          entity_type: 'proposal',
          entity_id: proposal.id,
          action,
          description,
          user_id: authUser?.id ?? null,
          user_name: authUser?.name ?? authUser?.email ?? null,
        });
        if (!timelineErr) refetchTimeline();
        else if (import.meta.env.DEV) console.warn('[ProposalDetail] ActivityTimeline insert failed', timelineErr);
        useUIStore.getState().addNotification({ type: 'success', title: 'Saved', message: 'Proposal saved.' });
      }
    } finally {
      saveInFlightRef.current = false;
      setSaving(false);
    }
  }, [proposal, canWrite, headerDirty, linesDirty, addonsDirty, removedCustomLineIds, draftLines, draftAddonsMap, addonsMap, saveHeader, refetch, setCanWrite, headerForm.status, authUser, refetchTimeline]);

  const handleSaveAndClose = useCallback(async () => {
    await handleSave();
    navigateBackContextual(router, {
      queryReturnTo: getReturnToFromCurrentQuery(),
      fallback: '/sales/proposals',
    });
  }, [handleSave]);

  const handleCreateVersion = useCallback(async () => {
    if (!proposal || creatingVersion) return;
    const confirmMsg =
      'Esto creará una NUEVA VERSIÓN a partir de esta propuesta (copia sus líneas, ajustes y add-ons) en borrador. La propuesta actual quedará archivada como histórico. ¿Continuar?';
    if (!window.confirm(confirmMsg)) return;
    setCreatingVersion(true);
    try {
      const res = await createProposalVersion(proposal.id);
      if ('error' in res) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: res.error });
        return;
      }
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Nueva versión creada',
        message: res.proposalNo ? `Versión ${res.proposalNo} en borrador.` : 'Versión creada en borrador.',
      });
      router.navigate(`/sales/proposals/${res.proposalId}`);
    } finally {
      setCreatingVersion(false);
    }
  }, [proposal, creatingVersion]);

  const listPath = '/sales/proposals';
  const queryReturnTo = getReturnToFromCurrentQuery();
  const normalizePath = (path: string | null | undefined) => {
    const trimmed = (path ?? '').split('?')[0].split('#')[0].replace(/\/+$/, '');
    return trimmed || '/';
  };
  const hasRedirectBack =
    !!queryReturnTo && normalizePath(queryReturnTo) !== normalizePath(listPath);

  const handleBack = useCallback(() => {
    router.navigate(listPath);
  }, []);

  const handleBackContextual = useCallback(() => {
    navigateBackContextual(router, {
      queryReturnTo,
      fallback: listPath,
    });
  }, [queryReturnTo]);

  const updateLineAdjustment = useCallback(
    (lineId: string, lineAdjustmentPct: number | null) => {
      if (!canWrite) return;
      const val = lineAdjustmentPct == null ? 0 : lineAdjustmentPct;
      if (val < -100 || val > 100) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: 'Line adjustment must be between -100 and 100' });
        return;
      }
      setDraftLines((prev) => prev.map((l) => (l.id === lineId ? { ...l, line_adjustment_pct: val } : l)));
      setLinesDirty(true);
    },
    [canWrite]
  );

  /**
   * Global Fee % — distributed into EVERY line by setting its line_adjustment_pct (last-writer-wins).
   * The fee is absolute (set, not added) and applied on the immutable line base, so re-applying never
   * compounds. It becomes part of each line total → taxable base → taxed, and is never shown as a
   * separate charge. Changing it re-sets all lines (a later per-line edit overrides that single line).
   */
  const applyGlobalFeePct = useCallback(
    (raw: string) => {
      if (!canWrite) return;
      const pct = raw === '' ? 0 : (parseFloat(raw) || 0);
      const clamped = Math.max(0, Math.min(100, Number.isNaN(pct) ? 0 : pct));
      setDraftLines((prev) => prev.map((l) => ({ ...l, line_adjustment_pct: clamped })));
      setLinesDirty(true);
    },
    [canWrite]
  );

  const updateCustomModalDraft = useCallback((fields: Partial<CustomItemModalDraft>) => {
    setCustomModalDraft((prev) => {
      if (!prev) return prev;
      const next = { ...prev, ...fields };
      const touchedCostOrMarkup = 'unit_cost' in fields || 'markup_pct' in fields;
      if (touchedCostOrMarkup && !('unit_price' in fields)) {
        const derived = customLinePriceFromCostMarkup(next.unit_cost, next.markup_pct);
        if (derived !== '') next.unit_price = derived;
      }
      if ('unit_price' in fields) {
        const c = Number(next.unit_cost);
        const p = Number(next.unit_price);
        if (Number.isFinite(c) && c > 0 && Number.isFinite(p)) {
          next.markup_pct = String(Math.round((p / c - 1) * 1000) / 10);
        }
      }
      return next;
    });
  }, []);

  const closeCustomModal = useCallback(() => {
    setCustomModalDraft(null);
  }, []);

  const openEditCustomModal = useCallback(
    (lineId: string) => {
      if (!canWrite) return;
      const line = displayLines.find((l) => l.id === lineId && l.line_type === 'custom');
      if (!line) return;
      const cost = Number(line.unit_cost ?? 0) || 0;
      const isMtm = line.custom_category === MADE_TO_MEASURE_CATEGORY;
      setCustomModalDraft({
        id: line.id,
        name: line.description ?? '',
        qty: String(Math.max(1, Number(line.qty) || 1)),
        unit_cost: cost > 0 ? String(cost) : '',
        markup_pct: line.markup_pct != null ? String(line.markup_pct) : '',
        unit_price: String(Number(line.unit_price) || 0),
        category: line.custom_category ?? 'service',
        area: line.area ?? '',
        position: line.position ?? '',
        width_mm: isMtm && line.width_m != null ? String(Math.round(Number(line.width_m) * 1000)) : '',
        height_mm: isMtm && line.height_m != null ? String(Math.round(Number(line.height_m) * 1000)) : '',
        product_type_id: isMtm && line.product_type_id ? String(line.product_type_id) : '',
        drive: isMtm && line.drive_type ? String(line.drive_type) : '',
      });
    },
    [canWrite, displayLines]
  );

  const addCustomLine = useCallback(() => {
    if (!proposal || !canWrite) return;
    setCustomModalDraft({
      id: `temp-${Date.now()}`,
      name: '',
      qty: '1',
      unit_cost: '',
      markup_pct: '',
      unit_price: '',
      category: 'service',
      area: '',
      position: '',
      width_mm: '',
      height_mm: '',
      product_type_id: '',
      drive: '',
    });
  }, [proposal, canWrite]);

  const commitCustomModal = useCallback(() => {
    if (!proposal || !canWrite || !customModalDraft) return;
    const d = customModalDraft;
    if (!d.name.trim()) return;
    const isMtm = d.category === MADE_TO_MEASURE_CATEGORY;
    if (isMtm && (!Number(d.width_mm) || !Number(d.height_mm))) return;

    const qty = Math.max(1, Number(d.qty) || 1);
    const unitCostRaw = d.unit_cost.trim() === '' ? null : Math.max(0, Number(d.unit_cost) || 0);
    const markupRaw = d.markup_pct.trim() === '' ? null : Number(d.markup_pct);
    const unitCost = unitCostRaw ?? 0;
    const markupPct = Number.isFinite(markupRaw as number) ? (markupRaw as number) : 0;
    const unitPrice = Math.max(
      0,
      Number(d.unit_price) || (unitCost > 0 ? unitCost * (1 + markupPct / 100) : 0)
    );
    const widthM = isMtm ? Number(d.width_mm) / 1000 : null;
    const heightM = isMtm ? Number(d.height_mm) / 1000 : null;
    const productTypeId = isMtm && d.product_type_id ? d.product_type_id : null;
    const driveType = isMtm && d.drive ? d.drive : null;

    const isNew = d.id.startsWith('temp-') && !draftLines.some((l) => l.id === d.id);

    if (isNew) {
      const newLine: ProposalLine = {
        id: d.id,
        organization_id: proposal.organization_id,
        dealer_id: proposal.dealer_id,
        proposal_id: proposal.id,
        quote_line_id: null,
        line_type: 'custom',
        override_mode: markupRaw != null && !Number.isNaN(markupRaw) ? 'markup_pct' : 'inherit',
        discount_pct: null,
        markup_pct: markupRaw != null && !Number.isNaN(markupRaw) ? markupRaw : null,
        fixed_unit_price: null,
        fixed_line_total: null,
        custom_category: d.category,
        area: d.area.trim() || null,
        position: d.position.trim() || null,
        description: d.name.trim(),
        qty,
        uom: null,
        unit_price: unitPrice,
        unit_cost: unitCostRaw,
        line_total: unitPrice * qty,
        line_adjustment_pct: null,
        width_m: widthM,
        height_m: heightM,
        product_type_id: productTypeId,
        drive_type: driveType,
        sort_order: draftLines.length,
        deleted: false,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
      setDraftLines((prev) => [...prev, newLine]);
    } else {
      setDraftLines((prev) =>
        prev.map((l) => {
          if (l.id !== d.id) return l;
          return {
            ...l,
            description: d.name.trim(),
            custom_category: d.category,
            area: d.area.trim() || null,
            position: d.position.trim() || null,
            qty,
            unit_cost: unitCostRaw,
            markup_pct: markupRaw != null && !Number.isNaN(markupRaw) ? markupRaw : null,
            unit_price: unitPrice,
            line_total: unitPrice * qty,
            override_mode: markupRaw != null && !Number.isNaN(markupRaw) ? 'markup_pct' : 'inherit',
            width_m: widthM,
            height_m: heightM,
            product_type_id: productTypeId,
            drive_type: driveType,
          };
        })
      );
    }
    setLinesDirty(true);
    setCustomModalDraft(null);
  }, [proposal, canWrite, customModalDraft, draftLines]);

  const removeCustomLine = useCallback(
    (lineId: string) => {
      if (!canWrite) return;
      const target = displayLines.find((line) => line.id === lineId);
      if (!target || target.line_type !== 'custom') return;

      if (!target.id.startsWith('temp-')) {
        setRemovedCustomLineIds((prev) => (prev.includes(target.id) ? prev : [...prev, target.id]));
      }

      setDraftLines((prev) => prev.filter((line) => line.id !== lineId));
      setDraftAddonsMap((prev) => {
        const next = new Map(prev);
        next.delete(lineId);
        return next;
      });
      if (expandedLineId === lineId) setExpandedLineId(null);
      setLinesDirty(true);
      setAddonsDirty(true);
    },
    [canWrite, displayLines, expandedLineId]
  );

  const reorderLines = useCallback(
    (newOrder: ProposalLine[]) => {
      if (!canWrite || newOrder.length === 0) return;
      setDraftLines(newOrder);
      setLinesDirty(true);
    },
    [canWrite]
  );

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates })
  );

  const handleDragEnd = useCallback(
    (event: DragEndEvent) => {
      const { active, over } = event;
      if (!over || active.id === over.id) return;
      const oldIndex = displayLines.findIndex((l) => l.id === active.id);
      const newIndex = displayLines.findIndex((l) => l.id === over.id);
      if (oldIndex === -1 || newIndex === -1) return;
      const newOrder = arrayMove(displayLines, oldIndex, newIndex);
      reorderLines(newOrder);
    },
    [displayLines, reorderLines]
  );

  const upsertAddOn = useCallback(
    (
      proposalLineId: string,
      addon: Partial<Pick<ProposalLineAddOn, 'addon_type' | 'cost_amount' | 'pricing_mode' | 'markup_pct' | 'sale_amount' | 'taxable'>>
    ) => {
      if (!proposal || !canWrite) return;
      const line = displayLines.find((l) => l.id === proposalLineId);
      if (!line) return;
      // Qty multiplier: installation is priced per curtain unit, so sale_amount = unit_cost × markup × qty.
      // fixed_price mode bypasses this (caller already provides the total).
      const lineQty = getProposalLineQty(line, line.quote_line_id ? quoteLinesMap.get(line.quote_line_id) : undefined);
      const saleAmount = addon.pricing_mode === 'fixed_price' && addon.sale_amount != null
        ? addon.sale_amount
        : (addon.cost_amount ?? 0) * (1 + ((addon.markup_pct ?? 0) / 100)) * Math.max(1, lineQty);
      const existingList = draftAddonsMap.get(proposalLineId) || [];
      const existing = existingList.find((a) => a.addon_type === (addon.addon_type || 'installation'));
      const newAddon: ProposalLineAddOn = {
        id: existing?.id ?? `temp-addon-${Date.now()}`,
        organization_id: proposal.organization_id,
        dealer_id: proposal.dealer_id,
        proposal_id: proposal.id,
        proposal_line_id: proposalLineId,
        addon_type: addon.addon_type ?? 'installation',
        cost_amount: addon.cost_amount ?? 0,
        pricing_mode: addon.pricing_mode ?? 'markup_pct',
        markup_pct: addon.pricing_mode === 'markup_pct' ? (addon.markup_pct ?? 100) : null,
        sale_amount: saleAmount,
        taxable: addon.taxable ?? true,
        sort_order: 0,
        deleted: false,
        created_at: existing?.created_at ?? new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
      if (existing) {
        setDraftAddonsMap((prev) => {
          const next = new Map(prev);
          const arr = (next.get(proposalLineId) || []).map((a) => (a.addon_type === newAddon.addon_type ? newAddon : a));
          next.set(proposalLineId, arr);
          return next;
        });
      } else {
        setDraftAddonsMap((prev) => {
          const next = new Map(prev);
          next.set(proposalLineId, [...(next.get(proposalLineId) || []), newAddon]);
          return next;
        });
      }
      setAddonsDirty(true);
    },
    [proposal, canWrite, displayLines, draftAddonsMap]
  );

  const removeAddOn = useCallback(
    (addonId: string) => {
      if (!canWrite) return;
      setDraftAddonsMap((prev) => {
        const next = new Map(prev);
        for (const [lineId, arr] of next) {
          const filtered = arr.filter((a) => a.id !== addonId);
          if (filtered.length !== arr.length) {
            next.set(lineId, filtered);
            break;
          }
        }
        return next;
      });
      setAddonsDirty(true);
    },
    [canWrite]
  );

  const totals = useMemo(() => {
    // Mirror DB recalc_proposal_totals formula exactly.
    const roundMoney = (n: number) => Math.round((n + Number.EPSILON) * 100) / 100;
    const discountPct = headerForm.global_discount_pct !== '' ? parseFloat(headerForm.global_discount_pct) || 0 : 0;
    const globalFeeAmount = headerForm.global_fee_amount !== '' ? parseFloat(headerForm.global_fee_amount) || 0 : 0;
    const instDiscountPct = headerForm.global_installation_discount_pct !== '' ? parseFloat(headerForm.global_installation_discount_pct) || 0 : 0;
    const instFeePct = headerForm.global_installation_fee_pct !== '' ? parseFloat(headerForm.global_installation_fee_pct) || 0 : 0;

    const lineTotals: number[] = [];
    let totalProduct = 0;
    let baseInstallationTotal = 0;
    let otherAddonsTotal = 0;
    displayLines.forEach((line) => {
      const qlInfo = line.quote_line_id ? quoteLinesMap.get(line.quote_line_id) : undefined;
      const rawMaterial = computeLineTotal(line, qlInfo, proposal?.status);
      lineTotals.push(rawMaterial);
      totalProduct += rawMaterial;

      const addons = displayAddonsMap?.get(line.id) || [];
      baseInstallationTotal += addons
        .filter((a) => a.addon_type === 'installation')
        .reduce((s, a) => s + (Number(a.sale_amount) || 0), 0);
      otherAddonsTotal += addons
        .filter((a) => a.addon_type !== 'installation')
        .reduce((s, a) => s + (Number(a.sale_amount) || 0), 0);
    });

    const installationTotal = baseInstallationTotal;
    const installationNet = roundMoney(installationTotal * (1 - (Number.isNaN(instDiscountPct) ? 0 : instDiscountPct) / 100) * (1 + (Number.isNaN(instFeePct) ? 0 : instFeePct) / 100));
    const laborDiscountAmount = roundMoney(Math.max(installationTotal - installationNet, 0));

    const subtotalBeforeDiscount = totalProduct + installationNet + otherAddonsTotal;
    const discountAmount = roundMoney((Number.isNaN(discountPct) ? 0 : subtotalBeforeDiscount * (discountPct / 100)));
    const taxableBase = Math.max(subtotalBeforeDiscount - discountAmount, 0);

    const exemptTax = headerForm.exempt_tax;
    const taxPct = proposal?.tax_pct ?? 0.07;
    const taxAmount = exemptTax ? 0 : roundMoney(taxableBase * taxPct);
    // Global Fee is NOT a separate charge: it is distributed into each line via line_adjustment_pct,
    // so it is already inside totalProduct → taxableBase → taxed. No post-tax lump is added.
    const total = roundMoney(taxableBase + taxAmount);

    return {
      totalProduct,
      baseTotalProduct: totalProduct,
      baseInstallationTotal,
      discountPct,
      discountAmount,
      globalFeeAmount,
      globalFeePct: 0, // kept for backward-compatible props/keys
      installationTotal,
      laborDiscountAmount,
      installationAmount: installationTotal,
      installationNet,
      otherAddonsTotal,
      subtotalBeforeDiscount,
      subtotal: taxableBase,
      taxAmount,
      total,
      lineTotals,
      instDiscountPct,
      instFeePct,
    };
  }, [displayLines, quoteLinesMap, displayAddonsMap, proposal?.status, proposal?.tax_pct, headerForm.global_discount_pct, headerForm.global_fee_amount, headerForm.global_installation_discount_pct, headerForm.global_installation_fee_pct, headerForm.exempt_tax]);

  // Keep the ref in sync so saveHeader can read the latest live totals when freezing on send.
  totalsRef.current = {
    totalProduct: totals.totalProduct,
    discountAmount: totals.discountAmount,
    installationNet: totals.installationNet,
    subtotal: totals.subtotal,
    taxAmount: totals.taxAmount,
    total: totals.total,
  };

  /**
   * Displayed Summary (hybrid model):
   *  - DRAFT (editable): live `totals`, so the Summary updates as you edit — exactly like before.
   *  - SENT / ACCEPTED (committed): the FROZEN snapshot (Proposals.* columns), captured at send time,
   *    so a closed proposal never drifts. Falls back to live only if the snapshot was never written.
   * The quote-derived base is already frozen in quote_line_snapshot, so even the live draft total is
   * immune to later Quote edits.
   */
  const summary = useMemo(() => {
    const locked = proposal?.status === 'sent' || proposal?.status === 'accepted';
    if (!locked || proposal?.total_amount == null) {
      return {
        totalProduct: totals.totalProduct,
        discountPct: totals.discountPct,
        discountAmount: totals.discountAmount,
        installationTotal: totals.installationTotal,
        installationNet: totals.installationNet,
        installationAmount: totals.installationAmount,
        laborDiscountAmount: totals.laborDiscountAmount,
        instDiscountPct: totals.instDiscountPct,
        otherAddonsTotal: totals.otherAddonsTotal,
        globalFeeAmount: totals.globalFeeAmount,
        subtotal: totals.subtotal,
        taxAmount: totals.taxAmount,
        total: totals.total,
        fromSnapshot: false,
      };
    }
    const net = Number(proposal?.installation_amount ?? 0);
    return {
      totalProduct: Number(proposal?.total_product_amount ?? totals.totalProduct),
      discountPct: Number(proposal?.global_discount_pct ?? 0),
      discountAmount: Number(proposal?.discount_amount ?? 0),
      installationTotal: net,
      installationNet: net,
      installationAmount: net,
      laborDiscountAmount: 0,
      instDiscountPct: Number(proposal?.global_installation_discount_pct ?? 0),
      otherAddonsTotal: 0,
      globalFeeAmount: Number(proposal?.global_fee_amount ?? 0),
      subtotal: Number(proposal?.subtotal_amount ?? 0),
      taxAmount: Number(proposal?.tax_amount ?? 0),
      total: Number(proposal?.total_amount ?? 0),
      fromSnapshot: true,
    };
  }, [proposal, totals]);

  /**
   * Resolve desired taxable base (subtotal after global discount) into Global Discount %.
   * Mirrors the live `totals` formula where discount is applied to subtotal_before_discount.
   */
  const setHeaderFromTargetProductNet = useCallback(
    (targetAfterDiscount: number) => {
      const base = totals.subtotalBeforeDiscount ?? 0;
      if (base <= 0) return;
      let nextDiscount = 0;
      if (targetAfterDiscount <= 0) {
        nextDiscount = 100;
      } else if (targetAfterDiscount < base) {
        nextDiscount = Math.round(((base - targetAfterDiscount) / base) * 1000000) / 10000;
      }
      setHeaderForm((f) => ({
        ...f,
        global_discount_pct: String(Math.max(0, Math.min(100, nextDiscount))),
      }));
      setHeaderDirty(true);
    },
    [totals.subtotalBeforeDiscount]
  );

  /** Target subtotal (sin tax) == taxable base after global discount. */
  const applyTargetSubtotal = useCallback(
    (raw: string) => {
      const target = parseFloat(raw);
      if (Number.isNaN(target) || target < 0) return;
      setHeaderFromTargetProductNet(target);
    },
    [setHeaderFromTargetProductNet]
  );

  /** Target total (con o sin ITBMS) -> derive taxable base using the live equation. */
  const applyTargetTotal = useCallback(
    (raw: string) => {
      const targetTotal = parseFloat(raw);
      if (Number.isNaN(targetTotal) || targetTotal < 0) return;
      // Global Fee is no longer a post-tax lump; it lives inside the line totals (line_adjustment_pct).
      const exemptTax = headerForm.exempt_tax;
      const taxPct = exemptTax ? 0 : (proposal?.tax_pct ?? 0.07);
      const targetSub = targetTotal / (1 + taxPct);
      setHeaderFromTargetProductNet(targetSub);
    },
    [headerForm.exempt_tax, proposal?.tax_pct, setHeaderFromTargetProductNet]
  );

  const customLinesInvalid = useMemo(() => {
    return displayLines.some(
      (l) =>
        l.line_type === 'custom' &&
        (!(l.description?.trim()) || l.qty == null || l.unit_price == null || Number(l.qty) <= 0)
    );
  }, [displayLines]);

  const hasFromQuoteLines = displayLines.some((l) => l.line_type === 'from_quote');
  const totalZeroWithFromQuote = hasFromQuoteLines && totals.total === 0;
  const currency = proposal?.currency || 'USD';

  /** Format accessories for PDF (tolerant of array/object) */
  const formatAccessoriesForPDF = useCallback((acc: unknown): string => {
    if (acc == null) return '—';
    if (Array.isArray(acc)) {
      const parts = acc.map((item) =>
        typeof item === 'string' ? item : item && typeof item === 'object' && 'name' in item ? `${(item as { name?: string }).name ?? ''} (${(item as { qty?: number }).qty ?? 1})` : String(item)
      );
      return parts.filter(Boolean).join(', ') || '—';
    }
    if (typeof acc === 'object') {
      const entries = Object.entries(acc).filter(([, v]) => v != null && v !== '');
      return entries.length > 0 ? entries.map(([k, v]) => `${k}: ${v}`).join(', ') : '—';
    }
    return String(acc) || '—';
  }, []);

  const buildProposalPDFDoc = useCallback(
    async (variant: 'internal' | 'customer') => {
      if (!proposal || !proposalId) return null;
      const { data: orgData } = await supabase
        .from('Organizations')
        .select('name')
        .eq('id', proposal.organization_id)
        .maybeSingle();
      const organizationName = (orgData as { name?: string } | null)?.name ?? 'Arquiproductos';

      let logoPngBase64: string | undefined;
      let logoWidthPx: number | undefined;
      let logoHeightPx: number | undefined;
      // Resolve logo: use state first; if empty, fetch dealer logo_url so PDF has it even before UI state updates
      let logoUrlForPdf = dealerLogoUrl;
      if (!logoUrlForPdf && proposal?.dealer_id) {
        const { data: dealerData } = await supabase
          .from('Dealers')
          .select('logo_url')
          .eq('id', proposal.dealer_id)
          .maybeSingle();
        logoUrlForPdf = (dealerData as { logo_url?: string } | null)?.logo_url ?? null;
      }
      const logoPath = getLogoPathFromUrl(logoUrlForPdf);
      const cleanPath = logoPath ? logoPath.replace(/^\/+/, '') : null;
      const logoUrlToLoad =
        cleanPath
          ? supabase.storage.from('catalog-images').getPublicUrl(cleanPath).data.publicUrl
          : /^https?:\/\//i.test(logoUrlForPdf ?? '')
            ? logoUrlForPdf!
            : null;

      if (logoUrlToLoad) {
        try {
          let dataUrl: string | null = null;
          const res = await fetch(logoUrlToLoad, { mode: 'cors', credentials: 'omit' });
          if (res.ok) {
            const blob = await res.blob();
            if (blob.type.startsWith('image/')) {
              dataUrl = await new Promise<string>((resolve, reject) => {
                const reader = new FileReader();
                reader.onloadend = () => resolve(reader.result as string);
                reader.onerror = reject;
                reader.readAsDataURL(blob);
              });
            }
          }
          if (import.meta.env.DEV && !res.ok) {
            console.warn('Proposal PDF: logo fetch failed', { status: res.status, statusText: res.statusText, url: logoUrlToLoad });
          }
          if (!dataUrl) {
            const fromImage = await new Promise<string | null>((resolve) => {
              const img = new Image();
              img.crossOrigin = 'anonymous';
              img.onload = () => {
                try {
                  const c = document.createElement('canvas');
                  c.width = img.naturalWidth;
                  c.height = img.naturalHeight;
                  const ctx = c.getContext('2d');
                  if (ctx) {
                    ctx.drawImage(img, 0, 0);
                    resolve(c.toDataURL('image/png'));
                  } else resolve(null);
                } catch {
                  resolve(null);
                }
              };
              img.onerror = () => resolve(null);
              img.src = logoUrlToLoad;
            });
            if (fromImage) dataUrl = fromImage;
          }
          if (dataUrl) {
            logoPngBase64 = dataUrl;
            const dims = await new Promise<{ w: number; h: number } | null>((resolve) => {
              const img2 = new Image();
              img2.onload = () => resolve({ w: img2.naturalWidth, h: img2.naturalHeight });
              img2.onerror = () => resolve(null);
              img2.src = dataUrl!;
            });
            if (dims) {
              logoWidthPx = dims.w;
              logoHeightPx = dims.h;
            }
          }
        } catch (e) {
          if (import.meta.env.DEV) {
            console.warn('Proposal PDF: logo failed to load', { url: logoUrlToLoad, error: e });
          }
        }
      }

      const pdfLines: ProposalPDFLine[] = displayLines.map((line, index) => {
        const lineTotal = totals.lineTotals[index] ?? 0;
        const installationAddon = (displayAddonsMap?.get(line.id) || []).find((a) => a.addon_type === 'installation');
        const isInstallIncluded = Number(installationAddon?.cost_amount ?? 0) > 0;
        if (line.line_type === 'custom') {
          const qty = Number(line.qty) || 0;
          const up = Number(line.unit_price) || 0;
          return {
            area: line.area ?? null,
            position: line.position ?? null,
            description: (line.description || '—') + (line.custom_category ? ` (${line.custom_category})` : ''),
            qty,
            unit_price: up,
            line_total: lineTotal,
          };
        }
        const snapFrozen = line.quote_line_snapshot;
        const qlInfo = line.quote_line_id ? quoteLinesMap.get(line.quote_line_id) : undefined;
        const snap =
          snapFrozen
            ? { measurements: snapFrozen.measurements, accessories: snapFrozen.accessories }
            : qlInfo?.config_snapshot ??
              (qlInfo?.configured_product_id ? (configuredProductsMap ?? {})[qlInfo.configured_product_id]?.config_snapshot : undefined);
        const dimensionsSource =
          snapFrozen && (snapFrozen.width_m != null || snapFrozen.height_m != null || (typeof snapFrozen.measurements === 'object' && snapFrozen.measurements))
            ? {
                measurements: (typeof snapFrozen.measurements === 'object' && snapFrozen.measurements) ? snapFrozen.measurements : undefined,
                panels: Array.isArray((snapFrozen as { panels?: unknown[] }).panels) ? (snapFrozen as { panels?: unknown[] }).panels : undefined,
                width_m: snapFrozen.width_m,
                height_m: snapFrozen.height_m,
              }
            : snap
              ? {
                  measurements: (typeof (snap as { measurements?: unknown }).measurements === 'object' && (snap as { measurements?: unknown }).measurements)
                    ? (snap as { measurements?: { panels?: unknown[]; height_mm?: number } }).measurements
                    : undefined,
                  panels: Array.isArray((snap as { panels?: unknown[] }).panels) ? (snap as { panels?: unknown[] }).panels : undefined,
                  width_m: qlInfo?.width_m ?? null,
                  height_m: qlInfo?.height_m ?? null,
                }
              : qlInfo
                ? { width_m: qlInfo.width_m, height_m: qlInfo.height_m }
                : null;
        const dimensionsFormatted =
          dimensionsSource
            ? formatDimensionsForProposalPDF(dimensionsSource as Parameters<typeof formatDimensionsForProposalPDF>[0]).trim()
            : null;
        const dimensions = dimensionsFormatted && dimensionsFormatted !== '—' ? dimensionsFormatted : null;
        const meas = (snapFrozen as { measurements?: { panel_count?: number; panels?: unknown[] } } | null)?.measurements ?? (snap as { measurements?: { panel_count?: number; panels?: unknown[] }; panels?: unknown[] } | undefined)?.measurements;
        const panelsArray = (snap as { panels?: unknown[] } | undefined)?.panels ?? meas?.panels;
        const panel_count =
          (typeof meas?.panel_count === 'number' && meas.panel_count >= 1 ? meas.panel_count : null) ??
          (Array.isArray(panelsArray) && panelsArray.length >= 1 ? panelsArray.length : null) ??
          1;
        const qty = snapFrozen?.qty ?? qlInfo?.quantity ?? 1;
        const unitPrice = qty > 0 ? lineTotal / qty : 0;
        const productTypeRaw = snapFrozen?.product_type ?? qlInfo?.product_type ?? null;
        const productTypeName =
          (qlInfo?.product_type_id && productTypeNameByCodeOrId.byId.get(qlInfo.product_type_id)) ??
          (productTypeRaw && productTypeNameByCodeOrId.byCode.get(productTypeRaw.trim().toLowerCase())) ??
          productTypeRaw;
        const styleCode =
          (snapFrozen as { style_code?: string; styleCode?: string } | null)?.style_code ??
          (snapFrozen as { style_code?: string; styleCode?: string } | null)?.styleCode ??
          (qlInfo?.config_snapshot as { style_code?: string; styleCode?: string } | null)?.style_code ??
          (qlInfo?.config_snapshot as { style_code?: string; styleCode?: string } | null)?.styleCode ??
          null;
        const productLine = readDraperyProductLine(
          snapFrozen as { product_line?: string; productLine?: string } | null,
          qlInfo?.config_snapshot as { product_line?: string; productLine?: string } | null
        );
        const trackOnly =
          Boolean((snapFrozen as { track_only?: boolean } | null)?.track_only) ||
          Boolean((qlInfo?.config_snapshot as { track_only?: boolean } | null)?.track_only);
        const hasSideChannel =
          Boolean((snapFrozen as { side_channel?: boolean } | null)?.side_channel) ||
          (typeof (snapFrozen as { side_channel_item_id?: string } | null)?.side_channel_item_id === 'string'
            && String((snapFrozen as { side_channel_item_id?: string }).side_channel_item_id).trim().length > 10
            && String((snapFrozen as { side_channel_item_id?: string }).side_channel_item_id).toUpperCase() !== 'NONE') ||
          Boolean((qlInfo?.config_snapshot as { side_channel?: boolean } | null)?.side_channel) ||
          (typeof (qlInfo?.config_snapshot as { side_channel_item_id?: string } | null)?.side_channel_item_id === 'string'
            && String((qlInfo?.config_snapshot as { side_channel_item_id?: string }).side_channel_item_id).trim().length > 10
            && String((qlInfo?.config_snapshot as { side_channel_item_id?: string }).side_channel_item_id).toUpperCase() !== 'NONE');
        const hasBottomChannel =
          Boolean((snapFrozen as { bottom_channel?: boolean } | null)?.bottom_channel) ||
          (typeof (snapFrozen as { bottom_channel_item_id?: string } | null)?.bottom_channel_item_id === 'string'
            && String((snapFrozen as { bottom_channel_item_id?: string }).bottom_channel_item_id).trim().length > 10
            && String((snapFrozen as { bottom_channel_item_id?: string }).bottom_channel_item_id).toUpperCase() !== 'NONE') ||
          Boolean((qlInfo?.config_snapshot as { bottom_channel?: boolean } | null)?.bottom_channel) ||
          (typeof (qlInfo?.config_snapshot as { bottom_channel_item_id?: string } | null)?.bottom_channel_item_id === 'string'
            && String((qlInfo?.config_snapshot as { bottom_channel_item_id?: string }).bottom_channel_item_id).trim().length > 10
            && String((qlInfo?.config_snapshot as { bottom_channel_item_id?: string }).bottom_channel_item_id).toUpperCase() !== 'NONE');
        const draperyTrackDescription = getDraperyTrackDescription({
          productTypeName: productTypeName ?? null,
          trackOnly,
          productLine,
          styleCode,
        });
        const isDraperyLine = /drapery/i.test(String(productTypeName ?? productTypeRaw ?? ''));
        // Fold style for full drapery curtains (track-only already carries it in the name).
        const draperyStyleLabel =
          isDraperyLine && !draperyTrackDescription
            ? formatDraperyStyleLabel({ productLine, styleCode }) || null
            : null;
        const hasHeadbox = detectHeadbox(snapFrozen) || detectHeadbox(qlInfo?.config_snapshot);
        const isCatalogLine = String(productTypeRaw ?? '').trim().toLowerCase() === 'catalog';
        const isServiceLine = String(productTypeRaw ?? '').trim().toLowerCase() === 'service';
        const catalogColor = isCatalogLine ? (qlInfo?.catalog_color ?? null) : null;
        const baseName = snapFrozen?.name ?? snapFrozen?.sku ?? qlInfo?.name ?? qlInfo?.sku ?? null;
        const catalogDescription = isCatalogLine && baseName
          ? (catalogColor ? `${baseName} — ${catalogColor}` : baseName)
          : null;
        return {
          area: snapFrozen?.area ?? qlInfo?.area ?? null,
          position: snapFrozen?.position ?? qlInfo?.position ?? null,
          product_type: productTypeName ?? null,
          collection_name: isServiceLine ? null : (snapFrozen?.collection_name ?? qlInfo?.collection_name ?? null),
          variant_name: isServiceLine ? null : (snapFrozen?.variant_name ?? qlInfo?.variant_name ?? null),
          drive_type: isServiceLine ? null : (snapFrozen?.drive_type ?? qlInfo?.drive_type ?? null),
          drive_system_label: isServiceLine ? null : (snapFrozen?.drive_system_label ?? qlInfo?.drive_system_label ?? null),
          description: catalogDescription ?? draperyTrackDescription ?? baseName,
          sku: isServiceLine ? null : (snapFrozen?.sku ?? qlInfo?.sku ?? null),
          dimensions: isServiceLine ? null : (dimensions ?? null),
          panel_count: isServiceLine ? null : panel_count,
          opening_direction:
            (snapFrozen as { opening_direction?: string } | null)?.opening_direction ??
            (qlInfo?.config_snapshot as { opening_direction?: string; openingDirection?: string } | null)?.opening_direction ??
            (qlInfo?.config_snapshot as { opening_direction?: string; openingDirection?: string } | null)?.openingDirection ??
            null,
          has_side_channel: hasSideChannel,
          has_bottom_channel: hasBottomChannel,
          has_headbox: hasHeadbox,
          style_label: draperyStyleLabel,
          install_included: isInstallIncluded,
          accessories: formatAccessoriesForPDF(
            (snapFrozen as { accessories?: unknown } | null)?.accessories ??
            (snap as { accessories?: unknown } | undefined)?.accessories
          ),
          qty,
          unit_price: unitPrice,
          line_total: lineTotal,
        };
      });

      const creatorId = proposal.created_by_user_id ?? null;
      const sellerName =
        creatorId
          ? (await getAppUsersDisplayNames([creatorId])).get(creatorId) ?? 'System'
          : 'System';

      const doc = generateProposalPDF(
        {
          proposal_no: proposal.proposal_no || proposal.id.slice(0, 8),
          status: proposal.status,
          currency: proposal.currency || 'USD',
          valid_until: proposal.valid_until,
          description: proposal.description ?? undefined,
          notes: (headerForm.notes?.trim() || proposal.notes) ?? undefined,
          terms_title: (headerForm.terms_title?.trim() || proposal.terms_title) ?? undefined,
          terms_content: headerForm.terms_content ?? proposal.terms_content ?? undefined,
          global_discount_pct: proposal.global_discount_pct,
          global_fee_amount: proposal.global_fee_amount,
          subtotal_amount: proposal.subtotal_amount ?? undefined,
          installation_amount: proposal.installation_amount ?? undefined,
          discount_amount: proposal.discount_amount ?? undefined,
          tax_amount: proposal.tax_amount ?? undefined,
          total_amount: proposal.total_amount ?? undefined,
          created_at: proposal.created_at,
        },
        customer,
        contact
          ? {
              contact_name: contact.contact_name ?? contact.contact_email ?? undefined,
              contact_email: contact.contact_email ?? undefined,
            }
          : null,
        pdfLines,
        {
          variant,
          organizationName,
          logoPngBase64,
          logoWidthPx,
          logoHeightPx,
          sellerName,
          customerAddress: customerAddressDisplay || undefined,
          customerEmail: contact?.contact_email ?? customer?.customer_email ?? undefined,
          customerPhone: customer?.customer_phone ?? undefined,
          overrideTotals: {
            totalProduct: summary.totalProduct ?? 0,
            discountAmount: summary.discountAmount ?? 0,
            installationAmount: summary.installationAmount ?? 0,
            subtotal: summary.subtotal ?? 0,
            taxAmount: summary.taxAmount ?? 0,
            total: summary.total ?? 0,
          },
          global_discount_pct: proposal.global_discount_pct ?? undefined,
          tax_pct: proposal.tax_pct ?? undefined,
          exempt_tax: proposal.exempt_tax ?? undefined,
        }
      );

      const proposalNo = proposal.proposal_no || proposal.id.slice(0, 8);
      const customerPart = (customer?.customer_name ?? 'Customer')
        .replace(/[\\/:*?"<>|]/g, '')
        .trim()
        .slice(0, 80) || 'Customer';
      const fileName = `${proposalNo}_${customerPart}.PDF`;
      return { doc, fileName };
    },
    [proposal, proposalId, displayLines, quoteLinesMap, configuredProductsMap, customer, contact, totals, summary, formatAccessoriesForPDF, dealerLogoUrl, headerForm]
  );

  const handlePreviewPDF = useCallback(
    async (variant: 'internal' | 'customer') => {
      const previewWindow = window.open('', '_blank');
      if (!previewWindow) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Popup blocked',
          message: 'Please allow popups for this site to preview the PDF.',
        });
        return;
      }
      try {
        const result = await buildProposalPDFDoc(variant);
        if (result) {
          const blob = result.doc.output('blob');
          const url = URL.createObjectURL(blob);
          previewWindow.location.href = url;
          setTimeout(() => URL.revokeObjectURL(url), 60000);
          useUIStore.getState().addNotification({
            type: 'success',
            title: 'Preview',
            message: `PDF abierto en nueva pestaña (${result.fileName}). Descárgalo desde el botón de descarga del navegador cuando quieras.`,
          });
        } else {
          previewWindow.close();
        }
      } catch (err: any) {
        previewWindow.close();
        console.error('Error generating PDF:', err);
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: err?.message || 'Failed to generate PDF',
        });
      }
    },
    [buildProposalPDFDoc]
  );

  const handleDownloadPDF = useCallback(
    async (variant: 'internal' | 'customer') => {
      try {
        const result = await buildProposalPDFDoc(variant);
        if (result) {
          const blob = result.doc.output('blob');
          const url = URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = url;
          a.download = result.fileName;
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          setTimeout(() => URL.revokeObjectURL(url), 60000);
          useUIStore.getState().addNotification({
            type: 'success',
            title: 'Download',
            message: `PDF descargado: ${result.fileName}`,
          });
        }
      } catch (err: any) {
        console.error('Error generating PDF:', err);
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: err?.message || 'Failed to generate PDF',
        });
      }
    },
    [buildProposalPDFDoc]
  );

  /**
   * Measurement Verification Form (field worksheet) generated from the PROPOSAL.
   * Source of truth for dimensions is the frozen proposal-line snapshot
   * (what the client actually received), falling back to the live QuoteLine /
   * ConfiguredProduct snapshot. Custom lines (no QuoteLine, no measurements) are
   * included with blank dimensions so they can be filled in by hand.
   */
  const handleMeasurementForm = useCallback(async () => {
    if (!proposal || !proposalId) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: 'Open a proposal first.' });
      return;
    }
    try {
      let logoPngBase64: string | undefined;
      let logoWidthPx = 100;
      let logoHeightPx = 100;
      let dealerName: string | undefined;

      let logoUrlForPdf = dealerLogoUrl;
      if (proposal.dealer_id) {
        const { data: dealerData } = await supabase
          .from('Dealers')
          .select('logo_url, dealer_name')
          .eq('id', proposal.dealer_id)
          .maybeSingle();
        dealerName = (dealerData as { dealer_name?: string } | null)?.dealer_name ?? undefined;
        if (!logoUrlForPdf) logoUrlForPdf = (dealerData as { logo_url?: string } | null)?.logo_url ?? null;
      }
      const logoPath = getLogoPathFromUrl(logoUrlForPdf);
      const cleanPath = logoPath ? logoPath.replace(/^\/+/, '') : null;
      const logoUrlToLoad = cleanPath
        ? supabase.storage.from('catalog-images').getPublicUrl(cleanPath).data.publicUrl
        : /^https?:\/\//i.test(logoUrlForPdf ?? '') ? logoUrlForPdf! : null;

      if (logoUrlToLoad) {
        try {
          let dataUrl: string | null = null;
          const res = await fetch(logoUrlToLoad, { mode: 'cors', credentials: 'omit' });
          if (res.ok) {
            const blob = await res.blob();
            if (blob.type.startsWith('image/')) {
              dataUrl = await new Promise<string>((resolve, reject) => {
                const reader = new FileReader();
                reader.onloadend = () => resolve(reader.result as string);
                reader.onerror = reject;
                reader.readAsDataURL(blob);
              });
            }
          }
          if (!dataUrl) {
            dataUrl = await new Promise<string | null>((resolve) => {
              const img = new Image();
              img.crossOrigin = 'anonymous';
              img.onload = () => {
                try {
                  const c = document.createElement('canvas');
                  c.width = img.naturalWidth; c.height = img.naturalHeight;
                  const ctx = c.getContext('2d');
                  if (ctx) { ctx.drawImage(img, 0, 0); resolve(c.toDataURL('image/png')); }
                  else resolve(null);
                } catch { resolve(null); }
              };
              img.onerror = () => resolve(null);
              img.src = logoUrlToLoad;
            });
          }
          if (dataUrl) {
            logoPngBase64 = dataUrl;
            const dims = await new Promise<{ w: number; h: number } | null>((resolve) => {
              const img2 = new Image();
              img2.onload = () => resolve({ w: img2.naturalWidth, h: img2.naturalHeight });
              img2.onerror = () => resolve(null);
              img2.src = dataUrl!;
            });
            if (dims) { logoWidthPx = dims.w; logoHeightPx = dims.h; }
          }
        } catch { /* logo unavailable — PDF will render without it */ }
      }

      const formLines: MeasurementFormLine[] = displayLines.map((line) => {
        if (line.line_type === 'custom') {
          return {
            area: line.area ?? null,
            position: line.position ?? null,
            product_type: line.custom_category ?? 'Custom',
            collection_name: null,
            variant_name: null,
            description: line.description ?? null,
            qty: Number(line.qty) || 1,
            width_m: null,
            height_m: null,
            dimensions_source: null,
            drive_type: null,
            drive_side: null,
            opening_direction: null,
            installation_type: null,
            installation_location: null,
          };
        }
        const snapFrozen = line.quote_line_snapshot as
          | (Record<string, unknown> & { measurements?: unknown; panels?: unknown[]; width_m?: number | null; height_m?: number | null })
          | null
          | undefined;
        const qlInfo = line.quote_line_id ? quoteLinesMap.get(line.quote_line_id) : undefined;
        const cpSnap = qlInfo?.configured_product_id
          ? (configuredProductsMap ?? {})[qlInfo.configured_product_id]?.config_snapshot
          : undefined;
        const liveSnap = (qlInfo?.config_snapshot ?? cpSnap) as
          | (Record<string, unknown> & { measurements?: unknown; panels?: unknown[] })
          | undefined;

        const dimensionsSource =
          snapFrozen && (snapFrozen.width_m != null || snapFrozen.height_m != null || (typeof snapFrozen.measurements === 'object' && snapFrozen.measurements))
            ? {
                measurements: (typeof snapFrozen.measurements === 'object' && snapFrozen.measurements) ? snapFrozen.measurements : undefined,
                panels: Array.isArray(snapFrozen.panels) ? snapFrozen.panels : undefined,
                width_m: snapFrozen.width_m ?? null,
                height_m: snapFrozen.height_m ?? null,
              }
            : liveSnap
              ? {
                  measurements: (typeof liveSnap.measurements === 'object' && liveSnap.measurements) ? liveSnap.measurements : undefined,
                  panels: Array.isArray(liveSnap.panels) ? liveSnap.panels : undefined,
                  width_m: qlInfo?.width_m ?? null,
                  height_m: qlInfo?.height_m ?? null,
                }
              : qlInfo
                ? { width_m: qlInfo.width_m ?? null, height_m: qlInfo.height_m ?? null }
                : null;

        const productTypeRaw = (snapFrozen?.product_type as string | undefined) ?? qlInfo?.product_type ?? null;
        const productTypeName =
          (qlInfo?.product_type_id && productTypeNameByCodeOrId.byId.get(qlInfo.product_type_id)) ??
          (productTypeRaw && productTypeNameByCodeOrId.byCode.get(productTypeRaw.trim().toLowerCase())) ??
          productTypeRaw;

        const pickStr = (...vals: unknown[]): string | null => {
          for (const v of vals) {
            if (typeof v === 'string' && v.trim()) return v;
          }
          return null;
        };

        const collectionName = (snapFrozen?.collection_name as string | undefined) ?? qlInfo?.collection_name ?? null;
        const variantName = (snapFrozen?.variant_name as string | undefined) ?? qlInfo?.variant_name ?? null;
        const isCatalogLine = String(productTypeRaw ?? '').trim().toLowerCase() === 'catalog';
        const baseName = pickStr(snapFrozen?.name, snapFrozen?.sku, qlInfo?.name, qlInfo?.sku);
        const catalogColor = isCatalogLine ? pickStr((qlInfo as { catalog_color?: unknown } | undefined)?.catalog_color) : null;
        // Catalog (and any line without collection/variant) shows its item name so the row isn't blank.
        const description =
          isCatalogLine && baseName
            ? (catalogColor ? `${baseName} — ${catalogColor}` : baseName)
            : (!collectionName && !variantName ? baseName ?? undefined : undefined);

        return {
          area: (snapFrozen?.area as string | undefined) ?? qlInfo?.area ?? null,
          position: (snapFrozen?.position as string | undefined) ?? qlInfo?.position ?? null,
          product_type: productTypeName ?? '—',
          collection_name: collectionName,
          variant_name: variantName,
          description,
          qty: Number((snapFrozen?.qty as number | undefined) ?? qlInfo?.quantity ?? line.qty ?? 1) || 1,
          width_m: (dimensionsSource?.width_m as number | null | undefined) ?? null,
          height_m: (dimensionsSource?.height_m as number | null | undefined) ?? null,
          dimensions_source: dimensionsSource as MeasurementFormLine['dimensions_source'],
          drive_type: pickStr(snapFrozen?.drive_type, qlInfo?.drive_type, liveSnap?.drive_type),
          drive_side: pickStr(liveSnap?.drive_side, (liveSnap as { driveSide?: unknown } | undefined)?.driveSide),
          opening_direction: pickStr(
            snapFrozen?.opening_direction,
            (liveSnap as { opening_direction?: unknown } | undefined)?.opening_direction,
            (liveSnap as { openingDirection?: unknown } | undefined)?.openingDirection
          ),
          installation_type: pickStr(
            qlInfo?.installation_type,
            (liveSnap as { installationType?: unknown } | undefined)?.installationType,
            (liveSnap as { installation_type?: unknown } | undefined)?.installation_type
          ),
          installation_location: pickStr(
            qlInfo?.installation_location,
            (liveSnap as { installationLocation?: unknown } | undefined)?.installationLocation,
            (liveSnap as { installation_location?: unknown } | undefined)?.installation_location
          ),
        };
      });

      const doc = generateMeasurementFormPDF(formLines, {
        quote_no: proposal.proposal_no || proposal.id.slice(0, 8),
        customer_name: customer?.customer_name ?? null,
        contact_name: contact?.contact_name ?? contact?.contact_email ?? null,
        address: normalizeAddressText(customer?.address ?? null) || null,
        project_description: proposal.description ?? null,
        created_at: proposal.created_at || new Date().toISOString(),
        logoPngBase64,
        logoWidthPx,
        logoHeightPx,
        dealerName,
      });

      const blob = doc.output('blob');
      const url = URL.createObjectURL(blob);
      window.open(url, '_blank');
      setTimeout(() => URL.revokeObjectURL(url), 60000);
    } catch (err: any) {
      console.error('Error generating measurement form:', err);
      useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err?.message || 'Failed to generate measurement form' });
    }
  }, [proposal, proposalId, displayLines, quoteLinesMap, configuredProductsMap, customer, contact, dealerLogoUrl, productTypeNameByCodeOrId]);

  if (!proposalId) {
    return (
      <div className="p-6">
        <p className="text-gray-500">Proposal ID not found.</p>
        <button onClick={handleBack} className="mt-2 text-blue-600 hover:underline">
          Back to Proposals
        </button>
      </div>
    );
  }

  if (loading && !proposal) {
    return <div className="p-6">Loading...</div>;
  }

  if (error || !proposal) {
    return (
      <div className="p-6">
        <p className="text-red-600">{error || 'Proposal not found'}</p>
        <button onClick={handleBack} className="mt-2 text-blue-600 hover:underline">
          Back to Proposals
        </button>
      </div>
    );
  }

  if (!stateResolved) {
    return <div className="p-6">Loading...</div>;
  }

  const readOnly = !canWrite;
  const isAccepted = proposal?.status === 'accepted';
  // Who can reopen an accepted proposal: portal Dealer Manager (Admin Dealer) or
  // any internal user with write access. Blocked if a Sales Order already exists.
  const isAdminDealer = userType === 'portal' && portalRole === 'dealer_manager';
  const canRevertStatus = isAccepted && (isAdminDealer || userType === 'internal') && !hasDownstreamSO;
  const contentReadOnly = readOnly || !!isAccepted;
  const statusDropdownDisabled = contentReadOnly && !canRevertStatus;

  const contactDisplay = (contact?.contact_name ?? '').trim();
  const customerAddressDisplay = normalizeAddressText(customer?.address ?? null);
  const linkedQuoteId = quote?.id ?? proposal.quote_id ?? null;
  const actionButtons = (
    <div className="flex items-center gap-2">
      <div className="relative" ref={printDropdownRef}>
        <button
          type="button"
          onClick={() => setPrintDropdownOpen((v) => !v)}
          className="flex items-center gap-1.5 px-2.5 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors hover:bg-gray-50"
          title="Print"
          aria-expanded={printDropdownOpen}
          aria-haspopup="true"
        >
          <Printer className="w-4 h-4 shrink-0 text-gray-600" />
          <ChevronDown className={`w-4 h-4 shrink-0 text-gray-500 transition-transform ${printDropdownOpen ? 'rotate-180' : ''}`} />
        </button>
        {printDropdownOpen && (
          <div
            className="absolute right-0 top-full mt-1 z-50 min-w-[200px] rounded-lg border border-gray-200 bg-white py-1 shadow-lg"
            role="menu"
          >
            <div className="px-3 py-1.5 text-xs font-medium text-gray-500 border-b border-gray-100">Preview in browser</div>
            <button
              type="button"
              role="menuitem"
              className="w-full px-3 py-2 text-left text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-2"
              onClick={() => {
                handlePreviewPDF('internal');
                setPrintDropdownOpen(false);
              }}
            >
              <Eye className="w-4 h-4 shrink-0 text-gray-500" />
              Full Detail
            </button>
            <button
              type="button"
              role="menuitem"
              className="w-full px-3 py-2 text-left text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-2"
              onClick={() => {
                handlePreviewPDF('customer');
                setPrintDropdownOpen(false);
              }}
            >
              <Eye className="w-4 h-4 shrink-0 text-gray-500" />
              Without Measurements
            </button>
            <div className="px-3 py-1.5 text-xs font-medium text-gray-500 border-t border-b border-gray-100 mt-1">Download PDF</div>
            <button
              type="button"
              role="menuitem"
              className="w-full px-3 py-2 text-left text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-2"
              onClick={() => {
                handleDownloadPDF('internal');
                setPrintDropdownOpen(false);
              }}
            >
              <Download className="w-4 h-4 shrink-0 text-gray-500" />
              Full Detail
            </button>
            <button
              type="button"
              role="menuitem"
              className="w-full px-3 py-2 text-left text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-2"
              onClick={() => {
                handleDownloadPDF('customer');
                setPrintDropdownOpen(false);
              }}
            >
              <Download className="w-4 h-4 shrink-0 text-gray-500" />
              Without Measurements
            </button>
            <div className="px-3 py-1.5 text-xs font-medium text-gray-500 border-t border-b border-gray-100 mt-1">Worksheet</div>
            <button
              type="button"
              role="menuitem"
              className="w-full px-3 py-2 text-left text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-2"
              onClick={() => {
                handleMeasurementForm();
                setPrintDropdownOpen(false);
              }}
            >
              <Ruler className="w-4 h-4 shrink-0 text-gray-500" />
              Measurement Form
            </button>
          </div>
        )}
      </div>
      {linkedQuoteId && (
        <button
          type="button"
          onClick={() => router.navigate(withReturnTo(`/sales/quotes/${linkedQuoteId}/edit`))}
          className="inline-flex items-center justify-center p-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors hover:bg-gray-50"
          title="Go to Quote"
          aria-label="Go to Quote"
        >
          <ExternalLink className="w-4 h-4" />
        </button>
      )}
      {(hasRedirectBack || quote) && (
        <button
          type="button"
          onClick={() => {
            if (hasRedirectBack) {
              handleBackContextual();
            } else if (quote) {
              router.navigate(`/sales/quotes/${quote.id}/edit`);
            }
          }}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
          title="Back"
        >
          <ArrowLeft className="w-4 h-4" />
          Back
        </button>
      )}
      {(proposal?.status === 'accepted' || proposal?.status === 'sent') && (
        <button
          type="button"
          onClick={handleCreateVersion}
          disabled={creatingVersion}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
          title="Crear una nueva versión (revisión) de esta propuesta"
        >
          <Plus className="w-4 h-4" />
          {creatingVersion ? 'Creando...' : 'New version'}
        </button>
      )}
      <button
        type="button"
        onClick={handleSave}
        disabled={saving || (contentReadOnly && !canRevertStatus)}
        className="btn-save px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
        title="Save"
      >
        {saving ? 'Saving...' : 'Save'}
      </button>
      <button
        type="button"
        onClick={handleSaveAndClose}
        disabled={saving || (contentReadOnly && !canRevertStatus)}
        className="btn-save-close px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {saving ? 'Saving...' : 'Save and Close'}
      </button>
    </div>
  );

  const tabs = [
    { id: 'overview', label: 'Overview' },
    { id: 'profitability', label: 'Performance' },
    { id: 'timeline', label: 'Timeline' },
  ];
  // Keep this as a plain value (not a hook) because this block is after early returns.
  return (
    <DetailPageLayout
      title={proposal.proposal_no || proposal.id.slice(0, 8)}
      subtitle="Proposal"
      status={<StatusBadge status={proposal.status} type="proposal" />}
      tabs={tabs}
      activeTab={activeTab}
      onTabChange={setActiveTab}
      onBack={handleBack}
      actions={actionButtons}
    >
      {activeTab === 'overview' && (
        <div className="space-y-6 w-full max-w-full">
          {/* Header cards (2 columns: Left = names/details, Right = discounts + summary) */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
            {/* LEFT CARD: Customer Info + Proposal Details (mirrors QuoteNew layout) */}
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Customer Info</h3>
              <div className="space-y-3">
                {/* Customer + Contact side-by-side, matching QuoteNew's grid */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div>
                    <Label htmlFor="proposal-customer">Customer (optional)</Label>
                    {contentReadOnly ? (
                      <div className="h-9 px-2.5 py-1.5 border border-gray-200 rounded text-sm bg-gray-50 text-gray-700 flex items-center">
                        {customer?.customer_name ?? '—'}
                      </div>
                    ) : (
                      <SelectShadcn
                        value={headerForm.customer_id || 'none'}
                        onValueChange={(v) => {
                          setHeaderForm((f) => ({ ...f, customer_id: v === 'none' ? '' : v }));
                          setHeaderDirty(true);
                        }}
                      >
                        <SelectTrigger id="proposal-customer">
                          <SelectValue placeholder="Select customer (optional)" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="none">None</SelectItem>
                          {directoryCustomers.map((c) => (
                            <SelectItem key={c.id} value={c.id}>{c.customer_name}</SelectItem>
                          ))}
                        </SelectContent>
                      </SelectShadcn>
                    )}
                  </div>
                  <div>
                    <Label htmlFor="proposal-contact">Contact (optional)</Label>
                    {contentReadOnly ? (
                      <div className="h-9 px-2.5 py-1.5 border border-gray-200 rounded text-sm bg-gray-50 text-gray-700 flex items-center">
                        {contactDisplay || '—'}
                      </div>
                    ) : (
                      <SelectShadcn
                        value={headerForm.contact_id || 'none'}
                        onValueChange={(v) => {
                          setHeaderForm((f) => ({ ...f, contact_id: v === 'none' ? '' : v }));
                          setHeaderDirty(true);
                        }}
                        disabled={!headerForm.customer_id}
                      >
                        <SelectTrigger id="proposal-contact">
                          <SelectValue
                            placeholder={headerForm.customer_id ? 'Select contact (optional)' : 'Pick a customer first'}
                          />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="none">None</SelectItem>
                          {proposalContacts.map((c) => (
                            <SelectItem key={c.id} value={c.id}>{c.contact_name}</SelectItem>
                          ))}
                        </SelectContent>
                      </SelectShadcn>
                    )}
                  </div>
                </div>
                {!contentReadOnly && (quote || proposal.quote_id) && (
                  <p className="text-xs text-gray-500">
                    {quote ? (
                      <>
                        Linked Quote:{' '}
                        <button
                          type="button"
                          onClick={() => router.navigate(withReturnTo(`/sales/quotes/${quote.id}`))}
                          className="text-primary hover:underline font-medium"
                        >
                          {quote.quote_no}
                        </button>
                        . Customer/Contact changes sync to the Quote.
                      </>
                    ) : (
                      'Linked to a parent Quote — changes sync both ways.'
                    )}
                  </p>
                )}

                {(customerAddressDisplay || contact?.contact_email || customer?.customer_email || customer?.customer_phone) && (
                  <div className="border-t border-gray-100 pt-3 space-y-1.5 text-xs">
                    {customerAddressDisplay && (
                      <div className="flex justify-between gap-3">
                        <dt className="text-gray-500 shrink-0">Address</dt>
                        <dd className="text-gray-700 text-right">{customerAddressDisplay}</dd>
                      </div>
                    )}
                    {(contact?.contact_email || customer?.customer_email) && (
                      <div className="flex justify-between gap-3">
                        <dt className="text-gray-500 shrink-0">Email</dt>
                        <dd className="text-gray-700">{contact?.contact_email ?? customer?.customer_email}</dd>
                      </div>
                    )}
                    {customer?.customer_phone && (
                      <div className="flex justify-between gap-3">
                        <dt className="text-gray-500 shrink-0">Phone</dt>
                        <dd className="text-gray-700">{customer.customer_phone}</dd>
                      </div>
                    )}
                  </div>
                )}

                <div>
                  <Label htmlFor="proposal-description">Description</Label>
                  <textarea
                    id="proposal-description"
                    rows={1}
                    className="w-full h-9 min-h-9 resize-none px-2.5 py-1.5 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                    value={headerForm.description}
                    onChange={(e) => { setHeaderForm((f) => ({ ...f, description: e.target.value })); setHeaderDirty(true); }}
                    disabled={contentReadOnly}
                    placeholder="Short proposal description"
                  />
                </div>
              </div>

              <div className="border-t border-gray-200 mt-4 pt-4">
                <h3 className="text-sm font-semibold text-gray-900 mb-3">Details</h3>
                <div className="space-y-3">
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                    <div>
                      <Label>Proposal No</Label>
                      <Input
                        value={headerForm.proposal_no}
                        onChange={(e) => { setHeaderForm((f) => ({ ...f, proposal_no: e.target.value })); setHeaderDirty(true); }}
                        disabled={contentReadOnly}
                      />
                    </div>
                    <div>
                      <Label>Status</Label>
                      <SelectShadcn
                        value={headerForm.status}
                        onValueChange={(v) => {
                          const next = v as Proposal['status'];
                          // Reopening an accepted proposal is an exceptional correction: confirm.
                          if (proposal?.status === 'accepted' && next !== 'accepted') {
                            const ok = window.confirm(
                              'Vas a reabrir una propuesta ACEPTADA y regresarla a edición. Úsalo solo para corregir un error. Para cambios de color/medidas, mejor crea una nueva versión. ¿Continuar?'
                            );
                            if (!ok) return;
                          }
                          setHeaderForm((f) => ({ ...f, status: next }));
                          setHeaderDirty(true);
                        }}
                        disabled={statusDropdownDisabled}
                      >
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {PROPOSAL_STATUS_OPTIONS.map((o) => (
                            <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
                          ))}
                        </SelectContent>
                      </SelectShadcn>
                      {isAccepted && hasDownstreamSO && (
                        <p className="text-[11px] text-amber-600 mt-1">
                          No se puede reabrir: ya existe una orden de venta generada. Crea una nueva versión si necesitas cambios.
                        </p>
                      )}
                    </div>
                    <div>
                      <Label>Valid until</Label>
                      <Input
                        type="date"
                        value={headerForm.valid_until}
                        onChange={(e) => { setHeaderForm((f) => ({ ...f, valid_until: e.target.value })); setHeaderDirty(true); }}
                        disabled={contentReadOnly}
                      />
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* RIGHT CARD: Adjustments + Summary */}
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Adjustments</h3>
              <div className="grid grid-cols-2 xl:grid-cols-4 gap-3">
                <div>
                  <Label className="block min-h-[2.5rem] leading-5">Global Disc. %</Label>
                  <Input
                    type="number"
                    step="0.01"
                    min="0"
                    max="100"
                    placeholder="0"
                    value={headerForm.global_discount_pct}
                    onChange={(e) => { setHeaderForm((f) => ({ ...f, global_discount_pct: e.target.value })); setHeaderDirty(true); }}
                    disabled={contentReadOnly}
                  />
                </div>
                <div>
                  <Label className="block min-h-[2.5rem] leading-5">Global Fee %</Label>
                  <Input
                    type="number"
                    step="0.01"
                    min="0"
                    max="100"
                    placeholder="0"
                    title="Distributed into every line price (hidden from the customer). Re-applies to all lines when changed."
                    value={headerForm.global_fee_amount}
                    onChange={(e) => { setHeaderForm((f) => ({ ...f, global_fee_amount: e.target.value })); setHeaderDirty(true); }}
                    onBlur={(e) => { if (!contentReadOnly) applyGlobalFeePct(e.target.value); }}
                    disabled={contentReadOnly}
                  />
                </div>
                <div>
                  <Label className="block min-h-[2.5rem] leading-5">Labor Disc. %</Label>
                  <Input
                    type="number"
                    step="0.01"
                    min="0"
                    max="100"
                    placeholder="0"
                    value={headerForm.global_installation_discount_pct}
                    onChange={(e) => { setHeaderForm((f) => ({ ...f, global_installation_discount_pct: e.target.value })); setHeaderDirty(true); }}
                    disabled={contentReadOnly}
                  />
                </div>
                <div>
                  <Label className="block min-h-[2.5rem] leading-5">Labor Fee %</Label>
                  <Input
                    type="number"
                    step="0.01"
                    min="0"
                    max="100"
                    placeholder="0"
                    value={headerForm.global_installation_fee_pct}
                    onChange={(e) => { setHeaderForm((f) => ({ ...f, global_installation_fee_pct: e.target.value })); setHeaderDirty(true); }}
                    disabled={contentReadOnly}
                  />
                </div>
              </div>

              <div className="border-t border-gray-200 mt-5 pt-4">
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <h3 className="text-sm font-semibold text-gray-900">Summary</h3>
                    {(proposal?.status === 'sent' || proposal?.status === 'accepted') && (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-medium bg-gray-100 text-gray-600 border border-gray-200" title="Committed proposal: totals are locked at the value sent to the customer.">
                        <Lock className="w-3 h-3" /> Locked
                      </span>
                    )}
                  </div>
                  <label className="flex items-center gap-1.5 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={headerForm.exempt_tax}
                      onChange={(e) => { setHeaderForm((f) => ({ ...f, exempt_tax: e.target.checked })); setHeaderDirty(true); }}
                      disabled={contentReadOnly}
                      className="rounded border-gray-300"
                    />
                    <span className="text-xs text-gray-600">Exempt Tax</span>
                  </label>
                </div>
                <div className="flex justify-between py-1 text-sm">
                  <span className="text-gray-600">Total Product</span>
                  <span className="tabular-nums">{formatCurrency(summary.totalProduct ?? 0, currency)}</span>
                </div>
                {(summary.discountAmount ?? 0) > 0 && (
                  <div className="flex justify-between py-1 text-sm">
                    <span className="text-gray-600">Discount {summary.discountPct ? `(${summary.discountPct}%)` : ''}</span>
                    <span className="tabular-nums">-{formatCurrency(summary.discountAmount ?? 0, currency)}</span>
                  </div>
                )}
                {(summary.installationTotal ?? summary.installationAmount ?? 0) > 0 && (
                  <>
                    {(summary.laborDiscountAmount ?? 0) > 0 ? (
                      <>
                        <div className="flex justify-between py-1 text-sm">
                          <span className="text-gray-600">Installation</span>
                          <span className="tabular-nums">{formatCurrency(summary.installationTotal ?? 0, currency)}</span>
                        </div>
                        <div className="flex justify-between py-1 text-sm">
                          <span className="text-gray-600">Labor discount {summary.instDiscountPct ? `(${summary.instDiscountPct}%)` : ''}</span>
                          <span className="tabular-nums">-{formatCurrency(summary.laborDiscountAmount ?? 0, currency)}</span>
                        </div>
                        <div className="flex justify-between py-1 text-sm font-medium">
                          <span className="text-gray-700">Installation (net)</span>
                          <span className="tabular-nums">{formatCurrency(summary.installationNet ?? 0, currency)}</span>
                        </div>
                      </>
                    ) : (
                      <div className="flex justify-between py-1 text-sm">
                        <span className="text-gray-600">Installation</span>
                        <span className="tabular-nums">{formatCurrency(summary.installationNet ?? summary.installationAmount ?? 0, currency)}</span>
                      </div>
                    )}
                  </>
                )}
                {(summary.otherAddonsTotal ?? 0) > 0 && (
                  <div className="flex justify-between py-1 text-sm">
                    <span className="text-gray-600">Other add-ons</span>
                    <span className="tabular-nums">{formatCurrency(summary.otherAddonsTotal ?? 0, currency)}</span>
                  </div>
                )}
                <div
                  className="flex justify-between py-1 text-sm cursor-pointer group"
                  onClick={() => { if (!contentReadOnly) { setShowAdjSubtotal((v) => !v); setShowAdjTotal(false); } }}
                >
                  <span className="text-gray-600">Subtotal</span>
                  <span className="tabular-nums inline-flex items-center gap-1">
                    {!contentReadOnly && (showAdjSubtotal
                      ? <ChevronDown className="w-3 h-3 text-gray-400 group-hover:text-gray-600" />
                      : <ChevronRight className="w-3 h-3 text-gray-400 group-hover:text-gray-600" />
                    )}
                    {formatCurrency(summary.subtotal ?? 0, currency)}
                  </span>
                </div>
                {showAdjSubtotal && !contentReadOnly && (
                  <div className="flex justify-end pb-2">
                    <div className="flex items-end gap-2">
                      <div>
                        <Label className="text-xs text-gray-500">Target subtotal</Label>
                        <Input
                          type="number"
                          step="0.01"
                          min="0"
                          className="w-32 mt-0.5"
                          value={targetSubtotalInput}
                          placeholder={String(Math.round((summary.subtotal ?? 0) * 100) / 100)}
                          onChange={(e) => setTargetSubtotalInput(e.target.value)}
                          onBlur={() => applyTargetSubtotal(targetSubtotalInput)}
                          onKeyDown={(e) => {
                            if (e.key === 'Enter') {
                              e.preventDefault();
                              applyTargetSubtotal(targetSubtotalInput);
                              (e.target as HTMLInputElement).blur();
                            }
                          }}
                        />
                      </div>
                      <button
                        type="button"
                        onClick={() => applyTargetSubtotal(targetSubtotalInput)}
                        className="px-2 py-1 text-xs rounded border border-gray-300 bg-white text-gray-700 hover:bg-gray-50"
                      >
                        Apply
                      </button>
                    </div>
                  </div>
                )}
                {!headerForm.exempt_tax && (
                  <div className="flex justify-between py-1 text-sm">
                    <span className="text-gray-600">Tax</span>
                    <span className="tabular-nums">{formatCurrency(summary.taxAmount ?? 0, currency)}</span>
                  </div>
                )}
                <div
                  className="flex justify-between py-2 mt-2 border-t border-gray-200 font-semibold cursor-pointer group"
                  onClick={() => { if (!contentReadOnly) { setShowAdjTotal((v) => !v); setShowAdjSubtotal(false); } }}
                >
                  <span>Total {currency ? `(${currency})` : ''}</span>
                  <span className="tabular-nums inline-flex items-center gap-1">
                    {!contentReadOnly && (showAdjTotal
                      ? <ChevronDown className="w-3 h-3 text-gray-400 group-hover:text-gray-600" />
                      : <ChevronRight className="w-3 h-3 text-gray-400 group-hover:text-gray-600" />
                    )}
                    {formatCurrency(summary.total, currency)}
                  </span>
                </div>
                {showAdjTotal && !contentReadOnly && (
                  <div className="flex justify-end pb-2">
                    <div className="flex items-end gap-2">
                      <div>
                        <Label className="text-xs text-gray-500">Target total (inc. tax)</Label>
                        <Input
                          type="number"
                          step="0.01"
                          min="0"
                          className="w-32 mt-0.5"
                          value={targetTotalInput}
                          placeholder={String(Math.round((summary.total ?? 0) * 100) / 100)}
                          onChange={(e) => setTargetTotalInput(e.target.value)}
                          onBlur={() => applyTargetTotal(targetTotalInput)}
                          onKeyDown={(e) => {
                            if (e.key === 'Enter') {
                              e.preventDefault();
                              applyTargetTotal(targetTotalInput);
                              (e.target as HTMLInputElement).blur();
                            }
                          }}
                        />
                      </div>
                      <button
                        type="button"
                        onClick={() => applyTargetTotal(targetTotalInput)}
                        className="px-2 py-1 text-xs rounded border border-gray-300 bg-white text-gray-700 hover:bg-gray-50"
                      >
                        Apply
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Lines - above Notes */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-6">
        <div className="p-4 border-b border-gray-200 flex justify-between items-center">
          <h2 className="text-xl font-semibold text-gray-900">Lines</h2>
          {!contentReadOnly && (
            <button
              onClick={addCustomLine}
              className="flex items-center gap-2 px-3 py-2 text-sm text-white rounded-lg transition-colors hover:opacity-90"
              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            >
              <Plus className="w-4 h-4" />
              Custom Item
            </button>
          )}
        </div>

        {displayLines.length === 0 ? (
          <div className="py-12 px-6 text-center">
            <p className="text-gray-500 mb-4">No lines yet. Add lines from the Quote or add a custom item.</p>
            <div className="flex flex-wrap gap-3 justify-center">
              {!contentReadOnly && (
                <button
                  onClick={addCustomLine}
                  className="flex items-center gap-2 px-4 py-2 text-white rounded-lg transition-colors hover:opacity-90"
                  style={{ backgroundColor: 'var(--primary-brand-hex)' }}
                >
                  <Plus className="w-4 h-4" />
                  Custom Item
                </button>
              )}
              {quote && (
                <button
                  onClick={() => router.navigate(withReturnTo(`/sales/quotes/${quote.id}/edit`))}
                  className="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 text-gray-700"
                >
                  Back to Quote
                </button>
              )}
            </div>
          </div>
        ) : (
        <div className="table-fit-wrapper proposal-lines-table-wrapper overflow-x-auto">
          <table className="table-fit proposal-lines-table w-full min-w-[1320px]">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left py-3 px-2 font-medium text-gray-700 text-xs w-10" title="Drag to reorder"></th>
                <th className="text-center py-3 px-1 font-medium text-gray-700 text-xs w-11 min-w-[44px]" aria-label="Expand row"></th>
                <th className="text-center py-3 px-2 font-medium text-gray-700 text-xs w-12">#</th>
                <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs min-w-[8rem]">Area</th>
                <th className="text-center py-3 pl-0.5 pr-4 font-medium text-gray-700 text-xs w-24 min-w-[6rem] -ml-5">Position</th>
                <th className="text-left py-3 pl-[29px] pr-3 font-medium text-gray-700 text-xs min-w-[320px]">Description</th>
                <th className="text-left py-3 px-2 font-medium text-gray-700 text-xs min-w-[120px]">Product type</th>
                <th className="text-center py-3 px-1.5 font-medium text-gray-700 text-xs min-w-[64px] w-[64px]">Qty</th>
                <th className="w-[16px] min-w-[16px] py-3" aria-hidden></th>
                <th className="text-right py-3 pl-2 pr-2 font-medium text-gray-700 text-xs w-[108px] max-w-[108px]">Unit Price</th>
                <th className="text-right py-3 pl-2 pr-5 font-medium text-gray-700 text-xs min-w-[108px]">Line total</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
                <SortableContext items={displayLines.map((l) => l.id)} strategy={verticalListSortingStrategy}>
              {displayLines.map((line, index) => {
                const qlInfo = line.quote_line_id ? quoteLinesMap.get(line.quote_line_id) : undefined;
                const lineTotal = totals.lineTotals[index] ?? 0;
                const baseAmount = line.line_type === 'from_quote'
                  ? (proposal?.status === 'sent' || proposal?.status === 'accepted') && line.quote_line_snapshot && (line.quote_line_snapshot as { base_line_msrp?: number }).base_line_msrp != null
                    ? (line.quote_line_snapshot as { base_line_msrp: number }).base_line_msrp
                    : (qlInfo ? getQuoteLineBase(qlInfo) : 0)
                  : 0;
                const hasBasePrice = line.line_type === 'from_quote' && qlInfo && baseAmount > 0;
                const snap = line.quote_line_snapshot as {
                  width_m?: number | null;
                  height_m?: number | null;
                  measurements?: { panels?: unknown[]; height_mm?: number } | null;
                  panels?: unknown[] | null;
                  name?: string | null;
                  sku?: string | null;
                  drive_type?: string | null;
                  drive_system_label?: string | null;
                  opening_direction?: string | null;
                  openingDirection?: string | null;
                } | null;
                const dimsSource = {
                  measurements: snap?.measurements ?? (qlInfo?.config_snapshot as { measurements?: { panels?: unknown[]; height_mm?: number } } | undefined)?.measurements,
                  panels: snap?.panels ?? (qlInfo?.config_snapshot as { panels?: unknown[] } | undefined)?.panels,
                  width_m: snap?.width_m ?? qlInfo?.width_m ?? null,
                  height_m: snap?.height_m ?? qlInfo?.height_m ?? null,
                };
                const dimsMm = formatDimensionsForProposalPDF(dimsSource as Parameters<typeof formatDimensionsForProposalPDF>[0]);
                const isCustomInvalid =
                  line.line_type === 'custom' &&
                  (!(line.description?.trim()) || line.qty == null || line.unit_price == null || Number(line.qty) <= 0);
                const isExpanded = expandedLineId === line.id;
                const installationAddon = (displayAddonsMap?.get(line.id) || []).find((a) => a.addon_type === 'installation');
                const hasInstallationAddon = !!installationAddon;
                const isInstallIncluded = Number(installationAddon?.cost_amount ?? 0) > 0;
                const addonsTotal = (displayAddonsMap?.get(line.id) || []).reduce((s, a) => s + (Number(a.sale_amount) || 0), 0);
                const materialTotal = computeLineTotal(line, qlInfo, proposal?.status);
                const qtyForLine = line.line_type === 'from_quote'
                  ? (Number((line.quote_line_snapshot as { qty?: number } | null)?.qty) || qlInfo?.quantity || 1)
                  : (Number(line.qty) || 0);
                const unitPriceForDisplay = qtyForLine > 0 ? lineTotal / qtyForLine : lineTotal;
                const ptRawForOpening = (line.quote_line_snapshot as { product_type?: string } | null)?.product_type ?? qlInfo?.product_type ?? null;
                const ptNameForOpening =
                  (qlInfo?.product_type_id && productTypeNameByCodeOrId.byId.get(qlInfo.product_type_id)) ??
                  (ptRawForOpening && productTypeNameByCodeOrId.byCode.get(ptRawForOpening.trim().toLowerCase())) ??
                  ptRawForOpening;
                const styleCodeForDrapery =
                  (snap as { style_code?: string; styleCode?: string } | null)?.style_code ??
                  (snap as { style_code?: string; styleCode?: string } | null)?.styleCode ??
                  (qlInfo?.config_snapshot as { style_code?: string; styleCode?: string } | null)?.style_code ??
                  (qlInfo?.config_snapshot as { style_code?: string; styleCode?: string } | null)?.styleCode ??
                  null;
                const productLineForDrapery = readDraperyProductLine(
                  snap as { product_line?: string; productLine?: string } | null,
                  qlInfo?.config_snapshot as { product_line?: string; productLine?: string } | null
                );
                const trackOnlyForDrapery =
                  Boolean((snap as { track_only?: boolean } | null)?.track_only) ||
                  Boolean((qlInfo?.config_snapshot as { track_only?: boolean } | null)?.track_only);
                const draperyTrackDescription = getDraperyTrackDescription({
                  productTypeName: ptNameForOpening ?? null,
                  trackOnly: trackOnlyForDrapery,
                  productLine: productLineForDrapery,
                  styleCode: styleCodeForDrapery,
                });
                const hasSideChannel =
                  Boolean((snap as { side_channel?: boolean } | null)?.side_channel) ||
                  (typeof (snap as { side_channel_item_id?: string } | null)?.side_channel_item_id === 'string'
                    && String((snap as { side_channel_item_id?: string }).side_channel_item_id).trim().length > 10
                    && String((snap as { side_channel_item_id?: string }).side_channel_item_id).toUpperCase() !== 'NONE') ||
                  Boolean((qlInfo?.config_snapshot as { side_channel?: boolean } | null)?.side_channel) ||
                  (typeof (qlInfo?.config_snapshot as { side_channel_item_id?: string } | null)?.side_channel_item_id === 'string'
                    && String((qlInfo?.config_snapshot as { side_channel_item_id?: string }).side_channel_item_id).trim().length > 10
                    && String((qlInfo?.config_snapshot as { side_channel_item_id?: string }).side_channel_item_id).toUpperCase() !== 'NONE');
                const hasBottomChannel =
                  Boolean((snap as { bottom_channel?: boolean } | null)?.bottom_channel) ||
                  (typeof (snap as { bottom_channel_item_id?: string } | null)?.bottom_channel_item_id === 'string'
                    && String((snap as { bottom_channel_item_id?: string }).bottom_channel_item_id).trim().length > 10
                    && String((snap as { bottom_channel_item_id?: string }).bottom_channel_item_id).toUpperCase() !== 'NONE') ||
                  Boolean((qlInfo?.config_snapshot as { bottom_channel?: boolean } | null)?.bottom_channel) ||
                  (typeof (qlInfo?.config_snapshot as { bottom_channel_item_id?: string } | null)?.bottom_channel_item_id === 'string'
                    && String((qlInfo?.config_snapshot as { bottom_channel_item_id?: string }).bottom_channel_item_id).trim().length > 10
                    && String((qlInfo?.config_snapshot as { bottom_channel_item_id?: string }).bottom_channel_item_id).toUpperCase() !== 'NONE');
                const isDrapery = /drapery/i.test(ptNameForOpening ?? '');
                const hasHeadbox = detectHeadbox(snap) || detectHeadbox(qlInfo?.config_snapshot);
                // Fold style for full drapery curtains (track-only already carries it in the name).
                const draperyStyleLabel =
                  isDrapery && !draperyTrackDescription
                    ? formatDraperyStyleLabel({
                        productLine: productLineForDrapery,
                        styleCode: styleCodeForDrapery,
                      }) || null
                    : null;
                const openingRaw =
                  snap?.opening_direction ??
                  snap?.openingDirection ??
                  (qlInfo?.config_snapshot as { opening_direction?: string; openingDirection?: string } | null)?.opening_direction ??
                  (qlInfo?.config_snapshot as { opening_direction?: string; openingDirection?: string } | null)?.openingDirection ??
                  null;
                const openingLabel =
                  isDrapery && openingRaw
                    ? ({ left: 'Left Stack', center: 'Center Opening', right: 'Right Stack' }[openingRaw] ?? openingRaw)
                    : null;
                return (
                  <>
                  <SortableRow
                    key={line.id}
                    id={line.id}
                    renderFirstCell={({ attributes, listeners }) => (
                      <td className="py-4 pl-2 pr-0 text-gray-400 w-10 align-middle" title="Drag to reorder">
                        {!contentReadOnly ? (
                          <span
                            {...attributes}
                            {...listeners}
                            className="p-1 rounded hover:bg-gray-100 cursor-grab active:cursor-grabbing inline-flex touch-none"
                            aria-label="Drag to reorder"
                          >
                            <GripVertical className="w-4 h-4" />
                          </span>
                        ) : (
                          <span className="inline-block w-4 h-4" />
                        )}
                      </td>
                    )}
                  >
                    <td className="py-4 pl-0.5 pr-1 text-center w-11 min-w-[44px] align-middle">
                      {line.line_type === 'custom' ? (
                        !contentReadOnly ? (
                          <button
                            type="button"
                            onClick={() => openEditCustomModal(line.id)}
                            className="min-w-[44px] min-h-[44px] rounded hover:bg-gray-100 active:bg-gray-200 inline-flex items-center justify-center touch-manipulation"
                            aria-label="Edit custom item"
                            title="Edit custom item"
                          >
                            <Pencil className="w-4 h-4 text-gray-500" />
                          </button>
                        ) : (
                          <span className="inline-block w-4 h-4" />
                        )
                      ) : (
                        <button
                          type="button"
                          onClick={() => setExpandedLineId(isExpanded ? null : line.id)}
                          className="min-w-[44px] min-h-[44px] rounded hover:bg-gray-100 active:bg-gray-200 inline-flex items-center justify-center touch-manipulation"
                          aria-label={isExpanded ? 'Collapse installation options' : 'Expand installation options'}
                        >
                          {isExpanded ? <ChevronDown className="w-4 h-4 text-gray-500" /> : <ChevronRight className="w-4 h-4 text-gray-500" />}
                        </button>
                      )}
                    </td>
                    <td className="py-4 px-2 text-center text-gray-500 text-sm tabular-nums w-12 align-middle">{index + 1}</td>
                    <td className="py-4 px-4 text-gray-700 text-sm min-w-[8rem] align-middle whitespace-nowrap">
                      {line.line_type === 'from_quote'
                        ? (line.quote_line_snapshot as { area?: string } | null)?.area ?? qlInfo?.area ?? '—'
                        : (line.area ?? '—')}
                    </td>
                    <td className="py-4 pl-0.5 pr-4 text-center text-gray-700 text-sm w-24 min-w-[6rem] align-middle -ml-5">
                      {line.line_type === 'from_quote'
                        ? (line.quote_line_snapshot as { position?: string } | null)?.position ?? qlInfo?.position ?? '—'
                        : (line.position ?? '—')}
                    </td>
                    <td className="py-4 pl-[30px] pr-5 align-middle min-w-[320px] max-w-[520px]">
                      {line.line_type === 'from_quote' && qlInfo ? (
                          <div className="min-h-[3.5rem] flex flex-col justify-center gap-0.5 flex-1 min-w-0">
                            <div className="break-words">
                              <span className="font-medium text-gray-900">
                                {(() => {
                                  const ptCode = String(
                                    (line.quote_line_snapshot as { product_type?: string } | null)?.product_type
                                      ?? qlInfo.product_type
                                      ?? ''
                                  ).trim().toLowerCase();
                                  const isCatalogLine = ptCode === 'catalog';
                                  const baseName = snap?.name ?? qlInfo.name ?? qlInfo.sku ?? '—';
                                  if (isCatalogLine && qlInfo.catalog_color) {
                                    return baseName === '—' ? baseName : `${baseName} — ${qlInfo.catalog_color}`;
                                  }
                                  return draperyTrackDescription ?? baseName;
                                })()}
                              </span>
                              {(snap?.sku ?? qlInfo.sku) && (snap?.sku ?? qlInfo.sku) !== (snap?.name ?? qlInfo.name ?? qlInfo.sku) && (
                                <span className="block text-gray-500 text-xs">{snap?.sku ?? qlInfo.sku}</span>
                              )}
                            </div>
                            <div className="flex flex-col gap-0.5 mt-0.5">
                              {(() => {
                                const driveRaw = snap?.drive_type ?? qlInfo?.drive_type ?? null;
                                const driveLabel = (snap?.drive_system_label ?? qlInfo?.drive_system_label)
                                  ?? (driveRaw === 'motor' || driveRaw === 'motorized'
                                      ? 'Motorized'
                                      : driveRaw === 'manual'
                                        ? 'Manual'
                                        : null);
                                return driveLabel ? (
                                  <span className="text-xs text-gray-500">{driveLabel}</span>
                                ) : null;
                              })()}
                              {draperyStyleLabel ? <span className="text-xs text-gray-500">Style: {draperyStyleLabel}</span> : null}
                              {hasSideChannel ? <span className="text-xs text-gray-500">Side Channel: Yes</span> : null}
                              {hasBottomChannel ? <span className="text-xs text-gray-500">Bottom Channel: Yes</span> : null}
                              {hasHeadbox ? <span className="text-xs text-gray-500">Headbox: Yes</span> : null}
                              {openingLabel ? <span className="text-xs text-gray-500">{openingLabel}</span> : null}
                              {dimsMm && dimsMm !== '—' && <span className="text-xs text-gray-500 whitespace-pre-line">{dimsMm}</span>}
                              {isInstallIncluded ? (
                                <span className="inline-flex items-center w-fit px-1.5 py-0.5 rounded-full text-xs font-medium bg-green-50 text-status-green">
                                  Install Included
                                </span>
                              ) : null}
                            </div>
                          </div>
                        ) : (
                          <button
                            type="button"
                            onClick={() => {
                              if (!contentReadOnly) openEditCustomModal(line.id);
                            }}
                            className={`flex flex-col gap-0.5 flex-1 min-w-0 text-left ${!contentReadOnly ? 'hover:opacity-80' : ''}`}
                            disabled={contentReadOnly}
                          >
                            <span className="text-sm text-gray-900">{line.description || '—'}</span>
                            <span className="text-xs text-gray-500">
                              {CUSTOM_CATEGORIES.find((o) => o.value === (line.custom_category ?? 'other'))?.label ?? 'Other'}
                            </span>
                            {line.custom_category === MADE_TO_MEASURE_CATEGORY && line.width_m != null && line.height_m != null && (
                              <span className="text-xs text-gray-500">
                                {Math.round(Number(line.width_m) * 1000)} × {Math.round(Number(line.height_m) * 1000)}
                                {line.drive_type === 'motor' ? ' · Motorized' : line.drive_type === 'manual' ? ' · Manual' : ''}
                              </span>
                            )}
                          </button>
                        )}
                    </td>
                    <td className="py-4 px-2 text-gray-700 text-sm align-middle min-w-[120px]">
                      {line.line_type === 'from_quote'
                        ? (() => {
                            const ptRaw = (line.quote_line_snapshot as { product_type?: string } | null)?.product_type ?? qlInfo?.product_type ?? null;
                            const ptName = (qlInfo?.product_type_id && productTypeNameByCodeOrId.byId.get(qlInfo.product_type_id)) ?? (ptRaw && productTypeNameByCodeOrId.byCode.get(ptRaw.trim().toLowerCase())) ?? ptRaw;
                            return ptName ?? '—';
                          })()
                        : (
                          <span className="text-gray-700">
                            {CUSTOM_CATEGORIES.find((o) => o.value === (line.custom_category ?? 'other'))?.label ?? 'Other'}
                          </span>
                        )}
                    </td>
                    <td className="py-4 px-1.5 text-center align-middle min-w-[64px] w-[64px] tabular-nums">
                      {line.line_type === 'custom' ? (
                        <span className="text-sm text-gray-900">{line.qty === 0 ? '—' : Number(line.qty)}</span>
                      ) : (
                        qlInfo?.quantity ?? '—'
                      )}
                    </td>
                    <td className="w-[16px] min-w-[16px] py-4 align-middle">
                      {line.line_type === 'custom' && !contentReadOnly ? (
                        <button
                          type="button"
                          onClick={() => removeCustomLine(line.id)}
                          className="inline-flex items-center justify-center rounded p-1 text-red-600 hover:bg-red-50"
                          title="Delete custom line"
                          aria-label="Delete custom line"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      ) : (
                        <span className="inline-block w-4 h-4" aria-hidden />
                      )}
                    </td>
                    <td className="py-4 pl-2 pr-2 text-right align-middle w-[108px] max-w-[108px] whitespace-nowrap tabular-nums">
                      {line.line_type === 'custom' ? (
                        <span className="text-sm text-gray-900" title={`Unit: ${formatCurrency(Number(line.unit_price) ?? 0, currency)}`}>
                          {formatCurrency(Number(line.unit_price) ?? 0, currency)}
                        </span>
                      ) : (
                        <span>
                          {hasBasePrice ? (
                            formatCurrency(unitPriceForDisplay, currency)
                          ) : (
                            <span className="inline-flex items-center gap-1">
                              <span>—</span>
                              <Tooltip content="Base price missing on QuoteLine" side="top">
                                <AlertTriangle className="w-4 h-4 text-amber-500 flex-shrink-0" aria-hidden />
                              </Tooltip>
                            </span>
                          )}
                        </span>
                      )}
                    </td>
                    <td className="py-4 pl-2 pr-5 text-right font-medium text-gray-900 text-sm align-middle min-w-[108px] whitespace-nowrap tabular-nums">{formatCurrency(lineTotal, currency)}</td>
                  </SortableRow>
                  {line.line_type === 'from_quote' && isExpanded && (
                    <tr key={`${line.id}-addons`} className="bg-gray-50/80">
                      <td colSpan={11} className="py-4 px-6">
                        <div className="rounded-lg border border-gray-200 bg-white p-4 space-y-4">
                          <div>
                            <h4 className="text-sm font-semibold text-gray-700 mb-2">Installation</h4>
                            <div className="flex flex-wrap items-center gap-4">
                              <label className="flex items-center gap-2 cursor-pointer">
                                <input
                                  type="checkbox"
                                  checked={hasInstallationAddon}
                                  onChange={(e) => {
                                    if (contentReadOnly) return;
                                    if (e.target.checked) {
                                      upsertAddOn(line.id, { addon_type: 'installation', cost_amount: 0, markup_pct: installationAddon?.markup_pct ?? 100, pricing_mode: 'markup_pct' });
                                    } else {
                                      const inst = (displayAddonsMap?.get(line.id) || []).find((a) => a.addon_type === 'installation');
                                      if (inst) removeAddOn(inst.id);
                                    }
                                  }}
                                  disabled={contentReadOnly}
                                  className="rounded border-gray-300"
                                />
                                <span className="text-sm text-gray-700">Install Included</span>
                              </label>
                              {hasInstallationAddon && (
                                <>
                                  <div>
                                    <Label className="text-xs">Cost</Label>
                                    <Input
                                      type="number"
                                      step="0.01"
                                      min="0"
                                      className="w-24"
                                      value={installationFieldDraft[line.id]?.cost ?? (installationAddon.cost_amount != null ? String(installationAddon.cost_amount) : '')}
                                      onChange={(e) => {
                                        const raw = e.target.value;
                                        setInstallationFieldDraft((prev) => ({
                                          ...prev,
                                          [line.id]: { ...prev[line.id], cost: raw },
                                        }));
                                        if (raw === '') return;
                                        const cost = Math.max(0, parseFloat(raw) || 0);
                                        upsertAddOn(line.id, {
                                          addon_type: 'installation',
                                          cost_amount: cost,
                                          markup_pct: installationAddon.markup_pct ?? 100,
                                          pricing_mode: 'markup_pct',
                                        });
                                      }}
                                      onBlur={() => {
                                        const raw = installationFieldDraft[line.id]?.cost;
                                        if (raw == null) return;
                                        const cost = raw === '' ? 0 : Math.max(0, parseFloat(raw) || 0);
                                        upsertAddOn(line.id, {
                                          addon_type: 'installation',
                                          cost_amount: cost,
                                          markup_pct: installationAddon.markup_pct ?? 100,
                                          pricing_mode: 'markup_pct',
                                        });
                                        setInstallationFieldDraft((prev) => ({
                                          ...prev,
                                          [line.id]: { ...prev[line.id], cost: undefined },
                                        }));
                                      }}
                                      disabled={contentReadOnly}
                                    />
                                  </div>
                                  <div>
                                    <Label className="text-xs">Markup %</Label>
                                    <Input
                                      type="number"
                                      step="0.01"
                                      min="0"
                                      className="w-20"
                                      value={installationFieldDraft[line.id]?.markup ?? (installationAddon.markup_pct != null ? String(installationAddon.markup_pct) : '')}
                                      onChange={(e) => {
                                        const raw = e.target.value;
                                        setInstallationFieldDraft((prev) => ({
                                          ...prev,
                                          [line.id]: { ...prev[line.id], markup: raw },
                                        }));
                                        if (raw === '') return;
                                        const markup = Math.max(0, parseFloat(raw) || 0);
                                        upsertAddOn(line.id, {
                                          addon_type: 'installation',
                                          cost_amount: installationAddon.cost_amount ?? 0,
                                          markup_pct: markup,
                                          pricing_mode: 'markup_pct',
                                        });
                                      }}
                                      onBlur={() => {
                                        const raw = installationFieldDraft[line.id]?.markup;
                                        if (raw == null) return;
                                        const markup = raw === '' ? 0 : Math.max(0, parseFloat(raw) || 0);
                                        upsertAddOn(line.id, {
                                          addon_type: 'installation',
                                          cost_amount: installationAddon.cost_amount ?? 0,
                                          markup_pct: markup,
                                          pricing_mode: 'markup_pct',
                                        });
                                        setInstallationFieldDraft((prev) => ({
                                          ...prev,
                                          [line.id]: { ...prev[line.id], markup: undefined },
                                        }));
                                      }}
                                      disabled={contentReadOnly}
                                    />
                                  </div>
                                  <span className="text-xs text-gray-500 self-end pb-2">
                                    Sale: {formatCurrency(Number(installationAddon.sale_amount) || 0, currency)}
                                  </span>
                                </>
                              )}
                            </div>
                          </div>
                          <h4 className="text-sm font-semibold text-gray-700 mb-3">Line Adjustments</h4>
                          <div className="flex flex-wrap items-end gap-4">
                            <div>
                                <Label className="text-xs">Discount %</Label>
                                <Input
                                  key={`disc-${line.id}-${line.line_adjustment_pct ?? 0}`}
                                  type="number"
                                  step="0.01"
                                  min="0"
                                  max="100"
                                  className="w-20"
                                  defaultValue={String((line.line_adjustment_pct ?? 0) < 0 ? -(line.line_adjustment_pct ?? 0) : 0)}
                                  onBlur={(e) => {
                                    const disc = Math.max(0, Math.min(100, parseFloat(e.target.value) || 0));
                                    const fee = (line.line_adjustment_pct ?? 0) > 0 ? (line.line_adjustment_pct ?? 0) : 0;
                                    updateLineAdjustment(line.id, fee - disc);
                                  }}
                                  disabled={contentReadOnly}
                                  placeholder="0"
                                />
                              </div>
                              <div>
                                <Label className="text-xs">Fee %</Label>
                                <Input
                                  key={`fee-${line.id}-${line.line_adjustment_pct ?? 0}`}
                                  type="number"
                                  step="0.01"
                                  min="0"
                                  max="100"
                                  className="w-20"
                                  defaultValue={String((line.line_adjustment_pct ?? 0) > 0 ? (line.line_adjustment_pct ?? 0) : 0)}
                                  onBlur={(e) => {
                                    const fee = Math.max(0, Math.min(100, parseFloat(e.target.value) || 0));
                                    const disc = (line.line_adjustment_pct ?? 0) < 0 ? -(line.line_adjustment_pct ?? 0) : 0;
                                    updateLineAdjustment(line.id, fee - disc);
                                  }}
                                  disabled={contentReadOnly}
                                  placeholder="0"
                                />
                              </div>
                              {baseAmount > 0 && (
                                <div>
                                  <Label className="text-xs">Adjusted Price</Label>
                                  <Input
                                    key={`adj-${line.id}-${line.line_adjustment_pct ?? 0}`}
                                    type="number"
                                    step="0.01"
                                    min="0"
                                    className="w-28"
                                    defaultValue={String(Math.round(lineTotal * 100) / 100)}
                                    onBlur={(e) => {
                                      const target = parseFloat(e.target.value);
                                      if (Number.isNaN(target) || target < 0 || baseAmount <= 0) return;
                                      const pct = Math.round(((target / baseAmount) - 1) * 1000000) / 10000;
                                      updateLineAdjustment(line.id, Math.max(-100, Math.min(100, pct)));
                                    }}
                                    disabled={contentReadOnly}
                                    placeholder={formatCurrency(lineTotal, currency)}
                                  />
                                </div>
                              )}
                              {((line.line_adjustment_pct ?? 0) !== 0) && (
                                <span className="text-xs text-gray-500 self-center">
                                  Base: {formatCurrency(baseAmount, currency)}
                                </span>
                              )}
                          </div>
                        </div>
                      </td>
                    </tr>
                  )}
                  </>
                );
              })}
                </SortableContext>
              </DndContext>
            </tbody>
          </table>
        </div>
        )}
      </div>

      {totalZeroWithFromQuote && (
        <div className="mb-4 p-3 bg-amber-50 border border-amber-200 rounded-lg flex items-center gap-2 text-amber-800 text-sm">
          <AlertTriangle className="w-5 h-5 flex-shrink-0" />
          <span>Some lines have no base price. Check QuoteLine MSRP / unit MSRP on the Quote.</span>
        </div>
      )}

          {/* Notes (left) + Summary (right) - in Overview */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-stretch">
            <div className="lg:col-span-2 min-w-0 bg-white border border-gray-200 rounded-lg p-6">
              <h3 className="text-sm font-semibold text-gray-700 mb-3">Notes</h3>
              <textarea
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm min-h-[120px]"
                rows={4}
                value={headerForm.notes}
                onChange={(e) => { setHeaderForm((f) => ({ ...f, notes: e.target.value })); setHeaderDirty(true); }}
                disabled={contentReadOnly}
                placeholder="Additional notes or comments..."
              />
            </div>
            <div className="bg-white border border-gray-200 rounded-lg p-6 w-full lg:col-span-1 shrink-0 self-start">
              <div className="flex items-center gap-2 pb-3 mb-3 border-b border-gray-100">
                <input
                  type="checkbox"
                  checked={headerForm.exempt_tax}
                  onChange={(e) => { setHeaderForm((f) => ({ ...f, exempt_tax: e.target.checked })); setHeaderDirty(true); }}
                  disabled={contentReadOnly}
                />
                <Label className="text-sm text-gray-700 cursor-pointer">Exempt Tax</Label>
              </div>
              <div className="flex justify-between py-1 text-sm">
                <span className="text-gray-600">Total Product</span>
                <span>{formatCurrency(summary.totalProduct ?? 0, currency)}</span>
              </div>
              {(summary.discountAmount ?? 0) > 0 && (
                <div className="flex justify-between py-1 text-sm">
                  <span className="text-gray-600">Discount {summary.discountPct ? `(${summary.discountPct}%)` : ''}</span>
                  <span>-{formatCurrency(summary.discountAmount ?? 0, currency)}</span>
                </div>
              )}
              {(summary.installationTotal ?? summary.installationAmount ?? 0) > 0 && (
                <>
                  {(summary.laborDiscountAmount ?? 0) > 0 ? (
                    <>
                      <div className="flex justify-between py-1 text-sm">
                        <span className="text-gray-600">Installation</span>
                        <span>{formatCurrency(summary.installationTotal ?? 0, currency)}</span>
                      </div>
                      <div className="flex justify-between py-1 text-sm">
                        <span className="text-gray-600">Labor discount {summary.instDiscountPct ? `(${summary.instDiscountPct}%)` : ''}</span>
                        <span>-{formatCurrency(summary.laborDiscountAmount ?? 0, currency)}</span>
                      </div>
                      <div className="flex justify-between py-1 text-sm font-medium">
                        <span className="text-gray-700">Installation (net)</span>
                        <span>{formatCurrency(summary.installationNet ?? 0, currency)}</span>
                      </div>
                    </>
                  ) : (
                    <div className="flex justify-between py-1 text-sm">
                      <span className="text-gray-600">Installation</span>
                      <span>{formatCurrency(summary.installationNet ?? summary.installationAmount ?? 0, currency)}</span>
                    </div>
                  )}
                </>
              )}
              <div className="flex justify-between py-1 text-sm">
                <span className="text-gray-600">Subtotal</span>
                <span>{formatCurrency(summary.subtotal ?? 0, currency)}</span>
              </div>
              {!headerForm.exempt_tax && (
                <div className="flex justify-between py-1 text-sm">
                  <span className="text-gray-600">Tax</span>
                  <span>{formatCurrency(summary.taxAmount ?? 0, currency)}</span>
                </div>
              )}
              <div className="flex justify-between py-2 mt-2 border-t border-gray-200 font-semibold">
                <span>Total {currency ? `(${currency})` : ''}</span>
                <span>{formatCurrency(summary.total, currency)}</span>
              </div>
            </div>
          </div>

          {/* Terms & Conditions - in Overview */}
          <div>
            <DocumentTermsSection
              docType="proposal"
              orgId={activeOrganizationId}
              dealerId={proposal?.dealer_id ?? null}
              termsTitle={headerForm.terms_title}
              termsContent={headerForm.terms_content}
              onTermsChange={(title, content) => {
                setHeaderForm((f) => ({ ...f, terms_title: title, terms_content: content }));
                setHeaderDirty(true);
              }}
              readOnly={contentReadOnly}
              hideSaveAsTemplate
              hideTitleInput
            />
          </div>
        </div>
      )}

      {activeTab === 'profitability' && proposal && (
        <ProposalProfitabilityTab
          lines={displayLines}
          quoteLinesMap={quoteLinesMap}
          addonsMap={displayAddonsMap}
          lineTotals={totals.lineTotals}
          globalDiscountPct={totals.discountPct}
          globalDiscountAmount={totals.discountAmount}
          globalFeePct={totals.globalFeePct}
          installationDiscountPct={totals.instDiscountPct ?? 0}
          installationDiscountAmount={totals.laborDiscountAmount ?? 0}
          installationFeePct={totals.instFeePct ?? 0}
          totalProduct={totals.totalProduct}
          installationTotal={totals.installationTotal ?? totals.installationAmount ?? 0}
          subtotal={totals.subtotal}
          taxAmount={totals.taxAmount}
          total={totals.total}
          currency={currency}
        />
      )}

      {activeTab === 'timeline' && (
        <TimelineView events={timeline} loading={loading && timeline.length === 0} emptyMessage="No activity yet" />
      )}

      {/* Custom Item modal — same layout as Quote Custom Item (incl. MTM) */}
      {customModalDraft && (() => {
        const d = customModalDraft;
        const isNew = d.id.startsWith('temp-') && !draftLines.some((l) => l.id === d.id);
        const isMTM = d.category === MADE_TO_MEASURE_CATEGORY;
        const previewTotal = (Number(d.unit_price) || 0) * Math.max(1, Number(d.qty) || 1);
        const set = (fields: Partial<CustomItemModalDraft>) => updateCustomModalDraft(fields);
        const selectablePts = productTypes.filter((pt) => String(pt.code || '').toLowerCase() !== 'service');
        return (
          <div className="fixed inset-0 bg-black bg-opacity-40 z-50 flex items-center justify-center p-6">
            <div className="bg-white rounded-lg shadow-xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
              <div className="flex items-center justify-between px-6 py-5 border-b">
                <h3 className="text-base font-semibold text-gray-900">{isNew ? 'New Custom Item' : 'Edit Custom Item'}</h3>
                <button type="button" onClick={closeCustomModal} className="p-1 hover:bg-gray-100 rounded">
                  <X className="w-4 h-4" />
                </button>
              </div>

              <div className="px-6 py-5 space-y-5">
                <div>
                  <Label className="text-xs text-gray-600 mb-1.5">Type</Label>
                  <SelectShadcn value={d.category} onValueChange={(v) => set({ category: v as ProposalCustomCategory })}>
                    <SelectTrigger className="!h-10 !rounded-md !border-gray-300">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent className="!rounded-md">
                      {CUSTOM_CATEGORIES.map((c) => (
                        <SelectItem key={c.value} value={c.value}>{c.label}</SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                  {isMTM && (
                    <p className="mt-1.5 text-[11px] text-amber-600">
                      Made-to-measure items require dimensions (width × height).
                    </p>
                  )}
                </div>

                {isMTM && (
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <Label className="text-xs text-gray-600 mb-1.5">Product Type</Label>
                      <SelectShadcn value={d.product_type_id || ''} onValueChange={(v) => set({ product_type_id: v })}>
                        <SelectTrigger className="!h-10 !rounded-md !border-gray-300">
                          <SelectValue placeholder="Select…" />
                        </SelectTrigger>
                        <SelectContent className="!rounded-md">
                          {selectablePts.map((pt) => (
                            <SelectItem key={pt.id} value={pt.id}>{pt.name}</SelectItem>
                          ))}
                        </SelectContent>
                      </SelectShadcn>
                    </div>
                    <div>
                      <Label className="text-xs text-gray-600 mb-1.5">System Drive</Label>
                      <SelectShadcn value={d.drive || ''} onValueChange={(v) => set({ drive: v })}>
                        <SelectTrigger className="!h-10 !rounded-md !border-gray-300">
                          <SelectValue placeholder="Select…" />
                        </SelectTrigger>
                        <SelectContent className="!rounded-md">
                          <SelectItem value="manual">Manual</SelectItem>
                          <SelectItem value="motor">Motorized</SelectItem>
                        </SelectContent>
                      </SelectShadcn>
                    </div>
                  </div>
                )}

                <div>
                  <Label className="text-xs text-gray-600 mb-1.5">Description <span className="text-red-500">*</span></Label>
                  <Input
                    autoFocus
                    value={d.name}
                    onChange={(e) => set({ name: e.target.value })}
                    placeholder={
                      d.category === 'shipping' ? 'e.g. Freight to site'
                        : d.category === 'installation' ? 'e.g. On-site installation'
                        : d.category === 'delivery' ? 'e.g. Local delivery'
                        : d.category === 'product' ? 'e.g. Motor remote control'
                        : isMTM ? 'e.g. Custom blackout panel'
                        : d.category === 'service' ? 'e.g. Design service'
                        : 'e.g. Custom line item'
                    }
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <Label className="text-xs text-gray-600 mb-1.5">Area</Label>
                    <Input value={d.area} onChange={(e) => set({ area: e.target.value })} placeholder="Optional" />
                  </div>
                  <div>
                    <Label className="text-xs text-gray-600 mb-1.5">Position</Label>
                    <Input value={d.position} onChange={(e) => set({ position: e.target.value })} placeholder="Optional" />
                  </div>
                </div>

                {isMTM && (
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <Label className="text-xs text-gray-600 mb-1.5">Width (mm)</Label>
                      <Input
                        inputMode="decimal"
                        value={d.width_mm}
                        onChange={(e) => set({ width_mm: e.target.value.replace(/[^0-9.]/g, '') })}
                        placeholder="e.g. 1000"
                      />
                    </div>
                    <div>
                      <Label className="text-xs text-gray-600 mb-1.5">Height (mm)</Label>
                      <Input
                        inputMode="decimal"
                        value={d.height_mm}
                        onChange={(e) => set({ height_mm: e.target.value.replace(/[^0-9.]/g, '') })}
                        placeholder="e.g. 2000"
                      />
                    </div>
                  </div>
                )}

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <Label className="text-xs text-gray-600 mb-1.5">Quantity</Label>
                    <Input
                      inputMode="numeric"
                      value={d.qty}
                      onChange={(e) => set({ qty: e.target.value.replace(/[^0-9]/g, '') })}
                      onBlur={(e) => { if (!e.target.value || Number(e.target.value) < 1) set({ qty: '1' }); }}
                    />
                  </div>
                  <div>
                    <Label className="text-xs text-gray-600 mb-1.5">Unit price ($)</Label>
                    <Input
                      inputMode="decimal"
                      value={d.unit_price}
                      onChange={(e) => set({ unit_price: e.target.value.replace(/[^0-9.]/g, '') })}
                      placeholder="0.00"
                    />
                  </div>
                </div>

                <div className="rounded-md border border-gray-200 bg-gray-50/60 p-4">
                  <p className="text-[11px] font-medium text-gray-500 mb-3">Internal — not shown to the customer</p>
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <Label className="text-xs text-gray-600 mb-1.5">Cost ($)</Label>
                      <Input
                        inputMode="decimal"
                        value={d.unit_cost}
                        onChange={(e) => set({ unit_cost: e.target.value.replace(/[^0-9.]/g, '') })}
                        placeholder="0.00"
                      />
                    </div>
                    <div>
                      <Label className="text-xs text-gray-600 mb-1.5">Markup %</Label>
                      <Input
                        inputMode="decimal"
                        value={d.markup_pct}
                        onChange={(e) => set({ markup_pct: e.target.value.replace(/[^0-9.\-]/g, '') })}
                        placeholder="e.g. 30"
                      />
                    </div>
                  </div>
                </div>

                <div className="flex items-center justify-between pt-1 border-t border-gray-100">
                  <span className="text-sm text-gray-500">Line total</span>
                  <span className="text-lg font-semibold text-gray-900 tabular-nums">{formatCurrency(previewTotal, currency)}</span>
                </div>
              </div>

              <div className="flex items-center justify-end gap-2 px-6 py-4 border-t bg-gray-50">
                <button
                  type="button"
                  onClick={closeCustomModal}
                  className="px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100 rounded-md transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={commitCustomModal}
                  disabled={!d.name.trim() || (isMTM && (!Number(d.width_mm) || !Number(d.height_mm)))}
                  className="px-4 py-2 text-sm font-medium text-white bg-primary hover:bg-primary/90 rounded-md transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  title={isMTM && (!Number(d.width_mm) || !Number(d.height_mm)) ? 'Enter width and height' : undefined}
                >
                  {isNew ? 'Add Item' : 'Save Changes'}
                </button>
              </div>
            </div>
          </div>
        );
      })()}
    </DetailPageLayout>
  );
}
