import { useState, useEffect, useRef } from 'react';
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
import { useCatalogItems, useCreateCatalogItem, useUpdateCatalogItem, useLeafItemCategories, useItemCategories } from '../../hooks/useCatalog';
import { useCategoryMargin } from '../../hooks/useCategoryMargins';
import { MeasureBasis, FabricPricingMode } from '../../types/catalog';
import { supabase } from '../../lib/supabase/client';
import { Plus, Trash2, Edit, X } from 'lucide-react';
import ImageUpload from '../../components/ui/ImageUpload';
import FileUpload from '../../components/ui/FileUpload';
import { 
  MEASURE_BASIS_OPTIONS, 
  getValidUomOptions, 
  normalizeUom, 
  normalizeMeasureBasis,
  isUomValidForMeasureBasis,
  validateAndNormalizeUom 
} from '../../lib/uom';

// Re-export for local use (already normalized in uom.ts)
const MEASURE_BASIS_OPTIONS_LOCAL = MEASURE_BASIS_OPTIONS;

// Fabric pricing mode options
const FABRIC_PRICING_MODE_OPTIONS = [
  { value: 'per_linear_m', label: 'Per Linear Meter' },
  { value: 'per_sqm', label: 'Per Square Meter' },
] as const;

// Item type options
const ITEM_TYPE_OPTIONS = [
  { value: 'component', label: 'Component' },
  { value: 'fabric', label: 'Fabric' },
  { value: 'linear', label: 'Linear' },
  { value: 'service', label: 'Service' },
  { value: 'accessory', label: 'Accessory' },
] as const;

// Schema for CatalogItem
const catalogItemSchema = z.object({
  sku: z.string().min(1, 'SKU is required'),
  name: z.string().min(1, 'Name is required'),
  description: z.string().optional(),
  item_category_id: z.string().uuid().optional().nullable(),
  item_type: z.enum(['component', 'fabric', 'linear', 'service', 'accessory']),
  measure_basis: z.enum(['unit', 'linear_m', 'area', 'fabric']),
  uom: z.string().min(1, 'Unit of measure is required'),
  is_fabric: z.boolean(),
  collection_name: z.string().optional().nullable(),
  variant_name: z.string().optional().nullable(),
  roll_width_m: z.number().optional().nullable(),
  fabric_pricing_mode: z.enum(['per_linear_m', 'per_sqm']).optional().nullable(),
  image_url: z.string().url().optional().nullable().or(z.literal('')),
  // Pricing fields
  cost_exw: z.number().min(0, 'Cost EXW must be >= 0').optional().nullable(), // Base cost (EXW = Ex Works)
  default_margin_pct: z.number().min(0).max(100, 'Margin must be between 0 and 100').optional().nullable(), // Default margin percentage
  msrp: z.number().min(0, 'MSRP must be >= 0').optional().nullable(), // Manufacturer's Suggested Retail Price
  // Labor costs
  labor_cost_per_unit: z.number().min(0).optional().nullable(),
  labor_cost_per_hour: z.number().min(0).optional().nullable(),
  labor_hours_per_unit: z.number().min(0).optional().nullable(),
  // Shipping costs
  shipping_cost_base: z.number().min(0).optional().nullable(),
  shipping_cost_per_kg: z.number().min(0).optional().nullable(),
  shipping_cost_per_unit: z.number().min(0).optional().nullable(),
  shipping_cost_percentage: z.number().min(0).max(100).optional().nullable(),
  // Additional costs
  import_tax_pct: z.number().min(0).max(100).optional().nullable(),
  freight_cost: z.number().min(0).optional().nullable(),
  handling_cost: z.number().min(0).optional().nullable(),
  // Legacy fields (kept for compatibility)
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

interface FileItem {
  id: string;
  name: string;
  url: string;
  size: number;
  type: string;
}

export default function CatalogItemNew() {
  const [activeTab, setActiveTab] = useState<'profile' | 'settings' | 'rates' | 'attachments'>('profile');
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [itemId, setItemId] = useState<string | null>(null);
  const [attachments, setAttachments] = useState<FileItem[]>([]);
  const { activeOrganizationId } = useOrganizationContext();
  const { createItem, isCreating } = useCreateCatalogItem();
  const { updateItem, isUpdating } = useUpdateCatalogItem();
  const { categories: leafCategories } = useLeafItemCategories();
  const { categories: allCategories } = useItemCategories();
  
  // Get current user's role and permissions
  const { canEditCustomers, loading: roleLoading } = useCurrentOrgRole();
  
  // Determine if form should be read-only (using canEditCustomers as proxy for now)
  const isReadOnly = !canEditCustomers;

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    clearErrors,
    formState: { errors },
  } = useForm<CatalogItemFormValues>({
    mode: 'onBlur', // Only validate on blur, not on change
    resolver: zodResolver(catalogItemSchema),
    defaultValues: {
      item_type: 'component',
      measure_basis: 'unit',
      uom: 'unit',
      is_fabric: false,
      image_url: null,
      cost_exw: null,
      default_margin_pct: 35, // Default 35% margin
      msrp: null,
      item_category_id: null,
      // Labor costs
      labor_cost_per_unit: null,
      labor_cost_per_hour: null,
      labor_hours_per_unit: null,
      // Shipping costs
      shipping_cost_base: null,
      shipping_cost_per_kg: null,
      shipping_cost_per_unit: null,
      shipping_cost_percentage: null,
      // Additional costs
      import_tax_pct: null,
      freight_cost: null,
      handling_cost: null,
      unit_price: 0,
      cost_price: 0,
      active: true,
      discontinued: false,
    },
  });

  const isFabric = watch('is_fabric');
  const measureBasis = watch('measure_basis');
  const fabricPricingMode = watch('fabric_pricing_mode');
  const itemType = watch('item_type');
  const costExw = watch('cost_exw');
  const defaultMarginPct = watch('default_margin_pct');
  const itemCategoryId = watch('item_category_id');
  const msrp = watch('msrp');

  // Get category margin if category is selected
  const { marginPercentage: categoryMarginPct, loading: categoryMarginLoading } = useCategoryMargin(itemCategoryId);

  // Read URL parameters to pre-fill form (e.g., from Collections page)
  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const isFabricParam = urlParams.get('is_fabric');
    const collectionNameParam = urlParams.get('collection_name');
    const variantNameParam = urlParams.get('variant_name');
    
    if (isFabricParam === 'true') {
      setValue('is_fabric', true, { shouldValidate: true });
      setValue('item_type', 'fabric', { shouldValidate: true });
      setValue('measure_basis', 'fabric', { shouldValidate: true });
    }
    
    if (collectionNameParam) {
      setValue('collection_name', collectionNameParam, { shouldValidate: false });
    }
    
    if (variantNameParam) {
      setValue('variant_name', variantNameParam, { shouldValidate: false });
    }
  }, [setValue]);

  // Track if MSRP was manually edited to avoid overwriting user input
  const [msrpManuallyEdited, setMsrpManuallyEdited] = useState(false);
  const previousCostExw = useRef<number | null>(null);
  const previousMarginPct = useRef<number | null>(null);
  const lastCalculatedMsrp = useRef<number | null>(null);

  // Auto-calculate MSRP when item-level pricing changes
  // Note: Only uses cost_exw (item cost), not operational costs
  // Priority: Category Margin > Item Default Margin > 35% fallback
  useEffect(() => {
    // Wait for category margin to load
    if (categoryMarginLoading) return;

    // Only calculate if we have cost_exw
    if (costExw !== null && costExw !== undefined && costExw > 0) {
      // Priority: Category Margin > Item Default Margin > 35% fallback
      const marginToUse = categoryMarginPct !== null 
        ? categoryMarginPct 
        : (defaultMarginPct !== null && defaultMarginPct !== undefined ? defaultMarginPct : 35);
      
      // Calculate MSRP: cost_exw * (1 + margin/100)
      // Only use item-level cost, operational costs are handled separately
      const calculatedMsrp = costExw * (1 + marginToUse / 100);
      
      // Check if cost_exw or margin changed (user is actively editing)
      const costChanged = previousCostExw.current !== costExw;
      const marginChanged = previousMarginPct.current !== marginToUse;
      
      // If cost or margin changed, reset the manual edit flag to allow recalculation
      if (costChanged || marginChanged) {
        setMsrpManuallyEdited(false);
      }
      
      // Auto-update MSRP if:
      // 1. MSRP was not manually edited, AND
      // 2. (MSRP is null/empty/zero, OR cost/margin changed, OR MSRP matches last calculation)
      const shouldUpdate = !msrpManuallyEdited && (
        msrp === null || 
        msrp === undefined || 
        msrp === 0 || 
        costChanged ||
        marginChanged ||
        (lastCalculatedMsrp.current !== null && Math.abs(msrp - lastCalculatedMsrp.current) < 0.01)
      );
      
      if (shouldUpdate) {
        const roundedMsrp = Number(calculatedMsrp.toFixed(2));
        setValue('msrp', roundedMsrp, { shouldValidate: false });
        lastCalculatedMsrp.current = roundedMsrp;
      }
      
      // Update refs to track changes
      previousCostExw.current = costExw;
      previousMarginPct.current = marginToUse;
    }
  }, [costExw, defaultMarginPct, categoryMarginPct, categoryMarginLoading, msrp, msrpManuallyEdited, setValue]);

  // Track manual MSRP edits
  const handleMsrpChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newValue = parseFloat(e.target.value) || null;
    setMsrpManuallyEdited(true);
    setValue('msrp', newValue, { shouldValidate: true });
    lastCalculatedMsrp.current = null; // Clear last calculated value when manually edited
  };

  // Auto-update item_type based on is_fabric and measure_basis
  useEffect(() => {
    if (isFabric) {
      setValue('item_type', 'fabric', { shouldValidate: true });
    } else if (measureBasis === 'linear_m') {
      setValue('item_type', 'linear', { shouldValidate: true });
    } else if (measureBasis === 'unit' && itemType === 'fabric') {
      // If user unchecks is_fabric, reset to component
      setValue('item_type', 'component', { shouldValidate: true });
    }
  }, [isFabric, measureBasis, itemType, setValue]);

  // Clear UOM if it becomes invalid when measure_basis changes
  useEffect(() => {
    const currentUom = watch('uom');
    const currentMeasureBasis = watch('measure_basis');
    
    if (currentUom && currentMeasureBasis && !isUomValidForMeasureBasis(currentMeasureBasis, currentUom)) {
      setValue('uom', '', { shouldValidate: true });
    }
  }, [measureBasis, watch, setValue]);

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
          setValue('name', data.name || data.item_name || '');
          setValue('description', data.description || '');
          setValue('item_type', (data as any).item_type || 'component');
          setValue('measure_basis', normalizeMeasureBasis(data.measure_basis) || data.measure_basis || 'unit');
          setValue('uom', normalizeUom(data.uom) || data.uom || 'unit');
          setValue('is_fabric', data.is_fabric || false);
          setValue('collection_name', data.collection_name || null);
          setValue('variant_name', data.variant_name || null);
          setValue('roll_width_m', data.roll_width_m);
          setValue('fabric_pricing_mode', data.fabric_pricing_mode);
          setValue('image_url', data.image_url || (data.metadata && typeof data.metadata === 'object' && data.metadata.image) || null);
          
          // Load attachments from metadata
          if (data.metadata && typeof data.metadata === 'object' && Array.isArray(data.metadata.attachments)) {
            setAttachments(data.metadata.attachments);
          } else {
            setAttachments([]);
          }
          
          // New pricing fields
          setValue('cost_exw', data.cost_exw ?? null);
          setValue('default_margin_pct', data.default_margin_pct ?? 35);
          setValue('msrp', data.msrp ?? null);
          // Labor costs
          setValue('labor_cost_per_unit', data.labor_cost_per_unit ?? null);
          setValue('labor_cost_per_hour', data.labor_cost_per_hour ?? null);
          setValue('labor_hours_per_unit', data.labor_hours_per_unit ?? null);
          // Shipping costs
          setValue('shipping_cost_base', data.shipping_cost_base ?? null);
          setValue('shipping_cost_per_kg', data.shipping_cost_per_kg ?? null);
          setValue('shipping_cost_per_unit', data.shipping_cost_per_unit ?? null);
          setValue('shipping_cost_percentage', data.shipping_cost_percentage ?? null);
          // Additional costs (hidden from UI, kept for database compatibility)
          setValue('import_tax_pct', data.import_tax_pct ?? null);
          setValue('freight_cost', data.freight_cost ?? null);
          setValue('handling_cost', data.handling_cost ?? null);
          // Legacy pricing fields (hidden from UI, kept for database compatibility only)
          setValue('unit_price', data.unit_price || 0);
          setValue('cost_price', data.cost_price || data.cost_exw || 0);
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
        item_name: values.name.trim(), // Map name to item_name for database (name field doesn't exist in CatalogItems)
        description: values.description?.trim() || null,
        item_category_id: values.item_category_id || null,
        item_type: values.item_type,
        measure_basis: normalizeMeasureBasis(values.measure_basis) || values.measure_basis,
        uom: normalizeUom(values.uom) || '',
        is_fabric: values.is_fabric,
        collection_name: values.collection_name?.trim() || null,
        variant_name: values.variant_name?.trim() || null,
        roll_width_m: values.is_fabric && values.roll_width_m ? values.roll_width_m : null,
        fabric_pricing_mode: values.is_fabric ? values.fabric_pricing_mode : null,
        image_url: values.image_url?.trim() || null,
        // Legacy fields (hidden from UI, kept for database compatibility only)
        unit_price: values.unit_price,
        cost_price: values.cost_price ?? values.cost_exw ?? 0, // Map cost_exw to cost_price if not set
        active: values.active,
        discontinued: values.discontinued,
        metadata: {
          attachments: attachments,
        },
      };

      // Only include new pricing fields if they have values (to avoid errors if columns don't exist yet)
      // After running migrations 19 and 21, these fields will be available
      if (values.cost_exw !== null && values.cost_exw !== undefined) {
        itemData.cost_exw = values.cost_exw;
      }
      if (values.default_margin_pct !== null && values.default_margin_pct !== undefined) {
        itemData.default_margin_pct = values.default_margin_pct;
      }
      if (values.msrp !== null && values.msrp !== undefined) {
        itemData.msrp = values.msrp;
      }
      // Labor costs
      if (values.labor_cost_per_unit !== null && values.labor_cost_per_unit !== undefined) {
        itemData.labor_cost_per_unit = values.labor_cost_per_unit;
      }
      if (values.labor_cost_per_hour !== null && values.labor_cost_per_hour !== undefined) {
        itemData.labor_cost_per_hour = values.labor_cost_per_hour;
      }
      if (values.labor_hours_per_unit !== null && values.labor_hours_per_unit !== undefined) {
        itemData.labor_hours_per_unit = values.labor_hours_per_unit;
      }
      // Shipping costs
      if (values.shipping_cost_base !== null && values.shipping_cost_base !== undefined) {
        itemData.shipping_cost_base = values.shipping_cost_base;
      }
      if (values.shipping_cost_per_kg !== null && values.shipping_cost_per_kg !== undefined) {
        itemData.shipping_cost_per_kg = values.shipping_cost_per_kg;
      }
      if (values.shipping_cost_per_unit !== null && values.shipping_cost_per_unit !== undefined) {
        itemData.shipping_cost_per_unit = values.shipping_cost_per_unit;
      }
      if (values.shipping_cost_percentage !== null && values.shipping_cost_percentage !== undefined) {
        itemData.shipping_cost_percentage = values.shipping_cost_percentage;
      }
      // Additional costs
      if (values.import_tax_pct !== null && values.import_tax_pct !== undefined) {
        itemData.import_tax_pct = values.import_tax_pct;
      }
      if (values.freight_cost !== null && values.freight_cost !== undefined) {
        itemData.freight_cost = values.freight_cost;
      }
      if (values.handling_cost !== null && values.handling_cost !== undefined) {
        itemData.handling_cost = values.handling_cost;
      }

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
        const newItem = await createItem(itemData);
        if (newItem && newItem.id) {
          if (import.meta.env.DEV) {
            console.log('✅ Item created, setting itemId:', newItem.id);
          }
          setItemId(newItem.id);
          // Update URL to edit mode so user can continue editing (without full page reload)
          // Use replaceState to avoid triggering a navigation
          if (window.history && window.history.replaceState) {
            window.history.replaceState({}, '', `/catalog/items/edit/${newItem.id}`);
          }
          useUIStore.getState().addNotification({
            type: 'success',
            title: 'Item created',
            message: 'Catalog item has been created successfully.',
          });
          // Item created successfully
          return;
        } else {
          useUIStore.getState().addNotification({
            type: 'success',
            title: 'Item created',
            message: 'Catalog item has been created successfully.',
          });
        }
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
                  <SelectShadcn
                    value={watch('uom') || ''}
                    onValueChange={(value) => {
                      const normalized = normalizeUom(value);
                      if (normalized) {
                        clearErrors('uom');
                      }
                      setValue('uom', normalized || '', { shouldValidate: true });
                    }}
                    disabled={isReadOnly || !watch('measure_basis')}
                  >
                    <SelectTrigger className={`h-auto py-1 text-xs ${errors.uom && !watch('uom') ? 'bg-red-50' : ''}`}>
                      <SelectValue placeholder={watch('measure_basis') ? "Select UOM" : "Select measure basis first"} />
                    </SelectTrigger>
                    <SelectContent>
                      {getValidUomOptions(watch('measure_basis')).map((uomOption) => (
                        <SelectItem key={uomOption} value={uomOption}>
                          {uomOption}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                  {errors.uom && !watch('uom') && (
                    <p className="text-xs text-red-600 mt-1">{errors.uom.message}</p>
                  )}
                  {watch('measure_basis') && !watch('uom') && !errors.uom && (
                    <p className="text-xs text-gray-500 mt-1">
                      Valid options: {getValidUomOptions(watch('measure_basis')).join(', ')}
                    </p>
                  )}
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

              {/* Image Upload */}
              <div className="col-span-12">
                <Label className="text-xs">Image</Label>
                <ImageUpload
                  currentImageUrl={watch('image_url') || null}
                  onImageUploaded={(url) => {
                    setValue('image_url', url || null, { shouldValidate: false });
                  }}
                  disabled={isReadOnly}
                />
              </div>

              {/* Category Selection */}
              <div className="col-span-12 grid grid-cols-12 gap-x-4">
                <div className="col-span-4">
                  <Label htmlFor="item_category_id" className="text-xs">Category</Label>
                  <SelectShadcn
                    value={watch('item_category_id') || '__none__'}
                    onValueChange={(value) => {
                      setValue('item_category_id', value === '__none__' ? null : value, { shouldValidate: true });
                    }}
                    disabled={isReadOnly}
                  >
                    <SelectTrigger className={`h-auto py-1 text-xs ${errors.item_category_id ? 'border-red-300 bg-red-50' : ''}`}>
                      <SelectValue placeholder="Select category (leaf categories only)" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="__none__">None</SelectItem>
                      {leafCategories.map((category) => (
                        <SelectItem key={category.id} value={category.id}>
                          {category.name} {category.code && `(${category.code})`}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                  {errors.item_category_id && (
                    <p className="text-xs text-red-600 mt-1">{errors.item_category_id.message}</p>
                  )}
                  {/* Warning badge if category is a group */}
                  {watch('item_category_id') && (() => {
                    const selectedCategory = allCategories.find(c => c.id === watch('item_category_id'));
                    if (selectedCategory?.is_group) {
                      return (
                        <div className="mt-2 flex items-center gap-2 px-3 py-2 bg-yellow-50 border border-yellow-200 rounded-md">
                          <span className="text-xs text-yellow-800 font-medium">⚠️ Warning:</span>
                          <span className="text-xs text-yellow-700">
                            Category "{selectedCategory.name}" is a group. Please choose a specific subcategory.
                          </span>
                        </div>
                      );
                    }
                    return null;
                  })()}
                </div>
              </div>

              {/* Item Type and Measurement */}
              <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                <div className="col-span-4">
                  <Label htmlFor="item_type" className="text-xs" required>Item Type</Label>
                  <SelectShadcn
                    value={watch('item_type') || 'component'}
                    onValueChange={(value) => {
                      setValue('item_type', value as 'component' | 'fabric' | 'linear' | 'service' | 'accessory', { shouldValidate: true });
                    }}
                    disabled={isReadOnly || isFabric} // Disable if is_fabric is checked (auto-set to fabric)
                  >
                    <SelectTrigger className={`h-auto py-1 text-xs ${errors.item_type ? 'border-red-300 bg-red-50' : ''}`}>
                      <SelectValue placeholder="Select item type" />
                    </SelectTrigger>
                    <SelectContent>
                      {ITEM_TYPE_OPTIONS.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                          {option.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                  {errors.item_type && (
                    <p className="text-xs text-red-600 mt-1">{errors.item_type.message}</p>
                  )}
                </div>

                <div className="col-span-4">
                  <Label htmlFor="measure_basis" className="text-xs" required>Measure Basis</Label>
                  <SelectShadcn
                    value={normalizeMeasureBasis(watch('measure_basis')) || 'unit'}
                    onValueChange={(value) => {
                      const normalized = normalizeMeasureBasis(value) || value.toLowerCase();
                      setValue('measure_basis', normalized as MeasureBasis, { shouldValidate: true });
                      // Clear UOM if it's not valid for the new measure basis
                      const currentUom = watch('uom');
                      if (currentUom && !isUomValidForMeasureBasis(normalized, currentUom)) {
                        setValue('uom', '', { shouldValidate: true });
                      }
                    }}
                    disabled={isReadOnly}
                  >
                    <SelectTrigger className={`h-auto py-1 text-xs ${errors.measure_basis ? 'border-red-300 bg-red-50' : ''}`}>
                      <SelectValue placeholder="Select measure basis">
                        {(() => {
                          const currentValue = normalizeMeasureBasis(watch('measure_basis'));
                          const option = MEASURE_BASIS_OPTIONS_LOCAL.find(opt => opt.value === currentValue);
                          return option ? option.label : currentValue || 'Select measure basis';
                        })()}
                      </SelectValue>
                    </SelectTrigger>
                    <SelectContent>
                      {MEASURE_BASIS_OPTIONS_LOCAL.map((option) => (
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
                      <Label htmlFor="collection_name" className="text-xs">Collection Name</Label>
                      <Input 
                        id="collection_name" 
                        {...register('collection_name')}
                        className="py-1 text-xs"
                        error={errors.collection_name?.message}
                        disabled={isReadOnly}
                        placeholder="Enter collection name"
                      />
                    </div>
                    <div className="col-span-4">
                      <Label htmlFor="variant_name" className="text-xs">Variant Name</Label>
                      <Input 
                        id="variant_name" 
                        {...register('variant_name')}
                        className="py-1 text-xs"
                        error={errors.variant_name?.message}
                        disabled={isReadOnly}
                        placeholder="Enter variant/color name"
                      />
                    </div>
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
                        <SelectTrigger className={`h-auto py-1 text-xs ${errors.fabric_pricing_mode ? 'border-red-300 bg-red-50' : ''}`}>
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
              {/* Pricing Section (Item Level) */}
              <div className="col-span-12">
                <h3 className="text-sm font-semibold text-gray-900 mb-4 flex items-center gap-2">
                  <span className="text-lg">$</span>
                  Pricing (Item Level)
                </h3>
                <p className="text-xs text-gray-500 mb-4">
                  Product definition pricing. Operational and project costs are managed separately.
                </p>
              </div>
              
              <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
                <div className="col-span-4">
                  <Label htmlFor="cost_exw" className="text-xs" required>Item Cost EXW</Label>
                  <Input 
                    id="cost_exw" 
                    type="number"
                    step="0.01"
                    {...register('cost_exw', { valueAsNumber: true })}
                    className="py-1 text-xs"
                    error={errors.cost_exw?.message}
                    disabled={isReadOnly}
                    placeholder="0.00"
                  />
                  <p className="text-xs text-gray-500 mt-1">Base cost (Ex Works)</p>
                </div>
                <div className="col-span-4">
                  <Label htmlFor="msrp" className="text-xs">Item Sale Price (MSRP)</Label>
                  <Input 
                    id="msrp" 
                    type="number"
                    step="0.01"
                    {...register('msrp', { valueAsNumber: true })}
                    onChange={(e) => {
                      register('msrp').onChange(e);
                      handleMsrpChange(e);
                    }}
                    className="py-1 text-xs"
                    error={errors.msrp?.message}
                    disabled={isReadOnly}
                    placeholder="0.00"
                  />
                  <p className="text-xs text-gray-500 mt-1">
                    Manufacturer's Suggested Retail Price (auto-calculated from cost + margin)
                    {categoryMarginPct !== null && (
                      <span className="block text-blue-600 font-medium mt-1">
                        Using category margin: {categoryMarginPct.toFixed(2)}%
                      </span>
                    )}
                    {categoryMarginPct === null && defaultMarginPct !== null && defaultMarginPct !== undefined && (
                      <span className="block text-gray-600 mt-1">
                        Using item margin: {defaultMarginPct.toFixed(2)}%
                      </span>
                    )}
                  </p>
                </div>
                <div className="col-span-4">
                  <Label htmlFor="default_margin_pct" className="text-xs">
                    Default Margin % 
                    {categoryMarginPct !== null && (
                      <span className="text-blue-600 text-xs ml-2">(Category margin overrides this)</span>
                    )}
                  </Label>
                  <Input 
                    id="default_margin_pct" 
                    type="number"
                    step="0.01"
                    min="0"
                    max="100"
                    {...register('default_margin_pct', { valueAsNumber: true })}
                    className="py-1 text-xs"
                    error={errors.default_margin_pct?.message}
                    disabled={isReadOnly}
                    placeholder="35.00"
                  />
                  <p className="text-xs text-gray-500 mt-1">
                    {categoryMarginPct !== null 
                      ? 'Category margin is being used instead' 
                      : 'Suggestion only (optional, used if no category margin)'}
                  </p>
                </div>
              </div>

              {/* Status fields */}
              <div className="col-span-12 mt-6 pt-4 border-t border-gray-200">
                <div className="grid grid-cols-12 gap-x-4 gap-y-3">
                  <div className="col-span-4">
                    <div className="flex items-center gap-2">
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
                    <div className="flex items-center gap-2">
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
            </div>
          )}

          {activeTab === 'attachments' && (
            <div className="grid grid-cols-12 gap-x-4 gap-y-4">
              <div className="col-span-12">
                <FileUpload
                  currentFiles={attachments}
                  onFilesChanged={(files) => setAttachments(files)}
                  disabled={isReadOnly || isSaving}
                  acceptedTypes={['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'image/*']}
                  maxFileSize={10 * 1024 * 1024} // 10MB
                  maxFiles={10}
                />
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}


