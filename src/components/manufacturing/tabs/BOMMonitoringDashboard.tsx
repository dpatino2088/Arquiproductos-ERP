import { AlertCircle, CheckCircle2, AlertTriangle, RefreshCw, TrendingUp, Package, DollarSign } from 'lucide-react';
import { useBOMMonitoring, BOMHealthStatus, BOMInstanceData } from '../../../hooks/useBOMMonitoring';
import { formatCurrency } from '../../../lib/utils';

// Helper function to format dates (replaces date-fns)
const formatDate = (date: string | Date): string => {
  const d = typeof date === 'string' ? new Date(date) : date;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const month = months[d.getMonth()];
  const day = d.getDate();
  const year = d.getFullYear();
  const hours = d.getHours().toString().padStart(2, '0');
  const minutes = d.getMinutes().toString().padStart(2, '0');
  return `${month} ${day}, ${year} ${hours}:${minutes}`;
};

interface BOMMonitoringDashboardProps {
  saleOrderId?: string | null;
  currency?: string;
}

export default function BOMMonitoringDashboard({ saleOrderId, currency = 'USD' }: BOMMonitoringDashboardProps) {
  const { bomInstance, healthStatus, loading, error, refetch } = useBOMMonitoring(saleOrderId);

  if (loading) {
    return (
      <div className="p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-gray-200 rounded"></div>
          <div className="h-32 bg-gray-200 rounded"></div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <div className="flex items-center gap-2">
            <AlertCircle className="w-5 h-5 text-red-600" />
            <p className="text-sm text-red-800 font-medium">Error loading monitoring data</p>
          </div>
          <p className="text-sm text-red-700 mt-2">{error}</p>
        </div>
      </div>
    );
  }

  if (!bomInstance && !healthStatus) {
    return (
      <div className="p-6">
        <div className="text-center text-gray-500 py-12">
          <Package className="w-12 h-12 mx-auto mb-4 text-gray-400" />
          <p className="mb-2">No BOM data available for monitoring.</p>
          <p className="text-xs text-gray-400">Generate a BOM to see monitoring data.</p>
        </div>
      </div>
    );
  }

  const getHealthBadge = (status: BOMHealthStatus) => {
    if (status.is_healthy) {
      return (
        <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
          <CheckCircle2 className="w-3.5 h-3.5" />
          Healthy
        </span>
      );
    } else if (status.total_issues <= 2) {
      return (
        <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
          <AlertTriangle className="w-3.5 h-3.5" />
          {status.total_issues} Warning{status.total_issues !== 1 ? 's' : ''}
        </span>
      );
    } else {
      return (
        <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
          <AlertCircle className="w-3.5 h-3.5" />
          {status.total_issues} Issue{status.total_issues !== 1 ? 's' : ''}
        </span>
      );
    }
  };

  return (
    <div className="p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-lg font-semibold text-gray-900">BOM Health Monitoring</h3>
          <p className="text-sm text-gray-600 mt-1">Real-time validation and health status</p>
        </div>
        <button
          onClick={() => refetch()}
          className="flex items-center gap-2 px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
        >
          <RefreshCw className="w-4 h-4" />
          Refresh
        </button>
      </div>

      {/* Health Status Card */}
      {healthStatus && (
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <div className="flex items-center justify-between mb-4">
            <h4 className="text-base font-semibold text-gray-900">System Health</h4>
            {getHealthBadge(healthStatus)}
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {/* Orphan Assembly Children */}
            <div className={`p-4 rounded-lg border-2 ${
              healthStatus.orphan_assembly_children > 0 
                ? 'bg-red-50 border-red-200' 
                : 'bg-green-50 border-green-200'
            }`}>
              <div className="flex items-center gap-2 mb-2">
                {healthStatus.orphan_assembly_children > 0 ? (
                  <AlertCircle className="w-5 h-5 text-red-600" />
                ) : (
                  <CheckCircle2 className="w-5 h-5 text-green-600" />
                )}
                <span className="text-sm font-medium text-gray-900">Orphan Children</span>
              </div>
              <div className="text-2xl font-bold text-gray-900">
                {healthStatus.orphan_assembly_children}
              </div>
              <p className="text-xs text-gray-600 mt-1">Assembly children without parent</p>
            </div>

            {/* Duplicate Items */}
            <div className={`p-4 rounded-lg border-2 ${
              healthStatus.duplicate_items > 0 
                ? 'bg-red-50 border-red-200' 
                : 'bg-green-50 border-green-200'
            }`}>
              <div className="flex items-center gap-2 mb-2">
                {healthStatus.duplicate_items > 0 ? (
                  <AlertCircle className="w-5 h-5 text-red-600" />
                ) : (
                  <CheckCircle2 className="w-5 h-5 text-green-600" />
                )}
                <span className="text-sm font-medium text-gray-900">Duplicates</span>
              </div>
              <div className="text-2xl font-bold text-gray-900">
                {healthStatus.duplicate_items}
              </div>
              <p className="text-xs text-gray-600 mt-1">Duplicate items in BOM</p>
            </div>

            {/* Missing Qty/UOM */}
            <div className={`p-4 rounded-lg border-2 ${
              healthStatus.missing_qty_uom > 0 
                ? 'bg-yellow-50 border-yellow-200' 
                : 'bg-green-50 border-green-200'
            }`}>
              <div className="flex items-center gap-2 mb-2">
                {healthStatus.missing_qty_uom > 0 ? (
                  <AlertTriangle className="w-5 h-5 text-yellow-600" />
                ) : (
                  <CheckCircle2 className="w-5 h-5 text-green-600" />
                )}
                <span className="text-sm font-medium text-gray-900">Missing Qty/UOM</span>
              </div>
              <div className="text-2xl font-bold text-gray-900">
                {healthStatus.missing_qty_uom}
              </div>
              <p className="text-xs text-gray-600 mt-1">Lines without quantity or UOM</p>
            </div>

            {/* Missing Parent */}
            <div className={`p-4 rounded-lg border-2 ${
              healthStatus.missing_parent > 0 
                ? 'bg-red-50 border-red-200' 
                : 'bg-green-50 border-green-200'
            }`}>
              <div className="flex items-center gap-2 mb-2">
                {healthStatus.missing_parent > 0 ? (
                  <AlertCircle className="w-5 h-5 text-red-600" />
                ) : (
                  <CheckCircle2 className="w-5 h-5 text-green-600" />
                )}
                <span className="text-sm font-medium text-gray-900">Missing Parent</span>
              </div>
              <div className="text-2xl font-bold text-gray-900">
                {healthStatus.missing_parent}
              </div>
              <p className="text-xs text-gray-600 mt-1">Children without parent in BOM</p>
            </div>
          </div>
        </div>
      )}

      {/* BOM Instance Summary */}
      {bomInstance && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <div className="bg-gray-50 px-6 py-3 border-b border-gray-200">
            <h4 className="text-base font-semibold text-gray-900">BOM Instance Summary</h4>
          </div>
          <div className="p-6">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
              <div>
                <div className="text-xs text-gray-600 mb-1">Created</div>
                <div className="text-sm font-medium text-gray-900">
                  {formatDate(bomInstance.bom_created_at)}
                </div>
              </div>
              <div>
                <div className="text-xs text-gray-600 mb-1">Total Lines</div>
                <div className="text-sm font-medium text-gray-900">
                  {bomInstance.total_lines}
                </div>
              </div>
              <div>
                <div className="text-xs text-gray-600 mb-1">Unique Items</div>
                <div className="text-sm font-medium text-gray-900">
                  {bomInstance.unique_items}
                </div>
              </div>
              <div>
                <div className="text-xs text-gray-600 mb-1">Total Qty</div>
                <div className="text-sm font-medium text-gray-900">
                  {bomInstance.total_qty.toFixed(2)}
                </div>
              </div>
            </div>
            <div className="grid grid-cols-2 md:grid-cols-3 gap-4 pt-4 border-t border-gray-200">
              <div>
                <div className="text-xs text-gray-600 mb-1">Sources</div>
                <div className="text-sm text-gray-700">
                  BOM: {bomInstance.bom_component_lines} | QLC: {bomInstance.quote_line_component_lines} | Assembly: {bomInstance.assembly_child_lines}
                </div>
              </div>
              <div>
                <div className="text-xs text-gray-600 mb-1">Total Cost (with Labor)</div>
                <div className="text-sm font-medium text-gray-900">
                  {formatCurrency(bomInstance.total_cost_with_labor, currency)}
                </div>
              </div>
              <div>
                <div className="text-xs text-gray-600 mb-1">Total MSRP (with Labor)</div>
                <div className="text-sm font-medium text-blue-700">
                  {formatCurrency(bomInstance.total_msrp_with_labor, currency)}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Summary Stats */}
      {bomInstance && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <div className="flex items-center gap-2 mb-2">
              <Package className="w-5 h-5 text-blue-600" />
              <span className="text-sm font-medium text-gray-900">BOM Instance ID</span>
            </div>
            <div className="text-xs font-mono text-blue-700 break-all">
              {bomInstance.bom_instance_id}
            </div>
            <p className="text-xs text-gray-600 mt-1">Current BOM instance</p>
          </div>

          <div className="bg-green-50 border border-green-200 rounded-lg p-4">
            <div className="flex items-center gap-2 mb-2">
              <TrendingUp className="w-5 h-5 text-green-600" />
              <span className="text-sm font-medium text-gray-900">Total Lines</span>
            </div>
            <div className="text-2xl font-bold text-green-700">
              {bomInstance.total_lines}
            </div>
            <p className="text-xs text-gray-600 mt-1">BOM lines in this instance</p>
          </div>

          <div className="bg-purple-50 border border-purple-200 rounded-lg p-4">
            <div className="flex items-center gap-2 mb-2">
              <DollarSign className="w-5 h-5 text-purple-600" />
              <span className="text-sm font-medium text-gray-900">Total Value</span>
            </div>
            <div className="text-2xl font-bold text-purple-700">
              {formatCurrency(bomInstance.total_msrp_with_labor, currency)}
            </div>
            <p className="text-xs text-gray-600 mt-1">MSRP with labor</p>
          </div>
        </div>
      )}
    </div>
  );
}

