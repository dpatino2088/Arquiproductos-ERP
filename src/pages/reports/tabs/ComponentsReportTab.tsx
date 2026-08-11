import { useMemo } from 'react';
import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { Cog, DollarSign, Puzzle } from 'lucide-react';
import { useReport, type ComponentConsumptionReport, type ReportDateRange } from '../../../hooks/useReports';
import { formatCurrency } from '../../../lib/utils';
import { CHART_COLORS, CsvButton, EmptyState, KpiCard, moneyFormatter, Panel, ReportTable } from '../reportUi';

const roleLabel = (role: string | null | undefined) =>
  String(role ?? 'other').replace(/_/g, ' ');

export default function ComponentsReportTab({ range, active }: { range: ReportDateRange; active: boolean }) {
  const { data, isInitialLoading, isRefreshing, error } = useReport<ComponentConsumptionReport>(
    'components',
    range,
    { enabled: active }
  );

  const byRole = data?.by_role ?? [];
  const topComponents = data?.top_components ?? [];
  const accessories = data?.accessories ?? [];
  const totalCost = byRole.reduce((s, r) => s + r.cost, 0);
  const topRole = byRole[0];

  const roleChart = useMemo(
    () =>
      byRole.slice(0, 12).map((r) => ({
        name: roleLabel(r.part_role),
        cost: r.cost,
      })),
    [byRole]
  );

  const componentsCsv = useMemo(
    () =>
      topComponents.map((c) => ({
        part_role: c.part_role ?? '',
        sku: c.sku ?? '',
        name: c.name ?? '',
        qty: c.qty,
        uom: c.uom ?? '',
        cost: c.cost,
        orders: c.orders_count,
      })),
    [topComponents]
  );

  return (
    <div className="space-y-6">
      {error ? <p className="text-xs text-status-red">Report error: {error}</p> : null}
      {isRefreshing ? <p className="text-xs text-muted-foreground">Updating…</p> : null}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <KpiCard
          title="Component Cost (sold orders)"
          value={formatCurrency(totalCost)}
          icon={DollarSign}
          loading={isInitialLoading}
        />
        <KpiCard
          title="Top Role by Cost"
          value={topRole ? `${roleLabel(topRole.part_role)} · ${formatCurrency(topRole.cost)}` : '—'}
          icon={Cog}
          loading={isInitialLoading}
        />
        <KpiCard
          title="Distinct Components"
          value={String(topComponents.length)}
          icon={Puzzle}
          loading={isInitialLoading}
        />
      </div>

      <Panel title="Cost by Component Role" subtitle="Motors, fabrics, tubes, brackets… from the BOM of sold orders">
        {roleChart.length === 0 ? (
          <EmptyState message="No BOM consumption in this period" />
        ) : (
          <ResponsiveContainer width="100%" height={Math.max(220, roleChart.length * 32)}>
            <BarChart data={roleChart} layout="vertical" margin={{ top: 4, right: 24, bottom: 4, left: 8 }}>
              <CartesianGrid strokeDasharray="3 3" horizontal={false} stroke="#f1f5f9" />
              <XAxis
                type="number"
                tick={{ fontSize: 11 }}
                tickLine={false}
                axisLine={false}
                tickFormatter={(v: number) => `$${v >= 1000 ? `${(v / 1000).toFixed(1)}k` : v}`}
              />
              <YAxis type="category" dataKey="name" width={130} tick={{ fontSize: 11 }} tickLine={false} axisLine={false} />
              <Tooltip formatter={moneyFormatter} />
              <Bar dataKey="cost" fill={CHART_COLORS[4]} radius={[0, 4, 4, 0]} barSize={18} />
            </BarChart>
          </ResponsiveContainer>
        )}
      </Panel>

      <Panel
        title="Top Components"
        subtitle="By cost consumed in sold orders (top 30)"
        action={<CsvButton filename={`components-${range.from}-${range.to}.csv`} rows={componentsCsv} />}
      >
        <ReportTable
          columns={[
            {
              key: 'part_role',
              label: 'Role',
              render: (r) => (
                <span className="inline-block text-xs font-medium bg-gray-100 text-gray-700 rounded px-2 py-0.5 capitalize">
                  {roleLabel(r.part_role as string)}
                </span>
              ),
            },
            { key: 'sku', label: 'SKU', render: (r) => <span className="font-mono text-xs">{String(r.sku ?? '—')}</span> },
            { key: 'name', label: 'Component', render: (r) => String(r.name ?? '—') },
            {
              key: 'qty',
              label: 'Qty',
              align: 'right',
              render: (r) => `${r.qty} ${String(r.uom ?? '')}`.trim(),
            },
            { key: 'orders_count', label: 'Orders', align: 'right' },
            {
              key: 'cost',
              label: 'Cost',
              align: 'right',
              render: (r) => <span className="font-medium">{formatCurrency(Number(r.cost) || 0)}</span>,
            },
          ]}
          rows={topComponents as unknown as Record<string, unknown>[]}
          emptyMessage="No BOM consumption in this period"
        />
      </Panel>

      <Panel title="Top Accessories" subtitle="Accessory components attached to sold quote lines">
        <ReportTable
          columns={[
            { key: 'sku', label: 'SKU', render: (r) => <span className="font-mono text-xs">{String(r.sku ?? '—')}</span> },
            { key: 'name', label: 'Accessory', render: (r) => String(r.name ?? '—') },
            { key: 'qty', label: 'Qty', align: 'right' },
            { key: 'orders_count', label: 'Orders', align: 'right' },
          ]}
          rows={accessories as unknown as Record<string, unknown>[]}
          emptyMessage="No accessories in this period"
        />
      </Panel>
    </div>
  );
}
