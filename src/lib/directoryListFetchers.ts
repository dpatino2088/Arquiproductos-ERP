import type { SupabaseClient } from '@supabase/supabase-js';
import { getEffectiveOrgAndDealer } from './directoryContext';
import type { DirectoryContact } from '../hooks/useDirectoryContacts';
import type { DirectoryCustomer } from '../hooks/useDirectoryCustomers';

const DIRECTORY_CONTACTS_SELECT = `
  id, organization_id, dealer_id, customer_id, created_by_email,
  contact_title, contact_name, contact_id_number, contact_type,
  contact_primary_phone, contact_cell_phone, contact_alt_phone, contact_email,
  contact_street_address, contact_street_address_2, contact_city, contact_state, contact_zip_code, contact_country,
  deleted, created_at, updated_at
`.replace(/\s+/g, ' ').trim();

type ContactType = 'architect' | 'interior_designer' | 'engineer' | 'project_manager' | 'end_customer';

function normalizeContactType(type: unknown): ContactType | null {
  if (!type) return null;
  const s = String(type).trim().toLowerCase();
  if (['architect', 'interior_designer', 'engineer', 'project_manager', 'end_customer'].includes(s)) {
    return s as ContactType;
  }
  return null;
}

/** Map a single row (e.g. from .single() after insert/update) to DirectoryContact. */
export function mapRowToContact(row: Record<string, unknown>): DirectoryContact {
  return {
    id: row.id as string,
    organization_id: row.organization_id as string,
    dealer_id: (row.dealer_id as string) || null,
    customer_id: (row.customer_id as string) || null,
    contact_title: (row.contact_title as string)?.trim() || null,
    contact_name: ((row.contact_name ?? row.name) as string)?.trim() || '',
    contact_id_number: (row.contact_id_number as string)?.trim() || null,
    contact_type: normalizeContactType(row.contact_type ?? row.type),
    contact_primary_phone: (row.contact_primary_phone as string)?.trim() || null,
    contact_cell_phone: (row.contact_cell_phone as string)?.trim() || null,
    contact_alt_phone: (row.contact_alt_phone as string)?.trim() || null,
    contact_email: (row.contact_email as string)?.trim() || null,
    contact_street_address: (row.contact_street_address as string)?.trim() || null,
    contact_street_address_2: (row.contact_street_address_2 as string)?.trim() || null,
    contact_city: (row.contact_city as string)?.trim() || null,
    contact_state: (row.contact_state as string)?.trim() || null,
    contact_zip_code: (row.contact_zip_code as string)?.trim() || null,
    contact_country: (row.contact_country as string)?.trim() || null,
    deleted: Boolean(row.deleted),
    created_at: row.created_at as string | undefined,
    updated_at: row.updated_at as string | undefined,
    created_by_email: (row.created_by_email as string) ?? null,
  };
}

/**
 * Fetch Directory contacts for list. Used by useDirectoryContactsList queryFn.
 */
export async function fetchDirectoryContacts(
  supabase: SupabaseClient,
  params: {
    orgId: string;
    userType: 'internal' | 'portal' | 'unknown';
    activeDealerId: string | null;
  }
): Promise<DirectoryContact[]> {
  const { orgId, userType, activeDealerId } = params;
  let dealerId: string | null = null;
  if (userType === 'portal') {
    const effective = await getEffectiveOrgAndDealer(supabase, {
      activeOrgId: orgId,
      userType,
      activeDealerId: null,
    });
    dealerId = effective.dealerId;
    if (dealerId == null) return [];
  } else {
    dealerId = activeDealerId;
  }

  if (import.meta.env.DEV) {
    console.log('[fetchDirectoryContacts] QUERY PARAMS', { orgId, userType, activeDealerId, dealerId });
  }

  let q = supabase
    .from('DirectoryContacts')
    .select(DIRECTORY_CONTACTS_SELECT)
    .eq('organization_id', orgId)
    .eq('deleted', false)
    .order('created_at', { ascending: false });

  if (userType === 'portal') {
    q = q.eq('dealer_id', dealerId!);
  } else if (dealerId != null) {
    q = q.eq('dealer_id', dealerId);
  }

  const { data, error } = await q;
  if (import.meta.env.DEV) {
    console.log('[fetchDirectoryContacts] RESULT', { dealerId, count: data?.length ?? 0, error: error?.message ?? null });
  }
  if (error) throw error;
  return (data || []).map((row) => mapRowToContact(row as unknown as Record<string, unknown>));
}

const DIRECTORY_CUSTOMERS_SELECT = `
  id, organization_id, dealer_id, created_by_email,
  customer_name, customer_email, customer_phone,
  identification_number, customer_type_name, website,
  alt_phone, primary_contact_id,
  street_address_line_1, street_address_line_2, city, state, zip_code, country,
  billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country,
  notes, status, deleted, created_at, updated_at
`.replace(/\s+/g, ' ').trim();

/** Map a single row (e.g. from .single() after insert/update) to DirectoryCustomer. */
export function mapRowToCustomer(row: Record<string, unknown>): DirectoryCustomer {
  return {
    id: row.id as string,
    organization_id: row.organization_id as string,
    dealer_id: (row.dealer_id as string) || undefined,
    customer_name: ((row.customer_name ?? row.name) as string)?.trim() || '',
    customer_email: (row.customer_email as string)?.trim() || null,
    customer_phone: (row.customer_phone as string)?.trim() || null,
    identification_number: (row.identification_number as string)?.trim() || null,
    customer_type_name: (row.customer_type_name as string)?.trim() || null,
    website: (row.website as string)?.trim() || null,
    alt_phone: (row.alt_phone as string)?.trim() || null,
    primary_contact_id: (row.primary_contact_id as string) || null,
    street_address_line_1: (row.street_address_line_1 as string)?.trim() || null,
    street_address_line_2: (row.street_address_line_2 as string)?.trim() || null,
    city: (row.city as string)?.trim() || null,
    state: (row.state as string)?.trim() || null,
    zip_code: (row.zip_code as string)?.trim() || null,
    country: (row.country as string)?.trim() || null,
    billing_street_address_line_1: (row.billing_street_address_line_1 as string)?.trim() || null,
    billing_street_address_line_2: (row.billing_street_address_line_2 as string)?.trim() || null,
    billing_city: (row.billing_city as string)?.trim() || null,
    billing_state: (row.billing_state as string)?.trim() || null,
    billing_zip_code: (row.billing_zip_code as string)?.trim() || null,
    billing_country: (row.billing_country as string)?.trim() || null,
    notes: (row.notes as string)?.trim() || null,
    status: (row.status as string) || undefined,
    deleted: Boolean(row.deleted),
    created_at: row.created_at as string | undefined,
    updated_at: row.updated_at as string | undefined,
    created_by_email: (row.created_by_email as string) ?? null,
  };
}

/**
 * Fetch Directory customers for list. Used by useDirectoryCustomersList queryFn.
 */
export async function fetchDirectoryCustomers(
  supabase: SupabaseClient,
  params: {
    orgId: string;
    userType: 'internal' | 'portal' | 'unknown';
    activeDealerId: string | null;
  }
): Promise<DirectoryCustomer[]> {
  const { orgId, userType, activeDealerId } = params;
  let dealerId: string | null = null;
  if (userType === 'portal') {
    const effective = await getEffectiveOrgAndDealer(supabase, {
      activeOrgId: orgId,
      userType,
      activeDealerId: null,
    });
    dealerId = effective.dealerId;
    if (dealerId == null) return [];
  } else {
    dealerId = activeDealerId;
  }

  if (import.meta.env.DEV) {
    console.log('[fetchDirectoryCustomers] QUERY PARAMS', { orgId, userType, activeDealerId, dealerId });
  }

  let q = supabase
    .from('DirectoryCustomers')
    .select(DIRECTORY_CUSTOMERS_SELECT)
    .eq('organization_id', orgId)
    .eq('deleted', false)
    .order('created_at', { ascending: false });
  if (dealerId != null) {
    q = q.eq('dealer_id', dealerId);
  }
  const { data, error } = await q;
  if (import.meta.env.DEV) {
    console.log('[fetchDirectoryCustomers] RESULT', { dealerId, count: data?.length ?? 0, error: error?.message ?? null });
  }
  if (error) throw error;
  return (data || []).map((row) => mapRowToCustomer(row as unknown as Record<string, unknown>));
}
