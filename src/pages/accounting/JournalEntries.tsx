import { useEffect, useMemo, useState } from 'react';
import { useJournalEntriesList, useJournalEntryDetail, useAccountingMutations, type JournalEntry } from '../../hooks/useAccounting';
import { formatCurrency } from '../../lib/utils';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { ACCOUNTING_GROUP_TABS } from './accountingSubmodules';

const STATUS_BADGE: Record<string, string> = {
  posted: 'bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-300',
  draft: 'bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300',
  void: 'bg-rose-100 text-rose-800 dark:bg-rose-900/40 dark:text-rose-300',
};

const SOURCE_TYPES = [
  { value: 'all', label: 'All sources' },
  { value: 'manual', label: 'Manual' },
  { value: 'inventory_movement', label: 'Inventory Movement' },
  { value: 'vendor_bill', label: 'Vendor Bill' },
  { value: 'vendor_payment', label: 'Vendor Payment' },
  { value: 'dealer_invoice', label: 'Sales Invoice' },
  { value: 'customer_payment', label: 'Customer Payment' },
  { value: 'delivery_note', label: 'Delivery (COGS)' },
];

export default function JournalEntries() {
  const { registerSubmodules } = useSubmoduleNav();
  const today = new Date().toISOString().slice(0, 10);
  const monthAgo = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString().slice(0, 10);

  useEffect(() => {
    registerSubmodules('Accounting', ACCOUNTING_GROUP_TABS);
  }, [registerSubmodules]);

  const [q, setQ] = useState('');
  const [status, setStatus] = useState('all');
  const [sourceType, setSourceType] = useState('all');
  const [from, setFrom] = useState(monthAgo);
  const [to, setTo] = useState(today);
  const [page, setPage] = useState(1);
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const list = useJournalEntriesList({
    q,
    status,
    sourceType,
    from,
    to,
    page,
    pageSize: 50,
  });

  const detail = useJournalEntryDetail(selectedId);
  const { voidEntry } = useAccountingMutations();

  const totalPages = useMemo(() => {
    if (!list.data) return 1;
    return Math.max(1, Math.ceil(list.data.total / 50));
  }, [list.data]);

  return (
    <div className="space-y-4 p-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold">Journal Entries</h1>
          <p className="text-sm text-muted-foreground">Diario general — todos los asientos contables (manuales + auto-postings)</p>
        </div>
        <button
          onClick={() => router.navigate('/accounting/journal/new')}
          className="rounded-lg bg-primary text-primary-foreground px-4 py-2 text-sm font-medium hover:opacity-90"
        >
          + Nuevo Asiento
        </button>
      </div>

      <div className="rounded-xl border border-border bg-card p-4">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3">
          <input
            type="search"
            value={q}
            onChange={(e) => {
              setQ(e.target.value);
              setPage(1);
            }}
            placeholder="Buscar JE# o descripción…"
            className="rounded-lg border border-border bg-background px-3 py-2 text-sm"
          />
          <select
            value={status}
            onChange={(e) => {
              setStatus(e.target.value);
              setPage(1);
            }}
            className="rounded-lg border border-border bg-background px-3 py-2 text-sm"
          >
            <option value="all">All status</option>
            <option value="posted">Posted</option>
            <option value="draft">Draft</option>
            <option value="void">Void</option>
          </select>
          <select
            value={sourceType}
            onChange={(e) => {
              setSourceType(e.target.value);
              setPage(1);
            }}
            className="rounded-lg border border-border bg-background px-3 py-2 text-sm"
          >
            {SOURCE_TYPES.map((s) => (
              <option key={s.value} value={s.value}>
                {s.label}
              </option>
            ))}
          </select>
          <input
            type="date"
            value={from}
            onChange={(e) => {
              setFrom(e.target.value);
              setPage(1);
            }}
            className="rounded-lg border border-border bg-background px-3 py-2 text-sm"
          />
          <input
            type="date"
            value={to}
            onChange={(e) => {
              setTo(e.target.value);
              setPage(1);
            }}
            className="rounded-lg border border-border bg-background px-3 py-2 text-sm"
          />
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2 rounded-xl border border-border bg-card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-muted/30 text-muted-foreground">
                <tr>
                  <th className="text-left px-3 py-2 font-medium">JE#</th>
                  <th className="text-left px-3 py-2 font-medium">Date</th>
                  <th className="text-left px-3 py-2 font-medium">Source</th>
                  <th className="text-left px-3 py-2 font-medium">Description</th>
                  <th className="text-right px-3 py-2 font-medium">Total</th>
                  <th className="text-center px-3 py-2 font-medium">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {list.isLoading && (
                  <tr>
                    <td colSpan={6} className="px-3 py-6 text-center text-muted-foreground">
                      Cargando…
                    </td>
                  </tr>
                )}
                {list.error && (
                  <tr>
                    <td colSpan={6} className="px-3 py-6 text-center text-red-700">
                      Error: {(list.error as Error).message}
                    </td>
                  </tr>
                )}
                {list.data?.rows.length === 0 && !list.isLoading && (
                  <tr>
                    <td colSpan={6} className="px-3 py-6 text-center text-muted-foreground">
                      No hay asientos en este rango.
                    </td>
                  </tr>
                )}
                {list.data?.rows.map((je: JournalEntry) => (
                  <tr
                    key={je.id}
                    onClick={() => setSelectedId(je.id)}
                    className={`cursor-pointer transition ${
                      selectedId === je.id ? 'bg-primary/5' : 'hover:bg-muted/40'
                    }`}
                  >
                    <td className="px-3 py-2 font-mono text-xs">{je.entry_no ?? '—'}</td>
                    <td className="px-3 py-2 whitespace-nowrap">{je.entry_date}</td>
                    <td className="px-3 py-2 text-muted-foreground text-xs">{je.source_type ?? '—'}</td>
                    <td className="px-3 py-2 truncate max-w-xs">{je.description ?? '—'}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{formatCurrency(je.total_debit)}</td>
                    <td className="px-3 py-2 text-center">
                      <span className={`inline-block rounded px-2 py-0.5 text-xs ${STATUS_BADGE[je.status] ?? ''}`}>
                        {je.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {list.data && list.data.total > 0 && (
            <div className="flex items-center justify-between px-4 py-3 border-t border-border text-sm">
              <span className="text-muted-foreground">
                {list.data.total} asientos · página {page} de {totalPages}
              </span>
              <div className="flex gap-2">
                <button
                  disabled={page <= 1}
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                  className="rounded border border-border px-2 py-1 disabled:opacity-50 hover:bg-muted/40"
                >
                  ← Prev
                </button>
                <button
                  disabled={page >= totalPages}
                  onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                  className="rounded border border-border px-2 py-1 disabled:opacity-50 hover:bg-muted/40"
                >
                  Next →
                </button>
              </div>
            </div>
          )}
        </div>

        <div className="rounded-xl border border-border bg-card p-4 max-h-[80vh] overflow-y-auto">
          {!selectedId ? (
            <div className="text-sm text-muted-foreground text-center py-8">
              Selecciona un asiento para ver el detalle.
            </div>
          ) : detail.isLoading ? (
            <div className="text-sm text-muted-foreground">Cargando detalle…</div>
          ) : !detail.data ? (
            <div className="text-sm text-muted-foreground">Asiento no encontrado.</div>
          ) : (
            <div className="space-y-3">
              <div className="flex items-start justify-between gap-2">
                <div>
                  <div className="font-mono text-sm">{detail.data.entry_no}</div>
                  <div className="text-xs text-muted-foreground">{detail.data.entry_date}</div>
                </div>
                <span className={`rounded px-2 py-0.5 text-xs ${STATUS_BADGE[detail.data.status] ?? ''}`}>
                  {detail.data.status}
                </span>
              </div>
              <div className="text-sm">{detail.data.description ?? '—'}</div>
              <div className="text-xs text-muted-foreground">
                Source: {detail.data.source_type ?? 'manual'}
              </div>

              <div className="rounded-lg border border-border overflow-hidden">
                <table className="w-full text-xs">
                  <thead className="bg-muted/30">
                    <tr>
                      <th className="text-left px-2 py-1.5 font-medium">Account</th>
                      <th className="text-right px-2 py-1.5 font-medium">Debit</th>
                      <th className="text-right px-2 py-1.5 font-medium">Credit</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {(detail.data.lines ?? []).map((l) => (
                      <tr key={l.id}>
                        <td className="px-2 py-1.5">
                          <div className="font-mono text-[10px] text-muted-foreground">{l.account?.code}</div>
                          <div>{l.account?.name}</div>
                          {l.description && <div className="text-[10px] text-muted-foreground">{l.description}</div>}
                        </td>
                        <td className="px-2 py-1.5 text-right tabular-nums">
                          {l.debit_base > 0 ? formatCurrency(l.debit_base) : ''}
                        </td>
                        <td className="px-2 py-1.5 text-right tabular-nums">
                          {l.credit_base > 0 ? formatCurrency(l.credit_base) : ''}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                  <tfoot className="bg-muted/20 font-medium">
                    <tr>
                      <td className="px-2 py-1.5">Total</td>
                      <td className="px-2 py-1.5 text-right tabular-nums">
                        {formatCurrency(detail.data.total_debit)}
                      </td>
                      <td className="px-2 py-1.5 text-right tabular-nums">
                        {formatCurrency(detail.data.total_credit)}
                      </td>
                    </tr>
                  </tfoot>
                </table>
              </div>

              {detail.data.status === 'posted' && (
                <button
                  onClick={async () => {
                    const reason = prompt('Razón de anulación:');
                    if (!reason) return;
                    try {
                      await voidEntry(detail.data!.id, reason);
                      setSelectedId(null);
                    } catch (e) {
                      alert(`Error: ${(e as Error).message}`);
                    }
                  }}
                  className="w-full rounded-lg border border-rose-300 bg-rose-50 text-rose-700 px-3 py-2 text-sm font-medium hover:bg-rose-100 dark:border-rose-900/40 dark:bg-rose-900/20 dark:text-rose-300"
                >
                  Anular asiento
                </button>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
