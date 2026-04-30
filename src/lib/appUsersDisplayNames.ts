/**
 * Helper reutilizable: fetch AppUsers display_name by auth user ids (batch + cache).
 * Usado por Quotes, QuoteLines y Proposals para columnas "Created by" / "Quote created by".
 *
 * - Los ids recibidos son auth_user_id (auth.uid()), que coincide con Quotes.created_by_user_id y Proposals.created_by_user_id.
 * - Llama al RPC SECURITY DEFINER `public.get_app_users_display_names` para evitar la
 *   política RLS de AppUsers (un Dealer Manager no puede ver AppUsers de otros dealers).
 * - Dedupe de ids (Set); si ids vacío retorna Map vacío y no llama a Supabase.
 * - Fallback: map.get(id) ?? 'Legacy / Imported' (null o no encontrado).
 * - Solo se cachean nombres reales; nunca se cachea el fallback.
 *
 * Regla: ERP y portal usan created_by_user_id; nombres vía AppUsers.auth_user_id.
 */

import { supabase } from './supabase/client';

const cache = new Map<string, string>();

export async function getAppUsersDisplayNames(ids: string[]): Promise<Map<string, string>> {
  const deduped = [...new Set(ids)].filter((id): id is string => !!id);
  if (deduped.length === 0) return new Map();

  const result = new Map<string, string>();
  const missing: string[] = [];

  for (const id of deduped) {
    const cached = cache.get(id);
    if (cached !== undefined) {
      result.set(id, cached);
    } else {
      missing.push(id);
    }
  }

  if (missing.length > 0) {
    const { data, error } = await supabase.rpc('get_app_users_display_names', {
      p_auth_user_ids: missing,
    });

    if (error) {
      console.warn('[appUsersDisplayNames] RPC failed, falling back to direct query', error);
    }

    const foundMap = new Map<string, string>();
    const rows = (data || []) as Array<{ auth_user_id: string | null; display_name: string | null }>;
    for (const row of rows) {
      const key = row?.auth_user_id;
      const label = (row?.display_name || '').toString().trim();
      if (key && label) {
        foundMap.set(key, label);
      }
    }

    for (const id of missing) {
      const value = foundMap.get(id);
      if (value) {
        cache.set(id, value);
        result.set(id, value);
      } else {
        result.set(id, 'Legacy / Imported');
      }
    }
  }

  return result;
}

export function clearAppUsersDisplayNamesCache(): void {
  cache.clear();
}
