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
 * Customer shape canónico para UI
 */
export interface DirectoryCustomer {
  id: string;
  organization_id: string;
  dealer_id?: string; // Opcional: dealer_id
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
  created_by_email?: string | null;
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
 *
 * DEALER SCOPE (igual que useDirectoryContacts):
 * - activeDealerId viene de useActiveDealer() (SuperAdmin "acting as dealer").
 * - Si activeDealerId existe => filtro estricto .eq('dealer_id', activeDealerId); al cambiar dealer, refetch por deps.
 */
export function useDirectoryCustomers(params?: { organizationId?: string | null; enabled?: boolean }) {
  const [customers, setCustomers] = useState<DirectoryCustomer[]>([]);
  // ✅ Iniciar como true cuando enabled → isFirstLoad=true desde el primer render (sin flash false→true)
  const [isPending, setIsPending] = useState(true);
  const [hasResolvedOnce, setHasResolvedOnce] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  // ✅ Estándar #1: State Machine
  const [scopeState, setScopeState] = useState<ScopeState>('idle');
  const abortControllerRef = useRef<AbortController | null>(null);

  const fetchIdRef = useRef(0);
  const { activeOrganizationId: contextOrgId } = useOrganizationContext();
  const { scopeKey, activeDealerId, hasHydrated } = useDealerScope();
  const { userType } = useAccessContext();

  const activeOrganizationId = params?.organizationId ?? contextOrgId;
  const enabled = params?.enabled ?? true;

  const scopeKeyRef = useRef<string>(scopeKey);
  scopeKeyRef.current = scopeKey;

  const isScopeReady = userType === 'internal' ? hasHydrated : true;
  const isInitialLoading = !hasResolvedOnce;

  /** Columnas explícitas de DirectoryCustomers según dump (sin name/email/phone que no existen) */
  const DIRECTORY_CUSTOMERS_SELECT = `
    id, organization_id, dealer_id, created_by_email,
    customer_name, customer_email, customer_phone,
    identification_number, customer_type_name, website,
    alt_phone, primary_contact_id,
    street_address_line_1, street_address_line_2, city, state, zip_code, country,
    billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country,
    notes, status, deleted, created_at, updated_at
  `.replace(/\s+/g, ' ').trim();

  /**
   * Select customers: solo columnas explícitas (evita 42703 y warning "Generic columns not found").
   */
  const safeSelectCustomers = useCallback(async (orgId: string, dealerId: string | null = null) => {
    let q = supabase
      .from('DirectoryCustomers')
      .select(DIRECTORY_CUSTOMERS_SELECT)
      .eq('organization_id', orgId)
      .eq('deleted', false)
      .order('created_at', { ascending: false });
    if (dealerId != null) {
      q = q.eq('dealer_id', dealerId);
    }
    const { data, error: queryError } = await q;
    if (queryError) throw queryError;
    return data || [];
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
      dealer_id: row.dealer_id || undefined,
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
      created_by_email: row.created_by_email ?? null,
    };
  }, []);

  /**
   * Fetch customers — portal = dealer_id obligatorio; org = selectedDealerId o todos.
   * Does not clear the list before fetch. Optional signal for abort on scope change.
   */
  const fetchCustomers = useCallback(async (signal?: AbortSignal) => {
    if (!enabled || !activeOrganizationId) {
      setCustomers([]);
      setIsPending(false);
      setHasResolvedOnce(false);
      setError(null);
      setScopeState('idle');
      return;
    }
    if (signal?.aborted) return;
    if (!isScopeReady) {
      setIsPending(true);
      setScopeState('loading_scope');
      return;
    }

    const thisFetchId = ++fetchIdRef.current;
    const currentScopeKey = scopeKey;

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
      } else {
        dealerId = activeDealerId ?? null;
      }

      const data = await safeSelectCustomers(activeOrganizationId, dealerId);
      if (signal?.aborted) return;
      const mapped = data.map(mapToCustomer);

      if (thisFetchId !== fetchIdRef.current) return;
      if (scopeKeyRef.current !== currentScopeKey) return;

      if (import.meta.env.DEV) {
        console.log('[useDirectoryCustomers] Fetched customers:', {
          count: mapped.length,
          userType,
          dealerId,
          scopeKey: currentScopeKey,
        });
      }

      setCustomers(mapped);
      setError(null);
      setScopeState('ready');
    } catch (err: any) {
      if (err?.name === 'AbortError') return;
      if (thisFetchId !== fetchIdRef.current) return;
      if (scopeKeyRef.current !== currentScopeKey) return;
      const errorMessage = err?.message || 'Error loading customers';
      console.error('[useDirectoryCustomers] Error:', errorMessage, err);
      setError(errorMessage);
      setScopeState('error');
    } finally {
      if (thisFetchId === fetchIdRef.current && scopeKeyRef.current === currentScopeKey) {
        setIsPending(false);
        setHasResolvedOnce(true);
      }
    }
  }, [enabled, activeOrganizationId, activeDealerId, userType, safeSelectCustomers, mapToCustomer, scopeKey, hasResolvedOnce, isScopeReady]);

  const fetchCustomersRef = useRef(fetchCustomers);
  fetchCustomersRef.current = fetchCustomers;

  /**
   * Create customer — payload mínimo. org/dealer vía getEffectiveOrgAndDealer.
   */
  const createCustomer = useCallback(async (input: CreateCustomerInput & { dealer_id?: string }): Promise<DirectoryCustomer> => {
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

      if (import.meta.env.DEV) {
        console.log('[useDirectoryCustomers] Insert payload', { organization_id: payload.organization_id, dealer_id: payload.dealer_id });
      }

      const { data, error: insertError } = await supabase
        .from('DirectoryCustomers')
        .insert(payload)
        .select(`
          id, organization_id, dealer_id,
          customer_name, customer_email, customer_phone,
          identification_number, customer_type_name, website,
          alt_phone, primary_contact_id,
          street_address_line_1, street_address_line_2, city, state, zip_code, country,
          billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country,
          notes, status, deleted, created_at, updated_at
        `)
        .single();

      if (insertError) {
        const isRls = insertError.message?.toLowerCase().includes('row-level security') || insertError.code === '42501';
        if (isRls) {
          throw new Error('No tienes permisos para crear clientes en este dealer. Comprueba que tu usuario portal esté vinculado (email coincida).');
        }
        throw insertError;
      }

      const newCustomer = mapToCustomer({ ...data, dealer_id: (data?.dealer_id ?? input.dealer_id) || null });
      if (import.meta.env.DEV) {
        console.log('[useDirectoryCustomers] Created customer:', newCustomer.id);
      }
      await fetchCustomers();
      return newCustomer;
    } catch (err: any) {
      const errorMessage = err?.message ?? 'Error creating customer';
      if (import.meta.env.DEV) {
        console.error('[useDirectoryCustomers] Create error:', errorMessage, err);
      }
      throw new Error(errorMessage);
    }
  }, [activeOrganizationId, activeDealerId, userType, fetchCustomers, mapToCustomer]);

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
          id, organization_id, dealer_id,
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
   * Soft delete customer (vía RPC para respetar permisos Dealer; fallback a UPDATE directo)
   */
  const archiveCustomer = useCallback(async (id: string): Promise<void> => {
    try {
      const { data, error: rpcError } = await supabase.rpc('soft_delete_directory_customer', {
        p_customer_id: id,
      });
      if (rpcError) {
        if (rpcError.code === '42883') {
          const { error: updateError } = await supabase
            .from('DirectoryCustomers')
            .update({ deleted: true })
            .eq('id', id)
            .eq('organization_id', activeOrganizationId || '')
            .eq('deleted', false);
          if (updateError) throw updateError;
        } else throw rpcError;
      } else if (data !== 1 && data != null) {
        throw new Error('Customer not found or no permission to delete');
      }

      if (import.meta.env.DEV) {
        console.log('[useDirectoryCustomers] Archived customer:', id);
      }

      await fetchCustomers();
    } catch (err: any) {
      const errorMessage = err?.message || 'Error archiving customer';
      console.error('[useDirectoryCustomers] Archive error:', errorMessage, err);
      throw new Error(errorMessage);
    }
  }, [activeOrganizationId, fetchCustomers]);

  const refetch = useCallback(() => {
    fetchCustomersRef.current();
  }, []);

  useEffect(() => {
    if (!enabled) {
      setCustomers([]);
      setIsPending(false);
      setHasResolvedOnce(false);
      setError(null);
      setScopeState('idle');
      return;
    }

    const ctrl = new AbortController();
    abortControllerRef.current = ctrl;
    fetchCustomersRef.current(ctrl.signal);

    return () => {
      ctrl.abort();
      abortControllerRef.current = null;
    };
  }, [scopeKey, enabled, userType]);

  const hasData = customers.length > 0;
  const isFirstLoad = isPending && !hasResolvedOnce;
  const isRefreshing = isPending && hasResolvedOnce;
  const isSwitchingDealer = scopeState === 'switching' && isPending;

  return {
    customers,
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
    fetchCustomers,
    createCustomer,
    updateCustomer,
    archiveCustomer,
    refetch,
  };
}
