import { useMemo } from 'react';
import {
  CheckCircle,
  Clock,
  DollarSign,
  FileText,
  Package,
  ReceiptText,
  TrendingUp,
} from 'lucide-react';
import { useDashboardOverview } from '../../hooks/useDashboardOverview';
import { formatCurrency } from '../../lib/utils';
import StatusBadge from '../../components/shared/StatusBadge';
import { router } from '../../lib/router';

export default function CommercialDashboard() {
  const { data, isInitialLoading, isRefreshing, error } = useDashboardOverview();

  const kpiCards = useMemo(() => {
    const salesDelta = data.salesTotal.deltaPct;
    const salesDeltaLabel = `${salesDelta != null && salesDelta >= 0 ? '+' : ''}${(salesDelta ?? 0).toFixed(1)}% vs prev 30d`;
    const activeDeltaLabel = `${data.activeOrders.delta >= 0 ? '+' : ''}${data.activeOrders.delta} vs prev 30d`;
    const sentDeltaLabel = `${data.proposalsSent.delta >= 0 ? '+' : ''}${data.proposalsSent.delta} vs prev 30d`;
    const acceptedDeltaLabel = `${data.proposalsAccepted.delta >= 0 ? '+' : ''}${data.proposalsAccepted.delta} vs prev 30d`;

    return [
      {
        title: 'Total Sales',
        value: formatCurrency(data.salesTotal.current),
        change: salesDeltaLabel,
        changeType: (salesDelta ?? 0) >= 0 ? 'positive' : 'negative',
        icon: DollarSign,
      },
      {
        title: 'Active Orders',
        value: data.activeOrders.current.toString(),
        change: activeDeltaLabel,
        changeType: data.activeOrders.delta >= 0 ? 'positive' : 'negative',
        icon: Package,
      },
      {
        title: 'Proposals Sent',
        value: data.proposalsSent.current.toString(),
        change: sentDeltaLabel,
        changeType: data.proposalsSent.delta >= 0 ? 'positive' : 'negative',
        icon: ReceiptText,
      },
      {
        title: 'Proposals Accepted',
        value: data.proposalsAccepted.current.toString(),
        change: acceptedDeltaLabel,
        changeType: data.proposalsAccepted.delta >= 0 ? 'positive' : 'negative',
        icon: CheckCircle,
      },
    ];
  }, [data]);

  const scopeTitle = data.scopeMode === 'dealer' ? 'Dealer Overview' : 'Organization Overview';

  return (
    <div className="p-6">
      <div className="mb-8">
        <h1 className="text-title font-semibold text-foreground">Management Dashboard</h1>
        <p className="text-sm text-muted-foreground mt-1">
          {scopeTitle} {isRefreshing ? '· Updating...' : ''}
        </p>
        {error ? (
          <p className="text-xs text-status-red mt-1">Dashboard query error: {error}</p>
        ) : null}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {kpiCards.map((stat, index) => (
          <div key={index} className="bg-white border border-gray-200 rounded-lg p-6 hover:shadow-lg transition-all duration-200 hover:border-primary/20">
            <div className="flex items-center justify-between mb-4">
              <stat.icon className="h-8 w-8 text-primary" />
              <div className="text-right">
                <div className="text-2xl font-bold text-foreground">{isInitialLoading ? '...' : stat.value}</div>
                <div className={`text-sm ${stat.changeType === 'positive' ? 'text-status-green' : stat.changeType === 'negative' ? 'text-status-red' : 'text-muted-foreground'}`}>
                  {stat.change}
                </div>
              </div>
            </div>
            <div className="text-sm font-medium text-muted-foreground">{stat.title}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-heading font-semibold">Commercial Pipeline</h2>
            <div className="bg-blue-50 text-status-blue text-xs px-2 py-1 rounded-full">Live</div>
          </div>
          <div className="space-y-4">
            {[
              { label: 'Quotes Draft', value: data.pipeline.quotesDraft, icon: FileText, route: '/sales/quotes?status=draft' },
              { label: 'Quotes Approved', value: data.pipeline.quotesApproved, icon: CheckCircle, route: '/sales/quotes?status=approved' },
              { label: 'Proposals Sent', value: data.pipeline.proposalsSent, icon: ReceiptText, route: '/sales/proposals?status=sent' },
              { label: 'Proposals Accepted', value: data.pipeline.proposalsAccepted, icon: TrendingUp, route: '/sales/proposals?status=accepted' },
              { label: 'Orders Active', value: data.pipeline.activeOrders, icon: Package, route: '/sales/orders?status=confirmed' },
            ].map((item) => (
              <button
                key={item.label}
                type="button"
                onClick={() => router.navigate(item.route)}
                className="w-full flex items-center justify-between p-3 hover:bg-gray-50 rounded-lg transition-colors"
                title={`Go to ${item.label}`}
              >
                <div className="flex items-center gap-3">
                  <item.icon className="h-4 w-4 text-primary" />
                  <span className="font-medium">{item.label}</span>
                </div>
                <span className="text-lg font-semibold text-foreground">{isInitialLoading ? '...' : item.value}</span>
              </button>
            ))}
          </div>
        </div>

        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <h2 className="text-heading font-semibold mb-6">Orders Follow-up</h2>
          <div className="space-y-4">
            {data.recentOrders.length === 0 ? (
              <div className="text-sm text-muted-foreground">No orders found for this scope yet.</div>
            ) : data.recentOrders.map((order) => (
              <div key={order.id} className="p-3 hover:bg-gray-50 rounded-lg transition-colors">
                <div className="flex items-center justify-between">
                  <div>
                    <div className="font-medium">{order.number}</div>
                    <div className="text-xs text-muted-foreground">{new Date(order.created_at).toLocaleDateString()}</div>
                    {order.dealerName && (
                      <div className="text-xs text-muted-foreground">Dealer: {order.dealerName}</div>
                    )}
                  </div>
                  <div className="text-right">
                    <StatusBadge status={order.status} type="salesOrder" size="sm" />
                    <div className="text-sm font-semibold mt-1">{formatCurrency(order.amount)}</div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="flex items-center gap-3 mb-6">
          <Clock className="h-6 w-6 text-status-blue" />
          <h2 className="text-heading font-semibold">Recent Commercial Activity</h2>
        </div>
        <div className="space-y-4">
          {data.recentActivity.length === 0 ? (
            <div className="text-sm text-muted-foreground">No recent activity for this scope yet.</div>
          ) : data.recentActivity.map((activity) => (
            <div key={activity.id} className="flex items-start gap-4 p-3 hover:bg-gray-50 rounded-lg transition-colors">
              <CheckCircle className="h-5 w-5 text-status-green mt-0.5 flex-shrink-0" />
              <div className="flex-1 flex items-center justify-between gap-3">
                <div>
                  <div className="font-medium uppercase text-xs text-muted-foreground mb-1">{activity.entity}</div>
                  <div className="font-medium">{activity.number}</div>
                  <div className="text-sm text-muted-foreground capitalize">{activity.status.replace(/_/g, ' ')}</div>
                </div>
                <div className="text-right">
                  <div className="font-semibold">{formatCurrency(activity.amount)}</div>
                  <div className="text-xs text-muted-foreground">{new Date(activity.created_at).toLocaleDateString()}</div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
