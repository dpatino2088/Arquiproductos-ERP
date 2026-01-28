import React, { useState, useEffect, useMemo, useRef } from 'react';
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
import { useCreateCatalogItem, useUpdateCatalogItem, useCatalogCategories } from '../../hooks/useCatalog';
import { useCategoryMargins } from '../../hooks/useCostEngineSettings';
import { supabase } from '../../lib/supabase/client';
import ImageUpload from '../../components/ui/ImageUpload';
import { syncCatalogItemProductTypes } from '../../lib/catalog-item-helpers';
import { useProductTypes } from '../../hooks/useProductTypes';
import { useOnVisibilityChange } from '../../lib/app-persistence';

/**
 * ============================================================================
 * CATALOG ITEM FORM - REBUILT FROM SCRATCH
 * Based on DB dump: backups/2026-01-14_full.sql
 * ============================================================================
 * 
 * CatalogItems columns (REAL):
 * - id, organization_id, name, sku, unit_of_measure, description, category_id
 * - image_url, measure_basis, is_fabric, collection_name, variant_name
 * - roll_width, fabric_pricing_mode, color, is_active
 * - cost_exw, is_roll, roll_type
 * - created_at, updated_at
 * 
 * Note: manufacturer, manufacturer_id exist in DB but NOT used in this form (legacy)
 * 
 * Constraints:
 * - catalogitems_roll_type_requires_is_roll: if roll_type NOT NULL then is_roll must be true
 * - measure_basis: 'unit' | 'linear' | 'area'
 * - roll_type enum: 'fabric' | 'window_film' | 'vinyl' | 'mesh' | 'paper' | 'other'
 *
 * Terminology: always "Roll" for roll-of-material (fabric, film, vinyl). Never "Rail"
 * (rail = hardware: bottom_rail, top_rail, etc. in BOM/curtains).
 */

// Zod Schema - ONLY fields that exist in CatalogItems table
const catalogItemSchema = z.object({
  // Required fields
  sku: z.string().min(1, 'SKU is required'),
  name: z.string().min(1, 'Name is required'),
  unit_of_measure: z.string().min(1, 'Unit of measure is required'),
  measure_basis: z.enum(['unit', 'linear', 'area']),
  
  // Optional fields
  description: z.string().optional().nullable(),
  category_id: z.string().uuid().optional().nullable(),
  image_url: z.string().url().optional().nullable().or(z.literal('')),
  
  // Roll/Fabric fields
  is_fabric: z.boolean(),
  is_roll: z.boolean(),
  roll_type: z.enum(['fabric', 'window_film', 'vinyl', 'mesh', 'paper', 'other']).optional().nullable(),
  collection_name: z.string().optional().nullable(),
  variant_name: z.string().optional().nullable(),
  roll_width: z.number().optional().nullable(),
  fabric_pricing_mode: z.enum(['per_linear_m', 'per_sqm']).optional().nullable(),
  
  // Component fields
  color: z.string().optional().nullable(),
  
  // Pricing
  cost_exw: z.number().min(0).optional().nullable(),
  
  // Status
  is_active: z.boolean(),
}).refine((data) => {
  // If is_roll=true, collection_name and variant_name are required
  if (data.is_roll && !data.collection_name) return false;
  return true;
}, {
  message: 'Collection name is required for roll items',
  path: ['collection_name'],
}).refine((data) => {
  if (data.is_roll && !data.variant_name) return false;
  return true;
}, {
  message: 'Variant name (color) is required for roll items',
  path: ['variant_name'],
}).refine((data) => {
  // If is_roll=true, roll_type is required
  if (data.is_roll && !data.roll_type) return false;
  return true;
}, {
  message: 'Roll type is required for roll items',
  path: ['roll_type'],
});

type CatalogItemFormValues = z.infer<typeof catalogItemSchema>;

export default function CatalogItemNew() {
  const { activeOrganizationId } = useOrganizationContext();
  const { canEditCustomers: canEdit, loading: roleLoading } = useCurrentOrgRole();
  
  // Track current path so itemId stays in sync with navigation
  const [currentPath, setCurrentPath] = useState<string>(window.location.pathname);
  useEffect(() => {
    const syncPath = () => setCurrentPath(window.location.pathname);
    syncPath();
    const unsubscribe = router.addListener(syncPath);
    window.addEventListener('popstate', syncPath);
    return () => {
      unsubscribe();
      window.removeEventListener('popstate', syncPath);
    };
  }, []);

  const itemId = useMemo(() => {
    const match = currentPath.match(/\/catalog\/items\/edit\/([^/]+)/);
    return match && match[1] ? match[1] : null;
  }, [currentPath]);
  
  // Hooks
  const { createItem, isCreating } = useCreateCatalogItem();
  const { updateItem, isUpdating } = useUpdateCatalogItem();
  const { leafCategories: catalogCategories, loading: catalogCategoriesLoading } = useCatalogCategories();
  const { productTypes, loading: productTypesLoading } = useProductTypes();
  const { margins: categoryMargins, loading: categoryMarginsLoading } = useCategoryMargins();
  
  // ProductTypes selection state
  const [selectedProductTypeIds, setSelectedProductTypeIds] = useState<string[]>([]);
  
  // Note: Pricing percentages are now managed by CategoryMargins (by category), not per-item
  // CatalogItemsMSRP is a cache of calculated results only
  
  // Form state
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'profile' | 'rates'>('profile');
  
  // CatalogItemsMSRP: read-only for Rates tab (computed in backend; UI only displays)
  const [msrpRow, setMsrpRow] = useState<{
    msrp_sale_in: number;
    msrp_sale_out: number;
    total_cost: number;
    shipping_cost: number;
    import_tax_cost: number;
    minimum_margin_pct: number;   // col. CatalogItemsMSRP — % sale-in (equiv. msrp_pct_sale_in)
    msrp_pct_sale_out: number;    // col. CatalogItemsMSRP
  } | null>(null);
  const [msrpLoading, setMsrpLoading] = useState(false);
  
  const isReadOnly = !canEdit && !roleLoading;
  
  // React Hook Form
  const {
    register,
    handleSubmit,
    formState: { errors },
    setValue,
    watch,
    reset,
  } = useForm<CatalogItemFormValues>({
    resolver: zodResolver(catalogItemSchema),
    defaultValues: {
      sku: '',
      name: '',
      description: '',
      unit_of_measure: 'ea',
      measure_basis: 'unit',
      category_id: null,
      image_url: null,
      is_fabric: false,
      is_roll: false,
      roll_type: null,
      collection_name: null,
      variant_name: null,
      roll_width: null,
      fabric_pricing_mode: null,
      color: null,
      cost_exw: null,
      is_active: true,
    },
  });

  // Draft persistence (keeps unsaved changes on reload)
  const draftKey = itemId ? `catalogItemDraft:${itemId}` : 'catalogItemDraft:new';
  const draftTimerRef = useRef<number | null>(null);
  
  // ✅ FIX: SessionStorage persistence for editing (survives tab changes)
  const sessionKey = itemId ? `catalogItemEdit:${itemId}` : null;
  const sessionTimerRef = useRef<number | null>(null);
  const draftHydratedRef = useRef(false); // Prevent saving empty draft before hydration

  useEffect(() => {
    // ✅ Only apply draft on NEW items (not when editing)
    if (itemId) return;

    const raw = window.localStorage.getItem(draftKey);
    if (!raw) {
      // If new item and no draft, reset to defaults
      reset({
        sku: '',
        name: '',
        description: '',
        unit_of_measure: 'ea',
        measure_basis: 'unit',
        category_id: null,
        image_url: null,
        is_fabric: false,
        is_roll: false,
        roll_type: null,
        collection_name: null,
        variant_name: null,
        roll_width: null,
        fabric_pricing_mode: null,
        color: null,
        cost_exw: null,
        is_active: true,
      });
      setSelectedProductTypeIds([]);
      return;
    }

    try {
      const parsed = JSON.parse(raw);
      if (parsed?.values) {
        reset({ ...parsed.values });
      }
      if (Array.isArray(parsed?.productTypeIds)) {
        setSelectedProductTypeIds(parsed.productTypeIds);
      }
    } catch {
      // Ignore corrupted draft
    }
  }, [draftKey, itemId, reset]);

  useEffect(() => {
    // ✅ Only persist drafts for NEW items (avoid overriding edits)
    if (itemId) return;

    const subscription = watch((values) => {
      if (draftTimerRef.current) {
        window.clearTimeout(draftTimerRef.current);
      }
      draftTimerRef.current = window.setTimeout(() => {
        const payload = {
          values,
          productTypeIds: selectedProductTypeIds,
          savedAt: new Date().toISOString(),
        };
        window.localStorage.setItem(draftKey, JSON.stringify(payload));
      }, 300);
    });

    return () => {
      subscription.unsubscribe();
      if (draftTimerRef.current) {
        window.clearTimeout(draftTimerRef.current);
      }
    };
  }, [watch, draftKey, selectedProductTypeIds, itemId]);
  
  // Watch values
  const isRoll = watch('is_roll');
  const rollType = watch('roll_type');
  const measureBasis = watch('measure_basis');
  const categoryId = watch('category_id');
  
  // Load item data when editing
  useEffect(() => {
    if (!itemId || !activeOrganizationId) return;
    
    async function loadItem() {
      try {
        const { data, error } = await supabase
          .from('CatalogItems')
          .select('*')
          .eq('id', itemId)
          .eq('organization_id', activeOrganizationId)
          .maybeSingle();
        
        if (error) throw error;
        if (!data) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Item not found',
            message: 'The item you are trying to edit was not found.',
          });
          router.navigate('/catalog/items');
          return;
        }
        
        // ✅ FIX: Check sessionStorage first (user may have unsaved changes from tab switch)
        const sessionData = sessionKey ? window.sessionStorage.getItem(sessionKey) : null;
        let formValues: CatalogItemFormValues;
        
        if (sessionData) {
          try {
            const parsed = JSON.parse(sessionData);
            if (parsed?.values) {
              formValues = parsed.values;
              if (Array.isArray(parsed?.productTypeIds)) {
                setSelectedProductTypeIds(parsed.productTypeIds);
              }
              draftHydratedRef.current = true;
              if (import.meta.env.DEV) {
                console.log('✅ Restored form state from sessionStorage');
              }
            } else {
              throw new Error('Invalid session data');
            }
          } catch (err) {
            // Invalid session data, use database values
            if (import.meta.env.DEV) {
              console.warn('⚠️ Invalid sessionStorage data, using database values');
            }
            formValues = {
              sku: data.sku || '',
              name: data.name || '',
              description: data.description || '',
              unit_of_measure: data.unit_of_measure || 'ea',
              measure_basis: data.measure_basis || 'unit',
              category_id: data.category_id || null,
              image_url: data.image_url || null,
              is_fabric: data.is_fabric || false,
              is_roll: data.is_roll || false,
              roll_type: data.roll_type || null,
              collection_name: data.collection_name || null,
              variant_name: data.variant_name || null,
              roll_width: data.roll_width ? Number(data.roll_width) : null,
            fabric_pricing_mode: data.fabric_pricing_mode || null,
            color: data.color || null,
            cost_exw: data.cost_exw ? Number(data.cost_exw) : null,
            is_active: data.is_active !== undefined ? data.is_active : true,
            };
          }
        } else {
          // No session data, use database values
          formValues = {
            sku: data.sku || '',
            name: data.name || '',
            description: data.description || '',
            unit_of_measure: data.unit_of_measure || 'ea',
            measure_basis: data.measure_basis || 'unit',
            category_id: data.category_id || null,
            image_url: data.image_url || null,
            is_fabric: data.is_fabric || false,
            is_roll: data.is_roll || false,
            roll_type: data.roll_type || null,
            collection_name: data.collection_name || null,
            variant_name: data.variant_name || null,
            roll_width: data.roll_width ? Number(data.roll_width) : null,
            fabric_pricing_mode: data.fabric_pricing_mode || null,
            color: data.color || null,
            cost_exw: data.cost_exw ? Number(data.cost_exw) : null,
            is_active: data.is_active !== undefined ? data.is_active : true,
          };
        }
        
        // Set form values (single reset for reliability)
        reset(formValues);
        draftHydratedRef.current = true;
        
        // Note: MSRP percentages are now managed by CategoryMargins (by category)
        // CatalogItemsMSRP is auto-calculated by triggers, no need to load overrides
        
      } catch (err: any) {
        console.error('❌ Error loading item:', err);
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: err.message || 'Failed to load item',
        });
      }
    }
    
    loadItem();
  }, [itemId, activeOrganizationId, setValue, draftKey, sessionKey, reset]);
  
  // ✅ FIX: Persist form state to sessionStorage when editing (survives tab changes)
  useEffect(() => {
    if (!itemId || !sessionKey || !draftHydratedRef.current) return;
    
    const subscription = watch((values) => {
      if (sessionTimerRef.current) {
        window.clearTimeout(sessionTimerRef.current);
      }
      sessionTimerRef.current = window.setTimeout(() => {
        const payload = {
          values,
          productTypeIds: selectedProductTypeIds,
          savedAt: new Date().toISOString(),
        };
        window.sessionStorage.setItem(sessionKey, JSON.stringify(payload));
        if (import.meta.env.DEV) {
          console.log('💾 Saved form state to sessionStorage');
        }
      }, 300);
    });
    
    return () => {
      subscription.unsubscribe();
      if (sessionTimerRef.current) {
        window.clearTimeout(sessionTimerRef.current);
      }
    };
  }, [watch, sessionKey, selectedProductTypeIds, itemId]);
  
  // ✅ FIX: Restore state when tab becomes visible again
  useOnVisibilityChange(() => {
    if (!itemId || !sessionKey || !draftHydratedRef.current) return;
    
    const sessionData = window.sessionStorage.getItem(sessionKey);
    if (sessionData) {
      try {
        const parsed = JSON.parse(sessionData);
        if (parsed?.values) {
          reset(parsed.values);
          if (Array.isArray(parsed?.productTypeIds)) {
            setSelectedProductTypeIds(parsed.productTypeIds);
          }
          if (import.meta.env.DEV) {
            console.log('✅ Restored form state from sessionStorage (tab visible)');
          }
        }
      } catch (err) {
        if (import.meta.env.DEV) {
          console.warn('⚠️ Error restoring sessionStorage:', err);
        }
      }
    }
  });
  
  // Load ProductTypes relations when editing
  useEffect(() => {
    if (!itemId || !activeOrganizationId) return;
    
    async function loadProductTypeRelations() {
      try {
        const { data, error } = await supabase
          .from('CatalogItemProductTypes')
          .select('product_type_id')
          .eq('catalog_item_id', itemId)
          .eq('organization_id', activeOrganizationId);
        
        if (!error && data) {
          const ids = data.map((rel: any) => rel.product_type_id);
          setSelectedProductTypeIds(ids);
        }
      } catch (err) {
        console.warn('⚠️ Could not load ProductTypes relations (non-blocking)');
      }
    }
    
    loadProductTypeRelations();
  }, [itemId, activeOrganizationId]);

  // Load CatalogItemsMSRP for Rates tab (catalog_item_id). Backend computes; UI only reads and displays.
  useEffect(() => {
    if (!itemId || !activeOrganizationId) {
      setMsrpRow(null);
      return;
    }
    
    let isMounted = true;
    setMsrpLoading(true);
    setMsrpRow(null);
    
    (async () => {
      try {
        const { data, error } = await supabase
          .from('CatalogItemsMSRP')
          .select('msrp_sale_in, msrp_sale_out, total_cost, shipping_cost, import_tax_cost, minimum_margin_pct, msrp_pct_sale_out')
          .eq('catalog_item_id', itemId)
          .eq('organization_id', activeOrganizationId)
          .maybeSingle();
        
        if (error) throw error;
        if (isMounted && data) {
          setMsrpRow({
            msrp_sale_in: Number(data.msrp_sale_in ?? 0),
            msrp_sale_out: Number(data.msrp_sale_out ?? 0),
            total_cost: Number(data.total_cost ?? 0),
            shipping_cost: Number(data.shipping_cost ?? 0),
            import_tax_cost: Number(data.import_tax_cost ?? 0),
            minimum_margin_pct: Number(data.minimum_margin_pct ?? 0),
            msrp_pct_sale_out: Number(data.msrp_pct_sale_out ?? 0),
          });
        }
      } catch (err) {
        if (import.meta.env.DEV) console.warn('⚠️ Could not load CatalogItemsMSRP:', err);
        if (isMounted) setMsrpRow(null);
      } finally {
        if (isMounted) setMsrpLoading(false);
      }
    })();
    
    return () => { isMounted = false; };
  }, [itemId, activeOrganizationId]);
  
  // Auto-update is_fabric when is_roll changes (is_fabric mirrors is_roll for compatibility)
  useEffect(() => {
    setValue('is_fabric', watch('is_roll'));
  }, [watch('is_roll'), setValue]);
  
  // Handle form submission
  const onSubmit = async (values: CatalogItemFormValues) => {
    if (!activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'No organization selected',
      });
      return;
    }
    
    setIsSaving(true);
    setSaveError(null);
    
    try {
      // Prepare payload - ONLY fields that exist in CatalogItems
      const payload: any = {
        sku: values.sku.trim(),
        name: values.name.trim(),
        description: values.description?.trim() || null,
        unit_of_measure: values.unit_of_measure,
        measure_basis: values.measure_basis,
        category_id: values.category_id || null,
        image_url: values.image_url?.trim() || null,
        is_fabric: values.is_fabric,
        is_roll: values.is_roll,
        roll_type: values.is_roll ? values.roll_type : null,
        collection_name: values.is_roll ? (values.collection_name?.trim() || null) : null,
        variant_name: values.is_roll ? (values.variant_name?.trim() || null) : null,
        roll_width: values.is_roll && values.roll_width ? Number(values.roll_width) : null,
        fabric_pricing_mode: values.is_roll && values.roll_type === 'fabric' ? values.fabric_pricing_mode : null,
        color: !values.is_roll ? (values.color?.trim() || null) : null,
        cost_exw: values.cost_exw != null ? Number(values.cost_exw) : null,
        is_active: values.is_active,
      };
      
      console.log('📦 Saving CatalogItem with payload:', payload);
      
      // Defensive: derive itemId from URL if state is out of sync
      const routeMatch = window.location.pathname.match(/\/catalog\/items\/edit\/([^/]+)/);
      const routeItemId = routeMatch && routeMatch[1] ? routeMatch[1] : null;
      const effectiveItemId = itemId || routeItemId;

      let finalItemId = effectiveItemId;
      
      if (effectiveItemId) {
        // Update
        await updateItem(effectiveItemId, payload);
        finalItemId = effectiveItemId;
      } else {
        // Create
        const newItem = await createItem(payload);
        if (newItem?.id) {
          finalItemId = newItem.id;
        } else {
          throw new Error('Failed to create item');
        }
      }
      
      // Note: MSRP is calculated by triggers based on CategoryMargins (by category)
      // Trigger on CatalogItems automatically calls recompute_catalog_item_msrp() when cost_exw or category_id change
      // No need to save overrides to CatalogItemsMSRP - percentages come from CategoryMargins
      
      // Sync ProductTypes (non-blocking)
      try {
        if (selectedProductTypeIds.length > 0 && finalItemId) {
          await syncCatalogItemProductTypes(
            finalItemId,
            selectedProductTypeIds,
            null, // no primary concept in simple table
            activeOrganizationId
          );
          console.log('✅ ProductTypes synced');
        }
      } catch (ptErr) {
        console.warn('⚠️ ProductTypes sync failed (non-blocking):', ptErr);
      }
      
      // ✅ FIX: Clear sessionStorage after successful save
      if (sessionKey) {
        window.sessionStorage.removeItem(sessionKey);
        if (import.meta.env.DEV) {
          console.log('🧹 Cleared sessionStorage after successful save');
        }
      }
      
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: itemId ? 'Item updated successfully' : 'Item created successfully',
      });
      
      if (!itemId && finalItemId) {
        // Navigate to edit mode for new items
        router.navigate(`/catalog/items/edit/${finalItemId}`);
        return;
      }
      
      router.navigate('/catalog/items');
      
    } catch (err: any) {
      console.error('❌ Error saving item:', err);
      const errorMsg = (() => {
        if (err?.code === '23505' || String(err?.message || '').includes('CatalogItems_organization_id_sku_key')) {
          return 'SKU already exists in this organization. Please use a unique SKU.';
        }
        return err?.message || 'Failed to save item';
      })();
      setSaveError(errorMsg);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: errorMsg,
      });
    } finally {
      setIsSaving(false);
    }
  };
  
  // UOM options by measure basis. For Roll items with linear measure, include 'roll'.
  // Terminology: always "Roll" for roll-of-material (fabric, film, vinyl). Never "Rail" (hardware).
  const getUomOptions = (): string[] => {
    switch (measureBasis) {
      case 'unit':
        return ['ea', 'pcs', 'set', 'pair'];
      case 'linear':
        return isRoll ? ['m', 'yd', 'ft', 'roll'] : ['m', 'yd', 'ft'];
      case 'area':
        return ['m2', 'yd2', 'ft2'];
      default:
        return ['ea'];
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
          <p className="text-xs text-gray-500">
            {itemId ? 'Edit catalog item' : 'Create a new catalog item'}
          </p>
        </div>
        
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => router.navigate('/catalog/items')}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 text-sm hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={handleSubmit(onSubmit)}
            disabled={isSaving || isReadOnly}
            className="px-3 py-1.5 rounded bg-primary text-white text-sm hover:bg-primary/90 disabled:opacity-50"
          >
            {isSaving ? 'Saving...' : 'Save'}
          </button>
        </div>
      </div>
      
      {saveError && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {saveError}
        </div>
      )}
      
      {/* Tabs */}
      <div className="mb-6 border-b border-gray-200">
        <nav className="flex gap-6">
          <button
            onClick={() => setActiveTab('profile')}
            className={`pb-3 text-sm font-medium border-b-2 transition-colors ${
              activeTab === 'profile'
                ? 'border-[var(--tab-active-underline)] text-[var(--tab-active-underline)]'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Profile
          </button>
          <button
            onClick={() => setActiveTab('rates')}
            className={`pb-3 text-sm font-medium border-b-2 transition-colors ${
              activeTab === 'rates'
                ? 'border-[var(--tab-active-underline)] text-[var(--tab-active-underline)]'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Rates
          </button>
        </nav>
      </div>
      
      {/* Profile Tab */}
      {activeTab === 'profile' && (
        <div className="grid grid-cols-12 gap-4">
          {/* SKU, Name */}
          <div className="col-span-4">
            <Label htmlFor="sku" className="text-xs" required>SKU</Label>
            <Input
              id="sku"
              {...register('sku')}
              className="py-1 text-xs"
              error={errors.sku?.message}
              disabled={isReadOnly}
            />
          </div>
          
          <div className="col-span-8">
            <Label htmlFor="name" className="text-xs" required>Name</Label>
            <Input
              id="name"
              {...register('name')}
              className="py-1 text-xs"
              error={errors.name?.message}
              disabled={isReadOnly}
            />
          </div>
          
          {/* Description */}
          <div className="col-span-12">
            <Label htmlFor="description" className="text-xs">Description</Label>
            <textarea
              id="description"
              {...register('description')}
              className="w-full border border-gray-300 rounded px-3 py-1.5 text-xs"
              rows={3}
              disabled={isReadOnly}
            />
          </div>
          
          {/* Category */}
          <div className="col-span-6">
            <Label htmlFor="category_id" className="text-xs">Category</Label>
            <SelectShadcn
              value={watch('category_id') || '__none__'}
              onValueChange={(value) => setValue('category_id', value === '__none__' ? null : value)}
              disabled={isReadOnly || catalogCategoriesLoading}
            >
              <SelectTrigger className="h-auto py-1 text-xs">
                <SelectValue placeholder="Select category" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="__none__">None</SelectItem>
                {catalogCategories.map((cat) => (
                  <SelectItem key={cat.id} value={cat.id}>
                    {cat.path}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
          </div>
          
          {/* Product Types */}
          <div className="col-span-12">
            <Label className="text-xs">Product Types</Label>
            {productTypesLoading ? (
              <p className="text-xs text-gray-500 mt-2">Loading...</p>
            ) : productTypes.length === 0 ? (
              <p className="text-xs text-gray-500 mt-2">No product types available</p>
            ) : (
              <div className="mt-2 border border-gray-200 rounded p-3">
                <div className="grid grid-cols-3 gap-2">
                  {productTypes.map((pt) => (
                    <label key={pt.id} className="flex items-center gap-2 text-xs">
                      <input
                        type="checkbox"
                        checked={selectedProductTypeIds.includes(pt.id)}
                        onChange={(e) => {
                          if (e.target.checked) {
                            setSelectedProductTypeIds([...selectedProductTypeIds, pt.id]);
                          } else {
                            setSelectedProductTypeIds(selectedProductTypeIds.filter(id => id !== pt.id));
                          }
                        }}
                        disabled={isReadOnly}
                        className="h-4 w-4"
                      />
                      <span>{pt.name} {pt.code && `(${pt.code})`}</span>
                    </label>
                  ))}
                </div>
              </div>
            )}
          </div>
          
          {/* Measure Basis & UOM */}
          <div className="col-span-4">
            <Label htmlFor="measure_basis" className="text-xs" required>Measure Basis</Label>
            <SelectShadcn
              value={watch('measure_basis')}
              onValueChange={(value) => setValue('measure_basis', value as 'unit' | 'linear' | 'area')}
              disabled={isReadOnly}
            >
              <SelectTrigger className="h-auto py-1 text-xs">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="unit">Unit (each)</SelectItem>
                <SelectItem value="linear">Linear (length)</SelectItem>
                <SelectItem value="area">Area (m²)</SelectItem>
              </SelectContent>
            </SelectShadcn>
          </div>
          
          <div className="col-span-4">
            <Label htmlFor="unit_of_measure" className="text-xs" required>Unit of Measure</Label>
            <SelectShadcn
              value={watch('unit_of_measure')}
              onValueChange={(value) => setValue('unit_of_measure', value)}
              disabled={isReadOnly}
            >
              <SelectTrigger className="h-auto py-1 text-xs">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {getUomOptions().map((uom) => (
                  <SelectItem key={uom} value={uom}>{uom === 'roll' ? 'Roll' : uom}</SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
          </div>
          
          {/* Roll Item & Active Status — Always "Roll" (never "Rail"). Roll = material en rollo. */}
          <div className="col-span-6">
            <label className="flex items-center gap-2">
              <input
                type="checkbox"
                {...register('is_roll')}
                onChange={(e) => {
                  const next = e.target.checked;
                  setValue('is_roll', next);
                  if (next) {
                    setValue('measure_basis', 'linear');
                    setValue('unit_of_measure', 'm');
                  } else {
                    setValue('measure_basis', 'unit');
                    setValue('unit_of_measure', 'ea');
                  }
                }}
                className="h-4 w-4"
                disabled={isReadOnly}
              />
              <span className="text-xs font-medium">Roll Item (fabric, film, vinyl, etc.)</span>
            </label>
            <p className="text-xs text-gray-500 mt-1 ml-6">Roll = material en rollo. Se mide por largo (m, yd, ft) o por rollo.</p>
          </div>
          
          <div className="col-span-6">
            <label className="flex items-center gap-2">
              <input
                type="checkbox"
                {...register('is_active')}
                className="h-4 w-4"
                disabled={isReadOnly}
              />
              <span className="text-xs font-medium">Active</span>
            </label>
            <p className="text-xs text-gray-500 mt-1 ml-6">Uncheck to disable this item</p>
          </div>
          
          {/* Roll Fields (when is_roll=true) */}
          {isRoll && (
            <>
              <div className="col-span-4">
                <Label htmlFor="roll_type" className="text-xs" required>Roll Type</Label>
                <SelectShadcn
                  value={watch('roll_type') || ''}
                  onValueChange={(value) => setValue('roll_type', value as any)}
                  disabled={isReadOnly}
                >
                  <SelectTrigger className="h-auto py-1 text-xs">
                    <SelectValue placeholder="Select type" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="fabric">Fabric</SelectItem>
                    <SelectItem value="window_film">Window Film</SelectItem>
                    <SelectItem value="vinyl">Vinyl</SelectItem>
                    <SelectItem value="mesh">Mesh</SelectItem>
                    <SelectItem value="paper">Paper</SelectItem>
                    <SelectItem value="other">Other</SelectItem>
                  </SelectContent>
                </SelectShadcn>
                {errors.roll_type && <p className="text-xs text-red-600 mt-1">{errors.roll_type.message}</p>}
              </div>
              
              <div className="col-span-4">
                <Label htmlFor="collection_name" className="text-xs" required>Collection Name</Label>
                <Input
                  id="collection_name"
                  {...register('collection_name')}
                  className="py-1 text-xs"
                  error={errors.collection_name?.message}
                  disabled={isReadOnly}
                />
              </div>
              
              <div className="col-span-4">
                <Label htmlFor="variant_name" className="text-xs" required>Variant Name (Color)</Label>
                <Input
                  id="variant_name"
                  {...register('variant_name')}
                  className="py-1 text-xs"
                  error={errors.variant_name?.message}
                  disabled={isReadOnly}
                />
              </div>
              
              <div className="col-span-4">
                <Label htmlFor="roll_width" className="text-xs">Roll Width (m)</Label>
                <Input
                  id="roll_width"
                  type="number"
                  step="0.01"
                  {...register('roll_width', { valueAsNumber: true })}
                  className="py-1 text-xs"
                  disabled={isReadOnly}
                />
              </div>
              
              {rollType === 'fabric' && (
                <div className="col-span-4">
                  <Label htmlFor="fabric_pricing_mode" className="text-xs">Fabric Pricing Mode</Label>
                  <SelectShadcn
                    value={watch('fabric_pricing_mode') || ''}
                    onValueChange={(value) => setValue('fabric_pricing_mode', value as any)}
                    disabled={isReadOnly}
                  >
                    <SelectTrigger className="h-auto py-1 text-xs">
                      <SelectValue placeholder="Select mode" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="per_linear_m">Per Linear Meter</SelectItem>
                      <SelectItem value="per_sqm">Per Square Meter</SelectItem>
                    </SelectContent>
                  </SelectShadcn>
                </div>
              )}
            </>
          )}
          
          {/* Color (when is_roll=false) */}
          {!isRoll && (
            <div className="col-span-4">
              <Label htmlFor="color" className="text-xs">Color</Label>
              <Input
                id="color"
                {...register('color')}
                className="py-1 text-xs"
                disabled={isReadOnly}
              />
            </div>
          )}
          
          {/* Image */}
          <div className="col-span-12">
            <Label className="text-xs">Image</Label>
            <ImageUpload
              currentImageUrl={watch('image_url') || null}
              onImageUploaded={(url) => setValue('image_url', url ?? null)}
              disabled={isReadOnly}
            />
          </div>
        </div>
      )}
      
      {/* Rates Tab */}
      {activeTab === 'rates' && (
        <div className="grid grid-cols-12 gap-4">
          {/* Base Cost */}
          <div className="col-span-12">
            <h3 className="text-sm font-semibold mb-3">Base Cost</h3>
          </div>
          
          <div className="col-span-3">
            <Label htmlFor="cost_exw" className="text-xs">Cost EXW</Label>
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
            <p className="text-xs text-gray-500 mt-1">Ex Works base cost. MSRP is computed in the backend (triggers + msrp_compute_for_item).</p>
          </div>
          
          {/* MSRP: read-only from CatalogItemsMSRP. No client-side calculation. */}
          <div className="col-span-12 mt-6">
            <h3 className="text-sm font-semibold mb-3">MSRP (from CatalogItemsMSRP)</h3>
            {!itemId ? (
              <p className="text-xs text-gray-500 bg-amber-50 border border-amber-200 rounded p-3">
                Save the item first to see MSRP. Values are computed in the backend when cost and category are set.
              </p>
            ) : msrpLoading ? (
              <p className="text-xs text-gray-500">Loading MSRP…</p>
            ) : msrpRow ? (
              <div className="space-y-3">
                {/* Porcentajes afuera del bar */}
                <div className="grid grid-cols-2 gap-4 text-xs max-w-xs">
                  <div>
                    <p className="font-medium text-gray-700">Minimum Margin</p>
                    <p className="text-lg font-semibold text-purple-600">
                      {(msrpRow.minimum_margin_pct * 100).toFixed(2)}%
                    </p>
                    <p className="text-xs text-gray-500 mt-1">From category</p>
                  </div>
                  <div>
                    <p className="font-medium text-gray-700">MSRP % Sale Out</p>
                    <p className="text-lg font-semibold text-primary">
                      {(msrpRow.msrp_pct_sale_out * 100).toFixed(2)}%
                    </p>
                    <p className="text-xs text-gray-500 mt-1">From category</p>
                  </div>
                </div>
                {/* Bar: Shipping Cost | Import Tax | Total Cost | MSRP Sale In | MSRP Sale Out */}
                <div className="bg-blue-50 border border-blue-200 rounded p-4">
                  <div className="grid grid-cols-2 sm:grid-cols-5 gap-4 text-xs">
                    <div>
                      <p className="font-medium text-gray-700">Shipping Cost</p>
                      <p className="text-lg font-semibold">${msrpRow.shipping_cost.toFixed(2)}</p>
                    </div>
                    <div>
                      <p className="font-medium text-gray-700">Import Tax</p>
                      <p className="text-lg font-semibold">${msrpRow.import_tax_cost.toFixed(2)}</p>
                    </div>
                    <div>
                      <p className="font-medium text-gray-700">Total Cost</p>
                      <p className="text-lg font-semibold">${msrpRow.total_cost.toFixed(2)}</p>
                    </div>
                    <div>
                      <p className="font-medium text-gray-700">MSRP Sale In</p>
                      <p className="text-lg font-semibold text-green-600">${msrpRow.msrp_sale_in.toFixed(2)}</p>
                    </div>
                    <div>
                      <p className="font-medium text-gray-700">MSRP Sale Out</p>
                      <p className="text-lg font-semibold text-primary">${msrpRow.msrp_sale_out.toFixed(2)}</p>
                    </div>
                  </div>
                </div>
              </div>
            ) : (
              <p className="text-xs text-gray-500 bg-amber-50 border border-amber-200 rounded p-3">
                MSRP will be calculated by the system when cost and category are set. Recompute runs on save via triggers.
              </p>
            )}
          </div>
          
          {/* Category margin % (reference only; no final values) */}
          {categoryId && !categoryMarginsLoading && categoryMargins.length > 0 && (
            <div className="col-span-12">
              <h3 className="text-sm font-semibold mb-2">Category margin % (reference only)</h3>
              <p className="text-xs text-gray-500 mb-2">CategoryMargins only defines percentages; final MSRP is computed in the backend.</p>
              {(() => {
                const m = categoryMargins.find((x: any) => x.category_id === categoryId);
                if (!m) return <p className="text-xs text-gray-500">No margin defined for this category.</p>;
                return (
                  <div className="flex gap-4 text-xs">
                    <span>Minimum Margin (sale in): {Math.round(((m as any).msrp_pct_sale_in ?? (m as any).default_margin_pct ?? 0) * 100)}%</span>
                    <span>MSRP % Sale Out: {Math.round(((m as any).msrp_pct_sale_out ?? 0) * 100)}%</span>
                  </div>
                );
              })()}
            </div>
          )}
          
          {/* Info */}
          <div className="col-span-12 mt-6">
            <div className="bg-blue-50 border border-blue-200 rounded p-4">
              <p className="text-xs text-gray-700">
                <strong>ℹ️ MSRP:</strong> Values come only from <strong>CatalogItemsMSRP</strong>. The backend (triggers + <code>msrp_compute_for_item</code>) does the calculation. <strong>CategoryMargins</strong> only defines percentages; to change them: <strong>Settings → Cost Engine → Category Margins</strong>.
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
