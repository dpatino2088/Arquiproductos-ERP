/**
 * Data access for Proposals and ProposalLines.
 * RLS is enforced by Supabase; list filters by org + dealer (misma regla que Quotes/Directory).
 */

import { useCallback, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase/client';
import { getAppUsersDisplayNames } from '../lib/appUsersDisplayNames';
import { fetchAuthContext } from '../auth/authContext';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useActiveDealer } from './useActiveDealer';
import { useAccessContext } from './useAccessContext';
import { getEffectiveOrgAndDealer } from '../lib/directoryContext';
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
}

export function useProposalsList() {
  const [list, setList] = useState<ProposalListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();
  const { activeDealerId, hasHydrated } = useActiveDealer();
  const { userType } = useAccessContext();

  const fetchList = useCallback(async () => {
    if (!activeOrganizationId) {
      setList([]);
      setLoading(false);
      setError(null);
      return;
    }

    setList([]);
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
        effectiveDealerId = effective.dealerId;
        if (effectiveDealerId == null) {
          setList([]);
          setLoading(false);
          return;
        }
      } else {
        // Internal users: always filter by dealer_id. If no dealer selected, show no proposals.
        effectiveDealerId = activeDealerId ?? null;
        if (effectiveDealerId == null) {
          setList([]);
          setLoading(false);
          return;
        }
      }

      let query = supabase
        .from('Proposals')
        .select('id, proposal_no, version_no, status, quote_id, dealer_id, customer_id, updated_at, created_at, total_amount, created_by_user_id')
        .eq('organization_id', activeOrganizationId)
        .eq('dealer_id', effectiveDealerId)
        .or('deleted.is.false,deleted.is.null')
        .order('created_at', { ascending: false });

      const { data, error: e } = await query;

      if (e) {
        setError(e.message);
        setList([]);
        return;
      }

      const rows = (data || []) as ProposalListItem[];
      const quoteIds = [...new Set(rows.map((r) => r.quote_id))];

      const quotesRes = quoteIds.length
        ? await supabase.from('Quotes').select('id, quote_no, status, created_at, created_by_user_id, customer_id, contact_id').in('id', quoteIds).or('deleted.is.false,deleted.is.null')
        : { data: [] };

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
      setError(err?.message || 'Error loading proposals');
      setList([]);
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId, activeDealerId, userType]);

  useEffect(() => {
    if (userType === 'internal' && !hasHydrated) return;
    fetchList();
  }, [fetchList, userType, hasHydrated]);

  const deleteProposal = useCallback(
    async (id: string) => {
      const { data, error: e } = await supabase.rpc('soft_delete_proposals', { p_proposal_ids: [id] });
      if (e) throw e;
      if (data !== 1 && data != null) throw new Error('Proposal not found or no permission');
      await fetchList();
    },
    [fetchList]
  );

  const deleteProposals = useCallback(
    async (ids: string[]) => {
      if (ids.length === 0) return;
      const { data, error: e } = await supabase.rpc('soft_delete_proposals', { p_proposal_ids: ids });
      if (e) throw e;
      if (data != null && Number(data) < ids.length) throw new Error('Some proposals could not be deleted (no permission)');
      await fetchList();
    },
    [fetchList]
  );

  return { list, loading, error, refetch: fetchList, deleteProposal, deleteProposals };
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

export function useProposalDetail(proposalId: string | null) {
  const [state, setState] = useState<ProposalDetailState>({
    proposal: null,
    lines: [],
    addonsMap: new Map(),
    quoteLinesMap: new Map(),
    configuredProductsMap: {},
    quote: null,
    customer: null,
    contact: null,
    dealerLogoUrl: null,
    loading: true,
    error: null,
    canWrite: true,
  });

  const fetchDetail = useCallback(async () => {
    if (!proposalId) {
      setState((s) => ({ ...s, loading: false, error: null }));
      return;
    }
    setState((s) => ({ ...s, loading: true, error: null }));
    try {
      const { data: proposalData, error: proposalError } = await supabase
        .from('Proposals')
        .select('*')
        .eq('id', proposalId)
        .eq('deleted', false)
        .single();

      if (proposalError || !proposalData) {
        setState((s) => ({
          ...s,
          loading: false,
          error: proposalError?.message || 'Proposal not found',
          proposal: null,
          lines: [],
          addonsMap: new Map(),
          quoteLinesMap: new Map(),
          configuredProductsMap: {},
          quote: null,
          customer: null,
          contact: null,
          dealerLogoUrl: null,
        }));
        return;
      }

      const proposal = proposalData as Proposal;

      const { data: linesData, error: linesError } = await supabase
        .from('ProposalLines')
        .select('*')
        .eq('proposal_id', proposalId)
        .eq('deleted', false)
        .order('sort_order', { ascending: true })
        .order('created_at', { ascending: true });

      if (linesError) {
        setState((s) => ({ ...s, loading: false, error: linesError.message, proposal, lines: [], addonsMap: new Map(), quoteLinesMap: new Map(), configuredProductsMap: {}, quote: null, customer: null, contact: null, dealerLogoUrl: null }));
        return;
      }

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

      if (quoteLineIds.length > 0) {
        const { data: qlData } = await supabase
          .from('QuoteLines')
          .select('id, quantity, name, sku, msrp, unit_msrp, area, position, product_type, product_type_id, collection_name, variant_name, drive_type, width_m, height_m, configured_product_id')
          .in('id', quoteLineIds);
        (qlData || []).forEach((ql: any) => {
          quoteLinesMap.set(ql.id, {
            quantity: Number(ql.quantity) || 1,
            name: ql.name ?? null,
            sku: ql.sku ?? null,
            msrp: ql.msrp != null ? Number(ql.msrp) : null,
            unit_msrp: ql.unit_msrp != null ? Number(ql.unit_msrp) : null,
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

        // Resolve product_type from ProductTypes when product_type is null but product_type_id is set
        const ptIdsToResolve = (qlData || [])
          .filter((ql: any) => ql.product_type_id && !ql.product_type)
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
            if (ptId && ptMap.has(ptId) && !ql.product_type) {
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

        // Resolve accessories from QuoteLineComponents when config_snapshot.accessories is missing/empty
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
          .single();
        if (quoteRow) {
          if (!customerIdToUse && (quoteRow as any).customer_id) customerIdToUse = (quoteRow as any).customer_id;
          if (!contactIdToUse && (quoteRow as any).contact_id) contactIdToUse = (quoteRow as any).contact_id;
        }
      }
      if (customerIdToUse) {
        const { data: custData } = await supabase
          .from('DirectoryCustomers')
          .select('customer_name, street_address_line_1, street_address_line_2, city, state, zip_code, country, customer_email, customer_phone, alt_phone')
          .eq('id', customerIdToUse)
          .single();
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
      if (contactIdToUse) {
        const { data: contData } = await supabase
          .from('DirectoryContacts')
          .select('contact_name, contact_email')
          .eq('id', contactIdToUse)
          .single();
        if (contData) contact = {
          contact_name: (contData as any).contact_name ?? null,
          contact_email: (contData as any).contact_email ?? null,
        };
      }

      // Dealer logo: filter by proposal.dealer_id so the logo matches the proposal's dealer
      let dealerLogoUrl: string | null = null;
      if (proposal.dealer_id) {
        const { data: dealerData } = await supabase
          .from('Dealers')
          .select('logo_url')
          .eq('id', proposal.dealer_id)
          .maybeSingle();
        dealerLogoUrl = (dealerData as { logo_url?: string } | null)?.logo_url?.trim() || null;
      }

      setState((s) => ({
        ...s,
        loading: false,
        error: null,
        proposal,
        lines,
        addonsMap,
        quoteLinesMap,
        configuredProductsMap,
        quote,
        customer,
        contact,
        dealerLogoUrl,
        canWrite: true,
      }));
    } catch (err: any) {
      setState((s) => ({
        ...s,
        loading: false,
        error: err?.message || 'Error loading proposal',
        proposal: null,
        lines: [],
        addonsMap: new Map(),
        quoteLinesMap: new Map(),
        configuredProductsMap: {},
        quote: null,
        customer: null,
        contact: null,
        dealerLogoUrl: null,
      }));
    }
  }, [proposalId]);

  useEffect(() => {
    fetchDetail();
  }, [fetchDetail]);

  const setCanWrite = useCallback((canWrite: boolean) => {
    setState((s) => ({ ...s, canWrite }));
  }, []);

  return { ...state, refetch: fetchDetail, setCanWrite };
}

export interface CreateProposalFromQuoteOptions {
  /** When internal user is "acting as dealer", pass the selected dealer id so the proposal has a dealer even if the quote has none. */
  actingDealerId?: string | null;
}

/**
 * Create a new Proposal from a Quote and copy its QuoteLines as ProposalLines.
 * Sets created_by_user_id or created_by_portal_user_id from auth context.
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
  let createdByPortalUserId: string | null = null;
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
      if (du) createdByPortalUserId = du.id;
      else return { error: 'Dealer user not found' };
    } else {
      createdByUserId = userId;
    }
  } catch {
    // If get_auth_context fails (e.g. RPC missing), treat as org user
    createdByUserId = userId;
  }

  const { data: quote, error: quoteErr } = await supabase
    .from('Quotes')
    .select('id, organization_id, dealer_id, customer_id, contact_id, currency, quote_no, created_by_user_id, created_by_portal_user_id')
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
  // proposal_no must be unique per org: use quote's quote_no as base (e.g. QT-000003 -> QT-000003-V1) to avoid uq_proposals_org_proposal_no
  const quoteNoBase = (quote.quote_no ?? 'QT-0001').trim().replace(/-V\d+$/i, '') || 'QT-0001';
  const proposalNo = `${quoteNoBase}-V${newVersion}`;

  // Constraint proposals_created_by_exactly_one_chk: exactly one of the two must be set (never both null)
  let finalCreatedByUser: string | null = createdByPortalUserId ? null : (createdByUserId ?? userId);
  let finalCreatedByPortal: string | null = createdByPortalUserId ?? null;
  if (finalCreatedByUser == null && finalCreatedByPortal == null) {
    // Fallback: copy creator from the Quote so the insert never violates the constraint
    const q = quote as { created_by_user_id?: string | null; created_by_portal_user_id?: string | null };
    if (q.created_by_user_id != null && q.created_by_portal_user_id == null) {
      finalCreatedByUser = q.created_by_user_id;
    } else if (q.created_by_portal_user_id != null && q.created_by_user_id == null) {
      finalCreatedByPortal = q.created_by_portal_user_id;
    } else {
      return { error: 'Could not determine proposal creator. Please sign in again and try again.' };
    }
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
    created_by_portal_user_id: finalCreatedByPortal,
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
