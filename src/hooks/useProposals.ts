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
import type { Proposal, ProposalLine, ProposalLineAddOn } from '../types/proposals';

export interface ProposalListItem {
  id: string;
  proposal_no: string | null;
  status: Proposal['status'];
  quote_id: string;
  dealer_id: string;
  customer_id: string | null;
  updated_at: string;
  created_at: string;
  total_amount?: number | null;
  customer_name?: string;
  quote_no?: string;
  /** coalesce(AppUsers.display_name, 'Legacy / Imported') for proposal creator */
  proposal_created_by?: string;
  quote_status?: string;
  quote_created_at?: string | null;
  /** coalesce(AppUsers.display_name, 'Legacy / Imported') for quote creator */
  quote_created_by?: string;
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

      let query = supabase
        .from('Proposals')
        .select('id, proposal_no, version_no, status, quote_id, dealer_id, customer_id, updated_at, created_at, total_amount, created_by_user_id, archived')
        .eq('organization_id', activeOrganizationId)
        .or('deleted.is.false,deleted.is.null')
        .order('created_at', { ascending: false });

      if (effectiveDealerId) {
        query = query.eq('dealer_id', effectiveDealerId);
      }

      const { data, error: e } = await query;
      if (e) {
        setError(e.message);
        setList([]);
        return;
      }
      if (signal?.aborted) return;

      const rows = (data || []) as ProposalListItem[];
      const quoteIds = [...new Set(rows.map((r) => r.quote_id))];

      const quotesRes = quoteIds.length
        ? await supabase.from('Quotes').select('id, quote_no, status, created_at, created_by_user_id, customer_id, contact_id').in('id', quoteIds).or('deleted.is.false,deleted.is.null')
        : { data: [] };
      if (signal?.aborted) return;

      const quoteMap = new Map<string, { quote_no?: string; status?: string; created_at?: string; created_by_user_id?: string | null; customer_id?: string; contact_id?: string }>();
      (quotesRes.data || []).forEach((q: any) => {
        quoteMap.set(q.id, {
          quote_no: q.quote_no,
          status: q.status,
          created_at: q.created_at,
          created_by_user_id: q.created_by_user_id ?? undefined,
          customer_id: q.customer_id ?? undefined,
          contact_id: q.contact_id ?? undefined,
        });
      });

      const customerIds = new Set<string>();
      rows.forEach((r) => {
        if (r.customer_id) customerIds.add(r.customer_id);
        const q = quoteMap.get(r.quote_id);
        if (q?.customer_id) customerIds.add(q.customer_id);
      });

      const customersRes =
        customerIds.size > 0
          ? await supabase.from('DirectoryCustomers').select('id, customer_name').in('id', [...customerIds])
          : { data: [] };
      if (signal?.aborted) return;

      const customerMap = new Map<string, string>();
      (customersRes.data || []).forEach((c: { id: string; customer_name?: string }) => {
        customerMap.set(c.id, c.customer_name || '-');
      });

      const appUserIds: string[] = [];
      rows.forEach((r) => {
        if ((r as any).created_by_user_id) appUserIds.push((r as any).created_by_user_id);
        const q = quoteMap.get(r.quote_id);
        if (q?.created_by_user_id) appUserIds.push(q.created_by_user_id);
      });
      const appUsersMap = await getAppUsersDisplayNames(appUserIds);
      if (signal?.aborted) return;

      rows.forEach((r) => {
        const q = quoteMap.get(r.quote_id);
        r.quote_no = q?.quote_no;
        r.quote_status = q?.status;
        r.quote_created_at = q?.created_at ?? undefined;
        r.proposal_created_by = (r as any).created_by_user_id
          ? (appUsersMap.get((r as any).created_by_user_id) ?? 'Legacy / Imported')
          : 'Legacy / Imported';
        r.quote_created_by = q?.created_by_user_id
          ? (appUsersMap.get(q.created_by_user_id) ?? 'Legacy / Imported')
          : 'Legacy / Imported';
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
  area?: string | null;
  position?: string | null;
  product_type?: string | null;
  product_type_id?: string | null;
  collection_name?: string | null;
  variant_name?: string | null;
  drive_type?: string | null;
  width_m?: number | null;
  height_m?: number | null;
  configured_product_id?: string | null;
  config_snapshot?: Record<string, unknown> | null;
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
  quote: { id: string; quote_no: string } | null;
  customer: ProposalDetailCustomer | null;
  contact: ProposalDetailContact | null;
  /** Dealer logo URL for the proposal's dealer (Dealers.logo_url filtered by proposal.dealer_id) */
  dealerLogoUrl: string | null;
  loading: boolean;
  error: string | null;
  canWrite: boolean;
}

export type ProposalDetailData = Omit<ProposalDetailState, 'loading' | 'error' | 'canWrite'>;

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
  let quote: { id: string; quote_no: string } | null = null;

  if (proposal.quote_id) {
    const { data: quoteData } = await supabase
      .from('Quotes')
      .select('id, quote_no')
      .eq('id', proposal.quote_id)
      .eq('deleted', false)
      .single();
    if (quoteData) quote = { id: quoteData.id, quote_no: quoteData.quote_no || '' };
  }

  if (proposal.quote_id) {
    const { data: qlData, error: qlError } = await supabase
      .from('QuoteLines')
      .select('id, quantity, name, sku, msrp, unit_msrp_total_snapshot, area, position, product_type, product_type_id, collection_name, variant_name, drive_type, width_m, height_m, configured_product_id')
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
        area: ql.area ?? null,
        position: ql.position ?? null,
        product_type: ql.product_type ?? null,
        product_type_id: ql.product_type_id ?? null,
        collection_name: ql.collection_name ?? null,
        variant_name: ql.variant_name ?? null,
        drive_type: ql.drive_type ?? null,
        width_m: ql.width_m != null ? Number(ql.width_m) : null,
        height_m: ql.height_m != null ? Number(ql.height_m) : null,
        configured_product_id: ql.configured_product_id ?? null,
        config_snapshot: null,
      });
    });

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
    let catalogItemMap = new Map<string, { name?: string; item_name?: string; sku?: string }>();
    if (uniqueAccIds.length > 0) {
      const { data: ciData } = await supabase
        .from('CatalogItems')
        .select('id, name, item_name, sku')
        .in('id', uniqueAccIds)
        .eq('organization_id', proposal.organization_id);
      (ciData || []).forEach((ci: any) => {
        catalogItemMap.set(ci.id, {
          name: ci.name ?? undefined,
          item_name: ci.item_name ?? undefined,
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
        const name = (ci?.item_name || ci?.name || ci?.sku || '—').trim();
        return { name, qty: c.qty };
      });
      const nextSnapshot = snap && typeof snap === 'object' ? { ...snap } : {};
      (nextSnapshot as Record<string, unknown>).accessories = accessories;
      quoteLinesMap.set(qlId, { ...ql, config_snapshot: nextSnapshot });
    });
  }

  let customer: ProposalDetailCustomer | null = null;
  let contact: ProposalDetailContact | null = null;
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
  if (customerIdToUse && proposal.organization_id) {
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
      const parts = [
        c.street_address_line_1,
        c.street_address_line_2,
        [c.city, c.state, c.zip_code].filter(Boolean).join(', '),
        c.country,
      ].filter(Boolean) as string[];
      customer = {
        customer_name: c.customer_name || 'N/A',
        address: parts.length > 0 ? parts.join(', ') : null,
        customer_email: c.customer_email ?? null,
        customer_phone: c.customer_phone ?? c.alt_phone ?? null,
      };
    }
  }
  if (contactIdToUse && proposal.organization_id) {
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

  const { data: maxVersion } = await supabase
    .from('Proposals')
    .select('version_no')
    .eq('quote_id', quoteId)
    .eq('deleted', false)
    .order('version_no', { ascending: false })
    .limit(1)
    .single();

  const newVersion = (maxVersion?.version_no ?? 0) + 1;
  // Proposal has its own sequence PR-0100, PR-0101... per dealer (independent from Quote QT-xxxx)
  const proposalNo = await generateNextProposalNumber(orgId, dealerId);

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
  }

  return { proposalId };
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
