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
import { useCreateQuote, useUpdateQuote, useQuotes } from '../../hooks/useQuotes';
import { QuoteStatus } from '../../types/catalog';
import { Search, X } from 'lucide-react';

// Quote status options
const QUOTE_STATUS_OPTIONS = [
  { value: 'draft', label: 'Draft' },
  { value: 'sent', label: 'Sent' },
  { value: 'approved', label: 'Approved' },
  { value: 'rejected', label: 'Rejected' },
  { value: 'cancelled', label: 'Cancelled' },
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
  status: z.enum(['draft', 'sent', 'approved', 'rejected', 'cancelled']),
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
  const { activeOrganizationId } = useOrganizationContext();
  const { createQuote, isCreating } = useCreateQuote();
  const { updateQuote, isUpdating } = useUpdateQuote();
  const { quotes } = useQuotes();
  
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

  // Generate quote number
  useEffect(() => {
    const generateQuoteNo = async () => {
      if (!activeOrganizationId || quoteId) return; // Don't generate if editing

      try {
        // Get the last quote number for this organization
        const { data, error } = await supabase
          .from('Quotes')
          .select('quote_no')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: false })
          .limit(1);

        if (error && error.code !== 'PGRST116') {
          console.error('Error fetching last quote:', error);
        }

        let nextNumber = 1;
        if (data && data.length > 0) {
          // Extract number from quote_no (assuming format like "QT-000001" or "000001")
          const lastQuoteNo = data[0].quote_no;
          const match = lastQuoteNo.match(/\d+/);
          if (match) {
            nextNumber = parseInt(match[0], 10) + 1;
          }
        }

        // Format as QT-000001, QT-000002, etc.
        const formattedNo = `QT-${String(nextNumber).padStart(6, '0')}`;
        setQuoteNo(formattedNo);
        setValue('quote_no', formattedNo, { shouldValidate: true });
      } catch (err) {
        console.error('Error generating quote number:', err);
        // Fallback to timestamp-based number
        const fallbackNo = `QT-${Date.now().toString().slice(-6)}`;
        setQuoteNo(fallbackNo);
        setValue('quote_no', fallbackNo, { shouldValidate: true });
      }
    };

    generateQuoteNo();
  }, [activeOrganizationId, quoteId, setValue]);

  // Get quote ID from URL if in edit mode
  useEffect(() => {
    const path = window.location.pathname;
    const match = path.match(/\/sales\/quotes\/edit\/([^/]+)/);
    if (match && match[1]) {
      setQuoteId(match[1]);
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
          setQuoteNo(data.quote_no);
          setValue('quote_no', data.quote_no || '');
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
      
      if (errors.quote_no) missingFields.push('Quote Number');
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
        quote_no: values.quote_no.trim(),
        customer_id: values.customer_id,
        status: values.status,
        currency: values.currency,
        notes: values.notes?.trim() || null,
        totals: {
          subtotal: 0,
          tax: 0,
          total: 0,
        },
      };

      if (quoteId) {
        // Update existing quote
        await updateQuote(quoteId, quoteData);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Quote updated',
          message: 'Quote has been updated successfully.',
        });
      } else {
        // Create new quote
        await createQuote(quoteData);
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
                <Label htmlFor="quote_no" className="text-xs" required>Quote Number</Label>
                <Input 
                  id="quote_no" 
                  {...register('quote_no')}
                  className="py-1 text-xs"
                  error={errors.quote_no?.message}
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
                      setValue('status', value as QuoteStatus, { shouldValidate: true });
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
    </div>
  );
}

