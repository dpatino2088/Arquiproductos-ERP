import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

/**
 * Customer shape canónico para UI
 */
export interface DirectoryCustomer {
  id: string;
  organization_id: string;
  company_id?: string; // Nuevo: company_id (nullable durante transición)
  customer_name: string;
  customer_email?: string | null;
  customer_phone?: string | null;
  identification_number?: string | null;
  customer_type_name?: string | null;
  website?: string | null;
  alt_phone?: string | null;
  primary_contact_id?: string | null;
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
  status?: string;
  deleted: boolean;
  created_at?: string;
  updated_at?: string;
}

/**
 * Input para crear Customer
 */
export interface CreateCustomerInput {
  customer_name: string;
  customer_email?: string;
  customer_phone?: string;
  identification_number?: string;
  customer_type_name?: string;
  website?: string;
  alt_phone?: string;
  primary_contact_id?: string;
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
  status?: string;
}

/**
 * Input para actualizar Customer
 */
export interface UpdateCustomerInput {
  customer_name?: string;
  customer_email?: string;
  customer_phone?: string;
  identification_number?: string;
  customer_type_name?: string;
  website?: string;
  alt_phone?: string;
  primary_contact_id?: string;
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
  status?: string;
}

/**
 * Hook para gestionar DirectoryCustomers con transición gradual a columnas explícitas
 * 
 * REGLA DE ORO:
 * - Leer: seleccionar explícitas + genéricas (safe select con fallback)
 * - Mostrar/editar: usar explícitas con fallback a genéricas
 * - Escribir (insert/update): SOLO columnas explícitas (nunca genéricas)
 */
export function useDirectoryCustomers(params?: { organizationId?: string | null; enabled?: boolean }) {
  const [customers, setCustomers] = useState<DirectoryCustomer[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId: contextOrgId } = useOrganizationContext();
  
  // Use provided organizationId or fallback to context
  const activeOrganizationId = params?.organizationId ?? contextOrgId;
  const enabled = params?.enabled ?? true;

  /**
   * Safe select: intenta con explícitas + genéricas, fallback a solo explícitas si falla
   * Query base: Filtrar por organization_id, deleted=false, ordenar por created_at DESC
   * NO filtrar por status (incluir NULL)
   */
  const safeSelectCustomers = useCallback(async (orgId: string) => {
    // Primera intento: explícitas + genéricas (incluyendo company_id)
    const explicitAndGeneric = `
      id, organization_id, company_id, 
      customer_name, customer_email, customer_phone, 
      identification_number, customer_type_name, website,
      alt_phone, primary_contact_id,
      street_address_line_1, street_address_line_2, city, state, zip_code, country,
      billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country,
      notes, status, deleted, created_at, updated_at,
      name, email, phone
    `.replace(/\s+/g, ' ').trim();
    
    try {
      const { data, error: queryError } = await supabase
        .from('DirectoryCustomers')
        .select(explicitAndGeneric)
        .eq('organization_id', orgId)
        .eq('deleted', false)
        .order('created_at', { ascending: false });
        
      if (queryError) {
        throw queryError;
      }
      return data || [];
    } catch (err: any) {
      // Si falla por columna inexistente, reintentar SOLO con explícitas
      if (err?.code === '42703' || err?.message?.includes('does not exist') || err?.message?.includes('column')) {
        if (import.meta.env.DEV) {
          console.warn('[useDirectoryCustomers] Generic columns not found, retrying with explicit columns only');
        }
        
        const explicitOnly = `
          id, organization_id, company_id, 
          customer_name, customer_email, customer_phone,
          identification_number, customer_type_name, website,
          alt_phone, primary_contact_id,
          street_address_line_1, street_address_line_2, city, state, zip_code, country,
          billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country,
          notes, status, deleted, created_at, updated_at
        `.replace(/\s+/g, ' ').trim();
        
        const { data: retryData, error: retryError } = await supabase
          .from('DirectoryCustomers')
          .select(explicitOnly)
          .eq('organization_id', orgId)
          .eq('deleted', false)
          .order('created_at', { ascending: false });
          
        if (retryError) {
          throw retryError;
        }
        return retryData || [];
      }
      throw err;
    }
  }, []);

  /**
   * Mapear row a shape canónico DirectoryCustomer
   */
  const mapToCustomer = useCallback((row: any): DirectoryCustomer => {
    const customer_name = (row.customer_name ?? row.name ?? '').toString().trim();
    const customer_email = (row.customer_email ?? row.email ?? '').toString().trim() || null;
    const customer_phone = (row.customer_phone ?? row.phone ?? '').toString().trim() || null;

    return {
      id: row.id,
      organization_id: row.organization_id,
      company_id: row.company_id || undefined,
      customer_name,
      customer_email,
      customer_phone,
      identification_number: row.identification_number?.toString().trim() || null,
      customer_type_name: row.customer_type_name?.toString().trim() || null,
      website: row.website?.toString().trim() || null,
      alt_phone: row.alt_phone?.toString().trim() || null,
      primary_contact_id: row.primary_contact_id || null,
      street_address_line_1: row.street_address_line_1?.toString().trim() || null,
      street_address_line_2: row.street_address_line_2?.toString().trim() || null,
      city: row.city?.toString().trim() || null,
      state: row.state?.toString().trim() || null,
      zip_code: row.zip_code?.toString().trim() || null,
      country: row.country?.toString().trim() || null,
      billing_street_address_line_1: row.billing_street_address_line_1?.toString().trim() || null,
      billing_street_address_line_2: row.billing_street_address_line_2?.toString().trim() || null,
      billing_city: row.billing_city?.toString().trim() || null,
      billing_state: row.billing_state?.toString().trim() || null,
      billing_zip_code: row.billing_zip_code?.toString().trim() || null,
      billing_country: row.billing_country?.toString().trim() || null,
      notes: row.notes?.toString().trim() || null,
      status: row.status || null, // NULL status is valid, will be treated as "active" in UI
      deleted: row.deleted || false,
      created_at: row.created_at || undefined,
      updated_at: row.updated_at || undefined,
    };
  }, []);

  /**
   * Fetch customers - Query base obligatoria:
   * - Filtrar por organization_id = activeOrganizationId
   * - deleted = false
   * - NO filtrar por status si es NULL
   * - Ordenar por created_at DESC
   */
  const fetchCustomers = useCallback(async () => {
    if (!enabled || !activeOrganizationId) {
      setCustomers([]);
      setIsLoading(false);
      setError(null);
      return;
    }

    try {
      setIsLoading(true);
      setError(null);

      // Query base obligatoria según requerimientos
      const data = await safeSelectCustomers(activeOrganizationId);
      const mapped = data.map(mapToCustomer);

      if (import.meta.env.DEV) {
        console.log('[useDirectoryCustomers] Fetched customers:', {
          count: mapped.length,
          organizationId: activeOrganizationId,
          sample: mapped[0] || null,
        });
      }

      setCustomers(mapped);
    } catch (err: any) {
      const errorMessage = err?.message || 'Error loading customers';
      console.error('[useDirectoryCustomers] Error:', errorMessage, err);
      setError(errorMessage);
      setCustomers([]);
    } finally {
      setIsLoading(false);
    }
  }, [enabled, activeOrganizationId, safeSelectCustomers, mapToCustomer]);

  /**
   * Create customer (SOLO columnas explícitas)
   * Siempre usar organization_id (company_id es opcional)
   */
  const createCustomer = useCallback(async (input: CreateCustomerInput & { company_id?: string }): Promise<DirectoryCustomer> => {
    if (!activeOrganizationId) {
      throw new Error('No active organization');
    }

    try {
      // Normalizar: trim() y email lowercase
      // Siempre usar organization_id (company_id es opcional)
      const payload: any = {
        organization_id: activeOrganizationId, // Siempre requerido
        company_id: input.company_id || null,
        customer_name: input.customer_name.trim(),
        customer_email: input.customer_email?.trim().toLowerCase() || null,
        customer_phone: input.customer_phone?.trim() || null,
        identification_number: input.identification_number?.trim() || null,
        customer_type_name: input.customer_type_name || null,
        website: input.website?.trim() || null,
        alt_phone: input.alt_phone?.trim() || null,
        primary_contact_id: input.primary_contact_id || null,
        street_address_line_1: input.street_address_line_1?.trim() || null,
        street_address_line_2: input.street_address_line_2?.trim() || null,
        city: input.city?.trim() || null,
        state: input.state?.trim() || null,
        zip_code: input.zip_code?.trim() || null,
        country: input.country?.trim() || null,
        billing_street_address_line_1: input.billing_street_address_line_1?.trim() || null,
        billing_street_address_line_2: input.billing_street_address_line_2?.trim() || null,
        billing_city: input.billing_city?.trim() || null,
        billing_state: input.billing_state?.trim() || null,
        billing_zip_code: input.billing_zip_code?.trim() || null,
        billing_country: input.billing_country?.trim() || null,
        notes: input.notes?.trim() || null,
        status: input.status || null,
        deleted: false,
      };

      // NO incluir name/email/phone genéricas
      const { data, error: insertError } = await supabase
        .from('DirectoryCustomers')
        .insert(payload)
        .select(`
          id, organization_id, company_id,
          customer_name, customer_email, customer_phone,
          identification_number, customer_type_name, website,
          alt_phone, primary_contact_id,
          street_address_line_1, street_address_line_2, city, state, zip_code, country,
          billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country,
          notes, status, deleted, created_at, updated_at
        `)
        .single();

      if (insertError) {
        throw insertError;
      }

      const newCustomer = mapToCustomer({ ...data, company_id: input.company_id || null });

      if (import.meta.env.DEV) {
        console.log('[useDirectoryCustomers] Created customer:', newCustomer);
      }

      // Refrescar lista
      await fetchCustomers();

      return newCustomer;
    } catch (err: any) {
      const errorMessage = err?.message || 'Error creating customer';
      console.error('[useDirectoryCustomers] Create error:', errorMessage, err);
      throw new Error(errorMessage);
    }
  }, [activeOrganizationId, fetchCustomers, mapToCustomer]);

  /**
   * Update customer (SOLO columnas explícitas)
   */
  const updateCustomer = useCallback(async (id: string, input: UpdateCustomerInput): Promise<DirectoryCustomer> => {
    try {
      const payload: any = {};
      
      if (input.customer_name !== undefined) {
        payload.customer_name = input.customer_name.trim();
      }
      if (input.customer_email !== undefined) {
        payload.customer_email = input.customer_email?.trim().toLowerCase() || null;
      }
      if (input.customer_phone !== undefined) {
        payload.customer_phone = input.customer_phone?.trim() || null;
      }
      if (input.identification_number !== undefined) {
        payload.identification_number = input.identification_number?.trim() || null;
      }
      if (input.customer_type_name !== undefined) {
        payload.customer_type_name = input.customer_type_name || null;
      }
      if (input.website !== undefined) {
        payload.website = input.website?.trim() || null;
      }
      if (input.alt_phone !== undefined) {
        payload.alt_phone = input.alt_phone?.trim() || null;
      }
      if (input.primary_contact_id !== undefined) {
        payload.primary_contact_id = input.primary_contact_id || null;
      }
      if (input.street_address_line_1 !== undefined) {
        payload.street_address_line_1 = input.street_address_line_1?.trim() || null;
      }
      if (input.street_address_line_2 !== undefined) {
        payload.street_address_line_2 = input.street_address_line_2?.trim() || null;
      }
      if (input.city !== undefined) {
        payload.city = input.city?.trim() || null;
      }
      if (input.state !== undefined) {
        payload.state = input.state?.trim() || null;
      }
      if (input.zip_code !== undefined) {
        payload.zip_code = input.zip_code?.trim() || null;
      }
      if (input.country !== undefined) {
        payload.country = input.country?.trim() || null;
      }
      if (input.billing_street_address_line_1 !== undefined) {
        payload.billing_street_address_line_1 = input.billing_street_address_line_1?.trim() || null;
      }
      if (input.billing_street_address_line_2 !== undefined) {
        payload.billing_street_address_line_2 = input.billing_street_address_line_2?.trim() || null;
      }
      if (input.billing_city !== undefined) {
        payload.billing_city = input.billing_city?.trim() || null;
      }
      if (input.billing_state !== undefined) {
        payload.billing_state = input.billing_state?.trim() || null;
      }
      if (input.billing_zip_code !== undefined) {
        payload.billing_zip_code = input.billing_zip_code?.trim() || null;
      }
      if (input.billing_country !== undefined) {
        payload.billing_country = input.billing_country?.trim() || null;
      }
      if (input.notes !== undefined) {
        payload.notes = input.notes?.trim() || null;
      }
      if (input.status !== undefined) {
        payload.status = input.status || null;
      }

      // NO incluir name/email/phone genéricas
      const { data, error: updateError } = await supabase
        .from('DirectoryCustomers')
        .update(payload)
        .eq('id', id)
        .eq('organization_id', activeOrganizationId || '')
        .eq('deleted', false)
        .select(`
          id, organization_id, company_id,
          customer_name, customer_email, customer_phone,
          identification_number, customer_type_name, website,
          alt_phone, primary_contact_id,
          street_address_line_1, street_address_line_2, city, state, zip_code, country,
          billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country,
          notes, status, deleted, created_at, updated_at
        `)
        .single();

      if (updateError) {
        throw updateError;
      }

      const updatedCustomer = mapToCustomer(data);

      if (import.meta.env.DEV) {
        console.log('[useDirectoryCustomers] Updated customer:', updatedCustomer);
      }

      // Refrescar lista
      await fetchCustomers();

      return updatedCustomer;
    } catch (err: any) {
      const errorMessage = err?.message || 'Error updating customer';
      console.error('[useDirectoryCustomers] Update error:', errorMessage, err);
      throw new Error(errorMessage);
    }
  }, [activeOrganizationId, fetchCustomers, mapToCustomer]);

  /**
   * Soft delete customer
   */
  const archiveCustomer = useCallback(async (id: string): Promise<void> => {
    try {
      const { error: updateError } = await supabase
        .from('DirectoryCustomers')
        .update({ deleted: true })
        .eq('id', id)
        .eq('organization_id', activeOrganizationId || '')
        .eq('deleted', false);

      if (updateError) {
        throw updateError;
      }

      if (import.meta.env.DEV) {
        console.log('[useDirectoryCustomers] Archived customer:', id);
      }

      // Refrescar lista
      await fetchCustomers();
    } catch (err: any) {
      const errorMessage = err?.message || 'Error archiving customer';
      console.error('[useDirectoryCustomers] Archive error:', errorMessage, err);
      throw new Error(errorMessage);
    }
  }, [activeOrganizationId, fetchCustomers]);

  /**
   * Refetch customers
   */
  const refetch = useCallback(() => {
    fetchCustomers();
  }, [fetchCustomers]);

  // Auto-fetch cuando cambia organization (siempre declarado, no condicional)
  useEffect(() => {
    if (enabled) {
      fetchCustomers();
    } else {
      setCustomers([]);
      setIsLoading(false);
      setError(null);
    }
  }, [fetchCustomers, enabled]);

  return {
    customers,
    isLoading,
    error,
    fetchCustomers,
    createCustomer,
    updateCustomer,
    archiveCustomer,
    refetch,
  };
}
