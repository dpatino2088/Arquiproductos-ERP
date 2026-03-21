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
import { useProposalDetail } from '../../hooks/useProposals';
import type { Proposal, ProposalLine, ProposalCustomCategory, ProposalLineAddOn, ProposalLineAddOnPricingMode } from '../../types/proposals';
import { generateProposalPDF, type ProposalPDFLine } from '../../lib/pdf/generateProposalPDF';
import { formatDimensionsForProposalPDF } from '../../lib/formatDimensions';
import { getLogoPathFromUrl } from '../../lib/dealerLogo';
import { useResolvedStorageUrl } from '../../hooks/useResolvedStorageUrl';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import { ChevronDown, ChevronRight, GripVertical, Plus, AlertTriangle, Printer, Eye, ArrowLeft } from 'lucide-react';
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
import { getAppUsersDisplayNames } from '../../lib/appUsersDisplayNames';

const PROPOSAL_STATUS_OPTIONS: { value: Proposal['status']; label: string }[] = [
  { value: 'draft', label: 'Draft' },
  { value: 'sent', label: 'Sent' },
  { value: 'accepted', label: 'Accepted' },
  { value: 'rejected', label: 'Rejected' },
  { value: 'cancelled', label: 'Cancelled' },
];

const CUSTOM_CATEGORIES: { value: ProposalCustomCategory; label: string }[] = [
  { value: 'installation', label: 'Installation' },
  { value: 'delivery', label: 'Delivery' },
  { value: 'service', label: 'Service' },
  { value: 'other', label: 'Other' },
];

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
  proposalStatus?: string
): number {
  if (line.line_type === 'custom') {
    const qty = Number(line.qty) || 0;
    const up = Number(line.unit_price) || 0;
    return qty * up;
  }
  if (line.line_type === 'from_quote') {
    let base = 0;
    if (proposalStatus && (proposalStatus === 'sent' || proposalStatus === 'accepted') && line.quote_line_snapshot && (line.quote_line_snapshot as { base_line_msrp?: number }).base_line_msrp != null) {
      base = (line.quote_line_snapshot as { base_line_msrp: number }).base_line_msrp;
    } else if (quoteLineInfo) {
      base = getQuoteLineBase(quoteLineInfo);
    }
    const adj = Number(line.line_adjustment_pct) || 0;
    return base * (1 + adj / 100);
  }
  return 0;
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
  const [linesDirty, setLinesDirty] = useState(false);
  const [addonsDirty, setAddonsDirty] = useState(false);
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
    }
  }, [proposal, loading, lines, addonsMap, linesDirty, addonsDirty]);
  const displayLines = draftLines;
  const displayAddonsMap = draftAddonsMap;
  type AddonDraft = { cost_amount: number; markup_pct: number; sale_amount: number; pricing_mode: ProposalLineAddOnPricingMode; taxable: boolean };
  const [addonDraft, setAddonDraft] = useState<Record<string, AddonDraft>>({});
  const addonDraftRef = useRef<Record<string, AddonDraft>>({});
  addonDraftRef.current = addonDraft;

  const [saving, setSaving] = useState(false);
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
  });

  const [showAdjSubtotal, setShowAdjSubtotal] = useState(false);
  const [showAdjTotal, setShowAdjTotal] = useState(false);

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
    });
  }, [proposal]);

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
      };
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
    if (!headerDirty && !linesDirty && !addonsDirty) {
      return;
    }
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
            const insertPayload: Record<string, unknown> = {
              organization_id: proposal.organization_id,
              dealer_id: proposal.dealer_id,
              proposal_id: proposal.id,
              line_type: 'custom',
              override_mode: overrideMode,
              area: line.area?.trim() || null,
              position: line.position?.trim() || null,
              description: line.description ?? 'New line',
              qty: line.qty ?? 1,
              unit_cost: line.unit_cost ?? null,
              unit_price: line.unit_price ?? 0,
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
      setSaving(false);
    }
  }, [proposal, canWrite, headerDirty, linesDirty, addonsDirty, draftLines, draftAddonsMap, addonsMap, saveHeader, refetch, setCanWrite, headerForm.status, authUser, refetchTimeline]);

  const handleSaveAndClose = useCallback(async () => {
    await handleSave();
    navigateBackContextual(router, {
      queryReturnTo: getReturnToFromCurrentQuery(),
      fallback: '/sales/proposals',
    });
  }, [handleSave]);

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

  const updateCustomLine = useCallback(
    (lineId: string, fields: {
      description?: string;
      custom_category?: ProposalCustomCategory | null;
      qty?: number;
      unit_price?: number;
      area?: string | null;
      position?: string | null;
      unit_cost?: number | null;
      markup_pct?: number | null;
    }) => {
      if (!canWrite) return;
      setDraftLines((prev) =>
        prev.map((l) => {
          if (l.id !== lineId) return l;
          const next = { ...l, ...fields };
          if (next.line_type === 'custom' && (fields.unit_cost !== undefined || fields.markup_pct !== undefined)) {
            const cost = Number(fields.unit_cost !== undefined ? fields.unit_cost : (l.unit_cost ?? 0)) || 0;
            const markup = fields.markup_pct !== undefined ? fields.markup_pct : (l.markup_pct ?? 0);
            next.unit_price = cost * (1 + (Number(markup) || 0) / 100);
          }
          return next;
        })
      );
      setLinesDirty(true);
    },
    [canWrite]
  );

  const addCustomLine = useCallback(() => {
    if (!proposal || !canWrite) return;
    const newLine: ProposalLine = {
      id: `temp-${Date.now()}`,
      organization_id: proposal.organization_id,
      dealer_id: proposal.dealer_id,
      proposal_id: proposal.id,
      quote_line_id: null,
      line_type: 'custom',
      override_mode: 'inherit',
      discount_pct: null,
      markup_pct: null,
      fixed_unit_price: null,
      fixed_line_total: null,
      custom_category: 'other',
      area: null,
      position: null,
      description: 'New line',
      qty: 1,
      uom: null,
      unit_price: 0,
      unit_cost: null,
      line_total: 0,
      line_adjustment_pct: null,
      sort_order: displayLines.length,
      deleted: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    setDraftLines((prev) => [...prev, newLine]);
    setLinesDirty(true);
  }, [proposal, canWrite, displayLines.length]);

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
      const saleAmount = addon.pricing_mode === 'fixed_price' && addon.sale_amount != null
        ? addon.sale_amount
        : (addon.cost_amount ?? 0) * (1 + ((addon.markup_pct ?? 0) / 100));
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
    // Read percentages from headerForm (live); '0' and '' both parse to 0
    const discountPct = headerForm.global_discount_pct !== '' ? parseFloat(headerForm.global_discount_pct) || 0 : 0;
    const globalFeePct = headerForm.global_fee_amount !== '' ? parseFloat(headerForm.global_fee_amount) || 0 : 0;
    const instDiscountPct = headerForm.global_installation_discount_pct !== '' ? parseFloat(headerForm.global_installation_discount_pct) || 0 : 0;
    const instFeePct = headerForm.global_installation_fee_pct !== '' ? parseFloat(headerForm.global_installation_fee_pct) || 0 : 0;

    const feeMul = 1 + ((Number.isNaN(globalFeePct) ? 0 : globalFeePct) / 100);
    const instFeeMul = 1 + ((Number.isNaN(instFeePct) ? 0 : instFeePct) / 100);

    // Fee is baked into each line total so Unit Price & Line Total reflect it
    const lineTotals: number[] = [];
    let totalProduct = 0;
    let installationTotal = 0;
    displayLines.forEach((line) => {
      const qlInfo = line.quote_line_id ? quoteLinesMap.get(line.quote_line_id) : undefined;
      const rawMaterial = computeLineTotal(line, qlInfo, proposal?.status);
      const material = rawMaterial * feeMul;
      lineTotals.push(material);
      totalProduct += material;
      const installationAddons = (displayAddonsMap?.get(line.id) || []).filter((a) => a.addon_type === 'installation');
      const rawInstall = installationAddons.reduce((s, a) => s + (Number(a.sale_amount) || 0), 0);
      installationTotal += rawInstall * instFeeMul;
    });

    // Discount applies to fee-inclusive Total Product
    const discountAmount = Number.isNaN(discountPct) ? 0 : totalProduct * (discountPct / 100);
    const afterDiscount = Math.max(totalProduct - discountAmount, 0);

    // Labor Discount applies to fee-inclusive Installation
    const laborDiscountAmount = Number.isNaN(instDiscountPct) ? 0 : installationTotal * (instDiscountPct / 100);
    const installationNet = installationTotal - laborDiscountAmount;

    const subtotal = afterDiscount + installationNet;

    const exemptTax = headerForm.exempt_tax;
    const taxPct = proposal?.tax_pct ?? 0.07;
    const taxAmount = exemptTax ? 0 : subtotal * taxPct;
    const total = subtotal + taxAmount;

    return {
      totalProduct,
      discountPct,
      discountAmount,
      globalFeePct,
      installationTotal,
      laborDiscountAmount,
      installationAmount: installationTotal,
      installationNet,
      subtotal,
      taxAmount,
      total,
      lineTotals,
      instDiscountPct,
      instFeePct,
    };
  }, [displayLines, quoteLinesMap, displayAddonsMap, proposal?.status, proposal?.global_discount_pct, proposal?.global_fee_amount, proposal?.global_installation_discount_pct, proposal?.global_installation_fee_pct, proposal?.tax_pct, headerForm.global_discount_pct, headerForm.global_fee_amount, headerForm.global_installation_discount_pct, headerForm.global_installation_fee_pct, headerForm.exempt_tax]);

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
        return {
          area: snapFrozen?.area ?? qlInfo?.area ?? null,
          position: snapFrozen?.position ?? qlInfo?.position ?? null,
          product_type: productTypeName ?? null,
          collection_name: snapFrozen?.collection_name ?? qlInfo?.collection_name ?? null,
          variant_name: snapFrozen?.variant_name ?? qlInfo?.variant_name ?? null,
          drive_type: snapFrozen?.drive_type ?? qlInfo?.drive_type ?? null,
          drive_system_label: snapFrozen?.drive_system_label ?? qlInfo?.drive_system_label ?? null,
          description: snapFrozen?.name || snapFrozen?.sku || qlInfo?.name || qlInfo?.sku || null,
          sku: snapFrozen?.sku ?? qlInfo?.sku ?? null,
          dimensions: dimensions ?? null,
          panel_count,
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
          customerAddress: customer?.address ?? undefined,
          customerEmail: contact?.contact_email ?? customer?.customer_email ?? undefined,
          customerPhone: customer?.customer_phone ?? undefined,
          overrideTotals: {
            totalProduct: totals.totalProduct ?? 0,
            discountAmount: totals.discountAmount ?? 0,
            installationAmount: totals.installationAmount ?? 0,
            subtotal: totals.subtotal ?? 0,
            taxAmount: totals.taxAmount ?? 0,
            total: totals.total ?? 0,
          },
          global_discount_pct: proposal.global_discount_pct ?? undefined,
          tax_pct: proposal.tax_pct ?? undefined,
          exempt_tax: proposal.exempt_tax ?? undefined,
        }
      );

      const proposalNoRaw = proposal.proposal_no || proposal.id.slice(0, 8);
      const proposalNo = String(proposalNoRaw).replace(/[.\-]/g, '_');
      const dateYmd = proposal.created_at ? new Date(proposal.created_at).toISOString().slice(0, 10).replace(/-/g, '') : new Date().toISOString().slice(0, 10).replace(/-/g, '');
      const customerPart = (customer?.customer_name ?? 'Customer')
        .replace(/\s+/g, '_')
        .replace(/[\\/:*?"<>|]/g, '')
        .slice(0, 80) || 'Customer';
      const fileName = `${proposalNo}_${dateYmd}_${customerPart}.PDF`;
      return { doc, fileName };
    },
    [proposal, proposalId, displayLines, quoteLinesMap, configuredProductsMap, customer, contact, totals, formatAccessoriesForPDF, dealerLogoUrl, headerForm]
  );

  const handlePreviewPDF = useCallback(
    async (variant: 'internal' | 'customer') => {
      try {
        const result = await buildProposalPDFDoc(variant);
        if (result) {
          const blob = result.doc.output('blob');
          const url = URL.createObjectURL(blob);
          window.open(url, '_blank');
          setTimeout(() => URL.revokeObjectURL(url), 60000);
          useUIStore.getState().addNotification({
            type: 'success',
            title: 'Preview',
            message: `PDF abierto en nueva pestaña (${result.fileName}). Descárgalo desde el botón de descarga del navegador cuando quieras.`,
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
  const canRevertStatus = isAccepted && userType === 'portal' && portalRole === 'dealer_manager';
  const contentReadOnly = readOnly || !!isAccepted;
  const statusDropdownDisabled = contentReadOnly && !canRevertStatus;

  const contactDisplay = contact
    ? [contact.contact_name, contact.contact_email].filter(Boolean).join(' · ')
    : '';
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
          <ChevronDown className="w-4 h-4 shrink-0 text-gray-500" />
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
          </div>
        )}
      </div>
      {hasRedirectBack && (
        <button
          type="button"
          onClick={handleBackContextual}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
          title="Back"
        >
          <ArrowLeft className="w-4 h-4" />
          Back
        </button>
      )}
      <button
        type="button"
        onClick={handleSave}
        disabled={saving || contentReadOnly}
        className="btn-save px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
        title="Save"
      >
        {saving ? 'Saving...' : 'Save'}
      </button>
      <button
        type="button"
        onClick={handleSaveAndClose}
        disabled={saving || contentReadOnly}
        className="btn-save-close px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {saving ? 'Saving...' : 'Save and Close'}
      </button>
    </div>
  );

  const tabs = [
    { id: 'overview', label: 'Overview' },
    { id: 'timeline', label: 'Timeline' },
  ];

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
            {/* LEFT CARD: Customer Info + Proposal Details */}
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Customer Info</h3>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-gray-500">Quote</dt>
                  <dd>
                    {quote ? (
                      <button onClick={() => router.navigate(withReturnTo(`/sales/quotes/${quote.id}`))} className="text-primary hover:underline font-medium">
                        {quote.quote_no}
                      </button>
                    ) : '—'}
                  </dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Customer</dt>
                  <dd className="text-gray-900 font-medium">{customer?.customer_name ?? '—'}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Contact</dt>
                  <dd className="text-gray-900 text-right">{contactDisplay || '—'}</dd>
                </div>
                {customer?.address && (
                  <div className="border-t pt-2">
                    <dt className="text-gray-500 text-xs mb-0.5">Address</dt>
                    <dd className="text-gray-700 text-xs whitespace-pre-line">{customer.address}</dd>
                  </div>
                )}
                {(contact?.contact_email || customer?.customer_email) && (
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Email</dt>
                    <dd className="text-gray-900">{contact?.contact_email ?? customer?.customer_email}</dd>
                  </div>
                )}
                {customer?.customer_phone && (
                  <div className="flex justify-between">
                    <dt className="text-gray-500">Phone</dt>
                    <dd className="text-gray-900">{customer.customer_phone}</dd>
                  </div>
                )}
              </dl>

              <div className="border-t border-gray-200 mt-4 pt-4">
                <h3 className="text-sm font-semibold text-gray-900 mb-3">Details</h3>
                <div className="space-y-3">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
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
                        onValueChange={(v) => { setHeaderForm((f) => ({ ...f, status: v as Proposal['status'] })); setHeaderDirty(true); }}
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
                    </div>
                  </div>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
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
                  <div>
                    <Label>Description</Label>
                    <textarea
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm"
                      rows={2}
                      value={headerForm.description}
                      onChange={(e) => { setHeaderForm((f) => ({ ...f, description: e.target.value })); setHeaderDirty(true); }}
                      disabled={contentReadOnly}
                      placeholder="Short proposal description"
                    />
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
                    value={headerForm.global_fee_amount}
                    onChange={(e) => { setHeaderForm((f) => ({ ...f, global_fee_amount: e.target.value })); setHeaderDirty(true); }}
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
                  <h3 className="text-sm font-semibold text-gray-900">Summary</h3>
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
                  <span className="tabular-nums">{formatCurrency(totals.totalProduct ?? 0, currency)}</span>
                </div>
                {(totals.discountAmount ?? 0) > 0 && (
                  <div className="flex justify-between py-1 text-sm">
                    <span className="text-gray-600">Discount {totals.discountPct ? `(${totals.discountPct}%)` : ''}</span>
                    <span className="tabular-nums">-{formatCurrency(totals.discountAmount ?? 0, currency)}</span>
                  </div>
                )}
                {(totals.installationTotal ?? totals.installationAmount ?? 0) > 0 && (
                  <>
                    {(totals.laborDiscountAmount ?? 0) > 0 ? (
                      <>
                        <div className="flex justify-between py-1 text-sm">
                          <span className="text-gray-600">Installation</span>
                          <span className="tabular-nums">{formatCurrency(totals.installationTotal ?? 0, currency)}</span>
                        </div>
                        <div className="flex justify-between py-1 text-sm">
                          <span className="text-gray-600">Labor discount {totals.instDiscountPct ? `(${totals.instDiscountPct}%)` : ''}</span>
                          <span className="tabular-nums">-{formatCurrency(totals.laborDiscountAmount ?? 0, currency)}</span>
                        </div>
                        <div className="flex justify-between py-1 text-sm font-medium">
                          <span className="text-gray-700">Installation (net)</span>
                          <span className="tabular-nums">{formatCurrency(totals.installationNet ?? 0, currency)}</span>
                        </div>
                      </>
                    ) : (
                      <div className="flex justify-between py-1 text-sm">
                        <span className="text-gray-600">Installation</span>
                        <span className="tabular-nums">{formatCurrency(totals.installationNet ?? totals.installationAmount ?? 0, currency)}</span>
                      </div>
                    )}
                  </>
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
                    {formatCurrency(totals.subtotal ?? 0, currency)}
                  </span>
                </div>
                {showAdjSubtotal && !contentReadOnly && (
                  <div className="flex justify-end pb-2">
                    <div>
                      <Label className="text-xs text-gray-500">Target subtotal</Label>
                      <Input
                        type="number"
                        step="0.01"
                        min="0"
                        className="w-32 mt-0.5"
                        defaultValue=""
                        placeholder={String(Math.round((totals.subtotal ?? 0) * 100) / 100)}
                        onBlur={(e) => {
                          const target = parseFloat(e.target.value);
                          if (Number.isNaN(target) || target < 0) return;
                          const installNet = totals.installationNet ?? 0;
                          const tp = totals.totalProduct ?? 0;
                          if (tp <= 0) return;
                          const targetProductNet = target - installNet;
                          if (targetProductNet <= 0) {
                            setHeaderForm((f) => ({ ...f, global_discount_pct: '100' }));
                          } else if (targetProductNet < tp) {
                            const disc = Math.round(((tp - targetProductNet) / tp) * 1000000) / 10000;
                            setHeaderForm((f) => ({ ...f, global_discount_pct: String(disc) }));
                          } else {
                            setHeaderForm((f) => ({ ...f, global_discount_pct: '0' }));
                          }
                          setHeaderDirty(true);
                        }}
                      />
                    </div>
                  </div>
                )}
                {!headerForm.exempt_tax && (
                  <div className="flex justify-between py-1 text-sm">
                    <span className="text-gray-600">Tax</span>
                    <span className="tabular-nums">{formatCurrency(totals.taxAmount ?? 0, currency)}</span>
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
                    {formatCurrency(totals.total, currency)}
                  </span>
                </div>
                {showAdjTotal && !contentReadOnly && (
                  <div className="flex justify-end pb-2">
                    <div>
                      <Label className="text-xs text-gray-500">Target total (inc. tax)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        min="0"
                        className="w-32 mt-0.5"
                        defaultValue=""
                        placeholder={String(Math.round((totals.total ?? 0) * 100) / 100)}
                        onBlur={(e) => {
                          const targetTotal = parseFloat(e.target.value);
                          if (Number.isNaN(targetTotal) || targetTotal < 0) return;
                          const taxPct = headerForm.exempt_tax ? 0 : (proposal?.tax_pct ?? 0.07);
                          const targetSub = targetTotal / (1 + taxPct);
                          const installNet = totals.installationNet ?? 0;
                          const tp = totals.totalProduct ?? 0;
                          if (tp <= 0) return;
                          const targetProductNet = targetSub - installNet;
                          if (targetProductNet <= 0) {
                            setHeaderForm((f) => ({ ...f, global_discount_pct: '100' }));
                          } else if (targetProductNet < tp) {
                            const disc = Math.round(((tp - targetProductNet) / tp) * 1000000) / 10000;
                            setHeaderForm((f) => ({ ...f, global_discount_pct: String(disc) }));
                          } else {
                            setHeaderForm((f) => ({ ...f, global_discount_pct: '0' }));
                          }
                          setHeaderDirty(true);
                        }}
                      />
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
              Add Custom Line
            </button>
          )}
        </div>

        {displayLines.length === 0 ? (
          <div className="py-12 px-6 text-center">
            <p className="text-gray-500 mb-4">No lines yet. Add lines from the Quote or add a custom line.</p>
            <div className="flex flex-wrap gap-3 justify-center">
              {!contentReadOnly && (
                <button
                  onClick={addCustomLine}
                  className="flex items-center gap-2 px-4 py-2 text-white rounded-lg transition-colors hover:opacity-90"
                  style={{ backgroundColor: 'var(--primary-brand-hex)' }}
                >
                  <Plus className="w-4 h-4" />
                  Add Custom Line
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
        <div className="table-fit-wrapper proposal-lines-table-wrapper">
          <table className="table-fit proposal-lines-table">
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
                      <button
                        type="button"
                        onClick={() => setExpandedLineId(isExpanded ? null : line.id)}
                        className="min-w-[44px] min-h-[44px] rounded hover:bg-gray-100 active:bg-gray-200 inline-flex items-center justify-center touch-manipulation"
                        aria-label={isExpanded ? 'Collapse installation options' : 'Expand installation options'}
                      >
                        {isExpanded ? <ChevronDown className="w-4 h-4 text-gray-500" /> : <ChevronRight className="w-4 h-4 text-gray-500" />}
                      </button>
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
                                {snap?.name ?? qlInfo.name ?? qlInfo.sku ?? '—'}
                              </span>
                              {(snap?.sku ?? qlInfo.sku) && (snap?.sku ?? qlInfo.sku) !== (snap?.name ?? qlInfo.name ?? qlInfo.sku) && (
                                <span className="text-gray-500 text-xs ml-0.5">({snap?.sku ?? qlInfo.sku})</span>
                              )}
                            </div>
                            <div className="flex flex-col gap-0.5 mt-0.5">
                              {(() => {
                                const driveRaw = snap?.drive_type ?? qlInfo?.drive_type ?? null;
                                const driveLabel = (snap?.drive_system_label ?? qlInfo?.drive_system_label)
                                  ?? (driveRaw === 'motor' ? 'Motorized' : driveRaw === 'manual' ? 'Manual' : null);
                                return driveLabel ? (
                                  <span className="text-xs text-gray-500">{driveLabel}</span>
                                ) : null;
                              })()}
                              {dimsMm && dimsMm !== '—' && <span className="text-xs text-gray-500 whitespace-pre-line">{dimsMm}</span>}
                              {isInstallIncluded ? (
                                <span className="inline-flex items-center w-fit px-1.5 py-0.5 rounded-full text-xs font-medium bg-green-50 text-status-green">
                                  Install Included
                                </span>
                              ) : null}
                            </div>
                          </div>
                        ) : (
                          <div className="flex flex-col gap-0.5 flex-1 min-w-0">
                            <span className="text-sm text-gray-900">{line.description || '—'}</span>
                            <span className="text-xs text-gray-500">
                              {CUSTOM_CATEGORIES.find((o) => o.value === (line.custom_category ?? 'other'))?.label ?? 'Other'}
                            </span>
                          </div>
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
                    <td className="w-[16px] min-w-[16px] py-4" aria-hidden></td>
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
                  {line.line_type === 'custom' && isExpanded && (
                    <tr key={`${line.id}-costs`} className="bg-gray-50/80">
                      <td colSpan={11} className="py-4 px-6">
                        <div className="rounded-lg border border-gray-200 bg-white p-4">
                          <h4 className="text-sm font-semibold text-gray-700 mb-3">Cost & Pricing</h4>
                          <div className="flex flex-wrap items-end gap-4">
                            <div>
                              <Label className="text-xs">Area</Label>
                              <Input
                                className="w-24"
                                value={line.area ?? ''}
                                onChange={(e) => updateCustomLine(line.id, { area: e.target.value || null })}
                                disabled={contentReadOnly}
                                placeholder="Area"
                              />
                            </div>
                            <div>
                              <Label className="text-xs">Position</Label>
                              <Input
                                className="w-24"
                                value={line.position ?? ''}
                                onChange={(e) => updateCustomLine(line.id, { position: e.target.value || null })}
                                disabled={contentReadOnly}
                                placeholder="Position"
                              />
                            </div>
                            <div>
                              <Label className="text-xs">Description</Label>
                              <Input
                                className="w-48"
                                value={line.description ?? ''}
                                onChange={(e) => updateCustomLine(line.id, { description: e.target.value })}
                                disabled={contentReadOnly}
                                placeholder="Description"
                              />
                            </div>
                            <div>
                              <Label className="text-xs">Category</Label>
                              <SelectShadcn
                                value={line.custom_category ?? 'other'}
                                onValueChange={(v) => updateCustomLine(line.id, { custom_category: v as ProposalCustomCategory })}
                                disabled={contentReadOnly}
                              >
                                <SelectTrigger className="w-36">
                                  <SelectValue />
                                </SelectTrigger>
                                <SelectContent>
                                  {CUSTOM_CATEGORIES.map((o) => (
                                    <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
                                  ))}
                                </SelectContent>
                              </SelectShadcn>
                            </div>
                            <div>
                              <Label className="text-xs">Cost</Label>
                              <Input
                                type="number"
                                step="0.01"
                                min="0"
                                className="w-24"
                                placeholder="0"
                                value={line.unit_cost ?? ''}
                                onChange={(e) => updateCustomLine(line.id, { unit_cost: e.target.value === '' ? null : parseFloat(e.target.value) })}
                                disabled={contentReadOnly}
                              />
                            </div>
                            <div>
                              <Label className="text-xs">Markup %</Label>
                              <Input
                                type="number"
                                step="0.01"
                                min="0"
                                className="w-24"
                                placeholder="0"
                                value={line.markup_pct ?? ''}
                                onChange={(e) => updateCustomLine(line.id, { markup_pct: e.target.value === '' ? null : parseFloat(e.target.value) })}
                                disabled={contentReadOnly}
                              />
                            </div>
                            <div>
                              <Label className="text-xs">Unit Price</Label>
                              <span className="block w-24 py-2 text-sm font-medium text-gray-900 tabular-nums">
                                {formatCurrency(
                                  (Number(line.unit_cost) || 0) * (1 + (Number(line.markup_pct) || 0) / 100),
                                  currency
                                )}
                              </span>
                            </div>
                            <div>
                              <Label className="text-xs">Qty</Label>
                              <Input
                                type="number"
                                step="1"
                                min={0}
                                className="w-20"
                                placeholder="0"
                                value={line.qty == null || line.qty === 0 ? '' : line.qty}
                                onChange={(e) => {
                                  const raw = e.target.value;
                                  if (raw === '') {
                                    updateCustomLine(line.id, { qty: 0 });
                                    return;
                                  }
                                  const n = parseFloat(raw);
                                  if (!Number.isNaN(n) && n >= 0) updateCustomLine(line.id, { qty: n });
                                }}
                                disabled={contentReadOnly}
                              />
                            </div>
                          </div>
                        </div>
                      </td>
                    </tr>
                  )}
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
                                      value={installationAddon.cost_amount ?? ''}
                                      onChange={(e) => {
                                        const cost = Math.max(0, parseFloat(e.target.value) || 0);
                                        upsertAddOn(line.id, { addon_type: 'installation', cost_amount: cost, markup_pct: installationAddon.markup_pct ?? 100, pricing_mode: 'markup_pct' });
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
                                      value={installationAddon.markup_pct ?? ''}
                                      onChange={(e) => {
                                        const markup = Math.max(0, parseFloat(e.target.value) || 0);
                                        upsertAddOn(line.id, { addon_type: 'installation', cost_amount: installationAddon.cost_amount ?? 0, markup_pct: markup, pricing_mode: 'markup_pct' });
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
                                    key={`adj-${line.id}-${line.line_adjustment_pct ?? 0}-${totals.globalFeePct ?? 0}`}
                                    type="number"
                                    step="0.01"
                                    min="0"
                                    className="w-28"
                                    defaultValue={String(Math.round(lineTotal * 100) / 100)}
                                    onBlur={(e) => {
                                      const target = parseFloat(e.target.value);
                                      if (Number.isNaN(target) || target < 0 || baseAmount <= 0) return;
                                      const fMul = 1 + ((totals.globalFeePct ?? 0) / 100);
                                      const rawTarget = fMul > 0 ? target / fMul : target;
                                      const pct = Math.round(((rawTarget / baseAmount) - 1) * 1000000) / 10000;
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
                <span>{formatCurrency(totals.totalProduct ?? 0, currency)}</span>
              </div>
              {(totals.discountAmount ?? 0) > 0 && (
                <div className="flex justify-between py-1 text-sm">
                  <span className="text-gray-600">Discount {totals.discountPct ? `(${totals.discountPct}%)` : ''}</span>
                  <span>-{formatCurrency(totals.discountAmount ?? 0, currency)}</span>
                </div>
              )}
              {(totals.installationTotal ?? totals.installationAmount ?? 0) > 0 && (
                <>
                  {(totals.laborDiscountAmount ?? 0) > 0 ? (
                    <>
                      <div className="flex justify-between py-1 text-sm">
                        <span className="text-gray-600">Installation</span>
                        <span>{formatCurrency(totals.installationTotal ?? 0, currency)}</span>
                      </div>
                      <div className="flex justify-between py-1 text-sm">
                        <span className="text-gray-600">Labor discount {totals.instDiscountPct ? `(${totals.instDiscountPct}%)` : ''}</span>
                        <span>-{formatCurrency(totals.laborDiscountAmount ?? 0, currency)}</span>
                      </div>
                      <div className="flex justify-between py-1 text-sm font-medium">
                        <span className="text-gray-700">Installation (net)</span>
                        <span>{formatCurrency(totals.installationNet ?? 0, currency)}</span>
                      </div>
                    </>
                  ) : (
                    <div className="flex justify-between py-1 text-sm">
                      <span className="text-gray-600">Installation</span>
                      <span>{formatCurrency(totals.installationNet ?? totals.installationAmount ?? 0, currency)}</span>
                    </div>
                  )}
                </>
              )}
              <div className="flex justify-between py-1 text-sm">
                <span className="text-gray-600">Subtotal</span>
                <span>{formatCurrency(totals.subtotal ?? 0, currency)}</span>
              </div>
              {!headerForm.exempt_tax && (
                <div className="flex justify-between py-1 text-sm">
                  <span className="text-gray-600">Tax</span>
                  <span>{formatCurrency(totals.taxAmount ?? 0, currency)}</span>
                </div>
              )}
              <div className="flex justify-between py-2 mt-2 border-t border-gray-200 font-semibold">
                <span>Total {currency ? `(${currency})` : ''}</span>
                <span>{formatCurrency(totals.total, currency)}</span>
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

      {activeTab === 'timeline' && (
        <TimelineView events={timeline} loading={loading && timeline.length === 0} emptyMessage="No activity yet" />
      )}
    </DetailPageLayout>
  );
}
