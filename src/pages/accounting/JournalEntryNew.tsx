import { useEffect, useMemo, useState } from 'react';
import { useAccountsList, useAccountingMutations, type ManualJournalLine } from '../../hooks/useAccounting';
import { formatCurrency } from '../../lib/utils';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { ACCOUNTING_GROUP_TABS } from './accountingSubmodules';

interface DraftLine extends ManualJournalLine {
  key: string;
}

function newLine(): DraftLine {
  return {
    key: Math.random().toString(36).slice(2),
    account_id: '',
    description: '',
    debit: 0,
    credit: 0,
  };
}

export default function JournalEntryNew() {
  const { registerSubmodules } = useSubmoduleNav();
  const today = new Date().toISOString().slice(0, 10);
  const [entryDate, setEntryDate] = useState(today);

  useEffect(() => {
    registerSubmodules('Accounting', ACCOUNTING_GROUP_TABS);
  }, [registerSubmodules]);
  const [description, setDescription] = useState('');
  const [lines, setLines] = useState<DraftLine[]>([newLine(), newLine()]);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const { data: accounts, isLoading: accountsLoading } = useAccountsList();
  const { postManualEntry } = useAccountingMutations();

  const totals = useMemo(() => {
    const totalDebit = lines.reduce((s, l) => s + Number(l.debit || 0), 0);
    const totalCredit = lines.reduce((s, l) => s + Number(l.credit || 0), 0);
    const balanced = Math.abs(totalDebit - totalCredit) < 0.005;
    return { totalDebit, totalCredit, balanced };
  }, [lines]);

  const canSubmit =
    !submitting &&
    description.trim().length > 0 &&
    lines.length >= 2 &&
    lines.every((l) => l.account_id) &&
    (totals.totalDebit > 0 || totals.totalCredit > 0) &&
    totals.balanced;

  const updateLine = (idx: number, patch: Partial<DraftLine>) => {
    setLines((prev) => prev.map((l, i) => (i === idx ? { ...l, ...patch } : l)));
  };

  const addLine = () => setLines((prev) => [...prev, newLine()]);
  const removeLine = (idx: number) => {
    setLines((prev) => (prev.length > 2 ? prev.filter((_, i) => i !== idx) : prev));
  };

  const onSubmit = async () => {
    setError(null);
    setSubmitting(true);
    try {
      const payload: ManualJournalLine[] = lines.map((l) => ({
        account_id: l.account_id,
        description: l.description?.trim() || undefined,
        debit: Number(l.debit || 0),
        credit: Number(l.credit || 0),
      }));
      await postManualEntry({
        entry_date: entryDate,
        description: description.trim(),
        lines: payload,
      });
      router.navigate('/accounting/journal');
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-4 p-6 max-w-5xl">
      <div className="flex items-center gap-3">
        <button
          onClick={() => router.navigate('/accounting/journal')}
          className="rounded-lg border border-border px-3 py-1.5 text-sm hover:bg-muted/40"
        >
          ← Volver
        </button>
        <div>
          <h1 className="text-2xl font-semibold">Nuevo Asiento Manual</h1>
          <p className="text-sm text-muted-foreground">Crea un asiento de partida doble. Db = Cr es obligatorio.</p>
        </div>
      </div>

      <div className="rounded-xl border border-border bg-card p-4 space-y-3">
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <div>
            <label className="block text-xs font-medium text-muted-foreground mb-1">Fecha</label>
            <input
              type="date"
              value={entryDate}
              onChange={(e) => setEntryDate(e.target.value)}
              className="w-full rounded-lg border border-border bg-background px-3 py-2 text-sm"
            />
          </div>
          <div className="sm:col-span-2">
            <label className="block text-xs font-medium text-muted-foreground mb-1">Descripción</label>
            <input
              type="text"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Ej: Pago de alquiler de marzo"
              className="w-full rounded-lg border border-border bg-background px-3 py-2 text-sm"
            />
          </div>
        </div>
      </div>

      <div className="rounded-xl border border-border bg-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-muted/30 text-muted-foreground">
              <tr>
                <th className="text-left px-3 py-2 font-medium">Cuenta</th>
                <th className="text-left px-3 py-2 font-medium">Descripción</th>
                <th className="text-right px-3 py-2 font-medium w-32">Debe</th>
                <th className="text-right px-3 py-2 font-medium w-32">Haber</th>
                <th className="w-10" />
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {lines.map((l, idx) => (
                <tr key={l.key}>
                  <td className="px-3 py-2">
                    <select
                      value={l.account_id}
                      onChange={(e) => updateLine(idx, { account_id: e.target.value })}
                      disabled={accountsLoading}
                      className="w-full rounded-lg border border-border bg-background px-2 py-1.5 text-xs"
                    >
                      <option value="">— Selecciona cuenta —</option>
                      {(accounts ?? []).map((acc) => (
                        <option key={acc.id} value={acc.id}>
                          {acc.code} · {acc.name}
                        </option>
                      ))}
                    </select>
                  </td>
                  <td className="px-3 py-2">
                    <input
                      type="text"
                      value={l.description ?? ''}
                      onChange={(e) => updateLine(idx, { description: e.target.value })}
                      placeholder="Descripción opcional"
                      className="w-full rounded-lg border border-border bg-background px-2 py-1.5 text-xs"
                    />
                  </td>
                  <td className="px-3 py-2">
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      value={l.debit || ''}
                      onChange={(e) => {
                        const v = parseFloat(e.target.value) || 0;
                        updateLine(idx, { debit: v, credit: v > 0 ? 0 : l.credit });
                      }}
                      className="w-full rounded-lg border border-border bg-background px-2 py-1.5 text-xs text-right tabular-nums"
                    />
                  </td>
                  <td className="px-3 py-2">
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      value={l.credit || ''}
                      onChange={(e) => {
                        const v = parseFloat(e.target.value) || 0;
                        updateLine(idx, { credit: v, debit: v > 0 ? 0 : l.debit });
                      }}
                      className="w-full rounded-lg border border-border bg-background px-2 py-1.5 text-xs text-right tabular-nums"
                    />
                  </td>
                  <td className="px-2 py-2 text-center">
                    {lines.length > 2 && (
                      <button
                        type="button"
                        onClick={() => removeLine(idx)}
                        className="text-rose-500 hover:text-rose-700 text-xs"
                        title="Eliminar línea"
                      >
                        ✕
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
            <tfoot className="bg-muted/20 font-medium">
              <tr>
                <td colSpan={2} className="px-3 py-2 text-right">Totales</td>
                <td className="px-3 py-2 text-right tabular-nums">{formatCurrency(totals.totalDebit)}</td>
                <td className="px-3 py-2 text-right tabular-nums">{formatCurrency(totals.totalCredit)}</td>
                <td />
              </tr>
              <tr>
                <td colSpan={5} className="px-3 py-2">
                  <div className="flex items-center justify-between">
                    <button
                      type="button"
                      onClick={addLine}
                      className="text-sm text-primary hover:underline"
                    >
                      + Agregar línea
                    </button>
                    <div
                      className={`text-sm font-medium ${
                        totals.balanced ? 'text-green-700 dark:text-green-400' : 'text-rose-700 dark:text-rose-400'
                      }`}
                    >
                      {totals.balanced
                        ? '✓ Balanceado'
                        : `Diferencia: ${formatCurrency(Math.abs(totals.totalDebit - totals.totalCredit))}`}
                    </div>
                  </div>
                </td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-3 text-sm text-red-700 dark:border-red-900/40 dark:bg-red-900/20 dark:text-red-300">
          {error}
        </div>
      )}

      <div className="flex justify-end gap-2">
        <button
          type="button"
          onClick={() => router.navigate('/accounting/journal')}
          className="rounded-lg border border-border px-4 py-2 text-sm hover:bg-muted/40"
        >
          Cancelar
        </button>
        <button
          type="button"
          disabled={!canSubmit}
          onClick={onSubmit}
          className="rounded-lg bg-primary text-primary-foreground px-4 py-2 text-sm font-medium hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {submitting ? 'Posteando…' : 'Postear asiento'}
        </button>
      </div>
    </div>
  );
}
