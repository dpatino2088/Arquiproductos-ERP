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
import { Building2, DollarSign, Percent, Trophy } from 'lucide-react';
import { useReport, type DealerRankingReport, type ReportDateRange } from '../../../hooks/useReports';
import { formatCurrency } from '../../../lib/utils';
import { CHART_COLORS, CsvButton, EmptyState, KpiCard, moneyFormatter, Panel, ReportTable } from '../reportUi';

export default function DealersReportTab({ range, active }: { range: ReportDateRange; active: boolean }) {
  const { data, isInitialLoading, isRefreshing, error } = useReport<DealerRankingReport>(
    'dealers',
    range,
    { enabled: active }
  );

  const dealers = data ?? [];
  const withSales = dealers.filter((d) => d.sales_total > 0);
  const totalSales = withSales.reduce((s, d) => s + d.sales_total, 0);
  const topDealer = withSales[0];
  const marginRows = withSales.filter((d) => d.margin_pct != null);
  const avgMargin =
    marginRows.length > 0
      ? marginRows.reduce((s, d) => s + (d.margin_pct ?? 0), 0) / marginRows.length
      : null;

  const chartData = useMemo(
    () =>
      withSales.slice(0, 10).map((d) => ({
        name: d.dealer_name.length > 22 ? `${d.dealer_name.slice(0, 22)}…` : d.dealer_name,
        sales: d.sales_total,
      })),
    [data]
  );

  const csvRows = useMemo(
    () =>
      dealers.map((d) => ({
        dealer: d.dealer_name,
        dealer_no: d.dealer_no ?? '',
        quotes: d.quotes_count,
        orders: d.orders_count,
        conversion_pct: d.conversion_pct ?? '',
        sales_total: d.sales_total,
        margin_pct: d.margin_pct ?? '',
      })),
    [dealers]
  );

  return (
    <div className="space-y-6">
      {error ? <p className="text-xs text-status-red">Report error: {error}</p> : null}
      {isRefreshing ? <p className="text-xs text-muted-foreground">Updating…</p> : null}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <KpiCard
          title="Active Dealers (with sales)"
          value={String(withSales.length)}
          icon={Building2}
          loading={isInitialLoading}
        />
        <KpiCard
          title="Top Dealer"
          value={topDealer ? topDealer.dealer_name : '—'}
          icon={Trophy}
          loading={isInitialLoading}
        />
        <KpiCard
          title="Avg Sales per Dealer"
          value={formatCurrency(withSales.length > 0 ? totalSales / withSales.length : 0)}
          icon={DollarSign}
          loading={isInitialLoading}
        />
        <KpiCard
          title="Avg Margin"
          value={avgMargin != null ? `${avgMargin.toFixed(1)}%` : '—'}
          icon={Percent}
          loading={isInitialLoading}
        />
      </div>

      <Panel title="Top Dealers by Sales" subtitle="Sales Orders total in the period">
        {chartData.length === 0 ? (
          <EmptyState message="No dealer sales in this period" />
        ) : (
          <ResponsiveContainer width="100%" height={Math.max(220, chartData.length * 40)}>
            <BarChart data={chartData} layout="vertical" margin={{ top: 4, right: 24, bottom: 4, left: 8 }}>
              <CartesianGrid strokeDasharray="3 3" horizontal={false} stroke="#f1f5f9" />
              <XAxis
                type="number"
                tick={{ fontSize: 11 }}
                tickLine={false}
                axisLine={false}
                tickFormatter={(v: number) => `$${v >= 1000 ? `${(v / 1000).toFixed(0)}k` : v}`}
              />
              <YAxis type="category" dataKey="name" width={170} tick={{ fontSize: 11 }} tickLine={false} axisLine={false} />
              <Tooltip formatter={moneyFormatter} />
              <Bar dataKey="sales" fill={CHART_COLORS[0]} radius={[0, 4, 4, 0]} barSize={20} />
            </BarChart>
          </ResponsiveContainer>
        )}
      </Panel>

      <Panel
        title="Dealer Ranking"
        subtitle="Quotes, orders, conversion and margin per dealer"
        action={<CsvButton filename={`dealers-${range.from}-${range.to}.csv`} rows={csvRows} />}
      >
        <ReportTable
          columns={[
            {
              key: 'dealer_name',
              label: 'Dealer',
              render: (d) => (
                <div>
                  <span className="font-medium">{String(d.dealer_name)}</span>
                  {d.dealer_no ? <span className="text-xs text-muted-foreground ml-2">#{String(d.dealer_no)}</span> : null}
                </div>
              ),
            },
            { key: 'quotes_count', label: 'Quotes', align: 'right' },
            { key: 'orders_count', label: 'Orders', align: 'right' },
            {
              key: 'conversion_pct',
              label: 'Conversion',
              align: 'right',
              render: (d) => (d.conversion_pct != null ? `${d.conversion_pct}%` : '—'),
            },
            {
              key: 'sales_total',
              label: 'Sales',
              align: 'right',
              render: (d) => <span className="font-medium">{formatCurrency(Number(d.sales_total) || 0)}</span>,
            },
            {
              key: 'margin_pct',
              label: 'Margin',
              align: 'right',
              render: (d) =>
                d.margin_pct != null ? (
                  <span className={Number(d.margin_pct) >= 30 ? 'text-status-green' : Number(d.margin_pct) < 15 ? 'text-status-red' : ''}>
                    {String(d.margin_pct)}%
                  </span>
                ) : (
                  '—'
                ),
            },
          ]}
          rows={dealers as unknown as Record<string, unknown>[]}
          emptyMessage="No dealer activity in this period"
        />
      </Panel>
    </div>
  );
}
