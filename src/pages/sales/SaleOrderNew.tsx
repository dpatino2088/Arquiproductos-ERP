/**
 * SaleOrderNew - View and Edit Sale Orders
 * Similar structure to QuoteNew.tsx
 */

import { useState, useEffect, useMemo } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useSaleOrderLines, useUpdateSaleOrder, SaleOrderStatus } from '../../hooks/useSaleOrders';
import { Download, X } from 'lucide-react';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';

// Format currency
const formatCurrency = (amount: number, currency: string = 'USD') => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
};

// Sale Order status options (customer-facing)
const SALE_ORDER_STATUS_OPTIONS = [
  { value: 'Draft', label: 'Draft' },
  { value: 'Confirmed', label: 'Confirmed' },
  { value: 'Scheduled for Production', label: 'Scheduled for Production' },
  { value: 'In Production', label: 'In Production' },
  { value: 'Ready for Delivery', label: 'Ready for Delivery' },
  { value: 'Delivered', label: 'Delivered' },
  { value: 'Cancelled', label: 'Cancelled' },
] as const;

// Currency options
const CURRENCY_OPTIONS = [
  { value: 'USD', label: 'USD - US Dollar' },
  { value: 'EUR', label: 'EUR - Euro' },
  { value: 'GBP', label: 'GBP - British Pound' },
  { value: 'MXN', label: 'MXN - Mexican Peso' },
  { value: 'CAD', label: 'CAD - Canadian Dollar' },
] as const;

// Schema for Sale Order
const saleOrderSchema = z.object({
  sale_order_no: z.string().min(1, 'Sale order number is required'),
  customer_id: z.string().uuid('Customer is required'),
  status: z.enum(['Draft', 'Confirmed', 'Scheduled for Production', 'In Production', 'Ready for Delivery', 'Delivered', 'Cancelled']),
  currency: z.string().min(1, 'Currency is required'),
  notes: z.string().optional(),
});

type SaleOrderFormValues = z.infer<typeof saleOrderSchema>;

interface Customer {
  id: string;
  customer_name: string;
  primary_contact_id?: string | null;
}

interface Contact {
  id: string;
  contact_name: string;
  email?: string | null;
  primary_phone?: string | null;
  customer_id?: string | null;
}

export default function SaleOrderNew() {
  const { activeOrganizationId } = useOrganizationContext();
  const { updateSaleOrder, isUpdating } = useUpdateSaleOrder();
  const [saleOrderId, setSaleOrderId] = useState<string | null>(null);
  const [saleOrderData, setSaleOrderData] = useState<any>(null);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [selectedContactId, setSelectedContactId] = useState<string>('');
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  const { lines: saleOrderLines, loading: loadingLines, refetch: refetchLines } = useSaleOrderLines(saleOrderId);

  // Form setup
  const {
    register,
    handleSubmit,
    formState: { errors },
    setValue,
    watch,
  } = useForm<SaleOrderFormValues>({
    resolver: zodResolver(saleOrderSchema),
    defaultValues: {
      status: 'Draft',
      currency: 'USD',
      notes: '',
    },
  });

  // Check URL for sale_order_id (edit mode)
  useEffect(() => {
    const path = window.location.pathname;
    // Support both old route (/sales/sale-orders/edit/...) and new route (/sale-orders/edit/...)
    const urlMatch = path.match(/\/(?:sales\/)?sale-orders\/edit\/([^/]+)/);
    const editSaleOrderId = urlMatch ? urlMatch[1] : null;

    const urlParams = new URLSearchParams(window.location.search);
    const querySaleOrderId = urlParams.get('sale_order_id');

    if (editSaleOrderId) {
      setSaleOrderId(editSaleOrderId);
    } else if (querySaleOrderId) {
      setSaleOrderId(querySaleOrderId);
    }
  }, []);

  // Load sale order data when in edit mode
  useEffect(() => {
    const loadSaleOrderData = async () => {
      if (!saleOrderId || !activeOrganizationId) return;

      try {
        const { data, error } = await supabase
          .from('SalesOrders')
          .select(`
            *,
            DirectoryCustomers:customer_id (
              id,
              customer_name,
              primary_contact_id
            ),
            Quotes:quote_id (
              id,
              quote_no
            )
          `)
          .eq('id', saleOrderId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .maybeSingle();

        if (error) throw error;

        if (data) {
          setSaleOrderData(data);
          setValue('sale_order_no', data.sale_order_no || '');
          setValue('customer_id', data.customer_id || '');
          setValue('status', data.status as SaleOrderStatus || 'Draft');
          setValue('currency', data.currency || 'USD');
          setValue('notes', data.notes || '');
        }
      } catch (err) {
        console.error('Error loading sale order:', err);
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: 'Failed to load sale order data',
        });
      }
    };

    loadSaleOrderData();
  }, [saleOrderId, activeOrganizationId, setValue]);

  // Load customers
  useEffect(() => {
    const loadCustomers = async () => {
      if (!activeOrganizationId) return;

      try {
        const { data, error } = await supabase
          .from('DirectoryCustomers')
          .select('id, customer_name, primary_contact_id')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('customer_name');

        if (error) throw error;
        if (data) setCustomers(data);
      } catch (err) {
        console.error('Error loading customers:', err);
      }
    };

    loadCustomers();
  }, [activeOrganizationId]);

  // Load contacts for selected customer
  const selectedCustomerId = watch('customer_id');
  useEffect(() => {
    const loadContacts = async () => {
      if (!selectedCustomerId || !activeOrganizationId) {
        setContacts([]);
        return;
      }

      try {
        const { data, error } = await supabase
          .from('DirectoryContacts')
          .select('id, contact_name, email, primary_phone, customer_id')
          .eq('customer_id', selectedCustomerId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('contact_name');

        if (error) throw error;
        if (data) setContacts(data);
      } catch (err) {
        console.error('Error loading contacts:', err);
      }
    };

    loadContacts();
  }, [selectedCustomerId, activeOrganizationId]);

  // Helper function to calculate price with tier discount for Sales Orders
  // Sales Orders always show MSRP with tier discounts applied (In-Sell price)
  const calculatePriceWithDiscount = (line: any) => {
    const msrp = line.unit_price_snapshot || line.unit_price || 0;
    const discountPct = line.discount_pct_used || 0;
    const computedQty = line.computed_qty || line.qty || 1;
    
    // Calculate price after discount: MSRP * (1 - discount%)
    const unitPriceWithDiscount = msrp * (1 - discountPct / 100);
    const lineTotalWithDiscount = unitPriceWithDiscount * computedQty;
    
    return { unitPriceWithDiscount, lineTotalWithDiscount };
  };

  // Calculate totals from sale order lines
  // Sales Orders always show prices with tier discounts (In-Sell price)
  const totals = useMemo(() => {
    const subtotal = saleOrderLines.reduce((sum, line) => {
      const { lineTotalWithDiscount } = calculatePriceWithDiscount(line);
      return sum + lineTotalWithDiscount;
    }, 0);
    const tax = saleOrderData?.tax || 0;
    const discount = saleOrderData?.discount_amount || 0;
    const total = subtotal + tax - discount;

    return { subtotal, tax, discount, total };
  }, [saleOrderLines, saleOrderData]);

  // Validate status change is allowed
  const isStatusChangeAllowed = (currentStatus: SaleOrderStatus, newStatus: SaleOrderStatus): boolean => {
    // Only allow manual changes:
    // 1. Draft → Confirmed
    // 2. Ready for Delivery → Delivered
    // All other changes are automatic from ManufacturingOrder
    if (currentStatus === 'Draft' && newStatus === 'Confirmed') {
      return true;
    }
    if (currentStatus === 'Ready for Delivery' && newStatus === 'Delivered') {
      return true;
    }
    // If status didn't change, allow it
    if (currentStatus === newStatus) {
      return true;
    }
    // All other changes are blocked
    return false;
  };

  // Handle form submit
  const onSubmit = async (data: SaleOrderFormValues) => {
    if (!activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'No organization selected',
      });
      return;
    }

    if (!saleOrderId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Sale order ID is required',
      });
      return;
    }

    // Validate status change
    const currentStatus = saleOrderData?.status as SaleOrderStatus || 'Draft';
    const newStatus = data.status;
    
    if (!isStatusChangeAllowed(currentStatus, newStatus)) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Status Change Not Allowed',
        message: `Cannot change status from "${currentStatus}" to "${newStatus}". Only Draft→Confirmed and Ready for Delivery→Delivered are allowed manually. Other status changes are automatic from Manufacturing Orders.`,
      });
      return;
    }

    setIsSaving(true);
    setSaveError(null);

    try {
      const saleOrderUpdateData: any = {
        sale_order_no: data.sale_order_no,
        customer_id: data.customer_id,
        status: data.status,
        currency: data.currency,
        notes: data.notes || null,
        subtotal: totals.subtotal,
        tax: totals.tax,
        discount_amount: totals.discount,
        total: totals.total,
      };

      await updateSaleOrder(saleOrderId, saleOrderUpdateData);
      
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: 'Sale order updated successfully',
      });
      
      // Navigate back to sale orders list
      router.navigate('/sale-orders');
    } catch (err: any) {
      console.error('Error saving sale order:', err);
      setSaveError(err.message || 'Failed to save sale order');
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to save sale order',
      });
    } finally {
      setIsSaving(false);
    }
  };

  // Get selected customer name
  const selectedCustomer = customers.find(c => c.id === selectedCustomerId);
  const selectedContact = contacts.find(c => c.id === selectedContactId);

  if (!saleOrderId) {
    return (
      <div className="py-6 px-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error</p>
          <p className="text-sm text-red-700">Sale order ID is required</p>
        </div>
      </div>
    );
  }

  return (
    <div className="py-6 px-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">
            {saleOrderId ? 'Edit Sales Order' : 'New Sales Order'}
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {saleOrderId ? 'Edit sales order information' : 'Create a new sales order'}
          </p>
        </div>

        <div className="flex items-center gap-3">
          {saleOrderId && saleOrderData && (
            <button
              type="button"
              onClick={() => {
                // TODO: Implement PDF download for sale orders
                useUIStore.getState().addNotification({
                  type: 'info',
                  title: 'Info',
                  message: 'PDF download for sale orders coming soon',
                });
              }}
              className="flex items-center gap-2 px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
              title="Download PDF"
            >
              <Download className="w-4 h-4" />
              Download PDF
            </button>
          )}
          <button
            type="button"
            onClick={() => router.navigate('/sale-orders')}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
          >
            Close
          </button>
          <button
            type="button"
            onClick={handleSubmit(onSubmit)}
            disabled={isSaving || isUpdating}
            className="px-4 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            {isSaving || isUpdating ? 'Saving...' : 'Save'}
          </button>
        </div>
      </div>

      {saveError && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {saveError}
        </div>
      )}

      {/* Sale Order Form */}
      <div className="bg-white border border-gray-200 rounded-lg p-6 mb-4">
        <div className="grid grid-cols-12 gap-4">
          {/* Sale Order Number */}
          <div className="col-span-12 md:col-span-6">
            <Label htmlFor="sale_order_no">Sales Order Number *</Label>
            <Input
              id="sale_order_no"
              {...register('sale_order_no')}
              error={errors.sale_order_no?.message}
              disabled={true} // Read-only, generated by system
            />
          </div>

          {/* Customer */}
          <div className="col-span-12 md:col-span-6">
            <Label htmlFor="customer_id">Customer *</Label>
            <SelectShadcn
              value={watch('customer_id') || ''}
              onValueChange={(value) => {
                setValue('customer_id', value);
                setSelectedContactId(''); // Reset contact when customer changes
              }}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select customer" />
              </SelectTrigger>
              <SelectContent>
                {customers.map((customer) => (
                  <SelectItem key={customer.id} value={customer.id}>
                    {customer.customer_name}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
            {errors.customer_id && (
              <p className="text-red-600 text-xs mt-1">{errors.customer_id.message}</p>
            )}
          </div>

          {/* Contact */}
          <div className="col-span-12 md:col-span-6">
            <Label htmlFor="contact_id">Contact</Label>
            <SelectShadcn
              value={selectedContactId}
              onValueChange={setSelectedContactId}
              disabled={!selectedCustomerId}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select contact" />
              </SelectTrigger>
              <SelectContent>
                {contacts.map((contact) => (
                  <SelectItem key={contact.id} value={contact.id}>
                    {contact.contact_name}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
          </div>

          {/* Status */}
          <div className="col-span-12 md:col-span-3">
            <Label htmlFor="status">Status *</Label>
            <SelectShadcn
              value={watch('status') || 'Draft'}
              onValueChange={(value) => {
                const validStatus = value as SaleOrderStatus;
                const currentStatus = saleOrderData?.status as SaleOrderStatus || 'Draft';
                
                // Validate status change
                if (!isStatusChangeAllowed(currentStatus, validStatus)) {
                  useUIStore.getState().addNotification({
                    type: 'error',
                    title: 'Status Change Not Allowed',
                    message: `Cannot change status from "${currentStatus}" to "${validStatus}". Only Draft→Confirmed and Ready for Delivery→Delivered are allowed manually.`,
                  });
                  // Reset to current status
                  setValue('status', currentStatus);
                  return;
                }
                
                setValue('status', validStatus);
              }}
              disabled={(() => {
                const currentStatus = saleOrderData?.status as SaleOrderStatus || 'Draft';
                // Disable if current status is not Draft or Ready for Delivery
                return currentStatus !== 'Draft' && currentStatus !== 'Ready for Delivery';
              })()}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {SALE_ORDER_STATUS_OPTIONS.map((option) => {
                  const currentStatus = saleOrderData?.status as SaleOrderStatus || 'Draft';
                  const isAllowed = isStatusChangeAllowed(currentStatus, option.value as SaleOrderStatus);
                  
                  return (
                    <SelectItem 
                      key={option.value} 
                      value={option.value}
                      disabled={!isAllowed && currentStatus !== option.value}
                    >
                      {option.label}
                      {!isAllowed && currentStatus !== option.value && ' (Automatic)'}
                    </SelectItem>
                  );
                })}
              </SelectContent>
            </SelectShadcn>
            {saleOrderData?.status && (
              <p className="mt-1 text-xs text-gray-500">
                {(() => {
                  const currentStatus = saleOrderData.status as SaleOrderStatus;
                  if (currentStatus === 'Draft') {
                    return 'You can change to Confirmed manually. Other statuses are automatic.';
                  }
                  if (currentStatus === 'Ready for Delivery') {
                    return 'You can change to Delivered manually. Other statuses are automatic.';
                  }
                  return 'Status changes are automatic from Manufacturing Orders.';
                })()}
              </p>
            )}
          </div>

          {/* Currency */}
          <div className="col-span-12 md:col-span-3">
            <Label htmlFor="currency">Currency *</Label>
            <SelectShadcn
              value={watch('currency') || 'USD'}
              onValueChange={(value) => setValue('currency', value)}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {CURRENCY_OPTIONS.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
          </div>

          {/* Quote Reference */}
          {saleOrderData?.Quotes && (
            <div className="col-span-12">
              <Label>Related Quote</Label>
              <div className="mt-1 text-sm text-gray-700">
                Quote #{saleOrderData.Quotes.quote_no}
              </div>
            </div>
          )}

          {/* Notes */}
          <div className="col-span-12">
            <Label htmlFor="notes">Notes</Label>
            <textarea
              id="notes"
              {...register('notes')}
              rows={3}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
              placeholder="Add any additional notes or comments..."
            />
          </div>

          {/* Summary */}
          {saleOrderId && (
            <div className="col-span-12 border-t border-gray-200 pt-4 mt-4">
              <div className="flex justify-end">
                <div className="w-64">
                  <div className="space-y-2">
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-600">Subtotal:</span>
                      <span className="font-medium">{formatCurrency(totals.subtotal, watch('currency'))}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-600">Tax:</span>
                      <span className="font-medium">{formatCurrency(totals.tax, watch('currency'))}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-600">Discount:</span>
                      <span className="font-medium">{formatCurrency(totals.discount, watch('currency'))}</span>
                    </div>
                    <div className="flex justify-between text-lg font-semibold border-t border-gray-200 pt-2">
                      <span>Total:</span>
                      <span>{formatCurrency(totals.total, watch('currency'))}</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Sale Order Lines Section */}
      {saleOrderId && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
          <div className="py-4 px-6 border-b border-gray-200">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-semibold text-foreground">Sales Order Lines</h2>
                <p className="text-sm text-gray-500 mt-1">{saleOrderLines.length} {saleOrderLines.length === 1 ? 'line' : 'lines'}</p>
              </div>
            </div>
          </div>

          {loadingLines ? (
            <div className="p-6 text-center text-gray-500">Loading lines...</div>
          ) : saleOrderLines.length === 0 ? (
            <div className="p-6 text-center text-gray-500">No lines found for this sales order.</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Line #</th>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Description</th>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Product Type</th>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Collection</th>
                    <th className="py-3 px-6 text-right text-xs font-medium text-gray-700 uppercase tracking-wider">Qty</th>
                    <th className="py-3 px-6 text-right text-xs font-medium text-gray-700 uppercase tracking-wider">Unit Price</th>
                    <th className="py-3 px-6 text-right text-xs font-medium text-gray-700 uppercase tracking-wider">Total Price</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {saleOrderLines.map((line: any) => {
                    const productTypeName = line.product_type || 'N/A';
                    const collectionDisplay = line.collection_name && line.variant_name
                      ? `${line.collection_name} - ${line.variant_name}`
                      : line.collection_name || line.variant_name || 'N/A';

                    return (
                      <tr key={line.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {line.line_number}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {line.description || line.CatalogItems?.item_name || 'N/A'}
                        </td>
                        <td className="py-4 px-6 text-gray-900 text-sm font-medium">
                          {productTypeName}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {collectionDisplay}
                        </td>
                        <td className="py-4 px-6 text-right text-gray-900 text-sm">
                          {line.qty ? line.qty.toFixed(0) : 'N/A'}
                        </td>
                        <td className="py-4 px-6 text-right text-gray-900 text-sm">
                          {(() => {
                            const { unitPriceWithDiscount } = calculatePriceWithDiscount(line);
                            return formatCurrency(unitPriceWithDiscount, watch('currency'));
                          })()}
                        </td>
                        <td className="py-4 px-6 text-right text-gray-900 text-sm">
                          <div className="font-medium">
                            {(() => {
                              const { lineTotalWithDiscount } = calculatePriceWithDiscount(line);
                              const discountPct = line.discount_pct_used || 0;
                              return (
                                <>
                                  {formatCurrency(lineTotalWithDiscount, watch('currency'))}
                                  {discountPct > 0 && (
                                    <div className="text-xs text-gray-500 mt-1 font-normal">
                                      {discountPct.toFixed(1)}% tier discount
                                    </div>
                                  )}
                                </>
                              );
                            })()}
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
