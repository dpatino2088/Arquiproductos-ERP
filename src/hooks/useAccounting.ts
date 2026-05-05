import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useCallback } from 'react';
import { useOrganizationContext } from '../context/OrganizationContext';
import { supabase } from '../lib/supabase/client';
import {
  accountingAccountsListKey,
  accountingJournalEntriesListKey,
  accountingJournalEntryDetailKey,
  accountingTrialBalanceKey,
  accountingGeneralLedgerKey,
  accountingProfitLossKey,
  accountingBalanceSheetKey,
} from '../lib/queryKeys';
import { keepPreviousData } from '../lib/query-client';

const STALE_TIME_MS = 60_000;
const GC_TIME_MS = 5 * 60_000;

export type AccountType = 'ASSET' | 'LIABILITY' | 'EQUITY' | 'INCOME' | 'EXPENSE' | 'COGS';
export type JournalStatus = 'draft' | 'posted' | 'void';

export interface Account {
  id: string;
  organization_id: string;
  code: string;
  name: string;
  account_type: AccountType;
  detail_type: string | null;
  parent_id: string | null;
  currency: string;
  is_active: boolean;
  is_system: boolean;
  opening_balance: number;
  description: string | null;
}

export interface JournalLine {
  id: string;
  journal_entry_id: string;
  line_no: number;
  account_id: string;
  description: string | null;
  debit: number;
  credit: number;
  currency: string;
  exchange_rate: number;
  debit_base: number;
  credit_base: number;
  entity_type: string | null;
  entity_id: string | null;
  account?: { code: string; name: string; account_type: AccountType };
}

export interface JournalEntry {
  id: string;
  organization_id: string;
  entry_no: string | null;
  entry_date: string;
  source_type: string | null;
  source_id: string | null;
  description: string | null;
  base_currency: string;
  total_debit: number;
  total_credit: number;
  status: JournalStatus;
  posted_at: string | null;
  voided_at: string | null;
  voided_reason: string | null;
  created_at: string;
  updated_at: string;
  lines?: JournalLine[];
}

export interface TrialBalanceRow {
  account_id: string;
  code: string;
  name: string;
  account_type: AccountType;
  total_debit: number;
  total_credit: number;
  balance: number;
}

export interface GeneralLedgerRow {
  account_id: string;
  account_code: string;
  account_name: string;
  account_type: AccountType;
  journal_entry_id: string;
  entry_no: string;
  entry_date: string;
  source_type: string | null;
  source_id: string | null;
  description: string | null;
  line_no: number;
  line_description: string | null;
  debit: number;
  credit: number;
  running_balance: number;
  entity_type: string | null;
  entity_id: string | null;
}

export interface ProfitLossRow {
  section: string;
  account_id: string;
  code: string;
  name: string;
  account_type: AccountType;
  amount: number;
}

export interface BalanceSheetRow {
  section: string;
  account_id: string | null;
  code: string;
  name: string;
  account_type: AccountType;
  amount: number;
}

function toNumber(v: unknown): number {
  const n = Number(v ?? 0);
  return Number.isFinite(n) ? n : 0;
}

// =====================================================================
// Chart of Accounts
// =====================================================================
export function useAccountsList() {
  const { activeOrganizationId } = useOrganizationContext();
  const orgId = activeOrganizationId ?? '';

  return useQuery<Account[]>({
    queryKey: accountingAccountsListKey(orgId),
    queryFn: async () => {
      const { data, error } = await supabase
        .from('Accounts')
        .select('*')
        .eq('organization_id', orgId)
        .order('code', { ascending: true });
      if (error) throw error;
      return (data ?? []) as Account[];
    },
    enabled: !!orgId,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    placeholderData: keepPreviousData,
  });
}

// =====================================================================
// Journal Entries list
// =====================================================================
export interface JournalEntriesListParams {
  q?: string;
  status?: string;
  sourceType?: string;
  from?: string;
  to?: string;
  page?: number;
  pageSize?: number;
  enabled?: boolean;
}

export function useJournalEntriesList(params: JournalEntriesListParams = {}) {
  const { activeOrganizationId } = useOrganizationContext();
  const orgId = activeOrganizationId ?? '';

  const filters = {
    q: params.q ?? '',
    status: params.status ?? 'all',
    sourceType: params.sourceType ?? 'all',
    from: params.from ?? '',
    to: params.to ?? '',
    page: params.page ?? 1,
    pageSize: params.pageSize ?? 50,
  };

  return useQuery<{ rows: JournalEntry[]; total: number }>({
    queryKey: accountingJournalEntriesListKey(orgId, filters),
    queryFn: async () => {
      let query = supabase
        .from('JournalEntries')
        .select('*', { count: 'exact' })
        .eq('organization_id', orgId)
        .eq('deleted', false);

      if (filters.status !== 'all') query = query.eq('status', filters.status);
      if (filters.sourceType !== 'all') query = query.eq('source_type', filters.sourceType);
      if (filters.from) query = query.gte('entry_date', filters.from);
      if (filters.to) query = query.lte('entry_date', filters.to);
      if (filters.q) {
        query = query.or(
          `entry_no.ilike.%${filters.q}%,description.ilike.%${filters.q}%,source_type.ilike.%${filters.q}%`
        );
      }

      const fromIdx = (filters.page - 1) * filters.pageSize;
      const toIdx = fromIdx + filters.pageSize - 1;
      query = query.order('entry_date', { ascending: false }).order('entry_no', { ascending: false }).range(fromIdx, toIdx);

      const { data, error, count } = await query;
      if (error) throw error;
      return { rows: (data ?? []) as JournalEntry[], total: count ?? 0 };
    },
    enabled: (params.enabled ?? true) && !!orgId,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    placeholderData: keepPreviousData,
  });
}

// =====================================================================
// Journal Entry detail (with lines and accounts joined)
// =====================================================================
export function useJournalEntryDetail(entryId: string | null) {
  const { activeOrganizationId } = useOrganizationContext();
  const orgId = activeOrganizationId ?? '';

  return useQuery<JournalEntry | null>({
    queryKey: accountingJournalEntryDetailKey(orgId, entryId ?? ''),
    queryFn: async () => {
      if (!entryId) return null;
      const { data, error } = await supabase
        .from('JournalEntries')
        .select('*')
        .eq('id', entryId)
        .eq('organization_id', orgId)
        .single();
      if (error) throw error;

      const { data: lines, error: lerr } = await supabase
        .from('JournalLines')
        .select('*, account:Accounts(code, name, account_type)')
        .eq('journal_entry_id', entryId)
        .order('line_no', { ascending: true });
      if (lerr) throw lerr;

      return { ...(data as JournalEntry), lines: (lines ?? []) as JournalLine[] };
    },
    enabled: !!orgId && !!entryId,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
  });
}

// =====================================================================
// Manual Journal Entry posting
// =====================================================================
export interface ManualJournalLine {
  account_id: string;
  description?: string;
  debit: number;
  credit: number;
}

export function useAccountingMutations() {
  const queryClient = useQueryClient();
  const { activeOrganizationId } = useOrganizationContext();

  const postManualEntry = useCallback(
    async (input: {
      entry_date: string;
      description: string;
      lines: ManualJournalLine[];
      currency?: string;
    }) => {
      if (!activeOrganizationId) throw new Error('Missing organization');
      const totalDebit = input.lines.reduce((s, l) => s + toNumber(l.debit), 0);
      const totalCredit = input.lines.reduce((s, l) => s + toNumber(l.credit), 0);
      if (Math.abs(totalDebit - totalCredit) > 0.005) {
        throw new Error(`Asiento desbalanceado: Db ${totalDebit.toFixed(2)} vs Cr ${totalCredit.toFixed(2)}`);
      }
      if (input.lines.length < 2) throw new Error('Mínimo 2 líneas');

      const linesPayload = input.lines.map((l) => ({
        account_id: l.account_id,
        description: l.description ?? null,
        debit: toNumber(l.debit),
        credit: toNumber(l.credit),
      }));

      const { data, error } = await supabase.rpc('post_journal_entry', {
        p_org_id: activeOrganizationId,
        p_entry_date: input.entry_date,
        p_source_type: 'manual',
        p_source_id: null,
        p_description: input.description,
        p_lines: linesPayload,
        p_currency: input.currency ?? 'USD',
      });
      if (error) throw error;

      await queryClient.invalidateQueries({ queryKey: ['accounting'] });
      return data as string;
    },
    [activeOrganizationId, queryClient]
  );

  const voidEntry = useCallback(
    async (entryId: string, reason: string) => {
      if (!activeOrganizationId) throw new Error('Missing organization');
      const { error } = await supabase
        .from('JournalEntries')
        .update({ status: 'void', voided_at: new Date().toISOString(), voided_reason: reason })
        .eq('id', entryId)
        .eq('organization_id', activeOrganizationId);
      if (error) throw error;
      await queryClient.invalidateQueries({ queryKey: ['accounting'] });
    },
    [activeOrganizationId, queryClient]
  );

  return { postManualEntry, voidEntry };
}

// =====================================================================
// Reports
// =====================================================================
export function useTrialBalance(asOf: string) {
  const { activeOrganizationId } = useOrganizationContext();
  const orgId = activeOrganizationId ?? '';
  return useQuery<TrialBalanceRow[]>({
    queryKey: accountingTrialBalanceKey(orgId, asOf),
    queryFn: async () => {
      const { data, error } = await supabase.rpc('rpc_trial_balance', {
        p_org_id: orgId,
        p_as_of: asOf,
      });
      if (error) throw error;
      return (data ?? []) as TrialBalanceRow[];
    },
    enabled: !!orgId,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    placeholderData: keepPreviousData,
  });
}

export function useGeneralLedger(accountId: string | null, from: string | null, to: string) {
  const { activeOrganizationId } = useOrganizationContext();
  const orgId = activeOrganizationId ?? '';
  return useQuery<GeneralLedgerRow[]>({
    queryKey: accountingGeneralLedgerKey(orgId, accountId, from, to),
    queryFn: async () => {
      const { data, error } = await supabase.rpc('rpc_general_ledger', {
        p_org_id: orgId,
        p_account_id: accountId,
        p_from: from,
        p_to: to,
      });
      if (error) throw error;
      return (data ?? []) as GeneralLedgerRow[];
    },
    enabled: !!orgId,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    placeholderData: keepPreviousData,
  });
}

export function useProfitLoss(from: string, to: string) {
  const { activeOrganizationId } = useOrganizationContext();
  const orgId = activeOrganizationId ?? '';
  return useQuery<ProfitLossRow[]>({
    queryKey: accountingProfitLossKey(orgId, from, to),
    queryFn: async () => {
      const { data, error } = await supabase.rpc('rpc_profit_loss', {
        p_org_id: orgId,
        p_from: from,
        p_to: to,
      });
      if (error) throw error;
      return (data ?? []) as ProfitLossRow[];
    },
    enabled: !!orgId,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    placeholderData: keepPreviousData,
  });
}

export function useBalanceSheet(asOf: string) {
  const { activeOrganizationId } = useOrganizationContext();
  const orgId = activeOrganizationId ?? '';
  return useQuery<BalanceSheetRow[]>({
    queryKey: accountingBalanceSheetKey(orgId, asOf),
    queryFn: async () => {
      const { data, error } = await supabase.rpc('rpc_balance_sheet', {
        p_org_id: orgId,
        p_as_of: asOf,
      });
      if (error) throw error;
      return (data ?? []) as BalanceSheetRow[];
    },
    enabled: !!orgId,
    staleTime: STALE_TIME_MS,
    gcTime: GC_TIME_MS,
    placeholderData: keepPreviousData,
  });
}
