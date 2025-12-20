import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useQuoteLineCosts, useUpdateQuoteLineCosts } from '../../hooks/useCosts';
import { QuoteLineCosts } from '../../types/pricing';
import Input from '../ui/Input';
import Label from '../ui/Label';
import Textarea from '../ui/Textarea';
import { ChevronDown, ChevronUp, DollarSign } from 'lucide-react';

// Format currency
const formatCurrency = (amount: number, currency: string = 'USD') => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 4,
  }).format(amount);
};

// Schema for overrides
const overridesSchema = z.object({
  is_overridden: z.boolean(),
  override_reason: z.string().optional().nullable(),
  override_base_material_cost: z.number().min(0).optional().nullable(),
  override_labor_cost: z.number().min(0).optional().nullable(),
  override_shipping_cost: z.number().min(0).optional().nullable(),
  override_import_tax_cost: z.number().min(0).optional().nullable(),
  override_handling_cost: z.number().min(0).optional().nullable(),
  override_additional_cost: z.number().min(0).optional().nullable(),
}).refine((data) => {
  // If is_overridden is true, override_reason is required
  if (data.is_overridden && !data.override_reason?.trim()) {
    return false;
  }
  return true;
}, {
  message: 'Override reason is required when overrides are enabled',
  path: ['override_reason'],
});

type OverridesFormData = z.infer<typeof overridesSchema>;

interface QuoteLineCostsSectionProps {
  quoteLineId: string;
  currency?: string;
  onUpdate?: () => void;
}

export default function QuoteLineCostsSection({ 
  quoteLineId, 
  currency = 'USD',
  onUpdate 
}: QuoteLineCostsSectionProps) {
  const [showCostSummary, setShowCostSummary] = useState(false);
  const [showOverrides, setShowOverrides] = useState(false);
  const { costs, loading, error, refetch } = useQuoteLineCosts(quoteLineId);
  const { updateCosts, isUpdating } = useUpdateQuoteLineCosts();

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    formState: { errors },
  } = useForm<OverridesFormData>({
    resolver: zodResolver(overridesSchema),
    defaultValues: {
      is_overridden: costs?.is_overridden || false,
      override_reason: costs?.override_reason || null,
      override_base_material_cost: costs?.override_base_material_cost || null,
      override_labor_cost: costs?.override_labor_cost || null,
      override_shipping_cost: costs?.override_shipping_cost || null,
      override_import_tax_cost: costs?.override_import_tax_cost || null,
      override_handling_cost: costs?.override_handling_cost || null,
      override_additional_cost: costs?.override_additional_cost || null,
    },
  });

  const isOverridden = watch('is_overridden');

  // Update form when costs change
  if (costs && !loading) {
    setValue('is_overridden', costs.is_overridden);
    setValue('override_reason', costs.override_reason);
    setValue('override_base_material_cost', costs.override_base_material_cost);
    setValue('override_labor_cost', costs.override_labor_cost);
    setValue('override_shipping_cost', costs.override_shipping_cost);
    setValue('override_import_tax_cost', costs.override_import_tax_cost);
    setValue('override_handling_cost', costs.override_handling_cost);
    setValue('override_additional_cost', costs.override_additional_cost);
  }

  const onSubmit = async (data: OverridesFormData) => {
    try {
      await updateCosts(quoteLineId, {
        is_overridden: data.is_overridden,
        override_reason: data.override_reason || null,
        override_base_material_cost: data.override_base_material_cost || null,
        override_labor_cost: data.override_labor_cost || null,
        override_shipping_cost: data.override_shipping_cost || null,
        override_import_tax_cost: data.override_import_tax_cost || null,
        override_handling_cost: data.override_handling_cost || null,
        override_additional_cost: data.override_additional_cost || null,
      });
      
      await refetch();
      if (onUpdate) onUpdate();
    } catch (err) {
      console.error('Error updating costs:', err);
    }
  };

  // Get effective cost values (use overrides if enabled, otherwise use calculated)
  const getEffectiveCost = (field: keyof QuoteLineCosts): number => {
    if (!costs) return 0;
    
    if (costs.is_overridden) {
      const overrideField = `override_${field}` as keyof QuoteLineCosts;
      const overrideValue = costs[overrideField];
      if (overrideValue !== null && overrideValue !== undefined) {
        return overrideValue as number;
      }
    }
    
    return costs[field] as number;
  };

  const effectiveBaseMaterial = getEffectiveCost('base_material_cost');
  const effectiveLabor = getEffectiveCost('labor_cost');
  const effectiveShipping = getEffectiveCost('shipping_cost');
  const effectiveImportTax = getEffectiveCost('import_tax_cost');
  const effectiveHandling = getEffectiveCost('handling_cost');
  const effectiveAdditional = getEffectiveCost('additional_cost');
  const effectiveTotal = costs?.total_cost || 0;

  if (loading) {
    return (
      <div className="text-sm text-gray-500 py-2">
        Loading costs...
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-sm text-red-600 py-2">
        Error loading costs: {error}
      </div>
    );
  }

  if (!costs) {
    return (
      <div className="text-sm text-gray-500 py-2">
        No cost data available. Costs will be calculated automatically.
      </div>
    );
  }

  return (
    <div className="space-y-4 border-t border-gray-200 pt-4 mt-4">
      {/* Cost Summary Section */}
      <div>
        <button
          type="button"
          onClick={() => setShowCostSummary(!showCostSummary)}
          className="flex items-center justify-between w-full text-left text-sm font-medium text-gray-900 hover:text-gray-700"
        >
          <div className="flex items-center gap-2">
            <DollarSign className="w-4 h-4" />
            <span>Cost Summary</span>
            {costs.is_overridden && (
              <span className="text-xs bg-yellow-100 text-yellow-800 px-2 py-0.5 rounded">
                Overridden
              </span>
            )}
          </div>
          {showCostSummary ? (
            <ChevronUp className="w-4 h-4" />
          ) : (
            <ChevronDown className="w-4 h-4" />
          )}
        </button>

        {showCostSummary && (
          <div className="mt-3 space-y-2 bg-gray-50 rounded-lg p-4">
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <Label className="text-xs text-gray-600 mb-1">Base Material Cost</Label>
                <div className="font-medium text-gray-900">
                  {formatCurrency(effectiveBaseMaterial, costs.currency_code)}
                </div>
              </div>
              <div>
                <Label className="text-xs text-gray-600 mb-1">Labor Cost</Label>
                <div className="font-medium text-gray-900">
                  {formatCurrency(effectiveLabor, costs.currency_code)}
                </div>
              </div>
              <div>
                <Label className="text-xs text-gray-600 mb-1">Shipping Cost</Label>
                <div className="font-medium text-gray-900">
                  {formatCurrency(effectiveShipping, costs.currency_code)}
                </div>
              </div>
              <div>
                <Label className="text-xs text-gray-600 mb-1">Import Tax</Label>
                <div className="font-medium text-gray-900">
                  {formatCurrency(effectiveImportTax, costs.currency_code)}
                </div>
              </div>
              <div>
                <Label className="text-xs text-gray-600 mb-1">Handling</Label>
                <div className="font-medium text-gray-900">
                  {formatCurrency(effectiveHandling, costs.currency_code)}
                </div>
              </div>
              <div>
                <Label className="text-xs text-gray-600 mb-1">Additional Cost</Label>
                <div className="font-medium text-gray-900">
                  {formatCurrency(effectiveAdditional, costs.currency_code)}
                </div>
              </div>
            </div>
            <div className="border-t border-gray-300 pt-2 mt-2">
              <div className="flex items-center justify-between">
                <Label className="text-sm font-semibold text-gray-900">Total Cost</Label>
                <div className="text-lg font-bold text-gray-900">
                  {formatCurrency(effectiveTotal, costs.currency_code)}
                </div>
              </div>
            </div>
            {costs.calculated_at && (
              <div className="text-xs text-gray-500 mt-2">
                Last calculated: {new Date(costs.calculated_at).toLocaleString()}
              </div>
            )}
          </div>
        )}
      </div>

      {/* Overrides Section */}
      <div>
        <button
          type="button"
          onClick={() => setShowOverrides(!showOverrides)}
          className="flex items-center justify-between w-full text-left text-sm font-medium text-gray-900 hover:text-gray-700"
        >
          <span>Overrides</span>
          {showOverrides ? (
            <ChevronUp className="w-4 h-4" />
          ) : (
            <ChevronDown className="w-4 h-4" />
          )}
        </button>

        {showOverrides && (
          <form onSubmit={handleSubmit(onSubmit)} className="mt-3 space-y-4 bg-gray-50 rounded-lg p-4">
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="is_overridden"
                {...register('is_overridden')}
                className="rounded border-gray-300"
              />
              <Label htmlFor="is_overridden" className="text-sm font-medium">
                Enable Cost Overrides
              </Label>
            </div>

            {isOverridden && (
              <>
                <div>
                  <Label htmlFor="override_reason" className="text-xs mb-1">
                    Override Reason <span className="text-red-500">*</span>
                  </Label>
                  <Textarea
                    id="override_reason"
                    {...register('override_reason')}
                    rows={2}
                    placeholder="Explain why costs are being overridden..."
                    error={errors.override_reason?.message}
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <Label htmlFor="override_base_material_cost" className="text-xs mb-1">
                      Base Material Cost Override
                    </Label>
                    <Input
                      id="override_base_material_cost"
                      type="number"
                      step="0.0001"
                      min="0"
                      {...register('override_base_material_cost', {
                        valueAsNumber: true,
                      })}
                      error={errors.override_base_material_cost?.message}
                    />
                  </div>
                  <div>
                    <Label htmlFor="override_labor_cost" className="text-xs mb-1">
                      Labor Cost Override
                    </Label>
                    <Input
                      id="override_labor_cost"
                      type="number"
                      step="0.0001"
                      min="0"
                      {...register('override_labor_cost', {
                        valueAsNumber: true,
                      })}
                      error={errors.override_labor_cost?.message}
                    />
                  </div>
                  <div>
                    <Label htmlFor="override_shipping_cost" className="text-xs mb-1">
                      Shipping Cost Override
                    </Label>
                    <Input
                      id="override_shipping_cost"
                      type="number"
                      step="0.0001"
                      min="0"
                      {...register('override_shipping_cost', {
                        valueAsNumber: true,
                      })}
                      error={errors.override_shipping_cost?.message}
                    />
                  </div>
                  <div>
                    <Label htmlFor="override_import_tax_cost" className="text-xs mb-1">
                      Import Tax Override
                    </Label>
                    <Input
                      id="override_import_tax_cost"
                      type="number"
                      step="0.0001"
                      min="0"
                      {...register('override_import_tax_cost', {
                        valueAsNumber: true,
                      })}
                      error={errors.override_import_tax_cost?.message}
                    />
                  </div>
                  <div>
                    <Label htmlFor="override_handling_cost" className="text-xs mb-1">
                      Handling Cost Override
                    </Label>
                    <Input
                      id="override_handling_cost"
                      type="number"
                      step="0.0001"
                      min="0"
                      {...register('override_handling_cost', {
                        valueAsNumber: true,
                      })}
                      error={errors.override_handling_cost?.message}
                    />
                  </div>
                  <div>
                    <Label htmlFor="override_additional_cost" className="text-xs mb-1">
                      Additional Cost Override
                    </Label>
                    <Input
                      id="override_additional_cost"
                      type="number"
                      step="0.0001"
                      min="0"
                      {...register('override_additional_cost', {
                        valueAsNumber: true,
                      })}
                      error={errors.override_additional_cost?.message}
                    />
                  </div>
                </div>

                <div className="flex justify-end gap-2 pt-2">
                  <button
                    type="submit"
                    disabled={isUpdating}
                    className="px-4 py-2 bg-primary text-white text-sm font-medium rounded-md hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {isUpdating ? 'Saving...' : 'Save Overrides'}
                  </button>
                </div>
              </>
            )}
          </form>
        )}
      </div>
    </div>
  );
}





