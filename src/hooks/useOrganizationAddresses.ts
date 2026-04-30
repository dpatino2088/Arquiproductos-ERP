import { useMemo } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { organizationAddressesListKey } from '../lib/queryKeys';

export interface OrganizationAddress {
  id: string;
  organization_id: string;
  name: string;
  street_address_line_1: string;
  street_address_line_2: string | null;
  city: string | null;
  state: string | null;
  zip_code: string | null;
  country: string | null;
  notes: string | null;
  contact_person: string | null;
  contact_phone: string | null;
  contact_email: string | null;
  is_active: boolean;
  is_default_po_ship_to: boolean;
  deleted: boolean;
  created_at: string;
  updated_at: string;
}

export interface OrganizationAddressInput {
  name: string;
  street_address_line_1: string;
  street_address_line_2?: string;
  city?: string;
  state?: string;
  zip_code?: string;
  country?: string;
  notes?: string;
  contact_person?: string;
  contact_phone?: string;
  contact_email?: string;
  is_active?: boolean;
  is_default_po_ship_to?: boolean;
}

function normalizeInput(input: OrganizationAddressInput): Record<string, unknown> {
  return {
    name: input.name.trim(),
    street_address_line_1: input.street_address_line_1.trim(),
    street_address_line_2: input.street_address_line_2?.trim() || null,
    city: input.city?.trim() || null,
    state: input.state?.trim() || null,
    zip_code: input.zip_code?.trim() || null,
    country: input.country?.trim() || null,
    notes: input.notes?.trim() || null,
    contact_person: input.contact_person?.trim() || null,
    contact_phone: input.contact_phone?.trim() || null,
    contact_email: input.contact_email?.trim() || null,
    is_active: input.is_active ?? true,
    is_default_po_ship_to: input.is_default_po_ship_to ?? false,
  };
}

export function useOrganizationAddresses() {
  const { activeOrganizationId } = useOrganizationContext();
  const queryClient = useQueryClient();
  const scopeKey = activeOrganizationId ?? 'none';

  const listQuery = useQuery({
    queryKey: organizationAddressesListKey(scopeKey),
    queryFn: async (): Promise<OrganizationAddress[]> => {
      if (!activeOrganizationId) {
        return [];
      }
      const { data, error } = await supabase
        .from('OrganizationAddresses')
        .select('*')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('is_default_po_ship_to', { ascending: false })
        .order('name');
      if (error) {
        throw error;
      }
      return (data ?? []) as OrganizationAddress[];
    },
    enabled: !!activeOrganizationId,
  });

  const invalidate = async () => {
    await queryClient.invalidateQueries({ queryKey: organizationAddressesListKey(scopeKey) });
  };

  const createMutation = useMutation({
    mutationFn: async (input: OrganizationAddressInput) => {
      if (!activeOrganizationId) {
        throw new Error('No organization selected');
      }
      const payload = {
        ...normalizeInput(input),
        organization_id: activeOrganizationId,
      };
      const { data, error } = await supabase
        .from('OrganizationAddresses')
        .insert(payload)
        .select('*')
        .single();
      if (error) {
        throw error;
      }
      return data as OrganizationAddress;
    },
    onSuccess: invalidate,
  });

  const updateMutation = useMutation({
    mutationFn: async (params: { id: string; input: OrganizationAddressInput }) => {
      if (!activeOrganizationId) {
        throw new Error('No organization selected');
      }
      const { data, error } = await supabase
        .from('OrganizationAddresses')
        .update(normalizeInput(params.input))
        .eq('id', params.id)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .select('*')
        .single();
      if (error) {
        throw error;
      }
      return data as OrganizationAddress;
    },
    onSuccess: invalidate,
  });

  const archiveMutation = useMutation({
    mutationFn: async (id: string) => {
      if (!activeOrganizationId) {
        throw new Error('No organization selected');
      }
      const { error } = await supabase
        .from('OrganizationAddresses')
        .update({ deleted: true, is_default_po_ship_to: false })
        .eq('id', id)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false);
      if (error) {
        throw error;
      }
    },
    onSuccess: invalidate,
  });

  return useMemo(() => ({
    addresses: listQuery.data ?? [],
    isLoading: listQuery.isLoading,
    error: listQuery.error ? (listQuery.error as Error).message : null,
    refetch: listQuery.refetch,
    createAddress: createMutation.mutateAsync,
    updateAddress: updateMutation.mutateAsync,
    archiveAddress: archiveMutation.mutateAsync,
    isSaving: createMutation.isPending || updateMutation.isPending || archiveMutation.isPending,
  }), [
    listQuery.data,
    listQuery.isLoading,
    listQuery.error,
    listQuery.refetch,
    createMutation.mutateAsync,
    updateMutation.mutateAsync,
    archiveMutation.mutateAsync,
    createMutation.isPending,
    updateMutation.isPending,
    archiveMutation.isPending,
  ]);
}
