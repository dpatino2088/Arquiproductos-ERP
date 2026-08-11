import type { ComponentType, ReactNode } from 'react';
import { Download } from 'lucide-react';
import { formatCurrency } from '../../lib/utils';

/** Recharts v3 tooltip formatter (value may be undefined) — currency. */
export const moneyFormatter = (v: unknown) => formatCurrency(Number(v) || 0);

/** Tooltip formatter for series where only the 'total' key is money. */
export const moneyTotalFormatter = (v: unknown, name: unknown) =>
  String(name) === 'total' ? formatCurrency(Number(v) || 0) : String(v ?? '');

/** Shared palette for all report charts (theme-agnostic, readable on white). */
export const CHART_COLORS = [
  '#2563eb', // blue-600
  '#16a34a', // green-600
  '#f59e0b', // amber-500
  '#dc2626', // red-600
  '#7c3aed', // violet-600
  '#0891b2', // cyan-600
  '#db2777', // pink-600
  '#65a30d', // lime-600
  '#ea580c', // orange-600
  '#475569', // slate-600
];

export function KpiCard({
  title,
  value,
  delta,
  deltaSuffix = 'vs prev period',
  icon: Icon,
  loading,
}: {
  title: string;
  value: string;
  /** Percentage delta vs previous period; null hides the delta row */
  delta?: number | null;
  deltaSuffix?: string;
  icon: ComponentType<{ className?: string }>;
  loading?: boolean;
}) {
  const deltaLabel =
    delta == null ? null : `${delta >= 0 ? '+' : ''}${delta.toFixed(1)}% ${deltaSuffix}`;
  return (
    <div className="bg-white border border-gray-200 rounded-lg p-6 hover:shadow-lg transition-all duration-200 hover:border-primary/20">
      <div className="flex items-center justify-between mb-4">
        <Icon className="h-8 w-8 text-primary" />
        <div className="text-right">
          <div className="text-2xl font-bold text-foreground">{loading ? '...' : value}</div>
          {deltaLabel ? (
            <div className={`text-sm ${delta! >= 0 ? 'text-status-green' : 'text-status-red'}`}>
              {deltaLabel}
            </div>
          ) : null}
        </div>
      </div>
      <div className="text-sm font-medium text-muted-foreground">{title}</div>
    </div>
  );
}

export function Panel({
  title,
  subtitle,
  action,
  children,
}: {
  title: string;
  subtitle?: string;
  action?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="bg-white border border-gray-200 rounded-lg p-6">
      <div className="flex items-start justify-between mb-4">
        <div>
          <h2 className="text-heading font-semibold">{title}</h2>
          {subtitle ? <p className="text-xs text-muted-foreground mt-0.5">{subtitle}</p> : null}
        </div>
        {action}
      </div>
      {children}
    </div>
  );
}

export function EmptyState({ message }: { message: string }) {
  return (
    <div className="py-12 text-center text-sm text-muted-foreground">{message}</div>
  );
}

/** Escape + join rows into a CSV file and trigger a download. */
export function downloadCsv(filename: string, rows: Record<string, unknown>[]) {
  if (!rows.length) return;
  const headers = Object.keys(rows[0]);
  const esc = (v: unknown) => {
    const s = v == null ? '' : String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const lines = [headers.join(','), ...rows.map((r) => headers.map((h) => esc(r[h])).join(','))];
  const blob = new Blob([`\uFEFF${lines.join('\n')}`], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export function CsvButton({
  filename,
  rows,
  disabled,
}: {
  filename: string;
  rows: Record<string, unknown>[];
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={() => downloadCsv(filename, rows)}
      disabled={disabled || rows.length === 0}
      className="inline-flex items-center gap-1.5 text-xs font-medium text-gray-600 border border-gray-200 rounded-md px-2.5 py-1.5 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
      title="Export CSV"
    >
      <Download className="h-3.5 w-3.5" />
      CSV
    </button>
  );
}

/** Minimal report table: column defs + rows, right-aligned numerics. */
export function ReportTable<T extends Record<string, unknown>>({
  columns,
  rows,
  emptyMessage = 'No data for this period',
}: {
  columns: { key: string; label: string; align?: 'left' | 'right'; render?: (row: T) => ReactNode }[];
  rows: T[];
  emptyMessage?: string;
}) {
  if (rows.length === 0) return <EmptyState message={emptyMessage} />;
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-gray-200">
            {columns.map((c) => (
              <th
                key={c.key}
                className={`py-2 px-3 text-xs font-medium tracking-wide text-gray-600 ${c.align === 'right' ? 'text-right' : 'text-left'}`}
              >
                {c.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => (
            <tr key={i} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
              {columns.map((c) => (
                <td
                  key={c.key}
                  className={`py-2 px-3 ${c.align === 'right' ? 'text-right tabular-nums' : 'text-left'}`}
                >
                  {c.render ? c.render(row) : String(row[c.key] ?? '—')}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
