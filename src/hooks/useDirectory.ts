import { useState, useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

// Hook para obtener contactos
export function useContacts() {
  const [contacts, setContacts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
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

        // Step 1: Fetch all contacts
        const { data: contactsData, error: contactsError } = await supabase
          .from('DirectoryContacts')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: false });

        if (contactsError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching Contacts:', contactsError);
          }
          throw contactsError;
        }

        // Step 2: Get all unique customer IDs (filter out nulls)
        const customerIds = [...new Set(
          (contactsData || [])
            .map((c: any) => c.customer_id)
            .filter((id: any) => id !== null && id !== undefined)
        )];

        // Step 3: Fetch customers in batch if there are any
        let customersMap = new Map<string, string>();
        if (customerIds.length > 0) {
          const { data: customersData, error: customersError } = await supabase
            .from('DirectoryCustomers')
            .select('id, customer_name')
            .in('id', customerIds)
            .eq('deleted', false);

          if (customersError) {
            if (import.meta.env.DEV) {
              console.error('Error fetching Customers for Contacts:', customersError);
            }
            // Don't throw, just log - we can still show contacts without customer names
          } else if (customersData) {
            // Create a map for quick lookup
            customersMap = new Map(
              customersData.map((c: any) => [c.id, c.customer_name || ''])
            );
          }
        }

        // Step 4: Transform data with manual customer mapping
        const transformedContacts = (contactsData || []).map((contact: any) => {
          // Get customer name from map
          const customerName = contact.customer_id 
            ? (customersMap.get(contact.customer_id) || '') 
            : '';

          return {
            id: contact.id,
            firstName: contact.contact_name || '',
            lastName: '',
            email: contact.email || '',
            company: customerName, // Customer name from manual mapping
            customer_id: contact.customer_id || null,
            category: contact.contact_type 
              ? contact.contact_type.replace('_', ' ').replace(/\b\w/g, (l: string) => l.toUpperCase()) 
              : 'Architect',
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
          };
        });

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
  }, [activeOrganizationId, refreshTrigger]);

  return {
    data: contacts,
    contacts, // Alias for backward compatibility
    error,
    isLoading: loading,
    loading, // Alias for backward compatibility
    isError: !!error,
    refetch: () => {
      // Trigger re-fetch by incrementing refresh trigger
      setRefreshTrigger(prev => prev + 1);
    },
  };
}

// Hook para obtener customers
export function useCustomers() {
  const [customers, setCustomers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
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

        console.log('🔍 useCustomers - Iniciando fetch:', {
          activeOrganizationId,
          hasOrgId: !!activeOrganizationId
        });

        const { data, error: queryError } = await supabase
          .from('DirectoryCustomers')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: false });

        console.log('📊 useCustomers - Resultado query:', {
          dataCount: data?.length || 0,
          error: queryError,
          rawData: data,
          firstCustomer: data?.[0] ? {
            id: data[0].id,
            customer_name: data[0].customer_name,
            organization_id: data[0].organization_id
          } : null
        });

        if (queryError) {
          console.error('❌ Error fetching Customers:', {
            error: queryError,
            code: queryError.code,
            message: queryError.message,
            details: queryError.details
          });
          throw queryError;
        }

        // Get all primary contact IDs and customer type IDs
        const primaryContactIds = (data || [])
          .map((customer: any) => customer.primary_contact_id)
          .filter(Boolean);
        
        // Fetch all primary contacts in one query
        let contactsMap: Record<string, string> = {};
        if (primaryContactIds.length > 0) {
          try {
            const { data: contactsData } = await supabase
              .from('DirectoryContacts')
              .select('id, contact_name')
              .in('id', primaryContactIds)
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false);

            if (contactsData) {
              contactsMap = contactsData.reduce((acc: Record<string, string>, contact: any) => {
                acc[contact.id] = contact.contact_name || '';
                return acc;
              }, {});
            }
          } catch (err) {
            // Silently fail if contact fetch fails
            if (import.meta.env.DEV) {
              console.warn('Could not fetch primary contacts:', err);
            }
          }
        }

        // Transform data to match frontend interface
        // Note: We already filter by deleted = false in the query, so all customers here are active
        const transformedCustomers = (data || []).map((customer: any) => ({
          id: customer.id,
          companyName: customer.customer_name || '',
          contactName: customer.primary_contact_id ? (contactsMap[customer.primary_contact_id] || '') : '',
          email: customer.email || '',
          phone: customer.company_phone || '',
          customerType: customer.customer_type_name || 'N/A',
          status: customer.archived ? 'Archived' : 'Active' as 'Active' | 'On Hold' | 'Archived',
          location: [customer.city, customer.state, customer.country].filter(Boolean).join(', ') || 'N/A',
          dateAdded: customer.created_at ? new Date(customer.created_at).toISOString().split('T')[0] : '',
          totalRevenue: 0, // Not in schema yet
          // Include deleted flag for filtering (though it should always be false here)
          deleted: customer.deleted || false,
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
  }, [activeOrganizationId, refreshTrigger]);

  return {
    data: customers,
    customers, // Alias for backward compatibility
    error,
    isLoading: loading,
    loading, // Alias for backward compatibility
    isError: !!error,
    refetch: () => {
      setRefreshTrigger(prev => prev + 1);
    },
  };
}

// Hook para obtener vendors
export function useVendors() {
  const [vendors, setVendors] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
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
          vendorName: vendor.vendor_name || '',
          vendorId: vendor.identification_number || '',
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
  }, [activeOrganizationId, refreshTrigger]);

  return {
    data: vendors,
    vendors, // Alias for backward compatibility
    error,
    isLoading: loading,
    loading, // Alias for backward compatibility
    isError: !!error,
    refetch: () => {
      setRefreshTrigger(prev => prev + 1);
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

// Hook para borrar un contacto (soft delete)
export function useDeleteContact() {
  const { activeOrganizationId } = useOrganizationContext();
  const [isDeleting, setIsDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const deleteContact = async (contactId: string) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsDeleting(true);
    setError(null);

    try {
      const { error: deleteError } = await supabase
        .from('DirectoryContacts')
        .update({ deleted: true })
        .eq('id', contactId)
        .eq('organization_id', activeOrganizationId);

      if (deleteError) {
        throw deleteError;
      }

      return { success: true };
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Error deleting contact';
      setError(errorMessage);
      throw err;
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    deleteContact,
    isDeleting,
    error,
  };
}

// Hook para borrar un customer (soft delete)
export function useDeleteCustomer() {
  const { activeOrganizationId } = useOrganizationContext();
  const [isDeleting, setIsDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const deleteCustomer = async (customerId: string) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsDeleting(true);
    setError(null);

    try {
      // Verificar si hay contactos asociados
      const { data: contacts, error: checkError } = await supabase
        .from('DirectoryContacts')
        .select('id')
        .eq('customer_id', customerId)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .limit(1);

      if (checkError) {
        throw checkError;
      }

      if (contacts && contacts.length > 0) {
        throw new Error('Cannot delete customer with associated contacts. Please delete or reassign contacts first.');
      }

      const { error: deleteError } = await supabase
        .from('DirectoryCustomers')
        .update({ deleted: true })
        .eq('id', customerId)
        .eq('organization_id', activeOrganizationId);

      if (deleteError) {
        throw deleteError;
      }

      return { success: true };
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Error deleting customer';
      setError(errorMessage);
      throw err;
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    deleteCustomer,
    isDeleting,
    error,
  };
}

// Hook para borrar un vendor (soft delete)
export function useDeleteVendor() {
  const { activeOrganizationId } = useOrganizationContext();
  const [isDeleting, setIsDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const deleteVendor = async (vendorId: string) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsDeleting(true);
    setError(null);

    try {
      const { error: deleteError } = await supabase
        .from('DirectoryVendors')
        .update({ deleted: true })
        .eq('id', vendorId)
        .eq('organization_id', activeOrganizationId);

      if (deleteError) {
        throw deleteError;
      }

      return { success: true };
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Error deleting vendor';
      setError(errorMessage);
      throw err;
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    deleteVendor,
    isDeleting,
    error,
  };
}

