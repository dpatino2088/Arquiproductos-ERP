/**
 * Data access for Proposals and ProposalLines.
 * RLS is enforced by Supabase; list filters by org + dealer (misma regla que Quotes/Directory).
 */

import { useCallback, useEffect, useRef, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';
import { getAppUsersDisplayNames } from '../lib/appUsersDisplayNames';
import { fetchAuthContext } from '../auth/authContext';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useDealerScope } from './useDealerScope';
import { useActiveDealer } from './useActiveDealer';
import { useAccessContext } from './useAccessContext';
import { getEffectiveOrgAndDealer } from '../lib/directoryContext';
import { generateNextProposalNumber } from '../lib/sequential-numbers';
import { buildDirectoryScopeKey } from '../lib/directoryScopeKey';
import { proposalDetailKey } from '../lib/queryKeys';
import { fetchAllPaginated, chunkArray } from '../lib/supabasePagination';
import type { Proposal, ProposalLine, ProposalLineAddOn } from '../types/proposals';

/**
 * Live proposal totals aggregated in Postgres via `proposal_list_totals` (mirrors the
 * ProposalDetail live formula). Used for DRAFT proposals so the list updates live like the detail.
 * Sent/accepted proposals are NOT overridden — they keep their frozen `total_amount` snapshot.
 */
async function fetchProposalTotalsMap(
  proposalIds: string[],
  signal?: AbortSignal,
): Promise<Map<string, number>> {
  const map = new Map<string, number>();
  if (proposalIds.length === 0) return map;
  for (const ids of chunkArray(proposalIds, 500)) {
    if (signal?.aborted) return map;
    const { data, error } = await supabase.rpc('proposal_list_totals', { p_proposal_ids: ids });
    if (error) throw error;
    (data ?? []).forEach((row: any) => {
      map.set(row.proposal_id, Number(row.total_amount ?? 0));
    });
  }
  return map;
}

/** Dealer-price subtotal per quote (sum of dealer line prices, MSRP fallback), aggregated
 *  server-side via `quote_list_totals`. Replaces the old client-side QuoteLines download that
 *  truncated at 1000 rows for quotes with many lines. */
async function fetchQuoteDealerSubtotalMap(
  quoteIds: string[],
  signal?: AbortSignal,
): Promise<Map<string, number>> {
  const map = new Map<string, number>();
  if (quoteIds.length === 0) return map;
  for (const ids of chunkArray(quoteIds, 500)) {
    if (signal?.aborted) return map;
    const { data, error } = await supabase.rpc('quote_list_totals', { p_quote_ids: ids });
    if (error) throw error;
    (data ?? []).forEach((row: any) => {
      map.set(row.quote_id, Number(row.dealer_subtotal ?? 0));
    });
  }
  return map;
}

export interface ProposalListItem {
  id: string;
  proposal_no: string | null;
  version_no?: number | null;
  status: Proposal['status'];
  /** Null for standalone proposals (one-off cotizaciones with no parent Quote). */
  quote_id: string | null;
  dealer_id: string;
  customer_id: string | null;
  updated_at: string;
  created_at: string;
  total_amount?: number | null;
  subtotal_amount?: number | null;
  discount_amount?: number | null;
  tax_amount?: number | null;
  /** Auth user id of the proposal creator (used for member ownership checks). */
  created_by_user_id?: string | null;
  customer_name?: string;
  quote_no?: string;
  /** coalesce(AppUsers.display_name, 'Legacy / Imported') for proposal creator */
  proposal_created_by?: string;
  quote_status?: string;
  quote_created_at?: string | null;
  quote_updated_at?: string | null;
  /** coalesce(AppUsers.display_name, 'Legacy / Imported') for quote creator */
  quote_created_by?: string;
  quote_total_amount?: number | null;
  /** True when quote was edited after this proposal was created. */
  is_outdated?: boolean;
  archived?: boolean;
}

export function useProposalsList() {
  const [list, setList] = useState<ProposalListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();
  const { scopeKey, activeDealerId, effectiveDealerId: scopeEffectiveDealerId, hasHydrated } = useDealerScope();
  const { userType } = useAccessContext();
  const fetchListRef = useRef<(signal?: AbortSignal) => Promise<void>>(null!);

  const fetchList = useCallback(async (signal?: AbortSignal) => {
    if (!activeOrganizationId) {
      setList([]);
      setLoading(false);
      setError(null);
      return;
    }
    if (signal?.aborted) return;

    setLoading(true);
    setError(null);

    try {
      let effectiveDealerId: string | null = null;
      if (userType === 'portal') {
        const effective = await getEffectiveOrgAndDealer(supabase, {
          activeOrgId: activeOrganizationId,
          userType,
          activeDealerId: null,
        });
        if (signal?.aborted) return;
        effectiveDealerId = effective.dealerId;
        if (effectiveDealerId == null) {
          setList([]);
          setLoading(false);
          return;
        }
      } else {
        effectiveDealerId = scopeEffectiveDealerId ?? activeDealerId ?? null;
      }

      const makeProposalsQuery = (from: number, to: number) => {
        let q = supabase
          .from('Proposals')
          .select('id, proposal_no, version_no, status, quote_id, dealer_id, customer_id, updated_at, created_at, total_amount, subtotal_amount, discount_amount, tax_amount, created_by_user_id, archived')
          .eq('organization_id', activeOrganizationId)
          .or('deleted.is.false,deleted.is.null')
          .order('created_at', { ascending: false })
          .range(from, to);
        if (effectiveDealerId) {
          q = q.eq('dealer_id', effectiveDealerId);
        }
        return q;
      };

      let rows: ProposalListItem[];
      try {
        rows = await fetchAllPaginated<ProposalListItem>(
          (from, to) => makeProposalsQuery(from, to),
          signal,
        );
      } catch (queryErr: any) {
        setError(queryErr?.message ?? 'Error loading proposals');
        setList([]);
        return;
      }
      if (signal?.aborted) return;

      // Standalone proposals have quote_id=null and skip the Quote join.
      const quoteIds = [...new Set(rows.map((r) => r.quote_id).filter((id): id is string => !!id))];

      // Quotes header (chunked so large proposal sets don't truncate at 1000 ids).
      const quoteMap = new Map<string, { quote_no?: string; status?: string; created_at?: string; updated_at?: string; created_by_user_id?: string | null; customer_id?: string; contact_id?: string; total_amount?: number | null }>();
      for (const ids of chunkArray(quoteIds, 500)) {
        if (signal?.aborted) return;
        const quotesRes = await supabase
          .from('Quotes')
          .select('id, quote_no, status, created_at, updated_at, created_by_user_id, customer_id, contact_id, total_amount')
          .in('id', ids)
          .or('deleted.is.false,deleted.is.null');
        (quotesRes.data || []).forEach((q: any) => {
          quoteMap.set(q.id, {
            quote_no: q.quote_no,
            status: q.status,
            created_at: q.created_at,
            updated_at: q.updated_at,
            created_by_user_id: q.created_by_user_id ?? undefined,
            customer_id: q.customer_id ?? undefined,
            contact_id: q.contact_id ?? undefined,
            total_amount: q.total_amount ?? null,
          });
        });
      }

      // Dealer-price subtotal per quote, aggregated server-side (no 1000-line truncation).
      const quoteDealerTotalMap = await fetchQuoteDealerSubtotalMap(quoteIds, signal);
      if (signal?.aborted) return;

      // Live totals for DRAFT proposals (sent/accepted keep their frozen snapshot) AND for
      // any proposal whose frozen snapshot was never computed (total_amount null) so the list
      // never shows $0 when a real amount exists.
      const liveTotalIds = rows
        .filter((r) => r.status === 'draft' || r.total_amount == null)
        .map((r) => r.id);
      const proposalTotalsMap = await fetchProposalTotalsMap(liveTotalIds, signal);
      if (signal?.aborted) return;

      const customerIds = new Set<string>();
      rows.forEach((r) => {
        if (r.customer_id) customerIds.add(r.customer_id);
        if (r.quote_id) {
          const q = quoteMap.get(r.quote_id);
          if (q?.customer_id) customerIds.add(q.customer_id);
        }
      });

      const customerMap = new Map<string, string>();
      for (const ids of chunkArray([...customerIds], 500)) {
        if (signal?.aborted) return;
        const customersRes = await supabase.from('DirectoryCustomers').select('id, customer_name').in('id', ids);
        (customersRes.data || []).forEach((c: { id: string; customer_name?: string }) => {
          customerMap.set(c.id, c.customer_name || '-');
        });
      }

      const appUserIds: string[] = [];
      rows.forEach((r) => {
        if ((r as any).created_by_user_id) appUserIds.push((r as any).created_by_user_id);
        if (r.quote_id) {
          const q = quoteMap.get(r.quote_id);
          if (q?.created_by_user_id) appUserIds.push(q.created_by_user_id);
        }
      });
      const appUsersMap = await getAppUsersDisplayNames(appUserIds);
      if (signal?.aborted) return;

      rows.forEach((r) => {
        const q = r.quote_id ? quoteMap.get(r.quote_id) : undefined;
        r.quote_no = q?.quote_no;
        r.quote_status = q?.status;
        r.quote_created_at = q?.created_at ?? undefined;
        r.quote_updated_at = q?.updated_at ?? undefined;
        r.proposal_created_by = (r as any).created_by_user_id
          ? (appUsersMap.get((r as any).created_by_user_id) ?? 'Legacy / Imported')
          : 'Legacy / Imported';
        // Standalone proposals: there is no quote, so "Quote created by" is N/A (em-dash).
        r.quote_created_by = r.quote_id === null
          ? '—'
          : (q?.created_by_user_id
              ? (appUsersMap.get(q.created_by_user_id) ?? 'Legacy / Imported')
              : 'Legacy / Imported');
        r.quote_total_amount = r.quote_id ? (quoteDealerTotalMap.get(r.quote_id) ?? null) : null;
        // Draft → live total (matches the detail's live Summary). Sent/accepted → keep the frozen
        // snapshot (Proposals.total_amount), the value committed when the proposal was sent.
        // Fallback: if a non-draft proposal has no frozen snapshot (null), use the live total so
        // the list never shows $0 for a proposal that actually has lines.
        if (r.status === 'draft' || r.total_amount == null) {
          const live = proposalTotalsMap.get(r.id);
          if (live != null) r.total_amount = live;
        }
        const quoteUpdatedTs = q?.updated_at ? Date.parse(q.updated_at) : NaN;
        const proposalCreatedTs = r.created_at ? Date.parse(r.created_at) : NaN;
        r.is_outdated = Number.isFinite(quoteUpdatedTs) && Number.isFinite(proposalCreatedTs) && quoteUpdatedTs > proposalCreatedTs;
        const customerId = r.customer_id ?? q?.customer_id;
        r.customer_name = customerId ? customerMap.get(customerId) : undefined;
      });
      setList(rows);
    } catch (err: any) {
      if (err?.name === 'AbortError') return;
      setError(err?.message || 'Error loading proposals');
      setList([]);
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId, userType, activeDealerId, scopeEffectiveDealerId]);

  fetchListRef.current = fetchList;

  const refetch = useCallback(() => {
    fetchListRef.current();
  }, []);

  useEffect(() => {
    const ctrl = new AbortController();
    fetchListRef.current(ctrl.signal);

    return () => {
      ctrl.abort();
    };
  }, [scopeKey, userType]);

  const deleteProposal = useCallback(
    async (id: string) => {
      const { data, error: e } = await supabase.rpc('soft_delete_proposals', { p_proposal_ids: [id] });
      if (e) throw e;
      if (data !== 1 && data != null) throw new Error('Proposal not found or no permission');
      refetch();
    },
    [refetch]
  );

  const deleteProposals = useCallback(
    async (ids: string[]) => {
      if (ids.length === 0) return;
      const { data, error: e } = await supabase.rpc('soft_delete_proposals', { p_proposal_ids: ids });
      if (e) throw e;
      if (data != null && Number(data) < ids.length) throw new Error('Some proposals could not be deleted (no permission)');
      refetch();
    },
    [refetch]
  );

  return { list, loading, error, refetch, deleteProposal, deleteProposals };
}

export interface QuoteLineInfoForPDF {
  quantity: number;
  name: string | null;
  sku: string | null;
  msrp: number | null;
  unit_msrp: number | null;
  dealer_price_total?: number | null;
  area?: string | null;
  position?: string | null;
  product_type?: string | null;
  product_type_id?: string | null;
  collection_name?: string | null;
  variant_name?: string | null;
  drive_type?: string | null;
  /** Drive system brand/type (e.g. "Manual Vertilux", "Motorize Lutron") */
  drive_system_label?: string | null;
  width_m?: number | null;
  height_m?: number | null;
  configured_product_id?: string | null;
  config_snapshot?: Record<string, unknown> | null;
  /** Catalog item id (for catalog product_type lines) */
  catalog_item_id?: string | null;
  /** Catalog item color, only set for catalog product_type lines */
  catalog_color?: string | null;
  /** Installation type (measurement form / PDF). */
  installation_type?: string | null;
  /** Installation location (measurement form / PDF). */
  installation_location?: string | null;
}

export interface ProposalDetailCustomer {
  customer_name: string;
  /** Formatted address from DirectoryCustomer (street, city, state, zip, country) */
  address?: string | null;
  customer_email?: string | null;
  customer_phone?: string | null;
}
export interface ProposalDetailContact {
  contact_name: string | null;
  contact_email: string | null;
}

export interface ProposalDetailState {
  proposal: Proposal | null;
  lines: ProposalLine[];
  addonsMap: Map<string, ProposalLineAddOn[]>;
  quoteLinesMap: Map<string, QuoteLineInfoForPDF>;
  configuredProductsMap: Record<string, { config_snapshot: Record<string, unknown> | null }>;
  quote: { id: string; quote_no: string; updated_at?: string | null } | null;
  customer: ProposalDetailCustomer | null;
  contact: ProposalDetailContact | null;
  /** Dealer logo URL for the proposal's dealer (Dealers.logo_url filtered by proposal.dealer_id) */
  dealerLogoUrl: string | null;
  loading: boolean;
  error: string | null;
  canWrite: boolean;
}

export type ProposalDetailData = Omit<ProposalDetailState, 'loading' | 'error' | 'canWrite'>;

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

/** Fetcher for proposal detail; throws on error. Used by useProposalDetail and by warmDetailIfNeeded. */
export async function fetchProposalDetailData(proposalId: string): Promise<ProposalDetailData> {
  const { data: proposalData, error: proposalError } = await supabase
    .from('Proposals')
    .select('*')
    .eq('id', proposalId)
    .eq('deleted', false)
    .single();

  if (proposalError || !proposalData) {
    throw new Error(proposalError?.message || 'Proposal not found');
  }

  const proposal = proposalData as Proposal;
  const isFrozenProposal = proposal.status === 'sent' || proposal.status === 'accepted';

  const { data: linesData, error: linesError } = await supabase
    .from('ProposalLines')
    .select('*')
    .eq('proposal_id', proposalId)
    .eq('deleted', false)
    .order('sort_order', { ascending: true })
    .order('created_at', { ascending: true });

  if (linesError) throw new Error(linesError.message);

  const lines = (linesData || []) as ProposalLine[];

  const { data: addonsData } = await supabase
    .from('ProposalLineAddOns')
    .select('*')
    .eq('proposal_id', proposalId)
    .eq('deleted', false)
    .order('sort_order', { ascending: true });

  const addonsMap = new Map<string, ProposalLineAddOn[]>();
  (addonsData || []).forEach((a: ProposalLineAddOn) => {
    const list = addonsMap.get(a.proposal_line_id) || [];
    list.push(a);
    addonsMap.set(a.proposal_line_id, list);
  });
  const quoteLineIds = lines.map((l) => l.quote_line_id).filter(Boolean) as string[];

  let quoteLinesMap = new Map<string, QuoteLineInfoForPDF>();
  let configuredProductsMap: Record<string, { config_snapshot: Record<string, unknown> | null }> = {};
  let quote: { id: string; quote_no: string; updated_at?: string | null } | null = null;

  if (proposal.quote_id) {
    const { data: quoteData } = await supabase
      .from('Quotes')
      .select('id, quote_no, updated_at')
      .eq('id', proposal.quote_id)
      .eq('deleted', false)
      .single();
    if (quoteData) quote = { id: quoteData.id, quote_no: quoteData.quote_no || '', updated_at: quoteData.updated_at ?? null };
  }

  if (proposal.quote_id) {
    const { data: qlData, error: qlError } = await supabase
      .from('QuoteLines')
      .select('id, quantity, name, sku, msrp, unit_msrp_total_snapshot, dealer_price_total, area, position, product_type, product_type_id, collection_name, variant_name, drive_type, width_m, height_m, configured_product_id, catalog_item_id')
      .eq('quote_id', proposal.quote_id);

    if (qlError) throw new Error(qlError.message || 'Error loading quote lines');

    (qlData || []).forEach((ql: any) => {
      const qty = Number(ql.quantity) || 1;
      const lineMsrp = ql.msrp != null ? Number(ql.msrp) : null;
      const unitSnapshot = ql.unit_msrp_total_snapshot != null ? Number(ql.unit_msrp_total_snapshot) : null;
      const unitMsrp = unitSnapshot ?? (lineMsrp != null && qty > 0 ? lineMsrp / qty : null);
      quoteLinesMap.set(ql.id, {
        quantity: qty,
        name: ql.name ?? null,
        sku: ql.sku ?? null,
        msrp: lineMsrp,
        unit_msrp: unitMsrp,
        dealer_price_total: ql.dealer_price_total != null ? Number(ql.dealer_price_total) : null,
        area: ql.area ?? null,
        position: ql.position ?? null,
        product_type: ql.product_type ?? null,
        product_type_id: ql.product_type_id ?? null,
        collection_name: ql.collection_name ?? null,
        variant_name: ql.variant_name ?? null,
        drive_type: ql.drive_type ?? null,
        drive_system_label: null,
        width_m: ql.width_m != null ? Number(ql.width_m) : null,
        height_m: ql.height_m != null ? Number(ql.height_m) : null,
        configured_product_id: ql.configured_product_id ?? null,
        config_snapshot: null,
        catalog_item_id: ql.catalog_item_id ?? null,
        catalog_color: null,
      });
    });

    // Load color for catalog lines
    const catalogItemIds = (qlData || [])
      .filter((ql: any) => String(ql.product_type ?? '').trim().toLowerCase() === 'catalog')
      .map((ql: any) => ql.catalog_item_id)
      .filter((id: string | null | undefined): id is string => !!id);
    const uniqueCatalogIds = [...new Set(catalogItemIds)];
    if (uniqueCatalogIds.length > 0) {
      const { data: ciData } = await supabase
        .from('CatalogItems')
        .select('id, color')
        .in('id', uniqueCatalogIds);
      const colorMap = new Map<string, string>();
      (ciData || []).forEach((ci: any) => {
        if (ci.color) colorMap.set(ci.id, String(ci.color));
      });
      quoteLinesMap.forEach((ql, qlId) => {
        if (ql.catalog_item_id && colorMap.has(ql.catalog_item_id)) {
          quoteLinesMap.set(qlId, { ...ql, catalog_color: colorMap.get(ql.catalog_item_id)! });
        }
      });
    }

    const ptIdsToResolve = (qlData || [])
      .filter((ql: any) => ql.product_type_id)
      .map((ql: any) => ql.product_type_id);
    const uniquePtIds = [...new Set(ptIdsToResolve)] as string[];
    if (uniquePtIds.length > 0) {
      const { data: ptData } = await supabase
        .from('ProductTypes')
        .select('id, name, code')
        .in('id', uniquePtIds);
      const ptMap = new Map<string, string>();
      (ptData || []).forEach((pt: any) => {
        const label = (pt.name || pt.code || '').trim() || null;
        if (label) ptMap.set(pt.id, label);
      });
      quoteLinesMap.forEach((ql, qlId) => {
        const ptId = ql.product_type_id;
        if (ptId && ptMap.has(ptId)) {
          quoteLinesMap.set(qlId, { ...ql, product_type: ptMap.get(ptId)! });
        }
      });
    }

    const configuredProductIds = (qlData || [])
      .map((ql: any) => ql.configured_product_id)
      .filter((id: string | null | undefined) => id) as string[];
    if (configuredProductIds.length > 0) {
      const { data: cpData } = await supabase
        .from('ConfiguredProducts')
        .select('id, config_snapshot')
        .in('id', configuredProductIds);
      (cpData || []).forEach((cp: any) => {
        configuredProductsMap[cp.id] = { config_snapshot: cp.config_snapshot ?? null };
      });
      quoteLinesMap.forEach((ql, qlId) => {
        const cpId = ql.configured_product_id;
        if (cpId && configuredProductsMap[cpId]?.config_snapshot) {
          quoteLinesMap.set(qlId, { ...ql, config_snapshot: configuredProductsMap[cpId].config_snapshot });
        }
      });
    }

    const driveItemIds = new Set<string>();
    configuredProductsMap && Object.values(configuredProductsMap).forEach((cp: { config_snapshot: Record<string, unknown> | null }) => {
      const snap = cp.config_snapshot;
      const driveId = snap?.drive_item_id;
      const motorId = snap?.motor_item_id;
      if (driveId) driveItemIds.add(driveId as string);
      if (motorId) driveItemIds.add(motorId as string);
    });
    let driveItemsMap = new Map<string, { manufacturer_name?: string | null }>();
    if (driveItemIds.size > 0) {
      const { data: driveItemsData, error: driveErr } = await supabase
        .from('CatalogItems')
        .select('id, name, sku, manufacturer_id, manufacturer, Manufacturers(name)')
        .in('id', Array.from(driveItemIds))
        .or(`organization_id.eq.${proposal.organization_id},organization_id.is.null`)
        .eq('is_active', true);
      if (driveErr) {
        console.warn('[useProposals] Error fetching drive items:', driveErr.message);
      }
      if (driveItemsData?.length) {
        driveItemsData.forEach((item: any) => {
          const fromJoin = (item.Manufacturers as { name?: string } | null)?.name ?? (item.manufacturers as { name?: string } | null)?.name;
          const fromColumn = item.manufacturer ? String(item.manufacturer).trim() : null;
          const mfrName = fromJoin || fromColumn || null;
          driveItemsMap.set(item.id, { manufacturer_name: mfrName });
        });
      }
      quoteLinesMap.forEach((ql, qlId) => {
        const snap = (ql.config_snapshot as Record<string, unknown> | null);
        const driveType = ql.drive_type ?? null;
        const driveId = snap?.drive_item_id as string | undefined;
        const motorId = snap?.motor_item_id as string | undefined;
        const systemItemId = driveType === 'motor' ? (motorId ?? driveId) : (driveId ?? motorId);
        const driveItem = systemItemId ? driveItemsMap.get(systemItemId) : null;
        const manufacturerName = driveItem?.manufacturer_name ?? null;
        const driveTypeLabel = driveType === 'motor' ? 'Motorized' : driveType === 'manual' ? 'Manual' : null;
        const label =
          driveTypeLabel && manufacturerName
            ? `${driveTypeLabel} | ${manufacturerName}`
            : manufacturerName
              ? `${driveTypeLabel ?? 'Drive'} | ${manufacturerName}`
              : driveTypeLabel;
        if (label != null) quoteLinesMap.set(qlId, { ...ql, drive_system_label: label });
      });
    }
    quoteLinesMap.forEach((ql, qlId) => {
      if (ql.drive_system_label != null) return;
      const driveType = ql.drive_type ?? null;
      const driveTypeLabel = driveType === 'motor' ? 'Motorized' : driveType === 'manual' ? 'Manual' : null;
      if (driveTypeLabel != null) quoteLinesMap.set(qlId, { ...ql, drive_system_label: driveTypeLabel });
    });

    const { data: accData } = await supabase
      .from('QuoteLineComponents')
      .select('quote_line_id, catalog_item_id, qty')
      .in('quote_line_id', quoteLineIds)
      .eq('organization_id', proposal.organization_id)
      .eq('deleted', false)
      .or('source.eq.accessory,component_role.eq.accessory');
    const accByLine = new Map<string, Array<{ catalog_item_id: string; qty: number }>>();
    (accData || []).forEach((row: any) => {
      const list = accByLine.get(row.quote_line_id) || [];
      list.push({
        catalog_item_id: row.catalog_item_id,
        qty: Number(row.qty) || 1,
      });
      accByLine.set(row.quote_line_id, list);
    });
    const allAccItemIds = (accData || [])
      .map((r: any) => r.catalog_item_id)
      .filter(Boolean) as string[];
    const uniqueAccIds = [...new Set(allAccItemIds)];
    let catalogItemMap = new Map<string, { name?: string; sku?: string }>();
    if (uniqueAccIds.length > 0) {
      const { data: ciData } = await supabase
        .from('CatalogItems')
        .select('id, name, sku')
        .in('id', uniqueAccIds)
        .eq('organization_id', proposal.organization_id);
      (ciData || []).forEach((ci: any) => {
        catalogItemMap.set(ci.id, {
          name: ci.name ?? undefined,
          sku: ci.sku ?? undefined,
        });
      });
    }
    quoteLinesMap.forEach((ql, qlId) => {
      const snap = ql.config_snapshot as Record<string, unknown> | null | undefined;
      const hasAccessories = Array.isArray(snap?.accessories) && (snap!.accessories as unknown[]).length > 0;
      if (hasAccessories) return;
      const components = accByLine.get(qlId) || [];
      if (components.length === 0) return;
      const accessories = components.map((c) => {
        const ci = catalogItemMap.get(c.catalog_item_id);
        const name = (ci?.name || ci?.sku || '—').trim();
        return { name, qty: c.qty };
      });
      const nextSnapshot = snap && typeof snap === 'object' ? { ...snap } : {};
      (nextSnapshot as Record<string, unknown>).accessories = accessories;
      quoteLinesMap.set(qlId, { ...ql, config_snapshot: nextSnapshot });
    });
  }

  let customer: ProposalDetailCustomer | null = null;
  let contact: ProposalDetailContact | null = null;
  if (isFrozenProposal && proposal.customer_snapshot_name) {
    customer = {
      customer_name: proposal.customer_snapshot_name || 'N/A',
      address: composeAddress([proposal.customer_snapshot_address]),
      customer_email: proposal.customer_snapshot_email ?? null,
      customer_phone: proposal.customer_snapshot_phone ?? null,
    };
    contact = {
      contact_name: proposal.contact_snapshot_name ?? null,
      contact_email: proposal.contact_snapshot_email ?? null,
    };
  }
  if (!customer || !contact) {
    let customerIdToUse = proposal.customer_id;
    let contactIdToUse = proposal.contact_id;
    if ((!customerIdToUse || !contactIdToUse) && proposal.quote_id) {
      const { data: quoteRow } = await supabase
        .from('Quotes')
        .select('customer_id, contact_id')
        .eq('id', proposal.quote_id)
        .eq('deleted', false)
        .maybeSingle();
      if (quoteRow) {
        if (!customerIdToUse && (quoteRow as any).customer_id) customerIdToUse = (quoteRow as any).customer_id;
        if (!contactIdToUse && (quoteRow as any).contact_id) contactIdToUse = (quoteRow as any).contact_id;
      }
    }
    if (!customer && customerIdToUse && proposal.organization_id) {
      const { data: custData } = await supabase
        .from('DirectoryCustomers')
        .select('customer_name, street_address_line_1, street_address_line_2, city, state, zip_code, country, customer_email, customer_phone, alt_phone')
        .eq('id', customerIdToUse)
        .eq('organization_id', proposal.organization_id)
        .maybeSingle();
      if (custData) {
        const c = custData as {
          customer_name?: string;
          street_address_line_1?: string | null;
          street_address_line_2?: string | null;
          city?: string | null;
          state?: string | null;
          zip_code?: string | null;
          country?: string | null;
          customer_email?: string | null;
          customer_phone?: string | null;
          alt_phone?: string | null;
        };
        const cityStateZip = [c.city, c.state, c.zip_code]
          .map((p) => (p ?? '').trim())
          .filter(Boolean)
          .join(', ');
        customer = {
          customer_name: c.customer_name || 'N/A',
          address: composeAddress([
            c.street_address_line_1,
            c.street_address_line_2,
            cityStateZip,
            c.country,
          ]),
          customer_email: c.customer_email ?? null,
          customer_phone: c.customer_phone ?? c.alt_phone ?? null,
        };
      }
    }
    if (!contact && contactIdToUse && proposal.organization_id) {
      const { data: contData } = await supabase
        .from('DirectoryContacts')
        .select('contact_name, contact_email')
        .eq('id', contactIdToUse)
        .eq('organization_id', proposal.organization_id)
        .maybeSingle();
      if (contData)
        contact = {
          contact_name: (contData as any).contact_name ?? null,
          contact_email: (contData as any).contact_email ?? null,
        };
    }
  }

  let dealerLogoUrl: string | null = null;
  if (proposal.dealer_id) {
    const { data: dealerData } = await supabase
      .from('Dealers')
      .select('logo_url')
      .eq('id', proposal.dealer_id)
      .maybeSingle();
    dealerLogoUrl = (dealerData as { logo_url?: string } | null)?.logo_url?.trim() || null;
  }

  return {
    proposal,
    lines,
    addonsMap,
    quoteLinesMap,
    configuredProductsMap,
    quote,
    customer,
    contact,
    dealerLogoUrl,
  };
}

const EMPTY_DETAIL: ProposalDetailData = {
  proposal: null,
  lines: [],
  addonsMap: new Map(),
  quoteLinesMap: new Map(),
  configuredProductsMap: {},
  quote: null,
  customer: null,
  contact: null,
  dealerLogoUrl: null,
};

export function useProposalDetail(proposalId: string | null) {
  const { activeOrganizationId } = useOrganizationContext();
  const { activeDealerId } = useActiveDealer();
  const { userType } = useAccessContext();

  const scopeKey = buildDirectoryScopeKey({
    orgId: activeOrganizationId ?? null,
    activeDealerId: activeDealerId ?? null,
    userRole: userType,
  });
  const isScopeReady = !!activeOrganizationId;

  const [canWrite, setCanWriteState] = useState(true);

  const query = useQuery({
    queryKey: proposalDetailKey(scopeKey, proposalId),
    queryFn: () => fetchProposalDetailData(proposalId!),
    enabled: !!proposalId && isScopeReady,
    refetchOnMount: true,
  });

  const refetch = useCallback(() => {
    query.refetch();
  }, [query.refetch]);

  const setCanWrite = useCallback((value: boolean) => {
    setCanWriteState(value);
  }, []);

  if (!proposalId || !isScopeReady) {
    return {
      ...EMPTY_DETAIL,
      loading: false,
      error: null,
      refetch: () => Promise.resolve(undefined),
      setCanWrite,
      canWrite: true,
    };
  }

  const data = query.data;
  const loading = query.isLoading;
  const error = query.error ? (query.error as Error)?.message ?? 'Error loading proposal' : null;

  if (loading && !data) {
    return {
      ...EMPTY_DETAIL,
      loading: true,
      error: null,
      refetch,
      setCanWrite,
      canWrite,
    };
  }

  if (query.isError || !data) {
    return {
      ...EMPTY_DETAIL,
      loading: false,
      error: error ?? 'Error loading proposal',
      refetch,
      setCanWrite,
      canWrite,
    };
  }

  return {
    ...data,
    loading: false,
    error: null,
    refetch,
    setCanWrite,
    canWrite,
  };
}

export interface CreateProposalFromQuoteOptions {
  /** When internal user is "acting as dealer", pass the selected dealer id so the proposal has a dealer even if the quote has none. */
  actingDealerId?: string | null;
  /**
   * Force the proposal number/version to continue an existing proposal family
   * (used when revising an accepted proposal: the new proposal is built from a
   * cloned quote version but must keep the original PR-xxxx family as _V<n>).
   * When provided, the per-quote auto numbering and PR sequence consumption are skipped.
   */
  versionOf?: { baseProposalNo: string; versionNo: number } | null;
}

function getProposalBaseNo(proposalNo: string | null | undefined): string | null {
  if (!proposalNo) return null;
  const trimmed = String(proposalNo).trim();
  if (!trimmed) return null;
  return trimmed.replace(/_V\d+$/i, '');
}

function getProposalVersionFromNo(proposalNo: string | null | undefined): number | null {
  if (!proposalNo) return null;
  const m = String(proposalNo).match(/_V(\d+)$/i);
  if (!m || !m[1]) return null;
  const n = Number(m[1]);
  return Number.isFinite(n) && n >= 2 ? n : null;
}

/**
 * Create a new Proposal from a Quote and copy its QuoteLines as ProposalLines.
 * Sets created_by_user_id from auth context (org and portal users).
 * Resolves dealer_id: quote.dealer_id ?? actingDealerId ?? portalUser.dealer_id (required for Proposals.dealer_id NOT NULL).
 */
export async function createProposalFromQuote(
  quoteId: string,
  options?: CreateProposalFromQuoteOptions
): Promise<{ proposalId: string } | { error: string }> {
  const { data: sessionData } = await supabase.auth.getSession();
  const userId = sessionData?.session?.user?.id;
  if (!userId) {
    return { error: 'Not authenticated' };
  }

  let createdByUserId: string | null = null;
  let portalDealerId: string | null = null;

  try {
    const authContext = await fetchAuthContext(supabase);
    if (authContext.is_portal_user && authContext.dealer_id) {
      portalDealerId = authContext.dealer_id;
      const { data: du } = await supabase
        .from('DealerUsers')
        .select('id')
        .eq('dealer_id', authContext.dealer_id)
        .eq('user_id', userId)
        .eq('deleted', false)
        .limit(1)
        .single();
      if (!du) return { error: 'Dealer user not found' };
      createdByUserId = userId;
    } else {
      createdByUserId = userId;
    }
  } catch {
    // If get_auth_context fails (e.g. RPC missing), treat as org user
    createdByUserId = userId;
  }

  const { data: quote, error: quoteErr } = await supabase
    .from('Quotes')
    .select('id, organization_id, dealer_id, customer_id, contact_id, currency, quote_no, created_by_user_id')
    .eq('id', quoteId)
    .eq('deleted', false)
    .single();

  if (quoteErr || !quote) {
    return { error: quoteErr?.message || 'Quote not found' };
  }

  const orgId = quote.organization_id;
  // Resolve dealer_id: Quote first, then acting-as dealer (internal user), then portal user's dealer. Proposals.dealer_id is NOT NULL in DB.
  const dealerId =
    quote.dealer_id ??
    options?.actingDealerId ??
    portalDealerId ??
    null;

  if (!dealerId) {
    return {
      error:
        'No se puede crear la propuesta sin dealer. Asigna un dealer a la cotización o selecciona "Actuar como" un dealer antes de crear la propuesta.',
    };
  }

  const { data: existingProposals } = await supabase
    .from('Proposals')
    .select('proposal_no, version_no, created_at')
    .eq('quote_id', quoteId)
    .eq('deleted', false)
    .order('version_no', { ascending: true, nullsFirst: false })
    .order('created_at', { ascending: true });

  const proposalsForQuote = (existingProposals ?? []) as Array<{
    proposal_no: string | null;
    version_no: number | null;
    created_at: string | null;
  }>;

  const maxVersionNoFromColumn = proposalsForQuote.reduce((max, p) => {
    const n = Number(p.version_no);
    if (!Number.isFinite(n) || n <= 0) return max;
    return Math.max(max, n);
  }, 0);
  const maxVersionNoFromSuffix = proposalsForQuote.reduce((max, p) => {
    const suffix = getProposalVersionFromNo(p.proposal_no);
    if (!suffix) return max;
    return Math.max(max, suffix);
  }, 0);

  let newVersion: number;
  let proposalNo: string;
  if (options?.versionOf) {
    // Revision flow: keep the original PR-xxxx family, skip sequence consumption.
    newVersion = options.versionOf.versionNo;
    proposalNo =
      newVersion <= 1
        ? options.versionOf.baseProposalNo
        : `${options.versionOf.baseProposalNo}_V${newVersion}`;
  } else {
    newVersion = Math.max(maxVersionNoFromColumn, maxVersionNoFromSuffix, 0) + 1;

    let baseProposalNo: string | null = null;
    const firstProposalWithNo = proposalsForQuote.find((p) => getProposalBaseNo(p.proposal_no));
    if (firstProposalWithNo) {
      baseProposalNo = getProposalBaseNo(firstProposalWithNo.proposal_no);
    }
    if (!baseProposalNo) {
      // First proposal for this quote: consume next global PR sequence.
      baseProposalNo = await generateNextProposalNumber(orgId, dealerId);
    }
    proposalNo = newVersion <= 1 ? baseProposalNo : `${baseProposalNo}_V${newVersion}`;
  }

  // created_by_user_id: auth user id (org or portal). Fallback to quote's creator if needed.
  let finalCreatedByUser: string | null = createdByUserId ?? userId;
  if (finalCreatedByUser == null && quote.created_by_user_id != null) {
    finalCreatedByUser = quote.created_by_user_id;
  }
  if (finalCreatedByUser == null) {
    return { error: 'Could not determine proposal creator. Please sign in again and try again.' };
  }

  const insertProposal: Record<string, unknown> = {
    organization_id: orgId,
    dealer_id: dealerId,
    quote_id: quoteId,
    customer_id: quote.customer_id ?? null,
    contact_id: quote.contact_id ?? null,
    status: 'draft',
    proposal_no: proposalNo,
    version_no: newVersion,
    currency: quote.currency ?? 'USD',
    created_by_user_id: finalCreatedByUser,
  };

  const { data: newProposal, error: insertErr } = await supabase
    .from('Proposals')
    .insert(insertProposal)
    .select('id')
    .single();

  if (insertErr || !newProposal) {
    return { error: insertErr?.message || 'Error creating proposal' };
  }

  const proposalId = newProposal.id;

  // Note: QuoteLines does NOT have a 'deleted' column in the schema
  const { data: quoteLines, error: qlErr } = await supabase
    .from('QuoteLines')
    .select('id, sort_order')
    .eq('quote_id', quoteId)
    .order('sort_order', { ascending: true })
    .order('created_at', { ascending: true });

  if (qlErr) {
    return { error: qlErr.message };
  }

  const { data: policyData } = await supabase
    .from('DealerConfiguratorPolicies')
    .select('allow_custom_only_proposals')
    .eq('organization_id', orgId)
    .eq('dealer_id', dealerId)
    .maybeSingle();

  const allowCustomOnlyProposals = Boolean(policyData?.allow_custom_only_proposals);

  // Guardrail: if dealer policy does not allow custom-only proposals,
  // a proposal must start from at least one quote line.
  if (!quoteLines || quoteLines.length === 0) {
    if (!allowCustomOnlyProposals) {
      // Best effort rollback so we do not leave empty proposal headers.
      await supabase
        .from('Proposals')
        .update({ deleted: true })
        .eq('id', proposalId);
      return { error: 'Cannot create proposal: the quote has no lines.' };
    }

    // Policy allows custom-only proposals: keep empty header and let user add custom lines in ProposalDetail.
    return { proposalId };
  }

  const lineRows = (quoteLines || []).map((ql: any, i: number) => ({
    organization_id: orgId,
    dealer_id: dealerId,
    proposal_id: proposalId,
    line_type: 'from_quote' as const,
    quote_line_id: ql.id,
    override_mode: 'inherit' as const,
    sort_order: ql.sort_order ?? i,
  }));

  if (lineRows.length > 0) {
    const { error: linesInsertErr } = await supabase.from('ProposalLines').insert(lineRows);
    if (linesInsertErr) {
      return { error: linesInsertErr.message };
    }
    // Freeze quote-derived pricing at proposal creation time so later Quote edits
    // do not mutate existing proposal economics.
    const { error: snapshotErr } = await supabase.rpc('capture_proposal_snapshot', {
      p_proposal_id: proposalId,
    });
    if (snapshotErr) {
      // Best effort rollback to avoid leaving a draft proposal without a frozen snapshot.
      await supabase.from('Proposals').update({ deleted: true }).eq('id', proposalId);
      return { error: snapshotErr.message || 'Error freezing proposal snapshot' };
    }
  }

  return { proposalId };
}

export interface CreateProposalVersionResult {
  proposalId: string;
  quoteId: string | null;
  proposalNo: string | null;
}

/**
 * Create a new version (revision) of an existing proposal **from the proposal itself**.
 *
 * Clones the whole proposal — header, ALL lines (from_quote + custom, with their
 * adjustments and frozen snapshots) and add-ons — into a new draft. The link to the
 * original Quote (`quote_id`) is preserved; **no new Quote is created**. Numbering
 * continues the original PR-xxxx family as `_V<n>`.
 *
 * The source proposal is archived (`archived = true`) so it stays an immutable
 * historical record. To instead start a brand-new proposal from the Quote lines,
 * use `createProposalFromQuote` (that is the "from scratch" flow).
 */
export async function createProposalVersion(
  proposalId: string,
  _options?: { actingDealerId?: string | null }
): Promise<CreateProposalVersionResult | { error: string }> {
  const { data: src, error: srcErr } = await supabase
    .from('Proposals')
    .select('id, organization_id, dealer_id, quote_id, proposal_no, currency, customer_id, contact_id')
    .eq('id', proposalId)
    .eq('deleted', false)
    .single();
  if (srcErr || !src) return { error: srcErr?.message || 'Proposal not found' };

  const baseProposalNo = getProposalBaseNo(src.proposal_no) ?? src.proposal_no ?? null;

  // Next version across the whole PR family (base + _V suffixes), archived included.
  let nextVersion = 2;
  if (baseProposalNo) {
    const { data: family } = await supabase
      .from('Proposals')
      .select('proposal_no, version_no')
      .eq('organization_id', src.organization_id)
      .ilike('proposal_no', `${baseProposalNo}%`)
      .eq('deleted', false);
    const maxV = (family ?? []).reduce((m: number, p: any) => {
      const col = Number(p.version_no);
      const suf = getProposalVersionFromNo(p.proposal_no) ?? 0;
      return Math.max(m, Number.isFinite(col) ? col : 0, suf);
    }, 1);
    nextVersion = maxV + 1;
  }

  const cloned = await cloneProposalAsVersion(src, baseProposalNo, nextVersion);
  if ('error' in cloned) return cloned;

  // Archive the source proposal (immutable historical record). Uses a SECURITY DEFINER RPC so
  // a Dealer Member can supersede a proposal created by another dealer user (plain RLS would
  // silently skip the update and leave two active versions).
  const { error: archiveErr } = await supabase.rpc('archive_proposal_for_version', {
    p_proposal_id: proposalId,
  });
  if (archiveErr) {
    // Non-fatal: the new version was created. Fall back to a direct update (works for owner)
    // and warn so the predecessor can be archived manually if needed.
    await supabase.from('Proposals').update({ archived: true }).eq('id', proposalId);
    if (import.meta.env.DEV) {
      console.warn('[createProposalVersion] archive RPC failed', archiveErr);
    }
  }

  return {
    proposalId: cloned.proposalId,
    quoteId: null,
    proposalNo: baseProposalNo
      ? (nextVersion <= 1 ? baseProposalNo : `${baseProposalNo}_V${nextVersion}`)
      : null,
  };
}

/**
 * Clone a proposal as a new draft version: header + ALL lines (from_quote + custom,
 * with their adjustments and snapshots) + add-ons. The original `quote_id` is preserved.
 */
async function cloneProposalAsVersion(
  src: {
    id: string;
    organization_id: string;
    dealer_id: string;
    quote_id: string | null;
    currency: string | null;
    customer_id: string | null;
    contact_id: string | null;
  },
  baseProposalNo: string | null,
  nextVersion: number
): Promise<{ proposalId: string } | { error: string }> {
  const { data: sessionData } = await supabase.auth.getSession();
  const userId = sessionData?.session?.user?.id ?? null;

  const { data: full, error: fullErr } = await supabase
    .from('Proposals')
    .select(
      'global_discount_pct, global_fee_amount, global_installation_discount_pct, global_installation_fee_pct, exempt_tax, description, notes, terms_title, terms_content, terms_source_template_id, valid_until'
    )
    .eq('id', src.id)
    .single();
  if (fullErr || !full) return { error: fullErr?.message || 'Failed to load proposal header' };

  const proposalNo = baseProposalNo
    ? (nextVersion <= 1 ? baseProposalNo : `${baseProposalNo}_V${nextVersion}`)
    : null;

  const { data: created, error: insErr } = await supabase
    .from('Proposals')
    .insert({
      ...full,
      organization_id: src.organization_id,
      dealer_id: src.dealer_id,
      quote_id: src.quote_id ?? null,
      customer_id: src.customer_id ?? null,
      contact_id: src.contact_id ?? null,
      status: 'draft',
      archived: false,
      proposal_no: proposalNo,
      version_no: nextVersion,
      currency: src.currency ?? 'USD',
      created_by_user_id: userId,
    })
    .select('id')
    .single();
  if (insErr || !created) return { error: insErr?.message || 'Error creating proposal version' };
  const newId = created.id;

  const { data: srcLines, error: linesErr } = await supabase
    .from('ProposalLines')
    .select(
      'id, line_type, quote_line_id, override_mode, discount_pct, markup_pct, fixed_unit_price, fixed_line_total, custom_category, area, position, description, qty, uom, unit_price, unit_cost, line_total, line_adjustment_pct, width_m, height_m, product_type_id, drive_type, sort_order, quote_line_snapshot'
    )
    .eq('proposal_id', src.id)
    .eq('deleted', false);
  if (linesErr) return { error: linesErr.message };

  const idMap = new Map<string, string>();
  for (const ln of srcLines ?? []) {
    const { id: oldId, ...rest } = ln as any;
    const { data: newLine, error: e } = await supabase
      .from('ProposalLines')
      .insert({
        ...rest,
        organization_id: src.organization_id,
        dealer_id: src.dealer_id,
        proposal_id: newId,
        deleted: false,
      })
      .select('id')
      .single();
    if (e || !newLine) return { error: e?.message || 'Failed to copy proposal line' };
    idMap.set(oldId, newLine.id);
  }

  if (idMap.size > 0) {
    const { data: srcAddons } = await supabase
      .from('ProposalLineAddOns')
      .select('proposal_line_id, addon_type, cost_amount, pricing_mode, markup_pct, sale_amount, taxable, sort_order')
      .in('proposal_line_id', Array.from(idMap.keys()))
      .eq('deleted', false);
    for (const ad of srcAddons ?? []) {
      const newLineId = idMap.get((ad as any).proposal_line_id);
      if (!newLineId) continue;
      const { proposal_line_id: _omitLineId, ...rest } = ad as any;
      await supabase.from('ProposalLineAddOns').insert({
        ...rest,
        organization_id: src.organization_id,
        dealer_id: src.dealer_id,
        proposal_id: newId,
        proposal_line_id: newLineId,
        deleted: false,
      });
    }
  }

  return { proposalId: newId };
}

export interface CreateStandaloneProposalOptions {
  /** When internal user is "acting as dealer", pass the selected dealer id so the proposal has a dealer. */
  actingDealerId?: string | null;
  /** Optional currency override. Defaults to 'USD'. */
  currency?: string | null;
}

/**
 * Create a standalone (no parent Quote) Proposal.
 *
 * Standalone proposals are pure quoting documents: they do NOT generate
 * Sales Orders, manufacturing or accounting entries. Numbering shares the
 * same per-dealer PR- series as quote-based proposals.
 *
 * Requires that the dealer's DealerConfiguratorPolicies.allow_custom_only_proposals
 * is true; the caller must check this before invoking.
 */
export async function createStandaloneProposal(
  options?: CreateStandaloneProposalOptions
): Promise<{ proposalId: string } | { error: string }> {
  const { data: sessionData } = await supabase.auth.getSession();
  const userId = sessionData?.session?.user?.id;
  if (!userId) {
    return { error: 'Not authenticated' };
  }

  let createdByUserId: string | null = userId;
  let portalDealerId: string | null = null;
  let orgId: string | null = null;

  try {
    const authContext = await fetchAuthContext(supabase);
    orgId = authContext.organization_id ?? null;
    if (authContext.is_portal_user && authContext.dealer_id) {
      portalDealerId = authContext.dealer_id;
    }
    createdByUserId = userId;
  } catch {
    // ignore: fall back to userId, orgId remains null and we will resolve below
  }

  if (!orgId) {
    return { error: 'Could not resolve organization context. Please refresh and try again.' };
  }

  const dealerId = options?.actingDealerId ?? portalDealerId ?? null;
  if (!dealerId) {
    return {
      error:
        'No se puede crear una propuesta sin dealer. Selecciona "Actuar como" un dealer antes de crear la propuesta.',
    };
  }

  // Reuse the per-dealer PR- sequence so reports stay unfragmented.
  const proposalNo = await generateNextProposalNumber(orgId, dealerId);

  const insertProposal: Record<string, unknown> = {
    organization_id: orgId,
    dealer_id: dealerId,
    quote_id: null,
    customer_id: null,
    contact_id: null,
    status: 'draft',
    proposal_no: proposalNo,
    version_no: 1,
    currency: options?.currency ?? 'USD',
    created_by_user_id: createdByUserId,
  };

  const { data: newProposal, error: insertErr } = await supabase
    .from('Proposals')
    .insert(insertProposal)
    .select('id')
    .single();

  if (insertErr || !newProposal) {
    return { error: insertErr?.message || 'Error creating proposal' };
  }

  return { proposalId: newProposal.id };
}

export function useProposalsByQuote(quoteId: string | null) {
  const [proposals, setProposals] = useState<ProposalListItem[]>([]);
  const [loading, setLoading] = useState(false);

  const fetch = useCallback(async () => {
    if (!quoteId) {
      setProposals([]);
      return;
    }
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('Proposals')
        .select('id, proposal_no, version_no, status, quote_id, dealer_id, customer_id, updated_at, created_at, total_amount')
        .eq('quote_id', quoteId)
        .eq('deleted', false)
        .order('version_no', { ascending: false });

      if (error) {
        setProposals([]);
        return;
      }
      setProposals((data || []) as ProposalListItem[]);
    } catch {
      setProposals([]);
    } finally {
      setLoading(false);
    }
  }, [quoteId]);

  useEffect(() => {
    fetch();
  }, [fetch]);

  return { proposals, loading, refetch: fetch };
}
