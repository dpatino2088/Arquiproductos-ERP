import { useState, useEffect, useMemo } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useFilteredMfgSubmodules } from './manufacturingSubmodules';
import { useUIStore } from '../../stores/ui-store';
import { exportQuotePartsExcel } from '../../lib/parts/quotePartsExport';
import { formatDate } from '../../lib/utils';
import { Search, FileSpreadsheet, Download, Loader2, ListTree } from 'lucide-react';

interface QuoteResultRow {
  id: string;
  quote_no: string | null;
  status: string | null;
  created_at: string | null;
  dealer_id: string | null;
  customer_id: string | null;
  version_no: number | null;
  is_version: boolean | null;
  dealer_name: string | null;
  customer_name: string | null;
  sales_order_no: string | null;
  has_mo: boolean;
}

interface QuoteDbRow {
  id: string;
  quote_no: string | null;
  status: string | null;
  created_at: string | null;
  dealer_id: string | null;
  customer_id: string | null;
  version_no: number | null;
  is_version: boolean | null;
}

const QUOTE_SELECT = 'id, quote_no, status, created_at, dealer_id, customer_id, version_no, is_version';
const RESULT_LIMIT = 30;

async function enrichQuotes(quotes: QuoteDbRow[]): Promise<QuoteResultRow[]> {
  if (quotes.length === 0) {return [];}
  const quoteIds = quotes.map((q) => q.id);
  const dealerIds = [...new Set(quotes.map((q) => q.dealer_id).filter(Boolean))] as string[];
  const customerIds = [...new Set(quotes.map((q) => q.customer_id).filter(Boolean))] as string[];

  const [dealersRes, customersRes, sosRes] = await Promise.all([
    dealerIds.length > 0
      ? supabase.from('Dealers').select('id, dealer_name').in('id', dealerIds)
      : Promise.resolve({ data: [] as { id: string; dealer_name: string | null }[] }),
    customerIds.length > 0
      ? supabase.from('DirectoryCustomers').select('id, customer_name').in('id', customerIds)
      : Promise.resolve({ data: [] as { id: string; customer_name: string | null }[] }),
    supabase
      .from('SalesOrders')
      .select('id, quote_id, sales_order_no')
      .in('quote_id', quoteIds)
      .eq('deleted', false),
  ]);

  const dealerMap = new Map(
    ((dealersRes.data ?? []) as { id: string; dealer_name: string | null }[]).map((d) => [d.id, d.dealer_name]),
  );
  const customerMap = new Map(
    ((customersRes.data ?? []) as { id: string; customer_name: string | null }[]).map((c) => [c.id, c.customer_name]),
  );
  const soRows = (sosRes.data ?? []) as { id: string; quote_id: string; sales_order_no: string | null }[];
  const soByQuote = new Map<string, { id: string; sales_order_no: string | null }[]>();
  for (const so of soRows) {
    const list = soByQuote.get(so.quote_id) ?? [];
    list.push({ id: so.id, sales_order_no: so.sales_order_no });
    soByQuote.set(so.quote_id, list);
  }

  const soIds = soRows.map((s) => s.id);
  const soIdsWithMo = new Set<string>();
  if (soIds.length > 0) {
    const { data: moRows } = await supabase
      .from('ManufacturingOrders')
      .select('id, sales_order_id')
      .in('sales_order_id', soIds)
      .eq('deleted', false);
    for (const mo of (moRows ?? []) as { sales_order_id: string }[]) {
      soIdsWithMo.add(mo.sales_order_id);
    }
  }

  return quotes.map((q) => {
    const sos = soByQuote.get(q.id) ?? [];
    return {
      ...q,
      dealer_name: q.dealer_id ? (dealerMap.get(q.dealer_id) ?? null) : null,
      customer_name: q.customer_id ? (customerMap.get(q.customer_id) ?? null) : null,
      sales_order_no: sos.map((s) => s.sales_order_no).filter(Boolean).join(', ') || null,
      has_mo: sos.some((s) => soIdsWithMo.has(s.id)),
    };
  });
}

export default function Parts() {
  const { activeOrganizationId } = useOrganizationContext();
  const filteredSubmodules = useFilteredMfgSubmodules();
  const { registerSubmodules } = useSubmoduleNav();

  const [search, setSearch] = useState('');
  const [debounced, setDebounced] = useState('');
  const [rows, setRows] = useState<QuoteResultRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [downloadingId, setDownloadingId] = useState<string | null>(null);

  useEffect(() => {
    registerSubmodules('Manufacturing', filteredSubmodules);
  }, [registerSubmodules, filteredSubmodules]);

  useEffect(() => {
    const t = setTimeout(() => setDebounced(search.trim()), 300);
    return () => clearTimeout(t);
  }, [search]);

  useEffect(() => {
    if (!activeOrganizationId) { setRows([]); setLoading(false); return; }
    let cancelled = false;

    (async () => {
      setLoading(true);
      setError(null);
      try {
        const q = debounced;
        let quotes: QuoteDbRow[] = [];

        if (q.length < 2) {
          const { data, error: qErr } = await supabase
            .from('Quotes')
            .select(QUOTE_SELECT)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .order('created_at', { ascending: false })
            .limit(RESULT_LIMIT);
          if (qErr) {throw new Error(qErr.message);}
          quotes = (data ?? []) as QuoteDbRow[];
        } else {
          const like = `%${q}%`;
          // The search accepts a quote number, an SO number, a dealer name, or
          // a customer name; everything resolves back to the quote (the source
          // document for the quoted despiece).
          const [soMatch, dealerMatch, customerMatch] = await Promise.all([
            supabase
              .from('SalesOrders')
              .select('quote_id')
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false)
              .ilike('sales_order_no', like)
              .limit(RESULT_LIMIT),
            supabase.from('Dealers').select('id').ilike('dealer_name', like).limit(RESULT_LIMIT),
            supabase.from('DirectoryCustomers').select('id').ilike('customer_name', like).limit(RESULT_LIMIT),
          ]);

          const quoteIdsFromSo = [...new Set(
            ((soMatch.data ?? []) as { quote_id: string | null }[]).map((s) => s.quote_id).filter(Boolean),
          )] as string[];
          const dealerIds = ((dealerMatch.data ?? []) as { id: string }[]).map((d) => d.id);
          const customerIds = ((customerMatch.data ?? []) as { id: string }[]).map((c) => c.id);

          const queries = [
            supabase
              .from('Quotes')
              .select(QUOTE_SELECT)
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false)
              .ilike('quote_no', like)
              .order('created_at', { ascending: false })
              .limit(RESULT_LIMIT),
          ];
          if (quoteIdsFromSo.length > 0) {
            queries.push(
              supabase
                .from('Quotes')
                .select(QUOTE_SELECT)
                .eq('organization_id', activeOrganizationId)
                .eq('deleted', false)
                .in('id', quoteIdsFromSo)
                .limit(RESULT_LIMIT),
            );
          }
          if (dealerIds.length > 0) {
            queries.push(
              supabase
                .from('Quotes')
                .select(QUOTE_SELECT)
                .eq('organization_id', activeOrganizationId)
                .eq('deleted', false)
                .in('dealer_id', dealerIds)
                .order('created_at', { ascending: false })
                .limit(RESULT_LIMIT),
            );
          }
          if (customerIds.length > 0) {
            queries.push(
              supabase
                .from('Quotes')
                .select(QUOTE_SELECT)
                .eq('organization_id', activeOrganizationId)
                .eq('deleted', false)
                .in('customer_id', customerIds)
                .order('created_at', { ascending: false })
                .limit(RESULT_LIMIT),
            );
          }

          const results = await Promise.all(queries);
          const seen = new Set<string>();
          for (const res of results) {
            if (res.error) {throw new Error(res.error.message);}
            for (const row of (res.data ?? []) as QuoteDbRow[]) {
              if (!seen.has(row.id)) {
                seen.add(row.id);
                quotes.push(row);
              }
            }
          }
          quotes.sort((a, b) => (b.created_at ?? '').localeCompare(a.created_at ?? ''));
          quotes = quotes.slice(0, RESULT_LIMIT);
        }

        const enriched = await enrichQuotes(quotes);
        if (!cancelled) {setRows(enriched);}
      } catch (e) {
        if (!cancelled) {setError(e instanceof Error ? e.message : 'Failed to load quotes');}
      } finally {
        if (!cancelled) {setLoading(false);}
      }
    })();

    return () => { cancelled = true; };
  }, [activeOrganizationId, debounced]);

  const handleDownload = async (row: QuoteResultRow) => {
    if (downloadingId) {return;}
    setDownloadingId(row.id);
    try {
      const result = await exportQuotePartsExcel(row.id);
      if (!result.ok) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Part list export failed',
          message: result.error ?? 'Unknown error',
        });
      } else if (result.error) {
        useUIStore.getState().addNotification({
          type: 'warning',
          title: 'Part list downloaded with warnings',
          message: result.error,
        });
      }
    } finally {
      setDownloadingId(null);
    }
  };

  const emptyMessage = useMemo(() => {
    if (debounced.length >= 2) {return `No quotes match "${debounced}"`;}
    return 'No quotes found for this organization';
  }, [debounced]);

  return (
    <div className="py-6 px-6 space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Parts</h1>
          <p className="text-xs text-gray-500">
            Download the quoted part list (despiece) of any job — even before an MO exists — to project purchases
          </p>
        </div>
      </div>

      {/* Search */}
      <div className="bg-white border border-gray-200 py-6 px-6 rounded-lg">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by quote number, SO number, dealer, or customer..."
            className="w-full pl-9 pr-3 py-2 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
          />
        </div>
        <p className="mt-2 text-xs text-gray-400">
          The Excel reflects the quoted despiece. Fabric shows linear meters and nested roll purchase; custom lines are listed without parts.
        </p>
      </div>

      {/* Results */}
      {loading ? (
        <div className="animate-pulse space-y-3">
          {[0, 1, 2].map((i) => <div key={i} className="h-14 bg-gray-100 rounded-lg" />)}
        </div>
      ) : error ? (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">{error}</div>
      ) : rows.length === 0 ? (
        <div className="rounded-lg border border-gray-200 bg-white p-8 text-center">
          <ListTree className="w-10 h-10 text-gray-300 mx-auto mb-2" />
          <p className="text-sm text-gray-500">{emptyMessage}</p>
        </div>
      ) : (
        <div className="rounded-lg border border-gray-200 bg-white overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 text-left text-xs font-medium text-gray-500 uppercase tracking-wide">
                <th className="px-4 py-2.5">Quote</th>
                <th className="px-4 py-2.5">Created</th>
                <th className="px-4 py-2.5">Status</th>
                <th className="px-4 py-2.5">Dealer</th>
                <th className="px-4 py-2.5">Customer</th>
                <th className="px-4 py-2.5">Sales Order</th>
                <th className="px-4 py-2.5 text-center">MO</th>
                <th className="px-4 py-2.5 text-right">Part List</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.id} className="border-t border-gray-100 hover:bg-gray-50">
                  <td className="px-4 py-2.5">
                    <span className="font-semibold text-primary">{row.quote_no ?? row.id.slice(0, 8)}</span>
                    {row.is_version && row.version_no !== null && (
                      <span className="ml-1.5 text-xs text-gray-400">v{row.version_no}</span>
                    )}
                  </td>
                  <td className="px-4 py-2.5 text-gray-600">
                    {row.created_at ? formatDate(row.created_at) : '—'}
                  </td>
                  <td className="px-4 py-2.5">
                    <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-700 capitalize">
                      {row.status ?? '—'}
                    </span>
                  </td>
                  <td className="px-4 py-2.5 text-gray-600">{row.dealer_name ?? '—'}</td>
                  <td className="px-4 py-2.5 text-gray-600">{row.customer_name ?? '—'}</td>
                  <td className="px-4 py-2.5 text-gray-600">{row.sales_order_no ?? '—'}</td>
                  <td className="px-4 py-2.5 text-center">
                    {row.has_mo ? (
                      <span
                        className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-800"
                        title="An MO exists for this job. The Excel reflects the quoted despiece, not production substitutions."
                      >
                        MO exists
                      </span>
                    ) : (
                      <span className="text-xs text-gray-400">—</span>
                    )}
                  </td>
                  <td className="px-4 py-2.5 text-right">
                    <button
                      type="button"
                      onClick={() => handleDownload(row)}
                      disabled={downloadingId !== null}
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg text-primary bg-primary/10 hover:bg-primary/20 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {downloadingId === row.id ? (
                        <Loader2 className="w-3.5 h-3.5 animate-spin" />
                      ) : (
                        <Download className="w-3.5 h-3.5" />
                      )}
                      <FileSpreadsheet className="w-3.5 h-3.5" />
                      Excel
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
