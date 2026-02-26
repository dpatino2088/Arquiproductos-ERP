import { useState, useEffect, useCallback, useRef } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useDealerScope } from './useDealerScope';
import { useAccessContext } from './useAccessContext';
import { getEffectiveOrgAndDealer } from '../lib/directoryContext';

/**
 * ✅ Estándar #1: Scope State Machine
 */
export type ScopeState = 'idle' | 'loading_scope' | 'ready' | 'switching' | 'error';

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
  dealer_id?: string | null;
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
  created_by_email?: string | null;
}

/**
 * Input para crear Contact
 */
export interface CreateContactInput {
  dealer_id?: string | null;
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
  dealer_id?: string | null;
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

/** Columnas explícitas de DirectoryContacts según dump (sin genéricas name/email/title que no existen) */
const DIRECTORY_CONTACTS_SELECT = `
  id, organization_id, dealer_id, customer_id, created_by_email,
  contact_title, contact_name, contact_id_number, contact_type,
  contact_primary_phone, contact_cell_phone, contact_alt_phone, contact_email,
  contact_street_address, contact_street_address_2, contact_city, contact_state, contact_zip_code, contact_country,
  deleted, created_at, updated_at
`.replace(/\s+/g, ' ').trim();

/**
 * Hook para gestionar DirectoryContacts.
 * - SELECT/INSERT/UPDATE: solo columnas explícitas del esquema (dump V9).
 * - RLS: dircontacts_insert exige organization_id NOT NULL; enviamos organization_id y dealer_id siempre.
 */
export function useDirectoryContacts(params?: { organizationId?: string | null; enabled?: boolean }) {
  const [contacts, setContacts] = useState<DirectoryContact[]>([]);
  // ✅ Iniciar como true cuando enabled → isFirstLoad=true desde el primer render (sin flash false→true)
  const [isPending, setIsPending] = useState(true);
  const [hasResolvedOnce, setHasResolvedOnce] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  // ✅ Estándar #1: State Machine
  const [scopeState, setScopeState] = useState<ScopeState>('idle');
  
  // Cache por scopeKey (optimization)
  const cacheRef = useRef<Map<string, DirectoryContact[]>>(new Map());
  const abortControllerRef = useRef<AbortController | null>(null);

  const fetchIdRef = useRef(0);
  const { activeOrganizationId: contextOrgId } = useOrganizationContext();
  const { scopeKey, activeDealerId, effectiveDealerId, hasHydrated } = useDealerScope();
  const { userType } = useAccessContext();

  const activeOrganizationId = params?.organizationId ?? contextOrgId;
  const enabled = params?.enabled ?? true;

  const scopeKeyRef = useRef<string>(scopeKey);
  scopeKeyRef.current = scopeKey;

  /** Para org: solo true cuando ActingAs hidrató. Para portal: true. */
  const isScopeReady = userType === 'internal' ? hasHydrated : true;
  const isInitialLoading = !hasResolvedOnce;

  /**
   * Lista de contactos: una sola fuente de verdad.
   * Caso A (portal): organization_id = activeOrgId y dealer_id = current_dealer_id; si dealer_id null → 0 resultados.
   * Caso B (org): si selectedDealerId (activeDealerId) → dealer_id = selectedDealerId; si no → todos los de la org.
   */
  const safeSelectContacts = useCallback(
    async (orgId: string, options: { userType: 'internal' | 'portal' | 'unknown'; dealerId: string | null; selectedDealerId: string | null }) => {
      let q = supabase
        .from('DirectoryContacts')
        .select(DIRECTORY_CONTACTS_SELECT)
        .eq('organization_id', orgId)
        .eq('deleted', false)
        .order('created_at', { ascending: false });

      if (options.userType === 'portal') {
        if (options.dealerId == null) return [];
        q = q.eq('dealer_id', options.dealerId);
      } else {
        if (options.selectedDealerId != null) q = q.eq('dealer_id', options.selectedDealerId);
      }

      const { data, error } = await q;
      if (error) throw error;
      return data || [];
    },
    []
  );

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
      dealer_id: row.dealer_id || null,
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
      created_by_email: row.created_by_email ?? null,
    };
  }, [normalizeContactType]);

  /**
   * Fetch contacts — portal = dealer_id obligatorio; org = selectedDealerId o todos.
   * Does not clear the list before fetch (keeps previous data until new data arrives).
   * @param signal - optional; when aborted, skips state updates and ignores AbortError
   */
  const fetchContacts = useCallback(async (signal?: AbortSignal) => {
    if (!enabled || !activeOrganizationId) {
      setContacts([]);
      setIsPending(false);
      setHasResolvedOnce(false);
      setError(null);
      setScopeState('idle');
      return;
    }
    if (signal?.aborted) return;

    const thisFetchId = ++fetchIdRef.current;
    const currentScopeKey = scopeKey;

    if (cacheRef.current.has(currentScopeKey) && scopeKeyRef.current === currentScopeKey) {
      const cached = cacheRef.current.get(currentScopeKey)!;
      if (import.meta.env.DEV) {
        console.log('[useDirectoryContacts] Cache HIT:', { scopeKey: currentScopeKey, count: cached.length });
      }
      setContacts(cached);
      setScopeState('ready');
      setHasResolvedOnce(true);
      setIsPending(false);
      return;
    }

    setIsPending(true);
    setScopeState(hasResolvedOnce ? 'switching' : 'loading_scope');

    try {
      let dealerId: string | null = null;
      if (userType === 'portal') {
        const effective = await getEffectiveOrgAndDealer(supabase, {
          activeOrgId: activeOrganizationId,
          userType,
          activeDealerId: null,
        });
        if (signal?.aborted) return;
        dealerId = effective.dealerId;
        if (dealerId == null) {
          if (thisFetchId === fetchIdRef.current && scopeKeyRef.current === currentScopeKey) {
            setIsPending(false);
            setHasResolvedOnce(true);
            setScopeState('ready');
          }
          return;
        }
      }

      const data = await safeSelectContacts(activeOrganizationId, {
        userType,
        dealerId,
        selectedDealerId: userType === 'portal' ? null : (effectiveDealerId ?? null),
      });
      if (signal?.aborted) return;
      const mapped = data.map(mapToContact);

      if (thisFetchId !== fetchIdRef.current) return;
      if (scopeKeyRef.current !== currentScopeKey) return;

      if (import.meta.env.DEV) {
        console.log('[useDirectoryContacts] Fetched contacts:', {
          count: mapped.length,
          userType,
          dealerId: userType === 'portal' ? dealerId : effectiveDealerId ?? null,
          scopeKey: currentScopeKey,
        });
      }

      cacheRef.current.set(currentScopeKey, mapped);
      setContacts(mapped);
      setError(null);
      setScopeState('ready');
    } catch (err: any) {
      if (err?.name === 'AbortError') return;
      if (thisFetchId !== fetchIdRef.current) return;
      if (scopeKeyRef.current !== currentScopeKey) return;
      const errorMessage = err?.message || 'Error loading contacts';
      console.error('[useDirectoryContacts] Error:', errorMessage, err);
      setError(errorMessage);
      setScopeState('error');
    } finally {
      if (thisFetchId === fetchIdRef.current && scopeKeyRef.current === currentScopeKey) {
        setIsPending(false);
        setHasResolvedOnce(true);
      }
    }
  }, [enabled, activeOrganizationId, effectiveDealerId, userType, safeSelectContacts, mapToContact, scopeKey, hasResolvedOnce]);

  const fetchContactsRef = useRef(fetchContacts);
  fetchContactsRef.current = fetchContacts;

  /**
   * Get contact by ID
   */
  const getContactById = useCallback(async (id: string): Promise<DirectoryContact | null> => {
    if (!activeOrganizationId) {
      throw new Error('No active organization');
    }

    try {
      const { data, error: queryError } = await supabase
        .from('DirectoryContacts')
        .select(DIRECTORY_CONTACTS_SELECT)
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
   * Create contact — payload mínimo (solo columnas reales). org/dealer vía getEffectiveOrgAndDealer.
   */
  const createContact = useCallback(async (input: CreateContactInput): Promise<DirectoryContact> => {
    try {
      const { orgId, dealerId } = await getEffectiveOrgAndDealer(supabase, {
        activeOrgId: activeOrganizationId ?? null,
        userType,
        activeDealerId: activeDealerId ?? null,
      });

      if (!orgId) {
        throw new Error('No hay organización activa. Selecciona una organización o inicia sesión en el portal.');
      }

      const payload: Record<string, unknown> = {
        organization_id: orgId,
        dealer_id: dealerId ?? input.dealer_id ?? null,
        customer_id: input.customer_id || null,
        contact_title: input.contact_title?.trim() || null,
        contact_name: input.contact_name.trim(),
        contact_id_number: input.contact_id_number?.trim() || null,
        contact_type: input.contact_type,
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

      if (import.meta.env.DEV) {
        console.log('[useDirectoryContacts] Insert payload', { organization_id: payload.organization_id, dealer_id: payload.dealer_id });
      }

      const { data, error: insertError } = await supabase
        .from('DirectoryContacts')
        .insert(payload)
        .select(`
          id, organization_id, dealer_id, customer_id,
          contact_title, contact_name, contact_id_number, contact_type,
          contact_primary_phone, contact_cell_phone, contact_alt_phone, contact_email,
          contact_street_address, contact_street_address_2, contact_city, contact_state, contact_zip_code, contact_country,
          deleted, created_at, updated_at
        `)
        .single();

      if (insertError) {
        const isRls = insertError.message?.toLowerCase().includes('row-level security') || insertError.code === '42501';
        if (isRls) {
          throw new Error('No tienes permisos para crear contactos en este dealer. Comprueba que tu usuario portal esté vinculado (email coincida).');
        }
        throw insertError;
      }

      const newContact = mapToContact(data);
      if (import.meta.env.DEV) {
        console.log('[useDirectoryContacts] Created contact:', newContact.id);
      }
      await fetchContacts();
      return newContact;
    } catch (err: any) {
      const errorMessage = err?.message ?? 'Error creating contact';
      if (import.meta.env.DEV) {
        console.error('[useDirectoryContacts] Create error:', errorMessage, err);
      }
      throw new Error(errorMessage);
    }
  }, [enabled, activeOrganizationId, effectiveDealerId, userType, fetchContacts, mapToContact]);

  /**
   * Update contact (SOLO columnas explícitas)
   */
  const updateContact = useCallback(async (id: string, input: UpdateContactInput): Promise<DirectoryContact> => {
    try {
      const payload: any = {};
      
      if (input.dealer_id !== undefined) {
        payload.dealer_id = input.dealer_id || null;
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
          id, organization_id, dealer_id, customer_id,
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
   * Soft delete contact (vía RPC para respetar permisos Dealer; fallback a UPDATE directo)
   */
  const softDeleteContact = useCallback(async (id: string): Promise<void> => {
    try {
      const { data, error: rpcError } = await supabase.rpc('soft_delete_directory_contact', {
        p_contact_id: id,
      });
      if (rpcError) {
        if (rpcError.code === '42883') {
          const { error: updateError } = await supabase
            .from('DirectoryContacts')
            .update({ deleted: true })
            .eq('id', id)
            .eq('organization_id', activeOrganizationId || '')
            .eq('deleted', false);
          if (updateError) throw updateError;
        } else throw rpcError;
      } else if (data !== 1 && data != null) {
        throw new Error('Contact not found or no permission to delete');
      }

      if (import.meta.env.DEV) {
        console.log('[useDirectoryContacts] Soft deleted contact:', id);
      }

      await fetchContacts();
    } catch (err: any) {
      const errorMessage = err?.message || 'Error deleting contact';
      console.error('[useDirectoryContacts] Delete error:', errorMessage, err);
      throw new Error(errorMessage);
    }
  }, [enabled, activeOrganizationId, fetchContacts]);

  /**
   * Refetch contacts (no abort signal; used after create/update/delete or manual refresh)
   */
  const refetch = useCallback(() => {
    fetchContactsRef.current();
  }, []);

  // Single effect: react to scopeKey (and enabled). Abort previous fetch on cleanup.
  useEffect(() => {
    if (!enabled) {
      setContacts([]);
      setIsPending(false);
      setHasResolvedOnce(false);
      setError(null);
      setScopeState('idle');
      return;
    }

    const ctrl = new AbortController();
    abortControllerRef.current = ctrl;
    fetchContactsRef.current(ctrl.signal);

    return () => {
      ctrl.abort();
      abortControllerRef.current = null;
    };
  }, [scopeKey, enabled, userType]);

  const hasData = contacts.length > 0;
  const isFirstLoad = isPending && !hasResolvedOnce;
  const isRefreshing = isPending && hasResolvedOnce;
  const isSwitchingDealer = scopeState === 'switching' && isPending;

  return {
    contacts,
    isLoading: isPending,
    isPending,
    isInitialLoading,
    isScopeReady,
    hasResolvedOnce,
    error,
    scopeState,
    hasData,
    isFirstLoad,
    isRefreshing,
    isSwitchingDealer,
    fetchContacts,
    getContactById,
    createContact,
    updateContact,
    softDeleteContact,
    refetch,
  };
}
