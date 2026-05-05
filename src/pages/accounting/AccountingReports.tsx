import { useEffect, useMemo, useState } from 'react';
import {
  useTrialBalance,
  useGeneralLedger,
  useProfitLoss,
  useBalanceSheet,
  useAccountsList,
  type AccountType,
} from '../../hooks/useAccounting';
import { formatCurrency } from '../../lib/utils';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { ACCOUNTING_GROUP_TABS } from './accountingSubmodules';

type ReportTab = 'trial-balance' | 'general-ledger' | 'profit-loss' | 'balance-sheet';

const TYPE_BADGE: Record<AccountType, string> = {
  ASSET: 'bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-300',
  LIABILITY: 'bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300',
  EQUITY: 'bg-purple-100 text-purple-800 dark:bg-purple-900/40 dark:text-purple-300',
  INCOME: 'bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-300',
  COGS: 'bg-orange-100 text-orange-800 dark:bg-orange-900/40 dark:text-orange-300',
  EXPENSE: 'bg-rose-100 text-rose-800 dark:bg-rose-900/40 dark:text-rose-300',
};

export default function AccountingReports() {
  const { registerSubmodules } = useSubmoduleNav();
  const [tab, setTab] = useState<ReportTab>('trial-balance');

  useEffect(() => {
    registerSubmodules('Accounting', ACCOUNTING_GROUP_TABS);
  }, [registerSubmodules]);

  return (
    <div className="space-y-4 p-6">
      <div>
        <h1 className="text-2xl font-semibold">Accounting Reports</h1>
        <p className="text-sm text-muted-foreground">Trial Balance, General Ledger, P&L, Balance Sheet</p>
      </div>

      <div className="flex gap-1 border-b border-border">
        {([
          ['trial-balance', 'Trial Balance'],
          ['general-ledger', 'General Ledger'],
          ['profit-loss', 'Profit & Loss'],
          ['balance-sheet', 'Balance Sheet'],
        ] as [ReportTab, string][]).map(([id, label]) => (
          <button
            key={id}
            onClick={() => setTab(id)}
            className={`px-4 py-2 text-sm font-medium border-b-2 transition ${
              tab === id
                ? 'border-primary text-primary'
                : 'border-transparent text-muted-foreground hover:text-foreground'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      <div>
        {tab === 'trial-balance' && <TrialBalancePanel />}
        {tab === 'general-ledger' && <GeneralLedgerPanel />}
        {tab === 'profit-loss' && <ProfitLossPanel />}
        {tab === 'balance-sheet' && <BalanceSheetPanel />}
      </div>
    </div>
  );
}

function TrialBalancePanel() {
  const today = new Date().toISOString().slice(0, 10);
  const [asOf, setAsOf] = useState(today);
  const { data, isLoading, error } = useTrialBalance(asOf);

  const totals = useMemo(() => {
    if (!data) return { debit: 0, credit: 0 };
    return {
      debit: data.reduce((s, r) => s + Number(r.total_debit || 0), 0),
      credit: data.reduce((s, r) => s + Number(r.total_credit || 0), 0),
    };
  }, [data]);

  return (
    <div className="space-y-3">
      <div className="flex items-center gap-3">
        <label className="text-sm text-muted-foreground">As of:</label>
        <input
          type="date"
          value={asOf}
          onChange={(e) => setAsOf(e.target.value)}
          className="rounded-lg border border-border bg-background px-3 py-1.5 text-sm"
        />
      </div>

      {isLoading && <div className="text-sm text-muted-foreground">Calculando…</div>}
      {error && <ErrorBox msg={(error as Error).message} />}

      <div className="rounded-xl border border-border bg-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-muted/30 text-muted-foreground">
              <tr>
                <th className="text-left px-3 py-2 font-medium w-24">Code</th>
                <th className="text-left px-3 py-2 font-medium">Account</th>
                <th className="text-left px-3 py-2 font-medium w-24">Type</th>
                <th className="text-right px-3 py-2 font-medium w-32">Debit</th>
                <th className="text-right px-3 py-2 font-medium w-32">Credit</th>
                <th className="text-right px-3 py-2 font-medium w-32">Balance</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {data?.length === 0 && !isLoading && (
                <tr>
                  <td colSpan={6} className="px-3 py-6 text-center text-muted-foreground">
                    Sin movimientos contables hasta esta fecha.
                  </td>
                </tr>
              )}
              {(data ?? []).map((r) => (
                <tr key={r.account_id} className="hover:bg-muted/40">
                  <td className="px-3 py-2 font-mono text-xs">{r.code}</td>
                  <td className="px-3 py-2">{r.name}</td>
                  <td className="px-3 py-2">
                    <span className={`rounded px-2 py-0.5 text-xs ${TYPE_BADGE[r.account_type]}`}>{r.account_type}</span>
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatCurrency(r.total_debit)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatCurrency(r.total_credit)}</td>
                  <td className="px-3 py-2 text-right tabular-nums font-medium">{formatCurrency(r.balance)}</td>
                </tr>
              ))}
            </tbody>
            {data && data.length > 0 && (
              <tfoot className="bg-muted/20 font-medium">
                <tr>
                  <td colSpan={3} className="px-3 py-2 text-right">Totales</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatCurrency(totals.debit)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatCurrency(totals.credit)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {Math.abs(totals.debit - totals.credit) < 0.01 ? (
                      <span className="text-green-700 dark:text-green-400">✓ Balanceado</span>
                    ) : (
                      <span className="text-rose-700 dark:text-rose-400">
                        Δ {formatCurrency(Math.abs(totals.debit - totals.credit))}
                      </span>
                    )}
                  </td>
                </tr>
              </tfoot>
            )}
          </table>
        </div>
      </div>
    </div>
  );
}

function GeneralLedgerPanel() {
  const today = new Date().toISOString().slice(0, 10);
  const monthAgo = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString().slice(0, 10);
  const [from, setFrom] = useState(monthAgo);
  const [to, setTo] = useState(today);
  const [accountId, setAccountId] = useState<string>('');

  const accounts = useAccountsList();
  const { data, isLoading, error } = useGeneralLedger(accountId || null, from, to);

  return (
    <div className="space-y-3">
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <select
          value={accountId}
          onChange={(e) => setAccountId(e.target.value)}
          className="rounded-lg border border-border bg-background px-3 py-2 text-sm"
        >
          <option value="">Todas las cuentas</option>
          {(accounts.data ?? []).map((acc) => (
            <option key={acc.id} value={acc.id}>
              {acc.code} · {acc.name}
            </option>
          ))}
        </select>
        <input
          type="date"
          value={from}
          onChange={(e) => setFrom(e.target.value)}
          className="rounded-lg border border-border bg-background px-3 py-2 text-sm"
        />
        <input
          type="date"
          value={to}
          onChange={(e) => setTo(e.target.value)}
          className="rounded-lg border border-border bg-background px-3 py-2 text-sm"
        />
      </div>

      {isLoading && <div className="text-sm text-muted-foreground">Calculando…</div>}
      {error && <ErrorBox msg={(error as Error).message} />}

      <div className="rounded-xl border border-border bg-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-muted/30 text-muted-foreground">
              <tr>
                <th className="text-left px-3 py-2 font-medium">Account</th>
                <th className="text-left px-3 py-2 font-medium w-28">Date</th>
                <th className="text-left px-3 py-2 font-medium w-28">JE#</th>
                <th className="text-left px-3 py-2 font-medium">Description</th>
                <th className="text-right px-3 py-2 font-medium w-28">Debit</th>
                <th className="text-right px-3 py-2 font-medium w-28">Credit</th>
                <th className="text-right px-3 py-2 font-medium w-32">Running</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {data?.length === 0 && !isLoading && (
                <tr>
                  <td colSpan={7} className="px-3 py-6 text-center text-muted-foreground">
                    Sin movimientos en este rango.
                  </td>
                </tr>
              )}
              {(data ?? []).map((r, idx) => (
                <tr key={`${r.journal_entry_id}-${r.line_no}-${idx}`} className="hover:bg-muted/40">
                  <td className="px-3 py-2 text-xs">
                    <div className="font-mono">{r.account_code}</div>
                    <div className="text-muted-foreground">{r.account_name}</div>
                  </td>
                  <td className="px-3 py-2 whitespace-nowrap">{r.entry_date}</td>
                  <td className="px-3 py-2 font-mono text-xs">{r.entry_no}</td>
                  <td className="px-3 py-2">
                    {r.line_description || r.description || (
                      <span className="text-muted-foreground">{r.source_type}</span>
                    )}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {r.debit > 0 ? formatCurrency(r.debit) : ''}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {r.credit > 0 ? formatCurrency(r.credit) : ''}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums font-medium">
                    {formatCurrency(r.running_balance)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

function ProfitLossPanel() {
  const today = new Date().toISOString().slice(0, 10);
  const yearStart = `${new Date().getFullYear()}-01-01`;
  const [from, setFrom] = useState(yearStart);
  const [to, setTo] = useState(today);
  const { data, isLoading, error } = useProfitLoss(from, to);

  const sections = useMemo(() => {
    const groups = { income: [] as typeof data, cogs: [] as typeof data, expense: [] as typeof data };
    (data ?? []).forEach((r) => {
      if (r.account_type === 'INCOME') groups.income!.push(r);
      else if (r.account_type === 'COGS') groups.cogs!.push(r);
      else if (r.account_type === 'EXPENSE') groups.expense!.push(r);
    });
    const sumIncome = (groups.income ?? []).reduce((s, r) => s + Number(r.amount || 0), 0);
    const sumCogs = (groups.cogs ?? []).reduce((s, r) => s + Number(r.amount || 0), 0);
    const sumExpense = (groups.expense ?? []).reduce((s, r) => s + Number(r.amount || 0), 0);
    const grossProfit = sumIncome - sumCogs;
    const netIncome = grossProfit - sumExpense;
    return { groups, sumIncome, sumCogs, sumExpense, grossProfit, netIncome };
  }, [data]);

  return (
    <div className="space-y-3">
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 max-w-md">
        <div>
          <label className="block text-xs text-muted-foreground mb-1">Desde</label>
          <input
            type="date"
            value={from}
            onChange={(e) => setFrom(e.target.value)}
            className="w-full rounded-lg border border-border bg-background px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label className="block text-xs text-muted-foreground mb-1">Hasta</label>
          <input
            type="date"
            value={to}
            onChange={(e) => setTo(e.target.value)}
            className="w-full rounded-lg border border-border bg-background px-3 py-2 text-sm"
          />
        </div>
      </div>

      {isLoading && <div className="text-sm text-muted-foreground">Calculando…</div>}
      {error && <ErrorBox msg={(error as Error).message} />}

      <div className="rounded-xl border border-border bg-card overflow-hidden">
        <table className="w-full text-sm">
          <PLSection
            label="INGRESOS (Income)"
            rows={sections.groups.income ?? []}
            subtotal={sections.sumIncome}
            color="green"
          />
          <PLSection
            label="COSTO DE VENTAS (COGS)"
            rows={sections.groups.cogs ?? []}
            subtotal={sections.sumCogs}
            color="orange"
            negative
          />
          <tbody>
            <tr className="bg-muted/30 font-medium">
              <td className="px-3 py-2">UTILIDAD BRUTA (Gross Profit)</td>
              <td className="px-3 py-2 text-right tabular-nums">{formatCurrency(sections.grossProfit)}</td>
            </tr>
          </tbody>
          <PLSection
            label="GASTOS OPERATIVOS (Expenses)"
            rows={sections.groups.expense ?? []}
            subtotal={sections.sumExpense}
            color="rose"
            negative
          />
          <tbody>
            <tr className={`font-bold ${sections.netIncome >= 0 ? 'bg-green-50 dark:bg-green-900/20' : 'bg-rose-50 dark:bg-rose-900/20'}`}>
              <td className="px-3 py-3">UTILIDAD NETA (Net Income)</td>
              <td className={`px-3 py-3 text-right tabular-nums ${sections.netIncome >= 0 ? 'text-green-700 dark:text-green-400' : 'text-rose-700 dark:text-rose-400'}`}>
                {formatCurrency(sections.netIncome)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  );
}

function PLSection({
  label,
  rows,
  subtotal,
  color,
  negative,
}: {
  label: string;
  rows: { account_id: string; code: string; name: string; amount: number }[];
  subtotal: number;
  color: 'green' | 'orange' | 'rose';
  negative?: boolean;
}) {
  const colorClass = color === 'green' ? 'text-green-700' : color === 'orange' ? 'text-orange-700' : 'text-rose-700';
  return (
    <tbody>
      <tr className="border-t border-border">
        <td colSpan={2} className={`px-3 pt-3 pb-1 font-semibold ${colorClass}`}>
          {label}
        </td>
      </tr>
      {rows.length === 0 ? (
        <tr>
          <td colSpan={2} className="px-3 py-1 text-xs text-muted-foreground italic">
            Sin movimientos
          </td>
        </tr>
      ) : (
        rows.map((r) => (
          <tr key={r.account_id} className="hover:bg-muted/30">
            <td className="px-3 py-1.5 pl-6 text-sm">
              <span className="font-mono text-xs text-muted-foreground mr-2">{r.code}</span>
              {r.name}
            </td>
            <td className="px-3 py-1.5 text-right tabular-nums text-sm">
              {negative ? '(' : ''}
              {formatCurrency(r.amount)}
              {negative ? ')' : ''}
            </td>
          </tr>
        ))
      )}
      <tr className="border-b border-border">
        <td className="px-3 py-1.5 pl-6 text-sm font-medium">Subtotal {label}</td>
        <td className={`px-3 py-1.5 text-right tabular-nums text-sm font-medium ${colorClass}`}>
          {negative ? '(' : ''}
          {formatCurrency(subtotal)}
          {negative ? ')' : ''}
        </td>
      </tr>
    </tbody>
  );
}

function BalanceSheetPanel() {
  const today = new Date().toISOString().slice(0, 10);
  const [asOf, setAsOf] = useState(today);
  const { data, isLoading, error } = useBalanceSheet(asOf);

  const sections = useMemo(() => {
    const assets = (data ?? []).filter((r) => r.section === '1_ASSET');
    const liabilities = (data ?? []).filter((r) => r.section === '2_LIABILITY');
    const equity = (data ?? []).filter((r) => r.section === '3_EQUITY');
    const sum = (arr: typeof data) => (arr ?? []).reduce((s, r) => s + Number(r.amount || 0), 0);
    return {
      assets,
      liabilities,
      equity,
      sumAssets: sum(assets),
      sumLiab: sum(liabilities),
      sumEquity: sum(equity),
    };
  }, [data]);

  const totalLE = sections.sumLiab + sections.sumEquity;
  const balanced = Math.abs(sections.sumAssets - totalLE) < 0.01;

  return (
    <div className="space-y-3">
      <div className="flex items-center gap-3">
        <label className="text-sm text-muted-foreground">As of:</label>
        <input
          type="date"
          value={asOf}
          onChange={(e) => setAsOf(e.target.value)}
          className="rounded-lg border border-border bg-background px-3 py-1.5 text-sm"
        />
      </div>

      {isLoading && <div className="text-sm text-muted-foreground">Calculando…</div>}
      {error && <ErrorBox msg={(error as Error).message} />}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="rounded-xl border border-border bg-card overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-muted/30">
              <tr>
                <th className="text-left px-3 py-2 font-semibold text-blue-700 dark:text-blue-400">ACTIVOS (Assets)</th>
                <th className="text-right px-3 py-2 font-medium w-32">Amount</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {sections.assets.length === 0 && (
                <tr>
                  <td colSpan={2} className="px-3 py-3 text-center text-muted-foreground italic">Sin activos</td>
                </tr>
              )}
              {sections.assets.map((r) => (
                <tr key={r.account_id ?? r.code} className="hover:bg-muted/30">
                  <td className="px-3 py-1.5">
                    <span className="font-mono text-xs text-muted-foreground mr-2">{r.code}</span>
                    {r.name}
                  </td>
                  <td className="px-3 py-1.5 text-right tabular-nums">{formatCurrency(r.amount)}</td>
                </tr>
              ))}
            </tbody>
            <tfoot className="bg-muted/20 font-bold">
              <tr>
                <td className="px-3 py-2">TOTAL ACTIVOS</td>
                <td className="px-3 py-2 text-right tabular-nums">{formatCurrency(sections.sumAssets)}</td>
              </tr>
            </tfoot>
          </table>
        </div>

        <div className="rounded-xl border border-border bg-card overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-muted/30">
              <tr>
                <th className="text-left px-3 py-2 font-semibold text-amber-700 dark:text-amber-400">PASIVOS (Liabilities)</th>
                <th className="text-right px-3 py-2 font-medium w-32">Amount</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {sections.liabilities.length === 0 && (
                <tr>
                  <td colSpan={2} className="px-3 py-3 text-center text-muted-foreground italic">Sin pasivos</td>
                </tr>
              )}
              {sections.liabilities.map((r) => (
                <tr key={r.account_id ?? r.code} className="hover:bg-muted/30">
                  <td className="px-3 py-1.5">
                    <span className="font-mono text-xs text-muted-foreground mr-2">{r.code}</span>
                    {r.name}
                  </td>
                  <td className="px-3 py-1.5 text-right tabular-nums">{formatCurrency(r.amount)}</td>
                </tr>
              ))}
            </tbody>
            <tfoot className="bg-muted/20">
              <tr className="font-medium">
                <td className="px-3 py-1.5">Total Pasivos</td>
                <td className="px-3 py-1.5 text-right tabular-nums">{formatCurrency(sections.sumLiab)}</td>
              </tr>
            </tfoot>
            <thead className="bg-muted/30">
              <tr>
                <th className="text-left px-3 py-2 font-semibold text-purple-700 dark:text-purple-400">PATRIMONIO (Equity)</th>
                <th />
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {sections.equity.length === 0 && (
                <tr>
                  <td colSpan={2} className="px-3 py-3 text-center text-muted-foreground italic">Sin patrimonio</td>
                </tr>
              )}
              {sections.equity.map((r) => (
                <tr key={r.account_id ?? r.code} className="hover:bg-muted/30">
                  <td className="px-3 py-1.5">
                    <span className="font-mono text-xs text-muted-foreground mr-2">{r.code}</span>
                    {r.name}
                  </td>
                  <td className="px-3 py-1.5 text-right tabular-nums">{formatCurrency(r.amount)}</td>
                </tr>
              ))}
            </tbody>
            <tfoot className="bg-muted/20">
              <tr className="font-medium">
                <td className="px-3 py-1.5">Total Patrimonio</td>
                <td className="px-3 py-1.5 text-right tabular-nums">{formatCurrency(sections.sumEquity)}</td>
              </tr>
              <tr className="font-bold border-t border-border">
                <td className="px-3 py-2">TOTAL PASIVO + PATRIMONIO</td>
                <td className="px-3 py-2 text-right tabular-nums">{formatCurrency(totalLE)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      <div
        className={`rounded-xl border p-3 text-sm font-medium ${
          balanced
            ? 'border-green-300 bg-green-50 text-green-800 dark:border-green-900/40 dark:bg-green-900/20 dark:text-green-300'
            : 'border-rose-300 bg-rose-50 text-rose-800 dark:border-rose-900/40 dark:bg-rose-900/20 dark:text-rose-300'
        }`}
      >
        {balanced
          ? `✓ Balance Sheet balanceado: Activos = Pasivos + Patrimonio = ${formatCurrency(sections.sumAssets)}`
          : `✗ Diferencia: ${formatCurrency(sections.sumAssets - totalLE)} (Activos: ${formatCurrency(sections.sumAssets)} vs P+P: ${formatCurrency(totalLE)})`}
      </div>
    </div>
  );
}

function ErrorBox({ msg }: { msg: string }) {
  return (
    <div className="rounded-lg border border-red-200 bg-red-50 p-3 text-sm text-red-700 dark:border-red-900/40 dark:bg-red-900/20 dark:text-red-300">
      Error: {msg}
    </div>
  );
}
