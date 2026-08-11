import { useMemo, useState } from 'react';
import { BarChart3, Building2, Package, Puzzle, ShoppingCart, TrendingUp } from 'lucide-react';
import type { ReportDateRange } from '../../hooks/useReports';
import SalesReportTab from './tabs/SalesReportTab';
import DealersReportTab from './tabs/DealersReportTab';
import ProductsReportTab from './tabs/ProductsReportTab';
import ComponentsReportTab from './tabs/ComponentsReportTab';
import PurchasingReportTab from './tabs/PurchasingReportTab';

type TabId = 'sales' | 'dealers' | 'products' | 'components' | 'purchasing';

const TABS: { id: TabId; label: string; icon: typeof TrendingUp }[] = [
  { id: 'sales', label: 'Sales', icon: TrendingUp },
  { id: 'dealers', label: 'Dealers', icon: Building2 },
  { id: 'products', label: 'Products', icon: Package },
  { id: 'components', label: 'Components', icon: Puzzle },
  { id: 'purchasing', label: 'Purchasing', icon: ShoppingCart },
];

type PresetId = 'this_month' | 'last_30' | 'last_90' | 'ytd' | 'last_12m' | 'custom';

const PRESETS: { id: PresetId; label: string }[] = [
  { id: 'this_month', label: 'This month' },
  { id: 'last_30', label: 'Last 30 days' },
  { id: 'last_90', label: 'Last 90 days' },
  { id: 'ytd', label: 'YTD' },
  { id: 'last_12m', label: 'Last 12 months' },
  { id: 'custom', label: 'Custom' },
];

const iso = (d: Date) => {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
};

function presetRange(preset: PresetId): ReportDateRange {
  const today = new Date();
  const to = iso(today);
  switch (preset) {
    case 'this_month':
      return { from: iso(new Date(today.getFullYear(), today.getMonth(), 1)), to };
    case 'last_30':
      return { from: iso(new Date(today.getTime() - 29 * 86_400_000)), to };
    case 'last_90':
      return { from: iso(new Date(today.getTime() - 89 * 86_400_000)), to };
    case 'ytd':
      return { from: iso(new Date(today.getFullYear(), 0, 1)), to };
    case 'last_12m':
      return { from: iso(new Date(today.getFullYear() - 1, today.getMonth(), today.getDate())), to };
    default:
      return { from: iso(new Date(today.getFullYear(), 0, 1)), to };
  }
}

export default function ReportsModule() {
  const [activeTab, setActiveTab] = useState<TabId>('sales');
  const [preset, setPreset] = useState<PresetId>('last_90');
  const [customFrom, setCustomFrom] = useState('');
  const [customTo, setCustomTo] = useState('');

  const range = useMemo<ReportDateRange>(() => {
    if (preset === 'custom' && customFrom && customTo && customFrom <= customTo) {
      return { from: customFrom, to: customTo };
    }
    return presetRange(preset === 'custom' ? 'last_90' : preset);
  }, [preset, customFrom, customTo]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <BarChart3 className="h-6 w-6 text-primary" />
            <h1 className="text-title font-semibold text-foreground">Reports</h1>
          </div>
          <p className="text-sm text-muted-foreground mt-1">
            KPIs and movement across sales, dealers, products, components and purchasing
          </p>
        </div>

        {/* Date range selector */}
        <div className="flex flex-wrap items-center gap-2">
          <div className="flex rounded-lg border border-gray-200 bg-white p-0.5">
            {PRESETS.map((p) => (
              <button
                key={p.id}
                type="button"
                onClick={() => setPreset(p.id)}
                className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
                  preset === p.id
                    ? 'bg-primary text-white'
                    : 'text-gray-600 hover:bg-gray-50'
                }`}
              >
                {p.label}
              </button>
            ))}
          </div>
          {preset === 'custom' && (
            <div className="flex items-center gap-1.5">
              <input
                type="date"
                value={customFrom}
                onChange={(e) => setCustomFrom(e.target.value)}
                className="text-xs border border-gray-200 rounded-md px-2 py-1.5"
              />
              <span className="text-xs text-gray-400">→</span>
              <input
                type="date"
                value={customTo}
                onChange={(e) => setCustomTo(e.target.value)}
                className="text-xs border border-gray-200 rounded-md px-2 py-1.5"
              />
            </div>
          )}
          <span className="text-xs text-muted-foreground tabular-nums">
            {range.from} → {range.to}
          </span>
        </div>
      </div>

      {/* Tabs */}
      <div className="mb-6 border-b border-gray-200">
        <nav className="flex gap-1 -mb-px">
          {TABS.map((tab) => {
            const Icon = tab.icon;
            const active = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                type="button"
                onClick={() => setActiveTab(tab.id)}
                className={`inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium border-b-2 transition-colors ${
                  active
                    ? 'border-primary text-primary'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                <Icon className="h-4 w-4" />
                {tab.label}
              </button>
            );
          })}
        </nav>
      </div>

      {/* Tab panels: keep mounted, toggle with hidden (ERP pattern) so a tab
          keeps its data when switching back and forth. */}
      <div hidden={activeTab !== 'sales'}>
        <SalesReportTab range={range} active={activeTab === 'sales'} />
      </div>
      <div hidden={activeTab !== 'dealers'}>
        <DealersReportTab range={range} active={activeTab === 'dealers'} />
      </div>
      <div hidden={activeTab !== 'products'}>
        <ProductsReportTab range={range} active={activeTab === 'products'} />
      </div>
      <div hidden={activeTab !== 'components'}>
        <ComponentsReportTab range={range} active={activeTab === 'components'} />
      </div>
      <div hidden={activeTab !== 'purchasing'}>
        <PurchasingReportTab range={range} active={activeTab === 'purchasing'} />
      </div>
    </div>
  );
}
