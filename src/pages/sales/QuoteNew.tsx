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
import { useCreateQuote, useUpdateQuote, useQuoteLines } from '../../hooks/useQuotes';
import { QuoteStatus } from '../../types/catalog';
import { Plus, Edit, Trash2, X, Download } from 'lucide-react';
import ProductConfigurator from './ProductConfigurator';
import { ProductConfig } from './product-config/types';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import { generateQuotePDF } from '../../lib/pdf/generateQuotePDF';

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

  const { lines: quoteLines, loading: loadingLines, refetch: refetchLines } = useQuoteLines(quoteId);

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
        setShowConfigurator(true);
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
          setValue('quote_no', (data as any).quote_no || '');
          setValue('customer_id', data.customer_id || '');
          setValue('status', (data.status as QuoteStatus) || 'draft');
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

  // Generate quote number for new quotes
  useEffect(() => {
    const generateQuoteNo = async () => {
      if (quoteId || !activeOrganizationId) return; // Don't generate if editing

      try {
        const { data, error } = await supabase
          .from('Quotes')
          .select('quote_no')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: false })
          .limit(1);

        if (error) throw error;

        let nextNumber = 1;
        if (data && data.length > 0) {
          const lastNo = (data[0] as any).quote_no;
          const match = lastNo?.match(/QT-(\d+)/);
          if (match) {
            nextNumber = parseInt(match[1], 10) + 1;
          }
        }

        const quoteNo = `QT-${String(nextNumber).padStart(6, '0')}`;
        setValue('quote_no', quoteNo, { shouldValidate: true });
      } catch (err) {
        console.error('Error generating quote number:', err);
        const fallbackNo = `QT-${Date.now()}`;
        setValue('quote_no', fallbackNo, { shouldValidate: true });
      }
    };

    generateQuoteNo();
  }, [activeOrganizationId, quoteId, setValue]);

  // Calculate totals
  const totals = useMemo(() => {
    const subtotal = quoteLines.reduce((sum, line) => sum + (line.line_total || 0), 0);
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
      // Extract data from productConfig
      const area = productConfig.area || null;
      const position = productConfig.position || null;
      const width_m = productConfig.widthM || null;
      const height_m = productConfig.heightM || null;
      const quantity = productConfig.quantity || 1;

      // Get catalog item ID (from productConfig)
      const catalogItemId = (productConfig as any).catalogItemId;
      if (!catalogItemId) {
        throw new Error('Catalog item ID is required');
      }

      // Get product type ID
      let productTypeId: string | null = null;
      if (productConfig.productType) {
        const { data: productTypes } = await supabase
          .from('ProductTypes')
          .select('id')
          .eq('organization_id', activeOrganizationId)
          .eq('code', productConfig.productType)
          .eq('deleted', false)
          .limit(1);

        if (productTypes && productTypes.length > 0) {
          productTypeId = productTypes[0].id;
        }
      }

      // Get collection and variant names from catalog item
      const { data: catalogItem } = await supabase
        .from('CatalogItems')
        .select('collection_name, variant_name, cost_exw, msrp, default_margin_pct, uom')
        .eq('id', catalogItemId)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .maybeSingle();

      const collectionName = catalogItem?.collection_name || null;
      const variantName = catalogItem?.variant_name || null;

      // Calculate computed_qty (for pricing)
      const computedQty = width_m && height_m ? width_m * height_m : quantity;

      // Calculate unit price
      let unitPrice = 0;
      if (catalogItem?.msrp) {
        unitPrice = catalogItem.msrp;
      } else if (catalogItem?.cost_exw && catalogItem?.default_margin_pct) {
        unitPrice = catalogItem.cost_exw * (1 + catalogItem.default_margin_pct / 100);
      } else if (catalogItem?.cost_exw) {
        unitPrice = catalogItem.cost_exw * 1.5; // Default 50% margin
      }

      const lineTotal = unitPrice * computedQty;

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
        drive_type: (productConfig as any).drive_type || null,
        bottom_rail_type: (productConfig as any).bottom_rail_type || null,
        cassette: (productConfig as any).cassette || false,
        cassette_type: (productConfig as any).cassette_type || null,
        side_channel: (productConfig as any).side_channel || false,
        side_channel_type: (productConfig as any).side_channel_type || null,
        hardware_color: (productConfig as any).hardware_color || null,
        computed_qty: computedQty,
        unit_price_snapshot: unitPrice,
        unit_cost_snapshot: catalogItem?.cost_exw || 0,
        line_total: lineTotal,
        measure_basis_snapshot: 'area', // Default
        margin_percentage: catalogItem?.default_margin_pct || 50,
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

      // Generate BOM if product_type_id exists
      if (productTypeId && finalLineId) {
        try {
          await supabase.rpc('generate_configured_bom_for_quote_line', {
            p_quote_line_id: finalLineId,
            p_product_type_id: productTypeId,
            p_organization_id: activeOrganizationId,
            p_drive_type: (productConfig as any).drive_type || 'motor',
            p_bottom_rail_type: (productConfig as any).bottom_rail_type || 'standard',
            p_cassette: (productConfig as any).cassette || false,
            p_cassette_type: (productConfig as any).cassette_type || null,
            p_side_channel: (productConfig as any).side_channel || false,
            p_side_channel_type: (productConfig as any).side_channel_type || null,
            p_hardware_color: (productConfig as any).hardware_color || 'white',
            p_width_m: width_m || 0,
            p_height_m: height_m || 0,
            p_qty: quantity,
          });
        } catch (bomError) {
          console.warn('BOM generation failed:', bomError);
          // Don't fail the whole operation if BOM generation fails
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

  // Handle edit line
  const handleEditLine = (lineId: string) => {
    router.navigate(`/sales/quotes/new?quote_id=${quoteId}&line_id=${lineId}`);
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
  const onSubmit = async (data: QuoteFormValues) => {
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
        await updateQuote(quoteId, quoteData);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Success',
          message: 'Quote updated successfully',
        });
        // Navigate back to quotes list
        router.navigate('/sales/quotes');
      } else {
        // Create new quote
        const created = await createQuote(quoteData);
        if (created?.id) {
          useUIStore.getState().addNotification({
            type: 'success',
            title: 'Success',
            message: 'Quote created successfully',
          });
          // Navigate back to quotes list
          router.navigate('/sales/quotes');
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
            onClick={handleSubmit(onSubmit)}
            disabled={isSaving || isCreating || isUpdating}
            className="px-4 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            {isSaving || isCreating || isUpdating ? 'Saving...' : 'Save'}
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
              onValueChange={(value) => setValue('status', value as QuoteStatus)}
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
                    <th className="py-3 px-6 text-right text-xs font-medium text-gray-700 uppercase tracking-wider">Qty</th>
                    <th className="py-3 px-6 text-right text-xs font-medium text-gray-700 uppercase tracking-wider">Total Price</th>
                    <th className="py-3 px-6 text-right text-xs font-medium text-gray-700 uppercase tracking-wider">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {quoteLines.map((line: any) => {
                    // Debug: Log the line data to see what we're getting
                    if (import.meta.env.DEV) {
                      console.log('QuoteLine data:', {
                        id: line.id,
                        area: line.area,
                        position: line.position,
                        allKeys: Object.keys(line),
                        rawLine: line,
                      });
                    }

                    // Try multiple ways to access area and position
                    const area = line.area ?? (line as any).Area ?? null;
                    const position = line.position ?? (line as any).Position ?? null;
                    
                    const productTypeName = line.ProductType?.name || line.product_type || 'N/A';
                    const collectionDisplay = line.collection_name && line.variant_name
                      ? `${line.collection_name} - ${line.variant_name}`
                      : line.collection_name || line.variant_name || 'N/A';
                    const driveType = line.drive_type;
                    const driveDisplay = driveType === 'motor' ? 'Motorized' : driveType === 'manual' ? 'Manual' : 'N/A';

                    return (
                      <tr key={line.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {area != null && String(area).trim() !== '' ? String(area).trim() : 'N/A'}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {position != null && String(position).trim() !== '' ? String(position).trim() : 'N/A'}
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
                            : 'N/A'}
                        </td>
                        <td className="py-4 px-6 text-right text-gray-900 text-sm">
                          {line.qty ? line.qty.toFixed(0) : 'N/A'}
                        </td>
                        <td className="py-4 px-6 text-right text-gray-900 text-sm">
                          <div className="font-medium">
                            {formatCurrency(line.line_total || 0, watch('currency'))}
                          </div>
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
          <div className="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] overflow-hidden flex flex-col">
            <div className="flex items-center justify-between p-4 border-b">
              <h2 className="text-lg font-semibold">
                {editingLineId ? 'Edit Quote Line' : 'Add Quote Line'}
              </h2>
              <button
                onClick={() => {
                  setShowConfigurator(false);
                  setEditingLineId(null);
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
                }}
                initialConfig={editingLineId ? undefined : undefined} // TODO: Load initial config for editing
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
