// src/auth/authContext.ts
// Types and helper function for get_auth_context() RPC

import type { SupabaseClient } from '@supabase/supabase-js';

export type AuthContextRow = {
  user_id: string | null;
  is_org_user: boolean;
  is_portal_user: boolean;
  organization_id: string | null;
  company_id: string | null;
  needs_password: boolean;
  access_allowed: boolean;
};

/**
 * Fetch authentication context using get_auth_context() RPC
 * 
 * Returns the authentication context including:
 * - User ID
 * - Membership status (org_user, portal_user)
 * - Organization/Company IDs
 * - Password requirement status
 * - Access permission
 * 
 * @param supabase - Supabase client instance
 * @returns AuthContextRow with user context, or default values if no context found
 */
export async function fetchAuthContext(supabase: SupabaseClient): Promise<AuthContextRow> {
  const { data, error } = await supabase.rpc('get_auth_context');

  if (error) {
    console.error('[fetchAuthContext] RPC error:', error);
    throw error;
  }

  // Supabase RPC can return array or single row depending on function definition
  // get_auth_context() returns TABLE, so it's an array
  const row = Array.isArray(data) ? (data[0] as AuthContextRow | undefined) : (data as AuthContextRow | null);

  // Return default values if no context found
  return (
    row ?? {
      user_id: null,
      is_org_user: false,
      is_portal_user: false,
      organization_id: null,
      company_id: null,
      needs_password: false,
      access_allowed: false,
    }
  );
}
