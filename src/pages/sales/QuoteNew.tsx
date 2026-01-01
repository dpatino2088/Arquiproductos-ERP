/**
 * QuoteNew - Create and Edit Quotes
 * Clean implementation from scratch
 */

import { useState, useEffect, useMemo } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useCreateQuote, useUpdateQuote, useQuoteLines, approveQuote, normalizeStatus } from '../../hooks/useQuotes';
import { QuoteStatus } from '../../types/catalog';
import { Plus, Edit, Trash2, X, Download } from 'lucide-react';
import ProductConfigurator from './ProductConfigurator';
import { ProductConfig } from './product-config/types';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import { generateQuotePDF } from '../../lib/pdf/generateQuotePDF';
import { useCostSettings } from '../../hooks/useCosts';
import { calculateQuoteLinePrice } from '../../lib/pricing';

// Format currency
const formatCurrency = (amount: number, currency: string = 'USD') => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
};

// Quote status options
const QUOTE_STATUS_OPTIONS = [
  { value: 'draft', label: 'Draft' },
  { value: 'sent', label: 'Sent' },
  { value: 'approved', label: 'Approved' },
  { value: 'rejected', label: 'Rejected' },
] as const;

// Currency options
const CURRENCY_OPTIONS = [
  { value: 'USD', label: 'USD - US Dollar' },
  { value: 'EUR', label: 'EUR - Euro' },
  { value: 'GBP', label: 'GBP - British Pound' },
  { value: 'MXN', label: 'MXN - Mexican Peso' },
  { value: 'CAD', label: 'CAD - Canadian Dollar' },
] as const;

// Schema for Quote
const quoteSchema = z.object({
  quote_no: z.string().min(1, 'Quote number is required'),
  customer_id: z.string().uuid('Customer is required'),
  status: z.enum(['draft', 'sent', 'approved', 'rejected']),
  currency: z.string().min(1, 'Currency is required'),
  notes: z.string().optional(),
});

type QuoteFormValues = z.infer<typeof quoteSchema>;

interface Customer {
  id: string;
  customer_name: string;
  customer_type_name?: string | null; // VIP, Partner, Reseller, Distributor
  primary_contact_id?: string | null;
}

interface Contact {
  id: string;
  contact_name: string;
  email?: string | null;
  primary_phone?: string | null;
  customer_id?: string | null;
}

interface QuoteLineWithRelations {
  id: string;
  quote_id: string;
  catalog_item_id: string;
  qty: number;
  width_m?: number | null;
  height_m?: number | null;
  area?: string | null;
  position?: string | null;
  collection_name?: string | null;
  variant_name?: string | null;
  product_type?: string | null;
  product_type_id?: string | null;
  drive_type?: string | null;
  bottom_rail_type?: string | null;
  cassette?: boolean | null;
  cassette_type?: string | null;
  side_channel?: boolean | null;
  side_channel_type?: string | null;
  hardware_color?: string | null;
  computed_qty: number;
  line_total: number;
  ProductType?: { id: string; name: string } | null;
  CatalogItems?: { id: string; item_name: string; sku: string; uom: string } | null;
}

export default function QuoteNew() {
  const { activeOrganizationId } = useOrganizationContext();
  const { createQuote, isCreating } = useCreateQuote();
  const { updateQuote, isUpdating } = useUpdateQuote();
  const [quoteId, setQuoteId] = useState<string | null>(null);
  const [quoteData, setQuoteData] = useState<any>(null);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [selectedContactId, setSelectedContactId] = useState<string>('');
  const [showConfigurator, setShowConfigurator] = useState(false);
  const [editingLineId, setEditingLineId] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [initialLineConfig, setInitialLineConfig] = useState<ProductConfig | undefined>(undefined);

  const { lines: quoteLines, loading: loadingLines, refetch: refetchLines } = useQuoteLines(quoteId);
  const { settings: costSettings } = useCostSettings(); // Get cost settings for pricing calculations

  // Form setup
  const {
    register,
    handleSubmit,
    formState: { errors },
    setValue,
    watch,
  } = useForm<QuoteFormValues>({
    resolver: zodResolver(quoteSchema),
    defaultValues: {
      status: 'draft',
      currency: 'USD',
      notes: '',
    },
  });

  // Check URL for quote_id (edit mode) or line_id (edit line mode)
  useEffect(() => {
    const path = window.location.pathname;
    const urlMatch = path.match(/\/sales\/quotes\/edit\/([^/]+)/);
    const editQuoteId = urlMatch ? urlMatch[1] : null;

    const urlParams = new URLSearchParams(window.location.search);
    const queryQuoteId = urlParams.get('quote_id');
    const lineId = urlParams.get('line_id');

    if (editQuoteId) {
      setQuoteId(editQuoteId);
    } else if (queryQuoteId) {
      setQuoteId(queryQuoteId);
      if (lineId) {
        setEditingLineId(lineId);
        // Don't show configurator immediately - wait for line config to load
        // It will be shown when initialLineConfig is set
      }
    }
  }, []);

  // Load quote data when in edit mode
  useEffect(() => {
    const loadQuoteData = async () => {
      if (!quoteId || !activeOrganizationId) return;

      try {
        const { data, error } = await supabase
          .from('Quotes')
          .select('*')
          .eq('id', quoteId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .maybeSingle();

        if (error) throw error;

        if (data) {
          setQuoteData(data);
          // Set all values, ensuring quote_no is set first and won't be overwritten
          const quoteNo = (data as any).quote_no || '';
          setValue('quote_no', quoteNo, { shouldValidate: true });
          setValue('customer_id', data.customer_id || '');
          const status = data.status as QuoteStatus;
          setValue('status', (status === 'cancelled' ? 'draft' : status) || 'draft');
          setValue('currency', data.currency || 'USD');
          setValue('notes', data.notes || '');
          // Note: contact_id is not stored in Quotes table, so we don't load it
          // The contact dropdown is just for reference/display purposes
        }
      } catch (err) {
        console.error('Error loading quote:', err);
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: 'Failed to load quote data',
        });
      }
    };

    loadQuoteData();
  }, [quoteId, activeOrganizationId, setValue]);

  // Load customers
  useEffect(() => {
    const loadCustomers = async () => {
      if (!activeOrganizationId) return;

      try {
        const { data, error } = await supabase
          .from('DirectoryCustomers')
          .select('id, customer_name, customer_type_name, primary_contact_id')
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

  // Generate quote number for new quotes only (not when editing)
  useEffect(() => {
    const generateQuoteNo = async () => {
      // CRITICAL: Don't generate if editing - must preserve existing quote_no
      if (quoteId) {
        // When editing, ensure we keep the existing quote_no from quoteData
        // This will be set by loadQuoteData, but we ensure it's preserved here
        if (quoteData?.quote_no) {
          const currentQuoteNo = watch('quote_no');
          // Only set if it's different (to avoid unnecessary updates)
          if (currentQuoteNo !== quoteData.quote_no) {
            setValue('quote_no', quoteData.quote_no, { shouldValidate: true });
          }
        }
        return; // Never generate new number when editing
      }
      
      // Only generate for new quotes
      if (!activeOrganizationId) return;
      
      // Check if quote_no already has a value (from form state)
      const currentQuoteNo = watch('quote_no');
      if (currentQuoteNo && currentQuoteNo.trim() !== '') {
        return; // Already has a value, don't overwrite
      }

      try {
        // Use the utility function to generate next sequential number
        const { generateNextQuoteNumber } = await import('../../lib/sequential-numbers');
        const quoteNo = await generateNextQuoteNumber(activeOrganizationId);
        setValue('quote_no', quoteNo, { shouldValidate: true });
      } catch (err) {
        console.error('Error generating quote number:', err);
        const fallbackNo = `QT-${Date.now().toString().slice(-6)}`;
        setValue('quote_no', fallbackNo, { shouldValidate: true });
      }
    };

    // Small delay to ensure quoteData is loaded when editing
    const timeoutId = setTimeout(() => {
      generateQuoteNo();
    }, 100);

    return () => clearTimeout(timeoutId);
  }, [activeOrganizationId, quoteId, setValue, watch, quoteData]);

  // Calculate totals from List Price (MSRP End User) × Quantity
  // This shows the total MSRP value, not the net distributor price
  // Use the same qty that is displayed in the QTY column (line.qty, not computed_qty)
  const totals = useMemo(() => {
    const subtotal = quoteLines.reduce((sum, line) => {
      // Total = List Price (MSRP) × Quantity (the qty shown in the QTY column)
      // Fallback to unit_price_snapshot for old records that don't have list_unit_price_snapshot
      const listPrice = line.list_unit_price_snapshot || line.unit_price_snapshot || 0;
      const qty = line.qty || 1; // Use qty (what's displayed), not computed_qty
      return sum + (listPrice * qty);
    }, 0);
    const tax = 0; // TODO: Calculate tax if needed
    const total = subtotal + tax;

    return { subtotal, tax, total };
  }, [quoteLines]);

  // Handle product configuration completion
  const handleProductConfigComplete = async (productConfig: ProductConfig) => {
    if (!quoteId || !activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Quote must be saved first before adding lines',
      });
      return;
    }

    try {
      // Validate required fields for Roller Shade
      if (productConfig.productType === 'roller-shade') {
        const operatingSystemVariant = (productConfig as any).operating_system_variant;
        const tubeType = (productConfig as any).tube_type;
        const width_m = (productConfig as any).widthM || ((productConfig as any).width_mm ? (productConfig as any).width_mm / 1000 : null);
        const height_m = (productConfig as any).heightM || ((productConfig as any).height_mm ? (productConfig as any).height_mm / 1000 : null);
        const driveType = (productConfig as any).operation_type || (productConfig as any).drive_type;
        const sideChannel = (productConfig as any).side_channel;
        const sideChannelType = (productConfig as any).side_channel_type;
        
        const errors: string[] = [];
        if (!operatingSystemVariant) errors.push('Operating System Variant is required');
        if (!tubeType) errors.push('Tube Type is required');
        if (!width_m || width_m <= 0) errors.push('Width is required');
        if (!height_m || height_m <= 0) errors.push('Height is required');
        if (!driveType) errors.push('Drive Type is required');
        if (sideChannel && !sideChannelType) errors.push('Side Channel Type is required when Side Channel is enabled');
        
        if (errors.length > 0) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Validation Error',
            message: errors.join('. '),
          });
          return;
        }
      }
      
      // Extract data from productConfig
      const area = productConfig.area || null;
      const position = productConfig.position || null;
      const width_m = (productConfig as any).widthM || ((productConfig as any).width_mm ? (productConfig as any).width_mm / 1000 : null);
      const height_m = (productConfig as any).heightM || ((productConfig as any).height_mm ? (productConfig as any).height_mm / 1000 : null);
      const quantity = productConfig.quantity || 1;

      // Get catalog item ID (from productConfig)
      // For roller-shade: use variantId directly
      // For dual/triple-shade: use frontFabric.variantId
      // For drapery/awning: use fabric.variantId
      let catalogItemId: string | undefined;
      if (productConfig.productType === 'roller-shade') {
        catalogItemId = (productConfig as any).variantId || (productConfig as any).catalogItemId;
      } else if (productConfig.productType === 'dual-shade' || productConfig.productType === 'triple-shade') {
        catalogItemId = (productConfig as any).frontFabric?.variantId;
      } else if (productConfig.productType === 'drapery' || productConfig.productType === 'awning') {
        catalogItemId = (productConfig as any).fabric?.variantId;
      } else {
        catalogItemId = (productConfig as any).catalogItemId;
      }
      
      if (!catalogItemId) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: 'Catalog item ID is required. Please complete the product configuration and select a variant.',
        });
        return;
      }

      // Get product type ID - CRITICAL: Always try to find product_type_id
      let productTypeId: string | null = null;
      if (productConfig.productType) {
        // First try: exact match by code in organization
        const { data: productTypes } = await supabase
          .from('ProductTypes')
          .select('id')
          .eq('organization_id', activeOrganizationId)
          .eq('code', productConfig.productType)
          .eq('deleted', false)
          .limit(1);

        if (productTypes && productTypes.length > 0 && productTypes[0]?.id) {
          productTypeId = productTypes[0].id;
        } else {
          // Second try: case-insensitive match by code in organization
          const { data: productTypesCaseInsensitive } = await supabase
            .from('ProductTypes')
            .select('id')
            .eq('organization_id', activeOrganizationId)
            .ilike('code', productConfig.productType)
            .eq('deleted', false)
            .limit(1);

          if (productTypesCaseInsensitive && productTypesCaseInsensitive.length > 0 && productTypesCaseInsensitive[0]?.id) {
            productTypeId = productTypesCaseInsensitive[0].id;
          } else {
            // Third try: shared ProductTypes (organization_id IS NULL)
            const { data: sharedProductTypes } = await supabase
              .from('ProductTypes')
              .select('id')
              .is('organization_id', null)
              .ilike('code', productConfig.productType)
              .eq('deleted', false)
              .limit(1);

            if (sharedProductTypes && sharedProductTypes.length > 0 && sharedProductTypes[0]?.id) {
              productTypeId = sharedProductTypes[0].id;
            } else {
              // Fourth try: common fallback (ROLLER SHADE)
              const { data: fallbackProductTypes } = await supabase
                .from('ProductTypes')
                .select('id')
                .in('code', ['ROLLER', 'ROLLER_SHADE', 'ROLLER-SHADE'])
                .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
                .eq('deleted', false)
                .order('organization_id', { ascending: true }) // Prefer organization-specific
                .limit(1);

              if (fallbackProductTypes && fallbackProductTypes.length > 0 && fallbackProductTypes[0]?.id) {
                productTypeId = fallbackProductTypes[0].id;
                console.warn(`ProductType not found for code "${productConfig.productType}", using fallback: ${productTypeId}`);
              }
            }
          }
        }
      }
      
      // Log warning if productTypeId is still null
      if (!productTypeId && productConfig.productType) {
        console.warn(`⚠️ Could not find product_type_id for productType: "${productConfig.productType}". BOM generation may fail.`);
      }

      // Get collection and variant names from catalog item (only fields that exist)
      const { data: catalogItem } = await supabase
        .from('CatalogItems')
        .select('collection_name, variant_name, cost_exw, msrp, default_margin_pct, uom, item_category_id, sku')
        .eq('id', catalogItemId)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .maybeSingle();

      // SECURITY GUARD: Block quoting items without MSRP
      if (!catalogItem || !catalogItem.msrp || catalogItem.msrp === 0) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Cannot Add Line',
          message: `Catalog item ${catalogItem?.sku || catalogItemId} does not have MSRP (list price). Please define MSRP before adding to quote.`,
        });
        setShowConfigurator(false);
        return;
      }

      const collectionName = catalogItem?.collection_name || null;
      const variantName = catalogItem?.variant_name || null;

      // Calculate computed_qty (for pricing)
      const computedQty = width_m && height_m ? width_m * height_m : quantity;

      // Get customer type for pricing tier (from quote's customer)
      const quoteCustomerId = quoteData?.customer_id || watch('customer_id');
      const quoteCustomer = customers.find(c => c.id === quoteCustomerId);
      const customerType = quoteCustomer?.customer_type_name || 'VIP'; // Default to VIP if not set
      
      // Get MSRP (END USER list price) from CatalogItem
      // CatalogItems.msrp = MSRP END USER (precio lista público)
      const listPrice = catalogItem.msrp; // Already validated above (cannot be null/0)

      // Calculate net price for distributor (with tier discounts + margin floor)
      // This is the price the distributor/customer will pay (after discounts)
      const categoryMargin: number | null = null;
      const pricingResult = calculateQuoteLinePrice(
        {
          msrp: catalogItem.msrp,
          cost_exw: catalogItem?.cost_exw || null,
          // Don't include optional cost fields that may not exist in DB
          labor_cost_per_unit: null,
          shipping_cost_per_unit: null,
          freight_cost: null,
          handling_cost: null,
          import_tax_pct: null,
          default_margin_pct: catalogItem?.default_margin_pct || null,
        },
        customerType,
        costSettings || null,
        categoryMargin
      );

      // Net unit price (after tier discount + margin floor) - distributor pays this
      const netUnitPrice = pricingResult.unitPrice;
      
      // Line total = net price * quantity (distributor pays this total)
      const lineTotal = netUnitPrice * computedQty;

      // NORMALIZE side_channel to boolean (CRITICAL: prevent string contamination)
      // Handle ALL possible truthy/falsy values defensively
      const rawSideChannel = (productConfig as any).side_channel;
      
      // Explicitly check for false values first
      const isExplicitlyFalse = 
        rawSideChannel === false ||
        rawSideChannel === 'false' ||
        rawSideChannel === 0 ||
        rawSideChannel === '0' ||
        rawSideChannel === null ||
        rawSideChannel === undefined ||
        rawSideChannel === '';
      
      // Then check for true values
      const sideChannelBool = !isExplicitlyFalse && (
        rawSideChannel === true ||
        rawSideChannel === 'true' ||
        rawSideChannel === 1 ||
        rawSideChannel === '1'
      );
      
      const rawSideChannelType = (productConfig as any).side_channel_type;
      
      // CRITICAL: If side_channel is true, side_channel_type MUST be valid
      // If side_channel is false, side_channel_type MUST be null
      let sideChannelTypeNormalized: 'side_only' | 'side_and_bottom' | null = null;
      
      if (sideChannelBool) {
        // side_channel = true: validate type
        if (rawSideChannelType === 'side_only' || rawSideChannelType === 'side_and_bottom') {
          sideChannelTypeNormalized = rawSideChannelType;
        } else {
          // If side_channel is true but type is invalid/missing, default to 'side_only'
          // This prevents constraint violations
          sideChannelTypeNormalized = 'side_only';
          if (import.meta.env.DEV) {
            console.warn('QuoteNew: side_channel=true but invalid type, defaulting to side_only', {
              rawSideChannelType,
              rawSideChannel
            });
          }
        }
      } else {
        // side_channel = false: type MUST be null
        sideChannelTypeNormalized = null;
      }

      // Debug log in development
      if (import.meta.env.DEV) {
        console.log('QuoteNew: Normalized side_channel values', {
          rawSideChannel,
          isExplicitlyFalse,
          sideChannelBool,
          rawSideChannelType,
          sideChannelTypeNormalized,
          productConfig: {
            side_channel: (productConfig as any).side_channel,
            side_channel_type: (productConfig as any).side_channel_type,
            operating_system_variant: (productConfig as any).operating_system_variant,
          }
        });
      }
      
      // FINAL VALIDATION: Ensure data integrity before saving
      if (sideChannelBool && !sideChannelTypeNormalized) {
        console.error('QuoteNew: CRITICAL - side_channel=true but type is null! Forcing side_only');
        sideChannelTypeNormalized = 'side_only';
      }
      if (!sideChannelBool && sideChannelTypeNormalized !== null) {
        console.error('QuoteNew: CRITICAL - side_channel=false but type is not null! Forcing null');
        sideChannelTypeNormalized = null;
      }

      // Create QuoteLine
      const quoteLineData: any = {
        quote_id: quoteId,
        catalog_item_id: catalogItemId,
        qty: quantity,
        width_m,
        height_m,
        area,
        position,
        collection_name: collectionName,
        variant_name: variantName,
        product_type: productConfig.productType || null,
        product_type_id: productTypeId,
        bom_template_id: (productConfig as any).bom_template_id || null,
        operating_system_variant: (productConfig as any).operating_system_variant || null,
        tube_type: (productConfig as any).tube_type || null,
        drive_type: (productConfig as any).operation_type || (productConfig as any).drive_type || null,
        bottom_rail_type: (productConfig as any).bottom_rail_type || 'standard', // Default to 'standard' if not selected
        cassette: (productConfig as any).cassette || false,
        cassette_type: (productConfig as any).cassette_type || null,
        side_channel: sideChannelBool,
        side_channel_type: sideChannelTypeNormalized,
        hardware_color: (productConfig as any).hardware_color || (productConfig as any).hardwareColor || null,
        computed_qty: computedQty,
        // ============================================
        // PRICING SNAPSHOTS (Source of Truth)
        // ============================================
        // MSRP = End User List Price (precio lista público)
        list_unit_price_snapshot: listPrice, // CatalogItems.msrp (END USER price)
        // Net Price = Distributor price (after tier discount + margin floor)
        unit_price_snapshot: netUnitPrice, // Net unit price distributor pays (pricingResult.unitPrice)
        // Totals
        line_total: lineTotal, // Net total = netUnitPrice * computedQty (distributor pays this)
        // Optional: list_line_total_snapshot = listPrice * computedQty (end user would pay this)
        // ============================================
        // COST SNAPSHOTS
        // ============================================
        unit_cost_snapshot: catalogItem?.cost_exw || 0, // Legacy: cost_exw only (kept for compatibility)
        total_unit_cost_snapshot: pricingResult.totalUnitCost, // Total unit cost (for margin calculation)
        // ============================================
        // PRICING METADATA
        // ============================================
        discount_pct_used: pricingResult.discountPct, // Discount percentage from customer tier
        customer_type_snapshot: customerType, // Customer type used for tier discount (VIP, Partner, etc.)
        price_basis: pricingResult.priceBasis, // 'MSRP_TIER' or 'MARGIN_FLOOR'
        margin_pct_used: pricingResult.totalUnitCost > 0 && netUnitPrice > 0
          ? ((netUnitPrice - pricingResult.totalUnitCost) / netUnitPrice * 100)
          : null, // Actual margin achieved on net price (margin-on-sale)
        measure_basis_snapshot: 'area', // Default
        // ============================================
        // DO NOT WRITE LEGACY FIELDS:
        // - final_unit_price (deprecated)
        // - discount_percentage (deprecated)
        // - discount_amount (deprecated)
        // - discount_source (deprecated - use price_basis instead)
        // - margin_percentage (deprecated - use margin_pct_used instead)
        // - margin_source (deprecated)
        // ============================================
      };

      let finalLineId = editingLineId;

      if (editingLineId) {
        // Update existing line
        const { error: updateError } = await supabase
          .from('QuoteLines')
          .update(quoteLineData)
          .eq('id', editingLineId)
          .eq('organization_id', activeOrganizationId);

        if (updateError) throw updateError;

        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Success',
          message: 'Quote line updated successfully',
        });
      } else {
        // Create new line
        const { data: newLine, error: insertError } = await supabase
          .from('QuoteLines')
          .insert({
            ...quoteLineData,
            organization_id: activeOrganizationId,
          })
          .select('id')
          .single();

        if (insertError) throw insertError;
        if (!newLine?.id) throw new Error('Failed to create quote line');

        finalLineId = newLine.id;

        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Success',
          message: 'Quote line added successfully',
        });
      }

      // Upsert fabric QuoteLineComponent if catalog item is fabric
      // (Trigger should handle this automatically, but we call it explicitly as fallback)
      if (finalLineId && catalogItemId) {
        try {
          // Check if catalog item is fabric
          const { data: itemCheck } = await supabase
            .from('CatalogItems')
            .select('is_fabric')
            .eq('id', catalogItemId)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .maybeSingle();
          
          if (itemCheck?.is_fabric) {
            // Update QuoteLine metadata with fabric rotation/heatseal if provided
            const fabricRotation = (productConfig as any).fabric_rotation || false;
            const fabricHeatseal = (productConfig as any).fabric_heatseal || false;
            
            if (fabricRotation || fabricHeatseal) {
              await supabase
                .from('QuoteLines')
                .update({
                  metadata: {
                    fabric_rotation: fabricRotation,
                    fabric_heatseal: fabricHeatseal,
                  }
                })
                .eq('id', finalLineId)
                .eq('organization_id', activeOrganizationId);
            }
            
            // Call function to upsert fabric component
            await supabase.rpc('upsert_fabric_quote_line_component', {
              p_quote_line_id: finalLineId,
              p_organization_id: activeOrganizationId,
            });
          }
        } catch (fabricError) {
          console.warn('Fabric component creation failed:', fabricError);
          // Don't fail the whole operation if fabric component creation fails
        }
      }

      // Generate BOM if product_type_id exists
      if (productTypeId && finalLineId) {
        try {
          // Use operation_type if available, fallback to drive_type, then default to 'motor'
          const operationType = (productConfig as any).operation_type || 
                               (productConfig as any).drive_type || 
                               ((productConfig as any).operatingSystem === 'manual' ? 'manual' : 'motor');
          
          // Normalize side_channel for RPC (use same normalization as quoteLineData)
          // Use the already normalized values from quoteLineData to ensure consistency
          const sideChannelBoolRPC = sideChannelBool;
          const sideChannelTypeRPC = sideChannelTypeNormalized;
          
          await supabase.rpc('generate_configured_bom_for_quote_line', {
            p_quote_line_id: finalLineId,
            p_product_type_id: productTypeId,
            p_organization_id: activeOrganizationId,
            p_drive_type: operationType,
            p_bottom_rail_type: (productConfig as any).bottom_rail_type || 'standard',
            p_cassette: (productConfig as any).cassette || false,
            p_cassette_type: (productConfig as any).cassette_type || null,
            p_side_channel: sideChannelBoolRPC,
            p_side_channel_type: sideChannelTypeRPC,
            p_hardware_color: (productConfig as any).hardware_color || 
                            (productConfig as any).hardwareColor || 
                            'white',
            p_width_m: width_m || 0,
            p_height_m: height_m || 0,
            p_qty: quantity,
            p_tube_type: (productConfig as any).tube_type || null,
            p_operating_system_variant: (productConfig as any).operating_system_variant || null,
          });
        } catch (bomError) {
          console.warn('BOM generation failed:', bomError);
          // Don't fail the whole operation if BOM generation fails
        }
      }

      // Save accessories as QuoteLineComponents
      const accessories = (productConfig as any).accessories || [];
      if (finalLineId) {
        try {
          // IMPORTANT: Delete old accessories first (when editing)
          // This prevents duplicates and ensures clean state
          const { error: deleteError } = await supabase
            .from('QuoteLineComponents')
            .update({ deleted: true })
            .eq('quote_line_id', finalLineId)
            .eq('organization_id', activeOrganizationId)
            .or('source.eq.accessory,component_role.eq.accessory');

          if (deleteError && import.meta.env.DEV) {
            console.warn('Failed to delete old accessories:', deleteError);
          }

          // Insert new accessories if any
          if (accessories.length > 0) {
            // Get catalog items for accessories to get their names and costs
            const accessoryIds = accessories.map((a: any) => a.id).filter(Boolean);
            if (accessoryIds.length > 0) {
              const { data: accessoryItems } = await supabase
                .from('CatalogItems')
                .select('id, item_name, sku, msrp, cost_exw, default_margin_pct')
                .in('id', accessoryIds)
                .eq('organization_id', activeOrganizationId)
                .eq('deleted', false);

              // Insert accessories as QuoteLineComponents
              const accessoryComponents = accessories.map((acc: any) => {
                const catalogItem = accessoryItems?.find((item: any) => item.id === acc.id);
                const unitCost = acc.price || catalogItem?.msrp || 
                  (catalogItem?.cost_exw ? catalogItem.cost_exw * (1 + (catalogItem.default_margin_pct || 50) / 100) : 0);
                
                return {
                  organization_id: activeOrganizationId,
                  quote_line_id: finalLineId,
                  catalog_item_id: acc.id,
                  qty: acc.qty || 1,
                  unit_cost_exw: unitCost,
                  source: 'accessory',
                  component_role: 'accessory',
                  uom: (catalogItem as any)?.uom || 'ea',
                };
              });

              if (accessoryComponents.length > 0) {
                const { error: accessoryError } = await supabase
                  .from('QuoteLineComponents')
                  .insert(accessoryComponents);

                if (accessoryError && import.meta.env.DEV) {
                  console.warn('Failed to save accessories:', accessoryError);
                }
              }
            }
          }
        } catch (accessoryError) {
          console.warn('Error saving accessories:', accessoryError);
        }
      }

      // Compute costs
      if (finalLineId) {
        try {
          await supabase.rpc('compute_quote_line_cost', {
            p_quote_line_id: finalLineId,
          });
        } catch (costError) {
          console.warn('Cost computation failed:', costError);
        }
      }

      // Refresh lines
      await refetchLines();
      setShowConfigurator(false);
      setEditingLineId(null);
    } catch (err: any) {
      console.error('Error saving quote line:', err);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to save quote line',
      });
    }
  };

  // Handle delete line
  const handleDeleteLine = async (lineId: string) => {
    if (!confirm('Are you sure you want to delete this line?')) return;

    try {
      const { error } = await supabase
        .from('QuoteLines')
        .update({ deleted: true })
        .eq('id', lineId)
        .eq('organization_id', activeOrganizationId);

      if (error) throw error;

      await refetchLines();
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: 'Quote line deleted',
      });
    } catch (err: any) {
      console.error('Error deleting line:', err);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to delete quote line',
      });
    }
  };

  // Load initial config for editing a line
  useEffect(() => {
    const loadLineConfig = async () => {
      if (!editingLineId || !quoteId || !activeOrganizationId) {
        setInitialLineConfig(undefined);
        return;
      }

      try {
        // First, fetch the QuoteLine without embedded relationships (more reliable)
        const { data: lineData, error } = await supabase
          .from('QuoteLines')
          .select('*')
          .eq('id', editingLineId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .maybeSingle();

        if (error) throw error;
        if (!lineData) {
          setInitialLineConfig(undefined);
          return;
        }

        // Fetch CatalogItem separately (for main product)
        let catalogItem = null;
        if (lineData.catalog_item_id) {
          const { data: catalogItemData } = await supabase
            .from('CatalogItems')
            .select('id, collection_name, variant_name, sku, item_name')
            .eq('id', lineData.catalog_item_id)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .maybeSingle();
          catalogItem = catalogItemData;
        }

        // Fetch ProductType separately
        // Try to get product_type_id from lineData, or look it up by product_type string
        let productType = null;
        let productTypeId = lineData.product_type_id;
        
        if (!productTypeId && lineData.product_type) {
          // If product_type_id is not stored, try to find it by product_type string
          const { data: productTypeByCode } = await supabase
            .from('ProductTypes')
            .select('id, code, name')
            .eq('code', lineData.product_type.toUpperCase())
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .maybeSingle();
          
          if (productTypeByCode) {
            productTypeId = productTypeByCode.id;
            productType = productTypeByCode;
          }
        }
        
        if (productTypeId && !productType) {
          // Fetch ProductType by ID
          const { data: productTypeData } = await supabase
            .from('ProductTypes')
            .select('id, code, name')
            .eq('id', productTypeId)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .maybeSingle();
          productType = productTypeData;
        }

        // Load accessories (filter by source='accessory' OR component_role='accessory')
        // Fetch accessories and their CatalogItems separately
        const { data: accessoriesData } = await supabase
          .from('QuoteLineComponents')
          .select('id, catalog_item_id, qty, unit_cost_exw, source, component_role')
          .eq('quote_line_id', editingLineId)
          .eq('deleted', false)
          .eq('organization_id', activeOrganizationId)
          .or('source.eq.accessory,component_role.eq.accessory');

        // Fetch CatalogItems for accessories
        const accessoryCatalogItemIds = (accessoriesData || [])
          .map((acc: any) => acc.catalog_item_id)
          .filter((id: string | null) => id);
        
        let accessoriesCatalogItemsMap = new Map<string, any>();
        if (accessoryCatalogItemIds.length > 0) {
          const { data: accessoryCatalogItems } = await supabase
            .from('CatalogItems')
            .select('id, item_name, sku, msrp, name')
            .in('id', accessoryCatalogItemIds)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false);
          
          if (accessoryCatalogItems) {
            accessoryCatalogItems.forEach((item: any) => {
              accessoriesCatalogItemsMap.set(item.id, item);
            });
          }
        }

        const accessories = (accessoriesData || []).map((acc: any) => {
          const catalogItem = accessoriesCatalogItemsMap.get(acc.catalog_item_id);
          return {
            id: acc.catalog_item_id,
            // Use item_name from CatalogItems (same pattern as area/position from QuoteLines)
            name: catalogItem?.item_name || catalogItem?.name || catalogItem?.sku || 'Unknown',
            qty: acc.qty || 1,
            price: acc.unit_cost_exw || catalogItem?.msrp || 0,
          };
        });

        // Convert QuoteLine to ProductConfig based on product_type
        // Use productType from DB query or fallback to lineData.product_type
        const productTypeCode = productType?.code || lineData.product_type?.toUpperCase() || 'ROLLER';
        // Map DB code to UI code
        const productTypeMap: Record<string, string> = {
          'ROLLER': 'roller-shade',
          'DUAL': 'dual-shade',
          'TRIPLE': 'triple-shade',
          'DRAPERY': 'drapery',
          'AWNING': 'awning',
          'FILM': 'window-film',
        };
        const productTypeUI = productTypeMap[productTypeCode] || 'roller-shade';
        
        // CRITICAL: Ensure we have productTypeId - use the one we found or fallback
        const finalProductTypeId = productTypeId || productType?.id;
        const width_mm = lineData.width_m ? lineData.width_m * 1000 : undefined;
        const height_mm = lineData.height_m ? lineData.height_m * 1000 : undefined;

        let config: ProductConfig;

        if (productTypeUI === 'roller-shade' || productTypeUI === 'triple-shade') {
          config = {
            productType: productTypeUI as 'roller-shade' | 'triple-shade',
            productTypeId: finalProductTypeId || undefined,
            area: lineData.area || undefined,
            position: lineData.position || '',
            quantity: lineData.qty || 1,
            width_mm,
            height_mm,
            variantId: lineData.catalog_item_id,
            catalogItemId: lineData.catalog_item_id,
            fabric_catalog_item_id: lineData.catalog_item_id, // For VariantsStep
            collectionName: catalogItem?.collection_name || lineData.collection_name || undefined, // For VariantsStep dropdown
            variantName: catalogItem?.variant_name || lineData.variant_name || undefined, // For display
            operatingSystem: lineData.drive_type === 'motor' ? 'motorized' : 'manual',
            operation_type: lineData.drive_type || 'motor',
            drive_type: lineData.drive_type || 'motor',
            bom_template_id: lineData.bom_template_id || undefined,
            operating_system_variant: lineData.operating_system_variant || undefined,
            tube_type: lineData.tube_type || undefined,
            bottom_rail_type: lineData.bottom_rail_type || 'standard',
            cassette: lineData.cassette || false,
            cassette_type: lineData.cassette_type || undefined,
            side_channel: lineData.side_channel || false,
            // CRITICAL: If side_channel is true but type is null, default to 'side_only'
            side_channel_type: lineData.side_channel 
              ? (lineData.side_channel_type || 'side_only')
              : (lineData.side_channel_type || undefined),
            hardware_color: lineData.hardware_color || 'white',
            hardwareColor: lineData.hardware_color || 'white',
            fabric_rotation: lineData.metadata?.fabric_rotation || false,
            fabric_heatseal: lineData.metadata?.fabric_heatseal || false,
            accessories,
          } as ProductConfig;
        } else if (productTypeUI === 'dual-shade') {
          config = {
            productType: 'dual-shade',
            productTypeId: finalProductTypeId || undefined,
            area: lineData.area || undefined,
            position: lineData.position || '',
            quantity: lineData.qty || 1,
            width_mm,
            height_mm,
            frontFabric: {
              variantId: lineData.catalog_item_id,
            },
            fabric_catalog_item_id: lineData.catalog_item_id, // For VariantsStep
            collectionName: catalogItem?.collection_name || lineData.collection_name || undefined, // For VariantsStep dropdown
            variantName: catalogItem?.variant_name || lineData.variant_name || undefined, // For display
            operatingSystem: lineData.drive_type === 'motor' ? 'motorized' : 'manual',
            drive_type: lineData.drive_type || 'motor',
            bottom_rail_type: lineData.bottom_rail_type || 'standard',
            cassette: lineData.cassette || false,
            side_channel: lineData.side_channel || false,
            hardware_color: lineData.hardware_color || 'white',
            fabric_rotation: lineData.metadata?.fabric_rotation || false,
            fabric_heatseal: lineData.metadata?.fabric_heatseal || false,
            accessories,
          } as ProductConfig;
        } else {
          // Default to roller-shade if unknown type
          config = {
            productType: 'roller-shade',
            productTypeId: finalProductTypeId || undefined,
            area: lineData.area || undefined,
            position: lineData.position || '',
            quantity: lineData.qty || 1,
            width_mm,
            height_mm,
            variantId: lineData.catalog_item_id,
            catalogItemId: lineData.catalog_item_id,
            fabric_catalog_item_id: lineData.catalog_item_id, // For VariantsStep
            collectionName: catalogItem?.collection_name || lineData.collection_name || undefined, // For VariantsStep dropdown
            variantName: catalogItem?.variant_name || lineData.variant_name || undefined, // For display
            operatingSystem: lineData.drive_type === 'motor' ? 'motorized' : 'manual',
            fabric_rotation: lineData.metadata?.fabric_rotation || false,
            fabric_heatseal: lineData.metadata?.fabric_heatseal || false,
            accessories,
          } as ProductConfig;
        }

        if (import.meta.env.DEV) {
          console.log('loadLineConfig: Config loaded - FULL DEBUG', {
            lineId: editingLineId,
            productType: config.productType,
            productTypeId: config.productTypeId,
            productTypeFromDB: productType?.id,
            finalProductTypeId: finalProductTypeId,
            hasArea: !!config.area,
            hasPosition: !!config.position,
            accessoriesCount: accessories.length,
            hasCollection: !!config.collectionName,
            hasVariant: !!config.variantName,
            width_mm: config.width_mm,
            height_mm: config.height_mm,
            drive_type: (config as any).drive_type,
            hardware_color: (config as any).hardware_color,
            fullConfig: config,
          });
        }

        setInitialLineConfig(config);
        // Show configurator after config is loaded
        if (editingLineId) {
          setShowConfigurator(true);
        }
      } catch (err: any) {
        const errorMessage = err?.message || 'Failed to load quote line configuration';
        if (import.meta.env.DEV) {
          console.error('Error loading line config:', {
            message: errorMessage,
            code: err?.code,
            editingLineId,
            quoteId,
          });
        }
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error loading quote line',
          message: errorMessage + '. Please try again.',
        });
        setInitialLineConfig(undefined);
      }
    };

    loadLineConfig();
  }, [editingLineId, quoteId, activeOrganizationId]);

  // Handle edit line
  const handleEditLine = (lineId: string) => {
    setEditingLineId(lineId);
    // Don't show configurator immediately - wait for loadLineConfig to finish
    // The useEffect will show it after config is loaded
  };

  // Handle PDF download
  const handleDownloadPDF = async () => {
    if (!quoteId || !quoteData || !selectedCustomer) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Quote data is not available',
      });
      return;
    }

    try {
      // Get organization name
      const { data: orgData } = await supabase
        .from('Organizations')
        .select('name')
        .eq('id', activeOrganizationId)
        .maybeSingle();

      const organizationName = orgData?.name || 'Arquiproductos';

      // Generate PDF
      const doc = generateQuotePDF(
        {
          quote_no: quoteData.quote_no || watch('quote_no'),
          customer_id: quoteData.customer_id || watch('customer_id'),
          status: quoteData.status || watch('status'),
          currency: quoteData.currency || watch('currency'),
          notes: quoteData.notes || watch('notes'),
          totals: quoteData.totals || totals,
          created_at: quoteData.created_at || new Date().toISOString(),
        },
        selectedCustomer,
        selectedContact || null,
        quoteLines as any[],
        organizationName
      );

      // Download PDF
      const fileName = `Quote_${quoteData.quote_no || watch('quote_no')}_${new Date().toISOString().split('T')[0]}.pdf`;
      doc.save(fileName);

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: 'PDF downloaded successfully',
      });
    } catch (err: any) {
      console.error('Error generating PDF:', err);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to generate PDF',
      });
    }
  };

  // Handle form submit
  const onSubmit = async (data: QuoteFormValues, shouldNavigate: boolean = false) => {
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
      const quoteData: any = {
        quote_no: data.quote_no,
        customer_id: data.customer_id,
        // Note: contact_id is not stored in Quotes table, only customer_id
        status: data.status,
        currency: data.currency,
        notes: data.notes || null,
        totals: {
          subtotal: totals.subtotal,
          tax_total: totals.tax,
          total: totals.total,
        },
        organization_id: activeOrganizationId,
      };

      if (quoteId) {
        // Update existing quote
        // Check if status is changing to 'approved' - use approveQuote function
        const isApproving = normalizeStatus(quoteData.status) === 'approved';
        
        // If approving, update other fields FIRST, then approve (safer transaction order)
        if (isApproving) {
          console.log('🔔 QuoteNew: Status changed to approved, using approveQuote function');
          
          // Step 1: Update other fields first (without status)
          const { status, ...safeData } = quoteData;
          if (Object.keys(safeData).length > 0) {
            await updateQuote(quoteId, safeData);
          }
          
          // Step 2: Approve quote (this triggers the DB trigger)
          await approveQuote(quoteId, activeOrganizationId);
        } else {
          // For non-approval updates, use regular updateQuote
          await updateQuote(quoteId, quoteData);
        }
        
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Success',
          message: isApproving ? 'Quote approved successfully' : 'Quote updated successfully',
        });
        
        // Only navigate if shouldNavigate is true
        if (shouldNavigate) {
          // If status is 'approved', navigate to QuoteApproved view
          if (isApproving) {
            router.navigate('/sales/quotes/approved');
          } else {
            // Otherwise, navigate back to quotes list
            router.navigate('/sales/quotes');
          }
        }
      } else {
        // Create new quote
        const created = await createQuote(quoteData);
        if (created?.id) {
          // Update quoteId state so form knows it's now in edit mode
          setQuoteId(created.id);
          setQuoteData(created);
          
          useUIStore.getState().addNotification({
            type: 'success',
            title: 'Success',
            message: 'Quote created successfully',
          });
          
          // Only navigate if shouldNavigate is true
          if (shouldNavigate) {
            // If status is 'approved', navigate to QuoteApproved view
            if (quoteData.status === 'approved') {
              router.navigate('/sales/quotes/approved');
            } else {
              // Otherwise, navigate back to quotes list
              router.navigate('/sales/quotes');
            }
          }
        }
      }
    } catch (err: any) {
      console.error('Error saving quote:', err);
      setSaveError(err.message || 'Failed to save quote');
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to save quote',
      });
    } finally {
      setIsSaving(false);
    }
  };

  // Wrapper for Save and Close button
  const handleSaveAndClose = async (data: QuoteFormValues) => {
    await onSubmit(data, true); // Pass true to navigate after saving
  };

  // Get selected customer name
  const selectedCustomer = customers.find(c => c.id === selectedCustomerId);
  const selectedContact = contacts.find(c => c.id === selectedContactId);

  return (
    <div className="py-6 px-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">
            {quoteId ? 'Edit Quote' : 'New Quote'}
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {quoteId ? 'Edit quote information' : 'Create a new quote'}
          </p>
        </div>

        <div className="flex items-center gap-3">
          {quoteId && (
            <button
              type="button"
              onClick={handleDownloadPDF}
              className="flex items-center gap-2 px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
              title="Download PDF"
            >
              <Download className="w-4 h-4" />
              Download PDF
            </button>
          )}
          <button
            type="button"
            onClick={() => router.navigate('/sales/quotes')}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
          >
            Close
          </button>
          <button
            type="button"
            onClick={handleSubmit((data) => onSubmit(data, false))}
            disabled={isSaving || isCreating || isUpdating}
            className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            {isSaving || isCreating || isUpdating ? 'Saving...' : 'Save'}
          </button>
          <button
            type="button"
            onClick={handleSubmit(handleSaveAndClose)}
            disabled={isSaving || isCreating || isUpdating}
            className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            style={{ backgroundColor: '#10b981' }}
          >
            {isSaving || isCreating || isUpdating ? 'Saving...' : 'Save and Close'}
          </button>
        </div>
      </div>

      {saveError && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {saveError}
        </div>
      )}

      {/* Quote Form */}
      <div className="bg-white border border-gray-200 rounded-lg p-6 mb-4">
        <div className="grid grid-cols-12 gap-4">
          {/* Quote Number */}
          <div className="col-span-12 md:col-span-6">
            <Label htmlFor="quote_no">Quote Number *</Label>
            <Input
              id="quote_no"
              {...register('quote_no')}
              error={errors.quote_no?.message}
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
              value={watch('status') || 'draft'}
              onValueChange={(value) => {
                const validStatus = value as 'draft' | 'sent' | 'approved' | 'rejected';
                setValue('status', validStatus);
              }}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {QUOTE_STATUS_OPTIONS.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
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
          {quoteId && (
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

      {/* Quote Lines Section */}
      {quoteId && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
          <div className="py-4 px-6 border-b border-gray-200">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-semibold text-foreground">Quote Lines</h2>
                <p className="text-sm text-gray-500 mt-1">{quoteLines.length} {quoteLines.length === 1 ? 'line' : 'lines'}</p>
              </div>
              <button
                type="button"
                onClick={() => {
                  setEditingLineId(null);
                  setInitialLineConfig(undefined); // Clear config for new line
                  setShowConfigurator(true);
                }}
                className="flex items-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors text-sm font-medium"
              >
                <Plus className="w-4 h-4" />
                Add Line
              </button>
            </div>
          </div>

          {loadingLines ? (
            <div className="p-6 text-center text-gray-500">Loading lines...</div>
          ) : quoteLines.length === 0 ? (
            <div className="p-6 text-center text-gray-500">No lines added yet. Click "Add Line" to get started.</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Area</th>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Position</th>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Product Type</th>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Collection</th>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">System Drive</th>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Measurements</th>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Accessories</th>
                    <th className="py-3 px-6 text-right text-xs font-medium text-gray-700 uppercase tracking-wider">Qty</th>
                    <th className="py-3 px-6 text-right text-xs font-medium text-gray-700 uppercase tracking-wider">List Price</th>
                    <th className="py-3 px-6 text-right text-xs font-medium text-gray-700 uppercase tracking-wider">Total</th>
                    <th className="py-3 px-6 text-right text-xs font-medium text-gray-700 uppercase tracking-wider">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {quoteLines.map((line: any) => {
                    // Extract data from line
                    const area = line.area ?? null;
                    const position = line.position ?? null;
                    
                    const productTypeName = line.ProductType?.name || line.product_type || 'N/A';
                    const collectionDisplay = line.collection_name && line.variant_name
                      ? `${line.collection_name} - ${line.variant_name}`
                      : line.collection_name || line.variant_name || 'N/A';
                    const driveType = line.drive_type;
                    const driveDisplay = driveType === 'motor' ? 'Motorized' : driveType === 'manual' ? 'Manual' : 'N/A';

                    return (
                      <tr key={line.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {area != null && String(area).trim() !== '' ? String(area).trim() : '—'}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {position != null && String(position).trim() !== '' ? String(position).trim() : '—'}
                        </td>
                        <td className="py-4 px-6 text-gray-900 text-sm font-medium">
                          {productTypeName}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {collectionDisplay}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {driveDisplay}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {line.width_m && line.height_m
                            ? `${(line.width_m * 1000).toFixed(0)} x ${(line.height_m * 1000).toFixed(0)} mm`
                            : '—'}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {line.Accessories && line.Accessories.length > 0 ? (
                            <div className="flex flex-wrap gap-1 items-center">
                              {line.Accessories.map((acc: any, idx: number) => {
                                // Get item_name from CatalogItems relationship (similar to how area/position work)
                                const itemName = acc.CatalogItems?.item_name || 
                                                acc.CatalogItems?.name || 
                                                acc.CatalogItems?.sku || 
                                                'Unknown';
                                return (
                                  <span key={acc.id || idx} className="text-xs bg-gray-100 px-2 py-0.5 rounded inline-block">
                                    {itemName}
                                  </span>
                                );
                              })}
                            </div>
                          ) : (
                            <span className="text-gray-400">—</span>
                          )}
                        </td>
                        <td className="py-4 px-6 text-right text-gray-900 text-sm">
                          {line.qty ? line.qty.toFixed(0) : 'N/A'}
                        </td>
                        {/* List Price (MSRP End User) */}
                        <td className="py-4 px-6 text-right text-gray-900 text-sm font-medium">
                          {(() => {
                            // Use list_unit_price_snapshot if available, otherwise fallback to unit_price_snapshot (for old records)
                            const listPrice = line.list_unit_price_snapshot || line.unit_price_snapshot || 0;
                            return formatCurrency(listPrice, watch('currency'));
                          })()}
                        </td>
                        {/* Total (List Price × Quantity) */}
                        <td className="py-4 px-6 text-right text-gray-900 text-sm font-medium">
                          {(() => {
                            // Use list_unit_price_snapshot if available, otherwise fallback to unit_price_snapshot (for old records)
                            const listPrice = line.list_unit_price_snapshot || line.unit_price_snapshot || 0;
                            // Use the same qty that is displayed in the QTY column
                            const qty = line.qty || 1;
                            return formatCurrency(listPrice * qty, watch('currency'));
                          })()}
                        </td>
                        <td className="py-4 px-6">
                          <div className="flex items-center gap-1 justify-end">
                            <button
                              onClick={() => handleEditLine(line.id)}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                              title="Edit line"
                            >
                              <Edit className="w-4 h-4" />
                            </button>
                            <button
                              onClick={() => handleDeleteLine(line.id)}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-red-600"
                              title="Delete line"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
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

      {/* Product Configurator Modal */}
      {showConfigurator && quoteId && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg shadow-xl w-full max-w-6xl max-h-[90vh] overflow-hidden flex flex-col">
            <div className="flex items-center justify-between p-4 border-b">
              <h2 className="text-lg font-semibold">
                {editingLineId ? 'Edit Quote Line' : 'Add Quote Line'}
              </h2>
              <button
                onClick={() => {
                  setShowConfigurator(false);
                  setEditingLineId(null);
                  setInitialLineConfig(undefined); // Clear config when closing
                }}
                className="p-1 hover:bg-gray-100 rounded transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="flex-1 overflow-y-auto">
              <ProductConfigurator
                quoteId={quoteId}
                onComplete={handleProductConfigComplete}
                onClose={() => {
                  setShowConfigurator(false);
                  setEditingLineId(null);
                  setInitialLineConfig(undefined);
                }}
                initialConfig={initialLineConfig}
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
