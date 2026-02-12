import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

/**
 * Dealer shape canónico para UI (antes Company)
 */
export interface Dealer {
  id: string;
  organization_id: string;
  dealer_no: string | null;
  dealer_name: string;
  dealer_email: string | null;
  dealer_phone: string | null;
  dealer_tier_id: string | null;
  status: string;
  deleted: boolean;
  created_at?: string;
  updated_at?: string;
}

/**
 * Input para crear Dealer
 */
export interface CreateDealerInput {
  dealer_name: string;
  dealer_email?: string;
  dealer_phone?: string;
  dealer_tier_id?: string | null;
  status?: string;
  identification_number?: string;
  website?: string;
  alt_phone?: string;
  primary_contact_id?: string;
  primary_contact_app_user_id?: string | null;
  street_address_line_1?: string;
  street_address_line_2?: string;
  city?: string;
  state?: string;
  zip_code?: string;
  country?: string;
  billing_same_as_location?: boolean;
  billing_street_address_line_1?: string;
  billing_street_address_line_2?: string;
  billing_city?: string;
  billing_state?: string;
  billing_zip_code?: string;
  billing_country?: string;
  notes?: string;
  logo_url?: string | null;
  primary_contact_app_user_id?: string | null;
}

/**
 * Input para actualizar Dealer
 */
export interface UpdateDealerInput {
  dealer_name?: string;
  dealer_email?: string;
  dealer_phone?: string;
  dealer_tier_id?: string | null;
  status?: string;
  identification_number?: string;
  website?: string;
  alt_phone?: string;
  primary_contact_id?: string;
  primary_contact_app_user_id?: string | null;
  street_address_line_1?: string;
  street_address_line_2?: string;
  city?: string;
  state?: string;
  zip_code?: string;
  country?: string;
  billing_same_as_location?: boolean;
  billing_street_address_line_1?: string;
  billing_street_address_line_2?: string;
  billing_city?: string;
  billing_state?: string;
  billing_zip_code?: string;
  billing_country?: string;
  notes?: string;
  logo_url?: string | null;
}

/**
 * Hook para gestionar Dealers (antes Companies)
 */
export function useDealers() {
  const [dealers, setDealers] = useState<Dealer[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  const fetchDealers = useCallback(async () => {
    if (!activeOrganizationId) {
      setDealers([]);
      setIsLoading(false);
      setError(null);
      return;
    }

    try {
      setIsLoading(true);
      setError(null);

      const { data, error: queryError } = await supabase
        .from('Dealers')
        .select('id, organization_id, dealer_no, dealer_name, dealer_email, dealer_phone, dealer_tier_id, status, deleted, created_at, updated_at, identification_number, website, alt_phone, primary_contact_id, street_address_line_1, street_address_line_2, city, state, zip_code, country, billing_same_as_location, billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country, notes')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('created_at', { ascending: false });

      if (queryError) throw queryError;

      const mapped: Dealer[] = (data || []).map((row: any) => ({
        id: row.id,
        organization_id: row.organization_id,
        dealer_no: row.dealer_no ? row.dealer_no.toString().trim() : null,
        dealer_name: (row.dealer_name || '').toString().trim(),
        dealer_email: row.dealer_email ? row.dealer_email.toString().trim().toLowerCase() : null,
        dealer_phone: row.dealer_phone ? row.dealer_phone.toString().trim() : null,
        dealer_tier_id: row.dealer_tier_id || null,
        status: row.status || 'active',
        deleted: row.deleted || false,
        created_at: row.created_at || undefined,
        updated_at: row.updated_at || undefined,
      }));

      setDealers(mapped);
    } catch (err: any) {
      const errorMessage = err?.message || 'Error loading dealers';
      console.error('[useDealers] Error:', err);
      setError(errorMessage);
      setDealers([]);
    } finally {
      setIsLoading(false);
    }
  }, [activeOrganizationId]);

  const createDealer = useCallback(async (input: CreateDealerInput): Promise<Dealer> => {
    if (!activeOrganizationId) throw new Error('No active organization');

    const payload: any = {
      organization_id: activeOrganizationId,
      dealer_name: input.dealer_name.trim(),
      dealer_email: input.dealer_email?.trim().toLowerCase() || null,
      dealer_phone: input.dealer_phone?.trim() || null,
      dealer_tier_id: input.dealer_tier_id ?? null,
      status: input.status || 'active',
      deleted: false,
      identification_number: input.identification_number?.trim() || null,
      website: input.website?.trim() || null,
      alt_phone: input.alt_phone?.trim() || null,
      primary_contact_id: input.primary_contact_id || null,
      primary_contact_app_user_id: input.primary_contact_app_user_id ?? null,
      street_address_line_1: input.street_address_line_1?.trim() || null,
      street_address_line_2: input.street_address_line_2?.trim() || null,
      city: input.city?.trim() || null,
      state: input.state?.trim() || null,
      zip_code: input.zip_code?.trim() || null,
      country: input.country?.trim() || null,
      billing_same_as_location: input.billing_same_as_location ?? true,
      billing_street_address_line_1: input.billing_street_address_line_1?.trim() || null,
      billing_street_address_line_2: input.billing_street_address_line_2?.trim() || null,
      billing_city: input.billing_city?.trim() || null,
      billing_state: input.billing_state?.trim() || null,
      billing_zip_code: input.billing_zip_code?.trim() || null,
      billing_country: input.billing_country?.trim() || null,
      notes: input.notes?.trim() || null,
    };
    if (input.logo_url !== undefined) payload.logo_url = input.logo_url?.trim() || null;

    const { data, error: insertError } = await supabase
      .from('Dealers')
      .insert(payload)
      .select('id, organization_id, dealer_no, dealer_name, dealer_email, dealer_phone, dealer_tier_id, status, deleted, created_at, updated_at, identification_number, website, alt_phone, primary_contact_id, street_address_line_1, street_address_line_2, city, state, zip_code, country, billing_same_as_location, billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country, notes')
      .single();

    if (insertError) throw insertError;

    const newDealer: Dealer = {
      id: data.id,
      organization_id: data.organization_id,
      dealer_no: data.dealer_no ? data.dealer_no.toString().trim() : null,
      dealer_name: (data.dealer_name || '').toString().trim(),
      dealer_email: data.dealer_email ? data.dealer_email.toString().trim().toLowerCase() : null,
      dealer_phone: data.dealer_phone ? data.dealer_phone.toString().trim() : null,
      dealer_tier_id: data.dealer_tier_id || null,
      status: data.status || 'active',
      deleted: data.deleted || false,
      created_at: data.created_at || undefined,
      updated_at: data.updated_at || undefined,
    };

    await fetchDealers();
    return newDealer;
  }, [activeOrganizationId, fetchDealers]);

  const updateDealer = useCallback(async (id: string, input: UpdateDealerInput): Promise<Dealer> => {
    const payload: any = {};
    if (input.dealer_name !== undefined) payload.dealer_name = input.dealer_name.trim();
    if (input.dealer_email !== undefined) payload.dealer_email = input.dealer_email?.trim().toLowerCase() || null;
    if (input.dealer_phone !== undefined) payload.dealer_phone = input.dealer_phone?.trim() || null;
    if (input.dealer_tier_id !== undefined) payload.dealer_tier_id = input.dealer_tier_id ?? null;
    if (input.status !== undefined) payload.status = input.status || null;
    if (input.identification_number !== undefined) payload.identification_number = input.identification_number?.trim() || null;
    if (input.website !== undefined) payload.website = input.website?.trim() || null;
    if (input.alt_phone !== undefined) payload.alt_phone = input.alt_phone?.trim() || null;
    if (input.primary_contact_id !== undefined) payload.primary_contact_id = input.primary_contact_id || null;
    if (input.primary_contact_app_user_id !== undefined) payload.primary_contact_app_user_id = input.primary_contact_app_user_id ?? null;
    if (input.street_address_line_1 !== undefined) payload.street_address_line_1 = input.street_address_line_1?.trim() || null;
    if (input.street_address_line_2 !== undefined) payload.street_address_line_2 = input.street_address_line_2?.trim() || null;
    if (input.city !== undefined) payload.city = input.city?.trim() || null;
    if (input.state !== undefined) payload.state = input.state?.trim() || null;
    if (input.zip_code !== undefined) payload.zip_code = input.zip_code?.trim() || null;
    if (input.country !== undefined) payload.country = input.country?.trim() || null;
    if (input.billing_same_as_location !== undefined) payload.billing_same_as_location = input.billing_same_as_location;
    if (input.billing_street_address_line_1 !== undefined) payload.billing_street_address_line_1 = input.billing_street_address_line_1?.trim() || null;
    if (input.billing_street_address_line_2 !== undefined) payload.billing_street_address_line_2 = input.billing_street_address_line_2?.trim() || null;
    if (input.billing_city !== undefined) payload.billing_city = input.billing_city?.trim() || null;
    if (input.billing_state !== undefined) payload.billing_state = input.billing_state?.trim() || null;
    if (input.billing_zip_code !== undefined) payload.billing_zip_code = input.billing_zip_code?.trim() || null;
    if (input.billing_country !== undefined) payload.billing_country = input.billing_country?.trim() || null;
    if (input.notes !== undefined) payload.notes = input.notes?.trim() || null;
    if (input.logo_url !== undefined) payload.logo_url = input.logo_url?.trim() || null;

    const { data, error: updateError } = await supabase
      .from('Dealers')
      .update(payload)
      .eq('id', id)
      .eq('organization_id', activeOrganizationId || '')
      .eq('deleted', false)
      .select('id, organization_id, dealer_no, dealer_name, dealer_email, dealer_phone, dealer_tier_id, status, deleted, created_at, updated_at, identification_number, website, alt_phone, primary_contact_id, street_address_line_1, street_address_line_2, city, state, zip_code, country, billing_same_as_location, billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country, notes')
      .single();

    if (updateError) throw updateError;

    const updatedDealer: Dealer = {
      id: data.id,
      organization_id: data.organization_id,
      dealer_no: data.dealer_no ? data.dealer_no.toString().trim() : null,
      dealer_name: (data.dealer_name || '').toString().trim(),
      dealer_email: data.dealer_email ? data.dealer_email.toString().trim().toLowerCase() : null,
      dealer_phone: data.dealer_phone ? data.dealer_phone.toString().trim() : null,
      dealer_tier_id: data.dealer_tier_id || null,
      status: data.status || 'active',
      deleted: data.deleted || false,
      created_at: data.created_at || undefined,
      updated_at: data.updated_at || undefined,
    };

    await fetchDealers();
    return updatedDealer;
  }, [activeOrganizationId, fetchDealers]);

  const archiveDealer = useCallback(async (id: string): Promise<void> => {
    const { error: updateError } = await supabase
      .from('Dealers')
      .update({ deleted: true })
      .eq('id', id)
      .eq('organization_id', activeOrganizationId || '')
      .eq('deleted', false);

    if (updateError) throw updateError;
    await fetchDealers();
  }, [activeOrganizationId, fetchDealers]);

  const refetch = useCallback(() => fetchDealers(), [fetchDealers]);

  useEffect(() => {
    fetchDealers();
  }, [fetchDealers]);

  return {
    dealers,
    isLoading,
    error,
    fetchDealers,
    createDealer,
    updateDealer,
    archiveDealer,
    refetch,
  };
}
