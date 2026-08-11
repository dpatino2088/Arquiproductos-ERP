import { useMemo } from 'react';
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { Layers, Package, Ruler } from 'lucide-react';
import { useReport, type ProductMixReport, type ReportDateRange } from '../../../hooks/useReports';
import { formatCurrency } from '../../../lib/utils';
import { CHART_COLORS, CsvButton, EmptyState, KpiCard, moneyFormatter, Panel, ReportTable } from '../reportUi';

export default function ProductsReportTab({ range, active }: { range: ReportDateRange; active: boolean }) {
  const { data, isInitialLoading, isRefreshing, error } = useReport<ProductMixReport>(
    'products',
    range,
    { enabled: active }
  );

  const byType = data?.by_product_type ?? [];
  const collections = data?.top_collections ?? [];
  const totalUnits = byType.reduce((s, t) => s + t.units, 0);
  const totalRevenue = byType.reduce((s, t) => s + t.revenue, 0);
  const topType = byType[0];

  const collectionsChart = useMemo(
    () =>
      collections.slice(0, 10).map((c) => ({
        name: `${c.collection}${c.variant ? ` · ${c.variant}` : ''}`.slice(0, 32),
        revenue: c.revenue,
      })),
    [collections]
  );

  const typeCsv = useMemo(
    () =>
      byType.map((t) => ({
        product_type: t.product_type,
        units: t.units,
        revenue: t.revenue,
        avg_width_m: t.avg_width_m ?? '',
        avg_height_m: t.avg_height_m ?? '',
      })),
    [byType]
  );

  const collectionsCsv = useMemo(
    () =>
      collections.map((c) => ({
        collection: c.collection,
        variant: c.variant ?? '',
        units: c.units,
        revenue: c.revenue,
      })),
    [collections]
  );

  return (
    <div className="space-y-6">
      {error ? <p className="text-xs text-status-red">Report error: {error}</p> : null}
      {isRefreshing ? <p className="text-xs text-muted-foreground">Updating…</p> : null}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <KpiCard
          title="Units Sold"
          value={String(totalUnits)}
          icon={Package}
          loading={isInitialLoading}
        />
        <KpiCard
          title="Top Product Type"
          value={topType ? topType.product_type : '—'}
          icon={Layers}
          loading={isInitialLoading}
        />
        <KpiCard
          title="Avg Size (top type)"
          value={
            topType?.avg_width_m != null && topType?.avg_height_m != null
              ? `${topType.avg_width_m} × ${topType.avg_height_m} m`
              : '—'
          }
          icon={Ruler}
          loading={isInitialLoading}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Panel title="Revenue by Product Type" subtitle={`Total ${formatCurrency(totalRevenue)}`}>
          {byType.length === 0 ? (
            <EmptyState message="No sales in this period" />
          ) : (
            <ResponsiveContainer width="100%" height={280}>
              <PieChart>
                <Pie
                  data={byType}
                  dataKey="revenue"
                  nameKey="product_type"
                  innerRadius={55}
                  outerRadius={90}
                  paddingAngle={2}
                  label={({ name }) => String(name)}
                  labelLine={false}
                >
                  {byType.map((_, i) => (
                    <Cell key={i} fill={CHART_COLORS[i % CHART_COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip formatter={moneyFormatter} />
              </PieChart>
            </ResponsiveContainer>
          )}
        </Panel>

        <div className="lg:col-span-2">
          <Panel title="Top Collections / Fabrics" subtitle="By revenue in the period">
            {collectionsChart.length === 0 ? (
              <EmptyState message="No fabric sales in this period" />
            ) : (
              <ResponsiveContainer width="100%" height={Math.max(220, collectionsChart.length * 34)}>
                <BarChart data={collectionsChart} layout="vertical" margin={{ top: 4, right: 24, bottom: 4, left: 8 }}>
                  <CartesianGrid strokeDasharray="3 3" horizontal={false} stroke="#f1f5f9" />
                  <XAxis
                    type="number"
                    tick={{ fontSize: 11 }}
                    tickLine={false}
                    axisLine={false}
                    tickFormatter={(v: number) => `$${v >= 1000 ? `${(v / 1000).toFixed(0)}k` : v}`}
                  />
                  <YAxis type="category" dataKey="name" width={210} tick={{ fontSize: 11 }} tickLine={false} axisLine={false} />
                  <Tooltip formatter={moneyFormatter} />
                  <Bar dataKey="revenue" fill={CHART_COLORS[1]} radius={[0, 4, 4, 0]} barSize={18} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </Panel>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Panel
          title="Product Types"
          subtitle="Units, revenue and average dimensions"
          action={<CsvButton filename={`products-types-${range.from}-${range.to}.csv`} rows={typeCsv} />}
        >
          <ReportTable
            columns={[
              { key: 'product_type', label: 'Type', render: (r) => <span className="font-medium">{String(r.product_type)}</span> },
              { key: 'units', label: 'Units', align: 'right' },
              {
                key: 'revenue',
                label: 'Revenue',
                align: 'right',
                render: (r) => formatCurrency(Number(r.revenue) || 0),
              },
              {
                key: 'avg',
                label: 'Avg W × H',
                align: 'right',
                render: (r) =>
                  r.avg_width_m != null && r.avg_height_m != null
                    ? `${r.avg_width_m} × ${r.avg_height_m} m`
                    : '—',
              },
            ]}
            rows={byType as unknown as Record<string, unknown>[]}
            emptyMessage="No sales in this period"
          />
        </Panel>

        <Panel
          title="Collections Detail"
          subtitle="Top 15 by revenue"
          action={<CsvButton filename={`products-collections-${range.from}-${range.to}.csv`} rows={collectionsCsv} />}
        >
          <ReportTable
            columns={[
              { key: 'collection', label: 'Collection', render: (r) => <span className="font-medium">{String(r.collection)}</span> },
              { key: 'variant', label: 'Variant', render: (r) => String(r.variant ?? '—') },
              { key: 'units', label: 'Units', align: 'right' },
              {
                key: 'revenue',
                label: 'Revenue',
                align: 'right',
                render: (r) => formatCurrency(Number(r.revenue) || 0),
              },
            ]}
            rows={collections as unknown as Record<string, unknown>[]}
            emptyMessage="No fabric sales in this period"
          />
        </Panel>
      </div>
    </div>
  );
}
