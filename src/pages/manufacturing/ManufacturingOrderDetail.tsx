import { useEffect, useState } from 'react';
import { router } from '../../lib/router';
import { useManufacturingOrder } from '../../hooks/useManufacturing';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import ManufacturingOrderTabs from '../../components/manufacturing/ManufacturingOrderTabs';
import { ArrowLeft } from 'lucide-react';

interface ManufacturingOrderDetailProps {
  moId?: string;
}

export default function ManufacturingOrderDetail({ moId: propMoId }: ManufacturingOrderDetailProps) {
  const [moId, setMoId] = useState<string | null>(propMoId || null);
  const { manufacturingOrder, loading, error } = useManufacturingOrder(moId);
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();

  // Get MO ID from URL if not provided
  useEffect(() => {
    if (!moId) {
      const path = window.location.pathname;
      const match = path.match(/\/manufacturing\/manufacturing-orders\/([^/]+)/);
      if (match) {
        const urlMoId = match[1];
        setMoId(urlMoId);
        sessionStorage.setItem('currentManufacturingOrderId', urlMoId);
      } else {
        const storedId = sessionStorage.getItem('currentManufacturingOrderId');
        if (storedId) {
          setMoId(storedId);
        }
      }
    }
  }, [moId]);

  // Register Manufacturing submodules
  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/manufacturing')) {
      registerSubmodules('Manufacturing', [
        { id: 'order-list', label: 'Order List', href: '/manufacturing/order-list' },
        { id: 'manufacturing-orders', label: 'Manufacturing Orders', href: '/manufacturing/manufacturing-orders' },
        { id: 'material', label: 'Material', href: '/manufacturing/material' },
      ]);
    }
    
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/manufacturing')) {
        clearSubmoduleNav();
      }
    };
  }, [registerSubmodules, clearSubmoduleNav]);

  if (!moId) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error</p>
          <p className="text-sm text-red-700">Manufacturing order ID is required</p>
        </div>
        <button
          onClick={() => router.navigate('/manufacturing/manufacturing-orders')}
          className="mt-4 px-4 py-2 text-sm text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          Back to Manufacturing Orders
        </button>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="py-6 px-6">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-gray-200 rounded w-1/4"></div>
          <div className="h-32 bg-gray-200 rounded"></div>
        </div>
      </div>
    );
  }

  if (error || !manufacturingOrder) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error</p>
          <p className="text-sm text-red-700">
            {error || 'Manufacturing order not found'}
          </p>
        </div>
        <button
          onClick={() => router.navigate('/manufacturing/manufacturing-orders')}
          className="mt-4 px-4 py-2 text-sm text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          Back to Manufacturing Orders
        </button>
      </div>
    );
  }

  return (
    <div className="py-6 px-6">
      {/* Header */}
      <div className="mb-6">
        <button
          onClick={() => router.navigate('/manufacturing/manufacturing-orders')}
          className="flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900 mb-4"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Manufacturing Orders
        </button>

        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold text-foreground mb-1">
              {manufacturingOrder.manufacturing_order_no}
            </h1>
            <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
              Manufacturing Order Details
            </p>
          </div>
          <div className="flex items-center gap-3">
            <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${
              manufacturingOrder.status === 'completed' ? 'bg-green-100 text-green-800' :
              manufacturingOrder.status === 'in_production' ? 'bg-yellow-100 text-yellow-800' :
              manufacturingOrder.status === 'planned' ? 'bg-blue-100 text-blue-800' :
              'bg-gray-100 text-gray-800'
            }`}>
              {manufacturingOrder.status.replace('_', ' ').toUpperCase()}
            </span>
          </div>
        </div>

        {/* Order Info */}
        <div className="mt-4 bg-white border border-gray-200 rounded-lg p-4">
          <div className="grid grid-cols-3 gap-4">
            <div>
              <label className="text-xs font-medium text-gray-700">Sale Order</label>
              <div className="mt-1 text-sm text-gray-900">
                {manufacturingOrder.SalesOrders?.sale_order_no || 'N/A'}
              </div>
            </div>
            <div>
              <label className="text-xs font-medium text-gray-700">Customer</label>
              <div className="mt-1 text-sm text-gray-900">
                {manufacturingOrder.SalesOrders?.DirectoryCustomers?.customer_name || 'N/A'}
              </div>
            </div>
            <div>
              <label className="text-xs font-medium text-gray-700">Priority</label>
              <div className="mt-1">
                <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                  manufacturingOrder.priority === 'urgent' ? 'bg-red-100 text-red-800' :
                  manufacturingOrder.priority === 'high' ? 'bg-orange-100 text-orange-800' :
                  manufacturingOrder.priority === 'low' ? 'bg-gray-100 text-gray-800' :
                  'bg-blue-100 text-blue-800'
                }`}>
                  {manufacturingOrder.priority.toUpperCase()}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <ManufacturingOrderTabs moId={moId} />
    </div>
  );
}
