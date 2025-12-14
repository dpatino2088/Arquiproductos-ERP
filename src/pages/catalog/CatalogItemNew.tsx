import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { useUIStore } from '../../stores/ui-store';
import Input from '../../components/ui/Input';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Label from '../../components/ui/Label';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useCatalogItems, useCreateCatalogItem, useUpdateCatalogItem } from '../../hooks/useCatalog';
import { MeasureBasis, FabricPricingMode } from '../../types/catalog';
import { supabase } from '../../lib/supabase/client';

// Measure basis options
const MEASURE_BASIS_OPTIONS = [
  { value: 'unit', label: 'Unit' },
  { value: 'width_linear', label: 'Width Linear' },
  { value: 'height_linear', label: 'Height Linear' },
  { value: 'area', label: 'Area' },
  { value: 'fabric', label: 'Fabric' },
] as const;

// Fabric pricing mode options
const FABRIC_PRICING_MODE_OPTIONS = [
  { value: 'per_linear_m', label: 'Per Linear Meter' },
  { value: 'per_sqm', label: 'Per Square Meter' },
] as const;

// Schema for CatalogItem
const catalogItemSchema = z.object({
  sku: z.string().min(1, 'SKU is required'),
  name: z.string().min(1, 'Name is required'),
  description: z.string().optional(),
  measure_basis: z.enum(['unit', 'width_linear', 'height_linear', 'area', 'fabric']),
  uom: z.string().min(1, 'Unit of measure is required'),
  is_fabric: z.boolean(),
  roll_width_m: z.number().optional().nullable(),
  fabric_pricing_mode: z.enum(['per_linear_m', 'per_sqm']).optional().nullable(),
  unit_price: z.number().min(0, 'Unit price must be >= 0'),
  cost_price: z.number().min(0, 'Cost price must be >= 0'),
  active: z.boolean(),
  discontinued: z.boolean(),
}).refine((data) => {
  // If is_fabric is true, fabric_pricing_mode is required
  if (data.is_fabric && !data.fabric_pricing_mode) {
    return false;
  }
  return true;
}, {
  message: 'Fabric pricing mode is required for fabric items',
  path: ['fabric_pricing_mode'],
}).refine((data) => {
  // If is_fabric is true and pricing is per_linear_m, roll_width_m is required
  if (data.is_fabric && data.fabric_pricing_mode === 'per_linear_m' && (!data.roll_width_m || data.roll_width_m <= 0)) {
    return false;
  }
  return true;
}, {
  message: 'Roll width is required for fabric items with per linear meter pricing',
  path: ['roll_width_m'],
});

type CatalogItemFormValues = z.infer<typeof catalogItemSchema>;

export default function CatalogItemNew() {
  const [activeTab, setActiveTab] = useState<'profile' | 'settings' | 'rates' | 'attachments'>('profile');
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [itemId, setItemId] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();
  const { createItem, isCreating } = useCreateCatalogItem();
  const { updateItem, isUpdating } = useUpdateCatalogItem();
  
  // Get current user's role and permissions
  const { canEditCustomers, loading: roleLoading } = useCurrentOrgRole();
  
  // Determine if form should be read-only (using canEditCustomers as proxy for now)
  const isReadOnly = !canEditCustomers;

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    formState: { errors },
  } = useForm<CatalogItemFormValues>({
    resolver: zodResolver(catalogItemSchema),
    defaultValues: {
      measure_basis: 'unit',
      uom: 'unit',
      is_fabric: false,
      unit_price: 0,
      cost_price: 0,
      active: true,
      discontinued: false,
    },
  });

  const isFabric = watch('is_fabric');
  const measureBasis = watch('measure_basis');
  const fabricPricingMode = watch('fabric_pricing_mode');

  // Get item ID from URL if in edit mode
  useEffect(() => {
    const path = window.location.pathname;
    const match = path.match(/\/catalog\/items\/edit\/([^/]+)/);
    if (match && match[1]) {
      setItemId(match[1]);
    }
  }, []);

  // Load item data when in edit mode
  useEffect(() => {
    const loadItemData = async () => {
      if (!itemId || !activeOrganizationId) return;

      try {
        const { data, error } = await supabase
          .from('CatalogItems')
          .select('*')
          .eq('id', itemId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .maybeSingle();

        if (error) {
          console.error('Error loading item:', error);
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Error loading item',
            message: 'Could not load item data. Please try again.',
          });
          return;
        }

        if (data) {
          setValue('sku', data.sku || '');
          setValue('name', data.name || '');
          setValue('description', data.description || '');
          setValue('measure_basis', data.measure_basis);
          setValue('uom', data.uom || 'unit');
          setValue('is_fabric', data.is_fabric || false);
          setValue('roll_width_m', data.roll_width_m);
          setValue('fabric_pricing_mode', data.fabric_pricing_mode);
          setValue('unit_price', data.unit_price || 0);
          setValue('cost_price', data.cost_price || 0);
          setValue('active', data.active ?? true);
          setValue('discontinued', data.discontinued || false);
        }
      } catch (err) {
        console.error('Error loading item data:', err);
      }
    };

    loadItemData();
  }, [itemId, activeOrganizationId, setValue]);

  // Show message if no organization is selected
  if (!activeOrganizationId) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800">
            Select an organization to continue.
          </p>
        </div>
      </div>
    );
  }

  const onSubmit = async (values: CatalogItemFormValues) => {
    if (!activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'No organization selected. Please select an organization.',
      });
      return;
    }

    setIsSaving(true);
    setSaveError(null);

    try {
      const itemData: any = {
        sku: values.sku.trim(),
        name: values.name.trim(),
        description: values.description?.trim() || null,
        measure_basis: values.measure_basis,
        uom: values.uom.trim(),
        is_fabric: values.is_fabric,
        roll_width_m: values.is_fabric && values.roll_width_m ? values.roll_width_m : null,
        fabric_pricing_mode: values.is_fabric ? values.fabric_pricing_mode : null,
        unit_price: values.unit_price,
        cost_price: values.cost_price,
        active: values.active,
        discontinued: values.discontinued,
        metadata: {},
      };

      if (itemId) {
        // Update existing item
        await updateItem(itemId, itemData);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Item updated',
          message: 'Catalog item has been updated successfully.',
        });
      } else {
        // Create new item
        await createItem(itemData);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Item created',
          message: 'Catalog item has been created successfully.',
        });
      }

      router.navigate('/catalog/items');
    } catch (err: any) {
      console.error('Error saving item:', err);
      setSaveError(err.message || 'Failed to save item. Please try again.');
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error saving item',
        message: err.message || 'Failed to save item. Please try again.',
      });
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="py-6 px-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">
            {itemId ? 'Edit Item' : 'New Item'}
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {itemId ? 'Edit catalog item information' : 'Create a new catalog item'}
          </p>
        </div>
        
        {/* Action Buttons */}
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => router.navigate('/catalog/items')}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
            title="Close"
          >
            Cancel
          </button>
          <button
            type="button"
            className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            onClick={handleSubmit(onSubmit)}
            disabled={isSaving || isReadOnly}
            title={isReadOnly ? 'You only have read permissions' : undefined}
          >
            {isSaving ? 'Saving...' : isReadOnly ? 'Read Only' : 'Save'}
          </button>
          {!isReadOnly && (
            <button
              type="button"
              className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
              style={{ backgroundColor: '#10b981' }}
              onClick={handleSubmit(onSubmit)}
              disabled={isSaving}
            >
              {isSaving ? 'Saving...' : 'Save and Finish'}
            </button>
          )}
        </div>
      </div>

      {saveError && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {saveError}
        </div>
      )}

      {/* Main Content Card */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        {/* Tab Toggle Header */}
        <div 
          className="border-b"
          style={{
            height: '2.625rem',
            backgroundColor: 'var(--gray-100)',
            borderColor: 'var(--gray-250)'
          }}
        >
          <div className="flex items-stretch h-full" role="tablist">
            {(['profile', 'settings', 'rates', 'attachments'] as const).map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`transition-colors flex items-center justify-start ${
                  tab !== 'profile' ? 'border-r' : ''
                } ${
                  activeTab === tab
                    ? 'bg-white font-semibold'
                    : 'hover:bg-white/50 font-normal'
                }`}
                style={{
                  fontSize: '12px',
                  padding: '0 48px',
                  height: '100%',
                  minWidth: '140px',
                  width: 'auto',
                  color: activeTab === tab ? 'var(--primary-brand-hex)' : 'var(--graphite-black-hex)',
                  borderColor: 'var(--gray-250)',
                  borderBottom: activeTab === tab ? '2px solid var(--primary-brand-hex)' : 'none'
                }}
                role="tab"
                aria-selected={activeTab === tab}
              >
                {tab.charAt(0).toUpperCase() + tab.slice(1)}
              </button>
            ))}
          </div>
        </div>

        {/* Form Body */}
        <div className="py-6 px-6">
          {activeTab === 'profile' && (
            <div className="grid grid-cols-12 gap-x-4 gap-y-4">
              {/* General Information */}
              <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                <div className="col-span-6">
                  <Label htmlFor="name" className="text-xs" required>Name</Label>
                  <Input 
                    id="name" 
                    {...register('name')}
                    className="py-1 text-xs"
                    error={errors.name?.message}
                    disabled={isReadOnly}
                    placeholder="Enter item name"
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="sku" className="text-xs" required>SKU</Label>
                  <Input 
                    id="sku" 
                    {...register('sku')}
                    className="py-1 text-xs"
                    error={errors.sku?.message}
                    disabled={isReadOnly}
                    placeholder="Enter SKU"
                  />
                </div>
                <div className="col-span-3">
                  <Label htmlFor="uom" className="text-xs" required>Unit of Measure</Label>
                  <Input 
                    id="uom" 
                    {...register('uom')}
                    className="py-1 text-xs"
                    error={errors.uom?.message}
                    disabled={isReadOnly}
                    placeholder="unit"
                  />
                </div>
              </div>

              <div className="col-span-12">
                <Label htmlFor="description" className="text-xs">Description</Label>
                <textarea
                  id="description"
                  {...register('description')}
                  className="w-full px-2.5 py-1.5 text-xs border border-gray-200 bg-gray-50 rounded-md focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 disabled:opacity-50"
                  rows={3}
                  disabled={isReadOnly}
                  placeholder="Type here..."
                />
              </div>

              {/* Measurement */}
              <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                <div className="col-span-4">
                  <Label htmlFor="measure_basis" className="text-xs" required>Measure Basis</Label>
                  <SelectShadcn
                    value={watch('measure_basis') || 'unit'}
                    onValueChange={(value) => {
                      setValue('measure_basis', value as MeasureBasis, { shouldValidate: true });
                    }}
                    disabled={isReadOnly}
                  >
                    <SelectTrigger className={`py-1 text-xs ${errors.measure_basis ? 'border-red-300 bg-red-50' : ''}`}>
                      <SelectValue placeholder="Select measure basis" />
                    </SelectTrigger>
                    <SelectContent>
                      {MEASURE_BASIS_OPTIONS.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                          {option.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                  {errors.measure_basis && (
                    <p className="text-xs text-red-600 mt-1">{errors.measure_basis.message}</p>
                  )}
                </div>

                <div className="col-span-4">
                  <div className="flex items-center gap-2 mt-6">
                    <input
                      type="checkbox"
                      id="is_fabric"
                      {...register('is_fabric')}
                      checked={isFabric}
                      onChange={(e) => {
                        setValue('is_fabric', e.target.checked, { shouldValidate: true });
                        if (!e.target.checked) {
                          setValue('fabric_pricing_mode', null);
                          setValue('roll_width_m', null);
                        }
                      }}
                      className="h-4 w-4"
                      disabled={isReadOnly}
                    />
                    <Label htmlFor="is_fabric" className="text-xs mb-0">Is Fabric</Label>
                  </div>
                </div>

                {isFabric && (
                  <>
                    <div className="col-span-4">
                      <Label htmlFor="roll_width_m" className="text-xs" required={fabricPricingMode === 'per_linear_m'}>Roll Width (m)</Label>
                      <Input 
                        id="roll_width_m" 
                        type="number"
                        step="0.001"
                        {...register('roll_width_m', { valueAsNumber: true })}
                        className="py-1 text-xs"
                        error={errors.roll_width_m?.message}
                        disabled={isReadOnly}
                        placeholder="0.000"
                      />
                    </div>
                    <div className="col-span-4">
                      <Label htmlFor="fabric_pricing_mode" className="text-xs" required>Fabric Pricing Mode</Label>
                      <SelectShadcn
                        value={watch('fabric_pricing_mode') || ''}
                        onValueChange={(value) => {
                          setValue('fabric_pricing_mode', value as FabricPricingMode, { shouldValidate: true });
                        }}
                        disabled={isReadOnly}
                      >
                        <SelectTrigger className={`py-1 text-xs ${errors.fabric_pricing_mode ? 'border-red-300 bg-red-50' : ''}`}>
                          <SelectValue placeholder="Select pricing mode" />
                        </SelectTrigger>
                        <SelectContent>
                          {FABRIC_PRICING_MODE_OPTIONS.map((option) => (
                            <SelectItem key={option.value} value={option.value}>
                              {option.label}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </SelectShadcn>
                      {errors.fabric_pricing_mode && (
                        <p className="text-xs text-red-600 mt-1">{errors.fabric_pricing_mode.message}</p>
                      )}
                    </div>
                  </>
                )}
              </div>
            </div>
          )}

          {activeTab === 'settings' && (
            <div className="grid grid-cols-12 gap-x-4 gap-y-4">
              <div className="col-span-12">
                <p className="text-xs text-gray-500">Settings tab - To be implemented</p>
              </div>
            </div>
          )}

          {activeTab === 'rates' && (
            <div className="grid grid-cols-12 gap-x-4 gap-y-4">
              <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                <div className="col-span-4">
                  <Label htmlFor="unit_price" className="text-xs" required>Unit Price</Label>
                  <Input 
                    id="unit_price" 
                    type="number"
                    step="0.01"
                    {...register('unit_price', { valueAsNumber: true })}
                    className="py-1 text-xs"
                    error={errors.unit_price?.message}
                    disabled={isReadOnly}
                    placeholder="0.00"
                  />
                </div>
                <div className="col-span-4">
                  <Label htmlFor="cost_price" className="text-xs" required>Cost Price</Label>
                  <Input 
                    id="cost_price" 
                    type="number"
                    step="0.01"
                    {...register('cost_price', { valueAsNumber: true })}
                    className="py-1 text-xs"
                    error={errors.cost_price?.message}
                    disabled={isReadOnly}
                    placeholder="0.00"
                  />
                </div>
                <div className="col-span-4">
                  <div className="flex items-center gap-2 mt-6">
                    <input
                      type="checkbox"
                      id="active"
                      {...register('active')}
                      className="h-4 w-4"
                      disabled={isReadOnly}
                    />
                    <Label htmlFor="active" className="text-xs mb-0">Active</Label>
                  </div>
                </div>
                <div className="col-span-4">
                  <div className="flex items-center gap-2 mt-6">
                    <input
                      type="checkbox"
                      id="discontinued"
                      {...register('discontinued')}
                      className="h-4 w-4"
                      disabled={isReadOnly}
                    />
                    <Label htmlFor="discontinued" className="text-xs mb-0">Discontinued</Label>
                  </div>
                </div>
              </div>
            </div>
          )}

          {activeTab === 'attachments' && (
            <div className="grid grid-cols-12 gap-x-4 gap-y-4">
              <div className="col-span-12">
                <p className="text-xs text-gray-500">Attachments tab - To be implemented</p>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

