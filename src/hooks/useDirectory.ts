import { useState, useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

// Hook para obtener contactos
export function useContacts() {
  const [contacts, setContacts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    async function fetchContacts() {
      if (!activeOrganizationId) {
        setLoading(false);
        setContacts([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('DirectoryContacts')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .order('created_at', { ascending: false });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching Contacts:', queryError);
          }
          throw queryError;
        }

        // Transform data to match frontend interface
        const transformedContacts = (data || []).map((contact) => ({
          id: contact.id,
          firstName: contact.customer_name || '',
          lastName: '',
          email: contact.email || '',
          company: '', // Will be populated from join if needed
          company_id: contact.company_id || null,
          category: contact.contact_type ? contact.contact_type.replace('_', ' ').replace(/\b\w/g, (l: string) => l.toUpperCase()) : 'Architect',
          status: contact.archived ? 'Archived' : 'Active' as 'Active' | 'Inactive' | 'Archived',
          location: [contact.city, contact.state, contact.country].filter(Boolean).join(', ') || 'N/A',
          dateAdded: contact.created_at || '',
          phone: contact.primary_phone || contact.cell_phone || '',
          contactType: 'Business' as 'Business' | 'Personal' | 'Vendor' | 'Customer',
          // Additional fields for table display
          primary_phone: contact.primary_phone || '',
          city: contact.city || '',
          country: contact.country || '',
          contact_type: contact.contact_type || 'architect',
          created_at: contact.created_at || '',
        }));

        setContacts(transformedContacts);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading contacts';
        if (import.meta.env.DEV) {
          console.error('Error fetching Contacts:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchContacts();
  }, [activeOrganizationId]);

  return {
    data: contacts,
    contacts, // Alias for backward compatibility
    error,
    isLoading: loading,
    loading, // Alias for backward compatibility
    isError: !!error,
    refetch: () => {
      // Trigger re-fetch by setting loading state
      setLoading(true);
    },
  };
}

// Hook para obtener customers
export function useCustomers() {
  const [customers, setCustomers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    async function fetchCustomers() {
      if (!activeOrganizationId) {
        setLoading(false);
        setCustomers([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('DirectoryCustomers')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .order('created_at', { ascending: false });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching Customers:', queryError);
          }
          throw queryError;
        }

        // Transform data to match frontend interface
        const transformedCustomers = (data || []).map((customer) => ({
          id: customer.id,
          companyName: customer.company_name || '',
          contactName: '',
          email: customer.email || '',
          phone: customer.company_phone || '',
          industry: 'N/A', // Not in schema yet
          customerType: 'Customer',
          status: customer.archived ? 'Archived' : 'Active' as 'Active' | 'On Hold' | 'Archived',
          location: [customer.city, customer.state, customer.country].filter(Boolean).join(', ') || 'N/A',
          dateAdded: customer.created_at ? new Date(customer.created_at).toISOString().split('T')[0] : '',
          totalRevenue: 0, // Not in schema yet
        }));

        setCustomers(transformedCustomers);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading customers';
        if (import.meta.env.DEV) {
          console.error('Error fetching Customers:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchCustomers();
  }, [activeOrganizationId]);

  return {
    data: customers,
    customers, // Alias for backward compatibility
    error,
    isLoading: loading,
    loading, // Alias for backward compatibility
    isError: !!error,
    refetch: () => {
      setLoading(true);
    },
  };
}

// Hook para obtener vendors
export function useVendors() {
  const [vendors, setVendors] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    async function fetchVendors() {
      if (!activeOrganizationId) {
        setLoading(false);
        setVendors([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('DirectoryVendors')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: false });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('[useDirectory] Error fetching vendors from DirectoryVendors:', queryError);
          }
          throw queryError;
        }

        // Transform data to match frontend interface
        const transformedVendors = (data || []).map((vendor) => ({
          id: vendor.id,
          vendorName: vendor.name || vendor.vendor_name || '',
          vendorId: vendor.ein || '',
          phone: vendor.work_phone || '',
          email: vendor.email || '',
          country: vendor.country || '',
          currency: 'USD', // Not in schema yet
          status: vendor.archived ? 'Archived' : 'Active' as 'Active' | 'Inactive' | 'Archived',
          dateAdded: vendor.created_at ? new Date(vendor.created_at).toISOString().split('T')[0] : '',
          vendorType: '',
        }));

        setVendors(transformedVendors);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading vendors';
        if (import.meta.env.DEV) {
          console.error('[useDirectory] Error fetching vendors from DirectoryVendors:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchVendors();
  }, [activeOrganizationId]);

  return {
    data: vendors,
    vendors, // Alias for backward compatibility
    error,
    isLoading: loading,
    loading, // Alias for backward compatibility
    isError: !!error,
    refetch: () => {
      setLoading(true);
    },
  };
}


// Hook para obtener un vendor por ID
export function useVendorById(options: { id?: string | null; organizationId?: string | null }) {
  const { id, organizationId } = options;
  const enabled = Boolean(id && organizationId);

  const query = useQuery({
    queryKey: ['directory-vendor', { organizationId, id }],
    enabled,
    queryFn: async () => {
      if (!id || !organizationId) return null;

      const { data, error } = await supabase
        .from('DirectoryVendors')
        .select('*')
        .eq('id', id)
        .eq('organization_id', organizationId)
        .maybeSingle();

      if (error) {
        if (import.meta.env.DEV) {
          console.error('[useDirectory] Error fetching vendor by id from DirectoryVendors:', error);
        }
        throw error;
      }

      return data;
    },
  });

  return {
    vendor: query.data,
    ...query,
  };
}

