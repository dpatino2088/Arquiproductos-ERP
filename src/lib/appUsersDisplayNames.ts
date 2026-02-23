/**
 * Helper reutilizable: fetch AppUsers display_name by auth user ids (batch + cache).
 * Usado por Quotes, QuoteLines y Proposals para columnas "Created by" / "Quote created by".
 *
 * - Los ids recibidos son auth_user_id (auth.uid()), que coincide con Quotes.created_by_user_id y Proposals.created_by_user_id.
 * - Busca en AppUsers por auth_user_id (no por AppUsers.id).
 * - Dedupe de ids (Set); si ids vacío retorna Map vacío y no llama a Supabase.
 * - Fallback: map.get(id) ?? 'Legacy / Imported' (null o no encontrado).
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
    const { data } = await supabase
      .from('AppUsers')
      .select('auth_user_id, display_name')
      .in('auth_user_id', missing)
      .eq('deleted', false);

    for (const id of missing) {
      const row = (data || []).find((r: { auth_user_id: string }) => r.auth_user_id === id);
      const value = (row?.display_name?.trim() || row?.display_name) ?? 'Legacy / Imported';
      cache.set(id, value);
      result.set(id, value);
    }
  }

  return result;
}
