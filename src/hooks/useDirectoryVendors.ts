import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { vendorsListKey } from '../lib/queryKeys';

export interface DirectoryVendor {
  id: string;
  organization_id: string;
  name: string;
  vendor_name?: string | null;
  ein?: string | null;
  website?: string | null;
  email?: string | null;
  work_phone?: string | null;
  fax?: string | null;
  street_address_line_1?: string | null;
  street_address_line_2?: string | null;
  city?: string | null;
  state?: string | null;
  zip_code?: string | null;
  country?: string | null;
  billing_street_address_line_1?: string | null;
  billing_street_address_line_2?: string | null;
  billing_city?: string | null;
  billing_state?: string | null;
  billing_zip_code?: string | null;
  billing_country?: string | null;
  notes?: string | null;
  primary_contact_id?: string | null;
  primary_contact_name?: string | null;
  contact_email?: string | null;
  contact_phone?: string | null;
  payment_terms?: string | null;
  delivery_terms?: string | null;
  transport?: string | null;
  tax_rule?: 'taxable' | 'tax_exempt' | null;
  manufacturer_id?: string | null;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at: string;
}

export interface VendorInput {
  name: string;
  vendor_name?: string;
  ein?: string;
  website?: string;
  email?: string;
  work_phone?: string;
  fax?: string;
  street_address_line_1?: string;
  street_address_line_2?: string;
  city?: string;
  state?: string;
  zip_code?: string;
  country?: string;
  billing_street_address_line_1?: string;
  billing_street_address_line_2?: string;
  billing_city?: string;
  billing_state?: string;
  billing_zip_code?: string;
  billing_country?: string;
  notes?: string;
  primary_contact_name?: string;
  contact_email?: string;
  contact_phone?: string;
  payment_terms?: string;
  delivery_terms?: string;
  transport?: string;
  tax_rule?: 'taxable' | 'tax_exempt';
  manufacturer_id?: string | null;
}

export function useDirectoryVendors() {
  const { activeOrganizationId } = useOrganizationContext();
  const queryClient = useQueryClient();
  const scopeKey = activeOrganizationId ?? 'none';

  const {
    data: vendors = [],
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: vendorsListKey(scopeKey),
    queryFn: async () => {
      if (!activeOrganizationId) return [];
      const { data, error } = await supabase
        .from('DirectoryVendors')
        .select('*')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('name', { ascending: true });
      if (error) throw error;
      return (data ?? []) as DirectoryVendor[];
    },
    enabled: !!activeOrganizationId,
  });

  const createVendor = useMutation({
    mutationFn: async (input: VendorInput) => {
      if (!activeOrganizationId) throw new Error('No organization selected');
      const { data, error } = await supabase
        .from('DirectoryVendors')
        .insert({ ...input, organization_id: activeOrganizationId })
        .select()
        .single();
      if (error) {
        const msg = String((error as { message?: string }).message ?? '').toLowerCase();
        const missingTaxRule = msg.includes('tax_rule');
        if (!missingTaxRule) throw error;
        const { tax_rule: _taxRule, ...fallbackInput } = input as VendorInput & { tax_rule?: 'taxable' | 'tax_exempt' };
        const fallback = await supabase
          .from('DirectoryVendors')
          .insert({ ...fallbackInput, organization_id: activeOrganizationId })
          .select()
          .single();
        if (fallback.error) throw fallback.error;
        return fallback.data as DirectoryVendor;
      }
      return data as DirectoryVendor;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: vendorsListKey(scopeKey) });
    },
  });

  const updateVendor = useMutation({
    mutationFn: async ({ id, ...input }: VendorInput & { id: string }) => {
      const { data, error } = await supabase
        .from('DirectoryVendors')
        .update({ ...input, updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single();
      if (error) {
        const msg = String((error as { message?: string }).message ?? '').toLowerCase();
        const missingTaxRule = msg.includes('tax_rule');
        if (!missingTaxRule) throw error;
        const { tax_rule: _taxRule, ...fallbackInput } = input as VendorInput & { tax_rule?: 'taxable' | 'tax_exempt' };
        const fallback = await supabase
          .from('DirectoryVendors')
          .update({ ...fallbackInput, updated_at: new Date().toISOString() })
          .eq('id', id)
          .select()
          .single();
        if (fallback.error) throw fallback.error;
        return fallback.data as DirectoryVendor;
      }
      return data as DirectoryVendor;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: vendorsListKey(scopeKey) });
    },
  });

  const deleteVendor = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase
        .from('DirectoryVendors')
        .update({ deleted: true, updated_at: new Date().toISOString() })
        .eq('id', id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: vendorsListKey(scopeKey) });
    },
  });

  return {
    vendors,
    isLoading,
    error,
    refetch,
    createVendor,
    updateVendor,
    deleteVendor,
  };
}
