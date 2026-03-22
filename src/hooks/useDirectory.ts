import { useState } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

// Hook para borrar un contacto (soft delete vía RPC para Dealer; fallback a UPDATE)
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
      const { data, error: rpcError } = await supabase.rpc('soft_delete_directory_contact', {
        p_contact_id: contactId,
      });
      if (rpcError) {
        if (rpcError.code === '42883') {
          const { error: updateError } = await supabase
            .from('DirectoryContacts')
            .update({ deleted: true })
            .eq('id', contactId)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false);
          if (updateError) throw updateError;
        } else throw rpcError;
      } else if (data !== 1 && data != null) {
        throw new Error('Contact not found or no permission to delete');
      }

      return { success: true };
    } catch (err: any) {
      const errorMessage = err?.message ?? 'Error deleting contact';
      setError(errorMessage);
      throw err instanceof Error ? err : new Error(errorMessage);
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

// Hook para borrar un customer (soft delete vía RPC para Dealer; fallback a UPDATE)
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

      const { data, error: rpcError } = await supabase.rpc('soft_delete_directory_customer', {
        p_customer_id: customerId,
      });
      if (rpcError) {
        if (rpcError.code === '42883') {
          const { error: updateError } = await supabase
            .from('DirectoryCustomers')
            .update({ deleted: true })
            .eq('id', customerId)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false);
          if (updateError) throw updateError;
        } else throw rpcError;
      } else if (data !== 1 && data != null) {
        throw new Error('Customer not found or no permission to delete');
      }

      return { success: true };
    } catch (err: any) {
      const errorMessage = err?.message ?? 'Error deleting customer';
      setError(errorMessage);
      throw err instanceof Error ? err : new Error(errorMessage);
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


