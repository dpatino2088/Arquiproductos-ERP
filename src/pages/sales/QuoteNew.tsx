import { useState, useEffect, useMemo } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import Input from '../../components/ui/Input';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Label from '../../components/ui/Label';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useCreateQuote, useUpdateQuote, useQuotes, useQuoteLines } from '../../hooks/useQuotes';
import { QuoteStatus, MeasureBasis } from '../../types/catalog';
import { Search, X, Plus, Edit, Trash2 } from 'lucide-react';
import CurtainConfigurator, { CurtainConfiguration } from './CurtainConfigurator';
import { computeComputedQty } from '../../lib/catalog/computeComputedQty';

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
  quote_number: z.string().min(1, 'Quote number is required'),
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

interface CustomerWithContacts extends Customer {
  contacts?: Contact[];
  primary_contact?: Contact | null;
}

export default function QuoteNew() {
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [quoteId, setQuoteId] = useState<string | null>(null);
  const [customers, setCustomers] = useState<CustomerWithContacts[]>([]);
  const [allContacts, setAllContacts] = useState<Contact[]>([]);
  const [loadingCustomers, setLoadingCustomers] = useState(true);
  const [quoteNo, setQuoteNo] = useState<string>('');
  const [customerSearchTerm, setCustomerSearchTerm] = useState('');
  const [showCustomerDropdown, setShowCustomerDropdown] = useState(false);
  const [selectedContactId, setSelectedContactId] = useState<string>('');
  const [showConfigurator, setShowConfigurator] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();
  const { createQuote, isCreating } = useCreateQuote();
  const { updateQuote, isUpdating } = useUpdateQuote();
  const { quotes } = useQuotes();
  const { lines: quoteLines, loading: loadingLines, refetch: refetchLines } = useQuoteLines(quoteId);
  
  // Get current user's role and permissions
  const { canEditCustomers, loading: roleLoading } = useCurrentOrgRole();
  
  // Determine if form should be read-only
  const isReadOnly = !canEditCustomers;

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    trigger,
    formState: { errors },
  } = useForm<QuoteFormValues>({
    resolver: zodResolver(quoteSchema),
    defaultValues: {
      status: 'draft',
      currency: 'USD',
    },
  });

  // Get quote ID from URL if in edit mode - MUST run first
  useEffect(() => {
    const getQuoteIdFromUrl = () => {
      const path = window.location.pathname;
      const match = path.match(/\/sales\/quotes\/edit\/([^/]+)/);
      if (match && match[1]) {
        const id = match[1];
        console.log('Quote ID from URL:', id);
        setQuoteId(id);
        return id;
      } else {
        setQuoteId(null);
        return null;
      }
    };

    getQuoteIdFromUrl();

    // Also listen for route changes
    const handleRouteChange = () => {
      getQuoteIdFromUrl();
    };

    // Check on mount and when pathname changes
    window.addEventListener('popstate', handleRouteChange);
    
    return () => {
      window.removeEventListener('popstate', handleRouteChange);
    };
  }, []);

  // Generate quote number - only if NOT editing
  useEffect(() => {
    const generateQuoteNo = async () => {
      // Don't generate if editing or if no organization
      if (!activeOrganizationId || quoteId) {
        return;
      }

      // Only generate if quote_no is not already set
      if (quoteNo) {
        return;
      }

      try {
        // Get the last quote number for this organization
        const { data, error } = await supabase
          .from('Quotes')
          .select('quote_number')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: false })
          .limit(1);

        if (error && error.code !== 'PGRST116') {
          console.error('Error fetching last quote:', error);
        }

        let nextNumber = 1;
        if (data && data.length > 0) {
          // Try quote_number first, then quote_no for backward compatibility
          const lastQuoteNo = (data[0] as any).quote_number || (data[0] as any).quote_no;
          if (lastQuoteNo) {
            const match = lastQuoteNo.match(/\d+/);
            if (match) {
              nextNumber = parseInt(match[0], 10) + 1;
            }
          }
        }

        // Format as QT-000001, QT-000002, etc.
        const formattedNo = `QT-${String(nextNumber).padStart(6, '0')}`;
        setQuoteNo(formattedNo);
        setValue('quote_number', formattedNo, { shouldValidate: true });
      } catch (err) {
        console.error('Error generating quote number:', err);
        // Fallback to timestamp-based number
        const fallbackNo = `QT-${Date.now().toString().slice(-6)}`;
        setQuoteNo(fallbackNo);
        setValue('quote_number', fallbackNo, { shouldValidate: true });
      }
    };

    generateQuoteNo();
  }, [activeOrganizationId, quoteId, setValue]);

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

        if (error) {
          console.error('Error loading quote:', error);
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Error loading quote',
            message: 'Could not load quote data. Please try again.',
          });
          return;
        }

        if (data) {
          const quoteNumber = (data as any).quote_number || (data as any).quote_no || '';
          setQuoteNo(quoteNumber);
          setValue('quote_number', quoteNumber);
          setValue('customer_id', data.customer_id || '');
          setValue('status', data.status || 'draft');
          setValue('currency', data.currency || 'USD');
          setValue('notes', data.notes || '');
        }
      } catch (err) {
        console.error('Error loading quote data:', err);
      }
    };

    loadQuoteData();
  }, [quoteId, activeOrganizationId, setValue]);

  // Load Customers and Contacts from Supabase
  useEffect(() => {
    const loadCustomersAndContacts = async () => {
      if (!activeOrganizationId) {
        setLoadingCustomers(false);
        return;
      }

      try {
        setLoadingCustomers(true);
        
        // Load Customers
        const { data: customersData, error: customersError } = await supabase
          .from('DirectoryCustomers')
          .select('id, customer_name, primary_contact_id')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .eq('archived', false)
          .order('customer_name', { ascending: true });

        if (customersError) {
          console.error('Error loading customers:', customersError);
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Error loading customers',
            message: customersError.message || 'Could not load customers',
          });
          return;
        }

        // Load Contacts
        const { data: contactsData, error: contactsError } = await supabase
          .from('DirectoryContacts')
          .select('id, contact_name, email, primary_phone, customer_id')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('contact_name', { ascending: true });

        if (contactsError) {
          console.error('Error loading contacts:', contactsError);
          // Continue even if contacts fail
        }

        // Combine customers with their contacts
        const customersWithContacts: CustomerWithContacts[] = (customersData || []).map((customer) => {
          const customerContacts = (contactsData || []).filter(
            (contact: Contact) => contact.customer_id === customer.id
          );
          const primaryContact = customer.primary_contact_id
            ? customerContacts.find((c: Contact) => c.id === customer.primary_contact_id) || null
            : null;

          return {
            id: customer.id,
            customer_name: customer.customer_name,
            primary_contact_id: customer.primary_contact_id,
            contacts: customerContacts,
            primary_contact: primaryContact,
          };
        });

        setCustomers(customersWithContacts);
        setAllContacts(contactsData || []);
      } catch (err) {
        console.error('Error loading customers and contacts:', err);
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error loading data',
          message: err instanceof Error ? err.message : 'Could not load customers and contacts',
        });
      } finally {
        setLoadingCustomers(false);
      }
    };

    loadCustomersAndContacts();
  }, [activeOrganizationId]);

  // Update customer search term when quote is loaded and customers are available
  useEffect(() => {
    if (quoteId && customers.length > 0 && watch('customer_id')) {
      const selectedCustomer = customers.find(c => c.id === watch('customer_id'));
      if (selectedCustomer && !customerSearchTerm) {
        setCustomerSearchTerm(selectedCustomer.customer_name);
      }
    }
  }, [quoteId, customers, watch('customer_id'), customerSearchTerm]);

  // Filter customers and contacts based on search term
  const filteredCustomers = useMemo(() => {
    if (!customerSearchTerm.trim()) return customers;
    const searchLower = customerSearchTerm.toLowerCase().trim();
    return customers.filter(customer => {
      // Search in customer name
      if (customer.customer_name?.toLowerCase().includes(searchLower)) return true;
      
      // Search in primary contact
      if (customer.primary_contact?.contact_name?.toLowerCase().includes(searchLower)) return true;
      if (customer.primary_contact?.email?.toLowerCase().includes(searchLower)) return true;
      if (customer.primary_contact?.primary_phone?.toLowerCase().includes(searchLower)) return true;
      
      // Search in all contacts
      if (customer.contacts?.some(contact => 
        contact.contact_name?.toLowerCase().includes(searchLower) ||
        contact.email?.toLowerCase().includes(searchLower) ||
        contact.primary_phone?.toLowerCase().includes(searchLower)
      )) return true;
      
      return false;
    });
  }, [customers, customerSearchTerm]);

  // Get selected customer info
  const selectedCustomer = useMemo(() => {
    const customerId = watch('customer_id');
    if (!customerId) return null;
    return customers.find(c => c.id === customerId);
  }, [watch('customer_id'), customers]);

  // Get available contacts for selected customer
  const availableContacts = useMemo(() => {
    if (!selectedCustomer) return [];
    return selectedCustomer.contacts || [];
  }, [selectedCustomer]);

  // Reset contact selection when customer changes
  useEffect(() => {
    if (!watch('customer_id')) {
      setSelectedContactId('');
    }
  }, [watch('customer_id')]);

  // Refetch quote lines when quoteId changes
  useEffect(() => {
    if (quoteId) {
      // Lines will be fetched automatically by useQuoteLines hook
    }
  }, [quoteId]);

  // Handle curtain configuration completion
  const handleCurtainConfigComplete = async (config: CurtainConfiguration) => {
    if (!quoteId || !activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Quote must be saved first before adding lines',
      });
      return;
    }

    try {
      // Find or create a catalog item based on configuration
      const sku = `CURTAIN-${config.productType || 'GENERIC'}-${Date.now()}`;
      
      let catalogItemId: string;
      
      // Try to find existing item with similar configuration
      const { data: existingItem } = await supabase
        .from('CatalogItems')
        .select('id, unit_price, cost_price, measure_basis, uom, roll_width_m, fabric_pricing_mode, is_fabric')
        .eq('organization_id', activeOrganizationId)
        .eq('measure_basis', 'area')
        .eq('active', true)
        .eq('deleted', false)
        .limit(1)
        .maybeSingle();

      if (existingItem) {
        catalogItemId = existingItem.id;
      } else {
        // Create a new catalog item for this configuration
        const insertData: any = {
          organization_id: activeOrganizationId,
          sku: sku,
          name: `Curtain - ${config.productType || 'Generic'}`,
          description: `Configured curtain: ${config.productType || 'Generic'}`,
          measure_basis: 'area',
          uom: 'sqm',
          unit_price: 0,
          cost_price: 0,
          is_fabric: false,
          active: true,
        };

        const { data: newItem, error: itemError } = await supabase
          .from('CatalogItems')
          .insert(insertData)
          .select()
          .single();

        if (itemError) {
          console.error('Error creating catalog item:', itemError);
          throw new Error(`Failed to create catalog item: ${itemError.message}`);
        }
        
        if (!newItem) {
          throw new Error('Failed to create catalog item: No data returned');
        }
        
        catalogItemId = newItem.id;
      }

      // Calculate dimensions in meters
      const width_m = config.width_mm ? config.width_mm / 1000 : null;
      const height_m = config.height_mm ? config.height_mm / 1000 : null;

      if (!width_m || !height_m) {
        throw new Error('Width and height are required to create a quote line');
      }

      // Get item details for calculation
      const { data: itemDetails, error: detailsError } = await supabase
        .from('CatalogItems')
        .select('measure_basis, roll_width_m, fabric_pricing_mode, unit_price, cost_price')
        .eq('id', catalogItemId)
        .single();

      if (detailsError) {
        console.error('Error fetching item details:', detailsError);
        throw new Error(`Failed to fetch catalog item details: ${detailsError.message}`);
      }

      if (!itemDetails) {
        throw new Error('Catalog item not found after creation');
      }

      // Calculate computed quantity
      const computedQty = computeComputedQty(
        itemDetails.measure_basis as MeasureBasis,
        1,
        width_m,
        height_m,
        itemDetails.roll_width_m || undefined,
        itemDetails.fabric_pricing_mode || undefined
      );

      const lineTotal = (itemDetails.unit_price || 0) * computedQty;

      // Add accessories to line total
      const accessoriesTotal = config.accessories?.reduce((sum: number, acc: any) => sum + (acc.price * acc.qty), 0) || 0;
      const finalLineTotal = lineTotal + accessoriesTotal;

      // Create QuoteLine
      const { data: newLine, error: lineError } = await supabase
        .from('QuoteLines')
        .insert({
          organization_id: activeOrganizationId,
          quote_id: quoteId,
          catalog_item_id: catalogItemId,
          qty: 1,
          width_m: width_m,
          height_m: height_m,
          measure_basis_snapshot: itemDetails.measure_basis as MeasureBasis,
          roll_width_m_snapshot: itemDetails.roll_width_m || null,
          fabric_pricing_mode_snapshot: itemDetails.fabric_pricing_mode || null,
          computed_qty: computedQty,
          unit_price_snapshot: itemDetails.unit_price || 0,
          unit_cost_snapshot: itemDetails.cost_price || 0,
          line_total: finalLineTotal,
        })
        .select()
        .single();

      if (lineError) {
        console.error('Error creating quote line:', lineError);
        throw new Error(`Failed to create quote line: ${lineError.message}`);
      }

      if (!newLine) {
        throw new Error('Failed to create quote line: No data returned');
      }

      // Update quote totals
      const { data: allLines } = await supabase
        .from('QuoteLines')
        .select('line_total')
        .eq('quote_id', quoteId)
        .eq('deleted', false);

      const currentSubtotal = (allLines || []).reduce((sum, line) => sum + (line.line_total || 0), 0);
      const tax = currentSubtotal * 0.1;
      const total = currentSubtotal + tax;

      await supabase
        .from('Quotes')
        .update({
          totals: {
            subtotal: currentSubtotal,
            tax: tax,
            total: total,
          },
        })
        .eq('id', quoteId)
        .eq('organization_id', activeOrganizationId);

      refetchLines();

      setShowConfigurator(false);
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Line added',
        message: 'Curtain configuration added to quote successfully',
      });
    } catch (error) {
      console.error('Error adding line:', error);
      const errorMessage = error instanceof Error 
        ? error.message 
        : typeof error === 'object' && error !== null && 'message' in error
        ? String(error.message)
        : 'Failed to add line to quote';
      
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: `Failed to add line to quote: ${errorMessage}`,
      });
    }
  };

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      const container = document.querySelector('.customer-search-container');
      if (container && !container.contains(target)) {
        setShowCustomerDropdown(false);
      }
    };

    if (showCustomerDropdown) {
      // Use a small delay to allow click events on dropdown items
      const timeoutId = setTimeout(() => {
        document.addEventListener('mousedown', handleClickOutside);
      }, 100);
      
      return () => {
        clearTimeout(timeoutId);
        document.removeEventListener('mousedown', handleClickOutside);
      };
    }
  }, [showCustomerDropdown]);

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

  const onSubmit = async (values: QuoteFormValues) => {
    if (!activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'No organization selected. Please select an organization.',
      });
      return;
    }

    // Validate form before saving
    const isValid = await trigger();
    if (!isValid) {
      const missingFields: string[] = [];
      
      if (errors.quote_number) missingFields.push('Quote Number');
      if (errors.customer_id) missingFields.push('Customer');
      if (errors.status) missingFields.push('Status');
      if (errors.currency) missingFields.push('Currency');
      
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Missing Required Information',
        message: missingFields.length > 0 
          ? `Please complete the following required fields: ${missingFields.join(', ')}.`
          : 'Please complete all required fields before saving.',
      });
      return;
    }

    setIsSaving(true);
    setSaveError(null);

    try {
      const quoteData: any = {
        quote_number: values.quote_number.trim(),
        customer_id: values.customer_id,
        status: values.status,
        currency: values.currency,
        notes: values.notes?.trim() || null,
        totals: {
          subtotal: 0,
          tax_total: 0,
          total: 0,
        },
      };

      // Check if we have a quoteId - this determines if we're editing or creating
      // Also check URL to be sure
      const path = window.location.pathname;
      const urlMatch = path.match(/\/sales\/quotes\/edit\/([^/]+)/);
      const editQuoteId = urlMatch ? urlMatch[1] : null;
      
      const finalQuoteId = quoteId || editQuoteId;
      
      console.log('Quote submission:', {
        quoteId,
        editQuoteId,
        finalQuoteId,
        path,
        isEdit: !!finalQuoteId
      });
      
      if (finalQuoteId) {
        // Update existing quote
        console.log('Updating quote with ID:', finalQuoteId);
        const updated = await updateQuote(finalQuoteId, quoteData);
        console.log('Quote updated:', updated);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Quote updated',
          message: 'Quote has been updated successfully.',
        });
      } else {
        // Create new quote
        console.log('Creating new quote - no quoteId found');
        const created = await createQuote(quoteData);
        console.log('Quote created:', created);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Quote created',
          message: 'Quote has been created successfully.',
        });
      }

      router.navigate('/sales/quotes');
    } catch (err: any) {
      console.error('Error saving quote:', err);
      setSaveError(err.message || 'Failed to save quote. Please try again.');
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error saving quote',
        message: err.message || 'Failed to save quote. Please try again.',
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
            {quoteId ? 'Edit Quote' : 'New Quote'}
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {quoteId ? 'Edit quote information' : 'Create a new quote'}
          </p>
        </div>
        
        {/* Action Buttons */}
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => router.navigate('/sales/quotes')}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
            title="Close"
          >
            Close
          </button>
          {!isReadOnly && (
            <button
              type="button"
              className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              onClick={handleSubmit(onSubmit)}
              disabled={isSaving}
            >
              {isSaving ? 'Saving...' : 'Save'}
            </button>
          )}
          <button
            type="button"
            className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            style={{ backgroundColor: isReadOnly ? 'var(--primary-brand-hex)' : '#10b981' }}
            onClick={handleSubmit(onSubmit)}
            disabled={isSaving || isReadOnly}
            title={isReadOnly ? 'You only have read permissions' : undefined}
          >
            {isSaving ? 'Saving...' : isReadOnly ? 'Read Only' : 'Save and Close'}
          </button>
        </div>
      </div>

      {saveError && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {saveError}
        </div>
      )}

      {/* Main Content Card */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        {/* Form Body */}
        <div className="py-6 px-6">
          <div className="grid grid-cols-12 gap-x-4 gap-y-4">
            {/* First Row: Quote Number, Customer, Contact, Status */}
            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              {/* Quote Number */}
              <div className="col-span-3">
                <Label htmlFor="quote_number" className="text-xs" required>Quote Number</Label>
                <Input 
                  id="quote_number" 
                  {...register('quote_number')}
                  className="py-1 text-xs"
                  error={errors.quote_number?.message}
                  disabled={isReadOnly}
                  placeholder="QT-000001"
                />
              </div>
              
              {/* Customer */}
              <div className="col-span-4">
                <Label htmlFor="customer_id" className="text-xs" required>Customer</Label>
                <div className="relative customer-search-container">
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                    <input
                      type="text"
                      placeholder={loadingCustomers ? "Loading customers..." : "Search customer or contact..."}
                      value={customerSearchTerm}
                      onChange={(e) => {
                        setCustomerSearchTerm(e.target.value);
                        setShowCustomerDropdown(true);
                      }}
                      onFocus={() => {
                        setShowCustomerDropdown(true);
                      }}
                      onBlur={(e) => {
                        // Don't close if clicking on dropdown
                        const relatedTarget = e.relatedTarget as HTMLElement;
                        if (relatedTarget && relatedTarget.closest('.customer-search-container')) {
                          return;
                        }
                        // Delay closing to allow click on dropdown items
                        setTimeout(() => {
                          setShowCustomerDropdown(false);
                        }, 200);
                      }}
                      className={`w-full pl-10 pr-10 py-1 text-xs border rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-offset-0 ${
                        errors.customer_id 
                          ? 'border-red-300 bg-red-50 focus:ring-red-500/20 focus:border-red-500' 
                          : 'border-gray-200 bg-gray-50 focus:ring-primary/20 focus:border-primary/50'
                      } ${isReadOnly ? 'opacity-50 cursor-not-allowed' : ''}`}
                      disabled={loadingCustomers || isReadOnly}
                    />
                    {watch('customer_id') && (
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          setValue('customer_id', '', { shouldValidate: true });
                          setCustomerSearchTerm('');
                          setShowCustomerDropdown(false);
                        }}
                        className="absolute right-2 top-1/2 transform -translate-y-1/2 p-1 hover:bg-gray-100 rounded"
                        disabled={isReadOnly}
                      >
                        <X className="w-3 h-3 text-gray-400" />
                      </button>
                    )}
                  </div>
                  
                  {/* Customer Dropdown */}
                  {showCustomerDropdown && !loadingCustomers && (
                    <div className="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg max-h-60 overflow-y-auto">
                      {filteredCustomers.length > 0 ? filteredCustomers.map((customer) => (
                        <div key={customer.id}>
                          {/* Customer Option */}
                          <div
                            onMouseDown={(e) => {
                              e.preventDefault(); // Prevent input blur
                            }}
                            onClick={() => {
                              setValue('customer_id', customer.id, { shouldValidate: true });
                              setCustomerSearchTerm(customer.customer_name);
                              setShowCustomerDropdown(false);
                            }}
                            className={`px-3 py-2 hover:bg-gray-50 cursor-pointer border-b border-gray-100 ${
                              watch('customer_id') === customer.id ? 'bg-blue-50' : ''
                            }`}
                          >
                            <div className="flex items-center justify-between">
                              <div className="flex-1">
                                <p className="text-xs font-medium text-gray-900">{customer.customer_name}</p>
                                {customer.primary_contact && (
                                  <p className="text-xs text-gray-500 mt-0.5">
                                    Primary: {customer.primary_contact.contact_name}
                                  </p>
                                )}
                              </div>
                              {watch('customer_id') === customer.id && (
                                <div className="ml-2">
                                  <div className="w-2 h-2 bg-primary rounded-full"></div>
                                </div>
                              )}
                            </div>
                          </div>
                          
                          {/* Show all contacts for this customer */}
                          {customer.contacts && customer.contacts.length > 0 && (
                            <div className="bg-gray-50 pl-6">
                              {customer.contacts.map((contact) => (
                                <div
                                  key={contact.id}
                                  onMouseDown={(e) => {
                                    e.preventDefault(); // Prevent input blur
                                  }}
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    setValue('customer_id', customer.id, { shouldValidate: true });
                                    setCustomerSearchTerm(`${customer.customer_name} - ${contact.contact_name}`);
                                    setShowCustomerDropdown(false);
                                  }}
                                  className="px-3 py-1.5 hover:bg-gray-100 cursor-pointer text-xs"
                                >
                                  <p className="text-gray-700">
                                    <span className="font-medium">{contact.contact_name}</span>
                                  </p>
                                </div>
                              ))}
                            </div>
                          )}
                        </div>
                      )) : (
                        <div className="p-3">
                          <p className="text-xs text-gray-500 text-center">No customers found</p>
                        </div>
                      )}
                    </div>
                  )}
                </div>
                
                
                {errors.customer_id && (
                  <p className="text-xs text-red-600 mt-1">{errors.customer_id.message}</p>
                )}
              </div>
              
              {/* Contact Selector */}
              <div className="col-span-3">
                <Label htmlFor="contact_id" className="text-xs">Contact</Label>
                <SelectShadcn
                  value={selectedContactId}
                  onValueChange={(value) => {
                    setSelectedContactId(value);
                  }}
                  disabled={!selectedCustomer || isReadOnly || availableContacts.length === 0}
                >
                  <SelectTrigger className="py-1 text-xs">
                    <SelectValue placeholder={
                      !selectedCustomer 
                        ? "Select customer first" 
                        : availableContacts.length === 0 
                        ? "No contacts available" 
                        : "Select contact"
                    } />
                  </SelectTrigger>
                  <SelectContent>
                    {availableContacts.map((contact) => (
                      <SelectItem key={contact.id} value={contact.id}>
                        {contact.contact_name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
              </div>
              
              {/* Quote Status - Aligned to right */}
              <div className="col-span-2 flex justify-end">
                <div className="w-full">
                  <Label htmlFor="status" className="text-xs" required>Status</Label>
                  <SelectShadcn
                  value={watch('status') || 'draft'}
                  onValueChange={(value) => {
                    setValue('status', value as 'draft' | 'sent' | 'approved' | 'rejected', { shouldValidate: true });
                  }}
                    disabled={isReadOnly}
                  >
                    <SelectTrigger className={`py-1 text-xs ${errors.status ? 'border-red-300 bg-red-50' : ''}`}>
                      <SelectValue placeholder="Select status" />
                    </SelectTrigger>
                    <SelectContent>
                      {QUOTE_STATUS_OPTIONS.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                          {option.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                  {errors.status && (
                    <p className="text-xs text-red-600 mt-1">{errors.status.message}</p>
                  )}
                </div>
              </div>
            </div>
            
            {/* Second Row: Currency */}
            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              <div className="col-span-3">
                <Label htmlFor="currency" className="text-xs" required>Currency</Label>
                <SelectShadcn
                  value={watch('currency') || 'USD'}
                  onValueChange={(value) => {
                    setValue('currency', value, { shouldValidate: true });
                  }}
                  disabled={isReadOnly}
                >
                  <SelectTrigger className={`py-1 text-xs ${errors.currency ? 'border-red-300 bg-red-50' : ''}`}>
                    <SelectValue placeholder="Select currency" />
                  </SelectTrigger>
                  <SelectContent>
                    {CURRENCY_OPTIONS.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
                {errors.currency && (
                  <p className="text-xs text-red-600 mt-1">{errors.currency.message}</p>
                )}
              </div>
            </div>

            {/* Notes */}
            <div className="col-span-12">
              <Label htmlFor="notes" className="text-xs">Notes</Label>
              <textarea
                id="notes"
                {...register('notes')}
                className="w-full px-2.5 py-1.5 text-xs border border-gray-200 bg-gray-50 rounded-md focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 disabled:opacity-50"
                rows={4}
                disabled={isReadOnly}
                placeholder="Add any additional notes or comments..."
              />
            </div>
          </div>
        </div>
      </div>

      {/* Quote Lines Section */}
      {quoteId && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
          <div className="py-4 px-6 border-b border-gray-200">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-semibold text-foreground">Quote Lines</h2>
                <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
                  {loadingLines ? 'Loading...' : `${quoteLines.length} line${quoteLines.length !== 1 ? 's' : ''}`}
                </p>
              </div>
              {!isReadOnly && (
                <button
                  type="button"
                  onClick={() => setShowConfigurator(true)}
                  className="flex items-center gap-2 px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90"
                  style={{ backgroundColor: 'var(--primary-brand-hex)' }}
                >
                  <Plus style={{ width: '14px', height: '14px' }} />
                  Add Line
                </button>
              )}
            </div>
          </div>

          {loadingLines ? (
            <div className="py-12 text-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
              <p className="text-sm text-gray-600">Loading quote lines...</p>
            </div>
          ) : quoteLines.length === 0 ? (
            <div className="py-12 text-center">
              <p className="text-sm text-gray-600 mb-2">No lines added yet</p>
              <p className="text-xs text-gray-500">Click "Add Line" to configure a curtain</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50 border-b border-gray-200">
                  <tr>
                    <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Item</th>
                    <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Dimensions</th>
                    <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Qty</th>
                    <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Unit Price</th>
                    <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Line Total</th>
                    {!isReadOnly && (
                      <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
                    )}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {quoteLines.map((line) => {
                    const item = (line as any).CatalogItems;
                    return (
                      <tr key={line.id} className="hover:bg-gray-50">
                        <td className="py-4 px-6">
                          <div>
                            <p className="text-sm font-medium text-gray-900">
                              {item?.name || 'Unknown Item'}
                            </p>
                            <p className="text-xs text-gray-500">{item?.sku || 'N/A'}</p>
                          </div>
                        </td>
                        <td className="py-4 px-6 text-sm text-gray-700">
                          {line.width_m && line.height_m
                            ? `${(line.width_m * 1000).toFixed(0)} x ${(line.height_m * 1000).toFixed(0)} mm`
                            : 'N/A'}
                        </td>
                        <td className="py-4 px-6 text-right text-sm text-gray-900">
                          {line.computed_qty.toFixed(2)}
                        </td>
                        <td className="py-4 px-6 text-right text-sm text-gray-700">
                          €{line.unit_price_snapshot.toFixed(2)}
                        </td>
                        <td className="py-4 px-6 text-right text-sm font-medium text-gray-900">
                          €{line.line_total.toFixed(2)}
                        </td>
                        {!isReadOnly && (
                          <td className="py-4 px-6">
                            <div className="flex items-center gap-1 justify-end">
                              <button
                                onClick={() => {
                                  // TODO: Implement edit functionality
                                  useUIStore.getState().addNotification({
                                    type: 'info',
                                    title: 'Coming soon',
                                    message: 'Edit functionality will be available soon',
                                  });
                                }}
                                className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                                title="Edit line"
                              >
                                <Edit className="w-4 h-4" />
                              </button>
                              <button
                                onClick={async () => {
                                  if (!confirm('Are you sure you want to delete this line?')) return;
                                  try {
                                    await supabase
                                      .from('QuoteLines')
                                      .update({ deleted: true })
                                      .eq('id', line.id);
                                    refetchLines();
                                    useUIStore.getState().addNotification({
                                      type: 'success',
                                      title: 'Line deleted',
                                      message: 'Quote line has been removed',
                                    });
                                  } catch (error) {
                                    useUIStore.getState().addNotification({
                                      type: 'error',
                                      title: 'Error',
                                      message: 'Failed to delete line',
                                    });
                                  }
                                }}
                                className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                                title="Delete line"
                              >
                                <Trash2 className="w-4 h-4" />
                              </button>
                            </div>
                          </td>
                        )}
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* Curtain Configurator Modal */}
      {showConfigurator && quoteId && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center">
          <div className="bg-white rounded-lg w-full h-full max-w-7xl m-4 overflow-hidden">
            <CurtainConfigurator
              quoteId={quoteId}
              onComplete={handleCurtainConfigComplete}
              onClose={() => setShowConfigurator(false)}
            />
          </div>
        </div>
      )}
    </div>
  );
}

