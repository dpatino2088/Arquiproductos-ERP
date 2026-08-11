import { useMemo } from 'react';
import {
  Bar,
  BarChart,
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { DollarSign, ShoppingCart, Truck } from 'lucide-react';
import { deltaPct, useReport, type PurchasingReport, type ReportDateRange } from '../../../hooks/useReports';
import { formatCurrency } from '../../../lib/utils';
import { CHART_COLORS, CsvButton, EmptyState, KpiCard, moneyFormatter, moneyTotalFormatter, Panel, ReportTable } from '../reportUi';

export default function PurchasingReportTab({ range, active }: { range: ReportDateRange; active: boolean }) {
  const { data, previousData, isInitialLoading, isRefreshing, error } = useReport<PurchasingReport>(
    'purchasing',
    range,
    { withPrevious: true, enabled: active }
  );

  const vendors = data?.by_vendor ?? [];
  const topItems = data?.top_items ?? [];
  const topVendor = vendors[0];

  const vendorChart = useMemo(
    () =>
      vendors.slice(0, 10).map((v) => ({
        name: v.vendor.length > 26 ? `${v.vendor.slice(0, 26)}…` : v.vendor,
        total: v.total,
      })),
    [vendors]
  );

  const itemsCsv = useMemo(
    () =>
      topItems.map((i) => ({
        sku: i.sku,
        name: i.name ?? '',
        qty: i.qty,
        unit: i.unit ?? '',
        spend: i.spend,
      })),
    [topItems]
  );

  return (
    <div className="space-y-6">
      {error ? <p className="text-xs text-status-red">Report error: {error}</p> : null}
      {isRefreshing ? <p className="text-xs text-muted-foreground">Updating…</p> : null}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <KpiCard
          title="Total Spend (committed POs)"
          value={formatCurrency(data?.total_spend ?? 0)}
          delta={deltaPct(data?.total_spend, previousData?.total_spend)}
          icon={DollarSign}
          loading={isInitialLoading}
        />
        <KpiCard
          title="Purchase Orders"
          value={String(data?.po_count ?? 0)}
          delta={deltaPct(data?.po_count, previousData?.po_count)}
          icon={ShoppingCart}
          loading={isInitialLoading}
        />
        <KpiCard
          title="Top Vendor"
          value={topVendor ? topVendor.vendor : '—'}
          icon={Truck}
          loading={isInitialLoading}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Panel title="Monthly Spend" subtitle="Committed POs (OPEN + CLOSED) by month">
          {(data?.monthly?.length ?? 0) === 0 ? (
            <EmptyState message="No purchases in this period" />
          ) : (
            <ResponsiveContainer width="100%" height={260}>
              <LineChart data={data!.monthly} margin={{ top: 8, right: 8, bottom: 0, left: 8 }}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                <XAxis dataKey="month" tick={{ fontSize: 11 }} tickLine={false} axisLine={false} />
                <YAxis
                  tick={{ fontSize: 11 }}
                  tickLine={false}
                  axisLine={false}
                  tickFormatter={(v: number) => `$${v >= 1000 ? `${(v / 1000).toFixed(0)}k` : v}`}
                />
                <Tooltip formatter={moneyTotalFormatter} />
                <Line type="monotone" dataKey="total" stroke={CHART_COLORS[8]} strokeWidth={2} dot={{ r: 3 }} />
              </LineChart>
            </ResponsiveContainer>
          )}
        </Panel>

        <Panel title="Spend by Vendor" subtitle="Top vendors in the period">
          {vendorChart.length === 0 ? (
            <EmptyState message="No purchases in this period" />
          ) : (
            <ResponsiveContainer width="100%" height={Math.max(220, vendorChart.length * 38)}>
              <BarChart data={vendorChart} layout="vertical" margin={{ top: 4, right: 24, bottom: 4, left: 8 }}>
                <CartesianGrid strokeDasharray="3 3" horizontal={false} stroke="#f1f5f9" />
                <XAxis
                  type="number"
                  tick={{ fontSize: 11 }}
                  tickLine={false}
                  axisLine={false}
                  tickFormatter={(v: number) => `$${v >= 1000 ? `${(v / 1000).toFixed(0)}k` : v}`}
                />
                <YAxis type="category" dataKey="name" width={190} tick={{ fontSize: 11 }} tickLine={false} axisLine={false} />
                <Tooltip formatter={moneyFormatter} />
                <Bar dataKey="total" fill={CHART_COLORS[2]} radius={[0, 4, 4, 0]} barSize={20} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </Panel>
      </div>

      <Panel
        title="Top Purchased Items"
        subtitle="By spend across committed POs (top 20)"
        action={<CsvButton filename={`purchasing-items-${range.from}-${range.to}.csv`} rows={itemsCsv} />}
      >
        <ReportTable
          columns={[
            { key: 'sku', label: 'SKU', render: (r) => <span className="font-mono text-xs">{String(r.sku)}</span> },
            { key: 'name', label: 'Item', render: (r) => String(r.name ?? '—') },
            {
              key: 'qty',
              label: 'Qty',
              align: 'right',
              render: (r) => `${r.qty} ${String(r.unit ?? '')}`.trim(),
            },
            {
              key: 'spend',
              label: 'Spend',
              align: 'right',
              render: (r) => <span className="font-medium">{formatCurrency(Number(r.spend) || 0)}</span>,
            },
          ]}
          rows={topItems as unknown as Record<string, unknown>[]}
          emptyMessage="No purchases in this period"
        />
      </Panel>
    </div>
  );
}
