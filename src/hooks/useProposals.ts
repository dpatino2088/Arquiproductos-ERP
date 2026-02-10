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
        effectiveDealerId = activeDealerId ?? null;
      }

      let query = supabase
        .from('Proposals')
        .select('id, proposal_no, version_no, status, quote_id, dealer_id, customer_id, updated_at, created_at, total_amount, created_by_user_id')
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
        setState((s) => ({ ...s, loading: false, error: linesError.message, proposal, lines: [], addonsMap: new Map(), quoteLinesMap: new Map(), configuredProductsMap: {}, quote: null, customer: null, contact: null }));
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
          .select('id, quantity, name, sku, msrp, unit_msrp, area, position, product_type, collection_name, variant_name, drive_type, width_m, height_m, configured_product_id')
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
            collection_name: ql.collection_name ?? null,
            variant_name: ql.variant_name ?? null,
            drive_type: ql.drive_type ?? null,
            width_m: ql.width_m != null ? Number(ql.width_m) : null,
            height_m: ql.height_m != null ? Number(ql.height_m) : null,
            configured_product_id: ql.configured_product_id ?? null,
            config_snapshot: null,
          });
        });

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
          .select('customer_name')
          .eq('id', customerIdToUse)
          .single();
        if (custData) customer = { customer_name: (custData as any).customer_name || 'N/A' };
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

/**
 * Create a new Proposal from a Quote and copy its QuoteLines as ProposalLines.
 * Sets created_by_user_id or created_by_portal_user_id from auth context.
 */
export async function createProposalFromQuote(quoteId: string): Promise<{ proposalId: string } | { error: string }> {
  const { data: sessionData } = await supabase.auth.getSession();
  const userId = sessionData?.session?.user?.id;
  if (!userId) {
    return { error: 'Not authenticated' };
  }

  const authContext = await fetchAuthContext(supabase);
  let createdByUserId: string | null = null;
  let createdByPortalUserId: string | null = null;

  if (authContext.is_portal_user && authContext.dealer_id) {
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

  const { data: quote, error: quoteErr } = await supabase
    .from('Quotes')
    .select('id, organization_id, dealer_id, customer_id, contact_id, currency, quote_no')
    .eq('id', quoteId)
    .eq('deleted', false)
    .single();

  if (quoteErr || !quote) {
    return { error: quoteErr?.message || 'Quote not found' };
  }

  const orgId = quote.organization_id;
  const dealerId = quote.dealer_id;
  if (!dealerId) {
    return { error: 'Quote has no dealer assigned' };
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
  const proposalNo = quote.quote_no ? `${quote.quote_no}-P${newVersion}` : null;

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
    created_by_user_id: createdByUserId,
    created_by_portal_user_id: createdByPortalUserId,
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
