import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useActiveCompany } from './useActiveCompany';

/**
 * Contact Type enum values (DB uses EN, UI shows ES)
 */
export type ContactType = 'architect' | 'interior_designer' | 'engineer' | 'project_manager' | 'end_customer';

/**
 * Contact Type mapping: DB (EN) -> UI (EN)
 * All labels in English for consistency
 */
export const CONTACT_TYPE_LABELS: Record<ContactType, string> = {
  architect: 'Architect',
  interior_designer: 'Interior Designer',
  engineer: 'Engineer',
  project_manager: 'Project Manager',
  end_customer: 'End Customer',
};

/**
 * Contact shape canónico para UI
 */
export interface DirectoryContact {
  id: string;
  organization_id: string;
  company_id?: string | null;
  customer_id?: string | null;
  // Campos explícitos con fallback a genéricos
  contact_title?: string | null;
  contact_name: string;
  contact_id_number?: string | null;
  contact_type: ContactType | null;
  contact_primary_phone?: string | null;
  contact_cell_phone?: string | null;
  contact_alt_phone?: string | null;
  contact_email?: string | null;
  contact_street_address?: string | null;
  contact_street_address_2?: string | null;
  contact_city?: string | null;
  contact_state?: string | null;
  contact_zip_code?: string | null;
  contact_country?: string | null;
  deleted: boolean;
  created_at?: string;
  updated_at?: string;
}

/**
 * Input para crear Contact
 */
export interface CreateContactInput {
  company_id?: string | null;
  customer_id?: string | null;
  contact_title?: string | null;
  contact_name: string;
  contact_id_number?: string | null;
  contact_type: ContactType;
  contact_primary_phone?: string | null;
  contact_cell_phone?: string | null;
  contact_alt_phone?: string | null;
  contact_email?: string | null;
  contact_street_address?: string | null;
  contact_street_address_2?: string | null;
  contact_city?: string | null;
  contact_state?: string | null;
  contact_zip_code?: string | null;
  contact_country?: string | null;
}

/**
 * Input para actualizar Contact
 */
export interface UpdateContactInput {
  company_id?: string | null;
  customer_id?: string | null;
  contact_title?: string | null;
  contact_name?: string;
  contact_id_number?: string | null;
  contact_type?: ContactType | null;
  contact_primary_phone?: string | null;
  contact_cell_phone?: string | null;
  contact_alt_phone?: string | null;
  contact_email?: string | null;
  contact_street_address?: string | null;
  contact_street_address_2?: string | null;
  contact_city?: string | null;
  contact_state?: string | null;
  contact_zip_code?: string | null;
  contact_country?: string | null;
}

/**
 * Hook para gestionar DirectoryContacts con transición gradual a columnas explícitas
 * 
 * REGLA DE ORO:
 * - Leer: seleccionar explícitas + genéricas (safe select con fallback)
 * - Mostrar/editar: usar explícitas con fallback a genéricas
 * - Escribir (insert/update): SOLO columnas explícitas (nunca genéricas)
 */
export function useDirectoryContacts(params?: { organizationId?: string | null; enabled?: boolean }) {
  const [contacts, setContacts] = useState<DirectoryContact[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId: contextOrgId } = useOrganizationContext();
  const { activeCompanyId } = useActiveCompany();
  
  // Use provided organizationId or fallback to context
  const activeOrganizationId = params?.organizationId ?? contextOrgId;
  const enabled = params?.enabled ?? true;

  /**
   * Safe select: intenta con explícitas + genéricas, fallback a solo explícitas si falla
   */
  const safeSelectContacts = useCallback(async (orgId: string, companyIds: string[] = []) => {
    // SELECT mínimo: explícitas + genéricas para transición
    const explicitAndGeneric = `
      id, organization_id, company_id, customer_id,
      contact_title, title,
      contact_name, name,
      contact_id_number, id_number,
      contact_type, type,
      contact_primary_phone, primary_phone,
      contact_cell_phone, cell_phone,
      contact_alt_phone, alt_phone,
      contact_email, email,
      contact_street_address, street_address,
      contact_street_address_2, street_address_2,
      contact_city, city,
      contact_state, state,
      contact_zip_code, zip_code,
      contact_country, country,
      deleted, created_at, updated_at
    `.replace(/\s+/g, ' ').trim();
    
    try {
      let query = supabase
        .from('DirectoryContacts')
        .select(explicitAndGeneric)
        .eq('deleted', false)
        .order('created_at', { ascending: false });

      // Filtrar por company_id si existen, sino por organization_id
      if (companyIds.length > 0) {
        query = query.in('company_id', companyIds);
        // También incluir contacts sin company_id pero con organization_id (transición)
        const { data: companyData } = await query;
        const { data: orgData } = await supabase
          .from('DirectoryContacts')
          .select(explicitAndGeneric)
          .eq('organization_id', orgId)
          .is('company_id', null)
          .eq('deleted', false)
          .order('created_at', { ascending: false });

        // Combinar sin duplicados
        const all = [...(companyData || []), ...(orgData || [])];
        return Array.from(new Map(all.map(item => [item.id, item])).values());
      } else {
        const { data, error: queryError } = await query.eq('organization_id', orgId);
        
        if (queryError) {
          throw queryError;
        }
        return data || [];
      }
    } catch (err: any) {
      // Si falla por columna inexistente, reintentar SOLO con explícitas
      if (err?.code === '42703' || err?.message?.includes('does not exist') || err?.message?.includes('column')) {
        if (import.meta.env.DEV) {
          console.warn('[useDirectoryContacts] Generic columns not found, retrying with explicit columns only');
        }
        
        const explicitOnly = `
          id, organization_id, company_id, customer_id,
          contact_title, contact_name, contact_id_number, contact_type,
          contact_primary_phone, contact_cell_phone, contact_alt_phone, contact_email,
          contact_street_address, contact_street_address_2, contact_city, contact_state, contact_zip_code, contact_country,
          deleted, created_at, updated_at
        `.replace(/\s+/g, ' ').trim();
        
        let retryQuery = supabase
          .from('DirectoryContacts')
          .select(explicitOnly)
          .eq('deleted', false)
          .order('created_at', { ascending: false });

        if (companyIds.length > 0) {
          const { data: retryCompanyData } = await retryQuery.in('company_id', companyIds);
          const { data: retryOrgData } = await supabase
            .from('DirectoryContacts')
            .select(explicitOnly)
            .eq('organization_id', orgId)
            .is('company_id', null)
            .eq('deleted', false)
            .order('created_at', { ascending: false });

          const all = [...(retryCompanyData || []), ...(retryOrgData || [])];
          return Array.from(new Map(all.map(item => [item.id, item])).values());
        } else {
          const { data: retryData, error: retryError } = await retryQuery.eq('organization_id', orgId);
          
          if (retryError) {
            throw retryError;
          }
          return retryData || [];
        }
      }
      throw err;
    }
  }, []);

  /**
   * Normalizar contact_type: acepta EN, retorna EN o null
   */
  const normalizeContactType = useCallback((type: any): ContactType | null => {
    if (!type) return null;
    const s = type.toString().trim().toLowerCase();
    
    // Si ya es un valor EN válido, retornarlo
    if (['architect', 'interior_designer', 'engineer', 'project_manager', 'end_customer'].includes(s)) {
      return s as ContactType;
    }
    
    // Si no se reconoce, retornar null
    if (import.meta.env.DEV) {
      console.warn('[useDirectoryContacts] Unknown contact_type value:', type);
    }
    return null;
  }, []);

  /**
   * Mapear row a shape canónico DirectoryContact con fallback
   */
  const mapToContact = useCallback((row: any): DirectoryContact => {
    // Mapping con fallback: explícitas primero, luego genéricas
    const contact_title = (row.contact_title ?? row.title ?? '').toString().trim() || null;
    const contact_name = (row.contact_name ?? row.name ?? '').toString().trim();
    const contact_id_number = (row.contact_id_number ?? row.id_number ?? '').toString().trim() || null;
    const contact_type = normalizeContactType(row.contact_type ?? row.type ?? null);
    const contact_primary_phone = (row.contact_primary_phone ?? row.primary_phone ?? '').toString().trim() || null;
    const contact_cell_phone = (row.contact_cell_phone ?? row.cell_phone ?? '').toString().trim() || null;
    const contact_alt_phone = (row.contact_alt_phone ?? row.alt_phone ?? '').toString().trim() || null;
    const contact_email = (row.contact_email ?? row.email ?? '').toString().trim() || null;
    const contact_street_address = (row.contact_street_address ?? row.street_address ?? '').toString().trim() || null;
    const contact_street_address_2 = (row.contact_street_address_2 ?? row.street_address_2 ?? '').toString().trim() || null;
    const contact_city = (row.contact_city ?? row.city ?? '').toString().trim() || null;
    const contact_state = (row.contact_state ?? row.state ?? '').toString().trim() || null;
    const contact_zip_code = (row.contact_zip_code ?? row.zip_code ?? '').toString().trim() || null;
    const contact_country = (row.contact_country ?? row.country ?? '').toString().trim() || null;

    return {
      id: row.id,
      organization_id: row.organization_id,
      company_id: row.company_id || null,
      customer_id: row.customer_id || null,
      contact_title,
      contact_name,
      contact_id_number,
      contact_type,
      contact_primary_phone,
      contact_cell_phone,
      contact_alt_phone,
      contact_email,
      contact_street_address,
      contact_street_address_2,
      contact_city,
      contact_state,
      contact_zip_code,
      contact_country,
      deleted: row.deleted || false,
      created_at: row.created_at || undefined,
      updated_at: row.updated_at || undefined,
    };
  }, [normalizeContactType]);

  /**
   * Fetch contacts (por company_id con fallback a organization_id)
   */
  const fetchContacts = useCallback(async () => {
    if (!enabled || !activeOrganizationId) {
      setContacts([]);
      setIsLoading(false);
      setError(null);
      return;
    }

    try {
      setIsLoading(true);
      setError(null);

      // Primero obtener companies de la organization
      const { data: orgCompanies } = await supabase
        .from('Companies')
        .select('id')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false);

      const companyIds = (orgCompanies || []).map(c => c.id);

      // Usar safeSelectContacts que maneja company_id y organization_id
      const data = await safeSelectContacts(activeOrganizationId, companyIds);
      const mapped = data.map(mapToContact);

      if (import.meta.env.DEV) {
        console.log('[useDirectoryContacts] Fetched contacts:', {
          count: mapped.length,
          companyIds: companyIds.length,
          sample: mapped[0] || null,
        });
      }

      setContacts(mapped);
    } catch (err: any) {
      const errorMessage = err?.message || 'Error loading contacts';
      console.error('[useDirectoryContacts] Error:', errorMessage, err);
      setError(errorMessage);
      setContacts([]);
    } finally {
      setIsLoading(false);
    }
  }, [enabled, activeOrganizationId, safeSelectContacts, mapToContact]);

  /**
   * Get contact by ID
   */
  const getContactById = useCallback(async (id: string): Promise<DirectoryContact | null> => {
    if (!activeOrganizationId) {
      throw new Error('No active organization');
    }

    try {
      // SOLO columnas explícitas - no usar genéricas que no existen
      const explicitOnly = `
        id, organization_id, company_id, customer_id,
        contact_title, contact_name, contact_id_number, contact_type,
        contact_primary_phone, contact_cell_phone, contact_alt_phone, contact_email,
        contact_street_address, contact_street_address_2, contact_city, contact_state, contact_zip_code, contact_country,
        deleted, created_at, updated_at
      `.replace(/\s+/g, ' ').trim();

      const { data, error: queryError } = await supabase
        .from('DirectoryContacts')
        .select(explicitOnly)
        .eq('id', id)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .single();

      if (queryError) {
        throw queryError;
      }

      return mapToContact(data);
    } catch (err: any) {
      const errorMessage = err?.message || 'Error loading contact';
      console.error('[useDirectoryContacts] Get contact error:', errorMessage, err);
      throw new Error(errorMessage);
    }
  }, [enabled, activeOrganizationId, mapToContact]);

  /**
   * Create contact (SOLO columnas explícitas)
   */
  const createContact = useCallback(async (input: CreateContactInput): Promise<DirectoryContact> => {
    if (!activeOrganizationId) {
      throw new Error('No active organization');
    }

    try {
      // Payload SOLO con columnas explícitas
      // IMPORTANT: organization_id debe SIEMPRE establecerse para que OrganizationUsers puedan ver los contacts
      // company_id es más específico (para portal users), pero organization_id es necesario para RLS de OrganizationUsers
      const payload: any = {
        company_id: input.company_id ?? activeCompanyId ?? null,
        organization_id: activeOrganizationId, // SIEMPRE establecer organization_id (necesario para RLS de OrganizationUsers)
        customer_id: input.customer_id || null,
        contact_title: input.contact_title?.trim() || null,
        contact_name: input.contact_name.trim(),
        contact_id_number: input.contact_id_number?.trim() || null,
        contact_type: input.contact_type, // Ya viene en EN
        contact_primary_phone: input.contact_primary_phone?.trim() || null,
        contact_cell_phone: input.contact_cell_phone?.trim() || null,
        contact_alt_phone: input.contact_alt_phone?.trim() || null,
        contact_email: input.contact_email?.trim().toLowerCase() || null,
        contact_street_address: input.contact_street_address?.trim() || null,
        contact_street_address_2: input.contact_street_address_2?.trim() || null,
        contact_city: input.contact_city?.trim() || null,
        contact_state: input.contact_state?.trim() || null,
        contact_zip_code: input.contact_zip_code?.trim() || null,
        contact_country: input.contact_country?.trim() || null,
        deleted: false,
      };

      // NO incluir columnas genéricas (name, email, phone, etc.)
      const { data, error: insertError } = await supabase
        .from('DirectoryContacts')
        .insert(payload)
        .select(`
          id, organization_id, company_id, customer_id,
          contact_title, contact_name, contact_id_number, contact_type,
          contact_primary_phone, contact_cell_phone, contact_alt_phone, contact_email,
          contact_street_address, contact_street_address_2, contact_city, contact_state, contact_zip_code, contact_country,
          deleted, created_at, updated_at
        `)
        .single();

      if (insertError) {
        throw insertError;
      }

      const newContact = mapToContact(data);

      if (import.meta.env.DEV) {
        console.log('[useDirectoryContacts] Created contact:', newContact);
      }

      // Refrescar lista
      await fetchContacts();

      return newContact;
    } catch (err: any) {
      const errorMessage = err?.message || 'Error creating contact';
      console.error('[useDirectoryContacts] Create error:', errorMessage, err);
      throw new Error(errorMessage);
    }
  }, [enabled, activeOrganizationId, activeCompanyId, fetchContacts, mapToContact]);

  /**
   * Update contact (SOLO columnas explícitas)
   */
  const updateContact = useCallback(async (id: string, input: UpdateContactInput): Promise<DirectoryContact> => {
    try {
      const payload: any = {};
      
      if (input.company_id !== undefined) {
        payload.company_id = input.company_id || null;
      }
      if (input.customer_id !== undefined) {
        payload.customer_id = input.customer_id || null;
      }
      if (input.contact_title !== undefined) {
        payload.contact_title = input.contact_title?.trim() || null;
      }
      if (input.contact_name !== undefined) {
        payload.contact_name = input.contact_name.trim();
      }
      if (input.contact_id_number !== undefined) {
        payload.contact_id_number = input.contact_id_number?.trim() || null;
      }
      if (input.contact_type !== undefined) {
        payload.contact_type = input.contact_type; // Ya viene en EN o null
      }
      if (input.contact_primary_phone !== undefined) {
        payload.contact_primary_phone = input.contact_primary_phone?.trim() || null;
      }
      if (input.contact_cell_phone !== undefined) {
        payload.contact_cell_phone = input.contact_cell_phone?.trim() || null;
      }
      if (input.contact_alt_phone !== undefined) {
        payload.contact_alt_phone = input.contact_alt_phone?.trim() || null;
      }
      if (input.contact_email !== undefined) {
        payload.contact_email = input.contact_email?.trim().toLowerCase() || null;
      }
      if (input.contact_street_address !== undefined) {
        payload.contact_street_address = input.contact_street_address?.trim() || null;
      }
      if (input.contact_street_address_2 !== undefined) {
        payload.contact_street_address_2 = input.contact_street_address_2?.trim() || null;
      }
      if (input.contact_city !== undefined) {
        payload.contact_city = input.contact_city?.trim() || null;
      }
      if (input.contact_state !== undefined) {
        payload.contact_state = input.contact_state?.trim() || null;
      }
      if (input.contact_zip_code !== undefined) {
        payload.contact_zip_code = input.contact_zip_code?.trim() || null;
      }
      if (input.contact_country !== undefined) {
        payload.contact_country = input.contact_country?.trim() || null;
      }

      // NO incluir columnas genéricas
      // IMPORTANT: Asegurarse de que organization_id esté en el payload si no viene en input
      // Esto permite que OrganizationUsers puedan ver el contact actualizado
      if (!payload.organization_id && activeOrganizationId) {
        payload.organization_id = activeOrganizationId;
      }
      
      const { data, error: updateError } = await supabase
        .from('DirectoryContacts')
        .update(payload)
        .eq('id', id)
        .eq('deleted', false)
        .select(`
          id, organization_id, company_id, customer_id,
          contact_title, contact_name, contact_id_number, contact_type,
          contact_primary_phone, contact_cell_phone, contact_alt_phone, contact_email,
          contact_street_address, contact_street_address_2, contact_city, contact_state, contact_zip_code, contact_country,
          deleted, created_at, updated_at
        `)
        .single();

      if (updateError) {
        throw updateError;
      }

      const updatedContact = mapToContact(data);

      if (import.meta.env.DEV) {
        console.log('[useDirectoryContacts] Updated contact:', updatedContact);
      }

      // Refrescar lista
      await fetchContacts();

      return updatedContact;
    } catch (err: any) {
      const errorMessage = err?.message || 'Error updating contact';
      console.error('[useDirectoryContacts] Update error:', errorMessage, err);
      throw new Error(errorMessage);
    }
  }, [enabled, activeOrganizationId, fetchContacts, mapToContact]);

  /**
   * Soft delete contact
   */
  const softDeleteContact = useCallback(async (id: string): Promise<void> => {
    try {
      const { error: updateError } = await supabase
        .from('DirectoryContacts')
        .update({ deleted: true })
        .eq('id', id)
        .eq('organization_id', activeOrganizationId || '')
        .eq('deleted', false);

      if (updateError) {
        throw updateError;
      }

      if (import.meta.env.DEV) {
        console.log('[useDirectoryContacts] Soft deleted contact:', id);
      }

      // Refrescar lista
      await fetchContacts();
    } catch (err: any) {
      const errorMessage = err?.message || 'Error deleting contact';
      console.error('[useDirectoryContacts] Delete error:', errorMessage, err);
      throw new Error(errorMessage);
    }
  }, [enabled, activeOrganizationId, fetchContacts]);

  /**
   * Refetch contacts
   */
  const refetch = useCallback(() => {
    fetchContacts();
  }, [fetchContacts]);

  // Auto-fetch cuando cambia organization (siempre declarado, no condicional)
  useEffect(() => {
    if (enabled) {
      fetchContacts();
    } else {
      setContacts([]);
      setIsLoading(false);
      setError(null);
    }
  }, [fetchContacts, enabled]);

  return {
    contacts,
    isLoading,
    error,
    fetchContacts,
    getContactById,
    createContact,
    updateContact,
    softDeleteContact,
    refetch,
  };
}
