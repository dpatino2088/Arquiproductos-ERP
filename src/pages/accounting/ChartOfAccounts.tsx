import { useEffect, useMemo, useState } from 'react';
import { useAccountsList, type Account, type AccountType } from '../../hooks/useAccounting';
import { formatCurrency } from '../../lib/utils';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { ACCOUNTING_GROUP_TABS } from './accountingSubmodules';

const TYPE_LABELS: Record<AccountType, string> = {
  ASSET: 'Asset',
  LIABILITY: 'Liability',
  EQUITY: 'Equity',
  INCOME: 'Income',
  COGS: 'COGS',
  EXPENSE: 'Expense',
};

const TYPE_BADGE_COLOR: Record<AccountType, string> = {
  ASSET: 'bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-300',
  LIABILITY: 'bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300',
  EQUITY: 'bg-purple-100 text-purple-800 dark:bg-purple-900/40 dark:text-purple-300',
  INCOME: 'bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-300',
  COGS: 'bg-orange-100 text-orange-800 dark:bg-orange-900/40 dark:text-orange-300',
  EXPENSE: 'bg-rose-100 text-rose-800 dark:bg-rose-900/40 dark:text-rose-300',
};

const TYPE_ORDER: AccountType[] = ['ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'COGS', 'EXPENSE'];

export default function ChartOfAccounts() {
  const { registerSubmodules } = useSubmoduleNav();
  const { data: accounts, isLoading, error } = useAccountsList();
  const [q, setQ] = useState('');
  const [typeFilter, setTypeFilter] = useState<'all' | AccountType>('all');

  useEffect(() => {
    registerSubmodules('Accounting', ACCOUNTING_GROUP_TABS);
  }, [registerSubmodules]);

  const grouped = useMemo(() => {
    const byType = new Map<AccountType, Account[]>();
    TYPE_ORDER.forEach((t) => byType.set(t, []));
    (accounts ?? []).forEach((acc) => {
      if (typeFilter !== 'all' && acc.account_type !== typeFilter) return;
      if (q) {
        const term = q.toLowerCase();
        if (
          !acc.code.toLowerCase().includes(term) &&
          !acc.name.toLowerCase().includes(term)
        )
          return;
      }
      byType.get(acc.account_type)?.push(acc);
    });
    return byType;
  }, [accounts, q, typeFilter]);

  const summary = useMemo(() => {
    const stats = TYPE_ORDER.map((type) => ({
      type,
      label: TYPE_LABELS[type],
      count: (accounts ?? []).filter((a) => a.account_type === type).length,
    }));
    return stats;
  }, [accounts]);

  return (
    <div className="space-y-4 p-6">
      <div>
        <h1 className="text-2xl font-semibold">Chart of Accounts</h1>
        <p className="text-sm text-muted-foreground">Plan de cuentas contable de la organización</p>
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
        {summary.map((s) => (
          <button
            key={s.type}
            onClick={() => setTypeFilter(typeFilter === s.type ? 'all' : s.type)}
            className={`rounded-xl border p-3 text-left transition ${
              typeFilter === s.type
                ? 'border-primary bg-primary/5 shadow-sm'
                : 'border-border hover:border-primary/50 bg-card'
            }`}
          >
            <div className="text-xs text-muted-foreground">{s.label}</div>
            <div className="text-2xl font-semibold mt-1">{s.count}</div>
          </button>
        ))}
      </div>

      <div className="flex items-center gap-3">
        <input
          type="search"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Buscar por código o nombre…"
          className="flex-1 max-w-md rounded-lg border border-border bg-background px-3 py-2 text-sm"
        />
        {(q || typeFilter !== 'all') && (
          <button
            onClick={() => {
              setQ('');
              setTypeFilter('all');
            }}
            className="text-sm text-muted-foreground hover:text-foreground"
          >
            Limpiar
          </button>
        )}
      </div>

      {isLoading && (
        <div className="text-sm text-muted-foreground">Cargando cuentas…</div>
      )}
      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-3 text-sm text-red-700 dark:border-red-900/40 dark:bg-red-900/20 dark:text-red-300">
          Error: {(error as Error).message}
        </div>
      )}

      <div className="space-y-6">
        {TYPE_ORDER.map((type) => {
          const rows = grouped.get(type) ?? [];
          if (rows.length === 0) return null;
          return (
            <section key={type} className="rounded-xl border border-border bg-card overflow-hidden">
              <header className="flex items-center justify-between px-4 py-3 border-b border-border">
                <div className="flex items-center gap-2">
                  <span className={`rounded px-2 py-0.5 text-xs font-medium ${TYPE_BADGE_COLOR[type]}`}>
                    {TYPE_LABELS[type]}
                  </span>
                  <span className="text-sm text-muted-foreground">{rows.length} cuentas</span>
                </div>
              </header>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-muted/30 text-muted-foreground">
                    <tr>
                      <th className="text-left px-4 py-2 font-medium w-24">Code</th>
                      <th className="text-left px-4 py-2 font-medium">Name</th>
                      <th className="text-left px-4 py-2 font-medium w-24">Currency</th>
                      <th className="text-right px-4 py-2 font-medium w-32">Opening</th>
                      <th className="text-center px-4 py-2 font-medium w-20">System</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {rows.map((acc) => (
                      <tr key={acc.id} className="hover:bg-muted/40 transition">
                        <td className="px-4 py-2 font-mono text-xs">{acc.code}</td>
                        <td className="px-4 py-2">{acc.name}</td>
                        <td className="px-4 py-2 text-muted-foreground">{acc.currency}</td>
                        <td className="px-4 py-2 text-right tabular-nums">
                          {acc.opening_balance ? formatCurrency(acc.opening_balance, acc.currency) : '—'}
                        </td>
                        <td className="px-4 py-2 text-center">
                          {acc.is_system && (
                            <span className="text-xs text-muted-foreground">●</span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          );
        })}
      </div>
    </div>
  );
}
