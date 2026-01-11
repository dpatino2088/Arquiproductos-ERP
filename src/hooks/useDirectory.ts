import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

// Hook para obtener contactos
export function useContacts() {
  const [contacts, setContacts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = useCallback(() => {
    setRefreshTrigger(prev => prev + 1);
  }, []);

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

        // Query: usar columnas EXPLÍCITAS con fallback a genéricas (transición)
        const { data: contactsData, error: contactsError } = await supabase
          .from('DirectoryContacts')
          .select('id, organization_id, customer_id, contact_name, name, contact_email, email, contact_phone, phone, deleted, created_at, updated_at')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: false });

        if (contactsError) {
          console.error('[useContacts] Error fetching Contacts:', contactsError);
          throw contactsError;
        }

        // Get all unique customer IDs (filter out nulls)
        const customerIds = [...new Set(
          (contactsData || [])
            .map((c: any) => c.customer_id)
            .filter((id: any) => id !== null && id !== undefined)
        )];

        // Fetch customers in batch if there are any
        // Usar columnas EXPLÍCITAS con fallback a genéricas para transición
        let customersMap = new Map<string, string>();
        if (customerIds.length > 0) {
          const { data: customersData, error: customersError } = await supabase
            .from('DirectoryCustomers')
            .select('id, customer_name, name')  // Leer ambas: explícita y genérica
            .in('id', customerIds)
            .eq('deleted', false);

          if (customersError) {
            console.warn('[useContacts] Error fetching Customers for Contacts:', customersError);
            // Don't throw, just log - we can still show contacts without customer names
          } else if (customersData) {
            customersMap = new Map(
              customersData.map((c: any) => [
                c.id, 
                (c.customer_name || c.name || '').toString().trim()  // Preferir explícita, fallback a genérica
              ])
            );
          }
        }

        // Transform data with manual customer mapping
        // Schema: DirectoryContacts tiene columnas EXPLÍCITAS (contact_name, contact_email, contact_phone)
        // Con fallback a genéricas (name, email, phone) para transición
        const transformedContacts = (contactsData || []).map((contact: any) => {
          const customerName = contact.customer_id 
            ? (customersMap.get(contact.customer_id) || '') 
            : '';

          // Usar columnas EXPLÍCITAS con fallback a genéricas
          const contactName = (contact.contact_name || contact.name || '').toString().trim();
          const contactEmail = (contact.contact_email || contact.email || '').toString().trim();
          const contactPhone = (contact.contact_phone || contact.phone || '').toString().trim();

          return {
            id: contact.id,
            firstName: contactName,
            lastName: '',
            email: contactEmail,
            company: customerName,
            customer_id: contact.customer_id || null,
            category: 'Contact', // Default category
            status: contact.deleted ? 'Archived' : 'Active' as 'Active' | 'Inactive' | 'Archived',
            location: '', // No location fields in base schema
            dateAdded: contact.created_at || '',
            phone: contactPhone,
            contactType: 'Business' as 'Business' | 'Personal' | 'Vendor' | 'Customer',
            primary_phone: contactPhone,
            city: '',
            country: '',
            contact_type: 'contact',
            created_at: contact.created_at || '',
          };
        });

        setContacts(transformedContacts);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading contacts';
        console.error('[useContacts] Error:', errorMessage);
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchContacts();
  }, [activeOrganizationId, refreshTrigger]);

  return {
    data: contacts,
    contacts,
    error,
    isLoading: loading,
    loading,
    isError: !!error,
    refetch,
  };
}

// Hook para obtener customers
export function useCustomers() {
  const [customers, setCustomers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = useCallback(() => {
    setRefreshTrigger(prev => prev + 1);
  }, []);

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

        // Query simplificada: solo campos básicos
        const { data, error: queryError } = await supabase
          .from('DirectoryCustomers')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: false });

        if (queryError) {
          console.error('[useCustomers] Error fetching Customers:', queryError);
          throw queryError;
        }

        if (!data || data.length === 0) {
          setCustomers([]);
          return;
        }

        // Get all primary contact IDs
        const primaryContactIds = [...new Set(
          data
            .map((customer: any) => customer.primary_contact_id)
            .filter((id: any): id is string => !!id)
        )];
        
        // Fetch all primary contacts in one query (separate to avoid JOIN issues)
        let contactsMap: Record<string, string> = {};
        if (primaryContactIds.length > 0) {
          try {
            // Usar columnas EXPLÍCITAS con fallback a genéricas
            const { data: contactsData, error: contactsError } = await supabase
              .from('DirectoryContacts')
              .select('id, contact_name, name')  // Leer ambas: explícita y genérica
              .in('id', primaryContactIds)
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false);

            if (contactsError) {
              console.warn('[useCustomers] Error fetching primary contacts:', contactsError);
            } else if (contactsData) {
              contactsMap = contactsData.reduce((acc: Record<string, string>, contact: any) => {
                // Preferir explícita, fallback a genérica
                acc[contact.id] = (contact.contact_name || contact.name || '').toString().trim();
                return acc;
              }, {});
            }
          } catch (err) {
            // Silently fail if contact fetch fails - customers can still be displayed
            if (import.meta.env.DEV) {
              console.warn('[useCustomers] Could not fetch primary contacts:', err);
            }
          }
        }

        // Transform data to match frontend interface
        // Schema: DirectoryCustomers tiene columnas EXPLÍCITAS (customer_name, customer_email, customer_phone)
        // Con fallback a genéricas (name) para transición
        const transformedCustomers = data.map((customer: any) => {
          // Usar columnas EXPLÍCITAS con fallback a genéricas
          const customerName = (customer.customer_name || customer.name || '').toString().trim();
          const customerEmail = (customer.customer_email || '').toString().trim();
          const customerPhone = (customer.customer_phone || '').toString().trim();

          return {
          id: customer.id,
            companyName: customerName,
            contactName: '', // No primary_contact_id in base schema - can be added later if needed
            email: customerEmail, // Ahora disponible desde customer_email
            phone: customerPhone, // Ahora disponible desde customer_phone
            customerType: customer.status || 'Active',
            status: customer.deleted ? 'Archived' : (customer.status || 'Active') as 'Active' | 'On Hold' | 'Archived',
            location: '', // No location fields in base schema
          dateAdded: customer.created_at ? new Date(customer.created_at).toISOString().split('T')[0] : '',
          totalRevenue: 0, // Not in schema yet
          deleted: customer.deleted || false,
          };
        });

        if (import.meta.env.DEV) {
          console.log('[useCustomers] Transformed customers:', {
            count: transformedCustomers.length,
            sample: transformedCustomers[0] || null
          });
        }

        setCustomers(transformedCustomers);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading customers';
        console.error('[useCustomers] Error:', errorMessage, err);
        setError(errorMessage);
        setCustomers([]);
      } finally {
        setLoading(false);
      }
    }

    fetchCustomers();
  }, [activeOrganizationId, refreshTrigger]);

  return {
    data: customers,
    customers,
    error,
    isLoading: loading,
    loading,
    isError: !!error,
    refetch,
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


