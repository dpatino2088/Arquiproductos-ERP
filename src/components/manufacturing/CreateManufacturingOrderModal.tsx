import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useSaleOrders } from '../../hooks/useSaleOrders';
import { useCreateManufacturingOrder, ManufacturingOrderPriority } from '../../hooks/useManufacturing';
import { useUIStore } from '../../stores/ui-store';
import { X } from 'lucide-react';
import Input from '../ui/Input';
import Label from '../ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../ui/SelectShadcn';

const createMOSchema = z.object({
  sale_order_id: z.string().uuid('Sale Order is required'),
  scheduled_start_date: z.string().optional(),
  scheduled_end_date: z.string().optional(),
  priority: z.enum(['low', 'normal', 'high', 'urgent']).optional(),
  notes: z.string().optional(),
});

type CreateMOFormValues = z.infer<typeof createMOSchema>;

const PRIORITY_OPTIONS = [
  { value: 'low', label: 'Low' },
  { value: 'normal', label: 'Normal' },
  { value: 'high', label: 'High' },
  { value: 'urgent', label: 'Urgent' },
] as const;

interface CreateManufacturingOrderModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: (moId: string) => void;
}

export default function CreateManufacturingOrderModal({
  isOpen,
  onClose,
  onSuccess,
}: CreateManufacturingOrderModalProps) {
  const { saleOrders, loading: loadingSaleOrders } = useSaleOrders();
  const { createManufacturingOrder, isCreating } = useCreateManufacturingOrder();
  const [searchTerm, setSearchTerm] = useState('');

  const {
    register,
    handleSubmit,
    formState: { errors },
    setValue,
    watch,
    reset,
  } = useForm<CreateMOFormValues>({
    resolver: zodResolver(createMOSchema),
    defaultValues: {
      priority: 'normal',
    },
  });

  // Filter sale orders for dropdown
  const filteredSaleOrders = saleOrders.filter(so => {
    if (!searchTerm) return true;
    const searchLower = searchTerm.toLowerCase();
    return (
      so.sale_order_no.toLowerCase().includes(searchLower) ||
      so.DirectoryCustomers?.customer_name.toLowerCase().includes(searchLower) ||
      so.Quotes?.quote_no.toLowerCase().includes(searchLower)
    );
  });

  // Reset form when modal closes
  useEffect(() => {
    if (!isOpen) {
      reset();
      setSearchTerm('');
    }
  }, [isOpen, reset]);

  const onSubmit = async (data: CreateMOFormValues) => {
    try {
      const mo = await createManufacturingOrder({
        sale_order_id: data.sale_order_id,
        scheduled_start_date: data.scheduled_start_date || undefined,
        scheduled_end_date: data.scheduled_end_date || undefined,
        priority: (data.priority as ManufacturingOrderPriority) || 'normal',
        notes: data.notes || undefined,
      });

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: `Manufacturing Order ${mo.manufacturing_order_no} created successfully`,
      });

      onSuccess?.(mo.id);
      onClose();
    } catch (err: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to create manufacturing order',
      });
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <h2 className="text-xl font-semibold text-gray-900">Create Manufacturing Order</h2>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 rounded transition-colors"
            aria-label="Close"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit(onSubmit)} className="flex-1 overflow-y-auto p-6">
          <div className="space-y-4">
            {/* Sale Order Selection */}
            <div>
              <Label htmlFor="sale_order_id">Sale Order *</Label>
              <div className="mt-1">
                <input
                  type="text"
                  placeholder="Search by order #, customer, or quote #..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm mb-2"
                />
                <SelectShadcn
                  value={watch('sale_order_id') || ''}
                  onValueChange={(value) => setValue('sale_order_id', value)}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select a sale order" />
                  </SelectTrigger>
                  <SelectContent>
                    {loadingSaleOrders ? (
                      <div className="p-4 text-center text-gray-500">Loading sale orders...</div>
                    ) : filteredSaleOrders.length === 0 ? (
                      <div className="p-4 text-center text-gray-500">No sale orders found</div>
                    ) : (
                      filteredSaleOrders.map((so) => (
                        <SelectItem key={so.id} value={so.id}>
                          {so.sale_order_no} - {so.DirectoryCustomers?.customer_name || 'N/A'} 
                          {so.Quotes?.quote_no && ` (Quote: ${so.Quotes.quote_no})`}
                        </SelectItem>
                      ))
                    )}
                  </SelectContent>
                </SelectShadcn>
              </div>
              {errors.sale_order_id && (
                <p className="text-red-600 text-xs mt-1">{errors.sale_order_id.message}</p>
              )}
            </div>

            {/* Priority */}
            <div>
              <Label htmlFor="priority">Priority</Label>
              <SelectShadcn
                value={watch('priority') || 'normal'}
                onValueChange={(value) => setValue('priority', value as ManufacturingOrderPriority)}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {PRIORITY_OPTIONS.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </SelectShadcn>
            </div>

            {/* Scheduled Dates */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="scheduled_start_date">Scheduled Start Date</Label>
                <Input
                  id="scheduled_start_date"
                  type="date"
                  {...register('scheduled_start_date')}
                  error={errors.scheduled_start_date?.message}
                />
              </div>
              <div>
                <Label htmlFor="scheduled_end_date">Scheduled End Date</Label>
                <Input
                  id="scheduled_end_date"
                  type="date"
                  {...register('scheduled_end_date')}
                  error={errors.scheduled_end_date?.message}
                />
              </div>
            </div>

            {/* Notes */}
            <div>
              <Label htmlFor="notes">Notes</Label>
              <textarea
                id="notes"
                {...register('notes')}
                rows={3}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                placeholder="Add any notes or comments..."
              />
            </div>
          </div>
        </form>

        {/* Footer */}
        <div className="flex items-center justify-end gap-3 p-6 border-t border-gray-200">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={handleSubmit(onSubmit)}
            disabled={isCreating}
            className="px-4 py-2 text-sm font-medium text-white rounded-lg transition-colors hover:opacity-90 disabled:opacity-50"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            {isCreating ? 'Creating...' : 'Create Manufacturing Order'}
          </button>
        </div>
      </div>
    </div>
  );
}
