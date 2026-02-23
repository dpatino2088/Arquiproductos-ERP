/**
 * Proposal detail: editable header, lines (from_quote + custom), totals, PDF download.
 * Uses V2 schema: ProposalLines have override_mode, qty, fixed_line_total.
 * PDF: same header as Quote, simplified table without measurements.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { getSupabaseErrorMessage, isRLSError } from '../../lib/supabase-error-utils';
import { useProposalDetail } from '../../hooks/useProposals';
import type { Proposal, ProposalLine, ProposalCustomCategory, ProposalLineAddOn, ProposalLineAddOnPricingMode } from '../../types/proposals';
import { generateProposalPDF, type ProposalPDFLine } from '../../lib/pdf/generateProposalPDF';
import { formatDimensionsDisplayCompact } from '../../lib/formatDimensions';
import { getLogoPathFromUrl } from '../../lib/dealerLogo';
import { useResolvedStorageUrl } from '../../hooks/useResolvedStorageUrl';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import { ChevronDown, ChevronRight, GripVertical, Plus, AlertTriangle, Printer, Eye } from 'lucide-react';
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
  /** Draft state: edits stay in React until Save. Synced from server when not dirty. */
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
      valid_until: proposal.valid_until ? proposal.valid_until.slice(0, 10) : '',
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
      const feePct = headerForm.global_fee_amount ? parseFloat(headerForm.global_fee_amount) : null;
      const payload: Record<string, unknown> = {
        proposal_no: headerForm.proposal_no || null,
        status: headerForm.status,
        description: headerForm.description?.trim() || null,
        notes: headerForm.notes?.trim() || null,
        terms_title: headerForm.terms_title?.trim() || null,
        terms_content: headerForm.terms_content ?? null,
        valid_until: headerForm.valid_until || null,
        global_discount_pct: headerForm.global_discount_pct ? parseFloat(headerForm.global_discount_pct) : null,
        global_fee_amount: feePct,
        global_installation_discount_pct: headerForm.global_installation_discount_pct ? parseFloat(headerForm.global_installation_discount_pct) : null,
        global_installation_fee_pct: headerForm.global_installation_fee_pct ? parseFloat(headerForm.global_installation_fee_pct) : null,
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
            const { data: inserted, error: e } = await supabase
              .from('ProposalLines')
              .insert({
                organization_id: proposal.organization_id,
                dealer_id: proposal.dealer_id,
                proposal_id: proposal.id,
                line_type: 'custom',
                area: line.area?.trim() || null,
                position: line.position?.trim() || null,
                description: line.description ?? 'New line',
                qty: line.qty ?? 1,
                unit_cost: line.unit_cost ?? null,
                markup_pct: line.markup_pct ?? null,
                unit_price: line.unit_price ?? 0,
                sort_order: draftLines.indexOf(line),
              })
              .select('id')
              .single();
            if (e || !inserted?.id) {
              useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: getSupabaseErrorMessage(e as any) || 'Failed to add line' });
              ok = false;
            } else tempToNewId.set(line.id, inserted.id);
          } else {
            const { error: e } = await supabase.from('ProposalLines').update({
              line_adjustment_pct: line.line_adjustment_pct,
              area: line.area?.trim() || null,
              position: line.position?.trim() || null,
              description: line.description,
              qty: line.qty,
              unit_cost: line.unit_cost ?? null,
              markup_pct: line.markup_pct ?? null,
              unit_price: line.unit_price,
              custom_category: line.custom_category,
              sort_order: draftLines.indexOf(line),
            }).eq('id', line.id);
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
        useUIStore.getState().addNotification({ type: 'success', title: 'Saved', message: 'Proposal saved.' });
      }
    } finally {
      setSaving(false);
    }
  }, [proposal, canWrite, headerDirty, linesDirty, addonsDirty, draftLines, draftAddonsMap, addonsMap, saveHeader, refetch, setCanWrite]);

  const handleSaveAndClose = useCallback(async () => {
    await handleSave();
    router.navigate('/sales/proposals');
  }, [handleSave]);

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
      setDraftLines((prev) => prev.map((l) => (l.id === lineId ? { ...l, ...fields } : l)));
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
    const lineTotals: number[] = [];
    let totalProduct = 0; // Sum of all line totals only (no installation)
    let installationTotal = 0;
    displayLines.forEach((line) => {
      const qlInfo = line.quote_line_id ? quoteLinesMap.get(line.quote_line_id) : undefined;
      const material = computeLineTotal(line, qlInfo, proposal?.status);
      lineTotals.push(material);
      totalProduct += material;
      const installationAddons = (displayAddonsMap?.get(line.id) || []).filter((a) => a.addon_type === 'installation');
      installationTotal += installationAddons.reduce((s, a) => s + (Number(a.sale_amount) || 0), 0);
    });

    const discountPct = proposal?.global_discount_pct ?? 0;
    const discountAmount = totalProduct * (discountPct / 100);

    // Installation: apply Labor Discount % and Labor Fee % (same formula as recalc_proposal_totals)
    const instDiscountPct = headerForm.global_installation_discount_pct ? parseFloat(headerForm.global_installation_discount_pct) : (proposal?.global_installation_discount_pct ?? 0);
    const instFeePct = headerForm.global_installation_fee_pct ? parseFloat(headerForm.global_installation_fee_pct) : (proposal?.global_installation_fee_pct ?? 0);
    const laborDiscountAmount = Number.isNaN(instDiscountPct) ? 0 : installationTotal * (instDiscountPct / 100);
    const afterLaborDiscount = installationTotal - laborDiscountAmount;
    const laborFeeAmount = Number.isNaN(instFeePct) ? 0 : afterLaborDiscount * (instFeePct / 100);
    const installationNet = afterLaborDiscount + laborFeeAmount;

    // Subtotal = Total Product - Discount + Installation net (before tax)
    const subtotal = Math.max(totalProduct - discountAmount, 0) + installationNet;

    if (proposal?.tax_amount != null && proposal?.total_amount != null && !headerForm.global_installation_discount_pct && !headerForm.global_installation_fee_pct) {
      const pctD = proposal.global_installation_discount_pct ?? 0;
      const pctF = proposal.global_installation_fee_pct ?? 0;
      const labDisc = installationTotal * (pctD / 100);
      const afterDisc = installationTotal - labDisc;
      const labFee = afterDisc * (pctF / 100);
      const instNet = afterDisc + labFee;
      const subtotalServer = Math.max(totalProduct - discountAmount, 0) + instNet;
      return {
        totalProduct,
        discountAmount,
        installationTotal,
        laborDiscountAmount: labDisc,
        laborFeeAmount: labFee,
        installationAmount: proposal.installation_amount ?? installationTotal,
        installationNet: instNet,
        subtotal: proposal.subtotal_amount ?? subtotalServer,
        taxAmount: proposal.tax_amount,
        total: proposal.total_amount,
        lineTotals,
        instDiscountPct: pctD,
        instFeePct: pctF,
      };
    }
    const taxPct = 0.07;
    const taxAmount = subtotal * taxPct;
    const total = subtotal + taxAmount;
    return {
      totalProduct,
      discountAmount,
      installationTotal,
      laborDiscountAmount,
      laborFeeAmount,
      installationAmount: installationTotal,
      installationNet,
      subtotal,
      taxAmount,
      total,
      lineTotals,
      instDiscountPct,
      instFeePct,
    };
  }, [displayLines, quoteLinesMap, displayAddonsMap, proposal?.subtotal_amount, proposal?.installation_amount, proposal?.discount_amount, proposal?.tax_amount, proposal?.total_amount, proposal?.global_discount_pct, proposal?.global_installation_discount_pct, proposal?.global_installation_fee_pct, headerForm.global_installation_discount_pct, headerForm.global_installation_fee_pct]);

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
        // Same source as UI Description column: prefer qlInfo.width_m × qlInfo.height_m ("1.2 × 2 m"), then snapshot, then formatDimensions for panels
        const hasSimpleDims = qlInfo && (qlInfo.width_m != null || qlInfo.height_m != null);
        const dimensionsSimple =
          hasSimpleDims
            ? `${qlInfo!.width_m ?? '—'} × ${qlInfo!.height_m ?? '—'} m`
            : null;
        const dimensionsSource =
          dimensionsSimple
            ? null
            : snapFrozen && (snapFrozen.width_m != null || snapFrozen.height_m != null)
              ? {
                  ...(typeof snapFrozen.measurements === 'object' && snapFrozen.measurements ? snapFrozen.measurements : {}),
                  width_m: snapFrozen.width_m,
                  height_m: snapFrozen.height_m,
                }
              : snap?.measurements && typeof snap.measurements === 'object'
                ? snap.measurements
                : qlInfo
                  ? { width_m: qlInfo.width_m, height_m: qlInfo.height_m }
                  : null;
        const dimensionsFormatted =
          dimensionsSource
            ? formatDimensionsDisplayCompact(dimensionsSource as Parameters<typeof formatDimensionsDisplayCompact>[0]).replace(/\s*mm\s*$/i, '').trim()
            : null;
        const dimensions = dimensionsSimple ?? (dimensionsFormatted && dimensionsFormatted !== '—' ? dimensionsFormatted : null);
        const qty = snapFrozen?.qty ?? qlInfo?.quantity ?? 1;
        const unitPrice = qty > 0 ? lineTotal / qty : 0;
        return {
          area: snapFrozen?.area ?? qlInfo?.area ?? null,
          position: snapFrozen?.position ?? qlInfo?.position ?? null,
          product_type: snapFrozen?.product_type ?? qlInfo?.product_type ?? null,
          collection_name: snapFrozen?.collection_name ?? qlInfo?.collection_name ?? null,
          variant_name: snapFrozen?.variant_name ?? qlInfo?.variant_name ?? null,
          drive_type: snapFrozen?.drive_type ?? qlInfo?.drive_type ?? null,
          description: snapFrozen?.name || snapFrozen?.sku || qlInfo?.name || qlInfo?.sku || null,
          sku: snapFrozen?.sku ?? qlInfo?.sku ?? null,
          dimensions: dimensions ?? null,
          install_included: !!(installationAddon && (Number(installationAddon.sale_amount) || 0) > 1),
          accessories: formatAccessoriesForPDF(
            (snapFrozen as { accessories?: unknown } | null)?.accessories ??
            (snap as { accessories?: unknown } | undefined)?.accessories
          ),
          qty,
          unit_price: unitPrice,
          line_total: lineTotal,
        };
      });

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
          customerAddress: customer?.address ?? undefined,
          customerEmail: customer?.customer_email ?? undefined,
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

      const suffix = variant === 'internal' ? 'Internal' : 'Customer';
      const fileName = `Proposal_${proposal.proposal_no || proposal.id.slice(0, 8)}_${suffix}_${new Date().toISOString().split('T')[0]}.pdf`;
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
            message: 'PDF opened in new tab. You can download from the browser if needed.',
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
        <button onClick={() => router.navigate('/sales/proposals')} className="mt-2 text-blue-600 hover:underline">
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
        <button onClick={() => router.navigate('/sales/proposals')} className="mt-2 text-blue-600 hover:underline">
          Back to Proposals
        </button>
      </div>
    );
  }

  const readOnly = !canWrite;

  const contactDisplay = contact
    ? [contact.contact_name, contact.contact_email].filter(Boolean).join(' · ')
    : '';

  return (
    <div className="py-6 px-6 max-w-6xl mx-auto">
      {/* Top row: "Proposal" title + Print dropdown (right) + Close + Save and Close */}
      <div className="flex items-center justify-between mb-2">
        <h1 className="text-xl font-semibold text-foreground">Proposal</h1>
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
          <button
            type="button"
            onClick={() => router.navigate('/sales/proposals')}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
            title="Close"
          >
            Close
          </button>
          <button
            type="button"
            onClick={handleSave}
            disabled={saving || readOnly || (!headerDirty && !linesDirty && !addonsDirty)}
            className="btn-save px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            title="Save"
          >
            {saving ? 'Saving...' : 'Save'}
          </button>
          <button
            type="button"
            onClick={handleSaveAndClose}
            disabled={saving || readOnly}
            className="btn-save-close px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {saving ? 'Saving...' : 'Save and Close'}
          </button>
        </div>
      </div>

      {/* Breadcrumb: Proposals / no · Quote · Customer · Contact · email */}
      <div className="mb-6 flex flex-wrap items-center gap-2 text-sm text-gray-500" style={{ marginTop: '4mm' }}>
        <button onClick={() => router.navigate('/sales/proposals')} className="hover:text-gray-700 whitespace-nowrap">
          Proposals
        </button>
        <span>/</span>
        <span className="text-gray-900 font-medium">{proposal.proposal_no || proposal.id.slice(0, 8)}</span>
        {quote && (
          <>
            <span>·</span>
            <button
              onClick={() => router.navigate(`/sales/quotes/${quote.id}/edit`)}
              className="text-blue-600 hover:underline whitespace-nowrap"
            >
              Quote {quote.quote_no}
            </button>
          </>
        )}
        {customer && (
          <>
            <span>·</span>
            <span className="text-gray-700">{customer.customer_name}</span>
          </>
        )}
        {contactDisplay && (
          <>
            <span>·</span>
            <span className="text-gray-600 truncate max-w-[200px] sm:max-w-none" title={contactDisplay}>
              {contactDisplay}
            </span>
          </>
        )}
      </div>

      {/* Header card: mismo estilo que Quotes/ERP; logo alineado con la P de Proposal No */}
      <div className="bg-white border border-gray-200 rounded-lg p-6 mb-6">
        <div className="flex items-start gap-4 mb-4 -ml-0">
          <div className="logo-slot flex-shrink-0 self-start">
            {showLogo ? (
              <img
                id="dealerLogoDetail"
                src={resolvedLogoUrl ?? ''}
                alt="Dealer logo"
                crossOrigin="anonymous"
                onError={handleLogoError}
                className="max-w-full max-h-full object-contain"
              />
            ) : (
              <div className="flex items-center justify-center w-full h-full text-gray-400 text-xs" aria-hidden>
                Dealer logo
              </div>
            )}
          </div>
        </div>
        <div className="grid grid-cols-12 gap-4">
          <div className="col-span-12 md:col-span-4">
            <Label>Proposal No</Label>
            <Input
              value={headerForm.proposal_no}
              onChange={(e) => { setHeaderForm((f) => ({ ...f, proposal_no: e.target.value })); setHeaderDirty(true); }}
              disabled={readOnly}
            />
          </div>
          <div className="col-span-12 md:col-span-2">
            <Label>Status</Label>
            <SelectShadcn
              value={headerForm.status}
              onValueChange={(v) => { setHeaderForm((f) => ({ ...f, status: v as Proposal['status'] })); setHeaderDirty(true); }}
              disabled={readOnly}
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
          <div className="col-span-12 md:col-span-4">
            <Label>Valid until</Label>
            <Input
              type="date"
              value={headerForm.valid_until}
              onChange={(e) => { setHeaderForm((f) => ({ ...f, valid_until: e.target.value })); setHeaderDirty(true); }}
              disabled={readOnly}
            />
          </div>
          <div className="col-span-12">
            <Label>Description</Label>
            <textarea
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm"
              rows={2}
              value={headerForm.description}
              onChange={(e) => { setHeaderForm((f) => ({ ...f, description: e.target.value })); setHeaderDirty(true); }}
              disabled={readOnly}
              placeholder="Short proposal description"
            />
          </div>
          <div className="col-span-6 md:col-span-2">
            <Label>Global discount %</Label>
            <Input
              type="number"
              step="0.01"
              min="0"
              max="100"
              value={headerForm.global_discount_pct}
              onChange={(e) => { setHeaderForm((f) => ({ ...f, global_discount_pct: e.target.value })); setHeaderDirty(true); }}
              disabled={readOnly}
            />
          </div>
          <div className="col-span-6 md:col-span-2">
            <Label>Global fee %</Label>
            <Input
              type="number"
              step="0.01"
              min="0"
              max="100"
              placeholder="e.g. 10"
              value={headerForm.global_fee_amount}
              onChange={(e) => { setHeaderForm((f) => ({ ...f, global_fee_amount: e.target.value })); setHeaderDirty(true); }}
              disabled={readOnly}
            />
          </div>
          <div className="col-span-6 md:col-span-2">
            <Label>Labor discount %</Label>
            <Input
              type="number"
              step="0.01"
              min="0"
              max="100"
              placeholder="Installation discount"
              value={headerForm.global_installation_discount_pct}
              onChange={(e) => { setHeaderForm((f) => ({ ...f, global_installation_discount_pct: e.target.value })); setHeaderDirty(true); }}
              disabled={readOnly}
            />
          </div>
          <div className="col-span-6 md:col-span-2">
            <Label>Labor fee %</Label>
            <Input
              type="number"
              step="0.01"
              min="0"
              max="100"
              placeholder="Installation fee"
              value={headerForm.global_installation_fee_pct}
              onChange={(e) => { setHeaderForm((f) => ({ ...f, global_installation_fee_pct: e.target.value })); setHeaderDirty(true); }}
              disabled={readOnly}
            />
          </div>
        </div>
      </div>

      {/* Lines: misma tabla y bordes que listas */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-6">
        <div className="p-4 border-b border-gray-200 flex justify-between items-center">
          <h2 className="text-xl font-semibold text-gray-900">Lines</h2>
          {!readOnly && (
            <button
              onClick={addCustomLine}
              className="flex items-center gap-2 px-3 py-2 text-sm bg-gray-100 hover:bg-gray-200 rounded-lg"
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
              {!readOnly && (
                <button
                  onClick={addCustomLine}
                  className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                >
                  <Plus className="w-4 h-4" />
                  Add Custom Line
                </button>
              )}
              {quote && (
                <button
                  onClick={() => router.navigate(`/sales/quotes/${quote.id}/edit`)}
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
                <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs w-24 [word-break:keep-all]">Area</th>
                <th className="text-center py-3 pl-[21px] pr-4 font-medium text-gray-700 text-xs w-24 min-w-[6rem]">Position</th>
                <th className="text-left py-3 pl-[29px] pr-3 font-medium text-gray-700 text-xs min-w-[447px]">Description</th>
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
                const dims =
                  qlInfo && (qlInfo.width_m != null || qlInfo.height_m != null)
                    ? `${qlInfo.width_m ?? '—'} × ${qlInfo.height_m ?? '—'} m`
                    : null;
                const isCustomInvalid =
                  line.line_type === 'custom' &&
                  (!(line.description?.trim()) || line.qty == null || line.unit_price == null || Number(line.qty) <= 0);
                const isExpanded = expandedLineId === line.id;
                const installationAddon = (displayAddonsMap?.get(line.id) || []).find((a) => a.addon_type === 'installation');
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
                        {!readOnly ? (
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
                    <td className="py-4 px-4 text-gray-700 text-sm w-24 align-middle [word-break:keep-all]">
                      {line.line_type === 'from_quote'
                        ? (line.quote_line_snapshot as { area?: string } | null)?.area ?? qlInfo?.area ?? '—'
                        : (
                          <input
                            className={`w-full min-w-0 max-w-[80px] border rounded px-2 py-1 text-xs ${isCustomInvalid ? 'border-red-400 bg-red-50' : 'border-gray-200'}`}
                            value={line.area ?? ''}
                            onChange={(e) => updateCustomLine(line.id, { area: e.target.value || null })}
                            disabled={readOnly}
                            placeholder="Area"
                          />
                        )}
                    </td>
                    <td className="py-4 pl-[21px] pr-4 text-center text-gray-700 text-sm w-24 min-w-[6rem] align-middle">
                      {line.line_type === 'from_quote'
                        ? (line.quote_line_snapshot as { position?: string } | null)?.position ?? qlInfo?.position ?? '—'
                        : (
                          <input
                            className={`w-full min-w-0 max-w-[80px] mx-auto border rounded px-2 py-1 text-xs text-center ${isCustomInvalid ? 'border-red-400 bg-red-50' : 'border-gray-200'}`}
                            value={line.position ?? ''}
                            onChange={(e) => updateCustomLine(line.id, { position: e.target.value || null })}
                            disabled={readOnly}
                            placeholder="Position"
                          />
                        )}
                    </td>
                    <td className="py-4 pl-[30px] pr-5 align-middle min-w-[447px] max-w-[447px]">
                      {line.line_type === 'from_quote' && qlInfo ? (
                          <div className="min-h-[3.5rem] flex flex-col justify-center gap-0.5 flex-1 min-w-0">
                            <div className="line-clamp-3 break-words flex flex-col gap-0.5">
                              <span className="font-medium text-gray-900">{qlInfo.name || qlInfo.sku || '—'}</span>
                              {qlInfo.sku && <span className="text-gray-500 text-xs">({qlInfo.sku})</span>}
                              {dims && <span className="text-xs text-gray-500">{dims}</span>}
                            </div>
                            {installationAddon && (Number(installationAddon.sale_amount) || 0) > 1 ? (
                              <span className="inline-flex items-center mt-1 px-1.5 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800 w-fit">
                                Install Included
                              </span>
                            ) : (
                              <span className="h-5 mt-1 w-fit" aria-hidden />
                            )}
                          </div>
                        ) : (
                          <div className="flex flex-col gap-1 flex-1 min-w-0">
                            <input
                              className={`w-full border rounded px-2 py-1 text-sm ${isCustomInvalid ? 'border-red-400 bg-red-50' : 'border-gray-200'}`}
                              value={line.description ?? ''}
                              onChange={(e) => updateCustomLine(line.id, { description: e.target.value })}
                              disabled={readOnly}
                              placeholder="Description"
                            />
                            {isExpanded ? (
                              <SelectShadcn
                                value={line.custom_category ?? 'other'}
                                onValueChange={(v) => updateCustomLine(line.id, { custom_category: v as ProposalCustomCategory })}
                                disabled={readOnly}
                              >
                                <SelectTrigger className="w-36 h-8">
                                  <SelectValue />
                                </SelectTrigger>
                                <SelectContent>
                                  {CUSTOM_CATEGORIES.map((o) => (
                                    <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
                                  ))}
                                </SelectContent>
                              </SelectShadcn>
                            ) : (
                              <span className="text-xs text-gray-500">
                                {CUSTOM_CATEGORIES.find((o) => o.value === (line.custom_category ?? 'other'))?.label ?? 'Other'}
                              </span>
                            )}
                          </div>
                        )}
                    </td>
                    <td className="py-4 px-2 text-gray-700 text-sm align-middle min-w-[120px]">
                      {line.line_type === 'from_quote'
                        ? (line.quote_line_snapshot as { product_type?: string } | null)?.product_type ?? qlInfo?.product_type ?? '—'
                        : (
                          <div className="flex items-center gap-1 flex-wrap">
                            <input
                              type="number"
                              step="0.01"
                              min="0"
                              placeholder="Cost"
                              className={`w-14 border rounded px-1.5 py-1 text-xs ${isCustomInvalid ? 'border-red-400 bg-red-50' : 'border-gray-200'}`}
                              value={line.unit_cost ?? ''}
                              onChange={(e) => updateCustomLine(line.id, { unit_cost: e.target.value === '' ? null : parseFloat(e.target.value) })}
                              disabled={readOnly}
                            />
                            <input
                              type="number"
                              step="0.01"
                              min="0"
                              placeholder="Markup%"
                              className={`w-14 border rounded px-1.5 py-1 text-xs ${isCustomInvalid ? 'border-red-400 bg-red-50' : 'border-gray-200'}`}
                              value={line.markup_pct ?? ''}
                              onChange={(e) => updateCustomLine(line.id, { markup_pct: e.target.value === '' ? null : parseFloat(e.target.value) })}
                              disabled={readOnly}
                            />
                          </div>
                        )}
                    </td>
                    <td className="py-4 px-1.5 text-center align-middle min-w-[64px] w-[64px] tabular-nums">
                      {line.line_type === 'custom' ? (
                        <input
                          type="number"
                          step="0.01"
                          min="0"
                          className={`w-14 border rounded px-1.5 py-1 text-sm text-center mx-auto ${isCustomInvalid ? 'border-red-400 bg-red-50' : 'border-gray-200'}`}
                          value={line.qty ?? ''}
                          onChange={(e) => updateCustomLine(line.id, { qty: e.target.value === '' ? 0 : parseFloat(e.target.value) })}
                          disabled={readOnly}
                        />
                      ) : (
                        qlInfo?.quantity ?? '—'
                      )}
                    </td>
                    <td className="w-[16px] min-w-[16px] py-4" aria-hidden></td>
                    <td className="py-4 pl-2 pr-2 text-right align-middle w-[108px] max-w-[108px] whitespace-nowrap tabular-nums">
                      {line.line_type === 'custom' ? (
                        <input
                          type="number"
                          step="0.01"
                          min="0"
                          className={`w-20 border rounded px-2 py-1 text-sm text-right ${isCustomInvalid ? 'border-red-400 bg-red-50' : 'border-gray-200'}`}
                          value={line.unit_price ?? ''}
                          onChange={(e) => updateCustomLine(line.id, { unit_price: e.target.value === '' ? 0 : parseFloat(e.target.value) })}
                          disabled={readOnly}
                        />
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
                        <div className="rounded-lg border border-gray-200 bg-white p-4">
                          <h4 className="text-sm font-semibold text-gray-700 mb-3">Add-ons</h4>
                          <div className="flex flex-wrap items-end gap-4">
                            <Label className="flex items-center gap-2">
                              <input
                                type="checkbox"
                                checked={!!installationAddon}
                                onChange={(e) => {
                                  if (e.target.checked) {
                                    upsertAddOn(line.id, { addon_type: 'installation', cost_amount: 0, pricing_mode: 'markup_pct', markup_pct: 100, taxable: true });
                                  } else if (installationAddon) {
                                    removeAddOn(installationAddon.id);
                                  }
                                }}
                                disabled={readOnly}
                              />
                              Installation
                            </Label>
                            {installationAddon && (() => {
                              const draft = addonDraft[line.id];
                              const cost = draft?.cost_amount ?? (installationAddon.cost_amount ?? 0);
                              const markupPct = draft?.markup_pct ?? (installationAddon.markup_pct ?? 100);
                              const sale = draft?.sale_amount ?? (installationAddon.sale_amount ?? 0);
                              const pricingMode = draft?.pricing_mode ?? (installationAddon.pricing_mode ?? 'markup_pct');
                              const taxable = draft?.taxable ?? (installationAddon.taxable ?? true);
                              const persist = () => {
                                const latest = addonDraftRef.current[line.id];
                                const c = latest?.cost_amount ?? cost;
                                const mp = latest?.markup_pct ?? markupPct;
                                const s = latest?.sale_amount ?? sale;
                                const pm = latest?.pricing_mode ?? pricingMode;
                                const t = latest?.taxable ?? taxable;
                                const newSale = pm === 'markup_pct' ? c * (1 + mp / 100) : s;
                                upsertAddOn(line.id, { addon_type: 'installation', cost_amount: c, pricing_mode: pm, markup_pct: pm === 'markup_pct' ? mp : undefined, sale_amount: newSale, taxable: t });
                                setAddonDraft((prev) => { const n = { ...prev }; delete n[line.id]; return n; });
                              };
                              return (
                                <>
                                  <div>
                                    <Label className="text-xs">Cost</Label>
                                    <Input
                                      type="number"
                                      step="0.01"
                                      min="0"
                                      className="w-24"
                                      value={String(cost)}
                                      onChange={(e) => {
                                        const v = parseFloat(e.target.value) || 0;
                                        const d: AddonDraft = {
                                          cost_amount: v,
                                          markup_pct: markupPct,
                                          sale_amount: pricingMode === 'fixed_price' ? sale : v * (1 + markupPct / 100),
                                          pricing_mode: pricingMode,
                                          taxable,
                                        };
                                        addonDraftRef.current = { ...addonDraftRef.current, [line.id]: d };
                                        setAddonDraft((prev) => ({ ...prev, [line.id]: d }));
                                      }}
                                      onBlur={persist}
                                      disabled={readOnly}
                                    />
                                  </div>
                                  <div>
                                    <Label className="text-xs">Pricing</Label>
                                    <SelectShadcn
                                      value={pricingMode}
                                      onValueChange={(v: ProposalLineAddOnPricingMode) => {
                                        const newSale = v === 'markup_pct' ? cost * (1 + markupPct / 100) : sale;
                                        setAddonDraft((prev) => ({ ...prev, [line.id]: { cost_amount: cost, markup_pct: markupPct, sale_amount: newSale, pricing_mode: v, taxable } }));
                                        upsertAddOn(line.id, { addon_type: 'installation', cost_amount: cost, pricing_mode: v, markup_pct: v === 'markup_pct' ? markupPct : undefined, sale_amount: newSale, taxable });
                                      }}
                                      disabled={readOnly}
                                    >
                                      <SelectTrigger className="w-36">
                                        <SelectValue />
                                      </SelectTrigger>
                                      <SelectContent>
                                        <SelectItem value="markup_pct">Markup %</SelectItem>
                                        <SelectItem value="fixed_price">Fixed sale price</SelectItem>
                                      </SelectContent>
                                    </SelectShadcn>
                                  </div>
                                  {pricingMode === 'markup_pct' && (
                                    <div>
                                      <Label className="text-xs">Markup %</Label>
                                      <Input
                                        type="number"
                                        step="1"
                                        min="0"
                                        className="w-20"
                                        value={String(markupPct)}
                                        onChange={(e) => {
                                          const v = parseFloat(e.target.value) || 0;
                                          const d: AddonDraft = { cost_amount: cost, markup_pct: v, sale_amount: cost * (1 + v / 100), pricing_mode: 'markup_pct', taxable };
                                          addonDraftRef.current = { ...addonDraftRef.current, [line.id]: d };
                                          setAddonDraft((prev) => ({ ...prev, [line.id]: d }));
                                        }}
                                        onBlur={persist}
                                        disabled={readOnly}
                                      />
                                    </div>
                                  )}
                                  {pricingMode === 'fixed_price' && (
                                    <div>
                                      <Label className="text-xs">Sale price</Label>
                                      <Input
                                        type="number"
                                        step="0.01"
                                        min="0"
                                        className="w-24"
                                        value={String(sale)}
                                        onChange={(e) => {
                                          const v = parseFloat(e.target.value) || 0;
                                          const d: AddonDraft = { cost_amount: cost, markup_pct: markupPct, sale_amount: v, pricing_mode: 'fixed_price', taxable };
                                          addonDraftRef.current = { ...addonDraftRef.current, [line.id]: d };
                                          setAddonDraft((prev) => ({ ...prev, [line.id]: d }));
                                        }}
                                        onBlur={persist}
                                        disabled={readOnly}
                                      />
                                    </div>
                                  )}
                                  <Label className="flex items-center gap-2">
                                    <input
                                      type="checkbox"
                                      checked={!!taxable}
                                      onChange={(e) => {
                                        const v = e.target.checked;
                                        setAddonDraft((prev) => ({ ...prev, [line.id]: { cost_amount: cost, markup_pct: markupPct, sale_amount: sale, pricing_mode: pricingMode, taxable: v } }));
                                        upsertAddOn(line.id, { addon_type: 'installation', cost_amount: cost, pricing_mode: pricingMode, markup_pct: markupPct, sale_amount: sale, taxable: v });
                                      }}
                                      disabled={readOnly}
                                    />
                                    Taxable
                                  </Label>
                                </>
                              );
                            })()}
                            <div className="w-full flex flex-wrap items-end gap-4 mt-2 pt-2 border-t border-gray-100">
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
                                  disabled={readOnly}
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
                                  disabled={readOnly}
                                  placeholder="0"
                                />
                              </div>
                              {((line.line_adjustment_pct ?? 0) !== 0) && (
                                <span className="text-xs text-gray-500 self-center">
                                  Base: {formatCurrency(baseAmount, currency)} → Adjusted: {formatCurrency(materialTotal, currency)}
                                </span>
                              )}
                            </div>
                          </div>
                          {addonsTotal > 0 && (
                            <div className="mt-3 pt-3 border-t border-gray-100 text-xs text-gray-600">
                              Material: {formatCurrency(materialTotal, currency)} (shown above). Installation: {formatCurrency(addonsTotal, currency)} → global Installation line
                            </div>
                          )}
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

      {/* Notes (left) + Summary (right) - aligned */}
      <div className="flex flex-col md:flex-row gap-6 items-stretch mb-6">
        <div className="flex-1 min-w-0 bg-white border border-gray-200 rounded-lg p-6">
          <h3 className="text-sm font-semibold text-gray-700 mb-3">Notes</h3>
          <textarea
            className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm min-h-[120px]"
            rows={4}
            value={headerForm.notes}
            onChange={(e) => { setHeaderForm((f) => ({ ...f, notes: e.target.value })); setHeaderDirty(true); }}
            disabled={readOnly}
            placeholder="Additional notes or comments..."
          />
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-6 w-full md:w-auto shrink-0 md:min-w-[284px] md:max-w-[284px] self-start">
          <div className="flex items-center gap-2 pb-3 mb-3 border-b border-gray-100">
            <input
              type="checkbox"
              checked={headerForm.exempt_tax}
              onChange={(e) => { setHeaderForm((f) => ({ ...f, exempt_tax: e.target.checked })); setHeaderDirty(true); }}
              disabled={readOnly}
            />
            <Label className="text-sm text-gray-700 cursor-pointer">Exempt Tax</Label>
          </div>
          <div className="flex justify-between py-1 text-sm">
            <span className="text-gray-600">Total Product</span>
            <span>{formatCurrency(totals.totalProduct ?? 0, currency)}</span>
          </div>
          {(totals.discountAmount ?? 0) > 0 && (
            <div className="flex justify-between py-1 text-sm">
              <span className="text-gray-600">Discount {proposal?.global_discount_pct != null ? `(${proposal.global_discount_pct}%)` : ''}</span>
              <span>-{formatCurrency(totals.discountAmount ?? 0, currency)}</span>
            </div>
          )}
          {(totals.installationTotal ?? totals.installationAmount ?? 0) > 0 && (
            <>
              {((totals.laborDiscountAmount ?? 0) > 0 || (totals.laborFeeAmount ?? 0) > 0) ? (
                <>
                  <div className="flex justify-between py-1 text-sm">
                    <span className="text-gray-600">Installation</span>
                    <span>{formatCurrency(totals.installationTotal ?? 0, currency)}</span>
                  </div>
                  {(totals.laborDiscountAmount ?? 0) > 0 && (
                    <div className="flex justify-between py-1 text-sm">
                      <span className="text-gray-600">Labor discount {totals.instDiscountPct != null ? `(${totals.instDiscountPct}%)` : ''}</span>
                      <span>-{formatCurrency(totals.laborDiscountAmount ?? 0, currency)}</span>
                    </div>
                  )}
                  {(totals.laborFeeAmount ?? 0) > 0 && (
                    <div className="flex justify-between py-1 text-sm">
                      <span className="text-gray-600">Labor fee {totals.instFeePct != null ? `(${totals.instFeePct}%)` : ''}</span>
                      <span>{formatCurrency(totals.laborFeeAmount ?? 0, currency)}</span>
                    </div>
                  )}
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

      {/* Terms & Conditions - at end of page */}
      <div className="mb-6">
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
          readOnly={readOnly}
          hideSaveAsTemplate
          hideTitleInput
        />
      </div>
    </div>
  );
}
